import 'package:flutter_test/flutter_test.dart';
import 'package:goabacus/arith/plan.dart';
import 'package:goabacus/arith/tape.dart';

List<int> run(List<DigitStep> steps, int rows) {
  final d = List.filled(rows, 0);
  for (final s in steps) {
    for (final m in s.moves) {
      d[m.row] += m.count;
      expect(d[m.row], inInclusiveRange(0, 9), reason: '$m');
    }
  }
  return d;
}

int valueOf(List<int> d) {
  var v = 0;
  for (var r = d.length - 1; r >= 0; r--) {
    v = v * 10 + d[r];
  }
  return v;
}

void main() {
  const max = 9999999999;

  test('parses examples', () {
    final r = parseExample('25 + 17 − 8', maxValue: max);
    expect(r.example!.terms, [25, 17, -8]);
    expect(r.example!.result, 34);
    expect(r.example!.format(), '25 + 17 − 8');
    expect(parseExample('12-3+', maxValue: max).error, ExampleError.unfinished);
    expect(parseExample('', maxValue: max).error, ExampleError.empty);
    expect(parseExample('5-7', maxValue: max).error, ExampleError.negative);
    expect(parseExample('99+1', maxValue: 99).error, ExampleError.tooBig);
    expect(parseExample('-5', maxValue: max).error, ExampleError.unfinished);
  });

  test('simple addition moves one row per digit', () {
    final steps = planExample(const Example([23, 45]), 10);
    expect(steps.map((s) => s.moves).expand((m) => m).toList(), const [
      BeadMove(1, 2),
      BeadMove(0, 3),
      BeadMove(1, 4),
      BeadMove(0, 5),
    ]);
    expect(steps.every((s) => s.complement == null), isTrue);
  });

  test('carry: + 7 = + 10 − 3', () {
    final steps = planExample(const Example([5, 7]), 10);
    final last = steps.last;
    expect(last.complement, 3);
    expect(last.moves, const [BeadMove(1, 1), BeadMove(0, -3)]);
  });

  test('borrow: − 7 = − 10 + 3', () {
    final steps = planExample(const Example([12, -7]), 10);
    final last = steps.last;
    expect(last.complement, 3);
    expect(last.moves, const [BeadMove(1, -1), BeadMove(0, 3)]);
  });

  test('carry ripples through nines', () {
    final steps = planExample(const Example([999, 1]), 10);
    expect(steps.last.moves, const [
      BeadMove(3, 1),
      BeadMove(2, -9),
      BeadMove(1, -9),
      BeadMove(0, -9),
    ]);
  });

  test('every plan ends on the right number', () {
    final examples = [
      [25, 17, -8],
      [1000, -1],
      [58, 67, -99, 444],
      [9999, 1, -10000],
      [123456789, 987654321],
    ];
    for (final t in examples) {
      final e = Example(t);
      expect(valueOf(run(planExample(e, 10), 10)), e.result, reason: '$t');
    }
  });

  test('tape writes a term after the beads rest', () {
    final tape = Tape();
    Duration ms(int v) => Duration(milliseconds: v);
    expect(tape.update(25, true, ms(0)), isFalse);
    expect(tape.update(25, true, ms(1600)), isTrue);
    expect(tape.terms, [25]);
    // A carry done with a short pause still counts as one move.
    tape.update(35, false, ms(2000));
    tape.update(35, true, ms(2500));
    tape.update(32, false, ms(2900));
    tape.update(32, true, ms(3200));
    expect(tape.update(32, true, ms(4800)), isTrue);
    expect(tape.terms, [25, 7]);
    tape.update(24, true, ms(5000));
    tape.update(24, true, ms(6600));
    expect(tape.example!.format(), '25 + 7 − 8');
    tape.update(0, true, ms(7000));
    tape.update(0, true, ms(8600));
    expect(tape.terms, isEmpty);
  });
}
