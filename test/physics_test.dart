import 'package:flutter_test/flutter_test.dart';
import 'package:goabacus/physics/abacus_physics.dart';

void run(
  AbacusPhysics p,
  double seconds, [
  void Function(AbacusPhysics)? each,
]) {
  for (var t = 0.0; t < seconds; t += 1 / 240) {
    each?.call(p);
    p.step(1 / 240);
  }
}

void main() {
  test('starts at zero with all beads on the right', () {
    final p = AbacusPhysics();
    expect(p.value, 0);
    expect(p.isAtRest, isTrue);
  });

  test('setRowCount and value', () {
    final p = AbacusPhysics();
    p.setRowCount(0, 7);
    p.setRowCount(1, 3);
    p.setRowCount(2, 10);
    expect(p.value, 7 + 30 + 1000);
  });

  test('beads stay still when the abacus lies flat', () {
    final p = AbacusPhysics()..setRowCount(0, 4);
    final before = List.of(p.x[0]);
    run(p, 1);
    for (var i = 0; i < 10; i++) {
      expect(p.x[0][i], closeTo(before[i], 1e-6));
    }
  });

  test('small tilt is held by static friction, steep tilt slides beads', () {
    final p = AbacusPhysics();
    p.gravityAlong = -0.5; // ~3 degrees towards the left
    run(p, 1);
    expect(p.value, 0);
    p.gravityAlong = -6.0; // ~37 degrees: beats friction and docking
    run(p, 2);
    expect(p.countedBeads(0), 10);
    expect(p.x[0][0], closeTo(p.config.halfBead, 1e-4));
  });

  test('beads never overlap or leave the wire', () {
    final p = AbacusPhysics();
    p.setRowCount(0, 5);
    for (var i = 0; i < 10; i++) {
      p.v[0][i] = (i.isEven ? 1 : -1) * 2.5;
    }
    run(p, 1);
    final c = p.config;
    final xs = p.x[0];
    expect(xs.first, greaterThanOrEqualTo(c.halfBead - 1e-9));
    expect(xs.last, lessThanOrEqualTo(c.wireLength - c.halfBead + 1e-9));
    for (var i = 0; i < 9; i++) {
      expect(xs[i + 1] - xs[i], greaterThanOrEqualTo(c.beadLength - 1e-4));
    }
  });

  test('a finger drags one bead to the left and it is counted', () {
    final p = AbacusPhysics();
    final last = p.config.beadsPerRow - 1;
    final start = p.x[0][last];
    // Grab the leftmost bead of the right group (index 0) and move it left.
    final g = Grab(0, 0, 0, p.x[0][0]);
    p.grabs[1] = g;
    run(p, 0.5, (p) => g.target = (g.target - 0.0008).clamp(0.02, 1));
    p.grabs.clear();
    run(p, 1);
    expect(p.countedBeads(0), 1);
    expect(p.x[0][last], closeTo(start, 1e-9));
  });

  test('pushing many beads is slower than pushing one', () {
    double pushed(int count) {
      final p = AbacusPhysics();
      // Pushing bead `count - 1` to the left moves `count` beads together.
      final i = count - 1;
      final g = Grab(0, i, 0, p.x[0][i]);
      p.grabs[1] = g;
      final from = p.x[0][i];
      g.target = from - 0.1;
      run(p, 0.06);
      return from - p.x[0][i];
    }

    expect(pushed(10), lessThan(pushed(1)));
  });

  test('collisions report impacts', () {
    final p = AbacusPhysics();
    p.v[0][0] = -1.5;
    final impacts = <Impact>[];
    for (var i = 0; i < 240; i++) {
      impacts.addAll(p.step(1 / 240));
    }
    expect(impacts.any((e) => e.kind == ImpactKind.frame), isTrue);
  });

  test('tilt inside the dead zone does nothing, even on a free bead', () {
    final p = AbacusPhysics();
    p.x[0][0] = 0.1; // a lone bead in the middle of the wire
    p.gravityAlong = 0.55;
    run(p, 1);
    expect(p.x[0][0], closeTo(0.1, 1e-9));
  });

  test('a slow bead docks at the frame without bouncing', () {
    final p = AbacusPhysics();
    p.x[0][0] = 0.1;
    p.v[0][0] = -0.8;
    run(p, 1);
    expect(p.x[0][0], closeTo(p.config.halfBead, 1e-6));
    expect(p.leftStack(0), 1);
  });

  test('a slow bead docks onto the stack at the frame', () {
    final p = AbacusPhysics()..setRowCount(0, 3);
    p.x[0][3] = 0.12;
    p.v[0][3] = -0.9;
    run(p, 1);
    expect(p.leftStack(0), 4);
    expect(p.countedBeads(0), 4);
  });

  test('docked beads hold against a moderate tilt', () {
    final p = AbacusPhysics()..setRowCount(0, 3);
    // ~21 degrees: enough to slide a free bead, not enough to undock.
    p.gravityAlong = 3.45;
    p.gravityNormal = 9.2;
    run(p, 1);
    expect(p.leftStack(0), 3);
  });

  test('a free bead slides at the tilt where a docked stack still holds', () {
    final p = AbacusPhysics();
    p.x[0][0] = 0.1;
    p.gravityAlong = -3.45;
    p.gravityNormal = 9.2;
    run(p, 1);
    expect(p.x[0][0], closeTo(p.config.halfBead, 1e-4));
  });

  test('tilting back the other way releases a full left stack', () {
    final p = AbacusPhysics()..setRowCount(0, 10);
    p.gravityAlong = 5.0; // ~30 degrees to the right
    p.gravityNormal = 8.5;
    run(p, 2);
    expect(p.countedBeads(0), 0);
  });

  test('a finger pulls a bead out of a full left stack', () {
    final p = AbacusPhysics()..setRowCount(0, 10);
    final g = Grab(0, 9, 0, p.x[0][9]);
    p.grabs[1] = g;
    run(p, 0.5, (p) => g.target += 0.001);
    p.grabs.clear();
    run(p, 1);
    expect(p.countedBeads(0), 9);
  });

  test('pushing a group or pressing against the frame is silent', () {
    final p = AbacusPhysics();
    // Finger pushes bead 9 left: the whole row of 10 moves as one group.
    final g = Grab(0, 9, 0, p.x[0][9]);
    p.grabs[1] = g;
    final impacts = <Impact>[];
    for (var i = 0; i < 240; i++) {
      g.target -= 0.0008;
      impacts.addAll(p.step(1 / 240));
    }
    // Keep pressing against the left frame for another second.
    for (var i = 0; i < 240; i++) {
      impacts.addAll(p.step(1 / 240));
    }
    // At most one knock when the group first reaches the frame.
    expect(impacts.length, lessThanOrEqualTo(1));
  });

  test('a bead hitting a group makes exactly one click', () {
    final p = AbacusPhysics()..setRowCount(0, 3);
    p.x[0][3] = 0.15;
    p.v[0][3] = -0.6;
    final impacts = <Impact>[];
    for (var i = 0; i < 480; i++) {
      impacts.addAll(p.step(1 / 240));
    }
    expect(impacts.where((e) => e.kind == ImpactKind.bead).length, 1);
  });

  test('a group hitting the frame delivers more impulse than one bead', () {
    double impulse(int count) {
      final p = AbacusPhysics();
      // `count` beads touching each other, all flying left.
      for (var i = 0; i < count; i++) {
        p.x[0][i] = 0.08 + i * p.config.beadLength;
        p.v[0][i] = -0.5;
      }
      for (var k = 0; k < 240; k++) {
        for (final e in p.step(1 / 240)) {
          if (e.kind == ImpactKind.frame) return e.impulse;
        }
      }
      return 0;
    }

    final one = impulse(1);
    final five = impulse(5);
    expect(one, greaterThan(0));
    expect(five, closeTo(one * 5, one * 0.5));
  });

  test('on a slow tilt beads break away one by one, the end bead first', () {
    final p = AbacusPhysics()..setRowCount(0, 6);
    final left = <int, double>{};
    var t = 0.0;
    // Slowly tilt to the right: gravity along grows 1 m/s² per second.
    while (t < 6 && left.length < 6) {
      p.gravityAlong = t * 1.0;
      p.gravityNormal = 9.6;
      p.step(1 / 240);
      t += 1 / 240;
      for (var i = 0; i < 6; i++) {
        if (!left.containsKey(i) &&
            p.x[0][i] > p.config.halfBead + i * p.config.beadLength + 0.002) {
          left[i] = t;
        }
      }
    }
    expect(left.length, 6);
    // Bead 5 (the free end, downhill) goes first, then 4, 3...
    for (var i = 5; i > 0; i--) {
      expect(left[i]!, lessThan(left[i - 1]!));
    }
    // ...one after another, not all at once.
    expect(left[0]! - left[5]!, greaterThan(0.06));
  });

  test('moving a group down the slope is easier than up the slope', () {
    // How far a slowly dragged group of 5 lags behind the finger.
    double lag(int dir) {
      final p = AbacusPhysics();
      for (var k = 0; k < 5; k++) {
        p.x[0][k] = 0.07 + k * p.config.beadLength;
      }
      // Board tilted ~13 degrees down to the right; free beads still hold.
      p.gravityAlong = 2.0;
      p.gravityNormal = 9.5;
      // Push the group by its trailing bead.
      final i = dir > 0 ? 0 : 4;
      final g = Grab(0, i, 0, p.x[0][i]);
      p.grabs[1] = g;
      for (var k = 0; k < 120; k++) {
        g.target += dir * 0.0004;
        g.targetVelocity = dir * 0.1;
        p.step(1 / 240);
      }
      return (g.target - p.x[0][i]) * dir;
    }

    final down = lag(1);
    final up = lag(-1);
    expect(up, greaterThan(down * 1.5));
  });
}
