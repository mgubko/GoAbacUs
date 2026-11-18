import 'package:test/test.dart';
import 'package:tutor_tasks/tutor_tasks.dart';

void main() {
  test('examples and missing numbers', () {
    expect(EqTask.parse('8+5').answer, 13);
    expect(EqTask.parse('9+?=15').answer, 6);
    expect(EqTask.parse('9+?=15').format(), '9 + ? = 15');
    expect(EqTask.parse('?-5=7').answer, 12);
    expect(EqTask.parse('7*6').answer, 42);
    expect(EqTask.parse('3*?=21').answer, 7);
    expect(EqTask.parse('3*7').questions.single.terms, [7, 7, 7]);
  });

  test('chain and house', () {
    final c = ChainTask(6, [7, -5, 8]);
    expect(c.questions.map((q) => q.answer), [13, 8, 16]);
    expect(c.questions[1].continues, isTrue);
    final h = HouseTask(13, [
      [8, null],
      [null, 4],
    ]);
    expect(h.questions.map((q) => q.answer), [5, 9]);
    expect(h.warnings, isEmpty);
    expect(
      HouseTask(10, [
        [12, null],
      ]).warnings,
      contains('room_bigger_than_roof'),
    );
  });

  test('mistakes', () {
    final q = EqTask.parse('57+28').questions.single;
    expect(classify(q, 84), Mistake.offByOne);
    expect(classify(q, 75), Mistake.placeValue);
    expect(classify(q, 29), Mistake.wrongOp);
    expect(classify(q, 58), Mistake.swapped);
    expect(classify(q, 40), Mistake.other);
  });

  test('json round trip', () {
    final tasks = <Task>[
      EqTask.parse('8+5', n: '1a', child: 12),
      EqTask.parse('9+?=15', n: '1b'),
      StepsTask(57, Op.add, 28, n: '2'),
      ChainTask(6, [7, -5, 8], n: '3'),
      HouseTask(13, [
        [8, null],
        [null, 4],
      ], n: '4'),
    ];
    for (final t in tasks) {
      final back = Task.fromJson(t.toJson());
      expect(back.format(), t.format());
      expect(back.n, t.n);
    }
  });
}
