import 'dart:convert';

import 'package:goabacus_license/limits.dart';
import 'package:goabacus_license/purchases.dart';
import 'package:goabacus_license/service.dart';
import 'package:goabacus_license/store.dart';
import 'package:shelf/shelf.dart';
import 'package:test/test.dart';
import 'package:tutor_tasks/tutor_tasks.dart';

class FakePlay implements PurchaseVerifier {
  DateTime? until;
  @override
  Future<DateTime?> paidUntil(String product, String token) async =>
      token == 'good' ? until : null;
}

void main() {
  final seed = devSeedBytes;
  final trusted = trustedLicenseKeys(debug: true);
  late MemoryStore store;
  late FakePlay play;
  late DateTime now;
  late LicenseService s;
  final key = FamilyKey.generate();
  final fam = {'family': key.id, 'keyHash': License.hashOf(key)};

  setUp(() {
    store = MemoryStore()
      ..codes['GA7K3MQ9X2PD'] = CodeRecord(code: 'GA7K3MQ9X2PD');
    play = FakePlay();
    now = DateTime.utc(2026, 11, 19, 8);
    s = LicenseService(store: store, seed: seed, play: play, clock: () => now);
  });

  Future<(int, Map<String, Object?>)> post(
    String path,
    Map<String, Object?> b,
  ) async {
    final r = await s.router.call(
      Request('POST', Uri.parse('http://x$path'), body: jsonEncode(b)),
    );
    return (
      r.statusCode,
      jsonDecode(await r.readAsString()) as Map<String, Object?>,
    );
  }

  License lic(Map<String, Object?> j) =>
      License.verify(j['license'] as String, trusted)!;

  test('a kit code gives 90 days, once, to one family', () async {
    final (st, j) = await post('/v1/redeem', {
      ...fam,
      'code': 'ga7k-3mq9-x2pd',
    });
    expect(st, 200);
    final l = lic(j);
    expect(l.fits(key), isTrue);
    expect(l.plan, Plan.kit);
    expect(l.daysLeft(now), 90);

    // The same family again: the same licence, no more days.
    final (st2, j2) = await post('/v1/redeem', {
      ...fam,
      'code': 'GA7K3MQ9X2PD',
    });
    expect(st2, 200);
    expect(lic(j2).until, l.until);

    // Another family: refused.
    final other = FamilyKey.generate();
    final (st3, _) = await post('/v1/redeem', {
      'family': other.id,
      'keyHash': License.hashOf(other),
      'code': 'GA7K3MQ9X2PD',
    });
    expect(st3, 409);

    final (st4, _) = await post('/v1/redeem', {...fam, 'code': 'NOPE'});
    expect(st4, 404);
  });

  test('a second kit code adds 90 days to the end', () async {
    store.codes['AAAABBBBCCCC'] = CodeRecord(code: 'AAAABBBBCCCC');
    await post('/v1/redeem', {...fam, 'code': 'GA7K3MQ9X2PD'});
    final (_, j) = await post('/v1/redeem', {...fam, 'code': 'AAAABBBBCCCC'});
    expect(lic(j).daysLeft(now), 180);
  });

  test('someone who knows only the family id cannot take it over', () async {
    await post('/v1/redeem', {...fam, 'code': 'GA7K3MQ9X2PD'});
    final (st, _) = await post('/v1/refresh', {
      'family': key.id,
      'keyHash': 'AAAAAAAAAAA',
    });
    expect(st, 403);
  });

  test('a Play subscription; refresh picks up the renewal', () async {
    play.until = DateTime.utc(2026, 12, 19, 8);
    final (st0, _) = await post('/v1/play', {
      ...fam,
      'product': 'family_monthly',
      'token': 'bad',
    });
    expect(st0, 402);
    final (st, j) = await post('/v1/play', {
      ...fam,
      'product': 'family_monthly',
      'token': 'good',
    });
    expect(st, 200);
    expect(lic(j).plan, Plan.sub);
    expect(lic(j).until, DateTime.utc(2026, 12, 19));

    play.until = DateTime.utc(2027, 1, 19);
    now = DateTime.utc(2026, 12, 20);
    final (_, j2) = await post('/v1/refresh', fam);
    expect(lic(j2).until, DateTime.utc(2027, 1, 19));
  });

  test('two families redeem one code at the same moment: one wins', () async {
    final other = FamilyKey.generate();
    final rs = await Future.wait([
      post('/v1/redeem', {...fam, 'code': 'GA7K3MQ9X2PD'}),
      post('/v1/redeem', {
        'family': other.id,
        'keyHash': License.hashOf(other),
        'code': 'GA7K3MQ9X2PD',
      }),
    ]);
    expect(rs.map((r) => r.$1).toList()..sort(), [200, 409]);
  });

  test('a refund moves the licence back to the kit days', () async {
    await post('/v1/redeem', {...fam, 'code': 'GA7K3MQ9X2PD'});
    play.until = DateTime.utc(2027, 6, 1);
    final (_, j) = await post('/v1/play', {
      ...fam,
      'product': 'family_monthly',
      'token': 'good',
    });
    expect(lic(j).until, DateTime.utc(2027, 6, 1));
    expect(lic(j).plan, Plan.sub);
    play.until = DateTime.utc(2026, 11, 20); // refunded
    final (_, j2) = await post('/v1/refresh', fam);
    expect(lic(j2).until, DateTime.utc(2027, 2, 16)); // the kit's 90 days
    expect(lic(j2).plan, Plan.kit);
  });

  test('too many tries from one client: 429', () async {
    final h = limits(perMinute: 3, clock: () => now)(s.router.call);
    Future<int> one() async => (await h(
      Request(
        'POST',
        Uri.parse('http://x/v1/redeem'),
        body: jsonEncode({...fam, 'code': 'WRONG'}),
        headers: {'x-forwarded-for': '1.2.3.4'},
      ),
    )).statusCode;
    expect(
      [await one(), await one(), await one(), await one()],
      [404, 404, 404, 429],
    );
    now = now.add(const Duration(minutes: 1));
    expect(await one(), 404);
  });
}
