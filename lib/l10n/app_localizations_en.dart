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
}
