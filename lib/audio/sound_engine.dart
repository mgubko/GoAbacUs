import 'dart:math' as math;

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../physics/abacus_physics.dart';

/// Plays bone and wood impact sounds. Loudness follows the impact speed.
class SoundEngine {
  final _bone = <AudioPool>[];
  final _wood = <AudioPool>[];
  final _rng = math.Random();
  bool enabled = true;
  bool _ready = false;
  DateTime _lastHaptic = DateTime.fromMillisecondsSinceEpoch(0);

  static const _variants = 4;
  static const _maxPerFrame = 5;

  Future<void> init() async {
    try {
      await AudioPlayer.global.setAudioContext(
        AudioContextConfig(
          focus: AudioContextConfigFocus.mixWithOthers,
        ).build(),
      );
      for (var i = 0; i < _variants; i++) {
        _bone.add(
          await AudioPool.createFromAsset(
            path: 'sounds/bone_$i.wav',
            maxPlayers: 4,
            playerMode: PlayerMode.lowLatency,
          ),
        );
        _wood.add(
          await AudioPool.createFromAsset(
            path: 'sounds/wood_$i.wav',
            maxPlayers: 3,
            playerMode: PlayerMode.lowLatency,
          ),
        );
      }
      _ready = true;
    } catch (e) {
      debugPrint('Sound disabled: $e');
    }
  }

  /// Plays the loudest impacts of one frame.
  void play(List<Impact> impacts) {
    if (impacts.isEmpty) return;
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
      // Perceived loudness grows roughly with the log of impact energy.
      final volume = (0.15 + 0.85 * math.min(1.0, impact.speed / 1.2)).clamp(
        0.0,
        1.0,
      );
      final pools = impact.kind == ImpactKind.bead ? _bone : _wood;
      pools[_rng.nextInt(pools.length)].start(volume: volume * volume);
    }
  }

  Future<void> dispose() async {
    for (final p in [..._bone, ..._wood]) {
      await p.dispose();
    }
  }
}
