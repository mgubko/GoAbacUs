import 'dart:math' as math;
import 'dart:typed_data';

import 'image.dart';

/// A connected region of a binary mask.
class Blob {
  Blob(this.pixels, this.width);
  final List<int> pixels;
  final int width;

  int get area => pixels.length;

  late final (double, double) centroid = () {
    var sx = 0.0, sy = 0.0;
    for (final p in pixels) {
      sx += p % width;
      sy += p ~/ width;
    }
    return (sx / area, sy / area);
  }();

  /// Principal axis angle (radians, image coordinates) and the extents
  /// along / across it, trimmed by [trim] of the pixels at each end.
  ({double angle, double length, double thickness, double lo, double hi, double wlo, double whi}) axes(
      {double trim = 0.01}) {
    final (cx, cy) = centroid;
    var sxx = 0.0, syy = 0.0, sxy = 0.0;
    for (final p in pixels) {
      final dx = p % width - cx, dy = p ~/ width - cy;
      sxx += dx * dx;
      syy += dy * dy;
      sxy += dx * dy;
    }
    final angle = 0.5 * math.atan2(2 * sxy, sxx - syy);
    final c = math.cos(angle), s = math.sin(angle);
    final along = Float64List(area), across = Float64List(area);
    for (var i = 0; i < area; i++) {
      final dx = pixels[i] % width - cx, dy = pixels[i] ~/ width - cy;
      along[i] = dx * c + dy * s;
      across[i] = -dx * s + dy * c;
    }
    along.sort();
    across.sort();
    final k = (area * trim).floor();
    final lo = along[k] - 0.5, hi = along[area - 1 - k] + 0.5;
    final wlo = across[k] - 0.5, whi = across[area - 1 - k] + 0.5;
    return (angle: angle, length: hi - lo, thickness: whi - wlo, lo: lo, hi: hi, wlo: wlo, whi: whi);
  }
}

extension BlobShape on Blob {
  /// True for a row of touching discs: the width across the main axis
  /// narrows between them (a rod, or rods side by side, keeps its width).
  bool get scalloped {
    final ax = axes();
    final (cx, cy) = centroid;
    final c = math.cos(ax.angle), s = math.sin(ax.angle);
    final bins = math.max(8, ax.length.round());
    final lo = Float64List(bins)..fillRange(0, bins, double.infinity);
    final hi = Float64List(bins)..fillRange(0, bins, -double.infinity);
    for (final p in pixels) {
      final dx = p % width - cx, dy = p ~/ width - cy;
      final t = dx * c + dy * s, q = -dx * s + dy * c;
      final k = ((t - ax.lo) / ax.length * bins).floor().clamp(0, bins - 1);
      if (q < lo[k]) lo[k] = q;
      if (q > hi[k]) hi[k] = q;
    }
    final wd = [for (var k = 0; k < bins; k++) hi[k] >= lo[k] ? hi[k] - lo[k] : 0.0];
    final a = (bins * 0.2).floor(), b = (bins * 0.8).ceil();
    var minW = double.infinity, maxW = 0.0;
    for (var k = a; k < b; k++) {
      if (wd[k] < minW) minW = wd[k];
      if (wd[k] > maxW) maxW = wd[k];
    }
    return maxW > 0 && minW < 0.8 * maxW;
  }
}

/// 8-connected components of [mask] (non-zero = set) with at least [minArea]
/// pixels.
List<Blob> findBlobs(Uint8List mask, int w, int h, {int minArea = 1}) {
  final seen = Uint8List(w * h);
  final stack = Int32List(w * h);
  final out = <Blob>[];
  for (var start = 0; start < w * h; start++) {
    if (mask[start] == 0 || seen[start] != 0) continue;
    var sp = 0;
    stack[sp++] = start;
    seen[start] = 1;
    final px = <int>[];
    while (sp > 0) {
      final p = stack[--sp];
      px.add(p);
      final x = p % w, y = p ~/ w;
      for (var dy = -1; dy <= 1; dy++) {
        final yy = y + dy;
        if (yy < 0 || yy >= h) continue;
        for (var dx = -1; dx <= 1; dx++) {
          final xx = x + dx;
          if (xx < 0 || xx >= w) continue;
          final q = yy * w + xx;
          if (mask[q] != 0 && seen[q] == 0) {
            seen[q] = 1;
            stack[sp++] = q;
          }
        }
      }
    }
    if (px.length >= minArea) out.add(Blob(px, w));
  }
  return out;
}

/// Binary erosion / dilation with a (2r+1) square, separable.
Uint8List _morph(Uint8List m, int w, int h, int r, bool dilate) {
  final tmp = Uint8List(w * h), out = Uint8List(w * h);
  for (var y = 0; y < h; y++) {
    for (var x = 0; x < w; x++) {
      var v = dilate ? 0 : 1;
      for (var k = -r; k <= r; k++) {
        final xx = x + k;
        final s = (xx < 0 || xx >= w) ? 0 : (m[y * w + xx] != 0 ? 1 : 0);
        if (dilate ? s == 1 : s == 0) {
          v = dilate ? 1 : 0;
          break;
        }
      }
      tmp[y * w + x] = v;
    }
  }
  for (var y = 0; y < h; y++) {
    for (var x = 0; x < w; x++) {
      var v = dilate ? 0 : 1;
      for (var k = -r; k <= r; k++) {
        final yy = y + k;
        final s = (yy < 0 || yy >= h) ? 0 : tmp[yy * w + x];
        if (dilate ? s == 1 : s == 0) {
          v = dilate ? 1 : 0;
          break;
        }
      }
      out[y * w + x] = v;
    }
  }
  return out;
}

Uint8List openMask(Uint8List m, int w, int h, int r) => _morph(_morph(m, w, h, r, false), w, h, r, true);
Uint8List closeMask(Uint8List m, int w, int h, int r) => _morph(_morph(m, w, h, r, true), w, h, r, false);

/// Pixels of [cur] that differ from the empty-sheet reference [ref]: colour
/// change, or a brightness change that is not a soft shadow (a shadow keeps
/// the chromaticity and darkens by at most [maxShadow]).
Uint8List foregroundMask(PlaneImage cur, PlaneImage ref, {double threshold = 38, double maxShadow = 0.45}) {
  final n = cur.width * cur.height;
  final m = Uint8List(n);
  final a = cur.rgb, b = ref.rgb;
  // Auto exposure and white balance drift: estimated on pixels that look
  // like the empty sheet (similar chromaticity), so a big object such as an
  // abacus does not count.
  final gain = List<double>.filled(3, 1);
  final rs = <double>[], gs = <double>[], bs = <double>[];
  for (var i = 0; i < n; i += 5) {
    final j = i * 3;
    final s1 = a[j] + a[j + 1] + a[j + 2] + 1, s0 = b[j] + b[j + 1] + b[j + 2] + 1;
    final chroma = ((a[j] / s1 - b[j] / s0).abs() + (a[j + 1] / s1 - b[j + 1] / s0).abs() +
            (a[j + 2] / s1 - b[j + 2] / s0).abs()) *
        400;
    final ratio = s1 / s0;
    if (chroma > threshold * 0.4 || ratio < 0.75 || ratio > 1.3) continue;
    rs.add((a[j] + 1) / (b[j] + 1));
    gs.add((a[j + 1] + 1) / (b[j + 1] + 1));
    bs.add((a[j + 2] + 1) / (b[j + 2] + 1));
  }
  if (rs.length > n / 5 * 0.15) {
    for (final (c, list) in [(0, rs), (1, gs), (2, bs)]) {
      list.sort();
      gain[c] = list[list.length ~/ 2];
    }
  }
  for (var i = 0; i < n; i++) {
    final j = i * 3;
    final r1 = a[j], g1 = a[j + 1], b1 = a[j + 2];
    final r0 = b[j] * gain[0], g0 = b[j + 1] * gain[1], b0 = b[j + 2] * gain[2];
    final s1 = r1 + g1 + b1 + 1, s0 = r0 + g0 + b0 + 1;
    // chromaticity difference, scaled to 0..255-ish
    final chroma = ((r1 / s1 - r0 / s0).abs() + (g1 / s1 - g0 / s0).abs() + (b1 / s1 - b0 / s0).abs()) * 400;
    final ratio = s1 / s0;
    final lumDiff = (s1 - s0).abs() / 3;
    var fg = chroma > threshold * 0.6;
    if (!fg && lumDiff > threshold * 0.4) {
      // brighter than the sheet, or much darker than a shadow can make it
      fg = ratio > 1.07 || ratio < 1 - maxShadow;
    }
    if (fg) m[i] = 1;
  }
  return m;
}

/// Box blur of a float plane with radius r (separable, edge-clamped).
Float32List boxBlur(Float32List src, int w, int h, int r) {
  final tmp = Float32List(w * h), out = Float32List(w * h);
  final n = 2 * r + 1;
  for (var y = 0; y < h; y++) {
    var s = 0.0;
    for (var k = -r; k <= r; k++) {
      s += src[y * w + k.clamp(0, w - 1)];
    }
    for (var x = 0; x < w; x++) {
      tmp[y * w + x] = s / n;
      s += src[y * w + (x + r + 1).clamp(0, w - 1)] - src[y * w + (x - r).clamp(0, w - 1)];
    }
  }
  for (var x = 0; x < w; x++) {
    var s = 0.0;
    for (var k = -r; k <= r; k++) {
      s += tmp[k.clamp(0, h - 1) * w + x];
    }
    for (var y = 0; y < h; y++) {
      out[y * w + x] = s / n;
      s += tmp[(y + r + 1).clamp(0, h - 1) * w + x] - tmp[(y - r).clamp(0, h - 1) * w + x];
    }
  }
  return out;
}

/// Luminance of a plane raster.
Float32List planeLuma(PlaneImage p) {
  final n = p.width * p.height;
  final out = Float32List(n);
  for (var i = 0; i < n; i++) {
    out[i] = p.lum(i);
  }
  return out;
}
