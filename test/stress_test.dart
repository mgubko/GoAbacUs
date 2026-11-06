import 'package:flutter_test/flutter_test.dart';
import 'package:goabacus/physics/abacus_physics.dart';

void main() {
  test('all beads on the left under strong tilt stays fast and stable', () {
    final p = AbacusPhysics();
    for (var r = 0; r < p.config.rows; r++) {
      p.setRowCount(r, 10);
    }
    p.gravityAlong = -9.0;
    p.gravityNormal = 3.0;
    final sw = Stopwatch()..start();
    for (var i = 0; i < 240 * 10; i++) {
      p.step(1 / 240);
    }
    sw.stop();
    expect(p.value, 11111111110);
    // 10 simulated seconds must take far less than real time.
    expect(sw.elapsedMilliseconds, lessThan(2000));
    for (final row in p.x) {
      for (final x in row) {
        expect(x.isFinite, isTrue);
      }
    }
  });
}
