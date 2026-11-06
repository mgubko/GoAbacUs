import 'plan.dart';

/// Writes down what the child does on the abacus: every time the beads come
/// to rest on a new number for a moment, the change becomes a term,
/// 25 + 17 − 8 = 34.
class Tape {
  /// How long the abacus must stay still on a new number before the change
  /// is written down. Long enough for a carry (+ 10, − 3) to count as one
  /// move when done without stopping.
  static const Duration settle = Duration(milliseconds: 1500);

  final terms = <int>[];
  int _recorded = 0;
  int? _candidate;
  Duration _since = Duration.zero;

  /// The value written down so far.
  int get total => _recorded;

  Example? get example => terms.isEmpty ? null : Example(List.of(terms));

  /// Starts a new record from [value] (for example after clearing).
  void reset([int value = 0]) {
    terms.clear();
    _recorded = value;
    _candidate = null;
    if (value != 0) terms.add(value);
  }

  /// Replaces the record (after an example has been played).
  void setExample(Example e) {
    terms
      ..clear()
      ..addAll(e.terms);
    _recorded = e.result;
    _candidate = null;
  }

  /// Feeds the current number. [still]: no finger on the beads and nothing
  /// moving. Returns true when a term was written.
  bool update(int value, bool still, Duration now) {
    if (!still || value == _recorded) {
      _candidate = null;
      return false;
    }
    if (_candidate != value) {
      _candidate = value;
      _since = now;
      return false;
    }
    if (now - _since < settle) return false;
    if (value == 0) {
      // Back to zero (cleared): start over rather than write "− 34".
      reset();
      return true;
    }
    if (terms.isEmpty) {
      terms.add(value);
    } else {
      terms.add(value - _recorded);
    }
    _recorded = value;
    _candidate = null;
    return true;
  }
}
