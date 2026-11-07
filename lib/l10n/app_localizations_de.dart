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

  @override
  String get exercisesTooltip => 'Aufgaben';

  @override
  String get opsAdd => 'Addition';

  @override
  String get opsSub => 'Subtraktion';

  @override
  String get opsBoth => 'Beides';

  @override
  String get levelEasy => 'Leicht';

  @override
  String get levelHard => 'Mit Übertrag';

  @override
  String get levelEasyHint => 'Zahlen bis 99, ohne Übertrag';

  @override
  String get levelHardHint => 'Zahlen bis 999, mit Übertrag und Entbündeln';

  @override
  String get startButton => 'Los';

  @override
  String taskNumber(int n) {
    return 'Aufgabe $n';
  }

  @override
  String get doneButton => 'Fertig';

  @override
  String get nextButton => 'Weiter';

  @override
  String get exitTooltip => 'Aufgaben beenden';

  @override
  String get rightTitle => 'Super gemacht!';

  @override
  String get wrongTitle => 'Nicht ganz';

  @override
  String get timeUpTitle => 'Die Zeit ist um';

  @override
  String answerIs(String answer) {
    return 'Die Antwort ist $answer';
  }

  @override
  String get showSolution => 'Lösung zeigen';

  @override
  String streakText(int n) {
    return '$n hintereinander!';
  }

  @override
  String get solveHint => 'Rechne es auf dem Abakus aus';

  @override
  String get menuTutorial => 'So rechnet man mit dem Abakus';

  @override
  String get tutorialTitle => 'So rechnet man mit dem Abakus';

  @override
  String tutorialShow(String example) {
    return 'Am Abakus zeigen: $example';
  }

  @override
  String get tutorialBack => 'Zurück';

  @override
  String get tutorialDone => 'Verstanden!';

  @override
  String tutorialPage(int n, int total) {
    return '$n von $total';
  }

  @override
  String noteSet(String place, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Perlen',
      one: '1 Perle',
    );
    return '$place: $_temp0 heranschieben';
  }

  @override
  String noteAddFits(String place, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Perlen',
      one: '1 Perle',
    );
    return 'Regel 1. $place: genug Platz, $_temp0 heranschieben';
  }

  @override
  String noteSubFits(String place, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Perlen',
      one: '1 Perle',
    );
    return 'Regel 3. $place: genug Perlen, $_temp0 zurückschieben';
  }

  @override
  String noteCarryOne(String place, int digit) {
    return 'Regel 2: kein Platz für $digit. $place: + 1 (Übertrag)';
  }

  @override
  String noteCarryNine(String place) {
    return '$place: schon 9, und + 1 = + 10 − 9: 9 zurückschieben';
  }

  @override
  String noteTakeFriend(String place, int digit, int friend) {
    return '$place: $friend zurückschieben, denn + $digit = + 10 − $friend';
  }

  @override
  String noteBorrowOne(String place, int digit) {
    return 'Regel 4: zu wenig Perlen für $digit. $place: − 1 (Zehner borgen)';
  }

  @override
  String noteBorrowZero(String place) {
    return '$place: hier 0, und − 1 = − 10 + 9: 9 heranschieben';
  }

  @override
  String noteGiveFriend(String place, int digit, int friend) {
    return '$place: $friend heranschieben, denn − $digit = − 10 + $friend';
  }

  @override
  String get tutWiresTitle => 'So ist der Abakus gebaut';

  @override
  String get tutWiresBody =>
      'Jeder Draht ist eine Stelle. Der unterste sind die Einer, darüber die Zehner, dann die Hunderter und so weiter.\n\nAuf jedem Draht sind 10 Perlen. Die Perlen, die wir zählen, schieben wir nach links; die freien bleiben rechts. Die zwei schwarzen Perlen in der Mitte sind die fünfte und die sechste: Mit ihnen sieht man die 5 sofort, ohne nachzuzählen.';

  @override
  String get tutSetTitle => 'So stellt man eine Zahl ein';

  @override
  String get tutSetBody =>
      'Eine Zahl stellt man von der größten Stelle aus ein, von links nach rechts. 254 sind 2 Hunderter, 5 Zehner und 4 Einer: Auf dem Hunderterdraht 2 Perlen heranschieben, auf dem Zehnerdraht 5 und auf dem Einerdraht 4.\n\nEine 0 in der Zahl heißt: Diesen Draht nicht anfassen.';

  @override
  String get tutAddTitle => 'Regel 1. Addieren';

  @override
  String get tutAddBody =>
      'Auch beim Addieren beginnen wir mit der größten Stelle. Auf einem Draht sind höchstens 9 Perlen. Sind es nach dem Addieren immer noch nicht mehr als 9, ist genug Platz: Einfach so viele Perlen heranschieben, wie die Ziffer sagt.\n\n23 + 45: Bei den Zehnern 4 heranschieben, bei den Einern 5. Das ergibt 68.';

  @override
  String get tutFriendsTitle => 'Zehnerfreunde';

  @override
  String get tutFriendsBody =>
      'Merke dir die Paare, die zusammen 10 ergeben:\n1 und 9,  2 und 8,  3 und 7,  4 und 6,  5 und 5.\n\nAm Abakus sieht man es sofort: Schiebe 7 Perlen heran, dann bleiben rechts 3. Diese Zehnerfreunde brauchen wir zum Übertragen und zum Borgen.';

  @override
  String get tutCarryTitle => 'Regel 2. Zehnerübergang';

  @override
  String get tutCarryBody =>
      '10 Perlen auf einem Draht sind 1 Perle auf dem Draht darüber. Ist kein Platz, schieben wir 1 Perle auf dem Draht darüber heran und hier den Zehnerfreund der Ziffer zurück:\n+ 7 = + 10 − 3.\n\n5 + 7: Bei den Einern sind schon 5, da passen keine 7 mehr. 1 Zehner heranschieben, bei den Einern 3 zurückschieben. Das ergibt 12.';

  @override
  String get tutSubTitle => 'Regel 3. Subtrahieren';

  @override
  String get tutSubBody =>
      'Auch beim Subtrahieren beginnen wir mit der größten Stelle. Sind genug Perlen herangeschoben, schieben wir so viele zurück, wie die Ziffer sagt.\n\n58 − 26: Bei den Zehnern 2 zurückschieben, bei den Einern 6. Es bleiben 32.';

  @override
  String get tutBorrowTitle => 'Regel 4. Zehner borgen';

  @override
  String get tutBorrowBody =>
      'Sind weniger Perlen herangeschoben, als wir abziehen müssen, borgen wir einen Zehner: 1 Perle auf dem Draht darüber zurückschieben und hier den Zehnerfreund der Ziffer heranschieben:\n− 7 = − 10 + 3.\n\n12 − 7: Bei den Einern sind nur 2. 1 Zehner zurückschieben, bei den Einern 3 heranschieben. Es bleiben 5.';

  @override
  String get tutChainTitle => 'Über die 9, über die 0';

  @override
  String get tutChainBody =>
      'Manchmal ist auch auf dem Draht darüber kein Platz: Dort sind schon 9. Dann gilt Regel 2 auch für ihn: + 1 = + 10 − 9. Die Eins wandert noch weiter nach oben, und hier werden 9 zurückgeschoben.\n\n99 + 1: Hunderter + 1, Zehner − 9, Einer − 9. Das ergibt 100.\nBeim Subtrahieren genauso, über die 0: 100 − 1 = 99.';

  @override
  String get tutTryTitle => 'Jetzt du';

  @override
  String get tutTryBody =>
      'Tippe auf den Taschenrechner und gib ein eigenes Beispiel ein: Der Abakus rechnet es vor und erklärt darunter jeden Schritt nach diesen Regeln.\n\nUnter Aufgaben rechnest du selbst.';

  @override
  String get menuTilt => 'Neigen bewegt die Perlen';

  @override
  String get menuSound => 'Ton';
}
