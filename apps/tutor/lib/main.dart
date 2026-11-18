import 'package:abacus_kit/abacus_kit.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:tutor_tasks/tutor_tasks.dart';

import 'lesson.dart';
import 'lesson_screen.dart';
import 'qr.dart';
import 'store.dart';
import 'strings.dart';

/// GoAbacUs Tutor: the child's app. It never goes online: tasks come from
/// the parent's phone as a QR code, the lesson runs on the device, and the
/// report goes back as a QR code.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  final store = await TutorStore.open();
  appLang.value = store.lang ?? store.pairing?.kid.homeLang ?? 'ru';
  runApp(TutorApp(store: store));
}

class TutorApp extends StatelessWidget {
  const TutorApp({super.key, required this.store});
  final TutorStore store;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<String>(
      valueListenable: appLang,
      builder: (context, _, _) => MaterialApp(
        title: 'GoAbacUs Tutor',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFF6B3E22),
          ),
          scaffoldBackgroundColor: const Color(0xFFE9DCC6),
        ),
        home: HomeScreen(store: store),
      ),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, required this.store});
  final TutorStore store;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  TutorStore get store => widget.store;
  String? _message;

  Future<void> _pair() async {
    final code = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (_) => QrScanPage(
          title: tr('pair_title'),
          hint: tr('pair_text'),
          accept: (c) => Pairing.decode(c) == null ? tr('not_ours') : null,
        ),
      ),
    );
    if (code == null) return;
    final p = Pairing.decode(code)!;
    await store.setPairing(p);
    if (store.lang == null) appLang.value = p.kid.homeLang;
    setState(() {});
  }

  Future<void> _getTasks() async {
    final key = store.pairing!.key;
    final code = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (_) => QrScanPage(
          title: tr('get_tasks'),
          hint: tr('get_tasks_text'),
          accept: (c) => TaskPacket.decode(c, key) == null ? tr('not_ours') : null,
          partsLabel: (h, t) => tr('parts', {'have': h, 'total': t}),
        ),
      ),
    );
    if (code == null) return;
    final p = TaskPacket.decode(code, key)!;
    await store.add(code, p);
    setState(() => _message = tr('received', {'n': p.tasks.length}));
  }

  Future<void> _start(TaskPacket p) async {
    final lesson = await Navigator.of(context).push<Lesson>(
      MaterialPageRoute(builder: (_) => LessonScreen(packet: p)),
    );
    if (lesson == null) return;
    await store.finish(p, lesson.report());
    if (!mounted) return;
    setState(() {});
    _showReport();
  }

  void _showReport() {
    final code = store.lastReport;
    if (code == null) return;
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(tr('report')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            QrCodes(code, size: 240),
            const SizedBox(height: 12),
            Text(tr('report_text'), textAlign: TextAlign.center),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  /// A sample page to try the tutor before pairing.
  static final sample = TaskPacket(
    family: 'demo',
    kid: 0,
    id: 'demo',
    source: 'Demo',
    tasks: [
      EqTask.parse('8+5', n: '1'),
      StepsTask(57, Op.add, 28, n: '2'),
      EqTask.parse('9+?=15', n: '3'),
      EqTask.parse('32-7', n: '4'),
      ChainTask(6, [7, -5, 8], n: '5'),
      EqTask.parse('3*4', n: '6'),
    ],
  );

  void _try() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => LessonScreen(packet: sample)),
    );
  }

  void _free() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const _FreeAbacus()),
    );
  }

  Widget _langMenu() => PopupMenuButton<String>(
    icon: const Icon(Icons.language),
    onSelected: (l) {
      appLang.value = l;
      store.setLang(l);
    },
    itemBuilder: (_) => [
      for (final e in languages.entries)
        PopupMenuItem(value: e.key, child: Text(e.value)),
    ],
  );

  @override
  Widget build(BuildContext context) {
    final pairing = store.pairing;
    final queue = store.queue;
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFFE9DCC6),
        title: Text(tr('app')),
        actions: [
          if (store.lastReport != null)
            IconButton(
              icon: const Icon(Icons.qr_code_2),
              tooltip: tr('report'),
              onPressed: _showReport,
            ),
          _langMenu(),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const Center(child: Text('🦉', style: TextStyle(fontSize: 72))),
            if (pairing == null) ...[
              Text(
                tr('pair_title'),
                style: Theme.of(context).textTheme.headlineSmall,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(tr('pair_text'), textAlign: TextAlign.center),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: _pair,
                icon: const Icon(Icons.qr_code_scanner),
                label: Text(tr('scan')),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: _try,
                icon: const Icon(Icons.play_arrow),
                label: Text(tr('try')),
              ),
            ] else ...[
              Text(
                '${tr('hello').split('!').first}, ${pairing.kid.name}!',
                style: Theme.of(context).textTheme.headlineSmall,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              if (queue.isEmpty)
                Text(tr('no_tasks'), textAlign: TextAlign.center),
              for (final p in queue)
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.menu_book_outlined),
                    title: Text(p.source.isEmpty ? p.id : p.source),
                    subtitle: Text(tr('tasks_n', {'n': p.tasks.length})),
                    trailing: FilledButton(
                      onPressed: () => _start(p),
                      child: Text(tr('start')),
                    ),
                  ),
                ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: _getTasks,
                icon: const Icon(Icons.qr_code_scanner),
                label: Text(tr('get_tasks')),
              ),
              if (_message != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(_message!, textAlign: TextAlign.center),
                ),
            ],
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _free,
              icon: const Icon(Icons.grid_on),
              label: Text(tr('free')),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.wifi_off, size: 16),
                const SizedBox(width: 6),
                Text(tr('offline')),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _FreeAbacus extends StatefulWidget {
  const _FreeAbacus();

  @override
  State<_FreeAbacus> createState() => _FreeAbacusState();
}

class _FreeAbacusState extends State<_FreeAbacus> {
  final _c = AbacusController(config: const AbacusConfig(rows: 4));

  @override
  void initState() {
    super.initState();
    _c.sound.init();
    _c.tilt.start();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFFE9DCC6),
        title: Text(tr('free')),
        actions: [
          IconButton(
            icon: const Icon(Icons.cleaning_services_outlined),
            onPressed: _c.clear,
          ),
        ],
      ),
      body: SafeArea(child: AbacusView(controller: _c)),
    );
  }
}
