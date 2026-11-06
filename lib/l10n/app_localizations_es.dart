// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Spanish Castilian (`es`).
class AppLocalizationsEs extends AppLocalizations {
  AppLocalizationsEs([String locale = 'es']) : super(locale);

  @override
  String get appTitle => 'GoAbacUs';

  @override
  String get resetTooltip => 'Poner el ábaco a cero';

  @override
  String get tiltOn => 'Inclinación: activada';

  @override
  String get tiltOff => 'Inclinación: desactivada';

  @override
  String get soundOn => 'Sonido: activado';

  @override
  String get soundOff => 'Sonido: desactivado';
}
