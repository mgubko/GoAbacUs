/// What travels between the parent's phone and the child's device: the
/// pairing code, task packets and lesson reports. Everything fits in QR
/// codes, so the child's device never needs a network.
///
/// A packet is compact JSON, deflated, base64url-encoded and signed with
/// the family key (HMAC-SHA256, 12 bytes). The child's app accepts only
/// packets of its own family.
library;

import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:crypto/crypto.dart';

import 'task.dart';

/// A shared secret created on the parent's phone, handed over once by the
/// pairing QR code.
class FamilyKey {
  FamilyKey(this.id, this.secret);

  /// Random, so that the parent can tell families apart (4 bytes, hex).
  final String id;
  final Uint8List secret;

  factory FamilyKey.generate([math.Random? random]) {
    final r = random ?? math.Random.secure();
    final id = List.generate(
      4,
      (_) => r.nextInt(256).toRadixString(16).padLeft(2, '0'),
    ).join();
    return FamilyKey(
      id,
      Uint8List.fromList(List.generate(16, (_) => r.nextInt(256))),
    );
  }

  String get encodedSecret => _b64(secret);

  factory FamilyKey.decode(String id, String secret) =>
      FamilyKey(id, _unb64(secret));

  List<int> sign(List<int> data) =>
      Hmac(sha256, secret).convert(data).bytes.sublist(0, 12);
}

/// The child's profile, as the parent sets it up.
class Kid {
  const Kid({
    required this.id,
    required this.name,
    this.grade = 1,
    this.schoolLang = 'de',
    this.homeLang = 'ru',
  });
  final int id;
  final String name;
  final int grade;
  final String schoolLang;
  final String homeLang;

  Map<String, Object?> toJson() => {
    'id': id,
    'name': name,
    'grade': grade,
    'sl': schoolLang,
    'hl': homeLang,
  };

  static Kid fromJson(Map<String, Object?> j) => Kid(
    id: j['id'] as int,
    name: j['name'] as String,
    grade: (j['grade'] as int?) ?? 1,
    schoolLang: (j['sl'] as String?) ?? 'de',
    homeLang: (j['hl'] as String?) ?? 'ru',
  );
}

/// The pairing code: `GAP1.<payload>`. It holds the key itself, so it is
/// shown only on the parent's screen, next to the child's device.
class Pairing {
  const Pairing(this.key, this.kid);
  final FamilyKey key;
  final Kid kid;

  static const prefix = 'GAP1.';

  String encode() =>
      prefix +
      _b64(
        utf8.encode(
          jsonEncode({
            'fam': key.id,
            'key': key.encodedSecret,
            'kid': kid.toJson(),
          }),
        ),
      );

  static Pairing? decode(String text) {
    if (!text.startsWith(prefix)) return null;
    try {
      final j =
          jsonDecode(utf8.decode(_unb64(text.substring(prefix.length))))
              as Map<String, Object?>;
      return Pairing(
        FamilyKey.decode(j['fam'] as String, j['key'] as String),
        Kid.fromJson(j['kid'] as Map<String, Object?>),
      );
    } catch (_) {
      return null;
    }
  }
}

/// Homework for one child: one or several book pages.
class TaskPacket {
  TaskPacket({
    required this.family,
    required this.kid,
    required this.id,
    required this.tasks,
    this.lang = 'de',
    this.source = '',
  });

  final String family;
  final int kid;

  /// "2026-11-18-1": date and a running number, unique per family.
  final String id;
  final String lang;

  /// What the parent called it: "Mathe S. 34".
  final String source;
  final List<Task> tasks;

  Map<String, Object?> toJson() => {
    'v': 1,
    'fam': family,
    'kid': kid,
    'id': id,
    'lang': lang,
    if (source.isNotEmpty) 'src': source,
    'tasks': [for (final t in tasks) t.toJson()],
  };

  static TaskPacket fromJson(Map<String, Object?> j) => TaskPacket(
    family: j['fam'] as String,
    kid: j['kid'] as int,
    id: j['id'] as String,
    lang: (j['lang'] as String?) ?? 'de',
    source: (j['src'] as String?) ?? '',
    tasks: [
      for (final t in j['tasks'] as List) Task.fromJson(t as Map<String, Object?>),
    ],
  );

  static const prefix = 'GA1.';

  String encode(FamilyKey key) => _seal(prefix, toJson(), key);

  /// Null when the text is not a packet of this family or was changed.
  static TaskPacket? decode(String text, FamilyKey key) {
    final j = _open(prefix, text, key);
    if (j == null || j['fam'] != key.id) return null;
    try {
      return fromJson(j);
    } catch (_) {
      return null;
    }
  }
}

/// How one task went.
class TaskResult {
  const TaskResult({
    required this.n,
    required this.solved,
    this.tries = 1,
    this.hints = 0,
    this.mistakes = const [],
    this.seconds = 0,
  });

  final String n;
  final bool solved;
  final int tries;

  /// The highest step of the hint ladder that was needed (0 = none).
  final int hints;
  final List<Mistake> mistakes;
  final int seconds;

  Map<String, Object?> toJson() => {
    'n': n,
    'ok': solved ? 1 : 0,
    if (tries != 1) 'tr': tries,
    if (hints != 0) 'h': hints,
    if (mistakes.isNotEmpty) 'm': [for (final m in mistakes) m.index],
    if (seconds != 0) 's': seconds,
  };

  static TaskResult fromJson(Map<String, Object?> j) => TaskResult(
    n: j['n'] as String,
    solved: j['ok'] == 1,
    tries: (j['tr'] as int?) ?? 1,
    hints: (j['h'] as int?) ?? 0,
    mistakes: [
      for (final m in (j['m'] as List?) ?? const []) Mistake.values[m as int],
    ],
    seconds: (j['s'] as int?) ?? 0,
  );
}

/// The lesson summary the child's device shows as a QR code for the parent.
class LessonReport {
  LessonReport({
    required this.family,
    required this.kid,
    required this.packet,
    required this.results,
    required this.finished,
  });

  final String family;
  final int kid;
  final String packet;
  final List<TaskResult> results;
  final DateTime finished;

  static const prefix = 'GR1.';

  Map<String, Object?> toJson() => {
    'v': 1,
    'fam': family,
    'kid': kid,
    'p': packet,
    'at': finished.millisecondsSinceEpoch ~/ 1000,
    'r': [for (final r in results) r.toJson()],
  };

  static LessonReport fromJson(Map<String, Object?> j) => LessonReport(
    family: j['fam'] as String,
    kid: j['kid'] as int,
    packet: j['p'] as String,
    finished: DateTime.fromMillisecondsSinceEpoch((j['at'] as int) * 1000),
    results: [
      for (final r in j['r'] as List) TaskResult.fromJson(r as Map<String, Object?>),
    ],
  );

  String encode(FamilyKey key) => _seal(prefix, toJson(), key);

  static LessonReport? decode(String text, FamilyKey key) {
    final j = _open(prefix, text, key);
    if (j == null || j['fam'] != key.id) return null;
    try {
      return fromJson(j);
    } catch (_) {
      return null;
    }
  }
}

String _seal(String prefix, Map<String, Object?> json, FamilyKey key) {
  final body = ZLibEncoder().encodeBytes(utf8.encode(jsonEncode(json)), level: 9);
  return '$prefix${_b64(body)}.${_b64(key.sign(body))}';
}

Map<String, Object?>? _open(String prefix, String text, FamilyKey key) {
  if (!text.startsWith(prefix)) return null;
  final parts = text.substring(prefix.length).split('.');
  if (parts.length != 2) return null;
  try {
    final body = _unb64(parts[0]);
    final sig = _unb64(parts[1]);
    final want = key.sign(body);
    if (sig.length != want.length) return null;
    var diff = 0;
    for (var i = 0; i < sig.length; i++) {
      diff |= sig[i] ^ want[i];
    }
    if (diff != 0) return null;
    return jsonDecode(utf8.decode(ZLibDecoder().decodeBytes(body)))
        as Map<String, Object?>;
  } catch (_) {
    return null;
  }
}

String _b64(List<int> b) => base64Url.encode(b).replaceAll('=', '');

Uint8List _unb64(String s) =>
    base64Url.decode(s.padRight((s.length + 3) ~/ 4 * 4, '='));

/// Splits a long code into several QR codes shown one after another:
/// `GAM<i>/<n>/<tag>:<part>`. [QrAssembler] puts them back together.
List<String> splitForQr(String code, {int maxChars = 800}) {
  if (code.length <= maxChars) return [code];
  final n = (code.length / maxChars).ceil();
  final tag = (code.hashCode & 0xffff).toRadixString(16);
  final size = (code.length / n).ceil();
  return [
    for (var i = 0; i < n; i++)
      'GAM${i + 1}/$n/$tag:'
          '${code.substring(i * size, math.min(code.length, (i + 1) * size))}',
  ];
}

/// Collects the parts of a split code, in any order.
class QrAssembler {
  final _parts = <int, String>{};
  int? _n;
  String? _tag;

  static final _re = RegExp(r'^GAM(\d+)/(\d+)/([0-9a-f]+):(.*)$', dotAll: true);

  /// Parts seen so far, and how many there are (0 when unknown).
  int get have => _parts.length;
  int get total => _n ?? 0;

  /// Returns the whole code once it is complete, or the text itself when it
  /// was not split.
  String? add(String text) {
    final m = _re.firstMatch(text);
    if (m == null) return text;
    final i = int.parse(m[1]!);
    final n = int.parse(m[2]!);
    if (_tag != m[3] || _n != n) {
      _parts.clear();
      _tag = m[3];
      _n = n;
    }
    _parts[i] = m[4]!;
    if (_parts.length < n) return null;
    return [for (var k = 1; k <= n; k++) _parts[k]!].join();
  }
}
