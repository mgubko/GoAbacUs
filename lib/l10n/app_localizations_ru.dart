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

  @override
  String get playTooltip => 'Показать пример';

  @override
  String get stopTooltip => 'Остановить';

  @override
  String get replayTooltip => 'Показать ещё раз';

  @override
  String get tapeHint => 'Двигайте костяшки: я запишу, что вы делаете';

  @override
  String get enterExample => 'Введите пример';

  @override
  String get showButton => 'Показать';

  @override
  String get errorUnfinished => 'Закончите пример числом';

  @override
  String get errorNegative => 'Ответ не должен уходить ниже нуля';

  @override
  String get errorTooBig => 'Это число не помещается на счётах';

  @override
  String get clearing => 'Сбрасываем счёты';

  @override
  String stepSet(String number) {
    return 'Откладываем $number';
  }

  @override
  String stepAdd(String number) {
    return 'Прибавляем $number';
  }

  @override
  String stepSub(String number) {
    return 'Отнимаем $number';
  }

  @override
  String carryHint(int count) {
    return 'Не хватает места: одну костяшку на ряд выше, здесь убираем $count';
  }

  @override
  String borrowHint(int count) {
    return 'Не хватает костяшек: одну снимаем с ряда выше, здесь добавляем $count';
  }

  @override
  String get place0 => 'Единицы';

  @override
  String get place1 => 'Десятки';

  @override
  String get place2 => 'Сотни';

  @override
  String get place3 => 'Тысячи';

  @override
  String get place4 => 'Десятки тысяч';

  @override
  String get place5 => 'Сотни тысяч';

  @override
  String get place6 => 'Миллионы';

  @override
  String get place7 => 'Десятки миллионов';

  @override
  String get place8 => 'Сотни миллионов';

  @override
  String get place9 => 'Миллиарды';

  @override
  String get exercisesTooltip => 'Задания';

  @override
  String get opsAdd => 'Сложение';

  @override
  String get opsSub => 'Вычитание';

  @override
  String get opsBoth => 'Всё вместе';

  @override
  String get levelEasy => 'Простые';

  @override
  String get levelHard => 'С переносом';

  @override
  String get levelEasyHint => 'Числа до 99, без переноса через разряд';

  @override
  String get levelHardHint => 'Числа до 999, с переносом и займом';

  @override
  String get startButton => 'Начать';

  @override
  String taskNumber(int n) {
    return 'Задание $n';
  }

  @override
  String get doneButton => 'Готово';

  @override
  String get nextButton => 'Дальше';

  @override
  String get exitTooltip => 'Закончить задания';

  @override
  String get rightTitle => 'Молодец!';

  @override
  String get wrongTitle => 'Не совсем так';

  @override
  String get timeUpTitle => 'Время вышло';

  @override
  String answerIs(String answer) {
    return 'Правильный ответ: $answer';
  }

  @override
  String get showSolution => 'Показать решение';

  @override
  String streakText(int n) {
    return '$n подряд!';
  }

  @override
  String get solveHint => 'Посчитай на счётах';
}
