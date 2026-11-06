import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'l10n/app_localizations.dart';
import 'ui/abacus_view.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
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
    return MaterialApp(
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

  String _format(int n) {
    final s = n.toString();
    final b = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) b.write(' ');
      b.write(s[i]);
    }
    return b.toString();
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
                    ValueListenableBuilder<int>(
                      valueListenable: _controller.value,
                      builder: (context, v, _) => Text(
                        _format(v),
                        style: const TextStyle(
                          fontSize: 40,
                          fontWeight: FontWeight.w700,
                          color: ink,
                          fontFeatures: [FontFeature.tabularFigures()],
                        ),
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      tooltip: _controller.tiltEnabled ? t.tiltOn : t.tiltOff,
                      color: ink,
                      iconSize: 30,
                      icon: Icon(
                        _controller.tiltEnabled
                            ? Icons.screen_rotation
                            : Icons.screen_lock_rotation,
                      ),
                      onPressed: () => setState(
                        () =>
                            _controller.tiltEnabled = !_controller.tiltEnabled,
                      ),
                    ),
                    IconButton(
                      tooltip: _controller.sound.enabled
                          ? t.soundOn
                          : t.soundOff,
                      color: ink,
                      iconSize: 30,
                      icon: Icon(
                        _controller.sound.enabled
                            ? Icons.volume_up
                            : Icons.volume_off,
                      ),
                      onPressed: () => setState(
                        () => _controller.sound.enabled =
                            !_controller.sound.enabled,
                      ),
                    ),
                    IconButton(
                      tooltip: t.resetTooltip,
                      color: ink,
                      iconSize: 30,
                      icon: const Icon(Icons.restart_alt),
                      onPressed: _controller.clear,
                    ),
                  ],
                ),
              ),
              Expanded(child: AbacusView(controller: _controller)),
            ],
          ),
        ),
      ),
    );
  }
}
