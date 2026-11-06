import 'dart:math' as math;

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

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

  Future<void> init() async {
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
    final strongest = impacts.first.speed;
    if (strongest > 0.7) {
      final now = DateTime.now();
      if (now.difference(_lastHaptic).inMilliseconds > 60) {
        _lastHaptic = now;
        HapticFeedback.lightImpact();
      }
    }
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
