import 'package:abacus_kit/abacus_kit.dart';
import 'package:flutter/material.dart';
import 'package:tutor_tasks/tutor_tasks.dart';

import 'aid_picture.dart';
import 'lesson.dart';
import 'speech/voice.dart';
import 'strings.dart';

/// A lesson on the screen abacus. Returns the lesson when it was finished.
class LessonScreen extends StatefulWidget {
  const LessonScreen({
    super.key,
    required this.packet,
    this.kid,
    this.progress,
    this.available,
  });
  final TaskPacket packet;
  final Kid? kid;

  /// The child's streaks per skill; the lesson moves them on.
  final Progress? progress;

  /// The aids on the desk; null takes them from [kid].
  final Set<Aid>? available;

  @override
  State<LessonScreen> createState() => _LessonScreenState();
}

class _LessonScreenState extends State<LessonScreen> {
  static const rows = 4;
  final _abacus = AbacusController(config: const AbacusConfig(rows: rows));
  late final Lesson _lesson = Lesson(
    widget.packet,
    rows: rows,
    kid: widget.kid,
    progress: widget.progress,
    available: widget.available,
  );
  final _voice = Voice();
  String _typed = '';
  bool _ownDemo = false;
  bool _wasPlaying = false;
  double _rest = 0;
  int? _restValue;
  bool _nudge = false;

  @override
  void initState() {
    super.initState();
    _abacus.showDigits = false;
    _abacus.sound.init();
    _abacus.tilt.start();
    _abacus.addListener(_onTick);
    _lesson.addListener(_onLesson);
    _onLesson();
  }

  @override
  void dispose() {
    _abacus.removeListener(_onTick);
    _abacus.dispose();
    _lesson.dispose();
    _voice.dispose();
    super.dispose();
  }

  Duration? _lastTick;

  void _onLesson() {
    final p = _lesson.preset;
    if (p != null) {
      // Put the number on the abacus for the child to look at.
      _abacus.physics.clear();
      var v = p;
      for (var r = 0; r < rows; r++) {
        _abacus.physics.setRowCount(r, v % 10);
        v ~/= 10;
      }
      _lesson.presetDone();
    }
    _voice.say(_lesson.say, appLang.value);
    if (mounted) setState(() {});
  }

  /// Called every frame by the abacus: feeds the lesson the settled number.
  void _onTick() {
    final now = Duration(microseconds: DateTime.now().microsecondsSinceEpoch);
    final dt = _lastTick == null
        ? 0.0
        : ((now - _lastTick!).inMicroseconds / 1e6).clamp(0.0, 0.1);
    _lastTick = now;
    if (_lesson.tick(dt)) setState(() => _nudge = true);
    final playing = _abacus.playing;
    if (_wasPlaying && !playing) {
      _wasPlaying = false;
      _abacus.takeOver();
      _lesson.demoDone(own: _ownDemo);
      return;
    }
    _wasPlaying = playing;
    if (playing) return;
    final v = _abacus.physics.value;
    if (_abacus.physics.isAtRest) {
      if (v != _restValue) {
        _restValue = v;
        _rest = 0;
      }
      _rest += dt;
      // A number counts once the beads lie still for a moment.
      if (_rest > 0.5) _lesson.onAbacus(v);
    } else {
      _rest = 0;
      _restValue = null;
    }
  }

  void _key(String k) {
    if (_lesson.phase == Phase.right) return;
    setState(() {
      if (k == '⌫') {
        if (_typed.isNotEmpty) _typed = _typed.substring(0, _typed.length - 1);
      } else if (k == 'OK') {
        if (_typed.isEmpty) return;
        final ok = _lesson.submit(int.parse(_typed));
        _abacus.sound.cue(success: ok);
        _typed = '';
        if (ok) {
          _abacus.highlightRow = null;
          Future.delayed(const Duration(milliseconds: 1600), () {
            if (!mounted) return;
            final wasLast =
                _lesson.questionIndex + 1 >= _lesson.task.questions.length;
            final continues =
                !wasLast &&
                _lesson.task.questions[_lesson.questionIndex + 1].continues;
            _lesson.next();
            if (!continues && _lesson.phase != Phase.done) {
              _abacus.physics.sweepRight();
            }
          });
        }
      } else if (_typed.length < 4) {
        _typed += k;
      }
    });
  }

  void _hint() {
    _nudge = false;
    final h = _lesson.nextHint();
    _abacus.highlightRow = h.row;
    if (h.demo != null) {
      _ownDemo = h.demoIsOwn;
      _abacus.highlightRow = null;
      _abacus.play(h.demo!);
      _wasPlaying = true;
    }
  }

  /// Straight to the similar example (the third step of the ladder).
  void _similar() {
    _lesson.hint = 2;
    _hint();
  }

  Widget _aidArea() {
    final l = _lesson;
    final showAbacus = l.usesAbacus || l.phase == Phase.demo;
    final abacus = Visibility(
      visible: showAbacus && !l.aidHidden,
      maintainState: true,
      maintainAnimation: true,
      maintainSize: true,
      // A screen reader names the abacus but does not read its value: the
      // child is meant to count the beads.
      child: Semantics(
        label: tr('name_abacus'),
        child: AbacusView(controller: _abacus),
      ),
    );
    Widget? over;
    if (l.aidHidden) {
      over = _EyesClosed(aid: l.choice.aid);
    } else if (!showAbacus) {
      over = Semantics(
        image: true,
        label: tr('name_${l.choice.aid.name}'),
        child: AidPicture(
          aid: l.choice.aid,
          question: l.question,
          reveal: l.reveal,
        ),
      );
    }
    return Stack(fit: StackFit.expand, children: [abacus, ?over]);
  }

  @override
  Widget build(BuildContext context) {
    if (_lesson.phase == Phase.done) return _Done(lesson: _lesson);
    final l = _lesson;
    return Scaffold(
      backgroundColor: const Color(0xFFE9DCC6),
      appBar: AppBar(
        backgroundColor: const Color(0xFFE9DCC6),
        title: Text(tr('task_of', {'n': l.number, 'total': l.tasks.length})),
        actions: [
          ValueListenableBuilder(
            valueListenable: Voice.on,
            builder: (context, on, _) => IconButton(
              tooltip: tr('voice'),
              icon: Icon(on ? Icons.volume_up : Icons.volume_off),
              onPressed: () {
                Voice.on.value = !on;
                if (on) {
                  _voice.stop();
                } else {
                  _voice.repeat(appLang.value);
                }
              },
            ),
          ),
          TextButton(
            onPressed: () => setState(l.skip),
            child: Text(tr('skip')),
          ),
        ],
      ),
      body: SafeArea(
        child: LayoutBuilder(
          // Small phones and large text: the task and the owl's words get
          // a share of the height and scroll inside it; the abacus keeps
          // the rest.
          builder: (context, box) => Column(
            children: [
              ConstrainedBox(
                constraints: BoxConstraints(maxHeight: box.maxHeight * 0.2),
                child: SingleChildScrollView(
                  child: _TaskCard(lesson: l, typed: _typed),
                ),
              ),
              ConstrainedBox(
                constraints: BoxConstraints(maxHeight: box.maxHeight * 0.2),
                child: SingleChildScrollView(
                  child: GestureDetector(
                    // Tap the owl's words to hear them again.
                    onTap: () => _voice.repeat(appLang.value),
                    excludeFromSemantics: true,
                    child: _Bubble(
                      onTap: () => _voice.repeat(appLang.value),
                      text: saying(l.say),
                      happy: l.phase == Phase.right,
                    ),
                  ),
                ),
              ),
              _AidBar(
                lesson: l,
                onSwitch: l.phase == Phase.answer || l.phase == Phase.setStart
                    ? l.switchAid
                    : null,
              ),
              Expanded(child: _aidArea()),
              _Tools(
                onHint: l.phase == Phase.demo || l.phase == Phase.right
                    ? null
                    : _hint,
                onSimilar: l.phase == Phase.demo || l.phase == Phase.right
                    ? null
                    : _similar,
                onClear: l.phase == Phase.demo || !l.usesAbacus
                    ? null
                    : _abacus.clear,
                nudge: _nudge,
              ),
              _Keypad(
                onKey: _key,
                keyHeight: (box.maxHeight * 0.065).clamp(48.0, 56.0),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Which aid the tutor chose and how far from it the child is.
class _AidBar extends StatelessWidget {
  const _AidBar({required this.lesson, required this.onSwitch});
  final Lesson lesson;
  final VoidCallback? onSwitch;

  @override
  Widget build(BuildContext context) {
    final c = lesson.choice;
    final icon = switch (c.aid) {
      Aid.fingers => '✋',
      Aid.twentyField => '🔴',
      Aid.rods => '📏',
      Aid.abacus => '🧮',
      Aid.hundredField => '⠿',
      Aid.additionTable || Aid.timesTable => '▦',
    };
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        children: [
          Flexible(
            child: Chip(
              avatar: ExcludeSemantics(child: Text(icon)),
              label: Text(
                '${tr('name_${c.aid.name}')} · ${tr('stage_name_${c.stage.name}')}',
                overflow: TextOverflow.ellipsis,
              ),
              backgroundColor: const Color(0xFFFDFAF1),
            ),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: TextButton.icon(
              onPressed: onSwitch,
              icon: const Icon(Icons.swap_horiz),
              label: Text(tr('switch_aid'), overflow: TextOverflow.ellipsis),
            ),
          ),
        ],
      ),
    );
  }
}

/// The aid is hidden: the child sees it in the head.
class _EyesClosed extends StatelessWidget {
  const _EyesClosed({required this.aid});
  final Aid aid;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF3B2A1E),
        borderRadius: BorderRadius.circular(14),
      ),
      alignment: Alignment.center,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('🙈', style: TextStyle(fontSize: 56)),
          const SizedBox(height: 8),
          Text(
            tr('eyes_closed'),
            style: const TextStyle(fontSize: 20, color: Color(0xFFFDFAF1)),
          ),
        ],
      ),
    );
  }
}

class _TaskCard extends StatelessWidget {
  const _TaskCard({required this.lesson, required this.typed});
  final Lesson lesson;
  final String typed;

  @override
  Widget build(BuildContext context) {
    final t = lesson.task;
    final q = lesson.question;
    final big = Theme.of(context).textTheme.headlineMedium!.copyWith(
      fontWeight: FontWeight.w700,
      color: const Color(0xFF402A1A),
    );
    final small = Theme.of(
      context,
    ).textTheme.titleMedium!.copyWith(color: const Color(0xFF6B4E3A));
    final lines = <Widget>[];
    if (t is StepsTask || t is ChainTask || t is HouseTask) {
      lines.add(Text(t.format(), style: small));
      for (var i = 0; i < lesson.questionIndex; i++) {
        final done = t.questions[i];
        lines.add(
          Text(done.format().replaceFirst('?', '${done.answer}'), style: small),
        );
      }
    }
    final shown = q.format().replaceFirst(
      '?',
      typed.isEmpty
          ? (lesson.phase == Phase.right ? '${q.answer}' : '?')
          : typed,
    );
    lines.add(Text(shown, style: big));
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(12, 4, 12, 4),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFDFAF1),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(children: lines),
    );
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({required this.text, required this.happy, this.onTap});
  final String text;
  final bool happy;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ExcludeSemantics(
            child: Text(
              happy ? '🦉✨' : '🦉',
              style: const TextStyle(fontSize: 34),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 250),
              layoutBuilder: (current, previous) => Stack(
                alignment: Alignment.topLeft,
                children: [...previous, ?current],
              ),
              child: Container(
                key: ValueKey(text),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: happy
                      ? const Color(0xFFDDEFD0)
                      : const Color(0xFFFFF4D6),
                  borderRadius: BorderRadius.circular(12),
                ),
                // A screen reader reads each new instruction by itself.
                child: Semantics(
                  liveRegion: true,
                  onTap: onTap,
                  onTapHint: tr('repeat_hint'),
                  child: Text(text, style: const TextStyle(fontSize: 18)),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Tools extends StatelessWidget {
  const _Tools({
    required this.onHint,
    required this.onSimilar,
    required this.onClear,
    required this.nudge,
  });
  final VoidCallback? onHint;
  final VoidCallback? onSimilar;
  final VoidCallback? onClear;
  final bool nudge;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        children: [
          for (final (i, (on, icon, label)) in [
            (onHint, Icons.lightbulb_outline, tr('hint')),
            (onSimilar, Icons.play_circle_outline, tr('similar')),
            (onClear, Icons.cleaning_services_outlined, tr('clear')),
          ].indexed)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 3),
                child: FilledButton.tonal(
                  onPressed: on,
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    backgroundColor: i == 0 && nudge
                        ? const Color(0xFFFFD36B)
                        : null,
                  ),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(icon, size: 20),
                        const SizedBox(width: 4),
                        Text(label),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _Keypad extends StatelessWidget {
  const _Keypad({required this.onKey, this.keyHeight = 52});
  final void Function(String) onKey;
  final double keyHeight;

  @override
  Widget build(BuildContext context) {
    Widget key(String k) => Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 1.5, vertical: 2),
        child: SizedBox(
          height: keyHeight,
          child: FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: k == 'OK'
                  ? const Color(0xFF4E7D3A)
                  : const Color(0xFF8A5A3B),
              padding: EdgeInsets.zero,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            onPressed: () => onKey(k),
            child: Text(
              k,
              style: const TextStyle(fontSize: 24),
              semanticsLabel: k == '⌫' ? tr('erase') : null,
            ),
          ),
        ),
      ),
    );
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 4, 4, 6),
      child: Column(
        children: [
          Row(children: [for (final k in '12345⌫'.characters) key(k)]),
          Row(
            children: [
              for (final k in ['6', '7', '8', '9', '0', 'OK']) key(k),
            ],
          ),
        ],
      ),
    );
  }
}

class _Done extends StatelessWidget {
  const _Done({required this.lesson});
  final Lesson lesson;

  @override
  Widget build(BuildContext context) {
    final r = lesson.results;
    final solved = r.where((x) => x.solved).length;
    final hinted = r.where((x) => x.hints > 0).length;
    return Scaffold(
      backgroundColor: const Color(0xFFE9DCC6),
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('🦉🎉', style: TextStyle(fontSize: 64)),
                const SizedBox(height: 12),
                Text(
                  tr('done'),
                  style: Theme.of(context).textTheme.headlineSmall,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                Text(
                  '${tr('solved', {'n': solved, 'total': r.length})}, '
                  '${tr('hints_used', {'n': hinted})}',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: () => Navigator.of(context).pop(lesson),
                  child: Text(tr('next')),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
