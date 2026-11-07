import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:goabacus/l10n/app_localizations.dart';
import 'package:goabacus/ui/tutorial.dart';

void main() {
  Future<BuildContext> host(WidgetTester tester) async {
    late BuildContext ctx;
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('ru'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) {
            ctx = context;
            return const SizedBox();
          },
        ),
      ),
    );
    return ctx;
  }

  testWidgets('opens on the given page and reports it with the example', (
    tester,
  ) async {
    final ctx = await host(tester);
    TutorialResult? r;
    showTutorial(ctx, page: 4).then((v) => r = v);
    await tester.pumpAndSettle();
    expect(find.text('Правило 2. Перенос десятка'), findsOneWidget);
    final show = find.textContaining('Показать на счётах');
    await tester.ensureVisible(show);
    await tester.tap(show);
    await tester.pumpAndSettle();
    expect(r!.page, 4);
    expect(r!.example!.terms, [5, 7]);
  });

  testWidgets('the back arrow keeps the page', (tester) async {
    final ctx = await host(tester);
    TutorialResult? r;
    showTutorial(ctx, page: 2).then((v) => r = v);
    await tester.pumpAndSettle();
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    expect(r!.page, 2);
    expect(r!.example, isNull);
  });
}
