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
  String carryHint(int count) {
    return 'No room: one bead in the next row, $count back here';
  }

  @override
  String borrowHint(int count) {
    return 'Not enough: one bead off the next row, $count added here';
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
}
