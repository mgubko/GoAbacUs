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
    p.gravityAlong = -5.0; // ~30 degrees: beats friction and docking
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
    // ~14 degrees: enough to slide a free bead, not enough to undock.
    p.gravityAlong = 2.4;
    p.gravityNormal = 9.4;
    run(p, 1);
    expect(p.leftStack(0), 3);
  });

  test('a free bead slides at the tilt where a docked stack still holds', () {
    final p = AbacusPhysics();
    p.x[0][0] = 0.1;
    p.gravityAlong = -2.4;
    p.gravityNormal = 9.5;
    run(p, 1);
    expect(p.x[0][0], closeTo(p.config.halfBead, 1e-4));
  });

  test('tilting back the other way releases a full left stack', () {
    final p = AbacusPhysics()..setRowCount(0, 10);
    p.gravityAlong = 3.0; // ~18 degrees to the right
    p.gravityNormal = 9.3;
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
}
