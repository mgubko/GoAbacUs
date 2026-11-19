import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Errors are kept on the device only: the last few, short, without any
/// task or child data. Nothing is sent anywhere by this class; the child's
/// app passes a summary to the parent inside the lesson report, and the
/// parent decides whether to send it to support.
class ErrorLog {
  ErrorLog._(this._p);
  final SharedPreferences _p;
  static ErrorLog? _instance;
  static ErrorLog? get instance => _instance;

  static const _key = 'error_log';
  static const keep = 20;

  /// Catches every uncaught error from here on.
  static Future<void> install() async {
    final log = _instance = ErrorLog._(await SharedPreferences.getInstance());
    final previous = FlutterError.onError;
    FlutterError.onError = (d) {
      log.record(d.exception, d.stack);
      previous?.call(d);
    };
    PlatformDispatcher.instance.onError = (e, s) {
      log.record(e, s);
      return true; // handled: do not crash the app
    };
    if (kReleaseMode) {
      // A broken widget shows a calm empty box, not a red screen.
      ErrorWidget.builder = (_) => const SizedBox.shrink();
    }
  }

  List<Map<String, Object?>> get entries => [
    for (final s in _p.getStringList(_key) ?? const <String>[])
      if (_tryDecode(s) case final m?) m,
  ];

  static Map<String, Object?>? _tryDecode(String s) {
    try {
      return jsonDecode(s) as Map<String, Object?>;
    } catch (_) {
      return null;
    }
  }

  /// Short: the error type, its first line and the first frame of our own
  /// code. Error texts never hold user data in this app, but they are cut
  /// to be sure.
  static String summary(Object e, StackTrace? s) {
    final first = '$e'.split('\n').first;
    final frame = (s?.toString().split('\n') ?? const <String>[])
        .firstWhere(
          (l) => l.contains('package:goabacus') || l.contains('package:tutor_tasks'),
          orElse: () => '',
        )
        .replaceAll(RegExp(r'^#\d+\s+'), '')
        .trim();
    final text = '${e.runtimeType}: $first${frame.isEmpty ? '' : ' @ $frame'}';
    return text.length > 200 ? text.substring(0, 200) : text;
  }

  void record(Object e, StackTrace? s) {
    debugPrint('error: $e\n$s');
    final entry = jsonEncode({
      't': DateTime.now().toUtc().toIso8601String(),
      'e': summary(e, s),
    });
    final list = [entry, ...?_p.getStringList(_key)];
    unawaited(_p.setStringList(_key, list.take(keep).toList()));
  }

  /// Entries since [since], newest first.
  List<String> since(DateTime? since) => [
    for (final m in entries)
      if (since == null ||
          DateTime.tryParse('${m['t']}')?.isAfter(since) == true)
        '${m['e']}',
  ];

  Future<void> clear() => _p.remove(_key);
}
