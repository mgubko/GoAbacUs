import 'dart:typed_data';

import 'package:tutor_vision/tutor_vision.dart';

/// A camera frame as plain bytes (what the camera plugin hands over).
class FrameData {
  FrameData.yuv({
    required this.width,
    required this.height,
    required this.y,
    required this.u,
    required this.v,
    required this.yRowStride,
    required this.uvRowStride,
    required this.uvPixelStride,
  })  : bgra = null,
        bgraRowStride = 0;

  FrameData.bgra({required this.width, required this.height, required Uint8List bytes, required int rowStride})
      : bgra = bytes,
        bgraRowStride = rowStride,
        y = null,
        u = null,
        v = null,
        yRowStride = 0,
        uvRowStride = 0,
        uvPixelStride = 0;

  final int width, height;
  final Uint8List? y, u, v, bgra;
  final int yRowStride, uvRowStride, uvPixelStride, bgraRowStride;

  ColorSource toSource() => bgra != null
      ? BgraFrame(width, height, bgra!, bgraRowStride)
      : YuvFrame(
          width: width,
          height: height,
          y: y!,
          yRowStride: yRowStride,
          u: u!,
          v: v!,
          uvRowStride: uvRowStride,
          uvPixelStride: uvPixelStride,
        );
}

/// A label drawn over the normalised field.
class Mark {
  Mark(this.x, this.y, this.text, {this.kind = 0, this.w = 0, this.h = 0, this.angle = 0});

  /// Plane pixels (centre).
  final double x, y;
  final String text;

  /// 0 = rod, 1 = abacus wire, 2 = touch, 3 = info.
  final int kind;
  final double w, h, angle;
}

/// What the lab shows for one frame.
class LabResult {
  LabResult({
    required this.status,
    this.sheetName,
    this.summary = '',
    this.rgba,
    this.width = 0,
    this.height = 0,
    this.marks = const [],
    this.ms = 0,
    this.hasReference = false,
  });

  final String status;
  final String? sheetName;
  final String summary;
  final Uint8List? rgba;
  final int width, height;
  final List<Mark> marks;
  final int ms;
  final bool hasReference;
}

/// All recognition state; lives in the worker isolate.
class Lab {
  final locator = BoardLocator();
  final touch = TouchReader();
  final still = StillnessGate();
  PlaneImage? reference;
  int? referenceSheet;
  bool _wantReference = false;
  ColorCalibration? _colors;
  LabResult? _lastSettled;

  static const scale = 2.0;

  void learnEmpty() {
    _wantReference = true;
    touch.reset();
  }

  LabResult process(FrameData data) {
    final sw = Stopwatch()..start();
    final frame = data.toSource();
    final pose = locator.locate(frame);
    if (pose == null) {
      return LabResult(status: 'Лист не найден: нужны хотя бы две угловые метки', ms: sw.elapsedMilliseconds);
    }
    final sheet = pose.sheet;
    final field = sheet.field;
    final plane = BoardLocator.warp(frame, pose, field, scale: scale);
    final measured = ColorCalibration.fromPatches(BoardLocator.measurePatches(frame, pose));
    _colors = measured;
    measured.correct(plane);
    final info = StringBuffer()
      ..write('меток ${pose.markers.length}, ')
      ..write('${pose.pxPerMm.toStringAsFixed(1)} пикс/мм, ')
      ..write('ошибка ${pose.reprojectionPx.toStringAsFixed(1)} пикс')
      ..write(pose.mirrored ? ', зеркально' : '');
    final hint = _hintText(pose.hint);
    if (referenceSheet != sheet.id) {
      reference = null;
      referenceSheet = sheet.id;
      touch.reset();
    }
    if (_wantReference) {
      reference = plane;
      _wantReference = false;
    }
    final isStill = still.feed(plane, DateTime.now());
    var summary = '';
    final marks = <Mark>[];
    if (sheet.table != null) {
      // Film tables: touches seen from behind.
      final t = touch.read(plane, table: sheet.table);
      for (final x in t) {
        final cell = x.cell;
        var label = '';
        if (cell != null && cell.$1 > 0 && cell.$2 > 0) {
          final a = sheet.table!.first + cell.$1 - 1, b = sheet.table!.first + cell.$2 - 1;
          label = sheet.id <= 11 ? '$a + $b = ${a + b}' : '$a × $b = ${a * b}';
        } else if (cell != null) {
          label = 'заголовок';
        }
        marks.add(Mark(plane.uOf(x.center.x), plane.vOf(x.center.y), label, kind: 2));
        summary = 'Касание: $label (резкость ${x.sharpness.toStringAsFixed(2)})';
      }
      if (t.isEmpty) summary = touch.hasBackground ? 'Касаний нет' : 'Запоминаю пустой лист';
    } else if (reference == null) {
      summary = 'Уберите всё с поля и нажмите «Пустой лист»';
    } else if (!isStill) {
      final last = _lastSettled;
      summary = 'Жду, пока картинка успокоится';
      if (last != null) marks.addAll(last.marks);
    } else if (sheet.id == SheetLayout.abacusMat.id) {
      final r = AbacusReader().read(plane, reference!);
      if (r == null) {
        summary = 'Счёты не найдены';
      } else {
        summary = 'Счёты: ${r.value ?? '?'}  (${r.digits.reversed.map((d) => d ?? '?').join(' ')})';
        for (var i = 0; i < r.digits.length; i++) {
          marks.add(Mark(4, plane.vOf(r.rowCentersMm[i]), '${r.digits[i] ?? '?'}', kind: 1));
        }
      }
    } else {
      final r = RodReader(_colors ?? ColorCalibration.nominal()).read(plane, reference!);
      for (final rod in r.rods) {
        marks.add(Mark(plane.uOf(rod.center.x), plane.vOf(rod.center.y), '${rod.value}${rod.sure ? '' : '?'}',
            kind: 0, w: rod.lengthMm * scale, h: 10 * scale, angle: rod.angle));
      }
      summary = r.trains.isEmpty
          ? 'Палочек нет'
          : 'Палочки: ${r.trains.map((t) => t.rods.length > 1 ? '$t = ${t.sum}' : '${t.sum}').join(';  ')}';
    }
    final result = LabResult(
      status: hint == null ? info.toString() : '$hint · $info',
      sheetName: sheet.name,
      summary: summary,
      rgba: _rgba(plane),
      width: plane.width,
      height: plane.height,
      marks: marks,
      ms: sw.elapsedMilliseconds,
      hasReference: reference != null,
    );
    if (isStill) _lastSettled = result;
    return result;
  }

  static String? _hintText(BoardHint h) => switch (h) {
        BoardHint.ok => null,
        BoardHint.noSheet => 'Не вижу угловых меток',
        BoardHint.cutLeft => 'Лист обрезан слева',
        BoardHint.cutRight => 'Лист обрезан справа',
        BoardHint.cutTop => 'Лист обрезан сверху',
        BoardHint.cutBottom => 'Лист обрезан снизу',
        BoardHint.closer => 'Поднесите камеру ближе',
        BoardHint.covered => 'Метка закрыта рукой или бликом',
      };

  static Uint8List _rgba(PlaneImage p) {
    final out = Uint8List(p.width * p.height * 4);
    for (var i = 0, j = 0; i < p.rgb.length; i += 3, j += 4) {
      out[j] = p.rgb[i].round().clamp(0, 255);
      out[j + 1] = p.rgb[i + 1].round().clamp(0, 255);
      out[j + 2] = p.rgb[i + 2].round().clamp(0, 255);
      out[j + 3] = 255;
    }
    return out;
  }
}
