import 'dart:math' as math;

/// Physical constants of the abacus. All units are SI (metres, kilograms,
/// seconds), so the simulation behaves the same on any screen size.
class AbacusConfig {
  const AbacusConfig({
    this.rows = 10,
    this.beadsPerRow = 10,
    this.wireLength = 0.32,
    this.beadLength = 0.018,
    this.beadMass = 0.008,
    this.beadRestitution = 0.35,
    this.wallRestitution = 0.28,
    this.staticFriction = 0.11,
    this.kineticFriction = 0.075,
    this.airDrag = 0.35,
    this.grabStiffness = 45.0,
    this.grabDampingRatio = 0.9,
    this.grabMaxForce = 0.55,
  });

  final int rows;
  final int beadsPerRow;

  /// Free length of a wire between the inner faces of the frame.
  final double wireLength;

  /// Thickness of one bead measured along the wire.
  final double beadLength;
  final double beadMass;

  /// Coefficient of restitution for bone hitting bone / bone hitting wood.
  final double beadRestitution;
  final double wallRestitution;

  /// Coulomb friction of a bead on its wire.
  final double staticFriction;
  final double kineticFriction;

  /// Small velocity-proportional loss (1/s): air and wire wobble.
  final double airDrag;

  /// The finger is modelled as a stiff spring with a limited force. A single
  /// bead follows the finger almost instantly; a long chain of beads is
  /// heavier, accelerates slower and lags behind, so it has to be "pulled"
  /// harder, exactly as on a real abacus.
  final double grabStiffness;
  final double grabDampingRatio;
  final double grabMaxForce;

  double get halfBead => beadLength / 2;
}

enum ImpactKind { bead, frame }

/// A collision that happened during a step. Used for sound and haptics.
class Impact {
  const Impact(this.row, this.position, this.speed, this.kind);
  final int row;
  final double position;
  final double speed;
  final ImpactKind kind;
}

/// A finger holding a bead.
class Grab {
  Grab(this.row, this.bead, this.offset, this.target);
  final int row;
  final int bead;

  /// Bead centre minus finger position at the moment of the grab.
  final double offset;

  /// Finger position along the wire.
  double target;
  double targetVelocity = 0;
}

class AbacusPhysics {
  AbacusPhysics([this.config = const AbacusConfig()])
    : x = List.generate(
        config.rows,
        (_) => List.filled(config.beadsPerRow, 0.0),
      ),
      v = List.generate(
        config.rows,
        (_) => List.filled(config.beadsPerRow, 0.0),
      ) {
    clear();
  }

  final AbacusConfig config;

  /// Bead centre positions per row, measured from the left inner frame face.
  /// Beads in a row are always sorted left to right.
  final List<List<double>> x;
  final List<List<double>> v;

  final Map<int, Grab> grabs = {};

  /// Gravity component along the wires (+ means towards the right), m/s².
  double gravityAlong = 0;

  /// Gravity component pressing beads onto the wires, m/s².
  double gravityNormal = 9.81;

  static const double _restSpeed = 1e-4;
  static const double _bounceSpeed = 0.05;
  static const double _impactSpeed = 0.03;
  static const int _iterations = 12;

  /// Puts every bead to the right side: the abacus shows zero.
  void clear() {
    for (var r = 0; r < config.rows; r++) {
      for (var i = 0; i < config.beadsPerRow; i++) {
        x[r][i] =
            config.wireLength -
            config.halfBead -
            (config.beadsPerRow - 1 - i) * config.beadLength;
        v[r][i] = 0;
      }
    }
  }

  /// Places [count] beads of [row] on the left (counted) side, the rest on
  /// the right, at rest.
  void setRowCount(int row, int count) {
    for (var i = 0; i < config.beadsPerRow; i++) {
      x[row][i] = i < count
          ? config.halfBead + i * config.beadLength
          : config.wireLength -
                config.halfBead -
                (config.beadsPerRow - 1 - i) * config.beadLength;
      v[row][i] = 0;
    }
  }

  /// Gives every bead a push towards the right, like sweeping the abacus clean.
  void sweepRight({double speed = 0.9}) {
    for (var r = 0; r < config.rows; r++) {
      for (var i = 0; i < config.beadsPerRow; i++) {
        v[r][i] = math.max(v[r][i], speed * (0.8 + 0.04 * i));
      }
    }
  }

  /// Index of the bead under [pos] in [row], or null.
  int? beadAt(int row, double pos, {double tolerance = 0.003}) {
    final h = config.halfBead + tolerance;
    int? best;
    var bestDist = double.infinity;
    for (var i = 0; i < config.beadsPerRow; i++) {
      final d = (x[row][i] - pos).abs();
      if (d <= h && d < bestDist) {
        best = i;
        bestDist = d;
      }
    }
    return best;
  }

  /// Number of beads on the counted (left) side of [row]. The two groups are
  /// separated by the widest gap on the wire.
  int countedBeads(int row) {
    final xs = x[row];
    final n = xs.length;
    var bestGap = xs[0] - config.halfBead;
    var best = 0;
    for (var i = 1; i < n; i++) {
      final gap = xs[i] - xs[i - 1] - config.beadLength;
      if (gap > bestGap + 1e-6) {
        bestGap = gap;
        best = i;
      }
    }
    final rightGap = config.wireLength - config.halfBead - xs[n - 1];
    if (rightGap > bestGap + 1e-6) best = n;
    return best;
  }

  /// The number shown on the abacus; row 0 holds the units.
  int get value {
    var total = 0;
    var place = 1;
    for (var r = 0; r < config.rows; r++) {
      total += countedBeads(r) * place;
      place *= 10;
    }
    return total;
  }

  bool get isAtRest {
    if (grabs.isNotEmpty) return false;
    for (final row in v) {
      for (final s in row) {
        if (s.abs() > _restSpeed) return false;
      }
    }
    return true;
  }

  /// Advances the simulation by [dt] seconds and reports collisions.
  List<Impact> step(double dt) {
    final impacts = <Impact>[];
    final c = config;
    final m = c.beadMass;
    final normal = math.max(gravityNormal, 1.0);
    final kinetic = c.kineticFriction * normal;
    final static = c.staticFriction * normal;
    final damping = 2 * c.grabDampingRatio * math.sqrt(c.grabStiffness * m);

    for (var r = 0; r < c.rows; r++) {
      final xs = x[r];
      final vs = v[r];
      final accel = List.filled(c.beadsPerRow, gravityAlong);
      for (final g in grabs.values) {
        if (g.row != r) continue;
        final i = g.bead;
        var f =
            c.grabStiffness * (g.target + g.offset - xs[i]) +
            damping * (g.targetVelocity - vs[i]);
        f = f.clamp(-c.grabMaxForce, c.grabMaxForce);
        accel[i] += f / m;
      }

      for (var i = 0; i < c.beadsPerRow; i++) {
        final a = accel[i];
        var s = vs[i];
        if (s.abs() <= _restSpeed) {
          // Sticking: it only starts to slide if pushed over static friction.
          if (a.abs() > static) {
            s = (a - a.sign * kinetic) * dt;
          } else {
            s = 0;
          }
        } else {
          s += a * dt;
          final loss = (kinetic + c.airDrag * s.abs()) * dt;
          if (s.abs() <= loss) {
            s = 0;
          } else {
            s -= s.sign * loss;
          }
        }
        vs[i] = s;
        xs[i] += s * dt;
      }

      _resolveContacts(r, impacts);
    }
    return impacts;
  }

  void _resolveContacts(int r, List<Impact> impacts) {
    final c = config;
    final xs = x[r];
    final vs = v[r];
    final n = c.beadsPerRow;
    final lo = c.halfBead;
    final hi = c.wireLength - c.halfBead;

    for (var it = 0; it < _iterations; it++) {
      final first = it == 0;
      // Frame.
      if (xs[0] < lo) {
        xs[0] = lo;
        if (vs[0] < 0) {
          if (first && -vs[0] > _impactSpeed) {
            impacts.add(Impact(r, 0, -vs[0], ImpactKind.frame));
          }
          vs[0] = -vs[0] > _bounceSpeed ? -vs[0] * c.wallRestitution : 0;
        }
      }
      if (xs[n - 1] > hi) {
        xs[n - 1] = hi;
        if (vs[n - 1] > 0) {
          if (first && vs[n - 1] > _impactSpeed) {
            impacts.add(Impact(r, c.wireLength, vs[n - 1], ImpactKind.frame));
          }
          vs[n - 1] = vs[n - 1] > _bounceSpeed
              ? -vs[n - 1] * c.wallRestitution
              : 0;
        }
      }
      // Neighbouring beads (equal masses).
      for (var i = 0; i < n - 1; i++) {
        final overlap = xs[i] + c.beadLength - xs[i + 1];
        if (overlap > 0) {
          xs[i] -= overlap / 2;
          xs[i + 1] += overlap / 2;
          final closing = vs[i] - vs[i + 1];
          if (closing > 0) {
            if (first && closing > _impactSpeed) {
              impacts.add(
                Impact(r, xs[i] + c.halfBead, closing, ImpactKind.bead),
              );
            }
            final e = closing > _bounceSpeed ? c.beadRestitution : 0.0;
            final j = (1 + e) * closing / 2;
            vs[i] -= j;
            vs[i + 1] += j;
          }
        }
      }
    }
    // Final hard clamp so beads never leave the wire.
    if (xs[0] < lo) xs[0] = lo;
    if (xs[n - 1] > hi) xs[n - 1] = hi;
  }
}
