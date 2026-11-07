import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'arith/exercise.dart';
import 'arith/plan.dart';
import 'l10n/app_localizations.dart';
import 'ui/abacus_view.dart';
import 'ui/example_panel.dart';
import 'ui/exercise_ui.dart';
import 'ui/language.dart';
import 'ui/tutorial.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await loadLocale();
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  runApp(const GoAbacusApp());
}

class GoAbacusApp extends StatelessWidget {
  const GoAbacusApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Locale?>(
      valueListenable: appLocale,
      builder: (context, locale, _) => _app(locale),
    );
  }

  Widget _app(Locale? locale) {
    return MaterialApp(
      locale: locale,
      onGenerateTitle: (context) => AppLocalizations.of(context).appTitle,
      debugShowCheckedModeBanner: false,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF6B3E22)),
        scaffoldBackgroundColor: const Color(0xFFE9DCC6),
      ),
      home: const AbacusScreen(),
    );
  }
}

class AbacusScreen extends StatefulWidget {
  const AbacusScreen({super.key});

  @override
  State<AbacusScreen> createState() => _AbacusScreenState();
}

class _AbacusScreenState extends State<AbacusScreen> {
  final _controller = AbacusController();

  @override
  void initState() {
    super.initState();
    _controller.sound.init();
    _controller.tilt.start();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  var _exerciseSettings = const ExerciseSettings();

  Future<void> _startExercises() async {
    final s = await showExerciseSetup(context, _exerciseSettings);
    if (s == null) return;
    _exerciseSettings = s;
    _controller.startExercises(s);
  }

  Future<void> _enterExample() async {
    _controller.stopExercises();
    final rows = _controller.physics.config.rows;
    var max = 1;
    for (var i = 0; i < rows; i++) {
      max *= 10;
    }
    final e = await showExampleEntry(context, maxValue: max - 1);
    if (e != null) _controller.play(e);
  }

  /// The tutorial page to come back to, and the example it sent us to show.
  var _tutorialPage = 0;
  Example? _tutorialExample;

  Future<void> _openTutorial() async {
    if (_tutorialExample != null) {
      // Back from the tutorial's example: an empty abacus for the next one.
      _controller.clear();
      _tutorialExample = null;
    }
    final r = await showTutorial(context, page: _tutorialPage);
    if (!mounted) return;
    _tutorialPage = r?.page ?? 0;
    final e = r?.example;
    if (e == null) return;
    _tutorialExample = e;
    _controller.stopExercises();
    _controller.play(e);
  }

  Future<void> _menu(_MenuItem item) async {
    switch (item) {
      case _MenuItem.tutorial:
        await _openTutorial();
      case _MenuItem.language:
        await showLanguagePicker(context);
      case _MenuItem.tilt:
        setState(() => _controller.tiltEnabled = !_controller.tiltEnabled);
      case _MenuItem.sound:
        setState(() => _controller.sound.enabled = !_controller.sound.enabled);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    const ink = Color(0xFF402A1A);
    return Scaffold(
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment(-0.2, -0.4),
            radius: 1.3,
            colors: [Color(0xFFF3E9D8), Color(0xFFD9C7A8)],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 6, 12, 0),
                child: Row(
                  children: [
                    // The number shrinks to fit, so the buttons always stay
                    // on screen (10 full rows give 11 111 111 110).
                    Expanded(
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: ValueListenableBuilder<int>(
                            valueListenable: _controller.value,
                            builder: (context, v, _) => Text(
                              formatNumber(v),
                              maxLines: 1,
                              style: const TextStyle(
                                fontSize: 40,
                                fontWeight: FontWeight.w700,
                                color: ink,
                                fontFeatures: [FontFeature.tabularFigures()],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: t.exercisesTooltip,
                      color: ink,
                      iconSize: 30,
                      icon: const Icon(Icons.school_outlined),
                      onPressed: _startExercises,
                    ),
                    IconButton(
                      tooltip: t.playTooltip,
                      color: ink,
                      iconSize: 30,
                      icon: const Icon(Icons.calculate_outlined),
                      onPressed: _enterExample,
                    ),
                    IconButton(
                      tooltip: t.resetTooltip,
                      color: ink,
                      iconSize: 30,
                      icon: const Icon(Icons.restart_alt),
                      onPressed: _controller.clear,
                    ),
                    PopupMenuButton<_MenuItem>(
                      iconColor: ink,
                      iconSize: 30,
                      color: const Color(0xFFF6EEE0),
                      onSelected: _menu,
                      itemBuilder: (context) => [
                        PopupMenuItem(
                          value: _MenuItem.tutorial,
                          child: ListTile(
                            leading: const Icon(Icons.menu_book_outlined),
                            title: Text(t.menuTutorial),
                          ),
                        ),
                        PopupMenuItem(
                          value: _MenuItem.language,
                          child: ListTile(
                            leading: const Icon(Icons.language),
                            title: Text(t.menuLanguage),
                          ),
                        ),
                        const PopupMenuDivider(),
                        CheckedPopupMenuItem(
                          value: _MenuItem.tilt,
                          checked: _controller.tiltEnabled,
                          child: Text(t.menuTilt),
                        ),
                        CheckedPopupMenuItem(
                          value: _MenuItem.sound,
                          checked: _controller.sound.enabled,
                          child: Text(t.menuSound),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              ValueListenableBuilder<int>(
                valueListenable: _controller.changes,
                builder: (context, _, _) =>
                    _controller.exercise != null && _controller.player == null
                    ? ExercisePanel(controller: _controller)
                    : ExamplePanel(
                        controller: _controller,
                        // Shown while the example came from the tutorial.
                        onBackToTutorial:
                            _tutorialExample != null &&
                                identical(
                                  _controller.player?.example,
                                  _tutorialExample,
                                )
                            ? _openTutorial
                            : null,
                      ),
              ),
              Expanded(
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    AbacusView(controller: _controller),
                    ExerciseResult(controller: _controller),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

enum _MenuItem { tutorial, language, tilt, sound }
