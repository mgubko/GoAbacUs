import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../physics/abacus_physics.dart';

/// Converts between physics metres and screen pixels.
class AbacusLayout {
  AbacusLayout(this.size, this.config) {
    const digitColumn = 56.0;
    final avail = Rect.fromLTWH(
      12,
      8,
      size.width - 24 - digitColumn,
      size.height - 16,
    );
    frameThickness = math.min(avail.width, avail.height) * 0.06;
    final innerWidth = avail.width - 2 * frameThickness;
    scale = innerWidth / config.wireLength;
    beadWidth = config.beadLength * scale;
    // Compact turned beads: taller than they are thick. Rows are as tall as
    // the beads need; the frame does not stretch to fill a tall screen.
    final maxSpacing = (avail.height - 2 * frameThickness) / config.rows;
    spacing = math.min(maxSpacing, beadWidth * 1.6 / 0.85);
    beadHeight = math.min(spacing * 0.85, beadWidth * 1.6);
    final frameHeight = spacing * config.rows + 2 * frameThickness;
    frame = Rect.fromLTWH(
      avail.left,
      avail.top + (avail.height - frameHeight) / 2,
      avail.width,
      frameHeight,
    );
    inner = frame.deflate(frameThickness);
    digitsX = frame.right + digitColumn / 2 + 4;
  }

  final Size size;
  final AbacusConfig config;
  late final Rect frame;
  late final Rect inner;
  late final double frameThickness;
  late final double spacing;
  late final double scale;
  late final double beadWidth;
  late final double beadHeight;
  late final double digitsX;

  /// Row 0 (units) is at the bottom, like on Russian school abacus.
  double wireY(int row) => inner.top + spacing * (config.rows - 1 - row + 0.5);

  double beadX(double metres) => inner.left + metres * scale;

  double toMetres(double px) => (px - inner.left) / scale;

  int? rowAt(double y) {
    if (y < inner.top - spacing * 0.3 || y > inner.bottom + spacing * 0.3) {
      return null;
    }
    final idx = ((y - inner.top) / spacing).floor().clamp(0, config.rows - 1);
    return config.rows - 1 - idx;
  }

  bool sameAs(Size s) => s == size;
}

/// Pre-rendered artwork: the frame with wires and the two kinds of beads.
class AbacusArt {
  AbacusArt._(
    this.layout,
    this.background,
    this.whiteBead,
    this.blackBead,
    this.spritePad,
  );

  final AbacusLayout layout;
  final ui.Picture background;
  final ui.Image whiteBead;
  final ui.Image blackBead;
  final double spritePad;

  static AbacusArt build(
    AbacusLayout layout,
    ui.Image wood,
    ui.Image bone,
    double pixelRatio,
  ) {
    final pad = layout.beadHeight * 0.25;
    return AbacusArt._(
      layout,
      _frame(layout, wood),
      _bead(layout, bone, false, pad, pixelRatio),
      _bead(layout, bone, true, pad, pixelRatio),
      pad,
    );
  }

  static ui.Picture _frame(AbacusLayout l, ui.Image wood) {
    final rec = ui.PictureRecorder();
    final c = Canvas(rec);

    final outer = RRect.fromRectAndRadius(
      l.frame,
      Radius.circular(l.frameThickness * 0.5),
    );
    final innerR = RRect.fromRectAndRadius(
      l.inner,
      Radius.circular(l.frameThickness * 0.15),
    );

    // Shadow of the frame on the table.
    c.drawRRect(
      outer.shift(Offset(l.frameThickness * 0.12, l.frameThickness * 0.25)),
      Paint()
        ..color = Colors.black.withValues(alpha: 0.35)
        ..maskFilter = MaskFilter.blur(
          BlurStyle.normal,
          l.frameThickness * 0.35,
        ),
    );

    // Inside the frame: the table, slightly shaded by the frame.
    c.save();
    c.clipRRect(innerR);
    c.drawRect(l.inner, Paint()..color = const Color(0xFFEDE1CC));
    c.restore();

    final ring = Path()
      ..fillType = PathFillType.evenOdd
      ..addRRect(outer)
      ..addRRect(innerR);

    // Wood: horizontal grain on the top and bottom bars, vertical on the sides.
    final woodScale = l.frame.width / wood.width;
    final horizontal = ImageShader(
      wood,
      TileMode.mirror,
      TileMode.mirror,
      (Matrix4.identity()..scaleByDouble(woodScale, woodScale * 0.8, 1, 1))
          .storage,
    );
    final vertical = ImageShader(
      wood,
      TileMode.mirror,
      TileMode.mirror,
      (Matrix4.identity()
            ..rotateZ(math.pi / 2)
            ..scaleByDouble(woodScale * 0.6, woodScale * 0.6, 1, 1))
          .storage,
    );
    c.save();
    c.clipPath(ring);
    c.drawRect(l.frame, Paint()..shader = horizontal);
    final t = l.frameThickness;
    final sideClip = Path()
      ..moveTo(l.frame.left, l.frame.top)
      ..lineTo(l.inner.left, l.inner.top)
      ..lineTo(l.inner.left, l.inner.bottom)
      ..lineTo(l.frame.left, l.frame.bottom)
      ..close()
      ..moveTo(l.frame.right, l.frame.top)
      ..lineTo(l.inner.right, l.inner.top)
      ..lineTo(l.inner.right, l.inner.bottom)
      ..lineTo(l.frame.right, l.frame.bottom)
      ..close();
    c.drawPath(sideClip, Paint()..shader = vertical);
    // Mitre joints.
    final joint = Paint()
      ..color = Colors.black.withValues(alpha: 0.35)
      ..strokeWidth = 1;
    c.drawLine(l.frame.topLeft, l.inner.topLeft, joint);
    c.drawLine(l.frame.topRight, l.inner.topRight, joint);
    c.drawLine(l.frame.bottomLeft, l.inner.bottomLeft, joint);
    c.drawLine(l.frame.bottomRight, l.inner.bottomRight, joint);
    // Varnish: light from the top left, rounded profile of the bars.
    c.drawRect(
      l.frame,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white.withValues(alpha: 0.18),
            Colors.transparent,
            Colors.black.withValues(alpha: 0.25),
          ],
        ).createShader(l.frame),
    );
    c.restore();

    // Bevels.
    c.drawRRect(
      outer.deflate(1),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = Colors.white.withValues(alpha: 0.18),
    );
    c.drawRRect(
      innerR,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = Colors.black.withValues(alpha: 0.45),
    );
    // Shadow of the top bar inside the frame.
    c.save();
    c.clipRRect(innerR);
    c.drawRect(
      Rect.fromLTWH(l.inner.left, l.inner.top, l.inner.width, t * 0.5),
      Paint()
        ..shader =
            LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.black.withValues(alpha: 0.25),
                Colors.transparent,
              ],
            ).createShader(
              Rect.fromLTWH(l.inner.left, l.inner.top, l.inner.width, t * 0.5),
            ),
    );
    c.restore();

    // Wires with their shadows on the table.
    final wireW = math.max(2.0, l.spacing * 0.035);
    for (var r = 0; r < l.config.rows; r++) {
      final y = l.wireY(r);
      c.drawLine(
        Offset(l.inner.left, y + l.spacing * 0.12),
        Offset(l.inner.right, y + l.spacing * 0.12),
        Paint()
          ..color = Colors.black.withValues(alpha: 0.12)
          ..strokeWidth = wireW
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, wireW),
      );
      final wireRect = Rect.fromLTRB(
        l.inner.left - 2,
        y - wireW / 2,
        l.inner.right + 2,
        y + wireW / 2,
      );
      c.drawRect(
        wireRect,
        Paint()
          ..shader = const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFF2F2F0), Color(0xFF9A9A98), Color(0xFF4A4A48)],
          ).createShader(wireRect),
      );
    }
    return rec.endRecording();
  }

  static ui.Image _bead(
    AbacusLayout l,
    ui.Image bone,
    bool black,
    double pad,
    double pixelRatio,
  ) {
    final w = l.beadWidth;
    final h = l.beadHeight;
    final rec = ui.PictureRecorder();
    final c = Canvas(rec);
    c.scale(pixelRatio);
    final body = Rect.fromLTWH(pad, pad, w, h);
    final shape = RRect.fromRectAndRadius(
      body,
      Radius.elliptical(w * 0.48, h * 0.42),
    );

    // Contact shadow on the table.
    c.drawRRect(
      shape.shift(Offset(w * 0.08, h * 0.12)),
      Paint()
        ..color = Colors.black.withValues(alpha: 0.38)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, h * 0.07),
    );

    c.save();
    c.clipRRect(shape);
    final s = h / bone.height * 1.6;
    final shader = ImageShader(
      bone,
      TileMode.mirror,
      TileMode.mirror,
      (Matrix4.identity()
            ..translateByDouble(pad, pad, 0, 1)
            ..scaleByDouble(s, s, 1, 1))
          .storage,
    );
    final base = Paint()..shader = shader;
    if (black) {
      base.colorFilter = const ColorFilter.mode(
        Color(0xFF2B2420),
        BlendMode.multiply,
      );
    }
    c.drawRect(body, base);

    // Rounded profile: darker towards the rims of the bead...
    c.drawRect(
      body,
      Paint()
        ..shader = LinearGradient(
          colors: [
            Colors.black.withValues(alpha: black ? 0.55 : 0.42),
            Colors.black.withValues(alpha: 0.0),
            Colors.white.withValues(alpha: black ? 0.10 : 0.18),
            Colors.black.withValues(alpha: 0.0),
            Colors.black.withValues(alpha: black ? 0.6 : 0.48),
          ],
          stops: const [0.0, 0.3, 0.5, 0.7, 1.0],
        ).createShader(body),
    );
    // ...lit from above.
    c.drawRect(
      body,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.white.withValues(alpha: black ? 0.22 : 0.35),
            Colors.white.withValues(alpha: 0.0),
            Colors.black.withValues(alpha: black ? 0.35 : 0.28),
          ],
          stops: const [0.0, 0.45, 1.0],
        ).createShader(body),
    );
    // Equator ridge of the turned bead.
    c.drawLine(
      Offset(body.center.dx, body.top + h * 0.08),
      Offset(body.center.dx, body.bottom - h * 0.08),
      Paint()
        ..color = Colors.white.withValues(alpha: black ? 0.12 : 0.28)
        ..strokeWidth = math.max(1, w * 0.05)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, w * 0.04),
    );
    // Gloss.
    c.drawOval(
      Rect.fromCenter(
        center: Offset(body.left + w * 0.42, body.top + h * 0.24),
        width: w * 0.32,
        height: h * 0.16,
      ),
      Paint()
        ..color = Colors.white.withValues(alpha: black ? 0.45 : 0.7)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, w * 0.06),
    );
    c.restore();
    c.drawRRect(
      shape,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.8
        ..color = Colors.black.withValues(alpha: 0.35),
    );
    final pic = rec.endRecording();
    return pic.toImageSync(
      ((w + pad * 2) * pixelRatio).ceil(),
      ((h + pad * 2) * pixelRatio).ceil(),
    );
  }
}

/// What an example being played adds to the picture: the row being worked
/// and the invisible finger.
class AbacusOverlay {
  const AbacusOverlay({this.row, this.fingerRow, this.fingerX});
  final int? row;
  final int? fingerRow;
  final double? fingerX;
}

class AbacusPainter extends CustomPainter {
  AbacusPainter({
    required this.physics,
    required this.art,
    required Listenable repaint,
    this.overlay,
  }) : super(repaint: repaint);

  final AbacusPhysics physics;
  final AbacusArt art;
  final AbacusOverlay? Function()? overlay;

  static const _accent = Color(0xFFB5452B);

  @override
  void paint(Canvas canvas, Size size) {
    final l = art.layout;
    canvas.drawPicture(art.background);
    final cfg = physics.config;
    final o = overlay?.call();
    if (o?.row != null) {
      // A warm glow along the wire being worked.
      final y = l.wireY(o!.row!);
      final band = Rect.fromLTRB(
        l.inner.left,
        y - l.spacing / 2,
        l.inner.right,
        y + l.spacing / 2,
      );
      canvas.drawRect(
        band,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              const Color(0x00FFE7A8),
              const Color(0x66FFE7A8),
              const Color(0x00FFE7A8),
            ],
          ).createShader(band),
      );
    }
    final src = Rect.fromLTWH(
      0,
      0,
      art.whiteBead.width.toDouble(),
      art.whiteBead.height.toDouble(),
    );
    final paint = Paint()..filterQuality = FilterQuality.medium;
    final w = l.beadWidth + art.spritePad * 2;
    final h = l.beadHeight + art.spritePad * 2;
    final mid = cfg.beadsPerRow ~/ 2;
    for (var r = 0; r < cfg.rows; r++) {
      final y = l.wireY(r);
      final xs = physics.x[r];
      for (var i = 0; i < cfg.beadsPerRow; i++) {
        final black = cfg.beadsPerRow >= 4 && (i == mid - 1 || i == mid);
        final cx = l.beadX(xs[i]);
        canvas.drawImageRect(
          black ? art.blackBead : art.whiteBead,
          src,
          Rect.fromLTWH(cx - w / 2, y - h / 2, w, h),
          paint,
        );
      }
      // Digit of this row.
      final n = physics.countedBeads(r);
      final active = o?.row == r;
      final tp = TextPainter(
        text: TextSpan(
          text: '$n',
          style: TextStyle(
            fontSize: math.min(l.spacing * (active ? 0.62 : 0.5), 36),
            fontWeight: active ? FontWeight.w800 : FontWeight.w600,
            color: active
                ? _accent
                : n == 0
                ? const Color(0x55402A1A)
                : const Color(0xFF402A1A),
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(l.digitsX - tp.width / 2, y - tp.height / 2));
    }
    if (o?.fingerRow != null && o?.fingerX != null) {
      // The invisible finger: a soft fingertip pressing the bead's edge.
      final c = Offset(l.beadX(o!.fingerX!), l.wireY(o.fingerRow!));
      final radius = l.beadHeight * 0.42;
      canvas.drawCircle(
        c.translate(1, 2),
        radius,
        Paint()
          ..color = Colors.black.withValues(alpha: 0.18)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, radius * 0.35),
      );
      canvas.drawCircle(
        c,
        radius,
        Paint()..color = const Color(0xFFF2B8A0).withValues(alpha: 0.72),
      );
      canvas.drawCircle(
        c,
        radius,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = _accent.withValues(alpha: 0.8),
      );
    }
  }

  @override
  bool shouldRepaint(AbacusPainter old) =>
      old.art != art || old.physics != physics;
}
