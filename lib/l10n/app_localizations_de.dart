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

  @override
  String get playTooltip => 'Beispiel zeigen';

  @override
  String get stopTooltip => 'Anhalten';

  @override
  String get replayTooltip => 'Noch einmal zeigen';

  @override
  String get tapeHint => 'Schiebe die Perlen: Ich schreibe auf, was du tust';

  @override
  String get enterExample => 'Beispiel eingeben';

  @override
  String get showButton => 'Zeigen';

  @override
  String get errorUnfinished => 'Beende das Beispiel mit einer Zahl';

  @override
  String get errorNegative => 'Das Ergebnis darf nicht unter null fallen';

  @override
  String get errorTooBig => 'Diese Zahl passt nicht auf den Abakus';

  @override
  String get clearing => 'Abakus wird geleert';

  @override
  String stepSet(String number) {
    return '$number einstellen';
  }

  @override
  String stepAdd(String number) {
    return '$number addieren';
  }

  @override
  String stepSub(String number) {
    return '$number abziehen';
  }

  @override
  String carryHint(int count) {
    return 'Kein Platz: eine Perle in der nächsten Reihe, hier $count zurück';
  }

  @override
  String borrowHint(int count) {
    return 'Zu wenig: eine Perle aus der nächsten Reihe, hier $count dazu';
  }

  @override
  String get place0 => 'Einer';

  @override
  String get place1 => 'Zehner';

  @override
  String get place2 => 'Hunderter';

  @override
  String get place3 => 'Tausender';

  @override
  String get place4 => 'Zehntausender';

  @override
  String get place5 => 'Hunderttausender';

  @override
  String get place6 => 'Millionen';

  @override
  String get place7 => 'Zehnmillionen';

  @override
  String get place8 => 'Hundertmillionen';

  @override
  String get place9 => 'Milliarden';
}
