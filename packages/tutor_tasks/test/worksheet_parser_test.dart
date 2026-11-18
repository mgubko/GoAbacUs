import 'dart:convert';
import 'dart:io';

import 'package:test/test.dart';
import 'package:tutor_tasks/tutor_tasks.dart';

/// OCR boxes of the nine real pages (RapidOCR, the PP-OCR mobile models:
/// the same class as ML Kit on the phone), at 0, 90 and 270 degrees.
final _ocr =
    jsonDecode(File('test/fixtures/ocr_boxes.json').readAsStringSync())
        as Map<String, dynamic>;
final _truth =
    jsonDecode(File('test/fixtures/truth.json').readAsStringSync())
        as Map<String, dynamic>;

ParsedPage _best(String page) {
  ParsedPage? best;
  for (final rot in ['0', '90', '270']) {
    final r = _ocr[page][rot] as Map<String, dynamic>;
    final boxes = [
      for (final b in r['boxes'] as List)
        OcrBox(
          b[0] as String,
          (b[1] as num).toDouble(),
          (b[2] as num).toDouble(),
          (b[3] as num).toDouble(),
          (b[4] as num).toDouble(),
        ),
    ];
    final p = parsePage(
      boxes,
      (r['w'] as num).toDouble(),
      (r['h'] as num).toDouble(),
    );
    if (best == null || p.lines.length > best.lines.length) best = p;
  }
  return best!;
}

Map<String, int> _count(Iterable<String> xs) {
  final m = <String, int>{};
  for (final x in xs) {
    m[x] = (m[x] ?? 0) + 1;
  }
  return m;
}

void main() {
  test('reads the nine real pages as well as the Python prototype', () {
    var hit = 0, total = 0, extra = 0, groupsOk = 0, groupsTotal = 0;
    for (final page in _truth.keys) {
      final t = _truth[page] as Map<String, dynamic>;
      final want = [
        for (final g in t['groups'] as List)
          for (final l in g as List) l as String,
        for (final l in t['single'] as List) l as String,
      ];
      final p = _best(page);
      final ct = _count(want), cg = _count(p.lines.map((l) => l.line));
      var h = 0;
      ct.forEach((k, v) => h += v < (cg[k] ?? 0) ? v : (cg[k] ?? 0));
      var e = 0;
      cg.forEach((k, v) => e += v > (ct[k] ?? 0) ? v - (ct[k] ?? 0) : 0);
      hit += h;
      extra += e;
      total += want.length;
      for (final g in t['groups'] as List) {
        groupsTotal++;
        if (p.groups.any((x) => x.join() == (g as List).join())) groupsOk++;
      }
      // ignore: avoid_print
      print('$page: $h/${want.length}, extra $e, tasks ${p.tasks.length}');
    }
    // ignore: avoid_print
    print('TOTAL $hit/$total, extra $extra, groups $groupsOk/$groupsTotal');
    expect(hit, greaterThanOrEqualTo(126));
    expect(extra, lessThanOrEqualTo(3));
    expect(groupsOk, greaterThanOrEqualTo(16));
  });

  test('a steps group becomes one task with two abacus steps', () {
    final p = _best('hw1');
    final steps = p.tasks.whereType<StepsTask>().toList();
    expect(steps.first.format(), '57 + 28 = ?');
    expect(steps.first.questions.map((q) => q.format()), [
      '57 + 20 = ?',
      '77 + 8 = ?',
    ]);
    expect(steps.first.answer, 85);
  });

  test('times-table pages give multiplication tasks', () {
    final p = _best('hw5');
    expect(p.multiplication, isTrue);
    expect(p.tasks.whereType<EqTask>().every((t) => t.op == Op.mul), isTrue);
  });
}
