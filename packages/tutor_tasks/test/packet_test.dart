import 'dart:math' as math;

import 'package:test/test.dart';
import 'package:tutor_tasks/tutor_tasks.dart';

void main() {
  final key = FamilyKey.generate(math.Random(1));
  TaskPacket page() => TaskPacket(
    family: key.id,
    kid: 1,
    id: '2026-11-18-1',
    source: 'Mathe S. 34',
    tasks: [
      for (final e in ['57+28', '36+12', '27+29', '81+13', '44+33', '61+14'])
        StepsTask(int.parse(e.split('+')[0]), Op.add,
            int.parse(e.split('+')[1])),
      for (var i = 1; i <= 10; i++) EqTask(i, Op.mul, 7),
    ],
  );

  test('a page of 16 tasks fits one QR code', () {
    final code = page().encode(key);
    // ignore: avoid_print
    print('${code.length} chars');
    expect(code.length, lessThan(600));
    expect(splitForQr(code), hasLength(1));
  });

  test('round trip, signature and family are checked', () {
    final code = page().encode(key);
    final back = TaskPacket.decode(code, key)!;
    expect(back.tasks.map((t) => t.format()), page().tasks.map((t) => t.format()));
    expect(back.source, 'Mathe S. 34');

    final other = FamilyKey.generate(math.Random(2));
    expect(TaskPacket.decode(code, other), isNull);
    final tampered = code.replaceRange(10, 11, code[10] == 'A' ? 'B' : 'A');
    expect(TaskPacket.decode(tampered, key), isNull);
    expect(TaskPacket.decode('hello', key), isNull);
  });

  test('pairing code', () {
    final p = Pairing(key, const Kid(id: 1, name: 'Мила', grade: 2));
    final back = Pairing.decode(p.encode())!;
    expect(back.kid.name, 'Мила');
    expect(back.key.encodedSecret, key.encodedSecret);
    expect(Pairing.decode('GAP1.zzz'), isNull);
  });

  test('lesson report', () {
    final r = LessonReport(
      family: key.id,
      kid: 1,
      packet: '2026-11-18-1',
      finished: DateTime.utc(2026, 11, 18, 17),
      results: const [
        TaskResult(n: '1', solved: true, hints: 2, mistakes: [Mistake.placeValue]),
        TaskResult(n: '2', solved: false, tries: 3),
      ],
    );
    final back = LessonReport.decode(r.encode(key), key)!;
    expect(back.results[0].mistakes, [Mistake.placeValue]);
    expect(back.results[1].solved, isFalse);
    expect(back.finished.isAtSameMomentAs(r.finished), isTrue);
  });

  test('long codes are split and put back together', () {
    final long = 'GA1.${'x' * 2000}';
    final parts = splitForQr(long, maxChars: 700);
    expect(parts, hasLength(3));
    final a = QrAssembler();
    expect(a.add(parts[2]), isNull);
    expect(a.add(parts[0]), isNull);
    expect(a.add(parts[1]), long);
    expect(QrAssembler().add('GA1.short'), 'GA1.short');
  });
}
