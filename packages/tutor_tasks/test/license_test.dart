import 'package:test/test.dart';
import 'package:tutor_tasks/tutor_tasks.dart';

void main() {
  final seed = List<int>.generate(32, (i) => i * 7 % 256);
  final pub = License.publicKeyOf(seed);
  final key = FamilyKey.generate();
  License lic(DateTime until, {FamilyKey? k}) => License(
    family: (k ?? key).id,
    keyHash: License.hashOf(k ?? key),
    until: until,
    plan: Plan.kit,
    issued: DateTime.utc(2026, 11, 19),
  );
  TaskPacket packet(String? license, {FamilyKey? k}) => TaskPacket(
    family: (k ?? key).id,
    kid: 1,
    id: 'p1',
    tasks: [EqTask.parse('8+5', n: '1')],
    license: license,
  );
  final today = DateTime.utc(2026, 12, 1);

  test('a licence signed by the server opens packets until it runs out', () {
    final code = lic(DateTime.utc(2027, 2, 17)).sign(seed);
    expect(code.length, lessThan(200));
    final l = License.verify(code, [pub])!;
    expect(l.fits(key), isTrue);
    expect(l.daysLeft(today), 79);

    final p = TaskPacket.decode(packet(code).encode(key), key)!;
    expect(checkLicense(p, key, [pub], today), isNull);
    // Three days of grace, then no more.
    expect(checkLicense(p, key, [pub], DateTime.utc(2027, 2, 20)), isNull);
    expect(
      checkLicense(p, key, [pub], DateTime.utc(2027, 2, 21)),
      Refusal.expired,
    );
  });

  test('no licence, a forged one, or somebody else\'s: refused', () {
    expect(checkLicense(packet(null), key, [pub], today), Refusal.noLicense);

    // Signed with a key the app does not trust.
    final fake = lic(DateTime.utc(2030)).sign(List.filled(32, 1));
    expect(checkLicense(packet(fake), key, [pub], today), Refusal.forged);

    // A changed date breaks the signature.
    final real = lic(DateTime.utc(2026, 12, 31)).sign(seed);
    final other = lic(DateTime.utc(2036, 12, 31)).sign(seed);
    final spliced =
        '${other.split('.').sublist(0, 2).join('.')}.${real.split('.')[2]}';
    expect(checkLicense(packet(spliced), key, [pub], today), Refusal.forged);

    // A real licence copied from another family's QR code: a new family
    // with the same id but its own secret does not fit.
    final mine = FamilyKey(key.id, FamilyKey.generate().secret);
    expect(
      checkLicense(packet(real, k: mine), mine, [pub], today),
      Refusal.foreign,
    );
  });

  test('turning the clock back does not revive a licence', () {
    final d = TrustedDate(null);
    expect(d.today(DateTime.utc(2027, 3, 1, 10)), DateTime.utc(2027, 3, 1));
    expect(d.today(DateTime.utc(2026, 12, 1)), DateTime.utc(2027, 3, 1));
    d.saw(DateTime.utc(2027, 3, 5));
    expect(d.today(DateTime.utc(2027, 3, 2)), DateTime.utc(2027, 3, 5));
  });

  test('the dev key is trusted only in debug builds', () {
    final code = lic(DateTime.utc(2027)).sign(devSeedBytes);
    expect(License.verify(code, trustedLicenseKeys(debug: true)), isNotNull);
    expect(License.verify(code, trustedLicenseKeys(debug: false)), isNull);
  });
}
