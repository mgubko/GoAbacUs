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

  @override
  String get playTooltip => 'Montrer un exemple';

  @override
  String get stopTooltip => 'Arrêter';

  @override
  String get replayTooltip => 'Montrer encore';

  @override
  String get tapeHint => 'Déplace les boules : j’écris ce que tu fais';

  @override
  String get enterExample => 'Saisis un exemple';

  @override
  String get showButton => 'Montrer';

  @override
  String get errorUnfinished => 'Termine l’exemple par un nombre';

  @override
  String get errorNegative => 'Le résultat ne doit pas descendre sous zéro';

  @override
  String get errorTooBig => 'Ce nombre ne tient pas sur le boulier';

  @override
  String get clearing => 'On vide le boulier';

  @override
  String stepSet(String number) {
    return 'On pose $number';
  }

  @override
  String stepAdd(String number) {
    return 'On ajoute $number';
  }

  @override
  String stepSub(String number) {
    return 'On retire $number';
  }

  @override
  String carryHint(int count) {
    return 'Pas de place : une boule au rang suivant, $count en moins ici';
  }

  @override
  String borrowHint(int count) {
    return 'Pas assez : une boule en moins au rang suivant, $count en plus ici';
  }

  @override
  String get place0 => 'Unités';

  @override
  String get place1 => 'Dizaines';

  @override
  String get place2 => 'Centaines';

  @override
  String get place3 => 'Milliers';

  @override
  String get place4 => 'Dizaines de mille';

  @override
  String get place5 => 'Centaines de mille';

  @override
  String get place6 => 'Millions';

  @override
  String get place7 => 'Dizaines de millions';

  @override
  String get place8 => 'Centaines de millions';

  @override
  String get place9 => 'Milliards';

  @override
  String get exercisesTooltip => 'Exercices';

  @override
  String get opsAdd => 'Addition';

  @override
  String get opsSub => 'Soustraction';

  @override
  String get opsBoth => 'Les deux';

  @override
  String get levelEasy => 'Faciles';

  @override
  String get levelHard => 'Avec retenue';

  @override
  String get levelEasyHint => 'Nombres jusqu’à 99, sans retenue';

  @override
  String get levelHardHint => 'Nombres jusqu’à 999, avec retenues';

  @override
  String get startButton => 'Commencer';

  @override
  String taskNumber(int n) {
    return 'Exercice $n';
  }

  @override
  String get doneButton => 'Terminé';

  @override
  String get nextButton => 'Suivant';

  @override
  String get exitTooltip => 'Arrêter les exercices';

  @override
  String get rightTitle => 'Bravo !';

  @override
  String get wrongTitle => 'Pas tout à fait';

  @override
  String get timeUpTitle => 'Le temps est écoulé';

  @override
  String answerIs(String answer) {
    return 'La réponse est $answer';
  }

  @override
  String get showSolution => 'Voir la solution';

  @override
  String streakText(int n) {
    return '$n d’affilée !';
  }

  @override
  String get solveHint => 'Calcule-le sur le boulier';
}
