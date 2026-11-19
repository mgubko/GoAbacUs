import 'package:test/test.dart';
import 'package:tutor_tasks/tutor_tasks.dart';

void main() {
  test('a packet and pairing go to the tutor on the same phone', () {
    final key = FamilyKey.generate();
    const kid = Kid(id: 1, name: 'Аня', aids: {'rods'});
    final packet = TaskPacket(
      family: key.id,
      kid: 1,
      id: '2026-11-19-1',
      tasks: [EqTask.parse('17:5', n: '1')],
    ).encode(key);
    final uri = Handoff(
      pairing: Pairing(key, kid).encode(),
      packet: packet,
    ).toTutor();
    expect(uri.scheme, tutorScheme);
    final back = Handoff.parse(Uri.parse(uri.toString()))!;
    expect(back.packet, packet);
    final p = Pairing.decode(back.pairing!)!;
    expect(p.kid.aids, {'rods'});
    expect(TaskPacket.decode(back.packet!, p.key)!.tasks.single.n, '1');
  });

  test('a report goes back to the parent app; foreign links are ignored', () {
    final h = Handoff.parse(
      Uri.parse(const Handoff(report: 'GR1.abc.def').toScan().toString()),
    )!;
    expect(h.report, 'GR1.abc.def');
    expect(Handoff.parse(Uri.parse('https://example.com/?c=GA1.x')), isNull);
    expect(Handoff.parse(Uri.parse('goabacus-tutor://open?c=evil')), isNull);
    expect(
      Handoff.parse(
        Uri.parse('goabacus-scan://activate?code=GA7K3MQ9X2PD'),
      )!.activation,
      'GA7K3MQ9X2PD',
    );
  });
}
