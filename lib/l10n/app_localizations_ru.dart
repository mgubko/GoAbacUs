// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Russian (`ru`).
class AppLocalizationsRu extends AppLocalizations {
  AppLocalizationsRu([String locale = 'ru']) : super(locale);

  @override
  String get appTitle => 'GoAbacUs';

  @override
  String get resetTooltip => 'Сбросить счёты';

  @override
  String get tiltOn => 'Наклон: включён';

  @override
  String get tiltOff => 'Наклон: выключен';

  @override
  String get soundOn => 'Звук: включён';

  @override
  String get soundOff => 'Звук: выключен';
}
