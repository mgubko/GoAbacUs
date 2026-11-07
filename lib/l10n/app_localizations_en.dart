// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'GoAbacUs';

  @override
  String get resetTooltip => 'Clear the abacus';

  @override
  String get tiltOn => 'Tilt: on';

  @override
  String get tiltOff => 'Tilt: off';

  @override
  String get soundOn => 'Sound: on';

  @override
  String get soundOff => 'Sound: off';

  @override
  String get playTooltip => 'Show an example';

  @override
  String get stopTooltip => 'Stop';

  @override
  String get replayTooltip => 'Show again';

  @override
  String get tapeHint => 'Move the beads: I will write down what you do';

  @override
  String get enterExample => 'Type an example';

  @override
  String get showButton => 'Show';

  @override
  String get errorUnfinished => 'Finish the example with a number';

  @override
  String get errorNegative => 'The answer must not drop below zero';

  @override
  String get errorTooBig => 'This number does not fit on the abacus';

  @override
  String get clearing => 'Clearing the abacus';

  @override
  String stepSet(String number) {
    return 'Set $number';
  }

  @override
  String stepAdd(String number) {
    return 'Add $number';
  }

  @override
  String stepSub(String number) {
    return 'Take away $number';
  }

  @override
  String get place0 => 'Ones';

  @override
  String get place1 => 'Tens';

  @override
  String get place2 => 'Hundreds';

  @override
  String get place3 => 'Thousands';

  @override
  String get place4 => 'Ten thousands';

  @override
  String get place5 => 'Hundred thousands';

  @override
  String get place6 => 'Millions';

  @override
  String get place7 => 'Ten millions';

  @override
  String get place8 => 'Hundred millions';

  @override
  String get place9 => 'Billions';

  @override
  String get exercisesTooltip => 'Exercises';

  @override
  String get opsAdd => 'Addition';

  @override
  String get opsSub => 'Subtraction';

  @override
  String get opsBoth => 'Both';

  @override
  String get levelEasy => 'Easy';

  @override
  String get levelHard => 'With carrying';

  @override
  String get levelEasyHint => 'Numbers up to 99, no carrying';

  @override
  String get levelHardHint => 'Numbers up to 999, carrying and borrowing';

  @override
  String get startButton => 'Start';

  @override
  String taskNumber(int n) {
    return 'Task $n';
  }

  @override
  String get doneButton => 'Done';

  @override
  String get nextButton => 'Next';

  @override
  String get exitTooltip => 'Finish exercises';

  @override
  String get rightTitle => 'Well done!';

  @override
  String get wrongTitle => 'Not quite';

  @override
  String get timeUpTitle => 'Time is up';

  @override
  String answerIs(String answer) {
    return 'The answer is $answer';
  }

  @override
  String get showSolution => 'Show the solution';

  @override
  String streakText(int n) {
    return '$n in a row!';
  }

  @override
  String get solveHint => 'Work it out on the abacus';

  @override
  String get menuTutorial => 'How to count on the abacus';

  @override
  String get tutorialTitle => 'How to count on the abacus';

  @override
  String tutorialShow(String example) {
    return 'Show on the abacus: $example';
  }

  @override
  String get tutorialBack => 'Back';

  @override
  String get tutorialDone => 'Got it!';

  @override
  String tutorialPage(int n, int total) {
    return '$n of $total';
  }

  @override
  String noteSet(String place, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count beads',
      one: '1 bead',
    );
    return '$place: push in $_temp0';
  }

  @override
  String noteAddFits(String place, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count beads',
      one: '1 bead',
    );
    return 'Rule 1. $place: there is room, push in $_temp0';
  }

  @override
  String noteSubFits(String place, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count beads',
      one: '1 bead',
    );
    return 'Rule 3. $place: enough beads, push back $_temp0';
  }

  @override
  String noteCarryOne(String place, int digit) {
    return 'Rule 2: no room for $digit. $place: + 1 (carry)';
  }

  @override
  String noteCarryNine(String place) {
    return '$place: already 9, and + 1 = + 10 − 9: push back 9';
  }

  @override
  String noteTakeFriend(String place, int digit, int friend) {
    return '$place: push back $friend, since + $digit = + 10 − $friend';
  }

  @override
  String noteBorrowOne(String place, int digit) {
    return 'Rule 4: not enough beads for $digit. $place: − 1 (borrow)';
  }

  @override
  String noteBorrowZero(String place) {
    return '$place: 0 here, and − 1 = − 10 + 9: push in 9';
  }

  @override
  String noteGiveFriend(String place, int digit, int friend) {
    return '$place: push in $friend, since − $digit = − 10 + $friend';
  }

  @override
  String get tutWiresTitle => 'How the abacus works';

  @override
  String get tutWiresBody =>
      'Each wire is a place. The bottom one is the ones, above it the tens, then the hundreds, and so on.\n\nThere are 10 beads on a wire. The beads we count are pushed to the left; the free ones stay on the right. The two black beads in the middle are the fifth and the sixth: they show 5 at a glance, no need to count again.';

  @override
  String get tutSetTitle => 'How to set a number';

  @override
  String get tutSetBody =>
      'A number is set from its biggest place, left to right. 254 is 2 hundreds, 5 tens and 4 ones: push in 2 beads on the hundreds wire, 5 on the tens wire and 4 on the ones wire.\n\nA 0 in the number means: leave that wire alone.';

  @override
  String get tutAddTitle => 'Rule 1. Adding';

  @override
  String get tutAddBody =>
      'We add from the biggest place too. A wire holds at most 9 beads. If there are still no more than 9 after adding, there is room: just push in as many beads as the digit says.\n\n23 + 45: push in 4 on the tens, 5 on the ones. That makes 68.';

  @override
  String get tutFriendsTitle => 'Pairs that make 10';

  @override
  String get tutFriendsBody =>
      'Remember the pairs that together make 10:\n1 and 9,  2 and 8,  3 and 7,  4 and 6,  5 and 5.\n\nThe abacus shows it at once: push in 7 beads and 3 are left on the right. We need these pairs to carry and to borrow.';

  @override
  String get tutCarryTitle => 'Rule 2. Carrying a ten';

  @override
  String get tutCarryBody =>
      '10 beads on one wire are 1 bead on the wire above. If there is no room, push in 1 bead on the wire above and push back the digit\'s partner to 10 here:\n+ 7 = + 10 − 3.\n\n5 + 7: the ones already have 5, so 7 won\'t fit. Push in 1 ten and push back 3 on the ones. That makes 12.';

  @override
  String get tutSubTitle => 'Rule 3. Taking away';

  @override
  String get tutSubBody =>
      'We take away from the biggest place too. If there are enough beads pushed in, push back as many as the digit says.\n\n58 − 26: push back 2 on the tens and 6 on the ones. 32 are left.';

  @override
  String get tutBorrowTitle => 'Rule 4. Borrowing a ten';

  @override
  String get tutBorrowBody =>
      'If fewer beads are pushed in than you need to take away, borrow a ten: push back 1 bead on the wire above and push in the digit\'s partner to 10 here:\n− 7 = − 10 + 3.\n\n12 − 7: the ones have only 2. Push back 1 ten and push in 3 on the ones. 5 are left.';

  @override
  String get tutChainTitle => 'Past 9 and past 0';

  @override
  String get tutChainBody =>
      'Sometimes the wire above has no room either: it already has 9. Then rule 2 works for it too: + 1 = + 10 − 9. The one goes further up, and 9 are pushed back here.\n\n99 + 1: hundreds + 1, tens − 9, ones − 9. That makes 100.\nTaking away works the same way, past 0: 100 − 1 = 99.';

  @override
  String get tutTryTitle => 'Your turn';

  @override
  String get tutTryBody =>
      'Tap the calculator and type your own example: the abacus will solve it and explain every step below by these rules.\n\nIn Exercises you solve examples yourself.';

  @override
  String get menuTilt => 'Tilt moves the beads';

  @override
  String get menuSound => 'Sound';
}
