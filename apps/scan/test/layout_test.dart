import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:goabacus_scan/license.dart';
import 'package:goabacus_scan/main.dart';
import 'package:goabacus_scan/review_screen.dart';
import 'package:goabacus_scan/store.dart';
import 'package:goabacus_scan/strings.dart';
import 'package:goabacus_scan/subscription_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tutor_tasks/tutor_tasks.dart';

import 'fake_plugins.dart';

/// Every screen on a small phone, a large-text phone and a tablet, in
/// every language: no overflow, no exception.
void main() {
  for (final (lang, w, h, scale) in [
    ('de', 320.0, 640.0, 1.0),
    ('ru', 360.0, 740.0, 1.3),
    ('en', 800.0, 1280.0, 1.0),
    ('fr', 320.0, 640.0, 1.3),
    ('es', 360.0, 740.0, 1.0),
  ]) {
    group('$lang ${w.toInt()}x${h.toInt()} text x$scale', () {
      late FamilyStore store;
      setUp(() async {
        Licensing.storeEnabled = false;
        SharedPreferences.setMockInitialValues({});
        store = await FamilyStore.open();
        await store.addKid('Аня', 2, 'de', 'ru', aids: {'rods'});
        appLang.value = lang;
      });

      Future<void> show(WidgetTester t, Widget w0) async {
        fakePlugins(t);
        t.view.physicalSize = Size(w * 2, h * 2);
        t.view.devicePixelRatio = 2;
        t.platformDispatcher.textScaleFactorTestValue = scale;
        addTearDown(t.view.reset);
        addTearDown(t.platformDispatcher.clearTextScaleFactorTestValue);
        await t.pumpWidget(w0);
        await t.pump(const Duration(milliseconds: 100));
        expect(t.takeException(), isNull);
        // Accessibility: big enough, labelled buttons and readable text.
        final semantics = t.ensureSemantics();
        await expectLater(t, meetsGuideline(androidTapTargetGuideline));
        await expectLater(t, meetsGuideline(labeledTapTargetGuideline));
        await expectLater(t, meetsGuideline(textContrastGuideline));
        semantics.dispose();
      }

      testWidgets('home', (t) => show(t, ScanApp(store: store)));

      testWidgets('subscription', (t) async {
        final l = Licensing(store);
        await show(t, MaterialApp(home: SubscriptionScreen(licensing: l)));
        l.dispose();
      });

      testWidgets(
        'review',
        (t) => show(
          t,
          MaterialApp(
            home: ReviewScreen(
              tasks: [
                EqTask.parse('8+5', n: '1'),
                EqTask.parse('9+?=15', n: '2'),
                StepsTask(57, Op.add, 28, n: '3'),
                EqTask.parse('17:5', n: '4'),
              ],
              note: tr('hard_page'),
            ),
          ),
        ),
      );
    });
  }
}
