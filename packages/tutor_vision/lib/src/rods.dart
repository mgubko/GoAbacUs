import 'dart:math' as math;
import 'dart:typed_data';

import 'blobs.dart';
import 'board.dart';
import 'homography.dart';
import 'image.dart';

/// One Cuisenaire-type rod (1 cm square section, n cm long, colour per n).
class Rod {
  Rod({
    required this.value,
    required this.byColor,
    required this.byLength,
    required this.lengthMm,
    required this.center,
    required this.angle,
    required this.train,
  });

  /// The decision: 1..10.
  final int value;

  /// What the colour alone says (0 = unknown) and what the length alone says.
  final int byColor, byLength;
  final double lengthMm;

  /// Centre on the sheet (mm, y up) and direction (radians, sheet frame).
  final Pt center;
  final double angle;

  /// Rods laid end to end in one line share a train number.
  final int train;

  /// Colour and length agree.
  bool get sure => byColor == value && byLength == value;

  @override
  String toString() => 'Rod($value${sure ? '' : '?'} c$byColor l$byLength ${lengthMm.toStringAsFixed(0)}mm @$center t$train)';
}

/// A row of rods end to end ("Zug"): their sum is what the child built.
class Train {
  Train(this.rods);
  final List<Rod> rods;
  int get sum => rods.fold(0, (s, r) => s + r.value);
  @override
  String toString() => rods.map((r) => r.value).join('+');
}

class RodsResult {
  RodsResult(this.rods, this.trains);
  final List<Rod> rods;
  final List<Train> trains;
}

/// Finds rods on a normalised field (see [BoardLocator.warp]): foreground
/// against the empty-field reference, split into 1 cm strips, colour per mm
/// along each strip, runs of one colour → rods; length checks the colour.
class RodReader {
  RodReader(this.colors, {this.rodWidthMm = 10, this.lengthWeight = 6});

  final ColorCalibration colors;
  final double rodWidthMm;

  /// Colour-distance units per mm of length error.
  final double lengthWeight;

  RodsResult read(PlaneImage cur, PlaneImage ref) {
    final s = cur.scale;
    final w = cur.width, h = cur.height;
    var mask = foregroundMask(cur, ref);
    mask = openMask(mask, w, h, math.max(1, (1.0 * s).round()));
    final blobs = findBlobs(mask, w, h, minArea: (40 * s * s).round());
    final rods = <Rod>[];
    final trains = <Train>[];
    for (final b in blobs) {
      final ax = b.axes();
      if (ax.length < 6 * s) continue;
      final strips = math.max(1, (ax.thickness / (rodWidthMm * s)).round());
      final (cx, cy) = b.centroid;
      final ca = math.cos(ax.angle), sa = math.sin(ax.angle);
      final stripW = ax.thickness / strips;
      for (var k = 0; k < strips; k++) {
        final off = ax.wlo + stripW * (k + 0.5);
        final classes = <int>[];
        final samples = <Rgb?>[];
        for (var t = ax.lo + s * 0.5; t < ax.hi; t += s) {
          var r = 0.0, g = 0.0, bb = 0.0, n = 0;
          for (final dq in const [-0.3, -0.15, 0.0, 0.15, 0.3]) {
            final q = off + dq * stripW;
            final x = (cx + t * ca - q * sa).round(), y = (cy + t * sa + q * ca).round();
            if (x < 0 || y < 0 || x >= w || y >= h) continue;
            final i = y * w + x;
            if (mask[i] == 0) continue;
            r += cur.rgb[i * 3];
            g += cur.rgb[i * 3 + 1];
            bb += cur.rgb[i * 3 + 2];
            n++;
          }
          final c = n < 2 ? null : Rgb(r / n, g / n, bb / n);
          samples.add(c);
          classes.add(c == null ? 0 : classify(c));
        }
        final smooth = _modeFilter(classes, 2);
        final runs = _runs(smooth);
        final trainRods = <Rod>[];
        for (final run in runs) {
          if (run.$1 == 0) continue;
          final lengthMm = run.$3.toDouble(); // samples are 1 mm apart
          if (lengthMm < 6) continue;
          // Mean colour of the run's middle (ends mix with the neighbours).
          var r = 0.0, g = 0.0, bb = 0.0, n = 0;
          final trim = math.min(3, run.$3 ~/ 4);
          for (var k = run.$2 + trim; k < run.$2 + run.$3 - trim; k++) {
            final c = samples[k];
            if (c == null) continue;
            r += c.r;
            g += c.g;
            bb += c.b;
            n++;
          }
          if (n == 0) continue;
          final mean = Rgb(r / n, g / n, bb / n);
          final colorVal = classify(mean);
          // Colour and length together: n rods of value v should be 10·v·n mm.
          var bestV = colorVal, bestN = 1;
          var bestCost = double.infinity;
          for (var v = 1; v <= 10; v++) {
            final cd = colorDistance(mean, colors.references[v + 1]);
            final cnt = math.max(1, (lengthMm / (10 * v)).round());
            final cost = cd + lengthWeight * (lengthMm - 10 * v * cnt).abs() + (cnt - 1) * 4;
            if (cost < bestCost) {
              bestCost = cost;
              bestV = v;
              bestN = cnt;
            }
          }
          final each = lengthMm / bestN;
          for (var j = 0; j < bestN; j++) {
            final tMid = ax.lo + s * 0.5 + (run.$2 + each * (j + 0.5) - 0.5) * s;
            final px = cx + tMid * ca - off * sa, py = cy + tMid * sa + off * ca;
            trainRods.add(Rod(
              value: bestV,
              byColor: colorVal,
              byLength: (each / 10).round().clamp(1, 10),
              lengthMm: each,
              center: Pt(cur.xMm(px), cur.yMm(py)),
              angle: -ax.angle,
              train: trains.length,
            ));
          }
        }
        if (trainRods.isEmpty) continue;
        rods.addAll(trainRods);
        trains.add(Train(trainRods));
      }
    }
    return _joinTrains(trains);
  }

  /// Rods that touch end to end but fell into separate blobs (a dark seam
  /// between them) still form one train: same line, ends within 4 mm.
  RodsResult _joinTrains(List<Train> trains) {
    final list = [for (final t in trains) List<Rod>.of(t.rods)];
    // A single 1 cm cube has no direction of its own: it takes the other's.
    bool cube(List<Rod> rs) => rs.length == 1 && rs.first.lengthMm < 15;
    (Pt, Pt, Pt) ends(List<Rod> rs, [Pt? dir]) {
      final a = rs.first, b = rs.last;
      final d = dir ?? Pt(math.cos(a.angle), math.sin(a.angle));
      final p0 = a.center - d * (a.lengthMm / 2), p1 = b.center + d * (b.lengthMm / 2);
      return (p0, p1, d);
    }

    var merged = true;
    while (merged) {
      merged = false;
      outer:
      for (var i = 0; i < list.length; i++) {
        for (var j = 0; j < list.length; j++) {
          if (i == j) continue;
          if (cube(list[i]) && cube(list[j])) continue;
          var (a0, a1, da) = ends(list[i]);
          if (cube(list[i])) (a0, a1, da) = ends(list[i], ends(list[j]).$3);
          final (b0, b1, db) = ends(list[j], cube(list[j]) ? da : null);
          final dot = da.x * db.x + da.y * db.y;
          if (dot.abs() < math.cos(8 * math.pi / 180)) continue;
          // Orient j like i.
          final bStart = dot > 0 ? b0 : b1;
          if (a1.dist(bStart) > 4) continue;
          final rodsJ = dot > 0 ? list[j] : list[j].reversed.toList();
          list[i].addAll(rodsJ);
          list.removeAt(j);
          merged = true;
          break outer;
        }
      }
    }
    final rods = <Rod>[], out = <Train>[];
    for (var k = 0; k < list.length; k++) {
      final rs = [
        for (final r in list[k])
          Rod(
            value: r.value,
            byColor: r.byColor,
            byLength: r.byLength,
            lengthMm: r.lengthMm,
            center: r.center,
            angle: r.angle,
            train: k,
          )
      ];
      rods.addAll(rs);
      out.add(Train(rs));
    }
    return RodsResult(rods, out);
  }

  /// Nearest rod colour 1..10 (references from the strip).
  int classify(Rgb c) {
    var best = 1;
    var bd = double.infinity;
    for (var v = 1; v <= 10; v++) {
      final d = colorDistance(c, colors.references[v + 1]);
      if (d < bd) {
        bd = d;
        best = v;
      }
    }
    return best;
  }

  static double colorDistance(Rgb a, Rgb b) {
    final sa = a.r + a.g + a.b + 1, sb = b.r + b.g + b.b + 1;
    final dl = (a.lum - b.lum).abs();
    // chromaticity matters less for dark colours (noise)
    final wc = math.min(1.0, math.min(a.lum, b.lum) / 60 + 0.25);
    final dc = (a.r / sa - b.r / sb).abs() + (a.g / sa - b.g / sb).abs() + (a.b / sa - b.b / sb).abs();
    return dl + 500 * wc * dc;
  }

  static List<int> _modeFilter(List<int> c, int r) {
    final out = List<int>.filled(c.length, 0);
    final counts = Int32List(11);
    for (var i = 0; i < c.length; i++) {
      counts.fillRange(0, 11, 0);
      for (var k = math.max(0, i - r); k <= math.min(c.length - 1, i + r); k++) {
        counts[c[k]]++;
      }
      var best = c[i];
      for (var v = 0; v <= 10; v++) {
        if (counts[v] > counts[best]) best = v;
      }
      out[i] = best;
    }
    return out;
  }

  /// (class, start, length) runs.
  static List<(int, int, int)> _runs(List<int> c) {
    final out = <(int, int, int)>[];
    var i = 0;
    while (i < c.length) {
      var j = i;
      while (j < c.length && c[j] == c[i]) {
        j++;
      }
      out.add((c[i], i, j - i));
      i = j;
    }
    return out;
  }
}
