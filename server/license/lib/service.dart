/// The licence server's API. Everything is JSON over HTTPS POST:
///
/// * `/v1/redeem`  {code, family, keyHash} → {license}
///   A kit activation code: the first family to redeem it gets `days`
///   (90) more days. The same family may redeem it again (a retry).
/// * `/v1/play`    {family, keyHash, product, token} → {license}
///   A Google Play subscription: checked with the Play Developer API.
/// * `/v1/refresh` {family, keyHash} → {license}
///   The current licence; a subscription is checked again with the store,
///   so a renewal shows up without the parent doing anything.
///
/// The server never sees names, children or homework: only the family id,
/// the hash of its secret and dates.
library;

import 'dart:convert';

import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';
import 'package:tutor_tasks/tutor_tasks.dart';

import 'purchases.dart';
import 'store.dart';

class LicenseService {
  LicenseService({
    required this.store,
    required this.seed,
    this.play,
    DateTime Function()? clock,
  }) : clock = clock ?? DateTime.now;

  final Store store;
  final List<int> seed;
  final PurchaseVerifier? play;
  final DateTime Function() clock;

  Router get router => Router()
    ..post('/v1/redeem', _wrap(redeem))
    ..post('/v1/play', _wrap(playPurchase))
    ..post('/v1/refresh', _wrap(refresh))
    // App Store Server API: not yet (needs the App Store Connect key).
    ..post(
      '/v1/apple',
      (Request _) => Response(501, body: jsonEncode({'error': 'apple'})),
    )
    ..get('/health', (Request _) => Response.ok('ok'));

  Handler _wrap(
    Future<Map<String, Object?>> Function(Map<String, Object?>) f,
  ) => (Request r) async {
    try {
      final body = jsonDecode(await r.readAsString());
      if (body is! Map<String, Object?>) throw const Refused(400, 'bad');
      final out = await f(body);
      return Response.ok(
        jsonEncode(out),
        headers: {'content-type': 'application/json'},
      );
    } on Refused catch (e) {
      return Response(
        e.status,
        body: jsonEncode({'error': e.reason}),
        headers: {'content-type': 'application/json'},
      );
    } on FormatException {
      return Response(400, body: jsonEncode({'error': 'bad'}));
    }
  };

  DateTime get _today {
    final n = clock().toUtc();
    return DateTime.utc(n.year, n.month, n.day);
  }

  static String _str(Map<String, Object?> b, String k) {
    final v = b[k];
    if (v is! String || v.isEmpty || v.length > 4096) {
      throw Refused(400, 'missing $k');
    }
    return v;
  }

  /// The family as the request names it; its secret's hash must match the
  /// one the server saw first.
  Future<FamilyRecord?> _family(Map<String, Object?> b) async {
    final id = _str(b, 'family');
    final kh = _str(b, 'keyHash');
    final f = await store.family(id);
    if (f != null && f.keyHash != kh) throw const Refused(403, 'family');
    return f;
  }

  Map<String, Object?> _license(FamilyRecord f) => {
    'license': License(
      family: f.id,
      keyHash: f.keyHash,
      until: f.until,
      plan: Plan.values.byName(f.plan),
      issued: _today,
    ).sign(seed),
    'until': f.until.toIso8601String().substring(0, 10),
    'plan': f.plan,
  };

  Future<Map<String, Object?>> redeem(Map<String, Object?> b) async {
    final raw = _str(b, 'code');
    final code = normalizeCode(raw);
    final c = await store.code(code);
    if (c == null) throw const Refused(404, 'code');
    final family = _str(b, 'family');
    var f = await _family(b);
    if (c.family != null) {
      if (c.family != family) throw const Refused(409, 'used');
      if (f == null) throw const Refused(409, 'used');
      return _license(f); // a retry of the same redemption
    }
    final from = f != null && f.until.isAfter(_today) ? f.until : _today;
    final until = from.add(Duration(days: c.days - (from == _today ? 1 : 0)));
    f = FamilyRecord(
      id: family,
      keyHash: _str(b, 'keyHash'),
      until: until,
      plan: f?.store != null ? f!.plan : 'kit',
      store: f?.store,
      product: f?.product,
      token: f?.token,
    );
    c
      ..family = family
      ..used = clock().toUtc();
    await store.putCode(c);
    await store.putFamily(f);
    return _license(f);
  }

  Future<Map<String, Object?>> playPurchase(Map<String, Object?> b) async {
    final v = play;
    if (v == null) throw const Refused(501, 'play');
    final product = _str(b, 'product');
    final token = _str(b, 'token');
    final paid = await v.paidUntil(product, token);
    if (paid == null) throw const Refused(402, 'not paid');
    final old = await _family(b);
    final until = DateTime.utc(paid.year, paid.month, paid.day);
    final f = FamilyRecord(
      id: _str(b, 'family'),
      keyHash: _str(b, 'keyHash'),
      // Days left from a kit code are kept.
      until: old != null && old.until.isAfter(until) ? old.until : until,
      plan: 'sub',
      store: 'play',
      product: product,
      token: token,
    );
    await store.putFamily(f);
    return _license(f);
  }

  Future<Map<String, Object?>> refresh(Map<String, Object?> b) async {
    final f = await _family(b);
    if (f == null) throw const Refused(404, 'family');
    final v = play;
    if (f.store == 'play' && v != null && f.token != null) {
      final paid = await v.paidUntil(f.product!, f.token!);
      if (paid != null) {
        final until = DateTime.utc(paid.year, paid.month, paid.day);
        if (until.isAfter(f.until)) {
          f.until = until;
          await store.putFamily(f);
        }
      }
    }
    return _license(f);
  }
}

class Refused implements Exception {
  const Refused(this.status, this.reason);
  final int status;
  final String reason;
}

/// Codes are printed as GA7K-3MQ9-X2PD; people type them in any case,
/// with or without dashes, and mix up O/0 and I/1.
String normalizeCode(String s) => s
    .toUpperCase()
    .replaceAll(RegExp(r'[\s-]'), '')
    .replaceAll('O', '0')
    .replaceAll(RegExp('[IL]'), '1');

const _alphabet = '0123456789ABCDEFGHJKMNPQRSTVWXYZ'; // Crockford

/// A new code: 12 characters, 60 random bits, shown in groups of four.
String newCode(int Function(int max) random) {
  final b = StringBuffer();
  for (var i = 0; i < 12; i++) {
    b.write(_alphabet[random(32)]);
  }
  return b.toString();
}

String showCode(String c) =>
    [for (var i = 0; i < c.length; i += 4) c.substring(i, i + 4)].join('-');
