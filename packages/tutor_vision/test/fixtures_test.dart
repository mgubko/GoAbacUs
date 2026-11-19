import 'dart:convert';
import 'dart:io';

import 'package:image/image.dart' as img;
import 'package:test/test.dart';
import 'package:tutor_vision/tutor_vision.dart';

// Synthetic phone pictures made by tools/vision/render_scenes.py: random
// perspective, uneven light, colour cast, blur, noise, JPEG.
final dir = Directory('test/fixtures');
final truth = jsonDecode(File('test/fixtures/truth.json').readAsStringSync()) as Map<String, dynamic>;

RgbImage load(String name) {
  final im = img.decodeJpg(File('${dir.path}/$name').readAsBytesSync())!;
  final out = RgbImage(im.width, im.height);
  var j = 0;
  for (final p in im) {
    out.rgb[j++] = p.r.toInt();
    out.rgb[j++] = p.g.toInt();
    out.rgb[j++] = p.b.toInt();
  }
  return out;
}

void main() {
  group('sheet markers and normalisation', () {
    for (final name in truth.keys.where((k) => k.startsWith('calib_'))) {
      test(name, () {
        final t = truth[name] as Map<String, dynamic>;
        final frame = load(name);
        final pose = BoardLocator().locate(frame);
        expect(pose, isNotNull);
        expect(pose!.sheet.id, t['sheet']);
        expect(pose.mirrored, t['mirrored']);
        expect(pose.reprojectionPx, lessThan(1.5));
        expect(pose.hint.name, t['hint']);
        if (t['hint'] != 'ok') return;
        expect(pose.cornerIds, {0, 1, 2, 3});
        // The strip's white is brighter than its grey, rod 7 is the darkest.
        final p = BoardLocator.measurePatches(frame, pose);
        expect(p[0].lum, greaterThan(p[1].lum + 40));
        expect(p[8].lum, lessThan(p[1].lum));
      });
    }
  });

  group('rods', () {
    for (final name in truth.keys.where((k) => k.startsWith('rods_'))) {
      test(name, () {
        final t = truth[name] as Map<String, dynamic>;
        final ref = load(name.replaceFirst('.jpg', '_empty.jpg'));
        final cur = load(name);
        final loc = BoardLocator();
        final pr = loc.locate(ref)!, pc = loc.locate(cur)!;
        final colors = ColorCalibration.fromPatches(BoardLocator.measurePatches(cur, pc));
        final field = pc.sheet.field;
        final a = BoardLocator.warp(ref, pr, field), b = BoardLocator.warp(cur, pc, field);
        colors.correct(a);
        colors.correct(b);
        final res = RodReader(colors).read(b, a);
        final got = [for (final tr in res.trains) tr.rods.map((r) => r.value).toList()]
          ..sort((x, y) => x.toString().compareTo(y.toString()));
        final want = [for (final tr in t['trains'] as List) (tr as List).cast<int>()]
          ..sort((x, y) => x.toString().compareTo(y.toString()));
        expect(got, want, reason: res.rods.join('\n'));
      });
    }
  });

  group('counters', () {
    for (final name in truth.keys.where((k) => k.startsWith('counters_'))) {
      test(name, () {
        final t = truth[name] as Map<String, dynamic>;
        final ref = load(name.replaceFirst('.jpg', '_empty.jpg'));
        final cur = load(name);
        final loc = BoardLocator();
        final pr = loc.locate(ref)!, pc = loc.locate(cur)!;
        final colors = ColorCalibration.fromPatches(BoardLocator.measurePatches(cur, pc));
        final field = pc.sheet.field;
        final a = BoardLocator.warp(ref, pr, field), b = BoardLocator.warp(cur, pc, field);
        colors.correct(a);
        colors.correct(b);
        final r = CounterReader().read(b, a);
        expect((r.red, r.blue), (t['red'], t['blue']), reason: r.counters.join('\n'));
      });
    }
  });

  group('abacus', () {
    for (final name in truth.keys.where((k) => k.startsWith('abacus_'))) {
      test(name, () {
        final t = truth[name] as Map<String, dynamic>;
        final ref = load(name.replaceFirst('.jpg', '_empty.jpg'));
        final cur = load(name);
        final loc = BoardLocator();
        final pr = loc.locate(ref)!, pc = loc.locate(cur)!;
        expect(pc.sheet.id, 15);
        final field = pc.sheet.field;
        final r = AbacusReader().read(BoardLocator.warp(cur, pc, field), BoardLocator.warp(ref, pr, field));
        expect(r, isNotNull);
        expect(r!.digits, (t['digits'] as List).cast<int>());
      });
    }
  });

  group('touches from behind', () {
    for (final name in truth.keys.where((k) => k.startsWith('touch_'))) {
      test(name, () {
        final t = truth[name] as Map<String, dynamic>;
        final ref = load(name.replaceFirst('.jpg', '_empty.jpg'));
        final cur = load(name);
        final loc = BoardLocator(defaultSheet: SheetLayout.addAnswers);
        final pr = loc.locate(ref)!, pc = loc.locate(cur)!;
        expect(pc.sheet.id, 10);
        expect(pc.mirrored, isTrue);
        final reader = TouchReader();
        final field = pc.sheet.field;
        reader.learnBackground(BoardLocator.warp(ref, pr, field));
        final touches = reader.read(BoardLocator.warp(cur, pc, field), table: pc.sheet.table);
        final cell = t['cell'] as List?;
        if (cell == null) {
          expect(touches, isEmpty, reason: 'hovering ${t['hover_mm']} mm');
        } else {
          expect(touches, hasLength(1), reason: touches.join('\n'));
          expect(touches.single.cell, (cell[0] as int, cell[1] as int));
        }
      });
    }
  });
}
