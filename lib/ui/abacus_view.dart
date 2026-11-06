import 'dart:ui' as ui;

import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../audio/sound_engine.dart';
import '../physics/abacus_physics.dart';
import '../sensors/tilt.dart';
import 'abacus_painter.dart';

/// Drives an [AbacusPhysics] in real time: fixed-step simulation, fingers,
/// tilt, sound. Owned by the screen so buttons can reach it.
class AbacusController extends ChangeNotifier {
  AbacusController({AbacusConfig config = const AbacusConfig()})
    : physics = AbacusPhysics(config);

  final AbacusPhysics physics;
  final sound = SoundEngine();
  final tilt = TiltSensor();
  final value = ValueNotifier<int>(0);
  bool tiltEnabled = true;

  static const double _dt = 1 / 240;
  double _acc = 0;

  void tick(double elapsed) {
    if (tiltEnabled && tilt.available) {
      physics.gravityAlong = tilt.along;
      physics.gravityNormal = tilt.normal;
    } else {
      physics.gravityAlong = 0;
      physics.gravityNormal = 9.81;
    }
    _acc += elapsed.clamp(0.0, 0.05);
    final impacts = <Impact>[];
    while (_acc >= _dt) {
      impacts.addAll(physics.step(_dt));
      _acc -= _dt;
    }
    sound.play(impacts);
    value.value = physics.value;
    notifyListeners();
  }

  void clear() => physics.sweepRight();

  @override
  void dispose() {
    tilt.dispose();
    sound.dispose();
    value.dispose();
    super.dispose();
  }
}

class AbacusView extends StatefulWidget {
  const AbacusView({super.key, required this.controller});
  final AbacusController controller;

  @override
  State<AbacusView> createState() => _AbacusViewState();
}

class _AbacusViewState extends State<AbacusView>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late final Ticker _ticker;
  Duration _last = Duration.zero;
  ui.Image? _wood;
  ui.Image? _bone;
  AbacusArt? _art;

  /// Fingers that touched a gap and wait to reach a bead.
  final _pending = <int, int>{};
  final _lastMove = <int, Duration>{};

  AbacusController get c => widget.controller;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _ticker = createTicker((now) {
      final dt = (now - _last).inMicroseconds / 1e6;
      _last = now;
      c.tick(dt);
    })..start();
    _loadImages();
  }

  Future<void> _loadImages() async {
    Future<ui.Image> load(String path) async {
      final data = await rootBundle.load(path);
      final codec = await ui.instantiateImageCodec(data.buffer.asUint8List());
      return (await codec.getNextFrame()).image;
    }

    final wood = await load('assets/images/wood.jpg');
    final bone = await load('assets/images/bone.jpg');
    if (!mounted) return;
    setState(() {
      _wood = wood;
      _bone = bone;
    });
  }

  @override
  void didChangeMetrics() => c.tilt.refreshRotation();

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _ticker.dispose();
    super.dispose();
  }

  AbacusLayout get _layout => _art!.layout;

  void _down(PointerDownEvent e) {
    if (_art == null) return;
    final row = _layout.rowAt(e.localPosition.dy);
    if (row == null) return;
    final pos = _layout.toMetres(e.localPosition.dx);
    final bead = c.physics.beadAt(row, pos, tolerance: 0.004);
    if (bead != null) {
      _grab(e.pointer, row, bead, pos);
    } else {
      _pending[e.pointer] = row;
    }
    _lastMove[e.pointer] = e.timeStamp;
  }

  void _grab(int pointer, int row, int bead, double fingerPos) {
    final p = c.physics;
    p.grabs[pointer] = Grab(row, bead, p.x[row][bead] - fingerPos, fingerPos);
  }

  void _move(PointerMoveEvent e) {
    if (_art == null) return;
    final pos = _layout.toMetres(e.localPosition.dx);
    final pendingRow = _pending[e.pointer];
    if (pendingRow != null) {
      final bead = c.physics.beadAt(pendingRow, pos, tolerance: 0);
      if (bead != null) {
        _pending.remove(e.pointer);
        // The finger meets the edge of the bead and starts pushing it.
        final p = c.physics;
        final edge = e.localDelta.dx >= 0
            ? p.x[pendingRow][bead] - p.config.halfBead
            : p.x[pendingRow][bead] + p.config.halfBead;
        p.grabs[e.pointer] = Grab(
          pendingRow,
          bead,
          p.x[pendingRow][bead] - edge,
          pos,
        );
      }
    }
    final g = c.physics.grabs[e.pointer];
    if (g != null) {
      final prev = _lastMove[e.pointer] ?? e.timeStamp;
      final dt = (e.timeStamp - prev).inMicroseconds / 1e6;
      final newV = dt > 0 ? (pos - g.target) / dt : g.targetVelocity;
      g.targetVelocity = g.targetVelocity * 0.4 + newV * 0.6;
      g.target = pos;
    }
    _lastMove[e.pointer] = e.timeStamp;
  }

  void _up(PointerEvent e) {
    _pending.remove(e.pointer);
    _lastMove.remove(e.pointer);
    c.physics.grabs.remove(e.pointer);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, box) {
        final size = box.biggest;
        if (_wood != null &&
            _bone != null &&
            (_art == null || !_art!.layout.sameAs(size))) {
          _art = AbacusArt.build(
            AbacusLayout(size, c.physics.config),
            _wood!,
            _bone!,
            MediaQuery.devicePixelRatioOf(context),
          );
        }
        if (_art == null) return const SizedBox.expand();
        return Listener(
          onPointerDown: _down,
          onPointerMove: _move,
          onPointerUp: _up,
          onPointerCancel: _up,
          behavior: HitTestBehavior.opaque,
          child: CustomPaint(
            size: size,
            painter: AbacusPainter(physics: c.physics, art: _art!, repaint: c),
          ),
        );
      },
    );
  }
}
