/// What the tutor says: a line of the table with its numbers, as text for
/// the screen and as a list of recorded clips for the voice.
///
/// The voice is recorded at build time (tool/voice/), never on the device:
/// each line is cut at its placeholders into fixed phrases, and numbers,
/// place names and signs are recorded once each. "Отложи на счётах" +
/// "57" + "." is played as two clips.
library;

import 'lines.dart';

/// What the tutor says, as a key into the lines and its arguments.
class Say {
  const Say(this.key, [this.args = const {}, this.then]);
  final String key;
  final Map<String, Object> args;

  /// Said right after this line ("Хорошо!" + "Теперь прибавь 5.").
  final Say? then;

  /// This line, then [next] (after whatever follows this one already).
  Say and(Say next) => Say(key, args, then == null ? next : then!.and(next));

  @override
  String toString() => '$key$args${then == null ? '' : ' + $then'}';

  @override
  bool operator ==(Object other) =>
      other is Say && other.toString() == toString();

  @override
  int get hashCode => toString().hashCode;
}

/// The lines that are spoken in a lesson (the rest are only on buttons).
const spokenKeys = {
  'hello', 'first_task', 'next_task', 'set', 'good', 'add', 'take', 'until',
  'mul', 'how_much', 'how_many_added', 'how_many_left', 'right_first',
  'right', 'wrong_offByOne', 'wrong_placeValue', 'wrong_wrongOp',
  'wrong_swapped', 'wrong_other', 'guide_count', 'guide_carry',
  'guide_borrow', 'guide_tens_first', 'guide_mul', 'look_row',
  'watch_similar', 'watch_own', 'now_you_answer', 'your_turn', 'need_help',
  'done', 'fingers_add', 'fingers_sub', 'fingers_missing', 'field_add',
  'field_bridge', 'field_sub', 'field_sub_bridge', 'field_missing',
  'field_doubles', 'field_div', 'field_rest', 'rods_add', 'rods_bridge',
  'rods_sub', 'rods_missing', 'rods_mul', 'rods_div', 'rods_rest', 'hf_mul',
  'hf_div', 'hf_rest', 'look_abacus', 'stage_look', 'stage_imagine',
  'stage_symbolic', 'check_table_add', 'check_table_mul', 'back_to_act',
  'other_aid', 'guide_bridge_field', 'guide_times_derived',
  'guide_times_derived_minus', 'guide_div', 'how_many_rest', 'div_abacus',
};

String line(String lang, String key) =>
    lines[lang]?[key] ?? lines['en']![key] ?? key;

/// "единиц", "десятков": the wire by its place.
String placeName(String lang, int row) {
  final names = switch (lang) {
    'ru' => ['единиц', 'десятков', 'сотен', 'тысяч'],
    'de' => ['Einer', 'Zehner', 'Hunderter', 'Tausender'],
    'fr' => ['unités', 'dizaines', 'centaines', 'milliers'],
    'es' => ['unidades', 'decenas', 'centenas', 'unidades de millar'],
    _ => ['ones', 'tens', 'hundreds', 'thousands'],
  };
  return row < names.length ? names[row] : '10^$row';
}

String _opWord(String lang, Object op) => switch (op) {
  '+' => line(lang, 'plus'),
  '-' => line(lang, 'minus'),
  '*' => line(lang, 'times_word'),
  ':' => line(lang, 'div_word'),
  _ => '$op',
};

/// An argument as it is written on the screen.
String _shown(String lang, String name, Object v) {
  if (name == 'row' && v is int) return placeName(lang, v);
  if (name == 'op') return _opWord(lang, v);
  if (name == 'aid') return line(lang, 'aid_$v');
  return '$v';
}

/// The text of [s] in [lang].
String render(Say s, String lang) {
  var t = line(lang, s.key);
  s.args.forEach((k, v) => t = t.replaceAll('{$k}', _shown(lang, k, v)));
  return s.then == null ? t : '$t ${render(s.then!, lang)}';
}

final _placeholder = RegExp(r'\{(\w+)\}');

/// The template cut at its placeholders: fixed phrases and argument names.
List<({String? text, String? arg})> pieces(String template) {
  final out = <({String? text, String? arg})>[];
  var at = 0;
  for (final m in _placeholder.allMatches(template)) {
    final before = _clean(template.substring(at, m.start));
    if (before != null) out.add((text: before, arg: null));
    out.add((text: null, arg: m[1]!));
    at = m.end;
  }
  final rest = _clean(template.substring(at));
  if (rest != null) out.add((text: rest, arg: null));
  return out;
}

/// A phrase worth a clip: trimmed, without a leading hyphen ("-mal"), and
/// only if it has a letter (". " alone is a pause, not a clip).
String? _clean(String s) {
  var t = s.trim();
  if (t.startsWith('-')) t = t.substring(1).trim();
  // A sentence end after a number ("{n}! С первого раза!") stays with the
  // number's clip as a pause.
  while (t.isNotEmpty && '.,:;!?'.contains(t[0])) {
    t = t.substring(1).trim();
  }
  return RegExp(r'\p{L}', unicode: true).hasMatch(t) ? t : null;
}

/// The clips for a number: 0–100 and the full hundreds are recorded;
/// 345 is "300" + "45". Null when the number has no recording.
List<String>? numberClips(int n) {
  if (n < 0) return null;
  if (n <= 100) return ['$n'];
  if (n < 1000) {
    final h = n ~/ 100 * 100;
    return [
      '$h',
      if (n % 100 != 0) '${n % 100}',
    ];
  }
  return null;
}

/// "57 + 20" or "17 : 5" spoken: numbers and sign words.
List<String>? _expressionClips(String lang, String e) {
  final out = <String>[];
  for (final m in RegExp(r'(\d[\d  ]*)|([+−\-·:])').allMatches(e)) {
    if (m[1] != null) {
      final n = int.tryParse(m[1]!.replaceAll(RegExp(r'[  ]'), ''));
      final c = n == null ? null : numberClips(n);
      if (c == null) return null;
      out.addAll(c);
    } else {
      final op = switch (m[2]) {
        '+' => '+',
        '·' => '*',
        ':' => ':',
        _ => '-',
      };
      out.add(_opWord(lang, op));
    }
  }
  return out;
}

/// The clips that say [s] in [lang], in order; null when something in it
/// was not recorded (a number over 999).
List<String>? clips(Say s, String lang) {
  final own = _clips(s, lang);
  if (own == null || s.then == null) return own;
  final rest = clips(s.then!, lang);
  return rest == null ? null : [...own, ...rest];
}

List<String>? _clips(Say s, String lang) {
  if (!spokenKeys.contains(s.key)) return const [];
  final out = <String>[];
  for (final p in pieces(line(lang, s.key))) {
    if (p.text != null) {
      out.add(p.text!);
      continue;
    }
    final v = s.args[p.arg];
    if (v == null) return null;
    if (v is int) {
      final c = numberClips(v);
      if (c == null) return null;
      out.addAll(c);
    } else if (p.arg == 'e') {
      final c = _expressionClips(lang, '$v');
      if (c == null) return null;
      out.addAll(c);
    } else {
      out.add(_shown(lang, p.arg!, v));
    }
  }
  return out;
}

/// Every clip a language needs: the fixed phrases of all spoken lines, the
/// numbers, place names, sign words and aid names. The voice tool records
/// exactly this list.
List<String> allClips(String lang) {
  final out = <String>{};
  for (final k in [...spokenKeys, 'good']) {
    if (!lines[lang]!.containsKey(k) && !lines['en']!.containsKey(k)) continue;
    for (final p in pieces(line(lang, k))) {
      if (p.text != null) out.add(p.text!);
    }
  }
  if (lines[lang]!.containsKey('good')) out.add(line(lang, 'good'));
  for (var n = 0; n <= 100; n++) {
    out.add('$n');
  }
  for (var h = 200; h < 1000; h += 100) {
    out.add('$h');
  }
  for (var r = 0; r < 4; r++) {
    out.add(placeName(lang, r));
  }
  for (final op in ['+', '-', '*', ':']) {
    out.add(_opWord(lang, op));
  }
  for (final a in [
    'fingers', 'twentyField', 'rods', 'abacus', 'hundredField',
    'additionTable', 'timesTable',
  ]) {
    out.add(line(lang, 'aid_$a'));
  }
  return out.toList()..sort();
}
