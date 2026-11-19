import 'package:flutter_test/flutter_test.dart';
import 'package:goabacus_scan/license.dart';
import 'package:goabacus_scan/main.dart';
import 'package:goabacus_scan/strings.dart';
import 'package:goabacus_scan/store.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
}
