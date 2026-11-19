import 'dart:math' as math;

import 'blobs.dart';
import 'board.dart';
import 'homography.dart';
import 'image.dart';

enum CounterColor { red, blue, other }

/// One round counter (Wendeplättchen) on the sheet.
class Counter {
  Counter(this.center, this.diameterMm, this.color);
  final Pt center;
  final double diameterMm;
  final CounterColor color;
  @override
  String toString() => 'Counter(${color.name} @$center ⌀${diameterMm.toStringAsFixed(0)})';
}

class CountersResult {
  CountersResult(this.counters);
  final List<Counter> counters;
  int get red => counters.where((c) => c.color == CounterColor.red).length;
  int get blue => counters.where((c) => c.color == CounterColor.blue).length;
}

/// Finds round two-colour counters (red / blue, 15-30 mm) on a normalised
/// field: foreground against the empty sheet, round blobs, colour by the
/// dominant channel. Counters that touch form one blob; its area says how
/// many.
class CounterReader {
  CounterReader({this.minDiameterMm = 12, this.maxDiameterMm = 32});

  final double minDiameterMm, maxDiameterMm;

  CountersResult read(PlaneImage cur, PlaneImage ref) {
    final s = cur.scale, w = cur.width, h = cur.height;
    var mask = foregroundMask(cur, ref);
    mask = openMask(mask, w, h, math.max(1, (1.0 * s).round()));
    final minArea = math.pi / 4 * minDiameterMm * minDiameterMm * s * s;
    final maxSingle = math.pi / 4 * maxDiameterMm * maxDiameterMm * s * s;
    final out = <Counter>[];
    final blobs = findBlobs(mask, w, h, minArea: (minArea * 0.8).round());
    // Typical single-counter area: median of the round blobs.
    final minD = minDiameterMm * s;
    // Round = an ellipse fills π/4 of its box (a square or a rod fills it all).
    bool isRound(Blob b, ({double angle, double length, double thickness, double lo, double hi, double wlo, double whi}) ax) {
      final fill = b.area / (math.pi / 4 * ax.length * ax.thickness);
      return ax.length < ax.thickness * 1.25 && fill > 0.82 && fill < 1.12 && ax.thickness >= minD;
    }

    final single = <double>[];
    for (final b in blobs) {
      final ax = b.axes();
      if (isRound(b, ax) && b.area <= maxSingle) single.add(b.area.toDouble());
    }
    single.sort();
    final typical = single.isEmpty ? null : single[single.length ~/ 2];
    for (final b in blobs) {
      final ax = b.axes();
      final round = isRound(b, ax);
      var n = 1;
      if (!round) {
        // Several counters in a row: as thick as one counter, scalloped
        // edges (a rod is thinner and fills its box).
        if (typical == null || ax.thickness < minD || ax.thickness < math.sqrt(typical) * 0.8) continue;
        if (!b.scalloped) continue;
        n = (b.area / typical).round();
        if (n < 2 || n > 10) continue;
      } else if (b.area > maxSingle) {
        continue;
      }
      // Colour from the blob's pixels.
      var r = 0.0, g = 0.0, bb = 0.0;
      for (final p in b.pixels) {
        r += cur.rgb[p * 3];
        g += cur.rgb[p * 3 + 1];
        bb += cur.rgb[p * 3 + 2];
      }
      final c = Rgb(r / b.area, g / b.area, bb / b.area);
      final color = c.r > c.g * 1.4 && c.r > c.b * 1.4
          ? CounterColor.red
          : (c.b > c.r * 1.25 && c.b > c.g * 1.05 ? CounterColor.blue : CounterColor.other);
      final (cx, cy) = b.centroid;
      final ca = math.cos(ax.angle), sa = math.sin(ax.angle);
      final d = math.sqrt(b.area / n / math.pi) * 2 / s;
      for (var k = 0; k < n; k++) {
        final t = n == 1 ? 0.0 : ax.lo + ax.length * (k + 0.5) / n;
        out.add(Counter(Pt(cur.xMm(cx + t * ca), cur.yMm(cy + t * sa)), d, color));
      }
    }
    return CountersResult(out);
  }
}
