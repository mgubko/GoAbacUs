import 'dart:math' as math;

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
    // The tutorial covers the abacus and stops its ticker, so nothing would
    // fade the sliding and spinning sounds out: they would hang on.
    _controller.sound.setPaused(true);
    final r = await showTutorial(context, page: _tutorialPage);
    _controller.sound.setPaused(false);
    if (!mounted) return;
    _tutorialPage = r?.page ?? 0;
    final e = r?.example;
    if (e == null) return;
    _tutorialExample = e;
    _controller.stopExercises();
    _controller.play(e);
  }

  /// A toolbar button. Compact, so that all seven fit on a phone next to
  /// the number; tablets have room to spare.
  Widget _tool(IconData icon, String tooltip, VoidCallback onPressed) {
    final wide = MediaQuery.sizeOf(context).width >= 600;
    return IconButton(
      tooltip: tooltip,
      color: const Color(0xFF402A1A),
      iconSize: wide ? 32 : 28,
      padding: EdgeInsets.zero,
      constraints: BoxConstraints(
        minWidth: wide ? 56 : 40,
        minHeight: wide ? 56 : 44,
      ),
      icon: Icon(icon),
      onPressed: onPressed,
    );
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
                padding: const EdgeInsets.fromLTRB(16, 6, 6, 0),
                child: Row(
                  children: [
                    // The number shrinks to fit, so the buttons always stay
                    // on screen (10 full rows give 11 111 111 110).
                    // Its height is fixed, so a shrinking number does not
                    // lift the abacus.
                    Expanded(
                      child: Container(
                        height: 48,
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
                    _tool(
                      Icons.menu_book_outlined,
                      t.menuTutorial,
                      _openTutorial,
                    ),
                    _tool(
                      Icons.school_outlined,
                      t.exercisesTooltip,
                      _startExercises,
                    ),
                    _tool(
                      Icons.calculate_outlined,
                      t.playTooltip,
                      _enterExample,
                    ),
                    _tool(
                      Icons.language,
                      t.menuLanguage,
                      () => showLanguagePicker(context),
                    ),
                    _tool(
                      _controller.tiltEnabled
                          ? Icons.screen_rotation
                          : Icons.screen_lock_rotation,
                      _controller.tiltEnabled ? t.tiltOn : t.tiltOff,
                      () => setState(
                        () =>
                            _controller.tiltEnabled = !_controller.tiltEnabled,
                      ),
                    ),
                    _tool(
                      _controller.sound.enabled
                          ? Icons.volume_up
                          : Icons.volume_off,
                      _controller.sound.enabled ? t.soundOn : t.soundOff,
                      () => setState(
                        () => _controller.sound.enabled =
                            !_controller.sound.enabled,
                      ),
                    ),
                    _tool(Icons.restart_alt, t.resetTooltip, _controller.clear),
                  ],
                ),
              ),
              // The panel keeps a fixed slot above the abacus; extra lines
              // of a long example spill over the free space on top of the
              // abacus area, so the abacus never moves while the example
              // grows.
              Expanded(
                child: ValueListenableBuilder<int>(
                  valueListenable: _controller.changes,
                  builder: (context, _, abacus) {
                    final exercise =
                        _controller.exercise != null &&
                        _controller.player == null;
                    return Stack(
                      children: [
                        Positioned.fill(
                          // One slot for both panels: the abacus stays put
                          // when exercises start, and two more lines of an
                          // example fit in it.
                          top: math.max(
                            ExercisePanel.slotHeight,
                            ExamplePanel.slotHeight,
                          ),
                          child: abacus!,
                        ),
                        Positioned(
                          top: 0,
                          left: 0,
                          right: 0,
                          child: exercise
                              ? ExercisePanel(controller: _controller)
                              : ExamplePanel(
                                  controller: _controller,
                                  // Shown while the example came from the
                                  // tutorial.
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
                      ],
                    );
                  },
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      AbacusView(controller: _controller),
                      ExerciseResult(controller: _controller),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
