// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for French (`fr`).
class AppLocalizationsFr extends AppLocalizations {
  AppLocalizationsFr([String locale = 'fr']) : super(locale);

  @override
  String get appTitle => 'GoAbacUs';

  @override
  String get resetTooltip => 'Remettre le boulier à zéro';

  @override
  String get tiltOn => 'Inclinaison : activée';

  @override
  String get tiltOff => 'Inclinaison : désactivée';

  @override
  String get soundOn => 'Son : activé';

  @override
  String get soundOff => 'Son : désactivé';
}
