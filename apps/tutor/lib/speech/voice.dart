import 'dart:async';
import 'dart:convert';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'speech.dart';

/// The tutor's voice: plays the recorded clips of a line one after another.
/// Everything is in the app's assets, nothing is synthesised on the device
/// and nothing goes to a network. A clip that is missing is skipped, so a
/// line without a recording is only shown, not spoken.
class Voice {
  /// Made on the first clip: no player at all while the voice is off.
  AudioPlayer? _p;
  AudioPlayer get _player => _p ??= AudioPlayer()
    // Its own cache: the abacus sounds set the global prefix to their
    // package.
    ..audioCache = AudioCache(prefix: '');
  final _index = <String, Map<String, String>>{};

  /// The child or the parent turned the voice off (for the whole app).
  static final on = ValueNotifier<bool>(true);

  int _gen = 0;
  Say? _last;

  Future<Map<String, String>> _load(String lang) async {
    final have = _index[lang];
    if (have != null) return have;
    try {
      final j =
          jsonDecode(
                await rootBundle.loadString('assets/voice/$lang/index.json'),
              )
              as Map<String, Object?>;
      return _index[lang] = j.map((k, v) => MapEntry(k, v as String));
    } catch (_) {
      return _index[lang] = const {};
    }
  }

  /// Says [s], cutting off whatever was being said. The same line twice in
  /// a row is said once.
  Future<void> say(Say s, String lang) async {
    if (s == _last) return;
    _last = s;
    final gen = ++_gen;
    await _p?.stop();
    if (!on.value) return;
    final list = clips(s, lang);
    if (list == null) return;
    final index = await _load(lang);
    for (final c in list) {
      if (gen != _gen || !on.value) return;
      final file = index[c];
      if (file == null) continue;
      try {
        final done = _player.onPlayerComplete.first;
        await _player.play(AssetSource('assets/voice/$lang/$file'));
        await done.timeout(const Duration(seconds: 12));
      } catch (e) {
        debugPrint('voice: $c: $e');
      }
    }
  }

  /// Says it again (the speaker button).
  Future<void> repeat(String lang) async {
    final s = _last;
    _last = null;
    if (s != null) await say(s, lang);
  }

  Future<void> stop() async {
    _gen++;
    await _p?.stop();
  }

  void dispose() {
    _gen++;
    _p?.dispose();
  }
}
