import 'package:flutter/foundation.dart';

import 'speech/lines.dart';
import 'speech/speech.dart';

export 'speech/speech.dart' show Say;

/// The tutor's language. A lesson's language is the family's choice (the
/// child may hear Russian at home and learn German at school), so it is
/// not taken from the device.
final appLang = ValueNotifier<String>('ru');

const languages = {
  'ru': 'Русский',
  'de': 'Deutsch',
  'en': 'English',
  'fr': 'Français',
  'es': 'Español',
};

String tr(String key, [Map<String, Object> args = const {}]) {
  var s = line(appLang.value, key);
  args.forEach((k, v) => s = s.replaceAll('{$k}', '$v'));
  return s;
}

String saying(Say s) => render(s, appLang.value);

/// Keeps the table reachable for tests.
Map<String, Map<String, String>> get allLines => lines;
