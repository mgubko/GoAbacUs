import 'package:flutter/material.dart';

import '../arith/explain.dart';
import '../arith/plan.dart';
import '../l10n/app_localizations.dart';
import 'abacus_view.dart';

const _ink = Color(0xFF402A1A);
const _accent = Color(0xFFB5452B);

String placeName(AppLocalizations t, int place) => switch (place) {
  0 => t.place0,
  1 => t.place1,
  2 => t.place2,
  3 => t.place3,
  4 => t.place4,
  5 => t.place5,
  6 => t.place6,
  7 => t.place7,
  8 => t.place8,
  _ => t.place9,
};

/// What move [i] of [step] does and by which tutorial rule.
String moveNote(AppLocalizations t, DigitStep step, int i) {
  final m = step.moves[i];
  final place = placeName(t, m.row);
  final count = m.count.abs();
  final friend = 10 - step.digit;
  return switch (roleOf(step, i)) {
    MoveRole.direct => switch (ruleOf(step)) {
      Rule.set => t.noteSet(place, count),
      Rule.subFits => t.noteSubFits(place, count),
      _ => t.noteAddFits(place, count),
    },
    MoveRole.carryOne => t.noteCarryOne(place, step.digit),
    MoveRole.carryThroughNine => t.noteCarryNine(place),
    MoveRole.takeFriend => t.noteTakeFriend(place, step.digit, friend),
    MoveRole.borrowOne => t.noteBorrowOne(place, step.digit),
    MoveRole.borrowThroughZero => t.noteBorrowZero(place),
    MoveRole.giveFriend => t.noteGiveFriend(place, step.digit, friend),
  };
}

/// The strip under the number: what was written down from the child's
/// moves, or the example being shown with a caption for every digit.
class ExamplePanel extends StatelessWidget {
  const ExamplePanel({
    super.key,
    required this.controller,
    this.onBackToTutorial,
  });
  final AbacusController controller;

  /// When set, a button leads back to the tutorial page the example came
  /// from.
  final VoidCallback? onBackToTutorial;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: controller.changes,
      builder: (context, _, _) {
        final t = AppLocalizations.of(context);
        final player = controller.player;
        final Widget line;
        Widget? caption;
        Widget? hint;
        Widget? button;
        if (player != null) {
          line = _exampleLine(player.example, player.term, player.done);
          final step = player.step;
          if (player.done && controller.exercise != null) {
            button = _button(
              Icons.arrow_forward_rounded,
              t.nextButton,
              controller.nextExercise,
            );
          } else if (player.done) {
            button = _button(
              Icons.replay,
              t.replayTooltip,
              () => controller.play(player.example),
            );
          } else {
            button = _button(
              Icons.stop_circle_outlined,
              t.stopTooltip,
              controller.stop,
            );
            if (step == null) {
              caption = Text(t.clearing);
            } else {
              final n = formatNumber(player.example.terms[step.term].abs());
              final what = step.term == 0
                  ? t.stepSet(n)
                  : step.add
                  ? t.stepAdd(n)
                  : t.stepSub(n);
              final sign = step.add ? '+' : '−';
              final back = step.add ? '−' : '+';
              final math = step.complement == null
                  ? '$sign ${step.digit}'
                  : '$sign ${step.digit} = $sign 10 $back ${step.complement}';
              caption = Text.rich(
                TextSpan(
                  children: [
                    TextSpan(text: '$what · '),
                    TextSpan(
                      text: '${placeName(t, step.place)}: $math',
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        color: _accent,
                      ),
                    ),
                  ],
                ),
              );
              hint = Text(moveNote(t, step, player.move));
            }
          }
        } else {
          final e = controller.tape.example;
          if (e == null) {
            line = Text(
              t.tapeHint,
              style: TextStyle(
                fontSize: 16,
                color: _ink.withValues(alpha: 0.55),
                fontStyle: FontStyle.italic,
              ),
            );
          } else {
            line = _exampleLine(e, e.terms.length - 1, e.terms.length > 1);
            button = _button(
              Icons.play_arrow_rounded,
              t.replayTooltip,
              () => controller.play(e),
            );
          }
        }
        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 12, 4),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      height: 30,
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: FittedBox(fit: BoxFit.scaleDown, child: line),
                      ),
                    ),
                    DefaultTextStyle.merge(
                      style: const TextStyle(fontSize: 15, color: _ink),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      // Scaled down rather than cut: the formula at its end
                      // is what matters.
                      child: SizedBox(
                        height: 20,
                        child: caption == null
                            ? null
                            : FittedBox(
                                fit: BoxFit.scaleDown,
                                alignment: Alignment.centerLeft,
                                child: caption,
                              ),
                      ),
                    ),
                    DefaultTextStyle.merge(
                      style: TextStyle(
                        fontSize: 13,
                        color: _ink.withValues(alpha: 0.7),
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      child: SizedBox(height: 36, child: hint),
                    ),
                  ],
                ),
              ),
              if (onBackToTutorial != null)
                _button(
                  Icons.menu_book_outlined,
                  t.backToTutorial,
                  onBackToTutorial!,
                ),
              ?button,
            ],
          ),
        );
      },
    );
  }

  Widget _button(IconData icon, String tooltip, VoidCallback onPressed) =>
      IconButton(
        tooltip: tooltip,
        color: _ink,
        iconSize: 34,
        icon: Icon(icon),
        onPressed: onPressed,
      );

  /// 25 + 17 − 8 = 34, with the term being worked highlighted.
  Widget _exampleLine(Example e, int current, bool showAnswer) {
    final spans = <TextSpan>[];
    for (var i = 0; i < e.terms.length; i++) {
      final v = e.terms[i];
      final text = i == 0
          ? formatNumber(v)
          : '${v < 0 ? ' − ' : ' + '}${formatNumber(v.abs())}';
      final style = i == current && !showAnswer
          ? const TextStyle(color: _accent, fontWeight: FontWeight.w800)
          : i > current
          ? TextStyle(color: _ink.withValues(alpha: 0.35))
          : null;
      spans.add(TextSpan(text: text, style: style));
    }
    if (showAnswer) {
      spans.add(
        TextSpan(
          text: ' = ${formatNumber(e.result)}',
          style: const TextStyle(color: _accent, fontWeight: FontWeight.w800),
        ),
      );
    }
    return Text.rich(
      TextSpan(children: spans),
      maxLines: 1,
      style: const TextStyle(
        fontSize: 24,
        fontWeight: FontWeight.w600,
        color: _ink,
        fontFeatures: [FontFeature.tabularFigures()],
      ),
    );
  }
}

/// Keypad for typing an example. Returns the example to show, or null.
Future<Example?> showExampleEntry(
  BuildContext context, {
  required int maxValue,
}) {
  return showModalBottomSheet<Example>(
    context: context,
    backgroundColor: const Color(0xFFF6EEE0),
    showDragHandle: true,
    // A plain sheet stops at 9/16 of the screen, too short for the keypad
    // on a phone: take the height needed and scroll if even that is short.
    isScrollControlled: true,
    builder: (context) => _ExampleEntry(maxValue: maxValue),
  );
}

class _ExampleEntry extends StatefulWidget {
  const _ExampleEntry({required this.maxValue});
  final int maxValue;

  @override
  State<_ExampleEntry> createState() => _ExampleEntryState();
}

class _ExampleEntryState extends State<_ExampleEntry> {
  var _text = '';
  String? _error;

  void _key(String k) {
    setState(() {
      _error = null;
      if (k == '⌫') {
        if (_text.isNotEmpty) _text = _text.substring(0, _text.length - 1);
      } else if (k == 'C') {
        _text = '';
      } else if (k == '+' || k == '−') {
        if (_text.isEmpty) return;
        final last = _text[_text.length - 1];
        if (last == '+' || last == '−') {
          _text = _text.substring(0, _text.length - 1);
        }
        _text += k;
      } else {
        _text += k;
      }
    });
  }

  void _show(AppLocalizations t) {
    final r = parseExample(_text, maxValue: widget.maxValue);
    if (r.example != null) {
      Navigator.of(context).pop(r.example);
      return;
    }
    setState(() {
      _error = switch (r.error!) {
        ExampleError.negative => t.errorNegative,
        ExampleError.tooBig => t.errorTooBig,
        _ => t.errorUnfinished,
      };
    });
  }

  String get _pretty => _text
      .replaceAll('+', ' + ')
      .replaceAll('−', ' − ')
      .replaceAllMapped(
        RegExp(r'\d+'),
        (m) => formatNumber(int.parse(m.group(0)!)),
      );

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    const keys = [
      ['7', '8', '9', '+'],
      ['4', '5', '6', '−'],
      ['1', '2', '3', '⌫'],
      ['C', '0', '', ''],
    ];
    return SafeArea(
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(t.enterExample, style: const TextStyle(color: _ink)),
                const SizedBox(height: 8),
                Container(
                  height: 56,
                  alignment: Alignment.centerRight,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: _ink.withValues(alpha: 0.25)),
                  ),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      _pretty.isEmpty ? '25 + 17 − 8' : _pretty,
                      style: TextStyle(
                        fontSize: 30,
                        fontWeight: FontWeight.w600,
                        color: _pretty.isEmpty
                            ? _ink.withValues(alpha: 0.25)
                            : _ink,
                      ),
                    ),
                  ),
                ),
                SizedBox(
                  height: 24,
                  child: _error == null
                      ? null
                      : Text(_error!, style: const TextStyle(color: _accent)),
                ),
                for (final row in keys)
                  Row(
                    children: [
                      for (final k in row)
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.all(4),
                            child: k.isEmpty
                                ? const SizedBox(height: 56)
                                : _Key(label: k, onTap: () => _key(k)),
                          ),
                        ),
                    ],
                  ),
                Padding(
                  padding: const EdgeInsets.all(4),
                  child: SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: _accent,
                        textStyle: const TextStyle(fontSize: 20),
                      ),
                      icon: const Icon(Icons.play_arrow_rounded),
                      label: Text(t.showButton),
                      onPressed: () => _show(t),
                    ),
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

class _Key extends StatelessWidget {
  const _Key({required this.label, required this.onTap});
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final op = !RegExp(r'\d').hasMatch(label);
    return SizedBox(
      height: 56,
      child: Material(
        color: op ? const Color(0xFFE6D5B8) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Center(
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w600,
                color: _ink,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
