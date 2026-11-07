import 'package:flutter/material.dart';

import '../arith/plan.dart';
import '../l10n/app_localizations.dart';
import 'example_panel.dart' show placeName;

const _ink = Color(0xFF402A1A);
const _accent = Color(0xFFB5452B);
const _paper = Color(0xFFF6EEE0);

/// The rules of counting on the abacus, page by page. Returns an example to
/// show on the big abacus when the child taps "Show", otherwise null.
Future<Example?> showTutorial(BuildContext context) {
  return Navigator.of(context).push<Example>(
    MaterialPageRoute(builder: (context) => const TutorialScreen()),
  );
}

/// A picture of a few wires: [digits] from the highest place down to the
/// ones. [after], when given, is drawn below with an arrow: the same wires
/// once the example is worked.
class _Picture {
  const _Picture(this.digits, {this.after, this.labels});
  final List<int> digits;
  final List<int>? after;

  /// Captions to the right of the wires instead of the place names.
  final List<String>? labels;
}

class _Page {
  const _Page(this.title, this.body, {this.picture, this.example});
  final String title;
  final String body;
  final _Picture? picture;
  final List<int>? example;
}

List<_Page> _pages(AppLocalizations t) => [
  _Page(t.tutWiresTitle, t.tutWiresBody, picture: const _Picture([0, 0, 6])),
  _Page(
    t.tutSetTitle,
    t.tutSetBody,
    picture: const _Picture([2, 5, 4]),
    example: const [254],
  ),
  _Page(
    t.tutAddTitle,
    t.tutAddBody,
    picture: const _Picture([2, 3], after: [6, 8]),
    example: const [23, 45],
  ),
  _Page(
    t.tutFriendsTitle,
    t.tutFriendsBody,
    picture: const _Picture([7, 3], labels: ['7 + 3 = 10', '3 + 7 = 10']),
  ),
  _Page(
    t.tutCarryTitle,
    t.tutCarryBody,
    picture: const _Picture([0, 5], after: [1, 2]),
    example: const [5, 7],
  ),
  _Page(
    t.tutSubTitle,
    t.tutSubBody,
    picture: const _Picture([5, 8], after: [3, 2]),
    example: const [58, -26],
  ),
  _Page(
    t.tutBorrowTitle,
    t.tutBorrowBody,
    picture: const _Picture([1, 2], after: [0, 5]),
    example: const [12, -7],
  ),
  _Page(
    t.tutChainTitle,
    t.tutChainBody,
    picture: const _Picture([0, 9, 9], after: [1, 0, 0]),
    example: const [99, 1],
  ),
  _Page(t.tutTryTitle, t.tutTryBody),
];

class TutorialScreen extends StatefulWidget {
  const TutorialScreen({super.key});

  @override
  State<TutorialScreen> createState() => _TutorialScreenState();
}

class _TutorialScreenState extends State<TutorialScreen> {
  final _controller = PageController();
  var _page = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _go(int page) => _controller.animateToPage(
    page,
    duration: const Duration(milliseconds: 300),
    curve: Curves.easeOut,
  );

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final pages = _pages(t);
    final last = _page == pages.length - 1;
    return Scaffold(
      backgroundColor: _paper,
      appBar: AppBar(
        backgroundColor: _paper,
        foregroundColor: _ink,
        title: Text(t.tutorialTitle),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: PageView.builder(
                controller: _controller,
                itemCount: pages.length,
                onPageChanged: (p) => setState(() => _page = p),
                itemBuilder: (context, i) => _PageView(page: pages[i]),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
              child: Row(
                children: [
                  TextButton.icon(
                    style: TextButton.styleFrom(foregroundColor: _ink),
                    onPressed: _page == 0 ? null : () => _go(_page - 1),
                    icon: const Icon(Icons.arrow_back_rounded),
                    label: Text(t.tutorialBack),
                  ),
                  Expanded(
                    child: Text(
                      t.tutorialPage(_page + 1, pages.length),
                      textAlign: TextAlign.center,
                      style: TextStyle(color: _ink.withValues(alpha: 0.6)),
                    ),
                  ),
                  FilledButton.icon(
                    style: FilledButton.styleFrom(backgroundColor: _accent),
                    onPressed: last
                        ? () => Navigator.of(context).pop()
                        : () => _go(_page + 1),
                    icon: Icon(
                      last ? Icons.check_rounded : Icons.arrow_forward_rounded,
                    ),
                    label: Text(last ? t.tutorialDone : t.nextButton),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PageView extends StatelessWidget {
  const _PageView({required this.page});
  final _Page page;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final picture = page.picture;
    final example = page.example == null ? null : Example(page.example!);
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                page.title,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  color: _accent,
                ),
              ),
              const SizedBox(height: 16),
              if (picture != null) ...[
                _MiniAbacus(digits: picture.digits, labels: picture.labels),
                if (picture.after != null) ...[
                  const Icon(
                    Icons.arrow_downward_rounded,
                    color: _accent,
                    size: 32,
                  ),
                  _MiniAbacus(
                    digits: picture.after!,
                    changed: [
                      for (var i = 0; i < picture.digits.length; i++)
                        picture.digits[i] != picture.after![i],
                    ],
                  ),
                ],
                const SizedBox(height: 16),
              ],
              Text(
                page.body,
                style: const TextStyle(fontSize: 18, height: 1.4, color: _ink),
              ),
              if (example != null) ...[
                const SizedBox(height: 20),
                Align(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: _accent,
                      side: const BorderSide(color: _accent),
                      textStyle: const TextStyle(fontSize: 17),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 14,
                      ),
                    ),
                    onPressed: () => Navigator.of(context).pop(example),
                    icon: const Icon(Icons.play_arrow_rounded),
                    label: Text(t.tutorialShow(example.format())),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// A small drawing of a few wires of the abacus with their place names.
class _MiniAbacus extends StatelessWidget {
  const _MiniAbacus({required this.digits, this.labels, this.changed});

  /// From the highest place down to the ones.
  final List<int> digits;
  final List<String>? labels;
  final List<bool>? changed;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final n = digits.length;
    return Row(
      children: [
        Expanded(
          flex: 3,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFFEDE1CC),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: const Color(0xFF8A5530), width: 6),
            ),
            child: Column(
              children: [
                for (var i = 0; i < n; i++)
                  SizedBox(
                    height: 26,
                    child: CustomPaint(
                      size: Size.infinite,
                      painter: _WirePainter(
                        digits[i],
                        highlight: changed?[i] ?? false,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          flex: 2,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (var i = 0; i < n; i++)
                SizedBox(
                  height: 26,
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        labels?[i] ??
                            '${placeName(t, n - 1 - i)}: ${digits[i]}',
                        style: TextStyle(
                          fontSize: 16,
                          color: (changed?[i] ?? false) ? _accent : _ink,
                          fontWeight: (changed?[i] ?? false)
                              ? FontWeight.w700
                              : FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _WirePainter extends CustomPainter {
  _WirePainter(this.count, {this.highlight = false});
  final int count;
  final bool highlight;

  static const _beads = 10;

  @override
  void paint(Canvas canvas, Size size) {
    final y = size.height / 2;
    if (highlight) {
      canvas.drawRect(
        Offset.zero & size,
        Paint()..color = const Color(0x55FFD27A),
      );
    }
    canvas.drawLine(
      Offset(0, y),
      Offset(size.width, y),
      Paint()
        ..color = const Color(0xFF8E8E8C)
        ..strokeWidth = 1.5,
    );
    // Counted beads on the left, the free ones on the right with a gap of
    // three beads between.
    final w = size.width / (_beads + 3);
    final h = size.height * 0.8;
    for (var i = 0; i < _beads; i++) {
      final left = i < count ? i * w : (i + 3) * w;
      final black = i == 4 || i == 5;
      final r = RRect.fromRectAndRadius(
        Rect.fromLTWH(left + 0.5, y - h / 2, w - 1, h),
        Radius.circular(w * 0.45),
      );
      canvas.drawRRect(
        r,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: black
                ? const [Color(0xFF5A4E46), Color(0xFF1E1814)]
                : const [Color(0xFFFFFBF2), Color(0xFFD8CBB4)],
          ).createShader(r.outerRect),
      );
      canvas.drawRRect(
        r,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.8
          ..color = Colors.black.withValues(alpha: 0.35),
      );
    }
  }

  @override
  bool shouldRepaint(_WirePainter old) =>
      old.count != count || old.highlight != highlight;
}
