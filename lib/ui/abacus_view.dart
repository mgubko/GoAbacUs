import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../arith/exercise.dart';
import '../arith/plan.dart';
import '../arith/player.dart';
import '../arith/tape.dart';
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

  /// Writes down what the child does.
  final tape = Tape();

  /// The example being shown, kept after it ends to show the answer.
  ExamplePlayer? player;

  /// Bumped whenever the tape or the shown step changes (not every frame).
  final changes = ValueNotifier<int>(0);

  bool get playing => player != null && !player!.done;

  /// Tasks to solve, when the exercise mode is on.
  ExerciseSession? exercise;
  int _shownSeconds = -1;

  void startExercises(ExerciseSettings settings) {
    player?.cancel();
    player = null;
    physics.sweepRight();
    exercise = ExerciseSession(settings);
    changes.value++;
  }

  /// Next task on an empty abacus.
  void nextExercise() {
    final e = exercise;
    if (e == null) return;
    player?.cancel();
    player = null;
    physics.sweepRight();
    e.next();
    changes.value++;
  }

  void submitExercise() {
    final e = exercise;
    if (e == null || e.state != TaskState.solving) return;
    e.submit(physics.value);
    sound.cue(success: e.state == TaskState.right);
    changes.value++;
  }

  void showSolution() {
    final e = exercise;
    if (e != null) play(e.task);
  }

  void stopExercises() {
    if (exercise == null) return;
    exercise = null;
    player?.cancel();
    player = null;
    tape.reset(physics.value);
    changes.value++;
  }

  static const double _dt = 1 / 240;
  double _acc = 0;
  Duration _clock = Duration.zero;

  /// Shows [example] on the abacus, starting from an empty one.
  void play(Example example) {
    player?.cancel();
    physics.grabs.clear();
    player = ExamplePlayer(physics, example);
    changes.value++;
  }

  /// Stops the show; recording goes on from what the abacus shows now.
  void stop() {
    if (player == null) return;
    player!.cancel();
    player = null;
    tape.reset(physics.value);
    changes.value++;
  }

  AbacusOverlay? overlay() {
    final p = player;
    if (p == null || p.done) return null;
    return AbacusOverlay(
      row: p.row,
      fingerRow: p.fingerRow,
      fingerX: p.fingerX,
    );
  }

  void tick(double elapsed) {
    _clock += Duration(microseconds: (elapsed * 1e6).round());
    final p = player;
    final before = p == null ? null : (p.term, p.step, p.done);
    if (playing) {
      // The board lies still while an example is shown.
      physics.gravityAlong = 0;
      physics.gravityNormal = 9.81;
    } else if (tiltEnabled && tilt.available) {
      physics.gravityAlong = tilt.along;
      physics.gravityNormal = tilt.normal;
    } else {
      physics.gravityAlong = 0;
      physics.gravityNormal = 9.81;
    }
    _acc += elapsed.clamp(0.0, 0.05);
    final impacts = <Impact>[];
    while (_acc >= _dt) {
      if (p != null && !p.done) p.update(_dt);
      impacts.addAll(physics.step(_dt));
      _acc -= _dt;
    }
    sound.play(impacts);
    _motionSound(elapsed);
    value.value = physics.value;
    final ex = exercise;
    if (p != null) {
      if (p.done && !before!.$3 && ex == null) tape.setExample(p.example);
      if ((p.term, p.step, p.done) != before) changes.value++;
      if (p.done &&
          before!.$3 &&
          ex == null &&
          p.example.result != 0 &&
          value.value == 0 &&
          physics.isAtRest) {
        // The beads were swept back (by tilting): start afresh.
        player = null;
        tape.reset();
        changes.value++;
      }
    } else if (ex != null) {
      final dt = Duration(
        microseconds: (elapsed.clamp(0.0, 0.1) * 1e6).round(),
      );
      if (ex.tick(dt, value.value, physics.isAtRest)) {
        sound.cue(success: ex.state == TaskState.right);
        changes.value++;
      }
      final seconds = ex.left.inSeconds;
      if (seconds != _shownSeconds) {
        _shownSeconds = seconds;
        changes.value++;
      }
    } else if (value.value == 0 && tape.terms.isNotEmpty && physics.isAtRest) {
      // All beads pushed back to the right: a fresh start, as with the
      // clear button.
      tape.reset();
      changes.value++;
    } else if (tape.update(value.value, physics.isAtRest, _clock)) {
      changes.value++;
    }
    notifyListeners();
  }

  /// Sweeps the beads away and starts a new record. During exercises only
  /// the beads are swept: the task stays.
  void clear() {
    if (exercise != null) {
      if (!playing) physics.sweepRight();
      return;
    }
    player?.cancel();
    player = null;
    physics.sweepRight();
    tape.reset();
    changes.value++;
  }

  /// The child touches the abacus after an example: back to free counting.
  void takeOver() {
    if (player == null || playing) return;
    player = null;
    changes.value++;
  }

  /// Measures how beads move: lone beads sliding and groups sliding together
  /// (beads touching each other, which rattle), and drives the loop sounds.
  List<List<double>>? _lastX;

  void _motionSound(double elapsed) {
    final cfg = physics.config;
    final prev = _lastX;
    _lastX = [for (final row in physics.x) List.of(row)];
    if (prev == null || elapsed <= 0) return;
    // Speeds from real displacement, so beads pressed against a stack or
    // the frame are silent.
    final dt = elapsed.clamp(0.001, 0.05);
    var single = 0.0;
    var group = 0.0;
    for (var r = 0; r < cfg.rows; r++) {
      final xs = physics.x[r];
      double sp(int k) => (xs[k] - prev[r][k]).abs() / dt;
      var i = 0;
      while (i < xs.length) {
        var j = i;
        var speed = sp(i);
        while (j + 1 < xs.length &&
            xs[j + 1] - xs[j] - cfg.beadLength <= 0.0006) {
          j++;
          speed += sp(j);
        }
        final size = j - i + 1;
        speed /= size;
        if (speed > 0.01) {
          if (size == 1) {
            single += speed;
          } else {
            group += speed * math.sqrt(size);
          }
        }
        i = j + 1;
      }
    }
    sound.motion(math.min(1, single / 0.6), math.min(1, group / 1.2));
  }

  @override
  void dispose() {
    tilt.dispose();
    sound.dispose();
    value.dispose();
    changes.dispose();
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

  /// Fingers brushed up or down across the rows: they spin the beads round
  /// their wires instead of moving them.
  final _swipes = <int, _Swipe>{};

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
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      c.sound.setPaused(false);
      c.tilt.resume();
      c.tilt.refreshRotation();
      if (!_ticker.isActive) {
        _last = Duration.zero;
        _ticker.start();
      }
      // GPU textures can be dropped while in the background: redraw them.
      setState(() => _art = null);
    } else {
      // Leaving the app: stop simulating, release fingers, silence sounds.
      if (_ticker.isActive) _ticker.stop();
      _pending.clear();
      _lastMove.clear();
      _swipes.clear();
      c.physics.grabs.removeWhere((k, _) => k >= 0);
      c.sound.setPaused(true);
      c.tilt.pause();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _ticker.dispose();
    super.dispose();
  }

  AbacusLayout get _layout => _art!.layout;

  void _down(PointerDownEvent e) {
    if (_art == null || c.playing) return;
    c.takeOver();
    final row = _layout.rowAt(e.localPosition.dy);
    if (row == null) return;
    _swipes[e.pointer] = _Swipe(row, e.localPosition, e.timeStamp);
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
    if (_spinSwipe(e)) return;
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

  /// Follows a finger across the rows. Once it crosses into another row
  /// moving mostly up or down, it no longer drags beads: every wire it
  /// passes spins its beads, louder for a faster swipe over more wires.
  bool _spinSwipe(PointerMoveEvent e) {
    final s = _swipes[e.pointer];
    if (s == null) return false;
    final row = _layout.rowAt(e.localPosition.dy);
    if (row == null || row == s.row) return s.spinning;
    final d = e.localPosition - s.from;
    if (!s.spinning && d.dy.abs() < d.dx.abs() * 1.2) {
      // A sideways drag that wandered into the next row: keep dragging.
      return false;
    }
    final dt = (e.timeStamp - s.time).inMicroseconds / 1e6;
    final crossed = (row - s.row).abs();
    // Speed in wires per second, smoothed over the crossings.
    final f = crossed / math.max(dt, 0.004);
    s.speed = s.spinning ? s.speed * 0.5 + f * 0.5 : f;
    s.row = row;
    s.time = e.timeStamp;
    s.from = e.localPosition;
    s.wires += crossed;
    final fresh = !s.spinning;
    if (fresh) {
      s.spinning = true;
      _pending.remove(e.pointer);
      c.physics.grabs.remove(e.pointer);
    }
    c.sound.spin(_spinLevel(s.speed, s.wires), fresh: fresh);
    return true;
  }

  /// Loudness grows as log(f·n): f wires per second, n wires touched. A slow
  /// brush over two wires is a whisper; 40 wires/s over all ten is full.
  static double _spinLevel(double f, int n) {
    const quiet = 2.0 * 2;
    const loud = 40.0 * 10;
    final k = math.log(math.max(f * n, quiet) / quiet) / math.log(loud / quiet);
    return 0.15 + 0.85 * k.clamp(0.0, 1.0);
  }

  void _up(PointerEvent e) {
    _swipes.remove(e.pointer);
    _pending.remove(e.pointer);
    _lastMove.remove(e.pointer);
    if (e.pointer >= 0) c.physics.grabs.remove(e.pointer);
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
            painter: AbacusPainter(
              physics: c.physics,
              art: _art!,
              repaint: c,
              overlay: c.overlay,
            ),
          ),
        );
      },
    );
  }
}

class _Swipe {
  _Swipe(this.row, this.from, this.time);
  int row;
  Offset from;
  Duration time;
  double speed = 0;

  /// Wires touched so far, the first one included.
  int wires = 1;
  bool spinning = false;
}
