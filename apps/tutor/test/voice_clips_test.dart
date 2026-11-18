import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:goabacus_tutor/speech/speech.dart';

/// The list of clips the voice tool records (tool/voice/clips.json) must
/// match the lines. After changing a line, run
/// `VOICE_DUMP=1 flutter test test/voice_clips_test.dart` and then
/// `python3 tool/voice/make_voice.py`.
void main() {
  test('tool/voice/clips.json lists every clip', () {
    final want = const JsonEncoder.withIndent('  ').convert({
      for (final l in ['ru', 'de', 'en']) l: allClips(l),
    });
    final f = File('tool/voice/clips.json');
    if (Platform.environment['VOICE_DUMP'] == '1') {
      f.writeAsStringSync('$want\n');
    }
    expect(f.readAsStringSync().trim(), want.trim(),
        reason: 'run VOICE_DUMP=1 flutter test test/voice_clips_test.dart');
  });
}
