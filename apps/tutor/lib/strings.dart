import 'package:flutter/foundation.dart';

import 'lesson.dart';

/// The tutor's words. A lesson's language is the family's choice (the
/// child may hear Russian at home and learn German at school), so it is
/// not taken from the device. Voice files will be recorded from the same
/// table (`tool/voice/`).
final appLang = ValueNotifier<String>('ru');

const languages = {'ru': 'Русский', 'de': 'Deutsch', 'en': 'English'};

String tr(String key, [Map<String, Object> args = const {}]) {
  final table = _t[appLang.value] ?? _t['en']!;
  var s = table[key] ?? _t['en']![key] ?? key;
  args.forEach((k, v) => s = s.replaceAll('{$k}', '$v'));
  return s;
}

/// "единиц", "десятков" — the wire by its place.
String placeName(int row, {bool genitive = true}) {
  final names = switch (appLang.value) {
    'ru' => genitive
        ? ['единиц', 'десятков', 'сотен', 'тысяч']
        : ['единицы', 'десятки', 'сотни', 'тысячи'],
    'de' => ['Einer', 'Zehner', 'Hunderter', 'Tausender'],
    _ => ['ones', 'tens', 'hundreds', 'thousands'],
  };
  return row < names.length ? names[row] : '10^$row';
}

String saying(Say s) {
  if (s.key == 'good_then') {
    final next = s.args['next'] as String;
    return '${tr('good')} ${saying(Say(next, s.args))}';
  }
  final args = Map<String, Object>.of(s.args);
  if (args['row'] is int) args['row'] = placeName(args['row'] as int);
  if (args['op'] == '+') args['op'] = tr('plus');
  if (args['op'] == '-') args['op'] = tr('minus');
  if (args['op'] == '*') args['op'] = tr('times');
  return tr(s.key, args);
}

const _t = <String, Map<String, String>>{
  'ru': {
    'app': 'GoAbacUs Репетитор',
    'hello': 'Привет! Начнём?',
    'first_task': 'Первое задание.',
    'next_task': 'Задание {n}.',
    'set': 'Отложи на счётах {n}.',
    'good': 'Хорошо!',
    'add': 'Теперь прибавь {n}.',
    'take': 'Теперь убери {n}.',
    'until': 'Добавляй костяшки, пока не станет {n}.',
    'mul': 'Добавляй по {n}, пока не будет {k} раз по {n}.',
    'how_much': 'Сколько получилось? Набери ответ.',
    'how_many_added': 'Сколько пришлось добавить? Набери ответ.',
    'how_many_left': 'Сколько осталось? Набери ответ.',
    'right_first': 'Верно, {n}! С первого раза!',
    'right': 'Верно, {n}!',
    'wrong_offByOne': 'Почти! Пересчитай костяшки ещё раз.',
    'wrong_placeValue': 'Посмотри на десятки: не потерялся ли десяток?',
    'wrong_wrongOp': 'Посмотри на знак: здесь {op}.',
    'wrong_swapped': 'Цифры поменялись местами. Сначала десятки, потом единицы.',
    'wrong_other': 'Давай проверим на счётах.',
    'plus': 'плюс',
    'minus': 'минус',
    'times': 'умножить',
    'guide_count': 'Посчитай костяшки по одной, не торопись.',
    'guide_carry':
        'В ряду {row} не хватает места для {d}. Прибавь один в следующем ряду и убери {c} здесь.',
    'guide_borrow':
        'В ряду {row} не хватает костяшек, чтобы убрать {d}. Убери один в следующем ряду и добавь {c} здесь.',
    'guide_tens_first': 'Сначала десятки, потом единицы.',
    'guide_mul': '{k} раз по {n}: прибавляй {n} снова и снова и считай, сколько раз.',
    'look_row': 'Посмотри на ряд {row}.',
    'watch_similar': 'Смотри, как решается похожий пример: {e}.',
    'watch_own': 'Давай решим вместе. Смотри на каждое движение.',
    'now_you_answer': 'Сколько получилось? Набери ответ.',
    'your_turn': '{e} = {r}. Теперь ты: сбрось счёты и отложи {n}.',
    'need_help': 'Нужна подсказка? Нажми на лампочку.',
    'done': 'Все задания решены! Ты молодец.',
    'task_of': 'Задание {n} из {total}',
    'hint': 'Подсказка',
    'similar': 'Похожий',
    'skip': 'Пропустить',
    'clear': 'Сбросить',
    'next': 'Дальше',
    'pair_title': 'Свяжи с телефоном родителя',
    'pair_text':
        'На телефоне родителя открой GoAbacUs Scan → «Связать устройство ребёнка» и наведи камеру на код.',
    'scan': 'Сканировать код',
    'get_tasks': 'Получить задания',
    'get_tasks_text': 'Наведи камеру на код с заданиями на телефоне родителя.',
    'no_tasks': 'Заданий пока нет. Попроси родителя сфотографировать домашку.',
    'start': 'Начать',
    'free': 'Свободные счёты',
    'tasks_n': 'заданий: {n}',
    'report': 'Отчёт для родителя',
    'report_text': 'Покажи этот код родителю: он узнает, как прошло занятие.',
    'not_ours': 'Это код другой семьи или он повреждён.',
    'parts': 'Код из нескольких частей: {have} из {total}',
    'received': 'Получено заданий: {n}',
    'offline': 'Работает без интернета',
    'solved': 'Решено: {n} из {total}',
    'hints_used': 'с подсказками: {n}',
    'home': 'На главную',
    'try': 'Попробовать на примерах',
    'camera_denied': 'Нет доступа к камере.',
  },
  'de': {
    'app': 'GoAbacUs Tutor',
    'hello': 'Hallo! Wollen wir anfangen?',
    'first_task': 'Erste Aufgabe.',
    'next_task': 'Aufgabe {n}.',
    'set': 'Schiebe {n} Perlen auf dem Abakus.',
    'good': 'Gut!',
    'add': 'Jetzt plus {n}.',
    'take': 'Jetzt nimm {n} weg.',
    'until': 'Schiebe Perlen dazu, bis es {n} sind.',
    'mul': 'Schiebe immer {n} dazu, bis du {k}-mal {n} hast.',
    'how_much': 'Wie viel ist es? Tippe die Antwort.',
    'how_many_added': 'Wie viele hast du dazugeschoben? Tippe die Antwort.',
    'how_many_left': 'Wie viele sind übrig? Tippe die Antwort.',
    'right_first': 'Richtig, {n}! Gleich beim ersten Mal!',
    'right': 'Richtig, {n}!',
    'wrong_offByOne': 'Fast! Zähl die Perlen noch einmal.',
    'wrong_placeValue': 'Schau auf die Zehner: Fehlt ein Zehner?',
    'wrong_wrongOp': 'Schau auf das Zeichen: Hier steht {op}.',
    'wrong_swapped': 'Die Ziffern sind vertauscht. Erst die Zehner, dann die Einer.',
    'wrong_other': 'Lass uns am Abakus nachsehen.',
    'plus': 'plus',
    'minus': 'minus',
    'times': 'mal',
    'guide_count': 'Zähl die Perlen einzeln, ganz ruhig.',
    'guide_carry':
        'Bei den {row} ist kein Platz für {d}. Schiebe einen bei der nächsten Stange dazu und nimm hier {c} weg.',
    'guide_borrow':
        'Bei den {row} sind zu wenige Perlen, um {d} wegzunehmen. Nimm einen bei der nächsten Stange weg und schiebe hier {c} dazu.',
    'guide_tens_first': 'Erst die Zehner, dann die Einer.',
    'guide_mul': '{k}-mal {n}: Schiebe immer wieder {n} dazu und zähle, wie oft.',
    'look_row': 'Schau auf die {row}.',
    'watch_similar': 'Schau, wie eine ähnliche Aufgabe geht: {e}.',
    'watch_own': 'Wir rechnen zusammen. Schau auf jeden Schritt.',
    'now_you_answer': 'Wie viel ist es? Tippe die Antwort.',
    'your_turn': '{e} = {r}. Jetzt du: Leere den Abakus und schiebe {n}.',
    'need_help': 'Brauchst du einen Tipp? Tippe auf die Lampe.',
    'done': 'Alle Aufgaben geschafft! Super gemacht.',
    'task_of': 'Aufgabe {n} von {total}',
    'hint': 'Tipp',
    'similar': 'Ähnliche',
    'skip': 'Überspringen',
    'clear': 'Leeren',
    'next': 'Weiter',
    'pair_title': 'Mit dem Handy der Eltern verbinden',
    'pair_text':
        'Öffne auf dem Handy der Eltern GoAbacUs Scan → „Kindergerät verbinden“ und richte die Kamera auf den Code.',
    'scan': 'Code scannen',
    'get_tasks': 'Aufgaben holen',
    'get_tasks_text': 'Richte die Kamera auf den Aufgaben-Code auf dem Handy der Eltern.',
    'no_tasks': 'Noch keine Aufgaben. Bitte Mama oder Papa, die Hausaufgabe zu fotografieren.',
    'start': 'Los geht’s',
    'free': 'Freier Abakus',
    'tasks_n': 'Aufgaben: {n}',
    'report': 'Bericht für die Eltern',
    'report_text': 'Zeig diesen Code deinen Eltern: So sehen sie, wie es lief.',
    'not_ours': 'Dieser Code gehört zu einer anderen Familie oder ist beschädigt.',
    'parts': 'Code aus mehreren Teilen: {have} von {total}',
    'received': 'Aufgaben erhalten: {n}',
    'offline': 'Funktioniert ohne Internet',
    'solved': 'Gelöst: {n} von {total}',
    'hints_used': 'mit Tipps: {n}',
    'home': 'Zur Startseite',
    'try': 'Mit Beispielen ausprobieren',
    'camera_denied': 'Kein Zugriff auf die Kamera.',
  },
  'en': {
    'app': 'GoAbacUs Tutor',
    'hello': 'Hi! Shall we start?',
    'first_task': 'First task.',
    'next_task': 'Task {n}.',
    'set': 'Put {n} on the abacus.',
    'good': 'Good!',
    'add': 'Now add {n}.',
    'take': 'Now take away {n}.',
    'until': 'Add beads until there are {n}.',
    'mul': 'Add {n} at a time until you have {k} times {n}.',
    'how_much': 'How much is it? Type the answer.',
    'how_many_added': 'How many did you add? Type the answer.',
    'how_many_left': 'How many are left? Type the answer.',
    'right_first': 'Right, {n}! First time!',
    'right': 'Right, {n}!',
    'wrong_offByOne': 'Almost! Count the beads once more.',
    'wrong_placeValue': 'Look at the tens: is a ten missing?',
    'wrong_wrongOp': 'Look at the sign: it is {op} here.',
    'wrong_swapped': 'The digits swapped places. Tens first, then ones.',
    'wrong_other': 'Let’s check on the abacus.',
    'plus': 'plus',
    'minus': 'minus',
    'times': 'times',
    'guide_count': 'Count the beads one by one, take your time.',
    'guide_carry':
        'There is no room for {d} on the {row} wire. Add one on the next wire and take {c} away here.',
    'guide_borrow':
        'There are not enough beads on the {row} wire to take {d} away. Take one away on the next wire and add {c} here.',
    'guide_tens_first': 'Tens first, then ones.',
    'guide_mul': '{k} times {n}: add {n} again and again and count how many times.',
    'look_row': 'Look at the {row} wire.',
    'watch_similar': 'Watch how a similar example goes: {e}.',
    'watch_own': 'Let’s solve it together. Watch each move.',
    'now_you_answer': 'How much is it? Type the answer.',
    'your_turn': '{e} = {r}. Your turn: clear the abacus and put {n}.',
    'need_help': 'Need a hint? Tap the bulb.',
    'done': 'All tasks done! Well done.',
    'task_of': 'Task {n} of {total}',
    'hint': 'Hint',
    'similar': 'Similar',
    'skip': 'Skip',
    'clear': 'Clear',
    'next': 'Next',
    'pair_title': 'Pair with the parent’s phone',
    'pair_text':
        'On the parent’s phone open GoAbacUs Scan → “Pair the child’s device” and point the camera at the code.',
    'scan': 'Scan code',
    'get_tasks': 'Get tasks',
    'get_tasks_text': 'Point the camera at the task code on the parent’s phone.',
    'no_tasks': 'No tasks yet. Ask a parent to photograph the homework.',
    'start': 'Start',
    'free': 'Free abacus',
    'tasks_n': 'tasks: {n}',
    'report': 'Report for the parent',
    'report_text': 'Show this code to your parent: they will see how the lesson went.',
    'not_ours': 'This code belongs to another family or is damaged.',
    'parts': 'Code in several parts: {have} of {total}',
    'received': 'Tasks received: {n}',
    'offline': 'Works without internet',
    'solved': 'Solved: {n} of {total}',
    'hints_used': 'with hints: {n}',
    'home': 'Home',
    'try': 'Try with sample tasks',
    'camera_denied': 'No camera access.',
  },
};
