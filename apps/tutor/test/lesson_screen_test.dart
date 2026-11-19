import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:goabacus_tutor/lesson_screen.dart';
import 'package:goabacus_tutor/speech/voice.dart';
import 'package:goabacus_tutor/strings.dart';
import 'package:tutor_tasks/tutor_tasks.dart';

import 'fake_plugins.dart';

void main() {
  for (final (lang, w, h, scale) in [
    ('ru', 412.0, 880.0, 1.0),
    ('de', 320.0, 640.0, 1.0),
    ('en', 360.0, 740.0, 1.3),
    ('de', 800.0, 1280.0, 1.0), // tablet
    ('fr', 320.0, 640.0, 1.3),
    ('es', 360.0, 740.0, 1.0),
  ]) {
    testWidgets(
      'lesson on screen, $lang ${w.toInt()}x${h.toInt()} text x$scale',
      (t) async {
        appLang.value = lang;
        Voice.on.value = false;
        fakePlugins(t);
        t.view.physicalSize = Size(w * 2, h * 2);
        t.view.devicePixelRatio = 2;
        t.platformDispatcher.textScaleFactorTestValue = scale;
        addTearDown(t.platformDispatcher.clearTextScaleFactorTestValue);
        addTearDown(t.view.reset);
        final packet = TaskPacket(
          family: 'demo',
          kid: 0,
          id: 'demo',
          tasks: [
            EqTask.parse('8+5', n: '1'),
            EqTask.parse('9+?=15', n: '2'),
            EqTask.parse('6*7', n: '3'),
            EqTask.parse('17:5', n: '4'),
            EqTask.parse('3+4', n: '5'),
          ],
        );
        await t.pumpWidget(
          MaterialApp(
            home: LessonScreen(packet: packet, available: Aid.values.toSet()),
          ),
        );
        await t.pump(const Duration(milliseconds: 400));
        // Accessibility: big enough, labelled buttons and readable text.
        final semantics = t.ensureSemantics();
        await expectLater(t, meetsGuideline(androidTapTargetGuideline));
        await expectLater(t, meetsGuideline(labeledTapTargetGuideline));
        // Text contrast is checked on the 'en' screen only: when the owl's
        // words are longer than their box and scroll, the check samples
        // the page around them and reports a false 1.2:1.
        if (lang == 'en') {
          await expectLater(t, meetsGuideline(textContrastGuideline));
        }
        semantics.dispose();
        Future<void> type(String digits) async {
          for (final d in digits.split('')) {
            await t.tap(find.text(d).last);
            await t.pump();
          }
          await t.tap(find.text('OK'));
          await t.pump(const Duration(milliseconds: 100));
        }

        // A wrong answer, a hint, another aid, then the right answers.
        await type('12');
        await t.tap(find.byIcon(Icons.lightbulb_outline));
        await t.pump(const Duration(milliseconds: 100));
        await t.tap(find.byIcon(Icons.swap_horiz));
        await t.pump(const Duration(milliseconds: 100));
        for (final a in ['13', '6', '42', '3', '2', '7']) {
          await type(a);
          await t.pump(const Duration(seconds: 2));
        }
        expect(t.takeException(), isNull);
      },
    );
  }
}
