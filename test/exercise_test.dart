import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:goabacus/arith/exercise.dart';

void main() {
  test('carry and borrow detection', () {
    expect(hasCarry(25, 17), isTrue);
    expect(hasCarry(23, 45), isFalse);
    expect(hasCarry(95, 10), isTrue);
    expect(hasBorrow(42, 8), isTrue);
    expect(hasBorrow(48, 25), isFalse);
  });

  test('easy tasks fit without carry or borrow', () {
    final g = ExerciseGenerator(math.Random(1));
    for (var i = 0; i < 500; i++) {
      final e = g.next(const ExerciseSettings(level: ExerciseLevel.easy));
      final a = e.terms[0], b = e.terms[1];
      expect(e.result, inInclusiveRange(0, 99));
      if (b > 0) {
        expect(hasCarry(a, b), isFalse, reason: e.format());
      } else {
        expect(hasBorrow(a, -b), isFalse, reason: e.format());
        expect(e.result, greaterThan(0));
      }
    }
  });

  test('hard tasks need a carry or a borrow', () {
    final g = ExerciseGenerator(math.Random(2));
    var adds = 0;
    for (var i = 0; i < 500; i++) {
      final e = g.next(const ExerciseSettings(level: ExerciseLevel.hard));
      final a = e.terms[0], b = e.terms[1];
      expect(e.result, inInclusiveRange(1, 999));
      if (b > 0) {
        adds++;
        expect(hasCarry(a, b), isTrue, reason: e.format());
      } else {
        expect(hasBorrow(a, -b), isTrue, reason: e.format());
      }
    }
    expect(adds, inInclusiveRange(150, 350));
  });

  test('ops setting is respected', () {
    final g = ExerciseGenerator(math.Random(3));
    for (var i = 0; i < 100; i++) {
      expect(
        g.next(const ExerciseSettings(ops: ExerciseOps.sub)).terms[1],
        isNegative,
      );
      expect(
        g.next(const ExerciseSettings(ops: ExerciseOps.add)).terms[1],
        isPositive,
      );
    }
  });

  test('session: right answer after the beads rest, time limit', () {
    const ms = Duration(milliseconds: 100);
    final s = ExerciseSession(const ExerciseSettings());
    final answer = s.answer;
    expect(s.tick(ms, answer, false), isFalse);
    for (var i = 0; i < 8; i++) {
      expect(s.tick(ms, answer, true), isFalse);
    }
    expect(s.tick(ms * 2, answer, true), isTrue);
    expect(s.state, TaskState.right);
    expect(s.solved, 1);

    s.next();
    for (var i = 0; i < 599; i++) {
      s.tick(ms, s.answer + 1, true);
    }
    expect(s.state, TaskState.solving);
    expect(s.tick(ms, s.answer + 1, true), isTrue);
    expect(s.state, TaskState.timeUp);
    expect(s.streak, 0);

    s.next();
    s.submit(s.answer + 1);
    expect(s.state, TaskState.wrong);
  });
}
