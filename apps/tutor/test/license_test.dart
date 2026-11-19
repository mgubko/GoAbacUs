import 'package:flutter_test/flutter_test.dart';
import 'package:goabacus_tutor/store.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tutor_tasks/tutor_tasks.dart';

void main() {
  test('the tutor opens only tasks with a valid licence of its family', () async {
    SharedPreferences.setMockInitialValues({});
    final store = await TutorStore.open();
    final key = FamilyKey.generate();
    await store.setPairing(Pairing(key, const Kid(id: 1, name: 'A')));
    TaskPacket packet(String? lic) => TaskPacket(
      family: key.id,
      kid: 1,
      id: 'x',
      tasks: [EqTask.parse('8+5', n: '1')],
      license: lic,
    );
    final now = DateTime.now().toUtc();
    String lic(DateTime until) => License(
      family: key.id,
      keyHash: License.hashOf(key),
      until: until,
      plan: Plan.kit,
      issued: now,
    ).sign(devSeedBytes);

    expect(await store.check(packet(null)), Refusal.noLicense);
    expect(await store.check(packet(lic(now.add(const Duration(days: 30))))), isNull);
    expect(
      await store.check(packet(lic(now.subtract(const Duration(days: 10))))),
      Refusal.expired,
    );
  });
}
