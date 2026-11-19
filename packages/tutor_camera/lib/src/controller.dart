import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:tutor_vision/tutor_vision.dart';

import 'lab.dart';
import 'worker.dart';

/// The desk camera: camera stream → recognition in a worker isolate →
/// [view] for the "what the camera sees" screen and [observations] for the
/// lesson (only settled, changed results).
class DeskCameraController extends ChangeNotifier {
  DeskCameraController({this.preferFront = false});

  /// The desk box looks through the front camera; a phone held over a
  /// sheet uses the back one.
  final bool preferFront;

  List<CameraDescription> _cameras = const [];
  int _cam = 0;
  CameraController? camera;
  DeskWorker? _worker;
  StreamSubscription<DeskView>? _sub;
  bool _busy = false;
  bool _disposed = false;
  bool torch = false;
  bool _raw = false;
  String? error;

  DeskView? view;
  ui.Image? sheetImage;
  ui.Image? rawImage;

  final _obs = StreamController<AidObservation>.broadcast();
  String _lastObs = '';

  /// Settled recognition results, one event per change.
  Stream<AidObservation> get observations => _obs.stream;

  bool get canSwitchCamera => _cameras.length > 1;

  Future<void> start() async {
    try {
      final w = await DeskWorker.start();
      _worker = w;
      _sub = w.results.listen(_onView);
      _cameras = await availableCameras();
      if (_cameras.isEmpty) {
        error = 'Камера не найдена';
        notifyListeners();
        return;
      }
      final want = preferFront ? CameraLensDirection.front : CameraLensDirection.back;
      _cam = math.max(0, _cameras.indexWhere((c) => c.lensDirection == want));
      await _open();
    } catch (e) {
      error = '$e';
      notifyListeners();
    }
  }

  Future<void> switchCamera() async {
    if (_cameras.length < 2) return;
    _cam = (_cam + 1) % _cameras.length;
    await _open();
  }

  Future<void> setTorch(bool on) async {
    final c = camera;
    if (c == null) return;
    try {
      await c.setFlashMode(on ? FlashMode.torch : FlashMode.off);
      torch = on;
      notifyListeners();
    } catch (_) {}
  }

  void learnEmpty() => _worker?.learnEmpty();

  /// Also deliver the unprocessed frame with the markers drawn.
  set showRaw(bool on) {
    _raw = on;
    _worker?.showRaw(on);
  }

  bool get showRaw => _raw;

  Future<void> pause() async {
    final c = camera;
    camera = null;
    if (c != null) {
      if (c.value.isStreamingImages) await c.stopImageStream();
      await c.dispose();
    }
  }

  Future<void> resume() async {
    if (camera == null && _cameras.isNotEmpty) await _open();
  }

  Future<void> _open() async {
    await pause();
    final ctl = CameraController(
      _cameras[_cam],
      ResolutionPreset.high, // 1280 x 720
      enableAudio: false,
      imageFormatGroup: defaultTargetPlatform == TargetPlatform.iOS ? ImageFormatGroup.bgra8888 : ImageFormatGroup.yuv420,
    );
    await ctl.initialize();
    await ctl.startImageStream(_onFrame);
    if (_disposed) {
      await ctl.dispose();
      return;
    }
    camera = ctl;
    torch = false;
    notifyListeners();
  }

  void _onFrame(CameraImage img) {
    final w = _worker;
    if (_busy || w == null) return;
    _busy = true;
    if (img.format.group == ImageFormatGroup.bgra8888) {
      final p = img.planes.first;
      w.frame(FrameData.bgra(width: img.width, height: img.height, bytes: p.bytes, rowStride: p.bytesPerRow));
    } else {
      final y = img.planes[0], u = img.planes[1], v = img.planes[2];
      w.frame(FrameData.yuv(
        width: img.width,
        height: img.height,
        y: y.bytes,
        u: u.bytes,
        v: v.bytes,
        yRowStride: y.bytesPerRow,
        uvRowStride: u.bytesPerRow,
        uvPixelStride: u.bytesPerPixel ?? 1,
      ));
    }
  }

  Future<void> _onView(DeskView v) async {
    if (v.settled) {
      for (final o in v.observations) {
        final key = _key(o);
        if (key != _lastObs) {
          _lastObs = key;
          _obs.add(o);
        }
      }
    }
    final s = v.sheetRgba == null ? null : await _decode(v.sheetRgba!, v.sheetW, v.sheetH);
    final r = v.rawRgba == null ? null : await _decode(v.rawRgba!, v.rawW, v.rawH);
    _busy = false;
    if (_disposed) return;
    if (s != null) {
      sheetImage?.dispose();
      sheetImage = s;
    }
    if (r != null) {
      rawImage?.dispose();
      rawImage = r;
    }
    view = v;
    notifyListeners();
  }

  static String _key(AidObservation o) => switch (o) {
        AbacusObservation(:final value) => 'abacus $value',
        RodsObservation(:final rows) => 'rods $rows',
        CellTouchObservation(:final sheetId, :final row, :final col) => 'touch $sheetId $row $col',
        CountersObservation(:final red, :final blue) => 'counters $red $blue',
      };

  static Future<ui.Image> _decode(Uint8List rgba, int w, int h) {
    final c = Completer<ui.Image>();
    ui.decodeImageFromPixels(rgba, w, h, ui.PixelFormat.rgba8888, c.complete);
    return c.future;
  }

  @override
  void dispose() {
    _disposed = true;
    _sub?.cancel();
    _worker?.stop();
    _obs.close();
    camera?.dispose();
    camera = null;
    sheetImage?.dispose();
    rawImage?.dispose();
    super.dispose();
  }
}
