import 'dart:math' as math;

import 'plan.dart';

enum ExerciseOps { add, sub, both }

enum ExerciseLevel { easy, hard }

class ExerciseSettings {
  const ExerciseSettings({
    this.ops = ExerciseOps.both,
    this.level = ExerciseLevel.easy,
  });
  final ExerciseOps ops;
  final ExerciseLevel level;
}

/// Makes school tasks for the abacus.
///
/// Easy: numbers up to 99, every digit fits in its row (no carry, no
/// borrow). Hard: numbers up to 999 with at least one carry or borrow, so
/// the child must use + 10 − 3 and − 10 + 3.
class ExerciseGenerator {
  ExerciseGenerator([math.Random? random]) : _rnd = random ?? math.Random();
  final math.Random _rnd;
  Example? _last;

  Example next(ExerciseSettings s) {
    for (;;) {
      final e = _make(s);
      if (_last == null || e.format() != _last!.format()) {
        _last = e;
        return e;
      }
    }
  }

  Example _make(ExerciseSettings s) {
    final add = switch (s.ops) {
      ExerciseOps.add => true,
      ExerciseOps.sub => false,
      ExerciseOps.both => _rnd.nextBool(),
    };
    final hard = s.level == ExerciseLevel.hard;
    for (;;) {
      if (hard) {
        final a = _number(10, 999);
        final b = _number(2, 999);
        if (add) {
          if (a + b <= 999 && hasCarry(a, b)) return Example([a, b]);
        } else {
          if (a > b && hasBorrow(a, b)) return Example([a, -b]);
        }
      } else {
        final a = _number(1, 99);
        final b = _number(1, 99);
        if (add) {
          if (a + b <= 99 && !hasCarry(a, b)) return Example([a, b]);
        } else {
          if (a > b && !hasBorrow(a, b)) return Example([a, -b]);
        }
      }
    }
  }

  /// Small numbers are as likely as big ones: first pick how many digits.
  int _number(int min, int max) {
    final lo = min.toString().length;
    final hi = max.toString().length;
    final digits = lo + _rnd.nextInt(hi - lo + 1);
    final from = math.max(
      min,
      digits == 1 ? 0 : math.pow(10, digits - 1).toInt(),
    );
    final to = math.min(max, math.pow(10, digits).toInt() - 1);
    return from + _rnd.nextInt(to - from + 1);
  }
}

bool hasCarry(int a, int b) {
  while (a > 0 || b > 0) {
    if (a % 10 + b % 10 > 9) return true;
    a ~/= 10;
    b ~/= 10;
  }
  return false;
}

bool hasBorrow(int a, int b) {
  while (b > 0) {
    if (a % 10 < b % 10) return true;
    a ~/= 10;
    b ~/= 10;
  }
  return false;
}

enum TaskState { solving, right, wrong, timeUp }

/// One sitting of tasks: the current task, its timer and the score.
class ExerciseSession {
  ExerciseSession(this.settings, {ExerciseGenerator? generator})
    : _gen = generator ?? ExerciseGenerator() {
    _newTask();
  }

  static const Duration limit = Duration(minutes: 1);

  /// The answer counts once the beads rest on it this long.
  static const Duration settle = Duration(milliseconds: 900);

  final ExerciseSettings settings;
  final ExerciseGenerator _gen;

  late Example task;
  TaskState state = TaskState.solving;
  Duration elapsed = Duration.zero;
  int number = 0;
  int solved = 0;
  int streak = 0;
  Duration _onAnswer = Duration.zero;

  int get answer => task.result;
  Duration get left => limit - elapsed;

  void _newTask() {
    task = _gen.next(settings);
    state = TaskState.solving;
    elapsed = Duration.zero;
    _onAnswer = Duration.zero;
    number++;
  }

  void next() => _newTask();

  /// Advances the clock. [value] is what the abacus shows, [still] whether
  /// nothing moves and no finger touches. Returns true when the state changed.
  bool tick(Duration dt, int value, bool still) {
    if (state != TaskState.solving) return false;
    elapsed += dt;
    if (value == answer && still) {
      _onAnswer += dt;
      if (_onAnswer >= settle) {
        state = TaskState.right;
        solved++;
        streak++;
        return true;
      }
    } else {
      _onAnswer = Duration.zero;
    }
    if (elapsed >= limit) {
      state = TaskState.timeUp;
      streak = 0;
      return true;
    }
    return false;
  }

  /// The child says "done": checks what the abacus shows.
  void submit(int value) {
    if (state != TaskState.solving) return;
    if (value == answer) {
      state = TaskState.right;
      solved++;
      streak++;
    } else {
      state = TaskState.wrong;
      streak = 0;
    }
  }
}
