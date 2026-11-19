/// The family's subscription, as the GoAbacUs licence server signs it.
///
/// The parent's phone makes the family key itself, so a family-signed task
/// packet proves nothing about payment: anyone can make a family. What the
/// child's app trusts instead is a licence signed by the server with
/// Ed25519. The app holds only the public key, so it checks the licence
/// offline; nobody but the server can make one.
///
/// A licence names the family and a hash of the family's secret, so a
/// licence copied out of somebody else's QR code is useless without their
/// secret, and it says until which day it holds. Every task packet carries
/// the licence; the child's app refuses a packet whose licence is missing,
/// foreign, forged or expired by the device's date.
library;

import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:pinenacl/ed25519.dart' as ed;

import 'packet.dart' show FamilyKey, TaskPacket;

/// How a family got its licence.
enum Plan {
  /// The activation code from a kit box.
  kit,

  /// A store subscription (Google Play, App Store).
  sub,

  /// Given by hand (testers, schools).
  gift,
}

class License {
  const License({
    required this.family,
    required this.keyHash,
    required this.until,
    required this.plan,
    required this.issued,
  });

  final String family;

  /// The first 8 bytes of SHA-256 of the family secret, base64url.
  final String keyHash;

  /// The last day it holds (UTC date, inclusive).
  final DateTime until;
  final Plan plan;
  final DateTime issued;

  static const prefix = 'GL1.';

  static String hashOf(FamilyKey key) =>
      _b64(sha256.convert(key.secret).bytes.sublist(0, 8));

  bool fits(FamilyKey key) => family == key.id && keyHash == hashOf(key);

  /// Valid on [today] (a date; the time of day does not matter).
  bool validOn(DateTime today) => !_day(today).isAfter(_day(until));

  /// Days left including today; negative when it ran out.
  int daysLeft(DateTime today) =>
      _day(until).difference(_day(today)).inDays + 1;

  Map<String, Object> _json() => {
    'f': family,
    'k': keyHash,
    'u': _days(until),
    'p': plan.name,
    'i': _days(issued),
  };

  /// Only the server can do this: it holds the signing seed.
  String sign(List<int> seed) {
    final body = utf8.encode(jsonEncode(_json()));
    final sig = ed.SigningKey.fromSeed(
      Uint8List.fromList(seed),
    ).sign(Uint8List.fromList(body)).signature;
    return '$prefix${_b64(body)}.${_b64(sig.asTypedList)}';
  }

  /// Null unless [code] is a licence signed by one of [trusted] keys
  /// (32-byte Ed25519 public keys).
  static License? verify(String code, List<List<int>> trusted) {
    if (!code.startsWith(prefix)) return null;
    final parts = code.substring(prefix.length).split('.');
    if (parts.length != 2) return null;
    try {
      final body = _unb64(parts[0]);
      final sig = _unb64(parts[1]);
      final ok = trusted.any((k) {
        try {
          return ed.VerifyKey(
            Uint8List.fromList(k),
          ).verify(signature: ed.Signature(sig), message: body);
        } catch (_) {
          return false;
        }
      });
      if (!ok) return null;
      final j = jsonDecode(utf8.decode(body)) as Map<String, Object?>;
      return License(
        family: j['f'] as String,
        keyHash: j['k'] as String,
        until: _date(j['u'] as int),
        plan: Plan.values.byName(j['p'] as String),
        issued: _date(j['i'] as int),
      );
    } catch (_) {
      return null;
    }
  }

  /// The public key for a signing seed (for the server's key tool).
  static List<int> publicKeyOf(List<int> seed) =>
      ed.SigningKey.fromSeed(Uint8List.fromList(seed)).verifyKey.asTypedList;
}

/// The date the child's device believes, never earlier than any date it
/// has seen before: turning the clock back does not revive a licence.
class TrustedDate {
  TrustedDate(this.latestSeen);

  /// The latest date seen so far (stored on the device).
  DateTime? latestSeen;

  DateTime today(DateTime now) {
    final d = _day(now);
    final l = latestSeen;
    final t = l != null && l.isAfter(d) ? l : d;
    latestSeen = t;
    return t;
  }

  /// A packet's issue date also moves the date on (the parent's phone is
  /// usually online and right).
  void saw(DateTime date) {
    final d = _day(date);
    if (latestSeen == null || d.isAfter(latestSeen!)) latestSeen = d;
  }
}

DateTime _day(DateTime t) {
  final u = t.toUtc();
  return DateTime.utc(u.year, u.month, u.day);
}

int _days(DateTime t) =>
    _day(t).millisecondsSinceEpoch ~/ Duration.millisecondsPerDay;

DateTime _date(int days) => DateTime.fromMillisecondsSinceEpoch(
  days * Duration.millisecondsPerDay,
  isUtc: true,
);

String _b64(List<int> b) => base64Url.encode(b).replaceAll('=', '');

Uint8List _unb64(String s) =>
    base64Url.decode(s.padRight((s.length + 3) ~/ 4 * 4, '='));

/// Days the child's app still accepts tasks after the licence ran out, so
/// that a renewal on the parent's phone a little late does not stop
/// homework.
const licenseGraceDays = 3;

/// Why the child's app refuses a task packet.
enum Refusal {
  /// The packet has no licence (made without a subscription).
  noLicense,

  /// Not signed by the GoAbacUs server.
  forged,

  /// Signed, but for another family.
  foreign,

  /// The subscription ran out.
  expired,
}

/// Null when the child's app may open [packet]; otherwise why not.
Refusal? checkLicense(
  TaskPacket packet,
  FamilyKey key,
  List<List<int>> trusted,
  DateTime today,
) {
  final code = packet.license;
  if (code == null) return Refusal.noLicense;
  final l = License.verify(code, trusted);
  if (l == null) return Refusal.forged;
  if (!l.fits(key)) return Refusal.foreign;
  if (!l.validOn(today.subtract(const Duration(days: licenseGraceDays)))) {
    return Refusal.expired;
  }
  return null;
}
