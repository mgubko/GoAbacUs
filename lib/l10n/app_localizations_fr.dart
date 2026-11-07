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

  @override
  String get menuTutorial => 'Compter sur le boulier';

  @override
  String get tutorialTitle => 'Compter sur le boulier';

  @override
  String tutorialShow(String example) {
    return 'Montrer sur le boulier : $example';
  }

  @override
  String get tutorialBack => 'Retour';

  @override
  String get tutorialDone => 'Compris !';

  @override
  String tutorialPage(int n, int total) {
    return '$n sur $total';
  }

  @override
  String noteSet(String place, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count boules',
      one: '1 boule',
    );
    return '$place : on pousse $_temp0';
  }

  @override
  String noteAddFits(String place, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count boules',
      one: '1 boule',
    );
    return 'Règle 1. $place : il y a de la place, on pousse $_temp0';
  }

  @override
  String noteSubFits(String place, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count boules',
      one: '1 boule',
    );
    return 'Règle 3. $place : assez de boules, on repousse $_temp0';
  }

  @override
  String noteCarryOne(String place, int digit) {
    return 'Règle 2 : pas de place pour $digit. $place : + 1 (retenue)';
  }

  @override
  String noteCarryNine(String place) {
    return '$place : déjà 9, et + 1 = + 10 − 9 : on repousse 9';
  }

  @override
  String noteTakeFriend(String place, int digit, int friend) {
    return '$place : on repousse $friend, car + $digit = + 10 − $friend';
  }

  @override
  String noteBorrowOne(String place, int digit) {
    return 'Règle 4 : pas assez de boules pour $digit. $place : − 1 (emprunt)';
  }

  @override
  String noteBorrowZero(String place) {
    return '$place : 0 ici, et − 1 = − 10 + 9 : on pousse 9';
  }

  @override
  String noteGiveFriend(String place, int digit, int friend) {
    return '$place : on pousse $friend, car − $digit = − 10 + $friend';
  }

  @override
  String get tutWiresTitle => 'Comment est fait le boulier';

  @override
  String get tutWiresBody =>
      'Chaque tige est un rang. Celle du bas, ce sont les unités, au-dessus les dizaines, puis les centaines, et ainsi de suite.\n\nIl y a 10 boules sur une tige. Les boules qu’on compte sont poussées à gauche ; les boules libres restent à droite. Les deux boules noires du milieu sont la cinquième et la sixième : elles montrent 5 d’un coup d’œil, sans recompter.';

  @override
  String get tutSetTitle => 'Comment poser un nombre';

  @override
  String get tutSetBody =>
      'On pose un nombre en commençant par le plus grand rang, de gauche à droite. 254, c’est 2 centaines, 5 dizaines et 4 unités : on pousse 2 boules sur la tige des centaines, 5 sur celle des dizaines et 4 sur celle des unités.\n\nUn 0 dans le nombre veut dire : on ne touche pas à cette tige.';

  @override
  String get tutAddTitle => 'Règle 1. Additionner';

  @override
  String get tutAddBody =>
      'On additionne aussi en commençant par le plus grand rang. Une tige porte au plus 9 boules. S’il n’y en a toujours pas plus de 9 après l’addition, il y a de la place : on pousse simplement autant de boules que dit le chiffre.\n\n23 + 45 : on pousse 4 sur les dizaines, 5 sur les unités. Cela fait 68.';

  @override
  String get tutFriendsTitle => 'Les compléments à 10';

  @override
  String get tutFriendsBody =>
      'Retiens les paires qui font 10 ensemble :\n1 et 9,  2 et 8,  3 et 7,  4 et 6,  5 et 5.\n\nLe boulier le montre tout de suite : pousse 7 boules, et il en reste 3 à droite. Ces paires servent pour la retenue et l’emprunt.';

  @override
  String get tutCarryTitle => 'Règle 2. La retenue';

  @override
  String get tutCarryBody =>
      '10 boules sur une tige valent 1 boule sur la tige du dessus. S’il n’y a pas de place, on pousse 1 boule sur la tige du dessus et on repousse ici le complément à 10 du chiffre :\n+ 7 = + 10 − 3.\n\n5 + 7 : les unités ont déjà 5, les 7 ne tiennent pas. On pousse 1 dizaine et on repousse 3 unités. Cela fait 12.';

  @override
  String get tutSubTitle => 'Règle 3. Soustraire';

  @override
  String get tutSubBody =>
      'On soustrait aussi en commençant par le plus grand rang. S’il y a assez de boules poussées, on en repousse autant que dit le chiffre.\n\n58 − 26 : on repousse 2 dizaines et 6 unités. Il reste 32.';

  @override
  String get tutBorrowTitle => 'Règle 4. L’emprunt';

  @override
  String get tutBorrowBody =>
      'S’il y a moins de boules poussées qu’il faut en enlever, on emprunte une dizaine : on repousse 1 boule sur la tige du dessus et on pousse ici le complément à 10 du chiffre :\n− 7 = − 10 + 3.\n\n12 − 7 : les unités n’ont que 2. On repousse 1 dizaine et on pousse 3 unités. Il reste 5.';

  @override
  String get tutChainTitle => 'Passer par 9 et par 0';

  @override
  String get tutChainBody =>
      'Parfois la tige du dessus n’a pas de place non plus : elle a déjà 9. Alors la règle 2 marche aussi pour elle : + 1 = + 10 − 9. Le un monte encore plus haut, et ici on repousse 9.\n\n99 + 1 : centaines + 1, dizaines − 9, unités − 9. Cela fait 100.\nPour soustraire, c’est pareil, en passant par 0 : 100 − 1 = 99.';

  @override
  String get tutTryTitle => 'À toi';

  @override
  String get tutTryBody =>
      'Touche la calculatrice et tape ton propre exemple : le boulier le résout et explique chaque étape en dessous avec ces règles.\n\nDans Exercices, c’est toi qui calcules.';

  @override
  String get menuTilt => 'L’inclinaison bouge les boules';

  @override
  String get menuSound => 'Son';
}
