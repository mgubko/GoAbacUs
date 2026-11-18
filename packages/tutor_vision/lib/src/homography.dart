import 'dart:math' as math;

/// A 2-D point.
class Pt {
  const Pt(this.x, this.y);
  final double x, y;
  Pt operator +(Pt o) => Pt(x + o.x, y + o.y);
  Pt operator -(Pt o) => Pt(x - o.x, y - o.y);
  Pt operator *(double k) => Pt(x * k, y * k);
  double dist(Pt o) => math.sqrt((x - o.x) * (x - o.x) + (y - o.y) * (y - o.y));
  @override
  String toString() => '(${x.toStringAsFixed(1)}, ${y.toStringAsFixed(1)})';
}

/// A plane projective transform (3 x 3, row-major, h[8] normalised to 1).
class Homography {
  Homography(this.h);
  final List<double> h;

  Pt map(Pt p) {
    final w = h[6] * p.x + h[7] * p.y + h[8];
    return Pt((h[0] * p.x + h[1] * p.y + h[2]) / w, (h[3] * p.x + h[4] * p.y + h[5]) / w);
  }

  /// Sign of the local orientation at [p]: +1 keeps the turning direction,
  /// -1 flips it (a mirror, or y up mapped to y down).
  int orientationAt(Pt p, [double d = 1]) {
    final o = map(p), a = map(Pt(p.x + d, p.y)), b = map(Pt(p.x, p.y + d));
    final c = (a.x - o.x) * (b.y - o.y) - (a.y - o.y) * (b.x - o.x);
    return c >= 0 ? 1 : -1;
  }

  Homography inverse() {
    final a = h;
    final inv = [
      a[4] * a[8] - a[5] * a[7], a[2] * a[7] - a[1] * a[8], a[1] * a[5] - a[2] * a[4],
      a[5] * a[6] - a[3] * a[8], a[0] * a[8] - a[2] * a[6], a[2] * a[3] - a[0] * a[5],
      a[3] * a[7] - a[4] * a[6], a[1] * a[6] - a[0] * a[7], a[0] * a[4] - a[1] * a[3],
    ];
    return Homography([for (final v in inv) v / inv[8]]);
  }

  /// Least-squares homography mapping [src] to [dst] (at least 4 pairs),
  /// normalised DLT, solved by the smallest eigenvector of AᵀA.
  static Homography? fit(List<Pt> src, List<Pt> dst) {
    if (src.length < 4 || src.length != dst.length) return null;
    final ns = _norm(src), nd = _norm(dst);
    final ata = List<double>.filled(81, 0);
    void add(List<double> r) {
      for (var i = 0; i < 9; i++) {
        if (r[i] == 0) continue;
        for (var j = 0; j < 9; j++) {
          ata[i * 9 + j] += r[i] * r[j];
        }
      }
    }

    for (var k = 0; k < src.length; k++) {
      final x = (src[k].x - ns[0]) * ns[2], y = (src[k].y - ns[1]) * ns[2];
      final u = (dst[k].x - nd[0]) * nd[2], v = (dst[k].y - nd[1]) * nd[2];
      add([x, y, 1, 0, 0, 0, -u * x, -u * y, -u]);
      add([0, 0, 0, x, y, 1, -v * x, -v * y, -v]);
    }
    final e = _smallestEigenvector(ata, 9);
    // H = Td⁻¹ · Hn · Ts
    final ts = [ns[2], 0.0, -ns[0] * ns[2], 0.0, ns[2], -ns[1] * ns[2], 0.0, 0.0, 1.0];
    final tdi = [1 / nd[2], 0.0, nd[0], 0.0, 1 / nd[2], nd[1], 0.0, 0.0, 1.0];
    final m = _mul(tdi, _mul(e, ts));
    if (m[8].abs() < 1e-12) return null;
    return Homography([for (final v in m) v / m[8]]);
  }

  static List<double> _norm(List<Pt> p) {
    var cx = 0.0, cy = 0.0;
    for (final q in p) {
      cx += q.x;
      cy += q.y;
    }
    cx /= p.length;
    cy /= p.length;
    var d = 0.0;
    for (final q in p) {
      d += math.sqrt((q.x - cx) * (q.x - cx) + (q.y - cy) * (q.y - cy));
    }
    d /= p.length;
    return [cx, cy, d > 0 ? math.sqrt2 / d : 1];
  }

  static List<double> _mul(List<double> a, List<double> b) {
    final r = List<double>.filled(9, 0);
    for (var i = 0; i < 3; i++) {
      for (var j = 0; j < 3; j++) {
        var s = 0.0;
        for (var k = 0; k < 3; k++) {
          s += a[i * 3 + k] * b[k * 3 + j];
        }
        r[i * 3 + j] = s;
      }
    }
    return r;
  }

  /// Cyclic Jacobi eigen decomposition of a symmetric n x n matrix; returns
  /// the eigenvector of the smallest eigenvalue.
  static List<double> _smallestEigenvector(List<double> a0, int n) {
    final a = List<double>.of(a0);
    final v = List<double>.filled(n * n, 0);
    for (var i = 0; i < n; i++) {
      v[i * n + i] = 1;
    }
    for (var sweep = 0; sweep < 60; sweep++) {
      var off = 0.0;
      for (var p = 0; p < n; p++) {
        for (var q = p + 1; q < n; q++) {
          off += a[p * n + q] * a[p * n + q];
        }
      }
      if (off < 1e-22) break;
      for (var p = 0; p < n; p++) {
        for (var q = p + 1; q < n; q++) {
          final apq = a[p * n + q];
          if (apq.abs() < 1e-30) continue;
          final theta = (a[q * n + q] - a[p * n + p]) / (2 * apq);
          final t = (theta >= 0 ? 1 : -1) / (theta.abs() + math.sqrt(theta * theta + 1));
          final c = 1 / math.sqrt(t * t + 1), s = t * c;
          for (var k = 0; k < n; k++) {
            final akp = a[k * n + p], akq = a[k * n + q];
            a[k * n + p] = c * akp - s * akq;
            a[k * n + q] = s * akp + c * akq;
          }
          for (var k = 0; k < n; k++) {
            final apk = a[p * n + k], aqk = a[q * n + k];
            a[p * n + k] = c * apk - s * aqk;
            a[q * n + k] = s * apk + c * aqk;
          }
          for (var k = 0; k < n; k++) {
            final vkp = v[k * n + p], vkq = v[k * n + q];
            v[k * n + p] = c * vkp - s * vkq;
            v[k * n + q] = s * vkp + c * vkq;
          }
        }
      }
    }
    var best = 0;
    for (var i = 1; i < n; i++) {
      if (a[i * n + i] < a[best * n + best]) best = i;
    }
    return [for (var k = 0; k < n; k++) v[k * n + best]];
  }
}
