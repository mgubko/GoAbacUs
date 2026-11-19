import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:tutor_camera/tutor_camera.dart';

void main() {
  test('a blank frame reports that no sheet is found', () {
    const w = 320, h = 240;
    final f = FrameData.yuv(
      width: w,
      height: h,
      y: Uint8List(w * h)..fillRange(0, w * h, 128),
      u: Uint8List(w * h ~/ 4)..fillRange(0, w * h ~/ 4, 128),
      v: Uint8List(w * h ~/ 4)..fillRange(0, w * h ~/ 4, 128),
      yRowStride: w,
      uvRowStride: w ~/ 2,
      uvPixelStride: 1,
    );
    final lab = DeskLab()..wantRaw = true;
    final r = lab.process(f);
    expect(r.status, contains('Лист не найден'));
    expect(r.sheetRgba, isNull);
    expect(r.rawW, 320);
  });
}
