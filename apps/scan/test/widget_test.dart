import 'package:flutter_test/flutter_test.dart';
import 'package:goabacus_scan/license.dart';
import 'package:goabacus_scan/main.dart';
import 'package:goabacus_scan/strings.dart';
import 'package:goabacus_scan/store.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tutor_tasks/tutor_tasks.dart';

void main() {
  testWidgets('home screen with a family key made on first start', (t) async {
    SharedPreferences.setMockInitialValues({});
    final store = await FamilyStore.open();
    expect(store.key.id, hasLength(8));
    await t.pumpWidget(ScanApp(store: store));
    await t.pump();
    expect(find.text('GoAbacUs Scan'), findsWidgets);
  });

  test('every string exists in every language', () {
    final ru = allStrings['ru']!.keys.toSet();
    for (final l in ['de', 'en', 'fr', 'es']) {
      expect(allStrings[l]!.keys.toSet(), ru, reason: l);
    }
    for (final e in [
      'no_server',
      'offline',
      'code_unknown',
      'code_used',
      'not_paid',
      'family_mismatch',
      'server_error',
      'store_not_ready',
      'store_error',
    ]) {
      expect(ru, contains('lerr_$e'));
    }
  });

  testWidgets('no licence: locked; the debug licence opens it', (t) async {
    SharedPreferences.setMockInitialValues({});
    final store = await FamilyStore.open();
    final l = Licensing(store);
    expect(l.active, isFalse);
    await l.devLicense();
    expect(l.active, isTrue);
    expect(l.license!.daysLeft(DateTime.now()), 90);
    l.dispose();
  });

  testWidgets('the family moves to a new phone with its licence', (t) async {
    SharedPreferences.setMockInitialValues({});
    final old = await FamilyStore.open();
    await old.addKid('Аня', 2, 'de', 'ru', aids: {'rods'});
    final l = Licensing(old);
    await l.devLicense();
    l.dispose();
    await old.nextPacketId();
    final code = old.exportFamily().encode();
    final oldId = old.key.id;

    SharedPreferences.setMockInitialValues({});
    final fresh = await FamilyStore.open();
    expect(fresh.key.id, isNot(oldId));
    await fresh.importFamily(FamilyTransfer.decode(code)!);
    expect(fresh.key.id, oldId);
    expect(fresh.kids.single.name, 'Аня');
    expect(Licensing(fresh).active, isTrue);
    expect(await fresh.nextPacketId(), endsWith('-2'));
  });
}
