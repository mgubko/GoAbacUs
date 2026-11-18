import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'lab.dart';
import 'worker.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const CamLabApp());
}

class CamLabApp extends StatelessWidget {
  const CamLabApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'GoAbacUs Камера',
        theme: ThemeData(colorSchemeSeed: const Color(0xFF8C510A), useMaterial3: true),
        home: const LabScreen(),
      );
}

/// Camera lab: point the phone at a printed GoAbacUs sheet. The app finds
/// the corner markers, straightens the sheet and, depending on the sheet,
/// reads rods (sheet 14), an abacus (sheet 15) or finger touches seen from
/// behind (film tables 10-13). Nothing leaves the phone.
class LabScreen extends StatefulWidget {
  const LabScreen({super.key});

  @override
  State<LabScreen> createState() => _LabScreenState();
}

class _LabScreenState extends State<LabScreen> with WidgetsBindingObserver {
  List<CameraDescription> _cameras = const [];
  int _cam = 0;
  CameraController? _ctl;
  LabWorker? _worker;
  StreamSubscription<LabResult>? _sub;
  bool _busy = false;
  bool _torch = false;
  LabResult? _result;
  ui.Image? _plane;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _init();
  }

  Future<void> _init() async {
    try {
      final w = await LabWorker.start();
      _worker = w;
      _sub = w.results.listen(_onResult);
      _cameras = await availableCameras();
      if (_cameras.isEmpty) {
        setState(() => _error = 'Камера не найдена');
        return;
      }
      _cam = math.max(0, _cameras.indexWhere((c) => c.lensDirection == CameraLensDirection.back));
      await _open();
    } catch (e) {
      setState(() => _error = '$e');
    }
  }

  Future<void> _open() async {
    final old = _ctl;
    _ctl = null;
    if (old != null) {
      if (old.value.isStreamingImages) await old.stopImageStream();
      await old.dispose();
    }
    final ctl = CameraController(
      _cameras[_cam],
      ResolutionPreset.high, // 1280 x 720
      enableAudio: false,
      imageFormatGroup: defaultTargetPlatform == TargetPlatform.iOS ? ImageFormatGroup.bgra8888 : ImageFormatGroup.yuv420,
    );
    await ctl.initialize();
    await ctl.startImageStream(_onFrame);
    if (!mounted) return;
    setState(() {
      _ctl = ctl;
      _torch = false;
    });
  }

  void _onFrame(CameraImage img) {
    final w = _worker;
    if (_busy || w == null) return;
    _busy = true;
    final FrameData f;
    if (img.format.group == ImageFormatGroup.bgra8888) {
      final p = img.planes.first;
      f = FrameData.bgra(width: img.width, height: img.height, bytes: p.bytes, rowStride: p.bytesPerRow);
    } else {
      final y = img.planes[0], u = img.planes[1], v = img.planes[2];
      f = FrameData.yuv(
        width: img.width,
        height: img.height,
        y: y.bytes,
        u: u.bytes,
        v: v.bytes,
        yRowStride: y.bytesPerRow,
        uvRowStride: u.bytesPerRow,
        uvPixelStride: u.bytesPerPixel ?? 1,
      );
    }
    w.frame(f);
  }

  void _onResult(LabResult r) {
    final rgba = r.rgba;
    if (rgba == null) {
      _busy = false;
      if (mounted) setState(() => _result = r);
      return;
    }
    ui.decodeImageFromPixels(rgba, r.width, r.height, ui.PixelFormat.rgba8888, (im) {
      _busy = false;
      if (!mounted) return;
      setState(() {
        _plane?.dispose();
        _plane = im;
        _result = r;
      });
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final ctl = _ctl;
    if (state == AppLifecycleState.inactive && ctl != null) {
      _ctl = null;
      ctl.dispose();
      setState(() {});
    } else if (state == AppLifecycleState.resumed && _ctl == null && _cameras.isNotEmpty) {
      _open();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _sub?.cancel();
    _ctl?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final r = _result;
    final ctl = _ctl;
    return Scaffold(
      appBar: AppBar(
        title: Text(r?.sheetName ?? 'GoAbacUs Камера'),
        actions: [
          if (_cameras.length > 1)
            IconButton(
              tooltip: 'Другая камера',
              icon: const Icon(Icons.cameraswitch),
              onPressed: () {
                _cam = (_cam + 1) % _cameras.length;
                _open();
              },
            ),
          IconButton(
            tooltip: 'Фонарик (подсветка сзади)',
            icon: Icon(_torch ? Icons.flashlight_on : Icons.flashlight_off),
            onPressed: ctl == null
                ? null
                : () async {
                    final on = !_torch;
                    try {
                      await ctl.setFlashMode(on ? FlashMode.torch : FlashMode.off);
                      setState(() => _torch = on);
                    } catch (_) {}
                  },
          ),
        ],
      ),
      body: _error != null
          ? Center(child: Padding(padding: const EdgeInsets.all(24), child: Text(_error!)))
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(
                  height: 150,
                  child: ctl == null
                      ? const Center(child: CircularProgressIndicator())
                      : Center(child: AspectRatio(aspectRatio: 1 / ctl.value.aspectRatio, child: CameraPreview(ctl))),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                  child: Text(
                    r == null ? 'Наведите камеру на напечатанный лист' : '${r.status} · ${r.ms} мс',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(8),
                    child: _plane == null || r == null
                        ? const Center(child: Text('Здесь появится выровненное поле'))
                        : FittedBox(
                            child: SizedBox(
                              width: r.width.toDouble(),
                              height: r.height.toDouble(),
                              child: CustomPaint(painter: _PlanePainter(_plane!, r.marks)),
                            ),
                          ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Text(r?.summary ?? '', style: Theme.of(context).textTheme.titleMedium),
                ),
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: FilledButton.icon(
                    icon: const Icon(Icons.crop_free),
                    label: Text(r?.hasReference == true ? 'Запомнить пустой лист заново' : 'Запомнить пустой лист'),
                    onPressed: () => _worker?.learnEmpty(),
                  ),
                ),
              ],
            ),
    );
  }
}

class _PlanePainter extends CustomPainter {
  _PlanePainter(this.image, this.marks);
  final ui.Image image;
  final List<Mark> marks;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawImage(image, Offset.zero, Paint());
    for (final m in marks) {
      final color = switch (m.kind) { 0 => Colors.cyanAccent, 1 => Colors.yellowAccent, _ => Colors.redAccent };
      final stroke = Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2;
      if (m.kind == 0) {
        canvas.save();
        canvas.translate(m.x, m.y);
        canvas.rotate(-m.angle);
        canvas.drawRect(Rect.fromCenter(center: Offset.zero, width: m.w, height: m.h), stroke);
        canvas.restore();
      } else if (m.kind == 2) {
        canvas.drawCircle(Offset(m.x, m.y), 12, stroke);
      }
      final tp = TextPainter(
        text: TextSpan(
          text: m.text,
          style: TextStyle(color: Colors.black, backgroundColor: color, fontSize: 14, fontWeight: FontWeight.bold),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      final off = m.kind == 2 ? Offset(m.x + 14, m.y - 24) : Offset(m.x - tp.width / 2, m.y - tp.height / 2);
      tp.paint(canvas, off);
    }
  }

  @override
  bool shouldRepaint(_PlanePainter old) => old.image != image || old.marks != marks;
}
