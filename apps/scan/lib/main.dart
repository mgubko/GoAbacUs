import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:tutor_tasks/tutor_tasks.dart';
import 'package:url_launcher/url_launcher.dart';

import 'crash_reports.dart';
import 'errors.dart';
import 'license.dart';
import 'qr.dart';
import 'recognize.dart';
import 'review_screen.dart';
import 'store.dart';
import 'subscription_screen.dart';
import 'strings.dart';

/// GoAbacUs Scan: the parent's app. Photographs a homework page, reads it
/// on the phone, lets the parent check it and hands the tasks to the
/// child's tutor as a QR code.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await ErrorLog.install();
  final store = await FamilyStore.open();
  await CrashReports.start(store.prefs);
  appLang.value =
      store.lang ??
      (languages.containsKey(PlatformDispatcher.instance.locale.languageCode)
          ? PlatformDispatcher.instance.locale.languageCode
          : 'en');
  runApp(ScanApp(store: store));
}

class ScanApp extends StatelessWidget {
  const ScanApp({super.key, required this.store});
  final FamilyStore store;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<String>(
      valueListenable: appLang,
      builder: (context, _, _) => MaterialApp(
        title: 'GoAbacUs Scan',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFF6B3E22),
          ),
        ),
        home: HomeScreen(store: store),
      ),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, required this.store});
  final FamilyStore store;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  FamilyStore get store => widget.store;
  late Kid? _kid = store.kids.firstOrNull;
  bool _busy = false;
  StreamSubscription<Uri>? _links;
  late final _licensing = Licensing(store)..addListener(_changed);

  void _changed() {
    if (mounted) setState(() {});
  }

  /// Recognising pages and sending tasks need a subscription.
  Future<bool> _needLicense() async {
    if (_licensing.active) return true;
    await _subscription();
    return _licensing.active;
  }

  Future<void> _subscription({String? code}) => Navigator.of(context).push(
    MaterialPageRoute(
      builder: (_) => SubscriptionScreen(licensing: _licensing, code: code),
    ),
  );

  @override
  void initState() {
    super.initState();
    // The tutor on this phone hands the report back by an app link.
    _links = AppLinks().uriLinkStream.listen(_onLink, onError: (_) {});
    _licensing.refreshIfDue();
  }

  @override
  void dispose() {
    _links?.cancel();
    _licensing.dispose();
    super.dispose();
  }

  Future<void> _onLink(Uri uri) async {
    final kit = Handoff.parse(uri)?.activation;
    if (kit != null) {
      Navigator.of(context).popUntil((r) => r.isFirst);
      await _subscription(code: kit);
      return;
    }
    final code = Handoff.parse(uri)?.report;
    if (code == null) return;
    final r = LessonReport.decode(code, store.key);
    if (r == null) return;
    await store.addReport(code);
    if (!mounted) return;
    setState(() {});
    _openReport(r);
  }

  /// The parent gives this phone to the child: open the tutor here with
  /// the tasks (and the pairing, in case the tutor is new on this phone).
  Future<void> _onThisPhone(Kid kid, {String? packet}) async {
    final uri = Handoff(
      pairing: Pairing(store.key, kid).encode(),
      packet: packet,
    ).toTutor();
    var ok = false;
    try {
      ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {}
    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(tr('no_tutor_here'))),
      );
    }
  }

  Future<void> _addKid() async {
    final kid = await showDialog<Kid>(
      context: context,
      builder: (_) => _KidDialog(store: store),
    );
    if (kid == null) return;
    setState(() => _kid = kid);
    _pair(kid);
  }

  void _pair(Kid kid) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(tr('pair')),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(tr('for_kid', {'name': kid.name})),
              const SizedBox(height: 8),
              QrCodes(Pairing(store.key, kid).encode(), size: 240),
              const SizedBox(height: 8),
              Text(tr('pair_text')),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _onThisPhone(kid);
            },
            child: Text(tr('this_phone')),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  Future<void> _fromCamera(ImageSource source) async {
    if (_kid == null) return _needKid();
    if (!await _needLicense()) return;
    // 1600 px is plenty for print; the parser scales to its own size.
    final file = await ImagePicker().pickImage(
      source: source,
      maxWidth: 1600,
      maxHeight: 1600,
      imageQuality: 85,
    );
    if (file == null) return;
    setState(() => _busy = true);
    try {
      final page = await recognizePage(file);
      final photo = await file.readAsBytes();
      if (!mounted) return;
      setState(() => _busy = false);
      final note = page.tasks.isEmpty
          ? tr('nothing_found')
          : page.looksComplete
          ? null
          : tr('hard_page');
      await _review(page.tasks, photo: photo, note: note);
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(tr('read_failed', {'e': e}))),
      );
    }
  }

  Future<void> _review(
    List<Task> tasks, {
    Uint8List? photo,
    String? note,
  }) async {
    final r = await Navigator.of(context).push<ReviewResult>(
      MaterialPageRoute(
        builder: (_) => ReviewScreen(tasks: tasks, photo: photo, note: note),
      ),
    );
    if (r == null || !mounted) return;
    if (!await _needLicense() || !mounted) return;
    final packet = TaskPacket(
      license: store.license,
      family: store.key.id,
      kid: _kid!.id,
      id: await store.nextPacketId(),
      lang: _kid!.schoolLang,
      source: r.source,
      tasks: r.tasks,
    );
    final code = packet.encode(store.key);
    await store.remember(code);
    if (!mounted) return;
    setState(() {});
    _showPacket(packet, code);
  }

  void _showPacket(TaskPacket p, String code) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => Scaffold(
          appBar: AppBar(title: Text(tr('qr_title'))),
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  QrCodes(code, size: 300),
                  const SizedBox(height: 16),
                  Text(
                    '${p.source.isEmpty ? p.id : p.source} · '
                    '${tr('found', {'n': p.tasks.length})}',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  Text(tr('qr_text'), textAlign: TextAlign.center),
                  const SizedBox(height: 24),
                  if (store.kids.where((k) => k.id == p.kid).firstOrNull
                      case final kid?)
                    FilledButton.icon(
                      onPressed: () => _onThisPhone(kid, packet: code),
                      icon: const Icon(Icons.child_care),
                      label: Text(tr('continue_here')),
                    ),
                  const SizedBox(height: 8),
                  Text(
                    tr('continue_here_text'),
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Turning reports on asks first and says what is sent; off is instant.
  Future<void> _toggleCrashReports() async {
    if (CrashReports.on.value) {
      await CrashReports.set(store.prefs, false);
      if (mounted) setState(() {});
      return;
    }
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(tr('crash_reports')),
        content: SingleChildScrollView(child: Text(tr('crash_reports_text'))),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(tr('cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(tr('crash_reports_on')),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await CrashReports.set(store.prefs, true);
    if (mounted) setState(() {});
  }

  /// The old phone: the family as a QR code, for a few minutes.
  void _moveOut() {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(tr('move_out')),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              QrCodes(store.exportFamily().encode(), size: 240),
              const SizedBox(height: 8),
              Text(tr('move_out_text')),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(tr('cancel')),
          ),
        ],
      ),
    );
  }

  /// The new phone: reads the old phone's code and takes the family over.
  Future<void> _moveIn() async {
    final code = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (_) => QrScanPage(
          title: tr('move_in'),
          hint: tr('move_in_hint'),
          accept: (c) =>
              FamilyTransfer.decode(c) == null ? tr('move_bad') : null,
        ),
      ),
    );
    if (code == null || !mounted) return;
    final t = FamilyTransfer.decode(code);
    if (t == null) return;
    if (t.key.id != store.key.id && store.kids.isNotEmpty) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          content: Text(tr('move_replace')),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(tr('cancel')),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(tr('move_in')),
            ),
          ],
        ),
      );
      if (ok != true) return;
    }
    await store.importFamily(t);
    if (!mounted) return;
    setState(() {});
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(tr('move_done', {'n': t.kids.length})),
      ),
    );
  }

  Future<void> _readReport() async {
    final code = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (_) => QrScanPage(
          title: tr('read_report'),
          hint: tr('report_hint'),
          accept: (c) =>
              LessonReport.decode(c, store.key) == null ? tr('not_ours') : null,
        ),
      ),
    );
    if (code == null) return;
    await store.addReport(code);
    setState(() {});
    if (mounted) _openReport(LessonReport.decode(code, store.key)!);
  }

  void _openReport(LessonReport r) {
    final sent = store.sent.where((p) => p.id == r.packet).firstOrNull;
    String taskText(String n) {
      final t = sent?.tasks.where((t) => t.n == n).firstOrNull;
      return t?.format() ?? tr('task_n', {'n': n});
    }

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => Scaffold(
          appBar: AppBar(title: Text(sent?.source ?? r.packet)),
          body: ListView(
            children: [
              for (final x in r.results)
                ListTile(
                  leading: Icon(
                    x.solved ? Icons.check_circle : Icons.cancel,
                    color: x.solved ? Colors.green : Colors.red,
                  ),
                  title: Text(taskText(x.n)),
                  subtitle: Text(
                    [
                      if (x.tries > 1) tr('tries', {'n': x.tries}),
                      if (x.hints > 0) tr('hints', {'n': x.hints}),
                      for (final m in x.mistakes) tr('mistake_${m.name}'),
                      for (final a in x.aids) _aidUsed(a),
                      '${x.seconds} s',
                    ].join(' · '),
                  ),
                ),
              if (r.errors.isNotEmpty)
                ListTile(
                  leading: const Icon(Icons.bug_report_outlined),
                  title: Text(tr('child_errors', {'n': r.errors.length})),
                  subtitle: Text(tr('child_errors_text')),
                  onTap: () {
                    Clipboard.setData(
                      ClipboardData(text: r.errors.join('\n')),
                    );
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(tr('copied'))),
                    );
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _needKid() {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(tr('no_kid'))));
  }

  @override
  Widget build(BuildContext context) {
    final kids = store.kids;
    final reports = store.reports;
    return Scaffold(
      appBar: AppBar(
        title: Text(tr('app')),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            onSelected: (v) => switch (v) {
              'out' => _moveOut(),
              'in' => _moveIn(),
              _ => _toggleCrashReports(),
            },
            itemBuilder: (_) => [
              PopupMenuItem(value: 'out', child: Text(tr('move_out'))),
              PopupMenuItem(value: 'in', child: Text(tr('move_in'))),
              if (CrashReports.available)
                CheckedPopupMenuItem(
                  value: 'crash',
                  checked: CrashReports.on.value,
                  child: Text(tr('crash_reports')),
                ),
            ],
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.language),
            onSelected: (l) {
              appLang.value = l;
              store.setLang(l);
            },
            itemBuilder: (_) => [
              for (final e in languages.entries)
                PopupMenuItem(value: e.key, child: Text(e.value)),
            ],
          ),
        ],
      ),
      body: _busy
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(height: 16),
                  Text(tr('reading')),
                ],
              ),
            )
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text(
                  tr('kids'),
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                Wrap(
                  spacing: 8,
                  children: [
                    for (final k in kids)
                      ChoiceChip(
                        label: Text(k.name),
                        selected: _kid?.id == k.id,
                        onSelected: (_) => setState(() => _kid = k),
                      ),
                    ActionChip(
                      avatar: const Icon(Icons.add),
                      label: Text(tr('add_kid')),
                      onPressed: _addKid,
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: () => _fromCamera(ImageSource.camera),
                  icon: const Icon(Icons.photo_camera),
                  label: Text(tr('photo')),
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: () => _fromCamera(ImageSource.gallery),
                  icon: const Icon(Icons.photo_library_outlined),
                  label: Text(tr('gallery')),
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: () async {
                    if (_kid == null) return _needKid();
                    if (await _needLicense()) await _review([]);
                  },
                  icon: const Icon(Icons.keyboard),
                  label: Text(tr('manual')),
                ),
                const SizedBox(height: 4),
                Text(
                  tr('local_note'),
                  style: Theme.of(context).textTheme.bodySmall,
                  textAlign: TextAlign.center,
                ),
                const Divider(height: 32),
                ListTile(
                  leading: Icon(
                    _licensing.active ? Icons.verified : Icons.lock_outline,
                    color: _licensing.active ? Colors.green : null,
                  ),
                  title: Text(tr('subscription')),
                  subtitle: Text(
                    _licensing.license == null
                        ? tr('sub_none_short')
                        : tr('sub_short', {
                            'n': _licensing.license!.daysLeft(DateTime.now()),
                          }),
                  ),
                  onTap: _subscription,
                ),
                if (_kid != null)
                  ListTile(
                    leading: const Icon(Icons.phonelink_lock),
                    title: Text(tr('pair')),
                    subtitle: Text(_kid!.name),
                    onTap: () => _pair(_kid!),
                  ),
                ListTile(
                  leading: const Icon(Icons.qr_code_scanner),
                  title: Text(tr('read_report')),
                  onTap: _readReport,
                ),
                if (reports.isNotEmpty) ...[
                  const Divider(height: 32),
                  Text(
                    tr('reports'),
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  for (final r in reports)
                    ListTile(
                      title: Text(
                        '${kids.where((k) => k.id == r.kid).firstOrNull?.name ?? ''} · '
                        '${r.finished.day}.${r.finished.month}.',
                      ),
                      subtitle: Text(
                        tr('solved', {
                          'n': r.results.where((x) => x.solved).length,
                          'total': r.results.length,
                        }),
                      ),
                      onTap: () => _openReport(r),
                    ),
                ],
              ],
            ),
    );
  }
}

class _KidDialog extends StatefulWidget {
  const _KidDialog({required this.store});
  final FamilyStore store;

  @override
  State<_KidDialog> createState() => _KidDialogState();
}

class _KidDialogState extends State<_KidDialog> {
  final _name = TextEditingController();
  int _grade = 2;
  String _school = 'de';
  String _home = 'ru';

  /// Physical aids on the desk; fingers and the screen abacus always count.
  final _aids = <String>{'abacus'};

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    DropdownButtonFormField<String> lang(
      String label,
      String value,
      ValueChanged<String> set,
    ) => DropdownButtonFormField<String>(
      initialValue: value,
      decoration: InputDecoration(labelText: label),
      items: [
        for (final e in languages.entries)
          DropdownMenuItem(value: e.key, child: Text(e.value)),
      ],
      onChanged: (v) => setState(() => set(v!)),
    );
    return AlertDialog(
      title: Text(tr('add_kid')),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _name,
              autofocus: true,
              decoration: InputDecoration(labelText: tr('name')),
            ),
            DropdownButtonFormField<int>(
              initialValue: _grade,
              decoration: InputDecoration(labelText: tr('grade')),
              items: [
                for (var g = 1; g <= 4; g++)
                  DropdownMenuItem(value: g, child: Text('$g')),
              ],
              onChanged: (v) => setState(() => _grade = v!),
            ),
            lang(tr('school_lang'), _school, (v) => _school = v),
            lang(tr('home_lang'), _home, (v) => _home = v),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(tr('aids_home')),
            ),
            for (final a in const [
              'abacus', 'twentyField', 'rods', 'hundredField',
              'additionTable', 'timesTable',
            ])
              CheckboxListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                value: _aids.contains(a),
                title: Text(tr('aid_$a')),
                onChanged: (v) => setState(
                  () => v! ? _aids.add(a) : _aids.remove(a),
                ),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(tr('cancel')),
        ),
        FilledButton(
          onPressed: () async {
            final name = _name.text.trim();
            if (name.isEmpty) return;
            final kid = await widget.store.addKid(
              name,
              _grade,
              _school,
              _home,
              aids: _aids,
            );
            if (context.mounted) Navigator.pop(context, kid);
          },
          child: Text(tr('save')),
        ),
      ],
    );
  }
}

/// "twentyField/act" as "Поле на 20 с фишками (руками)".
String _aidUsed(String a) {
  final p = a.split('/');
  return p.length == 2
      ? '${tr('aid_${p[0]}')} (${tr('stage_${p[1]}')})'
      : tr('aid_$a');
}
