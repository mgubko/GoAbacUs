import 'dart:math' as math;

/// Physical constants of the abacus. All units are SI (metres, kilograms,
/// seconds), so the simulation behaves the same on any screen size.
class AbacusConfig {
  const AbacusConfig({
    this.rows = 10,
    this.beadsPerRow = 10,
    this.wireLength = 0.29,
    this.beadLength = 0.018,
    this.beadMass = 0.008,
    this.beadRestitution = 0.2,
    this.wallRestitution = 0.25,
    this.staticFriction = 0.17,
    this.kineticFriction = 0.12,
    this.tiltDeadZone = 0.6,
    this.adhesion = 0.4,
    this.captureSpeed = 1.2,
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

  /// Gravity along the wires below this (m/s², about 3.5°) is ignored, so a
  /// slightly unsteady hand does not move the beads.
  final double tiltDeadZone;

  /// Beads resting against the frame, or against a stack of beads resting
  /// against the frame, are held by this extra acceleration (m/s²).
  final double adhesion;

  /// Below this approach speed (m/s) a bead hitting the frame or the stack at
  /// the frame does not bounce: it docks and stays there.
  final double captureSpeed;

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
  const Impact(
    this.row,
    this.position,
    this.speed,
    this.kind, {
    this.impulse = 0,
  });
  final int row;
  final double position;
  final double speed;
  final ImpactKind kind;

  /// Momentum delivered to the frame (kg·m/s): the whole group of beads that
  /// moves together counts, so a row of ten hits harder than one bead.
  final double impulse;
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
    // Every real bead is a little different: its grip on the wire and how
    // long it resists before it breaks loose. Fixed seed: the same abacus
    // every launch, and repeatable tests.
    final rnd = math.Random(7);
    for (var r = 0; r < config.rows; r++) {
      _grip.add(
        List.generate(
          config.beadsPerRow,
          (_) => 0.92 + 0.16 * rnd.nextDouble(),
        ),
      );
      _breakDelay.add(
        List.generate(
          config.beadsPerRow,
          (_) => 0.03 + 0.07 * rnd.nextDouble(),
        ),
      );
      _strain.add(List.filled(config.beadsPerRow, 0.0));
    }
    clear();
  }

  final AbacusConfig config;
  final _grip = <List<double>>[];
  final _breakDelay = <List<double>>[];
  final _strain = <List<double>>[];

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
  static const double _impactSpeed = 0.05;
  static const int _iterations = 12;
  static const double _touch = 0.0005;

  /// Number of beads docked at the left frame (beads 0..n-1 touching it and
  /// each other).
  int leftStack(int row) {
    final xs = x[row];
    if (xs[0] - config.halfBead > _touch) return 0;
    var n = 1;
    while (n < xs.length && xs[n] - xs[n - 1] - config.beadLength <= _touch) {
      n++;
    }
    return n;
  }

  /// Index of the first bead docked at the right frame (beadsPerRow if none).
  int rightStack(int row) {
    final xs = x[row];
    final last = xs.length - 1;
    if (config.wireLength - config.halfBead - xs[last] > _touch) {
      return xs.length;
    }
    var i = last;
    while (i > 0 && xs[i] - xs[i - 1] - config.beadLength <= _touch) {
      i--;
    }
    return i;
  }

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

  /// Whether bead [i] of row [r], pulled in direction [dir], rests against a
  /// resting neighbour or the frame on that side.
  bool _supported(int r, int i, int dir) {
    final xs = x[r];
    final j = i + dir;
    if (j < 0) return xs[i] - config.halfBead <= _touch;
    if (j >= xs.length) {
      return config.wireLength - config.halfBead - xs[i] <= _touch;
    }
    final gap = (xs[j] - xs[i]).abs() - config.beadLength;
    return gap <= _touch && v[r][j].abs() <= _restSpeed;
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
    final along = gravityAlong.abs() <= c.tiltDeadZone
        ? 0.0
        : gravityAlong - gravityAlong.sign * c.tiltDeadZone;

    for (var r = 0; r < c.rows; r++) {
      final xs = x[r];
      final vs = v[r];
      final accel = List.filled(c.beadsPerRow, along);
      final grabbed = List.filled(c.beadsPerRow, false);
      final touching = _contacts(r);
      final left = leftStack(r);
      final right = rightStack(r);
      for (final g in grabs.values) {
        if (g.row != r) continue;
        grabbed[g.bead] = true;
        final i = g.bead;
        var f =
            c.grabStiffness * (g.target + g.offset - xs[i]) +
            damping * (g.targetVelocity - vs[i]);
        f = f.clamp(-c.grabMaxForce, c.grabMaxForce);
        accel[i] += f / m;
      }

      final strain = _strain[r];
      for (var i = 0; i < c.beadsPerRow; i++) {
        final a = accel[i];
        var s = vs[i];
        if (s.abs() <= _restSpeed) {
          // Sticking: it only starts to slide if pushed over static friction,
          // plus adhesion when it is docked and pulled away from the frame.
          var hold = static * _grip[r][i];
          if (!grabbed[i] && ((i < left && a > 0) || (i >= right && a < 0))) {
            hold += c.adhesion;
          }
          if (a.abs() <= hold) {
            s = 0;
            strain[i] = 0;
          } else if (grabbed[i]) {
            s = (a - a.sign * kinetic) * dt;
          } else if (_supported(r, i, a.sign.toInt())) {
            // A resting bead propped up from below by a resting neighbour
            // (or the frame) stays put; only the last bead of a group, with
            // nothing below it, can break away.
            s = 0;
            strain[i] = 0;
          } else {
            // Dry friction lets go after a short, bead-specific moment, so
            // on a slow tilt beads tear off one after another: a cascade.
            strain[i] += dt;
            if (strain[i] >= _breakDelay[r][i]) {
              strain[i] = 0;
              s = (a - a.sign * kinetic) * dt;
            } else {
              s = 0;
            }
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

      _resolveContacts(r, impacts, left, right, touching);
    }
    return impacts;
  }

  /// Which contacts were already closed before this step: [0] left frame,
  /// [i] beads i-1 and i, [n] right frame. Only newly closed contacts make a
  /// sound; beads pressed together or pushed as a group stay silent.
  List<bool> _contacts(int r) {
    // A contact counts as closed when the gap is (almost) zero and the two
    // sides are not rushing together; a fast bead that is just about to hit
    // is still a new impact.
    final xs = x[r];
    final vs = v[r];
    final n = xs.length;
    final t = List.filled(n + 1, false);
    t[0] = xs[0] - config.halfBead <= _touch && -vs[0] <= _impactSpeed;
    for (var i = 1; i < n; i++) {
      t[i] =
          xs[i] - xs[i - 1] - config.beadLength <= _touch &&
          vs[i - 1] - vs[i] <= _impactSpeed;
    }
    t[n] =
        config.wireLength - config.halfBead - xs[n - 1] <= _touch &&
        vs[n - 1] <= _impactSpeed;
    return t;
  }

  /// Momentum towards the frame of the bead at [from] and the beads pressed
  /// behind it, moving in direction [dir] (-1 left, +1 right).
  double _groupMomentum(List<double> xs, List<double> vs, int from, int dir) {
    var p = 0.0;
    var i = from;
    while (i >= 0 && i < xs.length) {
      final s = vs[i] * dir;
      if (s <= 0) break;
      p += config.beadMass * s;
      final next = i - dir;
      if (next < 0 || next >= xs.length) break;
      final gap = (xs[i] - xs[next]).abs() - config.beadLength;
      if (gap > 0.001) break;
      i = next;
    }
    return p;
  }

  void _resolveContacts(
    int r,
    List<Impact> impacts,
    int left,
    int right,
    List<bool> touching,
  ) {
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
          if (first && !touching[0] && -vs[0] > _impactSpeed) {
            impacts.add(
              Impact(
                r,
                0,
                -vs[0],
                ImpactKind.frame,
                impulse: _groupMomentum(xs, vs, 0, -1),
              ),
            );
          }
          // Slow arrivals dock at the frame instead of bouncing.
          vs[0] = -vs[0] > c.captureSpeed ? -vs[0] * c.wallRestitution : 0;
        }
      }
      if (xs[n - 1] > hi) {
        xs[n - 1] = hi;
        if (vs[n - 1] > 0) {
          if (first && !touching[n] && vs[n - 1] > _impactSpeed) {
            impacts.add(
              Impact(
                r,
                c.wireLength,
                vs[n - 1],
                ImpactKind.frame,
                impulse: _groupMomentum(xs, vs, n - 1, 1),
              ),
            );
          }
          vs[n - 1] = vs[n - 1] > c.captureSpeed
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
            if (first && !touching[i + 1] && closing > _impactSpeed) {
              impacts.add(
                Impact(r, xs[i] + c.halfBead, closing, ImpactKind.bead),
              );
            }
            // A bead arriving at the stack docked at the frame joins it.
            final docking =
                (i < left || i + 1 >= right) && closing <= c.captureSpeed;
            final e = closing > _bounceSpeed && !docking
                ? c.beadRestitution
                : 0.0;
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
