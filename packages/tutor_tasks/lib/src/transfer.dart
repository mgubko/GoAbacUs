/// Moving a family to a new parent's phone: the old phone shows a QR code
/// with the family key, the children and the licence; the new phone reads
/// it. The children's devices keep working, since the key stays the same.
library;

import 'dart:convert';

import 'package:archive/archive.dart';

import 'packet.dart';

class FamilyTransfer {
  FamilyTransfer({
    required this.key,
    required this.kids,
    this.license,
    this.seq = 0,
    DateTime? made,
  }) : made = made ?? DateTime.now().toUtc();

  final FamilyKey key;
  final List<Kid> kids;
  final String? license;

  /// The packet counter, so that packet ids stay unique.
  final int seq;
  final DateTime made;

  static const prefix = 'GAT1.';

  /// A code shown on a screen is accepted only for a short time, so that
  /// an old photo of it is worthless.
  static const validFor = Duration(minutes: 15);

  String encode() =>
      prefix +
      _b64(
        ZLibEncoder().encodeBytes(
          utf8.encode(
            jsonEncode({
              'fam': key.id,
              'key': key.encodedSecret,
              'kids': [for (final k in kids) k.toJson()],
              'lic': ?license,
              'seq': seq,
              'at': made.millisecondsSinceEpoch ~/ 1000,
            }),
          ),
          level: 9,
        ),
      );

  /// Null when the text is not a transfer code, is damaged or too old.
  static FamilyTransfer? decode(String text, {DateTime? now}) {
    if (!text.startsWith(prefix)) return null;
    try {
      final j =
          jsonDecode(
                utf8.decode(
                  ZLibDecoder().decodeBytes(
                    base64Url.decode(_pad(text.substring(prefix.length))),
                  ),
                ),
              )
              as Map<String, Object?>;
      final t = FamilyTransfer(
        key: FamilyKey.decode(j['fam'] as String, j['key'] as String),
        kids: [
          for (final k in j['kids'] as List)
            Kid.fromJson(k as Map<String, Object?>),
        ],
        license: j['lic'] as String?,
        seq: (j['seq'] as int?) ?? 0,
        made: DateTime.fromMillisecondsSinceEpoch(
          (j['at'] as int) * 1000,
          isUtc: true,
        ),
      );
      final age = (now ?? DateTime.now()).toUtc().difference(t.made);
      // A few minutes of clock difference between the phones are fine.
      if (age > validFor || age < const Duration(minutes: -5)) return null;
      return t;
    } catch (_) {
      return null;
    }
  }
}

String _b64(List<int> b) => base64Url.encode(b).replaceAll('=', '');
String _pad(String s) => s.padRight((s.length + 3) ~/ 4 * 4, '=');
