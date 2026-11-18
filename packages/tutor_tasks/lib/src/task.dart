/// Homework tasks as the tutor understands them.
///
/// A task never carries its answer: the exact core computes it on the
/// child's device. Each task breaks down into [Question]s, the small steps
/// the child works one by one on the abacus.
library;

enum Op {
  add('+'),
  sub('-'),
  mul('*');

  const Op(this.symbol);
  final String symbol;

  /// The sign as printed in a school book.
  String get printed => switch (this) {
    Op.add => '+',
    Op.sub => '−',
    Op.mul => '·',
  };

  static Op? parse(String s) => switch (s) {
    '+' => Op.add,
    '-' || '−' || '–' => Op.sub,
    '*' || '·' || 'x' || '×' => Op.mul,
    _ => null,
  };

  int apply(int a, int b) => switch (this) {
    Op.add => a + b,
    Op.sub => a - b,
    Op.mul => a * b,
  };
}

/// One step the child answers with a number.
class Question {
  const Question({
    required this.a,
    required this.op,
    required this.b,
    required this.answer,
    this.unknown = Slot.result,
    this.continues = false,
  });

  final int a;
  final Op op;
  final int b;

  /// What the child has to find.
  final int answer;

  /// Which place of `a op b = c` is empty.
  final Slot unknown;

  /// The abacus keeps the previous result (chains, the steps of "57 + 28").
  final bool continues;

  int get result => op.apply(a, b);

  /// The bead terms to show it on an abacus that starts from zero
  /// (or from [a], when [continues]): 3 · 7 is shown as 7 + 7 + 7.
  List<int> get terms => switch (op) {
    Op.add => [a, b],
    Op.sub => [a, -b],
    Op.mul => [b, for (var i = 1; i < a; i++) b],
  };

  /// "57 + 20 = ?", "9 + ? = 15", "? + 8 = 85"
  String format() {
    String part(Slot s, int v) => s == unknown ? '?' : '$v';
    return '${part(Slot.a, a)} ${op.printed} ${part(Slot.b, b)} = '
        '${part(Slot.result, result)}';
  }

  @override
  String toString() => format();
}

enum Slot { a, b, result }

/// The error a wrong answer most likely shows. Codes are reported to the
/// parent and drive the next exercises.
enum Mistake {
  /// One too many or too few: a counting slip.
  offByOne,

  /// Ten (or a hundred) off: the carry or borrow was forgotten.
  placeValue,

  /// The other operation was done (added instead of subtracting).
  wrongOp,

  /// The digits were swapped (91 instead of 19).
  swapped,

  /// Anything else.
  other,
}

Mistake classify(Question q, int given) {
  final d = (given - q.answer).abs();
  if (d == 1) return Mistake.offByOne;
  if (d == 10 || d == 100) return Mistake.placeValue;
  if (q.unknown == Slot.result) {
    final other = switch (q.op) {
      Op.add => q.a - q.b,
      Op.sub => q.a + q.b,
      Op.mul => q.a + q.b,
    };
    if (given == other) return Mistake.wrongOp;
  }
  final s = q.answer.toString();
  if (s.length == 2 && s[0] != s[1] && '${s[1]}${s[0]}' == '$given') {
    return Mistake.swapped;
  }
  return Mistake.other;
}

/// A homework task.
sealed class Task {
  const Task({this.n = ''});

  /// The number in the book: "1a", "3".
  final String n;

  String get type;

  /// The steps the child works through, in order.
  List<Question> get questions;

  /// What to show as the task in a list: "57 + 28 = ?".
  String format();

  /// Doubts the core has about the recognised numbers (empty when it looks
  /// right). Shown highlighted on the parent's "Is it right?" screen.
  List<String> get warnings {
    final w = <String>[];
    for (final q in questions) {
      if (q.result < 0) w.add('negative');
      if (q.a > 1000 || q.b > 1000 || q.result > 1000) w.add('too_big');
      if (q.op == Op.mul && (q.a > 10 || q.b > 10)) w.add('big_product');
    }
    return w.toSet().toList();
  }

  Map<String, Object?> toJson();

  static Task fromJson(Map<String, Object?> j) {
    final n = (j['n'] as String?) ?? '';
    switch (j['t']) {
      case 'eq':
        return EqTask.parse(j['e'] as String, n: n, child: j['child'] as int?);
      case 'steps':
        final e = EqTask.parse(j['e'] as String);
        return StepsTask(e.a!, e.op, e.b!, n: n);
      case 'chain':
        return ChainTask(
          j['start'] as int,
          [for (final s in j['steps'] as List) s as int],
          n: n,
        );
      case 'house':
        return HouseTask(
          j['roof'] as int,
          [
            for (final r in j['rows'] as List)
              [for (final c in r as List) c as int?],
          ],
          n: n,
        );
    }
    throw FormatException('unknown task type ${j['t']}');
  }
}

/// A plain example, possibly with a missing number: 8 + 5 = ?,
/// 9 + ? = 15, ? − 5 = 7, 7 · 6 = ?.
class EqTask extends Task {
  const EqTask(this.a, this.op, this.b, {this.c, super.n, this.child})
    : assert((a == null ? 1 : 0) + (b == null ? 1 : 0) + (c == null ? 1 : 0) ==
          1);

  final int? a;
  final Op op;
  final int? b;

  /// The result, when it is printed and an operand is missing instead.
  final int? c;

  /// The answer already written in the book by the child, if any. A wrong
  /// one makes the task come first in the lesson.
  final int? child;

  /// "8+5", "9+?=15", "?-5=7", "7*6".
  static EqTask parse(String e, {String n = '', int? child}) {
    final m = RegExp(
      r'^\s*(\d+|\?)\s*([+\-*·−x×])\s*(\d+|\?)\s*(?:=\s*(\d+|\?)?)?\s*$',
    ).firstMatch(e);
    if (m == null) throw FormatException('bad example "$e"');
    int? v(String? s) => s == null || s == '?' ? null : int.parse(s);
    final op = Op.parse(m[2]!)!;
    return EqTask(v(m[1]), op, v(m[3]), c: v(m[4]), n: n, child: child);
  }

  int get answer => questions.single.answer;

  @override
  String get type => 'eq';

  @override
  List<Question> get questions {
    if (a != null && b != null) {
      return [Question(a: a!, op: op, b: b!, answer: op.apply(a!, b!))];
    }
    if (a != null) {
      // 9 + ? = 15, 15 − ? = 9, 3 · ? = 21
      final x = switch (op) {
        Op.add => c! - a!,
        Op.sub => a! - c!,
        Op.mul => a! == 0 ? 0 : c! ~/ a!,
      };
      return [Question(a: a!, op: op, b: x, answer: x, unknown: Slot.b)];
    }
    // ? + 8 = 15, ? − 5 = 7, ? · 7 = 21
    final x = switch (op) {
      Op.add => c! - b!,
      Op.sub => c! + b!,
      Op.mul => b! == 0 ? 0 : c! ~/ b!,
    };
    return [Question(a: x, op: op, b: b!, answer: x, unknown: Slot.a)];
  }

  @override
  List<String> get warnings {
    final w = super.warnings;
    if (op == Op.mul && c != null) {
      final k = a ?? b!;
      if (k != 0 && c! % k != 0) w.add('not_divisible');
    }
    return w;
  }

  @override
  String format() => questions.single.format();

  String get compact {
    String s(int? v) => v == null ? '?' : '$v';
    return c == null && b != null && a != null
        ? '$a${op.symbol}$b'
        : '${s(a)}${op.symbol}${s(b)}=${s(c)}';
  }

  @override
  Map<String, Object?> toJson() => {
    't': 'eq',
    if (n.isNotEmpty) 'n': n,
    'e': compact,
    'child': ?child,
  };
}

/// "By steps": 57 + 28, then 57 + 20 and __ + 8. The tens first, then the
/// ones, exactly as on the abacus.
class StepsTask extends Task {
  const StepsTask(this.a, this.op, this.b, {super.n});
  final int a;
  final Op op;
  final int b;

  int get tens => b ~/ 10 * 10;
  int get ones => b % 10;

  @override
  String get type => 'steps';

  @override
  List<Question> get questions {
    final mid = op.apply(a, tens);
    return [
      Question(a: a, op: op, b: tens, answer: mid),
      if (ones != 0)
        Question(
          a: mid,
          op: op,
          b: ones,
          answer: op.apply(mid, ones),
          continues: true,
        ),
    ];
  }

  int get answer => op.apply(a, b);

  /// The three lines as printed in the book.
  List<String> get lines => [
    '$a ${op.printed} $b = ?',
    '$a ${op.printed} $tens = ?',
    '? ${op.printed} $ones = ?',
  ];

  @override
  String format() => '$a ${op.printed} $b = ?';

  @override
  Map<String, Object?> toJson() => {
    't': 'steps',
    if (n.isNotEmpty) 'n': n,
    'e': '$a${op.symbol}$b',
  };
}

/// A chain: 6 → +7 → −5 → +8. The abacus is never cleared between steps.
class ChainTask extends Task {
  const ChainTask(this.start, this.steps, {super.n});
  final int start;

  /// Signed: +7, −5.
  final List<int> steps;

  @override
  String get type => 'chain';

  @override
  List<Question> get questions {
    var v = start;
    final out = <Question>[];
    for (var i = 0; i < steps.length; i++) {
      final s = steps[i];
      final op = s < 0 ? Op.sub : Op.add;
      final next = v + s;
      out.add(
        Question(a: v, op: op, b: s.abs(), answer: next, continues: i > 0),
      );
      v = next;
    }
    return out;
  }

  @override
  String format() {
    final b = StringBuffer('$start');
    for (final s in steps) {
      b.write(s < 0 ? ' → −${-s}' : ' → +$s');
    }
    return b.toString();
  }

  @override
  Map<String, Object?> toJson() => {
    't': 'chain',
    if (n.isNotEmpty) 'n': n,
    'start': start,
    'steps': steps,
  };
}

/// A number house: the roof is the sum of each floor's two rooms.
class HouseTask extends Task {
  const HouseTask(this.roof, this.rows, {super.n});
  final int roof;

  /// Each floor: [left, right], one of them empty (null).
  final List<List<int?>> rows;

  @override
  String get type => 'house';

  @override
  List<Question> get questions => [
    for (final r in rows)
      if (r[0] != null && r[1] == null)
        Question(
          a: r[0]!,
          op: Op.add,
          b: roof - r[0]!,
          answer: roof - r[0]!,
          unknown: Slot.b,
        )
      else if (r[1] != null && r[0] == null)
        Question(
          a: roof - r[1]!,
          op: Op.add,
          b: r[1]!,
          answer: roof - r[1]!,
          unknown: Slot.a,
        ),
  ];

  @override
  List<String> get warnings {
    final w = super.warnings;
    for (final r in rows) {
      if (r.length != 2) w.add('bad_floor');
      for (final c in r) {
        if (c != null && c > roof) w.add('room_bigger_than_roof');
      }
      if (r.every((c) => c == null) || r.every((c) => c != null)) {
        w.add('nothing_to_find');
      }
    }
    return w.toSet().toList();
  }

  @override
  String format() =>
      '$roof: ${rows.map((r) => '${r[0] ?? '?'}|${r[1] ?? '?'}').join('  ')}';

  @override
  Map<String, Object?> toJson() => {
    't': 'house',
    if (n.isNotEmpty) 'n': n,
    'roof': roof,
    'rows': rows,
  };
}
