import 'dart:convert';
import 'dart:io';

import 'package:googleapis/firestore/v1.dart' as fs;

/// A kit activation code, as minted for the boxes.
class CodeRecord {
  CodeRecord({required this.code, this.days = 90, this.family, this.used});
  final String code;

  /// How long the code lasts once redeemed.
  final int days;

  /// The family that redeemed it (null while unused).
  String? family;
  DateTime? used;

  Map<String, Object?> toJson() => {
    'days': days,
    'family': ?family,
    if (used != null) 'used': used!.toIso8601String(),
  };

  static CodeRecord fromJson(String code, Map<String, Object?> j) => CodeRecord(
    code: code,
    days: (j['days'] as num?)?.toInt() ?? 90,
    family: j['family'] as String?,
    used: j['used'] == null ? null : DateTime.parse(j['used'] as String),
  );
}

/// What the server knows about a family: never names, only the family id
/// and the hash of its secret.
class FamilyRecord {
  FamilyRecord({
    required this.id,
    required this.keyHash,
    this.kitUntil,
    this.subUntil,
    this.store,
    this.product,
    this.token,
  });
  final String id;
  final String keyHash;

  /// Paid by kit codes up to this day.
  DateTime? kitUntil;

  /// Paid by the store subscription up to this day (the store's word: a
  /// refund or revocation moves it back).
  DateTime? subUntil;

  DateTime get until {
    final k = kitUntil, s = subUntil;
    if (k == null) return s ?? DateTime.utc(2000);
    if (s == null) return k;
    return k.isAfter(s) ? k : s;
  }

  /// Which payment carries [until].
  String get plan =>
      subUntil != null && !subUntil!.isBefore(kitUntil ?? DateTime.utc(2000))
      ? 'sub'
      : 'kit';

  /// 'play' or 'apple' when the family pays by subscription.
  String? store;
  String? product;
  String? token;

  Map<String, Object?> toJson() => {
    'keyHash': keyHash,
    if (kitUntil != null) 'kitUntil': kitUntil!.toIso8601String(),
    if (subUntil != null) 'subUntil': subUntil!.toIso8601String(),
    'store': ?store,
    'product': ?product,
    'token': ?token,
  };

  static FamilyRecord fromJson(String id, Map<String, Object?> j) =>
      FamilyRecord(
        id: id,
        keyHash: j['keyHash'] as String,
        kitUntil: j['kitUntil'] == null
            ? null
            : DateTime.parse(j['kitUntil'] as String),
        subUntil: j['subUntil'] == null
            ? null
            : DateTime.parse(j['subUntil'] as String),
        store: j['store'] as String?,
        product: j['product'] as String?,
        token: j['token'] as String?,
      );
}

class CodeTaken implements Exception {}

abstract class Store {
  Future<CodeRecord?> code(String code);

  /// Marks [code] as used by [family], atomically: of two families that
  /// redeem the same code at the same moment only one gets it. Returns the
  /// record and whether it was claimed just now (false: [family] had it
  /// already); null for an unknown code; throws [CodeTaken] when another
  /// family has it.
  Future<({CodeRecord code, bool now})?> claimCode(
    String code,
    String family,
    DateTime at,
  );
  Future<void> putCode(CodeRecord c);
  Future<FamilyRecord?> family(String id);
  Future<void> putFamily(FamilyRecord f);
}

/// In memory, for tests and a local dev server.
class MemoryStore implements Store {
  final codes = <String, CodeRecord>{};
  final families = <String, FamilyRecord>{};

  @override
  Future<CodeRecord?> code(String code) async => codes[code];
  @override
  Future<void> putCode(CodeRecord c) async => codes[c.code] = c;
  @override
  Future<({CodeRecord code, bool now})?> claimCode(
    String code,
    String family,
    DateTime at,
  ) async {
    final c = codes[code];
    if (c == null) return null;
    if (c.family != null) {
      if (c.family != family) throw CodeTaken();
      return (code: c, now: false);
    }
    c
      ..family = family
      ..used = at;
    return (code: c, now: true);
  }

  @override
  Future<FamilyRecord?> family(String id) async => families[id];
  @override
  Future<void> putFamily(FamilyRecord f) async => families[f.id] = f;
}

/// One JSON file, for a single small server (a VM). Not for Cloud Run,
/// whose disk is thrown away.
class FileStore implements Store {
  FileStore(this.path) {
    final f = File(path);
    if (f.existsSync()) {
      final j = jsonDecode(f.readAsStringSync()) as Map<String, Object?>;
      (j['codes'] as Map? ?? {}).forEach(
        (k, v) =>
            _m.codes[k as String] = CodeRecord.fromJson(k, (v as Map).cast()),
      );
      (j['families'] as Map? ?? {}).forEach(
        (k, v) => _m.families[k as String] = FamilyRecord.fromJson(
          k,
          (v as Map).cast(),
        ),
      );
    }
  }
  final String path;
  final _m = MemoryStore();

  void _save() {
    final tmp = File('$path.tmp');
    tmp.writeAsStringSync(
      jsonEncode({
        'codes': {for (final c in _m.codes.values) c.code: c.toJson()},
        'families': {for (final f in _m.families.values) f.id: f.toJson()},
      }),
    );
    tmp.renameSync(path);
  }

  @override
  Future<CodeRecord?> code(String code) => _m.code(code);
  @override
  Future<void> putCode(CodeRecord c) async {
    await _m.putCode(c);
    _save();
  }

  @override
  Future<({CodeRecord code, bool now})?> claimCode(
    String code,
    String family,
    DateTime at,
  ) async {
    final c = await _m.claimCode(code, family, at);
    if (c != null) _save();
    return c;
  }

  @override
  Future<FamilyRecord?> family(String id) => _m.family(id);
  @override
  Future<void> putFamily(FamilyRecord f) async {
    await _m.putFamily(f);
    _save();
  }
}

/// Firestore (collections `codes` and `families`), for Cloud Run.
class FirestoreStore implements Store {
  FirestoreStore(this.api, this.project);
  final fs.FirestoreApi api;
  final String project;

  String _doc(String col, String id) =>
      'projects/$project/databases/(default)/documents/$col/$id';

  Future<Map<String, Object?>?> _get(String col, String id) async {
    try {
      final d = await api.projects.databases.documents.get(_doc(col, id));
      return {
        for (final e in (d.fields ?? {}).entries)
          e.key: e.value.stringValue ?? e.value.integerValue,
      };
    } on fs.DetailedApiRequestError catch (e) {
      if (e.status == 404) return null;
      rethrow;
    }
  }

  Future<void> _put(
    String col,
    String id,
    Map<String, Object?> j, {
    String? ifUpdateTime,
  }) => api.projects.databases.documents.patch(
    fs.Document(
      fields: {
        for (final e in j.entries)
          if (e.value != null)
            e.key: e.value is int
                ? fs.Value(integerValue: '${e.value}')
                : fs.Value(stringValue: '${e.value}'),
      },
    ),
    _doc(col, id),
    currentDocument_updateTime: ifUpdateTime,
  );

  @override
  Future<CodeRecord?> code(String code) async {
    final j = await _get('codes', code);
    if (j == null) return null;
    final days = j['days'];
    return CodeRecord.fromJson(code, {
      ...j,
      'days': days is String ? int.parse(days) : days,
    });
  }

  @override
  Future<void> putCode(CodeRecord c) => _put('codes', c.code, c.toJson());

  @override
  Future<({CodeRecord code, bool now})?> claimCode(
    String code,
    String family,
    DateTime at,
  ) async {
    for (var attempt = 0; attempt < 3; attempt++) {
      final fs.Document d;
      try {
        d = await api.projects.databases.documents.get(_doc('codes', code));
      } on fs.DetailedApiRequestError catch (e) {
        if (e.status == 404) return null;
        rethrow;
      }
      final c = CodeRecord.fromJson(code, {
        for (final e in (d.fields ?? {}).entries)
          e.key: e.key == 'days'
              ? int.tryParse(e.value.integerValue ?? '') ?? 90
              : e.value.stringValue,
      });
      if (c.family != null) {
        if (c.family != family) throw CodeTaken();
        return (code: c, now: false);
      }
      c
        ..family = family
        ..used = at;
      try {
        // Only if nobody changed the code since we read it.
        await _put('codes', code, c.toJson(), ifUpdateTime: d.updateTime);
        return (code: c, now: true);
      } on fs.DetailedApiRequestError catch (e) {
        if (e.status != 400 && e.status != 409) rethrow;
      }
    }
    throw CodeTaken();
  }

  @override
  Future<FamilyRecord?> family(String id) async {
    final j = await _get('families', id);
    return j == null ? null : FamilyRecord.fromJson(id, j);
  }

  @override
  Future<void> putFamily(FamilyRecord f) => _put('families', f.id, f.toJson());
}
