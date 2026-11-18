/// Why every bead move of a planned example is made, in the words of the
/// tutorial rules. The texts themselves live in the localizations.
library;

import 'plan.dart';

/// The rules taught in the tutorial.
enum Rule {
  /// Setting the first number on an empty abacus.
  set,

  /// Rule 1: there is room on the wire, push the digit's beads in.
  addFits,

  /// Rule 2: no room: one bead on the next wire, the digit's friend to ten
  /// taken away here: + 7 = + 10 − 3.
  carry,

  /// Rule 3: enough beads on the wire, take the digit's beads away.
  subFits,

  /// Rule 4: not enough beads: one bead off the next wire, the digit's
  /// friend to ten put on here: − 7 = − 10 + 3.
  borrow,
}

/// What a single move does within its rule.
enum MoveRole {
  /// The digit itself is pushed in or out on its own wire.
  direct,

  /// + 1 on a higher wire: the ten carried up (the first move of a carry).
  carryOne,

  /// A wire that held 9 gets one more: + 1 = + 10 − 9, so its 9 go back
  /// and the one moves further up (a carry through nines: 99 + 1).
  carryThroughNine,

  /// The digit's friend to ten taken away on its own wire (the last move
  /// of a carry).
  takeFriend,

  /// − 1 on a higher wire: the ten borrowed (the first move of a borrow).
  borrowOne,

  /// A wire that held 0 must give one: − 1 = − 10 + 9, so 9 come in and the
  /// one is taken further up (a borrow through zeros: 100 − 1).
  borrowThroughZero,

  /// The digit's friend to ten put on on its own wire (the last move of a
  /// borrow).
  giveFriend,
}

Rule ruleOf(DigitStep s) {
  if (s.term == 0) return Rule.set;
  if (s.complement == null) return s.add ? Rule.addFits : Rule.subFits;
  return s.add ? Rule.carry : Rule.borrow;
}

/// The role of move [i] of step [s].
MoveRole roleOf(DigitStep s, int i) {
  if (s.complement == null) return MoveRole.direct;
  if (i == s.moves.length - 1) {
    return s.add ? MoveRole.takeFriend : MoveRole.giveFriend;
  }
  if (i == 0) return s.add ? MoveRole.carryOne : MoveRole.borrowOne;
  return s.add ? MoveRole.carryThroughNine : MoveRole.borrowThroughZero;
}

/// The number of the rule as the tutorial counts them, 0 for setting the
/// first number.
int ruleNumber(Rule r) => switch (r) {
  Rule.set => 0,
  Rule.addFits => 1,
  Rule.carry => 2,
  Rule.subFits => 3,
  Rule.borrow => 4,
};
