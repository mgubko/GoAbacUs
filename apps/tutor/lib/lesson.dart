import 'dart:math' as math;

import 'package:abacus_kit/abacus_kit.dart';
import 'package:flutter/foundation.dart';
import 'package:tutor_tasks/tutor_tasks.dart';

/// What the tutor says, as a key into the strings and its numbers.
class Say {
  const Say(this.key, [this.args = const {}]);
  final String key;
  final Map<String, Object> args;

  @override
  String toString() => '$key$args';
}

enum Phase {
  /// Put the first number on the abacus.
  setStart,

  /// Do the operation on the abacus.
  operate,

  /// The abacus shows the result: say the number.
  answer,

  /// Right answer, a short pause before the next question.
  right,

  /// The tutor shows an example on the abacus.
  demo,

  /// All tasks done.
  done,
}

/// Something the screen does for a hint.
class HintAction {
  const HintAction({this.row, this.demo, this.demoIsOwn = false});

  /// Light up this wire.
  final int? row;

  /// Play this example on the abacus.
  final Example? demo;

  /// The demo is the child's own question (the last step of the ladder).
  final bool demoIsOwn;
}

/// The lesson: the exact core that leads the child through the tasks, one
/// small question at a time. It knows the abacus only by the settled number
/// it shows, so the same lesson will run with the camera on real beads.
class Lesson extends ChangeNotifier {
  Lesson(this.packet, {this.rows = 4, math.Random? random})
    : _rnd = random ?? math.Random(),
      tasks = _order(packet.tasks) {
    _results.addAll(List.filled(tasks.length, null));
    _startQuestion();
  }

  final TaskPacket packet;
  final int rows;
  final math.Random _rnd;

  /// The tasks in lesson order: those answered wrongly in the book first.
  final List<Task> tasks;

  static List<Task> _order(List<Task> ts) {
    bool wrongInBook(Task t) =>
        t is EqTask && t.child != null && t.child != t.answer;
    return [...ts.where(wrongInBook), ...ts.where((t) => !wrongInBook(t))];
  }

  int taskIndex = 0;
  int questionIndex = 0;
  Phase phase = Phase.setStart;
  Say say = const Say('hello');

  /// The highest hint step used on the current question (0..4).
  int hint = 0;
  int _taskHints = 0;
  int _tries = 0;
  final _mistakes = <Mistake>[];
  double _taskSeconds = 0;
  double _idle = 0;
  bool _nudged = false;

  /// Answers given to the questions of the current task.
  final answers = <int>[];

  final _results = <TaskResult?>[];
  List<TaskResult> get results => [for (final r in _results) ?r];

  Task get task => tasks[taskIndex];
  Question get question => task.questions[questionIndex];

  /// Number of the task shown to the child (from 1).
  int get number => taskIndex + 1;

  /// What the abacus must show before the operation.
  int get startValue {
    final q = question;
    if (q.unknown == Slot.a) return q.result; // ? + 8 = 15: start from 15
    if (q.op == Op.mul) return q.b; // 3 · 7: start with one 7
    return q.a;
  }

  /// What the abacus shows once the operation is done.
  int get goalValue {
    final q = question;
    if (q.unknown == Slot.a) return q.a; // 15 − 8 = 7
    return q.result;
  }

  void _startQuestion() {
    hint = 0;
    _idle = 0;
    _nudged = false;
    phase = Phase.setStart;
    if (questionIndex == 0) {
      say = Say(number == 1 ? 'first_task' : 'next_task', {'n': number});
    }
    _askStart();
  }

  void _askStart() {
    phase = Phase.setStart;
    say = Say('set', {'n': startValue});
  }

  void _askOperate() {
    final q = question;
    phase = Phase.operate;
    say = switch ((q.unknown, q.op)) {
      (Slot.a, Op.add) => Say('take', {'n': q.b}),
      (Slot.a, Op.sub) => Say('add', {'n': q.b}),
      (Slot.b, _) => Say('until', {'n': q.result}),
      (_, Op.mul) => Say('mul', {'n': q.b, 'k': q.a}),
      (_, Op.add) => Say('add', {'n': q.b}),
      (_, Op.sub) => Say('take', {'n': q.b}),
    };
  }

  void _askAnswer() {
    final q = question;
    phase = Phase.answer;
    say = switch (q.unknown) {
      Slot.b => const Say('how_many_added'),
      Slot.a => const Say('how_many_left'),
      Slot.result => const Say('how_much'),
    };
  }

  /// The abacus came to rest on [value].
  void onAbacus(int value) {
    if (phase == Phase.setStart && value == startValue) {
      _idle = 0;
      if (goalValue == startValue) {
        _askAnswer();
      } else {
        _askOperate();
        say = Say('good_then', {'next': say.key, ...say.args});
      }
      notifyListeners();
    } else if (phase == Phase.operate && value == goalValue) {
      _idle = 0;
      _askAnswer();
      notifyListeners();
    } else if (phase == Phase.answer && value != goalValue) {
      // The beads moved away from the result: lead again.
      _askOperate();
      notifyListeners();
    }
  }

  /// The child typed [n].
  bool submit(int n) {
    if (phase == Phase.done || phase == Phase.right || phase == Phase.demo) {
      return false;
    }
    _idle = 0;
    _tries++;
    if (n == question.answer) {
      answers.add(n);
      phase = Phase.right;
      say = Say(
        hint == 0 && _tries == 1 ? 'right_first' : 'right',
        {'n': n},
      );
      notifyListeners();
      return true;
    }
    final m = classify(question, n);
    _mistakes.add(m);
    hint = math.max(hint, 1);
    _taskHints = math.max(_taskHints, hint);
    say = Say('wrong_${m.name}', {'n': n, 'op': question.op.symbol});
    notifyListeners();
    return false;
  }

  /// After a right answer: the next question, task, or the end.
  void next() {
    if (questionIndex + 1 < task.questions.length) {
      questionIndex++;
      _tries = 0;
      _startQuestion();
    } else {
      _finishTask(solved: true);
    }
    notifyListeners();
  }

  /// The child skips the task.
  void skip() {
    _finishTask(solved: false);
    notifyListeners();
  }

  void _finishTask({required bool solved}) {
    _results[taskIndex] = TaskResult(
      n: task.n.isEmpty ? '$number' : task.n,
      solved: solved,
      tries: math.max(1, _tries),
      hints: _taskHints,
      mistakes: _mistakes.toSet().toList(),
      seconds: _taskSeconds.round(),
    );
    _tries = 0;
    _taskHints = 0;
    _mistakes.clear();
    _taskSeconds = 0;
    answers.clear();
    if (taskIndex + 1 < tasks.length) {
      taskIndex++;
      questionIndex = 0;
      _startQuestion();
    } else {
      phase = Phase.done;
      say = const Say('done');
    }
  }

  /// One step up the hint ladder. The answer is never shown at once:
  /// a guiding remark, then the wire to look at, then a similar example,
  /// and only then the child's own example, move by move.
  HintAction nextHint() {
    hint = math.min(4, hint + 1);
    _taskHints = math.max(_taskHints, hint);
    _idle = 0;
    final q = question;
    final step = _hardStep(q);
    switch (hint) {
      case 1:
        say = _guide(q, step);
        notifyListeners();
        return const HintAction();
      case 2:
        say = step == null
            ? Say('look_row', {'row': 0})
            : Say('look_row', {'row': step.place});
        notifyListeners();
        return HintAction(row: step?.place ?? 0);
      case 3:
        final e = similar(q);
        _demo = e;
        phase = Phase.demo;
        say = Say('watch_similar', {'e': e.format()});
        notifyListeners();
        return HintAction(demo: e);
      default:
        phase = Phase.demo;
        say = const Say('watch_own');
        notifyListeners();
        return HintAction(demo: Example(_ownTerms(q)), demoIsOwn: true);
    }
  }

  Example? _demo;

  /// The demo ended: back to the child.
  void demoDone({required bool own}) {
    if (phase != Phase.demo) return;
    if (own) {
      // The abacus shows the result now.
      phase = Phase.answer;
      say = const Say('now_you_answer');
    } else {
      _askStart();
      // The demo's result stays on the abacus for the child to look at.
      say = Say('your_turn', {
        'e': _demo?.format() ?? '',
        'r': _demo?.result ?? 0,
        'n': startValue,
      });
    }
    notifyListeners();
  }

  /// The terms that show the question on the abacus.
  List<int> _ownTerms(Question q) => switch ((q.unknown, q.op)) {
    (Slot.a, Op.add) => [q.result, -q.b],
    (Slot.a, Op.sub) => [q.result, q.b],
    _ => q.terms,
  };

  /// The digit step that needs a rule (carry / borrow), if any.
  DigitStep? _hardStep(Question q) {
    try {
      final steps = planExample(Example(_ownTerms(q)), rows);
      for (final s in steps) {
        if (s.term > 0 && s.complement != null) return s;
      }
      return steps.lastOrNull;
    } catch (_) {
      return null;
    }
  }

  Say _guide(Question q, DigitStep? s) {
    if (s == null || s.term == 0) return const Say('guide_count');
    if (s.complement != null) {
      return Say(s.add ? 'guide_carry' : 'guide_borrow', {
        'd': s.digit,
        'c': s.complement!,
        'row': s.place,
      });
    }
    return Say(q.op == Op.mul ? 'guide_mul' : 'guide_tens_first', {
      'n': q.b,
      'k': q.a,
    });
  }

  /// A different example that works the same way on the abacus: the same
  /// operation, the same sizes, a carry where the original has one.
  Example similar(Question q) {
    if (q.op == Op.mul) {
      final k = q.a > 2 ? q.a - 1 : q.a + 1;
      return Example([for (var i = 0; i < k; i++) q.b]);
    }
    final own = _ownTerms(q);
    final a = own[0], b = own[1].abs(), add = own[1] >= 0;
    final carry = add ? hasCarry(a, b) : hasBorrow(a, b);
    final max = math.pow(10, math.max(2, a.toString().length)).toInt() - 1;
    for (var tries = 0; tries < 400; tries++) {
      final a2 = _near(a);
      final b2 = _near(b);
      if (a2 == a && b2 == b) continue;
      if (add) {
        if (a2 + b2 > max || hasCarry(a2, b2) != carry) continue;
        return Example([a2, b2]);
      } else {
        if (a2 - b2 < 0 || hasBorrow(a2, b2) != carry) continue;
        return Example([a2, -b2]);
      }
    }
    return Example(own);
  }

  /// A number with as many digits as [n], close to it.
  int _near(int n) {
    final len = n.toString().length;
    final lo = len == 1 ? 1 : math.pow(10, len - 1).toInt();
    final hi = math.pow(10, len).toInt() - 1;
    final spread = math.max(3, n ~/ 3);
    return (n - spread + _rnd.nextInt(2 * spread + 1)).clamp(lo, hi);
  }

  /// Advances the clocks. Returns true when the tutor offers help.
  bool tick(double dt) {
    if (phase == Phase.done) return false;
    _taskSeconds += dt;
    if (phase == Phase.demo || phase == Phase.right) return false;
    _idle += dt;
    if (!_nudged && _idle > 25) {
      _nudged = true;
      say = const Say('need_help');
      notifyListeners();
      return true;
    }
    return false;
  }

  LessonReport report() => LessonReport(
    family: packet.family,
    kid: packet.kid,
    packet: packet.id,
    results: results,
    finished: DateTime.now(),
  );
}
