import 'package:test/test.dart';
import 'package:tutor_vision/tutor_vision.dart';

Rod rod(int v, double x, double y) =>
    Rod(value: v, byColor: v, byLength: v, lengthMm: 10.0 * v, center: Pt(x, y), angle: 0, train: 0);

void main() {
  test('rods are grouped in rows, top to bottom, left to right', () {
    final r = RodsResult([], [
      Train([rod(3, 30, 40)]),
      Train([rod(7, 50, 120), rod(5, 110, 120)]),
      Train([rod(2, 150, 42)]),
    ]);
    expect(r.observation.rows, [
      [7, 5],
      [3, 2],
    ]);
  });

  test('abacus value', () {
    final a = AbacusReading([3, 0, 7, 0], [1, 1, 1, 1], [0, 0, 0, 0]);
    expect(a.observation!.value, 703);
    expect(AbacusReading([3, null], [1, 0], [0, 0]).observation, isNull);
  });

  test('homography round trip and mirror sign', () {
    final src = [const Pt(0, 0), const Pt(100, 0), const Pt(100, 50), const Pt(0, 50), const Pt(50, 25)];
    final dst = [const Pt(10, 200), const Pt(400, 180), const Pt(390, 20), const Pt(30, 30), const Pt(208, 107)];
    final h = Homography.fit(src, dst)!;
    final back = h.inverse().map(h.map(const Pt(33, 17)));
    expect(back.dist(const Pt(33, 17)), lessThan(1e-6));
    expect(h.orientationAt(const Pt(50, 25)), -1); // y up → y down: direct view
  });
}
