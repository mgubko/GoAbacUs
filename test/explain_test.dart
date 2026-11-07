import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:goabacus/arith/explain.dart';
import 'package:goabacus/arith/plan.dart';
import 'package:goabacus/l10n/app_localizations.dart';
import 'package:goabacus/ui/example_panel.dart';

List<MoveRole> roles(DigitStep s) => [
  for (var i = 0; i < s.moves.length; i++) roleOf(s, i),
];

void main() {
  test('rules of the steps follow the tutorial', () {
    final steps = planExample(const Example([25, 13, 7, -4, -9]), 10);
    expect(steps.map(ruleOf).toList(), [
      Rule.set, // 2 tens
      Rule.set, // 5 ones
      Rule.addFits, // + 1 ten
      Rule.addFits, // + 3 ones: 38
      Rule.carry, // + 7: 45
      Rule.subFits, // − 4: 41
      Rule.borrow, // − 9: 32
    ]);
    expect(ruleNumber(Rule.carry), 2);
    expect(ruleNumber(Rule.borrow), 4);
  });

  test('carry: + 1 on the next wire, then the friend to ten away', () {
    final s = planExample(const Example([5, 7]), 10).last;
    expect(roles(s), [MoveRole.carryOne, MoveRole.takeFriend]);
  });

  test('carry through nines', () {
    final s = planExample(const Example([99, 1]), 10).last;
    expect(s.moves, const [BeadMove(2, 1), BeadMove(1, -9), BeadMove(0, -9)]);
    expect(roles(s), [
      MoveRole.carryOne,
      MoveRole.carryThroughNine,
      MoveRole.takeFriend,
    ]);
  });

  test('borrow through zeros', () {
    final s = planExample(const Example([100, -1]), 10).last;
    expect(s.moves, const [BeadMove(2, -1), BeadMove(1, 9), BeadMove(0, 9)]);
    expect(roles(s), [
      MoveRole.borrowOne,
      MoveRole.borrowThroughZero,
      MoveRole.giveFriend,
    ]);
  });

  test('every move gets a comment in every language', () {
    final steps = planExample(
      const Example([58, 67, -99, 9, 1000, -3, 999, 1, -1000]),
      10,
    );
    for (final locale in AppLocalizations.supportedLocales) {
      final t = lookupAppLocalizations(locale);
      for (final s in steps) {
        for (var i = 0; i < s.moves.length; i++) {
          final note = moveNote(t, s, i);
          expect(note, isNotEmpty);
          expect(note, isNot(contains('{')), reason: '$locale: $note');
        }
      }
    }
    final ru = lookupAppLocalizations(const Locale('ru'));
    final s = planExample(const Example([5, 7]), 10).last;
    expect(moveNote(ru, s, 0), contains('Правило 2'));
    expect(moveNote(ru, s, 0), contains('Десятки'));
    expect(moveNote(ru, s, 1), contains('отодвигаем 3'));
    final set = planExample(const Example([3]), 10).single;
    expect(moveNote(ru, set, 0), 'Единицы: придвигаем 3 костяшки');
  });
}
