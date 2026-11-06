import 'dart:math' as math;

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:vibration/vibration.dart';

import '../physics/abacus_physics.dart';

/// A fixed set of pre-loaded low-latency players for one sample, reused in
/// turn. (audioplayers' AudioPool never returns low-latency players to the
/// pool, so it created a new native player for every click and the app
/// slowed down and hung after a while.)
class _Voices {
  _Voices(this._players);
  final List<AudioPlayer> _players;
  final _busy = <bool>[];
  var _next = 0;

  static Future<_Voices> load(String asset, int count) async {
    final players = <AudioPlayer>[];
    for (var i = 0; i < count; i++) {
      final p = AudioPlayer();
      await p.setPlayerMode(PlayerMode.lowLatency);
      await p.setReleaseMode(ReleaseMode.stop);
      await p.setSource(AssetSource(asset));
      players.add(p);
    }
    return _Voices(players).._busy.addAll(List.filled(count, false));
  }

  void play(double volume) {
    // Skip if every voice is still talking to the platform: dropping a click
    // is better than queueing work behind the UI.
    for (var k = 0; k < _players.length; k++) {
      final i = (_next + k) % _players.length;
      if (_busy[i]) continue;
      _next = i + 1;
      _busy[i] = true;
      final p = _players[i];
      () async {
        try {
          await p.stop();
          await p.setVolume(volume);
          await p.resume();
        } catch (_) {
        } finally {
          _busy[i] = false;
        }
      }();
      return;
    }
  }

  Future<void> stopAll() async {
    for (final p in _players) {
      try {
        await p.stop();
      } catch (_) {}
    }
  }

  Future<void> dispose() async {
    for (final p in _players) {
      await p.dispose();
    }
  }
}

/// Plays bone and wood impact sounds. Loudness follows the impact speed.
class SoundEngine {
  final _bone = <_Voices>[];
  final _wood = <_Voices>[];
  final _rng = math.Random();
  bool enabled = true;

  /// Overall loudness; the clicks should be heard, not startle.
  double masterVolume = 0.6;
  bool _ready = false;
  bool _paused = false;
  DateTime _lastHaptic = DateTime.fromMillisecondsSinceEpoch(0);

  static const _variants = 4;
  static const _maxPerFrame = 4;

  bool vibrationEnabled = true;
  bool _amplitude = false;
  bool _hasVibrator = false;

  /// Impulse (kg·m/s) that gives the strongest buzz: a full row of ten
  /// beads hitting the frame at 0.25 m/s, or one bead flicked at 2.5 m/s.
  static const double _fullImpulse = 0.02;
  static const double _minImpulse = 0.001;

  /// Buzz on frame hits, stronger and longer for a bigger impulse.
  void _vibrate(List<Impact> impacts) {
    if (!vibrationEnabled) return;
    var impulse = 0.0;
    for (final i in impacts) {
      if (i.kind == ImpactKind.frame && i.impulse > impulse) {
        impulse = i.impulse;
      }
    }
    if (impulse < _minImpulse) return;
    final now = DateTime.now();
    if (now.difference(_lastHaptic).inMilliseconds < 40) return;
    _lastHaptic = now;
    final k = math.min(1.0, impulse / _fullImpulse);
    if (_hasVibrator) {
      Vibration.vibrate(
        // Short buzzes under ~15 ms are not felt on many phones.
        duration: (15 + 45 * k).round(),
        amplitude: _amplitude ? (70 + 185 * k).round() : -1,
      );
    } else if (k > 0.6) {
      HapticFeedback.heavyImpact();
    } else if (k > 0.25) {
      HapticFeedback.mediumImpact();
    } else {
      HapticFeedback.lightImpact();
    }
  }

  Future<void> init() async {
    try {
      _hasVibrator = await Vibration.hasVibrator();
      _amplitude = _hasVibrator && await Vibration.hasAmplitudeControl();
    } catch (_) {
      _hasVibrator = false;
    }
    try {
      await AudioPlayer.global.setAudioContext(
        AudioContextConfig(
          focus: AudioContextConfigFocus.mixWithOthers,
        ).build(),
      );
      for (var i = 0; i < _variants; i++) {
        _bone.add(await _Voices.load('sounds/bone_$i.wav', 3));
        _wood.add(await _Voices.load('sounds/wood_$i.wav', 2));
      }
      _ready = true;
    } catch (e) {
      debugPrint('Sound disabled: $e');
    }
  }

  /// Called when the app goes to the background / comes back.
  void setPaused(bool paused) {
    _paused = paused;
    if (paused) {
      for (final v in [..._bone, ..._wood]) {
        v.stopAll();
      }
    }
  }

  /// Plays the loudest impacts of one frame.
  void play(List<Impact> impacts) {
    if (impacts.isEmpty || _paused) return;
    impacts.sort((a, b) => b.speed.compareTo(a.speed));
    _vibrate(impacts);
    if (!enabled || !_ready) return;
    for (final impact in impacts.take(_maxPerFrame)) {
      final volume = (0.15 + 0.85 * math.min(1.0, impact.speed / 1.2)).clamp(
        0.0,
        1.0,
      );
      final voices = impact.kind == ImpactKind.bead ? _bone : _wood;
      voices[_rng.nextInt(voices.length)].play(masterVolume * volume * volume);
    }
  }

  Future<void> dispose() async {
    for (final v in [..._bone, ..._wood]) {
      await v.dispose();
    }
  }
}
