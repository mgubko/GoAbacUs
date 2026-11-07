import 'dart:math' as math;

import '../physics/abacus_physics.dart';
import 'plan.dart';

/// Plays an example on the abacus with an invisible finger that pushes the
/// beads through the physics, so the moves look and sound real.
class ExamplePlayer {
  ExamplePlayer(this.physics, this.example)
    : steps = planExample(example, physics.config.rows);

  final AbacusPhysics physics;
  final Example example;
  final List<DigitStep> steps;

  /// Key of the invisible finger in [AbacusPhysics.grabs].
  static const int finger = -1;

  /// Finger speed along the wire, m/s: a calm, clearly visible push.
  static const double speed = 0.32;
  // Pauses leave time to read the comment on the move that comes next.
  static const double _beforeTerm = 1.4;
  static const double _beforeStep = 1.1;
  static const double _beforeMove = 1.0;
  static const double _maxHold = 1.0;

  _Phase _phase = _Phase.clearing;
  double _time = 0;
  int _step = 0;
  int _move = 0;
  int _expected = 0;
  double _goal = 0;
  double _goalCentre = 0;
  int _bead = 0;

  /// Moves that needed the safety net / ran out of time (for tests).
  int fixes = 0;
  int timeouts = 0;

  bool get done => _phase == _Phase.done;

  /// The digit step being shown, or null while clearing / when done.
  DigitStep? get step =>
      _phase == _Phase.clearing || done ? null : steps[_step];

  /// Index of the term being worked, -1 while clearing.
  int get term => _phase == _Phase.clearing
      ? -1
      : done
      ? example.terms.length - 1
      : steps[_step].term;

  /// Index of the move within [step] shown (or about to be made) now.
  int get move => _move;

  /// Row the finger works on now.
  int? get row => step?.moves[_move].row;

  /// Finger position along the wire in metres, when it touches a bead.
  double? get fingerX => physics.grabs[finger]?.target;
  int? get fingerRow => physics.grabs[finger]?.row;

  void cancel() {
    physics.grabs.remove(finger);
    _phase = _Phase.done;
  }

  /// Advances the show by [dt] seconds. Call before stepping the physics.
  void update(double dt) {
    _time += dt;
    switch (_phase) {
      case _Phase.clearing:
        if (_time < 0.05) {
          if (physics.value != 0) physics.sweepRight();
          return;
        }
        if (physics.isAtRest || _time > 2.5) {
          if (physics.value != 0) physics.clear();
          if (steps.isEmpty) {
            _phase = _Phase.done;
          } else {
            _wait(_beforeStep);
          }
        }
      case _Phase.waiting:
        if (_time >= _pause) _startMove();
      case _Phase.pushing:
        final g = physics.grabs[finger]!;
        final dir = (_goal - g.target).sign;
        final next = g.target + dir * speed * dt;
        if ((next - _goal) * dir >= 0) {
          g.target = _goal;
          g.targetVelocity = 0;
          _phase = _Phase.holding;
          _time = 0;
        } else {
          g.target = next;
          g.targetVelocity = dir * speed;
        }
      case _Phase.holding:
        final r = physics.grabs[finger]!.row;
        final close =
            (physics.x[r][_bead] - _goalCentre).abs() < 0.0008 &&
            physics.v[r][_bead].abs() < 0.02;
        if (close || _time > _maxHold) {
          if (!close) timeouts++;
          _finishMove(r);
        }
      case _Phase.done:
        break;
    }
  }

  double _pause = 0;

  void _wait(double seconds) {
    _phase = _Phase.waiting;
    _pause = seconds;
    _time = 0;
  }

  void _startMove() {
    final m = steps[_step].moves[_move];
    final c = physics.config;
    final n = c.beadsPerRow;
    final counted = physics.countedBeads(m.row);
    _expected = (counted + m.count).clamp(0, n);
    final k = _expected - counted;
    if (k == 0) {
      _next();
      return;
    }
    if (k > 0) {
      // Push from the right edge of the k-th free bead: it carries the
      // ones in front of it to the counted side.
      _bead = counted + k - 1;
      _goalCentre = c.halfBead + _bead * c.beadLength;
      final start = physics.x[m.row][_bead] + c.halfBead;
      _goal = _goalCentre + c.halfBead;
      physics.grabs[finger] = Grab(m.row, _bead, -c.halfBead, start);
    } else {
      _bead = counted + k;
      _goalCentre = c.wireLength - c.halfBead - (n - 1 - _bead) * c.beadLength;
      final start = physics.x[m.row][_bead] - c.halfBead;
      _goal = _goalCentre - c.halfBead;
      physics.grabs[finger] = Grab(m.row, _bead, c.halfBead, start);
    }
    _phase = _Phase.pushing;
    _time = 0;
  }

  void _finishMove(int row) {
    physics.grabs.remove(finger);
    // A safety net: should the beads not land where planned, put them there.
    if (physics.countedBeads(row) != _expected) {
      fixes++;
      physics.setRowCount(row, _expected);
    }
    _next();
  }

  void _next() {
    _move++;
    if (_move < steps[_step].moves.length) {
      _wait(_beforeMove);
      return;
    }
    _move = 0;
    _step++;
    if (_step >= steps.length) {
      _step = steps.length - 1;
      _phase = _Phase.done;
      return;
    }
    final newTerm = steps[_step].term != steps[_step - 1].term;
    _wait(newTerm ? _beforeTerm : _beforeStep);
  }

  /// Rough length of the show in seconds, for tests.
  double get estimate {
    var t = 0.0;
    for (final s in steps) {
      for (final m in s.moves) {
        t += _beforeMove + m.count.abs() * 0.02 / speed + 0.3;
      }
      t += _beforeTerm + _beforeStep;
    }
    return math.max(t, 1) + 5;
  }
}

enum _Phase { clearing, waiting, pushing, holding, done }
