import 'package:flutter_test/flutter_test.dart';
import 'package:goabacus_scan/main.dart';
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
}
