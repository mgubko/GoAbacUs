import 'dart:typed_data';

import 'image.dart';

/// Says when the picture has stood still long enough to judge the child's
/// work (no hand moving over the field): the mean change of a small
/// thumbnail between frames stays below [threshold] for [still].
class StillnessGate {
  StillnessGate({this.threshold = 3.0, this.still = const Duration(milliseconds: 700)});

  final double threshold;
  final Duration still;

  Float32List? _prev;
  DateTime? _since;

  /// Feeds a frame; true once it has been still for [still].
  bool feed(PlaneImage p, DateTime now) {
    const tw = 40, th = 28;
    final t = Float32List(tw * th);
    for (var y = 0; y < th; y++) {
      for (var x = 0; x < tw; x++) {
        final u = (x + 0.5) * p.width ~/ tw, v = (y + 0.5) * p.height ~/ th;
        t[y * tw + x] = p.lum(v * p.width + u);
      }
    }
    final prev = _prev;
    _prev = t;
    if (prev == null) {
      _since = now;
      return false;
    }
    var diff = 0.0;
    for (var i = 0; i < t.length; i++) {
      diff += (t[i] - prev[i]).abs();
    }
    diff /= t.length;
    if (diff > threshold) _since = now;
    return now.difference(_since!) >= still;
  }
}
