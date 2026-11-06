/// Arithmetic on the school abacus: parsing a typed example and planning
/// the bead moves, digit by digit, the way it is taught.
library;

/// Formats a number with thin groups of three: 1 234 567.
String formatNumber(int n) {
  final s = n.abs().toString();
  final b = StringBuffer(n < 0 ? '−' : '');
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) b.write(' ');
    b.write(s[i]);
  }
  return b.toString();
}

/// An example such as 25 + 17 − 8: the first number, then signed terms.
class Example {
  const Example(this.terms);

  /// terms[0] is the starting number (≥ 0); the rest are added (positive)
  /// or subtracted (negative).
  final List<int> terms;

  int get result => terms.fold(0, (a, b) => a + b);

  /// 25 + 17 − 8
  String format({int? upTo}) {
    final b = StringBuffer();
    final n = upTo == null ? terms.length : upTo + 1;
    for (var i = 0; i < n && i < terms.length; i++) {
      final t = terms[i];
      if (i == 0) {
        b.write(formatNumber(t));
      } else {
        b.write(t < 0 ? ' − ' : ' + ');
        b.write(formatNumber(t.abs()));
      }
    }
    return b.toString();
  }
}

enum ExampleError { empty, unfinished, negative, tooBig }

class ParseResult {
  const ParseResult.ok(Example this.example) : error = null;
  const ParseResult.error(ExampleError this.error) : example = null;
  final Example? example;
  final ExampleError? error;
}

/// Parses "25+17-8" (spaces, − and - allowed). Every intermediate value must
/// fit on the abacus: from 0 to [maxValue].
ParseResult parseExample(String text, {required int maxValue}) {
  final s = text.replaceAll('−', '-').replaceAll(RegExp(r'\s'), '');
  if (s.isEmpty) return const ParseResult.error(ExampleError.empty);
  final terms = <int>[];
  var sign = 1;
  var i = 0;
  var expectNumber = true;
  while (i < s.length) {
    final ch = s[i];
    if (expectNumber) {
      final m = RegExp(r'\d+').matchAsPrefix(s, i);
      if (m == null) return const ParseResult.error(ExampleError.unfinished);
      final digits = m.group(0)!;
      if (digits.length > maxValue.toString().length) {
        return const ParseResult.error(ExampleError.tooBig);
      }
      terms.add(sign * int.parse(digits));
      i = m.end;
      expectNumber = false;
    } else if (ch == '+' || ch == '-') {
      sign = ch == '+' ? 1 : -1;
      i++;
      expectNumber = true;
    } else {
      return const ParseResult.error(ExampleError.unfinished);
    }
  }
  if (expectNumber) return const ParseResult.error(ExampleError.unfinished);
  var total = 0;
  for (final t in terms) {
    total += t;
    if (total < 0) return const ParseResult.error(ExampleError.negative);
    if (total > maxValue) return const ParseResult.error(ExampleError.tooBig);
  }
  return ParseResult.ok(Example(terms));
}

/// Moves [count] beads of [row]: positive towards the counted (left) side,
/// negative back to the right.
class BeadMove {
  const BeadMove(this.row, this.count);
  final int row;
  final int count;

  @override
  bool operator ==(Object other) =>
      other is BeadMove && other.row == row && other.count == count;

  @override
  int get hashCode => Object.hash(row, count);

  @override
  String toString() => 'r$row${count > 0 ? '+' : ''}$count';
}

/// One digit of one term: e.g. "ones: + 7 = + 10 − 3".
class DigitStep {
  DigitStep({
    required this.term,
    required this.place,
    required this.digit,
    required this.add,
    required this.complement,
    required this.moves,
  });

  /// Index into [Example.terms].
  final int term;

  /// 0 = ones, 1 = tens, ...
  final int place;
  final int digit;
  final bool add;

  /// For a carry (or a borrow): 10 − digit, the beads taken away (or put
  /// back) in this place after one is added to (taken from) the next place.
  /// Null when the digit simply fits.
  final int? complement;
  final List<BeadMove> moves;
}

/// Plans the whole example on an empty abacus with [rows] wires. Each term is
/// worked from the highest digit down; a digit that does not fit uses the
/// next place: + 7 = + 10 − 3, − 7 = − 10 + 3.
List<DigitStep> planExample(Example e, int rows) {
  final digits = List.filled(rows + 1, 0);
  final steps = <DigitStep>[];

  void add(int r, int d, List<BeadMove> moves) {
    if (r >= rows) throw StateError('overflow');
    if (digits[r] + d <= 9) {
      moves.add(BeadMove(r, d));
      digits[r] += d;
    } else {
      add(r + 1, 1, moves);
      moves.add(BeadMove(r, -(10 - d)));
      digits[r] -= 10 - d;
    }
  }

  void sub(int r, int d, List<BeadMove> moves) {
    if (r >= rows) throw StateError('negative');
    if (digits[r] >= d) {
      moves.add(BeadMove(r, -d));
      digits[r] -= d;
    } else {
      sub(r + 1, 1, moves);
      moves.add(BeadMove(r, 10 - d));
      digits[r] += 10 - d;
    }
  }

  for (var t = 0; t < e.terms.length; t++) {
    final value = e.terms[t];
    final adding = value >= 0;
    final s = value.abs().toString();
    for (var k = 0; k < s.length; k++) {
      final d = int.parse(s[k]);
      if (d == 0) continue;
      final place = s.length - 1 - k;
      final fits = adding ? digits[place] + d <= 9 : digits[place] >= d;
      final moves = <BeadMove>[];
      if (adding) {
        add(place, d, moves);
      } else {
        sub(place, d, moves);
      }
      steps.add(
        DigitStep(
          term: t,
          place: place,
          digit: d,
          add: adding,
          complement: fits ? null : 10 - d,
          moves: moves,
        ),
      );
    }
  }
  return steps;
}
