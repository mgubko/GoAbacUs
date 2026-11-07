import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../arith/exercise.dart';
import '../arith/plan.dart';
import '../l10n/app_localizations.dart';
import 'abacus_view.dart';

const _ink = Color(0xFF402A1A);
const _accent = Color(0xFFB5452B);
const _gold = Color(0xFFE8A93A);

/// Settings for a sitting of exercises. Returns null when dismissed.
Future<ExerciseSettings?> showExerciseSetup(
  BuildContext context,
  ExerciseSettings initial,
) {
  return showModalBottomSheet<ExerciseSettings>(
    context: context,
    backgroundColor: const Color(0xFFF6EEE0),
    showDragHandle: true,
    // A plain sheet stops at 9/16 of the screen, too short for the keypad
    // on a phone: take the height needed and scroll if even that is short.
    isScrollControlled: true,
    builder: (context) => _Setup(initial: initial),
  );
}

class _Setup extends StatefulWidget {
  const _Setup({required this.initial});
  final ExerciseSettings initial;

  @override
  State<_Setup> createState() => _SetupState();
}

class _SetupState extends State<_Setup> {
  late var _ops = widget.initial.ops;
  late var _level = widget.initial.level;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final style = SegmentedButton.styleFrom(
      selectedBackgroundColor: const Color(0xFFE6D5B8),
      foregroundColor: _ink,
      textStyle: const TextStyle(fontSize: 16),
    );
    return SafeArea(
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  t.exercisesTooltip,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: _ink,
                  ),
                ),
                const SizedBox(height: 16),
                SegmentedButton<ExerciseOps>(
                  style: style,
                  showSelectedIcon: false,
                  segments: [
                    ButtonSegment(
                      value: ExerciseOps.add,
                      label: Text(t.opsAdd),
                    ),
                    ButtonSegment(
                      value: ExerciseOps.sub,
                      label: Text(t.opsSub),
                    ),
                    ButtonSegment(
                      value: ExerciseOps.both,
                      label: Text(t.opsBoth),
                    ),
                  ],
                  selected: {_ops},
                  onSelectionChanged: (s) => setState(() => _ops = s.first),
                ),
                const SizedBox(height: 12),
                SegmentedButton<ExerciseLevel>(
                  style: style,
                  showSelectedIcon: false,
                  segments: [
                    ButtonSegment(
                      value: ExerciseLevel.easy,
                      label: Text(t.levelEasy),
                    ),
                    ButtonSegment(
                      value: ExerciseLevel.hard,
                      label: Text(t.levelHard),
                    ),
                  ],
                  selected: {_level},
                  onSelectionChanged: (s) => setState(() => _level = s.first),
                ),
                const SizedBox(height: 8),
                Text(
                  _level == ExerciseLevel.easy
                      ? t.levelEasyHint
                      : t.levelHardHint,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: _ink.withValues(alpha: 0.7)),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  height: 56,
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: _accent,
                      textStyle: const TextStyle(fontSize: 20),
                    ),
                    onPressed: () => Navigator.of(
                      context,
                    ).pop(ExerciseSettings(ops: _ops, level: _level)),
                    child: Text(t.startButton),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The task strip: number, score, the task itself, the clock and "done".
class ExercisePanel extends StatelessWidget {
  const ExercisePanel({super.key, required this.controller});
  final AbacusController controller;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: controller.changes,
      builder: (context, _, _) {
        final e = controller.exercise;
        if (e == null) return const SizedBox.shrink();
        final t = AppLocalizations.of(context);
        final solving = e.state == TaskState.solving;
        final left =
            e.left.inMilliseconds / ExerciseSession.limit.inMilliseconds;
        final secs = (e.left.inMilliseconds / 1000).ceil().clamp(0, 60);
        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 12, 4),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Text(
                    t.taskNumber(e.number),
                    style: TextStyle(
                      fontSize: 15,
                      color: _ink.withValues(alpha: 0.7),
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Icon(Icons.star_rounded, color: _gold, size: 22),
                  Text(
                    ' ${e.solved}',
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: _ink,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    tooltip: t.exitTooltip,
                    color: _ink,
                    icon: const Icon(Icons.close_rounded),
                    onPressed: controller.stopExercises,
                  ),
                ],
              ),
              Row(
                children: [
                  Expanded(
                    // Wraps between terms instead of shrinking.
                    child: Text(
                      '${e.task.format()} =\u00A0${solving ? '?' : formatNumber(e.answer)}',
                      style: const TextStyle(
                        fontSize: 34,
                        fontWeight: FontWeight.w800,
                        color: _ink,
                        fontFeatures: [FontFeature.tabularFigures()],
                      ),
                    ),
                  ),
                  if (solving)
                    FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: _accent,
                        minimumSize: const Size(120, 48),
                        textStyle: const TextStyle(fontSize: 18),
                      ),
                      onPressed: controller.submitExercise,
                      child: Text(t.doneButton),
                    ),
                ],
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: solving ? left.clamp(0.0, 1.0) : 0,
                        minHeight: 8,
                        backgroundColor: _ink.withValues(alpha: 0.12),
                        color: secs <= 10 ? _accent : const Color(0xFF7A9A4A),
                      ),
                    ),
                  ),
                  SizedBox(
                    width: 44,
                    child: Text(
                      solving ? '$secs' : '',
                      textAlign: TextAlign.right,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: secs <= 10 ? _accent : _ink,
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(
                height: 22,
                child: solving
                    ? Text(
                        t.solveHint,
                        style: TextStyle(
                          fontSize: 14,
                          fontStyle: FontStyle.italic,
                          color: _ink.withValues(alpha: 0.55),
                        ),
                      )
                    : null,
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Over the abacus: stars and confetti for a right answer, a sad face for a
/// wrong one, with the buttons to go on.
class ExerciseResult extends StatelessWidget {
  const ExerciseResult({super.key, required this.controller});
  final AbacusController controller;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: controller.changes,
      builder: (context, _, _) {
        final e = controller.exercise;
        if (e == null ||
            e.state == TaskState.solving ||
            controller.player != null) {
          return const SizedBox.shrink();
        }
        final right = e.state == TaskState.right;
        return Stack(
          fit: StackFit.expand,
          children: [
            const ModalBarrier(color: Color(0x33000000), dismissible: false),
            if (right) const IgnorePointer(child: _Confetti()),
            Center(
              child: _ResultCard(
                // A new key per task restarts the animations.
                key: ValueKey(e.number),
                controller: controller,
                session: e,
              ),
            ),
          ],
        );
      },
    );
  }
}

class _ResultCard extends StatelessWidget {
  const _ResultCard({
    super.key,
    required this.controller,
    required this.session,
  });
  final AbacusController controller;
  final ExerciseSession session;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final right = session.state == TaskState.right;
    final title = switch (session.state) {
      TaskState.right => t.rightTitle,
      TaskState.timeUp => t.timeUpTitle,
      _ => t.wrongTitle,
    };
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: right ? 700 : 600),
      curve: right ? Curves.elasticOut : Curves.easeOut,
      builder: (context, k, child) {
        // Right: the card pops in. Wrong: it shakes its head.
        final shake = right ? 0.0 : math.sin(k * math.pi * 6) * (1 - k) * 18;
        return Transform.translate(
          offset: Offset(shake, 0),
          child: Transform.scale(
            scale: right ? 0.6 + 0.4 * k : 1,
            child: child,
          ),
        );
      },
      child: Container(
        width: 340,
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 20),
        decoration: BoxDecoration(
          color: const Color(0xFFFBF5EA),
          borderRadius: BorderRadius.circular(24),
          boxShadow: const [
            BoxShadow(blurRadius: 24, color: Color(0x55000000)),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (right)
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (var i = 0; i < 3; i++)
                    Padding(
                      padding: EdgeInsets.only(bottom: i == 1 ? 16 : 0),
                      child: Icon(
                        Icons.star_rounded,
                        color: _gold,
                        size: i == 1 ? 76 : 56,
                      ),
                    ),
                ],
              )
            else
              Icon(
                session.state == TaskState.timeUp
                    ? Icons.hourglass_bottom_rounded
                    : Icons.sentiment_dissatisfied_rounded,
                color: const Color(0xFF8A7A6A),
                size: 76,
              ),
            const SizedBox(height: 8),
            Text(
              title,
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w800,
                color: right ? _accent : _ink,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              right
                  ? '${session.task.format()} = ${formatNumber(session.answer)}'
                  : t.answerIs(formatNumber(session.answer)),
              style: const TextStyle(fontSize: 18, color: _ink),
            ),
            if (right && session.streak >= 2) ...[
              const SizedBox(height: 4),
              Text(
                t.streakText(session.streak),
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: _gold,
                ),
              ),
            ],
            const SizedBox(height: 18),
            if (!right)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: _ink,
                      textStyle: const TextStyle(fontSize: 17),
                    ),
                    icon: const Icon(Icons.play_arrow_rounded),
                    label: Text(t.showSolution),
                    onPressed: controller.showSolution,
                  ),
                ),
              ),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: _accent,
                  textStyle: const TextStyle(fontSize: 19),
                ),
                icon: const Icon(Icons.arrow_forward_rounded),
                label: Text(t.nextButton),
                onPressed: controller.nextExercise,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A short burst of paper confetti and stars.
class _Confetti extends StatefulWidget {
  const _Confetti();

  @override
  State<_Confetti> createState() => _ConfettiState();
}

class _ConfettiState extends State<_Confetti>
    with SingleTickerProviderStateMixin {
  late final _anim = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2600),
  )..forward();
  final _bits = List.generate(70, (i) => _Bit(math.Random(i)));

  @override
  void dispose() {
    _anim.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      CustomPaint(painter: _ConfettiPainter(_anim, _bits), size: Size.infinite);
}

class _Bit {
  _Bit(math.Random r)
    : angle = -math.pi / 2 + (r.nextDouble() - 0.5) * 2.2,
      speed = 0.6 + r.nextDouble() * 0.7,
      spin = (r.nextDouble() - 0.5) * 16,
      size = 6 + r.nextDouble() * 8,
      star = r.nextDouble() < 0.25,
      color = const [
        Color(0xFFE8A93A),
        Color(0xFFB5452B),
        Color(0xFF7A9A4A),
        Color(0xFF4A7AA8),
        Color(0xFFD9779F),
      ][r.nextInt(5)];
  final double angle, speed, spin, size;
  final bool star;
  final Color color;
}

class _ConfettiPainter extends CustomPainter {
  _ConfettiPainter(this.anim, this.bits) : super(repaint: anim);
  final Animation<double> anim;
  final List<_Bit> bits;

  @override
  void paint(Canvas canvas, Size size) {
    final t = anim.value * 2.6;
    final origin = Offset(size.width / 2, size.height * 0.45);
    final scale = size.shortestSide;
    final fade = (1 - anim.value).clamp(0.0, 1.0);
    for (final b in bits) {
      final v = b.speed * scale * 1.1;
      final p =
          origin +
          Offset(
            math.cos(b.angle) * v * t * 0.6,
            math.sin(b.angle) * v * t + 0.5 * scale * 1.6 * t * t,
          );
      final paint = Paint()..color = b.color.withValues(alpha: fade);
      canvas.save();
      canvas.translate(p.dx, p.dy);
      canvas.rotate(b.spin * t);
      if (b.star) {
        canvas.drawPath(_star(b.size * 0.9), paint);
      } else {
        canvas.drawRect(
          Rect.fromCenter(
            center: Offset.zero,
            width: b.size,
            height: b.size * 0.5,
          ),
          paint,
        );
      }
      canvas.restore();
    }
  }

  Path _star(double r) {
    final path = Path();
    for (var i = 0; i < 10; i++) {
      final a = -math.pi / 2 + i * math.pi / 5;
      final rr = i.isEven ? r : r * 0.45;
      final o = Offset(math.cos(a) * rr, math.sin(a) * rr);
      i == 0 ? path.moveTo(o.dx, o.dy) : path.lineTo(o.dx, o.dy);
    }
    return path..close();
  }

  @override
  bool shouldRepaint(_ConfettiPainter old) => false;
}
