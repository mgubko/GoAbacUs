import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tutor_tasks/tutor_tasks.dart';

/// Everything the tutor keeps, on the device only: the family key, the
/// homework received and how the lessons went.
class TutorStore {
  TutorStore._(this._p);
  final SharedPreferences _p;

  static Future<TutorStore> open() async =>
      TutorStore._(await SharedPreferences.getInstance());

  Pairing? get pairing {
    final s = _p.getString('pairing');
    return s == null ? null : Pairing.decode(s);
  }

  Future<void> setPairing(Pairing p) async {
    await _p.setString('pairing', p.encode());
  }

  /// Homework not yet done, oldest first.
  List<TaskPacket> get queue {
    final key = pairing?.key;
    if (key == null) return [];
    return [
      for (final s in _p.getStringList('queue') ?? const <String>[])
        ?TaskPacket.decode(s, key),
    ];
  }

  /// Adds a packet unless it came already. Returns false for a repeat.
  Future<bool> add(String code, TaskPacket packet) async {
    final done = _p.getStringList('done_ids') ?? [];
    if (done.contains(packet.id) || queue.any((q) => q.id == packet.id)) {
      return false;
    }
    await _p.setStringList('queue', [
      ...?_p.getStringList('queue'),
      code,
    ]);
    return true;
  }

  Future<void> finish(TaskPacket packet, LessonReport report) async {
    final key = pairing!.key;
    final rest = [
      for (final s in _p.getStringList('queue') ?? const <String>[])
        if (TaskPacket.decode(s, key)?.id != packet.id) s,
    ];
    await _p.setStringList('queue', rest);
    await _p.setStringList('done_ids', [
      ...?_p.getStringList('done_ids'),
      packet.id,
    ]);
    await _p.setString('last_report', report.encode(key));
  }

  /// When the last report was made (errors after it go into the next).
  DateTime? get lastReportAt {
    final c = lastReport;
    final key = pairing?.key;
    return c == null || key == null ? null : LessonReport.decode(c, key)?.finished;
  }

  /// The last lesson's report code, to show the parent.
  String? get lastReport => _p.getString('last_report');

  /// How far the child has moved away from the aids, per skill.
  Progress get progress {
    final s = _p.getString('progress');
    if (s == null) return Progress();
    final j = jsonDecode(s) as Map<String, Object?>;
    return Progress({for (final e in j.entries) e.key: e.value as int});
  }

  Future<void> setProgress(Progress p) =>
      _p.setString('progress', jsonEncode(p.toJson()));

  /// The device's date, never earlier than a date seen before.
  TrustedDate get date {
    final d = _p.getInt('latest_day');
    return TrustedDate(
      d == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(
              d * Duration.millisecondsPerDay,
              isUtc: true,
            ),
    );
  }

  Future<void> setDate(TrustedDate d) async {
    final l = d.latestSeen;
    if (l == null) return;
    await _p.setInt(
      'latest_day',
      l.millisecondsSinceEpoch ~/ Duration.millisecondsPerDay,
    );
  }

  /// Null when the child may open [p]: the family's licence holds today.
  Future<Refusal?> check(TaskPacket p) async {
    final key = pairing?.key;
    if (key == null) return Refusal.foreign;
    final d = date..saw(p.issued);
    final today = d.today(DateTime.now());
    await setDate(d);
    return checkLicense(p, key, trustedLicenseKeys(debug: kDebugMode), today);
  }

  String? get lang => _p.getString('lang');
  Future<void> setLang(String l) => _p.setString('lang', l);

  /// A quick summary of a stored report.
  LessonReport? decodeReport(String code) {
    final key = pairing?.key;
    return key == null ? null : LessonReport.decode(code, key);
  }
}
