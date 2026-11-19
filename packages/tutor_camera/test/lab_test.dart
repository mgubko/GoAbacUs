import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:tutor_camera/tutor_camera.dart';
import 'package:tutor_vision/tutor_vision.dart';

// The synthetic phone pictures of tutor_vision, fed through the whole lab
// as camera frames (BGRA), as the app would.
FrameData frame(String name) {
  final im = img.decodeJpg(File('../tutor_vision/test/fixtures/$name').readAsBytesSync())!;
  final b = Uint8List(im.width * im.height * 4);
  var j = 0;
  for (final p in im) {
    b[j++] = p.b.toInt();
    b[j++] = p.g.toInt();
    b[j++] = p.r.toInt();
    b[j++] = 255;
  }
  return FrameData.bgra(width: im.width, height: im.height, bytes: b, rowStride: im.width * 4);
}

DeskView settle(DeskLab lab, String scene) {
  final t0 = DateTime(2026);
  lab.learnEmpty();
  lab.process(frame('${scene}_empty.jpg'), now: t0);
  final f = frame('$scene.jpg');
  lab.process(f, now: t0.add(const Duration(seconds: 1)));
  lab.process(f, now: t0.add(const Duration(seconds: 2)));
  return lab.process(f, now: t0.add(const Duration(seconds: 3)));
}

void main() {
  test('rods and counters: straightened sheet, guides, marks, observations', () {
    final lab = DeskLab()..wantRaw = true;
    final v = settle(lab, 'rods_1');
    expect(v.sheetId, 14);
    expect(v.sheetW, 440);
    expect(v.sheetH, 320);
    expect(v.sheetRgba!.length, 440 * 320 * 4);
    expect(v.rawW, 480);
    expect(v.rawMarkers.map((m) => m.$1).toSet(), {0, 1, 2, 3, 14});
    expect(v.guides, isNotEmpty);
    expect(v.settled, isTrue);
    expect(v.marks.where((m) => m.kind == MarkKind.rod), hasLength(5));
    expect(v.marks.where((m) => m.kind.name.startsWith('counter')), isEmpty);
    final rods = v.observations.whereType<RodsObservation>().single;
    expect(rods.rows, [
      [7, 5],
      [8, 2],
      [4],
    ]);
  });

  test('counters, touching ones and a rod among them', () {
    final v = settle(DeskLab(), 'counters_2');
    final c = v.observations.whereType<CountersObservation>().single;
    expect((c.red, c.blue), (3, 3));
    expect(v.marks.where((m) => m.kind == MarkKind.counterRed), hasLength(3));
    expect(v.observations.whereType<RodsObservation>().single.rows, [
      [6],
    ]);
    final row = settle(DeskLab(), 'counters_1');
    expect(row.marks.where((m) => m.kind == MarkKind.rod), isEmpty);
    final c1 = row.observations.whereType<CountersObservation>().single;
    expect((c1.red, c1.blue), (5, 2));
  });

  test('a touch on the addition table seen from behind, with the table grid guides', () {
    final lab = DeskLab();
    lab.process(frame('touch_0_empty.jpg'));
    final v = lab.process(frame('touch_0.jpg'));
    expect(v.sheetId, 10);
    expect(v.mirrored, isTrue);
    expect(v.summary, contains('2 + 3 = 5'));
    expect(v.observations.single, isA<CellTouchObservation>());
    // 13 vertical + 13 horizontal grid lines of the 12 x 12 table
    expect(v.guides.length, greaterThan(26));
  });

  test('abacus on the mat', () {
    final v = settle(DeskLab(), 'abacus_2');
    expect(v.observations.whereType<AbacusObservation>().single.value, 14925);
    expect(v.marks.where((m) => m.kind == MarkKind.wire), hasLength(10));
  });
}
