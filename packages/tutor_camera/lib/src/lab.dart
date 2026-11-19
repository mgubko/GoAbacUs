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

enum MarkKind { rod, wire, touch, counterRed, counterBlue, counterOther }

/// Something recognised, in sheet-image pixels (see [DeskView.sheetRgba]).
class Mark {
  Mark(this.kind, this.x, this.y, this.text, {this.w = 0, this.h = 0, this.angle = 0});
  final MarkKind kind;
  final double x, y;
  final String text;
  final double w, h, angle;
}

/// A line of the printed sheet (table grid, field border, marker squares),
/// in sheet-image pixels: drawn semi-transparently over the straightened
/// picture so that any misalignment is visible at once.
class GuideLine {
  GuideLine(this.x0, this.y0, this.x1, this.y1, {this.bold = false});
  final double x0, y0, x1, y1;
  final bool bold;
}

/// What the desk camera shows for one frame.
class DeskView {
  DeskView({
    required this.status,
    this.sheetId,
    this.sheetName,
    this.summary = '',
    this.sheetRgba,
    this.sheetW = 0,
    this.sheetH = 0,
    this.marks = const [],
    this.guides = const [],
    this.rawRgba,
    this.rawW = 0,
    this.rawH = 0,
    this.rawMarkers = const [],
    this.mirrored = false,
    this.ms = 0,
    this.hasReference = false,
    this.settled = false,
    this.observations = const [],
  });

  final String status;
  final int? sheetId;
  final String? sheetName;
  final String summary;

  /// The whole sheet straightened by the marker homography, 2 px/mm, as the
  /// child sees it (a mirror-imaged view is turned back).
  final Uint8List? sheetRgba;
  final int sheetW, sheetH;
  final List<Mark> marks;
  final List<GuideLine> guides;

  /// The camera frame as it arrives (downscaled), with the found markers.
  final Uint8List? rawRgba;
  final int rawW, rawH;

  /// Per marker: id and 4 corners (x0, y0, ... x3, y3) in raw-image pixels.
  final List<(int, List<double>)> rawMarkers;
  final bool mirrored;
  final int ms;
  final bool hasReference;

  /// The picture stood still and the recognition result is final.
  final bool settled;
  final List<AidObservation> observations;
}

/// All recognition state; lives in the worker isolate.
class DeskLab {
  final locator = BoardLocator();
  final touch = TouchReader();
  final still = StillnessGate();
  PlaneImage? reference;
  int? referenceSheet;
  bool _wantReference = false;
  DeskView? _lastSettled;

  /// Also send the raw frame (costs a little time).
  bool wantRaw = false;

  static const scale = 2.0;
  static const rawMaxWidth = 480;

  void learnEmpty() {
    _wantReference = true;
    touch.reset();
  }

  DeskView process(FrameData data, {DateTime? now}) {
    final sw = Stopwatch()..start();
    final frame = data.toSource();
    final pose = locator.locate(frame);
    final raw = wantRaw ? _raw(frame, pose) : null;
    if (pose == null) {
      return DeskView(
        status: 'Лист не найден: нужны хотя бы две угловые метки',
        rawRgba: raw?.$1,
        rawW: raw?.$2 ?? 0,
        rawH: raw?.$3 ?? 0,
        rawMarkers: raw?.$4 ?? const [],
        ms: sw.elapsedMilliseconds,
      );
    }
    final sheet = pose.sheet;
    final whole = MmRect(0, 0, sheet.width, sheet.height);
    final plane = BoardLocator.warp(frame, pose, whole, scale: scale);
    final colors = ColorCalibration.fromPatches(BoardLocator.measurePatches(frame, pose));
    colors.correct(plane);
    final info = StringBuffer()
      ..write('меток ${pose.markers.length}, ')
      ..write('${pose.pxPerMm.toStringAsFixed(1)} пикс/мм, ')
      ..write('ошибка ${pose.reprojectionPx.toStringAsFixed(1)} пикс')
      ..write(pose.mirrored ? ', видно зеркально' : '');
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
    final isStill = still.feed(plane, now ?? DateTime.now());
    var summary = '';
    var settled = false;
    final marks = <Mark>[];
    final obs = <AidObservation>[];
    if (sheet.table != null) {
      // Film tables: touches seen from behind, judged every frame.
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
        marks.add(Mark(MarkKind.touch, plane.uOf(x.center.x), plane.vOf(x.center.y), label,
            w: plane.uOf(sheet.table!.x + sheet.table!.cell) - plane.uOf(sheet.table!.x)));
        summary = 'Касание: $label (резкость ${x.sharpness.toStringAsFixed(2)})';
        final o = x.observation(sheet.id);
        if (o != null) obs.add(o);
      }
      settled = t.isNotEmpty;
      if (t.isEmpty) summary = touch.hasBackground ? 'Касаний нет' : 'Запоминаю пустой лист';
    } else if (reference == null) {
      summary = 'Уберите всё с листа и нажмите «Пустой лист»';
    } else if (!isStill) {
      summary = 'Жду, пока рука уйдёт и картинка успокоится';
      final last = _lastSettled;
      if (last != null) marks.addAll(last.marks);
    } else if (sheet.id == SheetLayout.abacusMat.id) {
      settled = true;
      final r = AbacusReader().read(plane, reference!);
      if (r == null) {
        summary = 'Счёты не найдены';
      } else {
        summary = 'Счёты: ${r.value ?? '?'}  (${r.digits.reversed.map((d) => d ?? '?').join(' ')})';
        for (var i = 0; i < r.digits.length; i++) {
          marks.add(Mark(MarkKind.wire, plane.uOf(sheet.field.x), plane.vOf(r.rowCentersMm[i]), '${r.digits[i] ?? '?'}',
              w: sheet.field.w * scale));
        }
        final o = r.observation;
        if (o != null) obs.add(o);
      }
    } else {
      settled = true;
      final rods = RodReader(colors).read(plane, reference!);
      final counters = CounterReader().read(plane, reference!);
      for (final rod in rods.rods) {
        marks.add(Mark(MarkKind.rod, plane.uOf(rod.center.x), plane.vOf(rod.center.y), '${rod.value}${rod.sure ? '' : '?'}',
            w: rod.lengthMm * scale, h: 10 * scale, angle: rod.angle));
      }
      for (final c in counters.counters) {
        final kind = switch (c.color) {
          CounterColor.red => MarkKind.counterRed,
          CounterColor.blue => MarkKind.counterBlue,
          CounterColor.other => MarkKind.counterOther,
        };
        marks.add(Mark(kind, plane.uOf(c.center.x), plane.vOf(c.center.y), '', w: c.diameterMm * scale));
      }
      final parts = <String>[];
      if (rods.trains.isNotEmpty) {
        parts.add('палочки ${rods.trains.map((t) => t.rods.length > 1 ? '$t = ${t.sum}' : '${t.sum}').join('; ')}');
        obs.add(rods.observation);
      }
      if (counters.counters.isNotEmpty) {
        parts.add('фишки: красных ${counters.red}, синих ${counters.blue}');
        obs.add(counters.observation);
      }
      summary = parts.isEmpty ? 'Поле пустое' : parts.join(' · ');
    }
    final result = DeskView(
      status: hint == null ? info.toString() : '$hint · $info',
      sheetId: sheet.id,
      sheetName: sheet.name,
      summary: summary,
      sheetRgba: _rgba(plane),
      sheetW: plane.width,
      sheetH: plane.height,
      marks: marks,
      guides: _guides(sheet, plane),
      rawRgba: raw?.$1,
      rawW: raw?.$2 ?? 0,
      rawH: raw?.$3 ?? 0,
      rawMarkers: raw?.$4 ?? const [],
      mirrored: pose.mirrored,
      ms: sw.elapsedMilliseconds,
      hasReference: reference != null || sheet.table != null,
      settled: settled,
      observations: obs,
    );
    if (isStill && sheet.table == null) _lastSettled = result;
    return result;
  }

  static List<GuideLine> _guides(SheetLayout sheet, PlaneImage p) {
    final out = <GuideLine>[];
    void rect(MmRect r, {bool bold = false}) {
      final x0 = p.uOf(r.x), x1 = p.uOf(r.right), y0 = p.vOf(r.top), y1 = p.vOf(r.y);
      out
        ..add(GuideLine(x0, y0, x1, y0, bold: bold))
        ..add(GuideLine(x1, y0, x1, y1, bold: bold))
        ..add(GuideLine(x1, y1, x0, y1, bold: bold))
        ..add(GuideLine(x0, y1, x0, y0, bold: bold));
    }

    rect(sheet.field);
    for (final id in sheet.markers.keys) {
      final m = sheet.markers[id]!;
      rect(MmRect(m.x, m.y, sheet.markerSize, sheet.markerSize), bold: true);
    }
    for (final patch in sheet.patches) {
      rect(patch);
    }
    final t = sheet.table;
    if (t != null) {
      for (var i = 0; i <= t.cells; i++) {
        final v = t.first + i - 2; // value of the column/row before line i
        final bold = i <= 1 || i == t.cells || (i > 1 && v > 0 && v % 5 == 0);
        out.add(GuideLine(p.uOf(t.x + t.cell * i), p.vOf(t.y), p.uOf(t.x + t.cell * i), p.vOf(t.top), bold: bold));
        out.add(GuideLine(p.uOf(t.x), p.vOf(t.top - t.cell * i), p.uOf(t.x + t.cell * t.cells), p.vOf(t.top - t.cell * i),
            bold: bold));
      }
    }
    return out;
  }

  static (Uint8List, int, int, List<(int, List<double>)>) _raw(ColorSource f, BoardPose? pose) {
    final k = f.width > rawMaxWidth ? f.width / rawMaxWidth : 1.0;
    final w = (f.width / k).floor(), h = (f.height / k).floor();
    final out = Uint8List(w * h * 4);
    final px = Float32List(3);
    for (var y = 0; y < h; y++) {
      for (var x = 0; x < w; x++) {
        f.sampleRgb((x + 0.5) * k, (y + 0.5) * k, px, 0);
        final j = (y * w + x) * 4;
        out[j] = px[0].round().clamp(0, 255);
        out[j + 1] = px[1].round().clamp(0, 255);
        out[j + 2] = px[2].round().clamp(0, 255);
        out[j + 3] = 255;
      }
    }
    final markers = <(int, List<double>)>[
      for (final m in pose?.markers ?? const <Marker>[])
        (m.id, [for (final c in m.corners) ...[c.x / k, c.y / k]]),
    ];
    return (out, w, h, markers);
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
