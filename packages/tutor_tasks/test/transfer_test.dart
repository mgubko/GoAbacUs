import 'package:test/test.dart';
import 'package:tutor_tasks/tutor_tasks.dart';

void main() {
  final key = FamilyKey.generate();
  final t0 = DateTime.utc(2026, 11, 19, 10);
  final t = FamilyTransfer(
    key: key,
    kids: const [
      Kid(id: 1, name: 'Аня', grade: 2, aids: {'rods'}),
      Kid(id: 2, name: 'Max', homeLang: 'de'),
    ],
    license: 'GL1.x.y',
    seq: 17,
    made: t0,
  );

  test('round trip', () {
    final back = FamilyTransfer.decode(t.encode(), now: t0)!;
    expect(back.key.id, key.id);
    expect(back.key.encodedSecret, key.encodedSecret);
    expect(back.kids.map((k) => k.name), ['Аня', 'Max']);
    expect(back.kids.first.aids, {'rods'});
    expect(back.license, 'GL1.x.y');
    expect(back.seq, 17);
    // Packets made with the moved key open with the original one.
    final p = TaskPacket(family: key.id, kid: 1, id: 'p', tasks: const []);
    expect(TaskPacket.decode(p.encode(back.key), key), isNotNull);
  });

  test('an old code is refused', () {
    final code = t.encode();
    expect(
      FamilyTransfer.decode(code, now: t0.add(const Duration(minutes: 14))),
      isNotNull,
    );
    expect(
      FamilyTransfer.decode(code, now: t0.add(const Duration(minutes: 16))),
      isNull,
    );
    expect(
      FamilyTransfer.decode(
        code,
        now: t0.subtract(const Duration(minutes: 10)),
      ),
      isNull,
    );
  });

  test('other codes and junk are refused', () {
    expect(
      FamilyTransfer.decode(
        Pairing(key, const Kid(id: 1, name: 'A')).encode(),
        now: t0,
      ),
      isNull,
    );
    expect(FamilyTransfer.decode('GAT1.abc', now: t0), isNull);
    expect(FamilyTransfer.decode('', now: t0), isNull);
  });
}
