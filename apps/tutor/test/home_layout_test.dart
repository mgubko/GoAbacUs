import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:goabacus_tutor/main.dart';
import 'package:goabacus_tutor/store.dart';
import 'package:goabacus_tutor/strings.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tutor_tasks/tutor_tasks.dart';

import 'fake_plugins.dart';

void main() {
  for (final (lang, w, h, scale, paired) in [
    ('de', 320.0, 640.0, 1.0, false),
    ('ru', 360.0, 740.0, 1.3, true),
    ('en', 800.0, 1280.0, 1.0, true),
    ('fr', 320.0, 640.0, 1.3, true),
    ('es', 360.0, 740.0, 1.0, false),
  ]) {
    testWidgets('home $lang ${w.toInt()}x${h.toInt()} x$scale paired=$paired', (
      t,
    ) async {
      fakePlugins(t);
      SharedPreferences.setMockInitialValues({});
      final store = await TutorStore.open();
      if (paired) {
        await store.setPairing(
          Pairing(FamilyKey.generate(), const Kid(id: 1, name: 'Аня')),
        );
      }
      appLang.value = lang;
      t.view.physicalSize = Size(w * 2, h * 2);
      t.view.devicePixelRatio = 2;
      t.platformDispatcher.textScaleFactorTestValue = scale;
      addTearDown(t.view.reset);
      addTearDown(t.platformDispatcher.clearTextScaleFactorTestValue);
      await t.pumpWidget(TutorApp(store: store));
      await t.pump(const Duration(milliseconds: 100));
      expect(t.takeException(), isNull);
      // Accessibility: big enough, labelled buttons and readable text.
      final semantics = t.ensureSemantics();
      await expectLater(t, meetsGuideline(androidTapTargetGuideline));
      await expectLater(t, meetsGuideline(labeledTapTargetGuideline));
      await expectLater(t, meetsGuideline(textContrastGuideline));
      semantics.dispose();
    });
  }
}
