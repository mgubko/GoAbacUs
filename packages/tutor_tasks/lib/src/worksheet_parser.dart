/// Turns the text an on-device OCR (ML Kit) finds on a homework page into
/// tasks, with no network. A port of recognition-test/local/local_parse.py,
/// which read 126 of 140 tasks on nine real pages.
///
/// The rules only fix what OCR typically gets wrong; nothing is guessed:
/// - the multiplication dot is read as "-", "." or ":" (fixed on pages
///   titled "Einmaleins"), or lost entirely ("57=" on "mit 6 und 7");
/// - "=" is read as "-", "#" or "E";
/// - a "by steps" group (57 + 28, 57 + 20, __ + 8) is recognised by its
///   structure, which also restores a third line OCR lost;
/// - worked examples ("Beispiel") with printed answers, a cut-off
///   neighbouring page and rows of matching cards (2+2+2) are skipped.
library;

import 'dart:math' as math;

import 'task.dart';

/// A piece of text with its box, in image pixels.
class OcrBox {
  const OcrBox(this.text, this.x0, this.y0, this.x1, this.y1);
  final String text;
  final double x0, y0, x1, y1;

  double get cy => (y0 + y1) / 2;
  double get h => y1 - y0;

  @override
  String toString() => '"$text" @${x0.round()},${y0.round()}';
}

/// One equation found on the page, as "57+28=?" / "?+8=?" / "7*6=?".
class FoundLine {
  FoundLine(this.line, this.x, this.y, {this.inferred = false});
  String line;
  final double x, y;

  /// Not read, but restored from the structure of its group.
  final bool inferred;
}

class ParsedPage {
  ParsedPage({
    required this.lines,
    required this.groups,
    required this.tasks,
    required this.multiplication,
    required this.textBoxes,
  });

  /// Every equation found (the quantity the evaluation scores).
  final List<FoundLine> lines;

  /// "By steps" groups, three lines each.
  final List<List<String>> groups;
  final List<Task> tasks;

  /// The page is about the times table.
  final bool multiplication;

  /// How many text boxes OCR returned: few tasks among much text means the
  /// page holds tasks the rules do not know (houses, word problems).
  final int textBoxes;

  /// Rough confidence that the page was understood without the cloud.
  bool get looksComplete =>
      tasks.isNotEmpty && tasks.length * 4 >= math.min(textBoxes, 60) ~/ 2;
}

/// Merges boxes that sit on one visual line and are close to each other.
List<OcrBox> mergeRows(List<OcrBox> boxes) {
  final sorted = [...boxes]..sort((a, b) => a.cy.compareTo(b.cy));
  final lines = <({double cy, List<OcrBox> b})>[];
  for (final b in sorted) {
    final i = lines.indexWhere(
      (l) => (l.cy - b.cy).abs() < math.max(8, 0.5 * b.h),
    );
    if (i >= 0) {
      lines[i].b.add(b);
    } else {
      lines.add((cy: b.cy, b: [b]));
    }
  }
  final out = <List<OcrBox>>[];
  for (final l in lines) {
    final bs = [...l.b]..sort((a, b) => a.x0.compareTo(b.x0));
    var cur = [bs.first];
    for (final b in bs.skip(1)) {
      if (b.x0 - cur.last.x1 < 1.6 * math.max(b.h, 12)) {
        cur.add(b);
      } else {
        out.add(cur);
        cur = [b];
      }
    }
    out.add(cur);
  }
  return [
    for (final c in out)
      OcrBox(
        c.map((b) => b.text).join(' '),
        c.map((b) => b.x0).reduce(math.min),
        c.map((b) => b.y0).reduce(math.min),
        c.map((b) => b.x1).reduce(math.max),
        c.map((b) => b.y1).reduce(math.max),
      ),
  ];
}

String normalise(String t) {
  t = t
      .replaceAll('−', '-')
      .replaceAll('–', '-')
      .replaceAll('—', '-')
      .replaceAll('·', '*')
      .replaceAll('•', '*')
      .replaceAll('×', '*');
  t = t.replaceAll(RegExp(r'(?<=\d)\s*[.,:]\s*(?=\d)'), '*');
  t = t.replaceAll(RegExp(r'(?<=\d)\s*[xX]\s*(?=\d)'), '*');
  return t
      .replaceAll('Z', '7')
      .replaceAll('O', '0')
      .replaceAll('o', '0')
      .replaceAll('l', '1')
      .replaceAll('I', '1');
}

final _expr = RegExp(
  r'(?<![\d+\-*])(\d{1,3})?\s*([+\-*])\s*(\d{1,3})\s*([=#E:]|-(?!\s*\d))?',
);
final _glued = RegExp(r'(?<![\d+\-*])(\d)(\d{1,2})\s*[=#E]');

/// Parses one page. [width] and [height] are the image size in pixels.
///
/// The rules' distances were tuned on photos 1280 px long, so the boxes are
/// scaled to that size first.
ParsedPage parsePage(List<OcrBox> boxes, double width, double height) {
  final k = 1280 / math.max(width, height);
  if ((k - 1).abs() > 0.01) {
    boxes = [
      for (final b in boxes)
        OcrBox(b.text, b.x0 * k, b.y0 * k, b.x1 * k, b.y1 * k),
    ];
    width *= k;
    height *= k;
  }
  final lines = mergeRows(boxes);
  final byTop = [...lines]..sort((a, b) => a.y0.compareTo(b.y0));
  final head = byTop.take(4).map((l) => l.text).join(' ');
  final mult = RegExp(r'Einmal|Mal(aufg|rech)').hasMatch(head);
  final facs = <String>{};
  for (final m in RegExp(
    r'mit\s*(\d+)(?:\s*und\s*(\d+))?',
  ).allMatches(head.replaceAll(' ', ''))) {
    if (m[1] != null) facs.add(m[1]!);
    if (m[2] != null) facs.add(m[2]!);
  }
  final examples = lines.where((l) => l.text.contains('Beispiel')).toList();

  final found = <FoundLine>[];
  for (final l in lines) {
    if (examples.any(
      (b) =>
          b.x0 - 20 < l.x0 &&
          l.x0 < b.x0 + 260 &&
          b.y0 - 5 < l.y0 &&
          l.y0 < b.y0 + 160,
    )) {
      continue; // a worked example with its answers printed
    }
    if (l.x1 > 0.95 * width || l.x0 < 0.03 * width) continue; // cut-off page
    final t = normalise(l.text);
    if (RegExp(r'\d\s*\+\s*\d\s*\+\s*\d').hasMatch(t)) continue; // 2+2+2 cards
    final hits = <String>[];
    for (final m in _expr.allMatches(t)) {
      var a = m[1];
      var op = m[2]!;
      final b = m[3]!;
      final eq = m[4];
      if (eq == '=' && RegExp(r'^\s*=?\s*\d').hasMatch(t.substring(m.end))) {
        continue; // printed result: an example, not a task
      }
      if (mult && op == '-' && (a == null || int.parse(a) <= 10) &&
          int.parse(b) <= 10) {
        op = '*';
      }
      if (a == null) {
        if (eq == null) continue;
        a = '?';
      }
      // A bare "a op b" counts only as its own box (matching cards).
      if (eq == null && t.trim() != m[0]!.trim()) continue;
      hits.add('$a$op$b=?');
    }
    if (mult && hits.isEmpty && facs.isNotEmpty) {
      for (final m in _glued.allMatches(t)) {
        if (facs.contains(m[2]) && int.parse(m[1]!) <= 10) {
          hits.add('${m[1]}*${m[2]}=?');
        }
      }
    }
    for (final h in hits) {
      found.add(FoundLine(h, l.x0, l.y0));
    }
  }

  // "By steps" groups: A op B ; A op tens(B) ; ? op ones(B), in one column.
  final groups = <List<String>>[];
  final groupOf = <FoundLine, int>{};
  for (var i = 0; i < found.length; i++) {
    final f = found[i];
    final m = RegExp(r'^(\d+)([+\-])(\d+)=\?$').firstMatch(f.line);
    if (m == null) continue;
    final a = int.parse(m[1]!), op = m[2]!, b = int.parse(m[3]!);
    final tens = b ~/ 10 * 10, ones = b % 10;
    final next = found
        .where((g) => (g.x - f.x).abs() < 60 && g.y - f.y > 0 && g.y - f.y < 250)
        .toList();
    final s2 = next.where((g) => g.line == '$a$op$tens=?').toList();
    final s3 = next
        .where(
          (g) => RegExp(
            '^(\\?|\\d+)${RegExp.escape(op)}$ones=\\?\$',
          ).hasMatch(g.line),
        )
        .toList();
    if (s2.isNotEmpty && s3.isNotEmpty) {
      s3.first.line = '?$op$ones=?'; // a misread blank
      groups.add([f.line, s2.first.line, s3.first.line]);
      for (final g in [f, s2.first, s3.first]) {
        groupOf[g] = groups.length - 1;
      }
    } else if (s2.isNotEmpty && ones != 0) {
      // OCR lost the third line: the structure says what it must be.
      final g = FoundLine(
        '?$op$ones=?',
        f.x,
        s2.first.y + 1,
        inferred: true,
      );
      found.add(g);
      groups.add([f.line, s2.first.line, g.line]);
      for (final x in [f, s2.first, g]) {
        groupOf[x] = groups.length - 1;
      }
    }
  }

  // Tasks in reading order: top to bottom, left column first on a line.
  final ordered = found.where((f) => !f.inferred).toList()
    ..sort((a, b) {
      final dy = a.y - b.y;
      if (dy.abs() > 25) return dy.sign.toInt();
      return a.x.compareTo(b.x);
    });
  final tasks = <Task>[];
  final emitted = <int>{};
  for (final f in ordered) {
    final g = groupOf[f];
    if (g != null) {
      if (emitted.add(g)) {
        final e = EqTask.parse(groups[g][0]);
        tasks.add(StepsTask(e.a!, e.op, e.b!, n: '${tasks.length + 1}'));
      }
      continue;
    }
    if (f.line.startsWith('?')) continue; // a step line without its group
    final e = EqTask.parse(f.line.replaceAll('=?', ''));
    tasks.add(EqTask(e.a, e.op, e.b, n: '${tasks.length + 1}'));
  }

  return ParsedPage(
    lines: found,
    groups: groups,
    tasks: tasks,
    multiplication: mult,
    textBoxes: boxes.length,
  );
}
