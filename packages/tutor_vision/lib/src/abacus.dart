import 'dart:math' as math;
import 'dart:typed_data';

import 'blobs.dart';
import 'image.dart';

/// Bead state of a real abacus lying on the sheet.
class AbacusReading {
  AbacusReading(this.digits, this.confidence, this.rowCentersMm);

  /// Beads on the counted side per wire, row 0 = units (the bottom wire as
  /// the child sees it); null where the wire was not seen.
  final List<int?> digits;

  /// Per wire 0..1: how clearly the beads split into two groups.
  final List<double> confidence;

  /// Sheet y (mm) of each wire.
  final List<double> rowCentersMm;

  /// The number shown (null if a wire is unreadable).
  int? get value {
    var total = 0, place = 1;
    for (final d in digits) {
      if (d == null) return null;
      total += d * place;
      place *= 10;
    }
    return total;
  }

  @override
  String toString() => 'Abacus(${digits.reversed.map((d) => d ?? '?').join(' ')} = $value)';
}

/// Reads bead positions on each wire of an abacus lying flat on a sheet,
/// wires along the sheet's long side. Works on the normalised field and the
/// empty-sheet reference: the frame bars are the columns / rows that are
/// almost fully covered, wires are equally spaced between the top and bottom
/// bars, and on each wire the widest gap splits the counted beads from the
/// rest (as in the screen abacus).
class AbacusReader {
  AbacusReader({this.rows = 10, this.beadsPerRow = 10, this.countedLeft = true});

  final int rows;
  final int beadsPerRow;

  /// Counted beads are the ones pushed to the left (as on the screen).
  final bool countedLeft;

  /// Last frame geometry, for the lab screen.
  String debugInfo = "";

  AbacusReading? read(PlaneImage cur, PlaneImage ref) {
    final w = cur.width, h = cur.height, s = cur.scale;
    var mask = foregroundMask(cur, ref);
    mask = openMask(mask, w, h, math.max(1, (0.5 * s).round()));
    final blobs = findBlobs(mask, w, h, minArea: (60 * s * s).round());
    if (blobs.isEmpty) return null;
    var x0 = w, x1 = 0, y0 = h, y1 = 0;
    final keep = Uint8List(w * h);
    for (final b in blobs) {
      for (final p in b.pixels) {
        keep[p] = 1;
        final x = p % w, y = p ~/ w;
        if (x < x0) x0 = x;
        if (x > x1) x1 = x;
        if (y < y0) y0 = y;
        if (y > y1) y1 = y;
      }
    }
    if (x1 - x0 < 40 * s || y1 - y0 < 30 * s) return null;
    double colOcc(int x, int ya, int yb) {
      var n = 0;
      for (var y = ya; y < yb; y++) {
        n += keep[y * w + x];
      }
      return n / math.max(1, yb - ya);
    }

    double rowOcc(int y, int xa, int xb) {
      var n = 0;
      for (var x = xa; x < xb; x++) {
        n += keep[y * w + x];
      }
      return n / math.max(1, xb - xa);
    }

    // Side bars, then top and bottom bars: a run of almost fully covered
    // columns / rows near the edge (a few ragged lines before it are skipped).
    int barEnd(int start, int dir, int limit, double Function(int) occ) {
      var i = start;
      final skip = (4 * s).round();
      var k = 0;
      while (k < skip && i != limit && occ(i) <= 0.8) {
        i += dir;
        k++;
      }
      if (occ(i) <= 0.8) return start;
      while (i != limit && occ(i) > 0.8) {
        i += dir;
      }
      return i;
    }

    final xl = barEnd(x0, 1, x1, (x) => colOcc(x, y0, y1 + 1));
    final xr = barEnd(x1, -1, xl, (x) => colOcc(x, y0, y1 + 1)) + 1;
    final yt = barEnd(y0, 1, y1, (y) => rowOcc(y, xl, xr));
    final yb = barEnd(y1, -1, yt, (y) => rowOcc(y, xl, xr)) + 1;
    debugInfo = "bbox $x0-$x1 x $y0-$y1  inner $xl-$xr x $yt-$yb";
    if (xr - xl < 30 * s || yb - yt < rows * 4 * s) return null;

    final occ = Float64List(h);
    for (var y = yt; y < yb; y++) {
      occ[y] = rowOcc(y, xl, xr);
    }
    final pitch = (yb - yt) / rows;
    final digits = List<int?>.filled(rows, null);
    final conf = List<double>.filled(rows, 0);
    final centers = List<double>.filled(rows, 0);
    for (var k = 0; k < rows; k++) {
      // k = 0 is the top wire in the picture; row index 0 is the bottom one.
      var c = (yt + pitch * (k + 0.5)).round();
      var best = -1.0;
      final r = (pitch * 0.3).round();
      for (var y = math.max(yt, c - r); y < math.min(yb, c + r + 1); y++) {
        var v = 0.0;
        for (var d = -1; d <= 1; d++) {
          v += occ[(y + d).clamp(yt, yb - 1)];
        }
        if (v > best) {
          best = v;
          c = y;
        }
      }
      final half = math.max(1, (pitch * 0.2).round());
      final ya = math.max(yt, c - half), yb2 = math.min(yb, c + half + 1);
      final filled = <bool>[for (var x = xl; x < xr; x++) colOcc(x, ya, yb2) > 0.5];
      final row = rows - 1 - k;
      centers[row] = cur.yMm(c);
      // Segments of beads and the gaps around them (including the frame ends).
      final gaps = <(int, int)>[]; // (start, length) in pixels from xl
      var occTotal = 0;
      var i = 0;
      while (i < filled.length) {
        var j = i;
        while (j < filled.length && filled[j] == filled[i]) {
          j++;
        }
        if (filled[i]) {
          occTotal += j - i;
        } else {
          gaps.add((i, j - i));
        }
        i = j;
      }
      if (occTotal < 3 * s * beadsPerRow * 0.5) continue; // wire not seen
      if (gaps.isEmpty) {
        // beads fill the wire: cannot tell
        continue;
      }
      gaps.sort((a, b) => b.$2.compareTo(a.$2));
      final split = gaps.first;
      var left = 0;
      for (var x = 0; x < split.$1; x++) {
        if (filled[x]) left++;
      }
      final countedOcc = countedLeft ? left : occTotal - left;
      digits[row] = (beadsPerRow * countedOcc / occTotal).round();
      final second = gaps.length > 1 ? gaps[1].$2 : 0;
      conf[row] = (split.$2 - second) / math.max(1, split.$2);
    }
    return AbacusReading(digits, conf, centers);
  }
}
