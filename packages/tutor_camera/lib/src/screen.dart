import 'dart:ui' as ui;

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:tutor_vision/tutor_vision.dart';

import 'controller.dart';
import 'lab.dart';

/// "What the camera sees": the sheet straightened by the corner markers
/// (and turned back if seen mirror-imaged), the printed grid laid over it
/// semi-transparently, and everything recognised on top: touches and the
/// touched cell, rods, counters, abacus wires. A second view shows the raw
/// camera frame with the markers found.
///
/// Pass [controller] to share the camera with a lesson; otherwise the screen
/// runs its own.
class DeskCameraScreen extends StatefulWidget {
  const DeskCameraScreen({super.key, this.controller, this.title = 'Что видит камера', this.preferFront = false});

  final DeskCameraController? controller;
  final String title;
  final bool preferFront;

  /// Opens the screen on top of the current route.
  static Future<void> open(BuildContext context, {DeskCameraController? controller, bool preferFront = false}) =>
      Navigator.of(context).push(MaterialPageRoute<void>(
        builder: (_) => DeskCameraScreen(controller: controller, preferFront: preferFront),
      ));

  @override
  State<DeskCameraScreen> createState() => _DeskCameraScreenState();
}

class _DeskCameraScreenState extends State<DeskCameraScreen> with WidgetsBindingObserver {
  late final DeskCameraController _c;
  late final bool _own;
  bool _raw = false;
  bool _guides = true;
  final _log = <String>[];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _own = widget.controller == null;
    _c = widget.controller ?? DeskCameraController(preferFront: widget.preferFront);
    _c.addListener(_changed);
    _c.observations.listen((o) {
      if (!mounted) return;
      setState(() {
        _log.insert(0, describeObservation(o));
        if (_log.length > 6) _log.removeLast();
      });
    });
    if (_own) _c.start();
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!_own) return;
    if (state == AppLifecycleState.inactive) {
      _c.pause();
    } else if (state == AppLifecycleState.resumed) {
      _c.resume();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _c.removeListener(_changed);
    if (_c.showRaw) _c.showRaw = false;
    if (_own) _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final v = _c.view;
    final cam = _c.camera;
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(v?.sheetName ?? widget.title),
        actions: [
          if (_c.canSwitchCamera)
            IconButton(tooltip: 'Другая камера', icon: const Icon(Icons.cameraswitch), onPressed: _c.switchCamera),
          IconButton(
            tooltip: 'Фонарик (подсветка сзади)',
            icon: Icon(_c.torch ? Icons.flashlight_on : Icons.flashlight_off),
            onPressed: cam == null ? null : () => _c.setTorch(!_c.torch),
          ),
        ],
      ),
      body: _c.error != null
          ? Center(child: Padding(padding: const EdgeInsets.all(24), child: Text(_c.error!)))
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
                  child: Row(
                    children: [
                      Expanded(
                        child: SegmentedButton<bool>(
                          segments: const [
                            ButtonSegment(value: false, label: Text('Выровненный лист'), icon: Icon(Icons.crop_free)),
                            ButtonSegment(value: true, label: Text('Кадр камеры'), icon: Icon(Icons.photo_camera)),
                          ],
                          selected: {_raw},
                          onSelectionChanged: (s) => setState(() {
                            _raw = s.first;
                            _c.showRaw = _raw;
                          }),
                        ),
                      ),
                      const SizedBox(width: 8),
                      FilterChip(
                        label: const Text('Сетка'),
                        selected: _guides,
                        onSelected: (on) => setState(() => _guides = on),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 6, 12, 0),
                  child: Text(
                    v == null ? 'Наведите камеру на напечатанный лист' : '${v.status} · ${v.ms} мс',
                    style: theme.textTheme.bodySmall,
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(8),
                    child: _picture(v, cam),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Text(v?.summary ?? '', style: theme.textTheme.titleMedium),
                ),
                if (_log.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 4, 12, 0),
                    child: Text('Для урока: ${_log.join('  ·  ')}',
                        maxLines: 2, overflow: TextOverflow.ellipsis, style: theme.textTheme.bodySmall),
                  ),
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: FilledButton.icon(
                    icon: const Icon(Icons.layers_clear),
                    label: Text(v?.hasReference == true ? 'Запомнить пустой лист заново' : 'Запомнить пустой лист'),
                    onPressed: _c.learnEmpty,
                  ),
                ),
              ],
            ),
    );
  }

  Widget _picture(DeskView? v, CameraController? cam) {
    if (_raw) {
      final img = _c.rawImage;
      if (img == null || v == null) {
        return cam == null
            ? const Center(child: CircularProgressIndicator())
            : Center(child: AspectRatio(aspectRatio: cam.value.aspectRatio, child: CameraPreview(cam)));
      }
      return FittedBox(
        child: SizedBox(
          width: v.rawW.toDouble(),
          height: v.rawH.toDouble(),
          child: CustomPaint(painter: RawFramePainter(img, v.rawMarkers)),
        ),
      );
    }
    final img = _c.sheetImage;
    if (img == null || v == null || v.sheetRgba == null && v.sheetW == 0) {
      return Column(children: [
        if (cam != null)
          Expanded(child: Center(child: AspectRatio(aspectRatio: cam.value.aspectRatio, child: CameraPreview(cam)))),
        const Padding(padding: EdgeInsets.all(8), child: Text('Здесь появится лист, выровненный по угловым меткам')),
      ]);
    }
    return FittedBox(
      child: SizedBox(
        width: img.width.toDouble(),
        height: img.height.toDouble(),
        child: CustomPaint(painter: SheetPainter(img, v.sheetW == img.width ? v.marks : const [], _guides ? v.guides : const [])),
      ),
    );
  }
}

/// A short human line for an observation.
String describeObservation(AidObservation o) => switch (o) {
      AbacusObservation(:final value) => 'счёты $value',
      RodsObservation(:final rows) => 'палочки ${rows.map((r) => r.join('+')).join(' / ')}',
      CellTouchObservation(:final row, :final col) => 'клетка $row,$col',
      CountersObservation(:final red, :final blue) => 'фишки $red + $blue',
    };

/// The straightened sheet with the print guides and the recognised things.
class SheetPainter extends CustomPainter {
  SheetPainter(this.image, this.marks, this.guides);
  final ui.Image image;
  final List<Mark> marks;
  final List<GuideLine> guides;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawImage(image, Offset.zero, Paint());
    final thin = Paint()
      ..color = const Color(0x8000B4FF)
      ..strokeWidth = 1;
    final bold = Paint()
      ..color = const Color(0xB000B4FF)
      ..strokeWidth = 2;
    for (final g in guides) {
      canvas.drawLine(Offset(g.x0, g.y0), Offset(g.x1, g.y1), g.bold ? bold : thin);
    }
    for (final m in marks) {
      final color = switch (m.kind) {
        MarkKind.rod => Colors.cyanAccent,
        MarkKind.wire => Colors.yellowAccent,
        MarkKind.touch => Colors.redAccent,
        MarkKind.counterRed => Colors.pinkAccent,
        MarkKind.counterBlue => Colors.lightBlueAccent,
        MarkKind.counterOther => Colors.white,
      };
      final stroke = Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5;
      switch (m.kind) {
        case MarkKind.rod:
          canvas.save();
          canvas.translate(m.x, m.y);
          canvas.rotate(-m.angle);
          canvas.drawRect(Rect.fromCenter(center: Offset.zero, width: m.w, height: m.h), stroke);
          canvas.restore();
        case MarkKind.wire:
          canvas.drawLine(Offset(m.x, m.y), Offset(m.x + m.w, m.y), stroke..strokeWidth = 1.5);
        case MarkKind.touch:
          // the touched cell, and the fingertip
          canvas.drawRect(
              Rect.fromCenter(center: Offset(m.x, m.y), width: m.w, height: m.w), Paint()..color = const Color(0x55FF5252));
          canvas.drawCircle(Offset(m.x, m.y), 10, stroke);
        case MarkKind.counterRed || MarkKind.counterBlue || MarkKind.counterOther:
          canvas.drawCircle(Offset(m.x, m.y), m.w / 2 + 2, stroke);
      }
      if (m.text.isEmpty) continue;
      final tp = TextPainter(
        text: TextSpan(
          text: m.text,
          style: TextStyle(color: Colors.black, backgroundColor: color, fontSize: 14, fontWeight: FontWeight.bold),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      final off = switch (m.kind) {
        MarkKind.touch => Offset(m.x + 14, m.y - 26),
        MarkKind.wire => Offset(m.x + 2, m.y - tp.height / 2),
        _ => Offset(m.x - tp.width / 2, m.y - tp.height / 2),
      };
      tp.paint(canvas, off);
    }
  }

  @override
  bool shouldRepaint(SheetPainter old) => old.image != image || old.marks != marks || old.guides != guides;
}

/// The camera frame as it arrives, with the found markers outlined.
class RawFramePainter extends CustomPainter {
  RawFramePainter(this.image, this.markers);
  final ui.Image image;
  final List<(int, List<double>)> markers;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawImage(image, Offset.zero, Paint());
    final stroke = Paint()
      ..color = Colors.greenAccent
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    for (final (id, c) in markers) {
      final path = Path()..moveTo(c[0], c[1]);
      for (var i = 1; i < 4; i++) {
        path.lineTo(c[i * 2], c[i * 2 + 1]);
      }
      path.close();
      canvas.drawPath(path, stroke);
      // printed top-left corner
      canvas.drawCircle(Offset(c[0], c[1]), 3, Paint()..color = Colors.redAccent);
      final tp = TextPainter(
        text: TextSpan(
            text: '$id', style: const TextStyle(color: Colors.black, backgroundColor: Colors.greenAccent, fontSize: 12)),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(c[0], c[1] - tp.height - 2));
    }
  }

  @override
  bool shouldRepaint(RawFramePainter old) => old.image != image || old.markers != markers;
}
