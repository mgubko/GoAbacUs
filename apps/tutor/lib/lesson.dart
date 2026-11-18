import 'dart:math' as math;

import 'package:abacus_kit/abacus_kit.dart';
import 'package:flutter/foundation.dart';
import 'package:tutor_tasks/tutor_tasks.dart';

import 'speech/speech.dart';

export 'speech/speech.dart' show Say;

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
  const HintAction({
    this.row,
    this.demo,
    this.demoIsOwn = false,
    this.picture = false,
  });

  /// Show the picture of the aid (the second step for a desk aid).
  final bool picture;

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
  Lesson(
    this.packet, {
    this.rows = 4,
    math.Random? random,
    this.kid,
    Progress? progress,
    Set<Aid>? available,
  }) : _rnd = random ?? math.Random(),
       progress = progress ?? Progress(),
       available =
           available ??
           {for (final a in kid?.aids ?? const <String>{}) ?Aid.byName(a)},
       tasks = _order(packet.tasks) {
    _results.addAll(List.filled(tasks.length, null));
    _startQuestion();
  }

  final TaskPacket packet;
  final int rows;
  final math.Random _rnd;

  /// The child, for the school language, grade and the aids at home.
  final Kid? kid;

  /// Streaks per skill: how far the child has moved away from the aids.
  final Progress progress;

  /// The aids on the desk (the screen abacus and fingers always count).
  final Set<Aid> available;

  /// The aid and stage for the current question.
  late AidChoice choice;
  final _avoid = <Aid>{};
  Mistake? _lastMistake;
  final _taskAids = <String>{};
  int _qTries = 0;

  /// A number the screen puts on the abacus by itself (to look at it).
  int? preset;

  bool get usesAbacus => choice.aid == Aid.abacus;

  /// The aid is hidden: the child imagines it, or works in the head.
  bool get aidHidden =>
      (choice.stage == Stage.imagine || choice.stage == Stage.symbolic) &&
      phase != Phase.right &&
      phase != Phase.demo;

  /// The picture shows the whole solution (after the right answer).
  bool get reveal => phase == Phase.right;

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
    if (q.unknown == Slot.rest) return q.remainder; // already there
    if (q.unknown == Slot.a) return q.result; // ? + 8 = 15: start from 15
    if (q.op == Op.mul) return q.b; // 3 · 7: start with one 7
    return q.a;
  }

  /// What the abacus shows once the operation is done.
  int get goalValue {
    final q = question;
    if (q.unknown == Slot.rest) return q.remainder;
    if (q.op == Op.div) return q.remainder; // 17 : 5 leaves 2 beads
    if (q.unknown == Slot.a) return q.a; // 15 − 8 = 7
    return q.result;
  }

  void _startQuestion() {
    hint = 0;
    _idle = 0;
    _nudged = false;
    _qTries = 0;
    _avoid.clear();
    _choose();
    _lead();
  }

  void _choose({Stage? stage}) {
    final c = chooseAid(
      question,
      available: available,
      school: kid?.schoolLang ?? packet.lang,
      grade: kid?.grade ?? 1,
      streak: progress.streak(skillOf(question)),
      avoid: _avoid,
      lastMistake: _lastMistake,
    );
    choice = stage == null ? c : AidChoice(c.aid, stage, c.skill);
    _taskAids.add('${choice.aid.name}/${choice.stage.name}');
  }

  /// The tutor's instruction for the current aid and stage.
  void _lead() {
    final q = question;
    final st = choice.stage;
    if (usesAbacus) {
      switch (st) {
        case Stage.act:
          _askStart();
        case Stage.look:
          preset = startValue;
          phase = Phase.answer;
          say = const Say('look_abacus');
        case Stage.imagine:
          phase = Phase.answer;
          say = const Say('stage_imagine', {'aid': 'abacus'});
        case Stage.symbolic:
          phase = Phase.answer;
          say = const Say('stage_symbolic');
      }
      return;
    }
    phase = Phase.answer;
    say = switch (st) {
      Stage.act => aidLine(q, choice),
      Stage.look => const Say('stage_look'),
      Stage.imagine => Say('stage_imagine', {'aid': choice.aid.name}),
      Stage.symbolic => const Say('stage_symbolic'),
    };
  }

  /// What to do with a desk aid, the way German schools use it.
  static Say aidLine(Question q, AidChoice c) {
    final bridge =
        c.skill == Skill.bridge20 || c.skill == Skill.bridge100;
    // ? + 3 = 7 is 7 − 3; 15 − ? = 9 is "from 9 up to 15".
    final ab = {'a': q.a, 'b': q.b};
    final fromResult = {'a': q.result, 'b': q.b};
    final missing = {'a': q.a, 'c': q.result};
    final missingSub = {'a': q.result, 'c': q.a};
    if (q.unknown == Slot.rest) {
      return switch (c.aid) {
        Aid.twentyField => const Say('field_rest'),
        Aid.rods => const Say('rods_rest'),
        Aid.hundredField => const Say('hf_rest'),
        _ => const Say('how_many_rest'),
      };
    }
    final kind = switch ((q.op, q.unknown)) {
      (Op.add, Slot.b) => 'missing',
      (Op.sub, Slot.b) => 'missingSub',
      (Op.add, Slot.a) => 'fromResult',
      (Op.sub, Slot.a) => 'addBack',
      (Op.add, _) => 'add',
      (Op.sub, _) => 'sub',
      (Op.mul, _) => 'mul',
      (Op.div, _) => 'div',
    };
    switch (c.aid) {
      case Aid.fingers:
        return switch (kind) {
          'missing' => Say('fingers_missing', missing),
          'missingSub' => Say('fingers_missing', missingSub),
          'fromResult' || 'sub' => Say(
            'fingers_sub',
            kind == 'sub' ? ab : fromResult,
          ),
          'addBack' => Say('fingers_add', fromResult),
          _ => Say('fingers_add', ab),
        };
      case Aid.twentyField:
        return switch (kind) {
          'missing' => Say('field_missing', missing),
          'missingSub' => Say('field_missing', missingSub),
          'fromResult' => Say('field_sub', fromResult),
          'addBack' => Say('field_add', fromResult),
          'sub' => Say(bridge ? 'field_sub_bridge' : 'field_sub', ab),
          'div' || 'mul' => Say('field_div', ab),
          _ => Say(
            c.skill == Skill.doubles
                ? 'field_doubles'
                : bridge
                ? 'field_bridge'
                : 'field_add',
            ab,
          ),
        };
      case Aid.rods:
        return switch (kind) {
          'missing' => Say('rods_missing', missing),
          'missingSub' => Say('rods_missing', missingSub),
          'fromResult' => Say('rods_sub', fromResult),
          'addBack' => Say('rods_add', fromResult),
          'sub' => Say('rods_sub', ab),
          'mul' => Say('rods_mul', ab),
          'div' => Say('rods_div', ab),
          _ => Say(bridge ? 'rods_bridge' : 'rods_add', ab),
        };
      case Aid.hundredField:
        return Say(kind == 'div' ? 'hf_div' : 'hf_mul', ab);
      case Aid.abacus:
      case Aid.additionTable:
      case Aid.timesTable:
        return const Say('stage_symbolic');
    }
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
      (_, Op.div) => Say('div_abacus', {'b': q.b}),
      (Slot.rest, _) => const Say('how_many_rest'),
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
      Slot.rest => const Say('how_many_rest'),
      Slot.result =>
        q.op == Op.div ? Say('div_abacus', {'b': q.b}) : const Say('how_much'),
    };
  }

  /// The abacus came to rest on [value].
  void onAbacus(int value) {
    if (!usesAbacus || choice.stage != Stage.act) return;
    if (phase == Phase.setStart && value == startValue) {
      _idle = 0;
      if (goalValue == startValue) {
        _askAnswer();
      } else {
        _askOperate();
        say = const Say('good').and(say);
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
    _qTries++;
    if (n == question.answer) {
      answers.add(n);
      progress.record(choice.skill, clean: _qTries == 1 && hint == 0);
      _lastMistake = null;
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
    _lastMistake = m;
    say = Say('wrong_${m.name}', {'n': n, 'op': question.op.symbol});
    if (choice.stage != Stage.act) {
      // Wartha & Schulz: when the picture in the head fails, go back to
      // the hands.
      _choose(stage: Stage.act);
      _lead();
      say = Say('wrong_${m.name}', {
        'n': n,
        'op': question.op.symbol,
      }).and(const Say('back_to_act')).and(say);
    } else if (!usesAbacus && _qTries >= 2) {
      // The same aid twice in vain: change the aid, not the volume.
      _avoid.add(choice.aid);
      _choose(stage: Stage.act);
      _lead();
      say = const Say('other_aid').and(say);
    }
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
      aids: _taskAids.toList(),
    );
    _taskAids.clear();
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
        say = _aidGuide(q) ?? _guide(q, step);
        notifyListeners();
        return const HintAction();
      case 2 when !usesAbacus || choice.stage != Stage.act:
        // Show the aid as a picture and look at it.
        if (usesAbacus) preset = startValue;
        choice = AidChoice(choice.aid, Stage.look, choice.skill);
        say = usesAbacus ? const Say('look_abacus') : const Say('stage_look');
        notifyListeners();
        return const HintAction(picture: true);
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

  /// The first hint for a desk aid, from the methodology of that aid.
  Say? _aidGuide(Question q) {
    final s = choice.skill;
    if (s == Skill.timesDerived) {
      final d = deriveTimes(q.a, q.b);
      if (d != null) {
        return Say(
          d.minus ? 'guide_times_derived_minus' : 'guide_times_derived',
          {'core': d.core, 'rest': d.rest, 'n': q.b},
        );
      }
    }
    if (s == Skill.division || s == Skill.divisionRest) {
      return Say('guide_div', {'a': q.a, 'b': q.b});
    }
    if (s == Skill.bridge20 && choice.aid == Aid.twentyField) {
      return const Say('guide_bridge_field');
    }
    return null;
  }

  /// The child asked for another aid (the "Другое средство" button).
  void switchAid() {
    if (phase == Phase.demo || phase == Phase.right || phase == Phase.done) {
      return;
    }
    _avoid.add(choice.aid);
    final before = choice.aid;
    _choose(stage: Stage.act);
    if (choice.aid == before) _avoid.clear();
    _lead();
    notifyListeners();
  }

  /// The screen took the preset number.
  void presetDone() => preset = null;

  Example? _demo;

  /// The demo ended: back to the child.
  void demoDone({required bool own}) {
    if (phase != Phase.demo) return;
    if (own) {
      // The abacus shows the result now.
      phase = Phase.answer;
      say = const Say('now_you_answer');
    } else if (!usesAbacus || choice.stage != Stage.act) {
      // Back to the chosen aid with what the example showed.
      _lead();
      say = Say('your_turn', {
        'e': _demo?.format() ?? '',
        'r': _demo?.result ?? 0,
        'n': startValue,
      });
      phase = Phase.answer;
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
    (Slot.b, Op.sub) => [q.result, q.b],
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
    if (q.op == Op.div) {
      // The same divisor, one more or one fewer group, the same remainder.
      final b = math.max(1, q.b);
      final n = q.a ~/ b > 1 ? q.a ~/ b - 1 : q.a ~/ b + 1;
      final a = n * b + q.a % b;
      return Example([a, for (var i = 0; i < n; i++) -b]);
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
