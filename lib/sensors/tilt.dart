import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:sensors_plus/sensors_plus.dart';

/// Reads the accelerometer and turns it into gravity along the abacus wires
/// (screen X axis) and gravity pressing the beads onto the wires.
class TiltSensor {
  static const _channel = MethodChannel('goabacus/display');

  StreamSubscription<AccelerometerEvent>? _sub;

  /// Display rotation: 0, 1 (90°), 2 (180°), 3 (270°), in Android terms.
  int _rotation = 0;

  /// Low-pass filtered gravity in screen coordinates.
  double along = 0;
  double normal = 9.81;
  bool available = false;

  void start() {
    refreshRotation();
    try {
      _sub =
          accelerometerEventStream(
            samplingPeriod: SensorInterval.gameInterval,
          ).listen(
            _onEvent,
            onError: (_) => available = false,
            cancelOnError: true,
          );
    } catch (_) {
      available = false;
    }
  }

  Future<void> refreshRotation() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;
    try {
      _rotation = await _channel.invokeMethod<int>('rotation') ?? _rotation;
    } catch (_) {}
  }

  void _onEvent(AccelerometerEvent e) {
    available = true;
    // Device axes -> screen X axis.
    final double sx = switch (_rotation) {
      0 => e.x,
      1 => -e.y,
      2 => -e.x,
      _ => e.y,
    };
    // The accelerometer measures the reaction to gravity, so gravity along the
    // screen X axis is the opposite sign.
    final g = -sx;
    final total = math.sqrt(e.x * e.x + e.y * e.y + e.z * e.z);
    final n = math.sqrt(math.max(0, total * total - sx * sx));
    const k = 0.25;
    along += (g - along) * k;
    normal += (n - normal) * k;
  }

  void pause() => _sub?.pause();

  void resume() {
    if (_sub?.isPaused ?? false) _sub!.resume();
  }

  void dispose() => _sub?.cancel();
}
