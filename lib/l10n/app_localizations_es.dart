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
  String carryHint(int count) {
    return 'No hay sitio: una cuenta en la fila siguiente, aquí quitamos $count';
  }

  @override
  String borrowHint(int count) {
    return 'No alcanza: quitamos una cuenta de la fila siguiente, aquí ponemos $count';
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
}
