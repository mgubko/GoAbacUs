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

  @override
  String get playTooltip => 'Mostrar un ejemplo';

  @override
  String get stopTooltip => 'Detener';

  @override
  String get replayTooltip => 'Mostrar otra vez';

  @override
  String get tapeHint => 'Mueve las cuentas: yo anoto lo que haces';

  @override
  String get enterExample => 'Escribe un ejemplo';

  @override
  String get showButton => 'Mostrar';

  @override
  String get errorUnfinished => 'Termina el ejemplo con un número';

  @override
  String get errorNegative => 'El resultado no puede bajar de cero';

  @override
  String get errorTooBig => 'Este número no cabe en el ábaco';

  @override
  String get clearing => 'Vaciando el ábaco';

  @override
  String stepSet(String number) {
    return 'Ponemos $number';
  }

  @override
  String stepAdd(String number) {
    return 'Sumamos $number';
  }

  @override
  String stepSub(String number) {
    return 'Restamos $number';
  }

  @override
  String get place0 => 'Unidades';

  @override
  String get place1 => 'Decenas';

  @override
  String get place2 => 'Centenas';

  @override
  String get place3 => 'Millares';

  @override
  String get place4 => 'Decenas de millar';

  @override
  String get place5 => 'Centenas de millar';

  @override
  String get place6 => 'Millones';

  @override
  String get place7 => 'Decenas de millón';

  @override
  String get place8 => 'Centenas de millón';

  @override
  String get place9 => 'Millares de millón';

  @override
  String get exercisesTooltip => 'Ejercicios';

  @override
  String get opsAdd => 'Suma';

  @override
  String get opsSub => 'Resta';

  @override
  String get opsBoth => 'Las dos';

  @override
  String get levelEasy => 'Fáciles';

  @override
  String get levelHard => 'Con llevadas';

  @override
  String get levelEasyHint => 'Números hasta 99, sin llevar';

  @override
  String get levelHardHint => 'Números hasta 999, llevando y pidiendo prestado';

  @override
  String get startButton => 'Empezar';

  @override
  String taskNumber(int n) {
    return 'Ejercicio $n';
  }

  @override
  String get doneButton => 'Listo';

  @override
  String get nextButton => 'Siguiente';

  @override
  String get exitTooltip => 'Terminar los ejercicios';

  @override
  String get rightTitle => '¡Muy bien!';

  @override
  String get wrongTitle => 'No exactamente';

  @override
  String get timeUpTitle => 'Se acabó el tiempo';

  @override
  String answerIs(String answer) {
    return 'La respuesta es $answer';
  }

  @override
  String get showSolution => 'Ver la solución';

  @override
  String streakText(int n) {
    return '¡$n seguidos!';
  }

  @override
  String get solveHint => 'Resuélvelo en el ábaco';

  @override
  String get menuTutorial => 'Cómo contar con el ábaco';

  @override
  String get tutorialTitle => 'Cómo contar con el ábaco';

  @override
  String tutorialShow(String example) {
    return 'Mostrar en el ábaco: $example';
  }

  @override
  String get tutorialBack => 'Atrás';

  @override
  String get tutorialDone => '¡Entendido!';

  @override
  String tutorialPage(int n, int total) {
    return '$n de $total';
  }

  @override
  String noteSet(String place, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count cuentas',
      one: '1 cuenta',
    );
    return '$place: acercamos $_temp0';
  }

  @override
  String noteAddFits(String place, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count cuentas',
      one: '1 cuenta',
    );
    return 'Regla 1. $place: hay sitio, acercamos $_temp0';
  }

  @override
  String noteSubFits(String place, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count cuentas',
      one: '1 cuenta',
    );
    return 'Regla 3. $place: hay bastantes cuentas, apartamos $_temp0';
  }

  @override
  String noteCarryOne(String place, int digit) {
    return 'Regla 2: no hay sitio para $digit. $place: + 1 (llevada)';
  }

  @override
  String noteCarryNine(String place) {
    return '$place: ya hay 9, y + 1 = + 10 − 9: apartamos 9';
  }

  @override
  String noteTakeFriend(String place, int digit, int friend) {
    return '$place: apartamos $friend, porque + $digit = + 10 − $friend';
  }

  @override
  String noteBorrowOne(String place, int digit) {
    return 'Regla 4: no hay bastantes cuentas para $digit. $place: − 1 (préstamo)';
  }

  @override
  String noteBorrowZero(String place) {
    return '$place: aquí hay 0, y − 1 = − 10 + 9: acercamos 9';
  }

  @override
  String noteGiveFriend(String place, int digit, int friend) {
    return '$place: acercamos $friend, porque − $digit = − 10 + $friend';
  }

  @override
  String get tutWiresTitle => 'Cómo es el ábaco';

  @override
  String get tutWiresBody =>
      'Cada alambre es un orden. El de abajo son las unidades, encima las decenas, luego las centenas, y así sucesivamente.\n\nEn cada alambre hay 10 cuentas. Las cuentas que contamos se acercan a la izquierda; las libres se quedan a la derecha. Las dos cuentas negras del medio son la quinta y la sexta: con ellas se ve el 5 de un vistazo, sin volver a contar.';

  @override
  String get tutSetTitle => 'Cómo poner un número';

  @override
  String get tutSetBody =>
      'Un número se pone empezando por el orden más grande, de izquierda a derecha. 254 son 2 centenas, 5 decenas y 4 unidades: en el alambre de las centenas acercamos 2 cuentas, en el de las decenas 5 y en el de las unidades 4.\n\nUn 0 en el número quiere decir: ese alambre no se toca.';

  @override
  String get tutAddTitle => 'Regla 1. Sumar';

  @override
  String get tutAddBody =>
      'También sumamos empezando por el orden más grande. En un alambre caben como mucho 9 cuentas. Si después de sumar sigue habiendo 9 o menos, hay sitio: acercamos tantas cuentas como dice la cifra.\n\n23 + 45: en las decenas acercamos 4, en las unidades 5. Son 68.';

  @override
  String get tutFriendsTitle => 'Parejas del 10';

  @override
  String get tutFriendsBody =>
      'Recuerda las parejas que juntas suman 10:\n1 y 9,  2 y 8,  3 y 7,  4 y 6,  5 y 5.\n\nEn el ábaco se ve enseguida: acerca 7 cuentas y a la derecha quedan 3. Estas parejas sirven para llevar y para pedir prestado.';

  @override
  String get tutCarryTitle => 'Regla 2. Llevarse una decena';

  @override
  String get tutCarryBody =>
      '10 cuentas en un alambre son 1 cuenta en el alambre de arriba. Si no hay sitio, acercamos 1 cuenta en el alambre de arriba y aquí apartamos la pareja del 10 de la cifra:\n+ 7 = + 10 − 3.\n\n5 + 7: en las unidades ya hay 5 y no caben 7. Acercamos 1 decena y en las unidades apartamos 3. Son 12.';

  @override
  String get tutSubTitle => 'Regla 3. Restar';

  @override
  String get tutSubBody =>
      'También restamos empezando por el orden más grande. Si hay bastantes cuentas acercadas, apartamos tantas como dice la cifra.\n\n58 − 26: en las decenas apartamos 2, en las unidades 6. Quedan 32.';

  @override
  String get tutBorrowTitle => 'Regla 4. Pedir prestada una decena';

  @override
  String get tutBorrowBody =>
      'Si hay menos cuentas acercadas de las que hay que quitar, pedimos prestada una decena: apartamos 1 cuenta en el alambre de arriba y aquí acercamos la pareja del 10 de la cifra:\n− 7 = − 10 + 3.\n\n12 − 7: en las unidades solo hay 2. Apartamos 1 decena y en las unidades acercamos 3. Quedan 5.';

  @override
  String get tutChainTitle => 'Pasar por el 9 y el 0';

  @override
  String get tutChainBody =>
      'A veces tampoco hay sitio en el alambre de arriba: ya tiene 9. Entonces la regla 2 vale también para él: + 1 = + 10 − 9. El uno sube todavía más, y aquí apartamos 9.\n\n99 + 1: centenas + 1, decenas − 9, unidades − 9. Son 100.\nAl restar es igual, pasando por el 0: 100 − 1 = 99.';

  @override
  String get tutTryTitle => 'Ahora tú';

  @override
  String get tutTryBody =>
      'Toca la calculadora y escribe tu propio ejemplo: el ábaco lo resuelve y debajo explica cada paso con estas reglas.\n\nEn Ejercicios resuelves tú los ejemplos.';

  @override
  String get menuTilt => 'Inclinar mueve las cuentas';

  @override
  String get menuSound => 'Sonido';

  @override
  String get menuLanguage => 'Idioma';

  @override
  String get languageSystem => 'Como en el dispositivo';

  @override
  String get backToTutorial => 'Volver al tutorial';
}
