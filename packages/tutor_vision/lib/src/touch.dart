import 'dart:math' as math;
import 'dart:typed_data';

import 'blobs.dart';
import 'homography.dart';
import 'image.dart';
import 'layout.dart';

/// A fingertip pressed on the matte sheet, seen from behind.
class Touch {
  Touch(this.center, this.areaMm2, this.sharpness, this.contrast, this.cell);

  /// Sheet position, mm, y up.
  final Pt center;
  final double areaMm2;

  /// Edge steepness relative to the contrast; pressing gives a sharp spot,
  /// a hovering finger a soft one.
  final double sharpness;
  final double contrast;

  /// (row, column) in the sheet's table, row/column 0 = headers.
  final (int, int)? cell;

  @override
  String toString() => 'Touch($center, ${areaMm2.round()} mm², s=${sharpness.toStringAsFixed(2)}, cell $cell)';
}

/// Finds fingertips pressed on a matte translucent sheet, camera behind it
/// (cuisenaire-research.md, section 9). Diffuser physics: what touches the
/// sheet is sharp, what is a few mm away is blurred. So: difference to the
/// learned empty sheet → high-pass (spot minus its 5 mm surroundings) →
/// blobs of fingertip size with a sharp edge.
///
/// Works with room light from the child's side (the finger is a shadow) and
/// with a backlight from the camera side (the finger is a bright spot).
class TouchReader {
  TouchReader({this.minAreaMm2 = 25, this.maxAreaMm2 = 450, this.minSharpness = 0.35, this.minContrast = 14});

  final double minAreaMm2, maxAreaMm2, minSharpness, minContrast;

  Float32List? _background;
  int _bgW = 0, _bgH = 0;

  bool get hasBackground => _background != null;

  /// Forget the background; the next frame becomes the empty sheet.
  void reset() => _background = null;

  /// Learn the empty sheet (call with nothing touching it).
  void learnBackground(PlaneImage empty) {
    _background = planeLuma(empty);
    _bgW = empty.width;
    _bgH = empty.height;
  }

  List<Touch> read(PlaneImage cur, {TableGrid? table, bool adapt = true}) {
    final w = cur.width, h = cur.height, s = cur.scale;
    final lum = planeLuma(cur);
    if (_background == null || _bgW != w || _bgH != h) {
      learnBackground(cur);
      return const [];
    }
    final bg = _background!;
    // Exposure drift: scale by the median ratio.
    final ratios = <double>[for (var i = 0; i < w * h; i += 11) (lum[i] + 1) / (bg[i] + 1)]..sort();
    final gain = ratios[ratios.length ~/ 2];
    final d = Float32List(w * h);
    var pos = 0.0, neg = 0.0;
    for (var i = 0; i < w * h; i++) {
      final v = bg[i] * gain - lum[i]; // > 0: darker than the empty sheet
      d[i] = v;
      if (v > 0) {
        pos = math.max(pos, v);
      } else {
        neg = math.max(neg, -v);
      }
    }
    // Backlight mode: the finger reflects light and is brighter.
    final sign = neg > pos * 1.3 ? -1.0 : 1.0;
    if (sign < 0) {
      for (var i = 0; i < w * h; i++) {
        d[i] = -d[i];
      }
    }
    final r = math.max(2, (5 * s).round());
    final blurred = boxBlur(d, w, h, r);
    final mask = Uint8List(w * h);
    for (var i = 0; i < w * h; i++) {
      final hp = d[i] - blurred[i];
      if (d[i] > minContrast && hp > minContrast * 0.5) mask[i] = 1;
    }
    final blobs = findBlobs(mask, w, h, minArea: (minAreaMm2 * 0.4 * s * s).round());
    final touches = <Touch>[];
    // Gradient magnitude of d (for the edge sharpness).
    for (final b in blobs) {
      final area = b.area / (s * s);
      if (area < minAreaMm2 || area > maxAreaMm2) continue;
      var peak = 0.0, wx = 0.0, wy = 0.0, ws = 0.0;
      for (final p in b.pixels) {
        final v = d[p];
        if (v > peak) peak = v;
        wx += (p % w) * v;
        wy += (p ~/ w) * v;
        ws += v;
      }
      if (peak < minContrast * 1.5) continue;
      // Sharpness: steepest drop across the blob's rim, per mm, over peak.
      var grad = <double>[];
      for (final p in b.pixels) {
        final x = p % w, y = p ~/ w;
        if (x < 1 || y < 1 || x >= w - 1 || y >= h - 1) continue;
        if (mask[p - 1] == 1 && mask[p + 1] == 1 && mask[p - w] == 1 && mask[p + w] == 1) continue;
        final gx = (d[p + 1] - d[p - 1]) / 2, gy = (d[p + w] - d[p - w]) / 2;
        grad.add(math.sqrt(gx * gx + gy * gy) * s);
      }
      if (grad.isEmpty) continue;
      grad.sort();
      final rim = grad[(grad.length * 0.75).floor().clamp(0, grad.length - 1)];
      final sharp = rim / peak;
      if (sharp < minSharpness) continue;
      final c = Pt(cur.xMm(wx / ws), cur.yMm(wy / ws));
      touches.add(Touch(c, area, sharp, peak, table?.cellAt(c)));
    }
    if (adapt && touches.isEmpty) {
      // Slowly follow light changes where nothing is happening.
      for (var i = 0; i < w * h; i++) {
        if (d[i].abs() < minContrast * 0.7) bg[i] = bg[i] * 0.9 + lum[i] / gain * 0.1;
      }
    }
    return touches;
  }
}
