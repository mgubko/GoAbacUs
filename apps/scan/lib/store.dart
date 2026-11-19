import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:tutor_tasks/tutor_tasks.dart';

/// The family key, the children and what was sent, on this phone only.
class FamilyStore {
  FamilyStore._(this._p);
  final SharedPreferences _p;

  static Future<FamilyStore> open() async {
    final s = FamilyStore._(await SharedPreferences.getInstance());
    if (s._p.getString('fam_id') == null) {
      final k = FamilyKey.generate();
      await s._p.setString('fam_id', k.id);
      await s._p.setString('fam_key', k.encodedSecret);
    }
    return s;
  }

  /// The family's licence (`GL1.` code), as the server signed it.
  String? get license => _p.getString('license');
  Future<void> setLicense(String code) => _p.setString('license', code);

  DateTime? get lastRefresh {
    final t = _p.getInt('license_refresh');
    return t == null ? null : DateTime.fromMillisecondsSinceEpoch(t);
  }

  Future<void> setLastRefresh(DateTime t) =>
      _p.setInt('license_refresh', t.millisecondsSinceEpoch);

  FamilyKey get key =>
      FamilyKey.decode(_p.getString('fam_id')!, _p.getString('fam_key')!);

  List<Kid> get kids => [
    for (final s in _p.getStringList('kids') ?? const <String>[])
      Kid.fromJson(jsonDecode(s) as Map<String, Object?>),
  ];

  Future<Kid> addKid(
    String name,
    int grade,
    String schoolLang,
    String homeLang, {
    Set<String> aids = const {},
  }) async {
    final ks = kids;
    final kid = Kid(
      id: ks.isEmpty ? 1 : ks.map((k) => k.id).reduce((a, b) => a > b ? a : b) + 1,
      name: name,
      grade: grade,
      schoolLang: schoolLang,
      homeLang: homeLang,
      aids: aids,
    );
    await _p.setStringList('kids', [
      for (final k in [...ks, kid]) jsonEncode(k.toJson()),
    ]);
    return kid;
  }

  /// A new packet id: the date and a running number.
  Future<String> nextPacketId() async {
    final n = (_p.getInt('seq') ?? 0) + 1;
    await _p.setInt('seq', n);
    final d = DateTime.now();
    String two(int x) => x.toString().padLeft(2, '0');
    return '${d.year}-${two(d.month)}-${two(d.day)}-$n';
  }

  /// Packets sent, newest first, as their codes.
  List<TaskPacket> get sent => [
    for (final s in _p.getStringList('sent') ?? const <String>[])
      ?TaskPacket.decode(s, key),
  ];

  Future<void> remember(String code) async {
    await _p.setStringList('sent', [
      code,
      ...?_p.getStringList('sent')?.take(29),
    ]);
  }

  List<LessonReport> get reports => [
    for (final s in _p.getStringList('reports') ?? const <String>[])
      ?LessonReport.decode(s, key),
  ];

  /// Keeps the last 50; the same report read twice is kept once.
  Future<void> addReport(String code) async {
    final old = (_p.getStringList('reports') ?? const <String>[])
        .where((c) => c != code)
        .take(49);
    await _p.setStringList('reports', [code, ...old]);
  }

  /// The whole family, for the new phone.
  FamilyTransfer exportFamily() => FamilyTransfer(
    key: key,
    kids: kids,
    license: license,
    seq: _p.getInt('seq') ?? 0,
  );

  /// Takes over the family from the old phone. This phone's own family
  /// (if it had one) is replaced, with its sent packets and reports.
  Future<void> importFamily(FamilyTransfer t) async {
    await _p.setString('fam_id', t.key.id);
    await _p.setString('fam_key', t.key.encodedSecret);
    await _p.setStringList('kids', [
      for (final k in t.kids) jsonEncode(k.toJson()),
    ]);
    if (t.license != null) {
      await _p.setString('license', t.license!);
    } else {
      await _p.remove('license');
    }
    await _p.remove('license_refresh');
    final seq = _p.getInt('seq') ?? 0;
    await _p.setInt('seq', t.seq > seq ? t.seq : seq);
    await _p.remove('sent');
    await _p.remove('reports');
  }

  String? get lang => _p.getString('lang');
  Future<void> setLang(String l) => _p.setString('lang', l);
}
