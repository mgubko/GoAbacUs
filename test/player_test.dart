import 'package:flutter_test/flutter_test.dart';
import 'package:goabacus/arith/plan.dart';
import 'package:goabacus/arith/player.dart';
import 'package:goabacus/physics/abacus_physics.dart';

void main() {
  const dt = 1 / 240;

  ({double seconds, int impacts}) play(AbacusPhysics p, List<int> terms) {
    final player = ExamplePlayer(p, Example(terms));
    var t = 0.0;
    var impacts = 0;
    while (!player.done && t < player.estimate * 3) {
      player.update(dt);
      impacts += p.step(dt).length;
      t += dt;
    }
    expect(player.done, isTrue, reason: 'finished $terms');
    return (seconds: t, impacts: impacts);
  }

  for (final terms in [
    [25, 17, -8],
    [5, 7],
    [12, -7],
    [999, 1],
    [1000, -1],
    [9876543210, -9876543210],
  ]) {
    test('plays ${Example(terms).format()} through the physics', () {
      final p = AbacusPhysics();
      final r = play(p, terms);
      expect(p.value, Example(terms).result);
      expect(r.impacts, greaterThan(0), reason: 'beads should click');
      // ignore: avoid_print
      print('${Example(terms).format()}: ${r.seconds.toStringAsFixed(1)} s');
    });
  }

  test('clears a non-empty abacus first', () {
    final p = AbacusPhysics();
    p.setRowCount(0, 4);
    p.setRowCount(3, 9);
    play(p, [3, 4]);
    expect(p.value, 7);
  });

  test('beads land by physics alone, without timeouts', () {
    final p = AbacusPhysics();
    final player = ExamplePlayer(p, const Example([58, 67, -99, 9, 1000, -3]));
    var t = 0.0;
    while (!player.done && t < 120) {
      player.update(dt);
      p.step(dt);
      t += dt;
    }
    expect(p.value, 1032);
    expect(player.fixes, 0);
    expect(player.timeouts, 0);
  });
}
