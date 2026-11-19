import 'dart:math' as math;
import 'dart:typed_data';

import 'aruco_dict.dart';
import 'homography.dart';
import 'image.dart';

/// One detected ArUco marker (DICT_4X4_50).
class Marker {
  Marker(this.id, this.corners, {required this.mirrored, required this.errors});

  final int id;

  /// Image positions of the printed top-left, top-right, bottom-right and
  /// bottom-left corners of the marker (as printed, not as seen).
  final List<Pt> corners;

  /// The marker is seen mirror-imaged (through the back of a translucent
  /// sheet or by an odd number of mirrors).
  final bool mirrored;

  /// Bits corrected (0 or 1).
  final int errors;

  Pt get center =>
      Pt((corners[0].x + corners[1].x + corners[2].x + corners[3].x) / 4,
          (corners[0].y + corners[1].y + corners[2].y + corners[3].y) / 4);

  double get side =>
      (corners[0].dist(corners[1]) + corners[1].dist(corners[2]) + corners[2].dist(corners[3]) + corners[3].dist(corners[0])) / 4;

  @override
  String toString() => 'Marker($id${mirrored ? ', mirrored' : ''}, $center)';
}

/// Finds ArUco 4x4 markers in a grey image. Pure Dart, no OpenCV:
/// adaptive threshold → dark connected components → convex quad → refined
/// edges → 6 x 6 bit grid → dictionary match in all 8 orientations.
class ArucoDetector {
  ArucoDetector({this.minSide = 12, this.windows = const [11, 25, 51], this.allowedIds});

  /// Smallest marker side in pixels.
  final int minSide;

  /// Adaptive threshold window sizes (pixels); several so that small and big
  /// markers are both found.
  final List<int> windows;

  /// Only these ids are reported (null = all 50).
  final Set<int>? allowedIds;

  List<Marker> detect(GrayImage g) {
    final integral = _integral(g);
    final found = <Marker>[];
    for (final w in windows) {
      for (final m in _detectWith(g, integral, w)) {
        final dup = found.any((f) => f.id == m.id && f.center.dist(m.center) < f.side * 0.5);
        if (!dup) found.add(m);
      }
    }
    return found;
  }

  static Uint32List _integral(GrayImage g) {
    final w = g.width + 1;
    final s = Uint32List(w * (g.height + 1));
    for (var y = 0; y < g.height; y++) {
      var row = 0;
      for (var x = 0; x < g.width; x++) {
        row += g.data[y * g.width + x];
        s[(y + 1) * w + x + 1] = s[y * w + x + 1] + row;
      }
    }
    return s;
  }

  Iterable<Marker> _detectWith(GrayImage g, Uint32List integral, int win) sync* {
    final w = g.width, h = g.height, iw = w + 1;
    final r = win ~/ 2;
    // 1. Adaptive threshold: dark = below local mean - 7.
    final dark = Uint8List(w * h);
    for (var y = 0; y < h; y++) {
      final y0 = math.max(0, y - r), y1 = math.min(h, y + r + 1);
      for (var x = 0; x < w; x++) {
        final x0 = math.max(0, x - r), x1 = math.min(w, x + r + 1);
        final sum = integral[y1 * iw + x1] - integral[y0 * iw + x1] - integral[y1 * iw + x0] + integral[y0 * iw + x0];
        final area = (y1 - y0) * (x1 - x0);
        if (g.data[y * w + x] * area < sum - 7 * area) dark[y * w + x] = 1;
      }
    }
    // 2. Connected components (4-connected), tracked by row/column extents.
    final label = Int32List(w * h);
    final stack = Int32List(w * h);
    var next = 0;
    for (var start = 0; start < w * h; start++) {
      if (dark[start] == 0 || label[start] != 0) continue;
      next++;
      var sp = 0;
      stack[sp++] = start;
      label[start] = next;
      var minX = w, maxX = 0, minY = h, maxY = 0, count = 0;
      final pixels = <int>[];
      while (sp > 0) {
        final p = stack[--sp];
        pixels.add(p);
        count++;
        final px = p % w, py = p ~/ w;
        if (px < minX) minX = px;
        if (px > maxX) maxX = px;
        if (py < minY) minY = py;
        if (py > maxY) maxY = py;
        if (px > 0 && dark[p - 1] == 1 && label[p - 1] == 0) {
          label[p - 1] = next;
          stack[sp++] = p - 1;
        }
        if (px < w - 1 && dark[p + 1] == 1 && label[p + 1] == 0) {
          label[p + 1] = next;
          stack[sp++] = p + 1;
        }
        if (py > 0 && dark[p - w] == 1 && label[p - w] == 0) {
          label[p - w] = next;
          stack[sp++] = p - w;
        }
        if (py < h - 1 && dark[p + w] == 1 && label[p + w] == 0) {
          label[p + w] = next;
          stack[sp++] = p + w;
        }
      }
      final bw = maxX - minX + 1, bh = maxY - minY + 1;
      if (bw < minSide || bh < minSide) continue;
      if (bw > w * 0.6 || bh > h * 0.6) continue;
      if (bw > 4 * bh || bh > 4 * bw) continue;
      // The border ring alone is ~5/9 of the marker's area; the bits add more.
      if (count < bw * bh * 0.2) continue;
      if (minX == 0 || minY == 0 || maxX == w - 1 || maxY == h - 1) continue;
      final m = _marker(g, pixels, w, minX, maxX, minY, maxY);
      if (m != null) yield m;
    }
  }

  Marker? _marker(GrayImage g, List<int> pixels, int w, int minX, int maxX, int minY, int maxY) {
    // Outer boundary points: per row and per column extremes.
    final rows = maxY - minY + 1, cols = maxX - minX + 1;
    final rMin = Int32List(rows)..fillRange(0, rows, 1 << 30);
    final rMax = Int32List(rows)..fillRange(0, rows, -1);
    final cMin = Int32List(cols)..fillRange(0, cols, 1 << 30);
    final cMax = Int32List(cols)..fillRange(0, cols, -1);
    for (final p in pixels) {
      final x = p % w, y = p ~/ w;
      final ry = y - minY, cx = x - minX;
      if (x < rMin[ry]) rMin[ry] = x;
      if (x > rMax[ry]) rMax[ry] = x;
      if (y < cMin[cx]) cMin[cx] = y;
      if (y > cMax[cx]) cMax[cx] = y;
    }
    final boundary = <Pt>[];
    for (var i = 0; i < rows; i++) {
      if (rMax[i] < 0) continue;
      boundary.add(Pt(rMin[i] - 0.5, (minY + i).toDouble()));
      boundary.add(Pt(rMax[i] + 0.5, (minY + i).toDouble()));
    }
    for (var i = 0; i < cols; i++) {
      if (cMax[i] < 0) continue;
      boundary.add(Pt((minX + i).toDouble(), cMin[i] - 0.5));
      boundary.add(Pt((minX + i).toDouble(), cMax[i] + 0.5));
    }
    final hull = _convexHull(boundary);
    if (hull.length < 4) return null;
    final quad = _quadFromHull(hull);
    if (quad == null) return null;
    final hullArea = _area(hull), quadArea = _area(quad);
    if (quadArea < hullArea * 0.88) return null; // not a quadrilateral
    for (var i = 0; i < 4; i++) {
      final s = quad[i].dist(quad[(i + 1) % 4]);
      if (s < minSide * 0.8) return null;
    }
    final refined = _refine(quad, boundary) ?? quad;
    return _decode(g, refined);
  }

  /// Line fit through boundary points near each edge, corners = intersections.
  List<Pt>? _refine(List<Pt> q, List<Pt> boundary) {
    final lines = <List<double>>[];
    for (var i = 0; i < 4; i++) {
      final a = q[i], b = q[(i + 1) % 4];
      final len = a.dist(b);
      final nx = -(b.y - a.y) / len, ny = (b.x - a.x) / len;
      var sx = 0.0, sy = 0.0, sxx = 0.0, syy = 0.0, sxy = 0.0, n = 0;
      for (final p in boundary) {
        final t = ((p.x - a.x) * (b.x - a.x) + (p.y - a.y) * (b.y - a.y)) / (len * len);
        if (t < 0.12 || t > 0.88) continue;
        final d = (p.x - a.x) * nx + (p.y - a.y) * ny;
        if (d.abs() > math.max(1.5, len * 0.04)) continue;
        sx += p.x;
        sy += p.y;
        sxx += p.x * p.x;
        syy += p.y * p.y;
        sxy += p.x * p.y;
        n++;
      }
      if (n < 4) return null;
      final mx = sx / n, my = sy / n;
      final cxx = sxx / n - mx * mx, cyy = syy / n - my * my, cxy = sxy / n - mx * my;
      final ang = 0.5 * math.atan2(2 * cxy, cxx - cyy); // direction of the line
      final dx = math.cos(ang), dy = math.sin(ang);
      lines.add([mx, my, dx, dy]);
    }
    final out = <Pt>[];
    for (var i = 0; i < 4; i++) {
      final l1 = lines[(i + 3) % 4], l2 = lines[i];
      final det = l1[2] * (-l2[3]) - l1[3] * (-l2[2]);
      if (det.abs() < 1e-6) return null;
      final rx = l2[0] - l1[0], ry = l2[1] - l1[1];
      final t = (rx * (-l2[3]) - ry * (-l2[2])) / det;
      final p = Pt(l1[0] + t * l1[2], l1[1] + t * l1[3]);
      if (p.dist(q[i]) > math.max(3.0, q[i].dist(q[(i + 1) % 4]) * 0.15)) return null;
      out.add(p);
    }
    return out;
  }

  // Dihedral transforms of the unit square: printed (x, y) → seen (x, y).
  static final List<Pt Function(double, double)> _transforms = [
    (x, y) => Pt(x, y),
    (x, y) => Pt(1 - y, x),
    (x, y) => Pt(1 - x, 1 - y),
    (x, y) => Pt(y, 1 - x),
    (x, y) => Pt(1 - x, y),
    (x, y) => Pt(x, 1 - y),
    (x, y) => Pt(y, x),
    (x, y) => Pt(1 - y, 1 - x),
  ];

  Marker? _decode(GrayImage g, List<Pt> quad) {
    // Make the quad clockwise in image coordinates (y down).
    if (_signedArea(quad) < 0) quad = [quad[0], quad[3], quad[2], quad[1]];
    final hm = Homography.fit(const [Pt(0, 0), Pt(1, 0), Pt(1, 1), Pt(0, 1)], quad);
    if (hm == null) return null;
    final cells = Float64List(36);
    var lo = 255.0, hi = 0.0;
    for (var r = 0; r < 6; r++) {
      for (var c = 0; c < 6; c++) {
        var s = 0.0;
        for (final dy in const [-0.22, 0.0, 0.22]) {
          for (final dx in const [-0.22, 0.0, 0.22]) {
            final p = hm.map(Pt((c + 0.5 + dx) / 6, (r + 0.5 + dy) / 6));
            s += g.sample(p.x, p.y);
          }
        }
        s /= 9;
        cells[r * 6 + c] = s;
        if (s < lo) lo = s;
        if (s > hi) hi = s;
      }
    }
    if (hi - lo < 30) return null;
    // Threshold: Otsu over the 36 cell values.
    final t = _otsu(cells);
    var borderErr = 0;
    for (var i = 0; i < 6; i++) {
      for (final k in [i, 30 + i, i * 6, i * 6 + 5]) {
        if (cells[k] > t) borderErr++;
      }
    }
    if (borderErr > 2) return null;
    final seen = List<int>.generate(16, (k) => cells[(k ~/ 4 + 1) * 6 + k % 4 + 1] > t ? 1 : 0);
    Marker? best;
    for (var ti = 0; ti < 8; ti++) {
      final tf = _transforms[ti];
      var code = 0;
      for (var r = 0; r < 4; r++) {
        for (var c = 0; c < 4; c++) {
          final s = tf((c + 0.5) / 4, (r + 0.5) / 4);
          final sc = (s.x * 4).floor(), sr = (s.y * 4).floor();
          code = (code << 1) | seen[sr * 4 + sc];
        }
      }
      for (var id = 0; id < aruco4x4x50.length; id++) {
        if (allowedIds != null && !allowedIds!.contains(id)) continue;
        final d = _popcount(code ^ aruco4x4x50[id]);
        if (d > 1) continue;
        if (best != null && best.errors <= d) continue;
        // Image corner of each printed corner.
        Pt corner(double x, double y) {
          final s = tf(x, y);
          final k = s.x < 0.5 ? (s.y < 0.5 ? 0 : 3) : (s.y < 0.5 ? 1 : 2);
          return quad[k];
        }

        best = Marker(id, [corner(0, 0), corner(1, 0), corner(1, 1), corner(0, 1)], mirrored: ti >= 4, errors: d);
      }
    }
    return best;
  }

  static int _popcount(int v) {
    var c = 0;
    while (v != 0) {
      v &= v - 1;
      c++;
    }
    return c;
  }

  static double _otsu(Float64List v) {
    final s = List<double>.of(v)..sort();
    var best = (s.first + s.last) / 2, bestVar = -1.0;
    for (var i = 1; i < s.length; i++) {
      final a = s.sublist(0, i), b = s.sublist(i);
      final ma = a.reduce((x, y) => x + y) / a.length, mb = b.reduce((x, y) => x + y) / b.length;
      final bv = a.length * b.length * (ma - mb) * (ma - mb);
      if (bv > bestVar) {
        bestVar = bv;
        best = (s[i - 1] + s[i]) / 2;
      }
    }
    return best;
  }

  static List<Pt> _convexHull(List<Pt> pts) {
    final p = List<Pt>.of(pts)..sort((a, b) => a.x != b.x ? a.x.compareTo(b.x) : a.y.compareTo(b.y));
    if (p.length < 3) return p;
    double cross(Pt o, Pt a, Pt b) => (a.x - o.x) * (b.y - o.y) - (a.y - o.y) * (b.x - o.x);
    final lower = <Pt>[];
    for (final q in p) {
      while (lower.length >= 2 && cross(lower[lower.length - 2], lower.last, q) <= 0) {
        lower.removeLast();
      }
      lower.add(q);
    }
    final upper = <Pt>[];
    for (final q in p.reversed) {
      while (upper.length >= 2 && cross(upper[upper.length - 2], upper.last, q) <= 0) {
        upper.removeLast();
      }
      upper.add(q);
    }
    lower.removeLast();
    upper.removeLast();
    return [...lower, ...upper];
  }

  /// The 4 hull points with the largest quadrilateral area (greedy: farthest
  /// pair as a diagonal, then the farthest point on each side of it).
  static List<Pt>? _quadFromHull(List<Pt> hull) {
    var bi = 0, bj = 0;
    var bd = -1.0;
    for (var i = 0; i < hull.length; i++) {
      for (var j = i + 1; j < hull.length; j++) {
        final d = hull[i].dist(hull[j]);
        if (d > bd) {
          bd = d;
          bi = i;
          bj = j;
        }
      }
    }
    final a = hull[bi], c = hull[bj];
    Pt? b, d;
    var db = 0.0, dd = 0.0;
    for (final p in hull) {
      final s = (c.x - a.x) * (p.y - a.y) - (c.y - a.y) * (p.x - a.x);
      if (s > db) {
        db = s;
        b = p;
      }
      if (-s > dd) {
        dd = -s;
        d = p;
      }
    }
    if (b == null || d == null) return null;
    return [a, b, c, d];
  }

  static double _signedArea(List<Pt> p) {
    var s = 0.0;
    for (var i = 0; i < p.length; i++) {
      final a = p[i], b = p[(i + 1) % p.length];
      s += a.x * b.y - b.x * a.y;
    }
    return s / 2;
  }

  static double _area(List<Pt> p) => _signedArea(p).abs();
}
