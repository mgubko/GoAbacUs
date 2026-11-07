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

  @override
  String get menuTutorial => 'Как считать на счётах';

  @override
  String get tutorialTitle => 'Как считать на счётах';

  @override
  String tutorialShow(String example) {
    return 'Показать на счётах: $example';
  }

  @override
  String get tutorialBack => 'Назад';

  @override
  String get tutorialDone => 'Понятно!';

  @override
  String tutorialPage(int n, int total) {
    return '$n из $total';
  }

  @override
  String noteSet(String place, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count костяшек',
      few: '$count костяшки',
      one: '$count костяшку',
    );
    return '$place: придвигаем $_temp0';
  }

  @override
  String noteAddFits(String place, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count костяшек',
      few: '$count костяшки',
      one: '$count костяшку',
    );
    return 'Правило 1. $place: место есть, придвигаем $_temp0';
  }

  @override
  String noteSubFits(String place, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count костяшек',
      few: '$count костяшки',
      one: '$count костяшку',
    );
    return 'Правило 3. $place: костяшек хватает, отодвигаем $_temp0';
  }

  @override
  String noteCarryOne(String place, int digit) {
    return 'Правило 2: для $digit нет места. $place: + 1 (перенос)';
  }

  @override
  String noteCarryNine(String place) {
    return '$place: тут уже 9, а + 1 = + 10 − 9: отодвигаем 9';
  }

  @override
  String noteTakeFriend(String place, int digit, int friend) {
    return '$place: отодвигаем $friend, ведь + $digit = + 10 − $friend';
  }

  @override
  String noteBorrowOne(String place, int digit) {
    return 'Правило 4: для $digit не хватает костяшек. $place: − 1 (заём)';
  }

  @override
  String noteBorrowZero(String place) {
    return '$place: тут 0, а − 1 = − 10 + 9: придвигаем 9';
  }

  @override
  String noteGiveFriend(String place, int digit, int friend) {
    return '$place: придвигаем $friend, ведь − $digit = − 10 + $friend';
  }

  @override
  String get tutWiresTitle => 'Как устроены счёты';

  @override
  String get tutWiresBody =>
      'Каждая проволока — это разряд. Нижняя — единицы, над ней десятки, ещё выше сотни, и так далее.\n\nНа проволоке 10 костяшек. Костяшки, которые мы считаем, придвигаем влево, свободные лежат справа. Две чёрные костяшки в середине — пятая и шестая: по ним сразу видно 5, не нужно пересчитывать.';

  @override
  String get tutSetTitle => 'Как отложить число';

  @override
  String get tutSetBody =>
      'Число откладываем со старшего разряда, слева направо. 254 — это 2 сотни, 5 десятков и 4 единицы: на проволоке сотен придвигаем 2 костяшки, на проволоке десятков 5, на проволоке единиц 4.\n\nЕсли в числе 0, на этой проволоке ничего не трогаем.';

  @override
  String get tutAddTitle => 'Правило 1. Прибавляем';

  @override
  String get tutAddBody =>
      'Прибавляем тоже со старшего разряда. На проволоке может быть не больше 9 костяшек. Если и после прибавления их будет не больше 9, место есть: просто придвигаем столько костяшек, сколько в цифре.\n\n23 + 45: на десятках придвигаем 4, на единицах 5. Получилось 68.';

  @override
  String get tutFriendsTitle => 'Пары до 10';

  @override
  String get tutFriendsBody =>
      'Запомни пары чисел, которые вместе дают 10:\n1 и 9,  2 и 8,  3 и 7,  4 и 6,  5 и 5.\n\nНа счётах это видно сразу: придвинь 7 костяшек, и справа останется 3. Пары до 10 нужны для переноса и заёма.';

  @override
  String get tutCarryTitle => 'Правило 2. Перенос десятка';

  @override
  String get tutCarryBody =>
      '10 костяшек на одной проволоке — это 1 костяшка на проволоке выше. Если места не хватает, придвигаем 1 костяшку на проволоке выше, а здесь отодвигаем пару цифры до 10:\n+ 7 = + 10 − 3.\n\n5 + 7: на единицах уже 5, и 7 не поместятся. Придвигаем 1 десяток, на единицах отодвигаем 3. Получилось 12.';

  @override
  String get tutSubTitle => 'Правило 3. Отнимаем';

  @override
  String get tutSubBody =>
      'Отнимаем тоже со старшего разряда. Если придвинутых костяшек хватает, отодвигаем вправо столько, сколько в цифре.\n\n58 − 26: на десятках отодвигаем 2, на единицах 6. Осталось 32.';

  @override
  String get tutBorrowTitle => 'Правило 4. Заём десятка';

  @override
  String get tutBorrowBody =>
      'Если придвинутых костяшек меньше, чем надо отнять, занимаем десяток: отодвигаем 1 костяшку на проволоке выше, а здесь придвигаем пару цифры до 10:\n− 7 = − 10 + 3.\n\n12 − 7: на единицах только 2. Отодвигаем 1 десяток, на единицах придвигаем 3. Осталось 5.';

  @override
  String get tutChainTitle => 'Через 9 и через 0';

  @override
  String get tutChainBody =>
      'Бывает, что и на проволоке выше места нет: там уже 9. Тогда и для неё работает правило 2: + 1 = + 10 − 9. Единица уходит ещё выше, а здесь отодвигаем 9.\n\n99 + 1: сотни + 1, десятки − 9, единицы − 9. Получилось 100.\nПри вычитании так же, через 0: 100 − 1 = 99.';

  @override
  String get tutTryTitle => 'Попробуй сам';

  @override
  String get tutTryBody =>
      'Нажми на калькулятор и введи свой пример: счёты покажут решение и под ним объяснят каждый шаг по этим правилам.\n\nА в «Заданиях» решай примеры сам.';

  @override
  String get menuTilt => 'Наклон двигает костяшки';

  @override
  String get menuSound => 'Звук';

  @override
  String get menuLanguage => 'Язык';

  @override
  String get languageSystem => 'Как в системе';

  @override
  String get backToTutorial => 'Вернуться к обучению';
}
