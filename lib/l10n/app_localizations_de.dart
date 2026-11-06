// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for German (`de`).
class AppLocalizationsDe extends AppLocalizations {
  AppLocalizationsDe([String locale = 'de']) : super(locale);

  @override
  String get appTitle => 'GoAbacUs';

  @override
  String get resetTooltip => 'Abakus leeren';

  @override
  String get tiltOn => 'Neigen: an';

  @override
  String get tiltOff => 'Neigen: aus';

  @override
  String get soundOn => 'Ton: an';

  @override
  String get soundOff => 'Ton: aus';
}
