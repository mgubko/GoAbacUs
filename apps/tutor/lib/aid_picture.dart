import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:tutor_tasks/tutor_tasks.dart';

/// The picture of a desk aid for the current question: what the child lays
/// out (the "ikonisch" step between hands and symbols), and after the
/// right answer the whole solution (8 + 5 = 10 + 3 on the twenty frame).
class AidPicture extends StatelessWidget {
  const AidPicture({
    super.key,
    required this.aid,
    required this.question,
    required this.reveal,
  });

  final Aid aid;
  final Question question;
  final bool reveal;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _AidPainter(aid, question, reveal),
      size: Size.infinite,
    );
  }
}

/// Rod colours 1–10 in the usual order (white, red, light green, pink,
/// yellow, dark green, black, brown, blue, orange).
const rodColors = [
  Color(0xFFF4F1EA),
  Color(0xFFD7263D),
  Color(0xFF8BC34A),
  Color(0xFFC2185B),
  Color(0xFFFFD23F),
  Color(0xFF2E7D32),
  Color(0xFF333333),
  Color(0xFF8D5524),
  Color(0xFF1E5AA8),
  Color(0xFFF57C00),
];

const _red = Color(0xFFD7263D);
const _blue = Color(0xFF1E5AA8);
const _ink = Color(0xFF402A1A);
const _paper = Color(0xFFFDFAF1);

class _AidPainter extends CustomPainter {
  _AidPainter(this.aid, this.q, this.reveal);
  final Aid aid;
  final Question q;
  final bool reveal;

  /// a, b as the child lays them out (? + 3 = 7 is laid as 7 − 3).
  (int, int, String) get _setup => switch ((q.op, q.unknown)) {
    (Op.add, Slot.b) => (q.a, q.result - q.a, 'missing'),
    (Op.sub, Slot.b) => (q.result, q.a - q.result, 'missing'),
    (Op.add, Slot.a) => (q.result, q.b, 'sub'),
    (Op.sub, Slot.a) => (q.result, q.b, 'add'),
    (Op.add, _) => (q.a, q.b, 'add'),
    (Op.sub, _) => (q.a, q.b, 'sub'),
    (Op.mul, _) => (q.a, q.b, 'mul'),
    (Op.div, _) => (q.a, q.b, 'div'),
  };

  @override
  void paint(Canvas canvas, Size size) {
    final r = Rect.fromLTWH(12, 8, size.width - 24, size.height - 16);
    canvas.drawRRect(
      RRect.fromRectAndRadius(r, const Radius.circular(14)),
      Paint()..color = _paper,
    );
    final inner = r.deflate(14);
    switch (aid) {
      case Aid.twentyField:
        _field(canvas, inner);
      case Aid.rods:
        _rods(canvas, inner);
      case Aid.hundredField:
        _hundred(canvas, inner);
      case Aid.fingers:
        _fingers(canvas, inner);
      case Aid.additionTable:
      case Aid.timesTable:
        _table(canvas, inner);
      case Aid.abacus:
        break;
    }
  }

  void _dot(Canvas c, Offset o, double rad, Color color,
      {bool empty = false, bool crossed = false}) {
    if (empty) {
      c.drawCircle(
        o,
        rad,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = _ink.withValues(alpha: 0.35),
      );
      return;
    }
    c.drawCircle(o, rad, Paint()..color = color.withValues(alpha: crossed ? 0.25 : 1));
    if (crossed) {
      final p = Paint()
        ..color = _ink
        ..strokeWidth = 2.5;
      final d = rad * 0.7;
      c.drawLine(o.translate(-d, -d), o.translate(d, d), p);
      c.drawLine(o.translate(-d, d), o.translate(d, -d), p);
    }
  }

  void _text(Canvas c, String s, Offset at, {double size = 22, bool center = true}) {
    final tp = TextPainter(
      text: TextSpan(
        text: s,
        style: TextStyle(fontSize: size, color: _ink, fontWeight: FontWeight.w700),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(c, center ? at - Offset(tp.width / 2, tp.height / 2) : at);
  }

  /// Zwanzigerfeld: 2 × 10, 5 | 5, filled from the left, top row first.
  void _field(Canvas c, Rect r) {
    final (a, b, kind) = _setup;
    if (kind == 'div' || kind == 'mul') return _groups(c, r, a, b);
    final cell = math.min(r.width / 10.6, r.height / 2.8);
    final w = cell * 10 + cell * 0.6;
    final left = r.center.dx - w / 2;
    final top = r.top + (r.height - cell * 2) / 2 - 10;
    Offset at(int i) {
      final row = i ~/ 10, col = i % 10;
      final x = left + col * cell + (col >= 5 ? cell * 0.6 : 0) + cell / 2;
      return Offset(x, top + row * cell + cell / 2);
    }

    final grid = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..color = _ink.withValues(alpha: 0.5);
    for (var i = 0; i < 20; i++) {
      c.drawRect(Rect.fromCenter(center: at(i), width: cell, height: cell), grid);
    }
    final rad = cell * 0.38;
    final total = kind == 'sub' ? a : a + b;
    for (var i = 0; i < math.min(20, total); i++) {
      if (kind == 'sub') {
        _dot(c, at(i), rad, _red, crossed: i >= a - b);
      } else if (i < a) {
        _dot(c, at(i), rad, _red);
      } else {
        _dot(c, at(i), rad, _blue, empty: kind == 'missing' && !reveal);
      }
    }
    if (reveal) {
      _text(c, q.format().replaceFirst('?', '${q.answer}'),
          Offset(r.center.dx, top + cell * 2 + 26));
    }
  }

  /// Counters (or dots) in rows of [b]: division as Aufteilen, the
  /// remainder in a different colour.
  void _groups(Canvas c, Rect r, int a, int b) {
    final per = math.max(1, b);
    final rows = (a / per).ceil();
    final cell = math.min(r.width / math.max(per, 5), r.height / math.max(rows + 1, 3));
    final left = r.center.dx - per * cell / 2;
    final top = r.top + 4;
    final count = q.op == Op.mul ? a * b : a;
    final rowLen = q.op == Op.mul ? b : per;
    for (var i = 0; i < count; i++) {
      final row = i ~/ rowLen, col = i % rowLen;
      final inRest = q.op == Op.div && row == count ~/ rowLen && count % rowLen != 0;
      _dot(
        c,
        Offset(left + col * cell + cell / 2, top + row * cell + cell / 2),
        cell * 0.36,
        inRest && reveal ? const Color(0xFF9E9E9E) : _red,
      );
    }
    if (reveal) {
      _text(c, q.format().replaceFirst('?', '${q.answer}'),
          Offset(r.center.dx, math.min(r.bottom - 14, top + rows * cell + 22)));
    }
  }

  void _rod(Canvas c, double x, double y, int n, double unit, double h,
      {bool dashed = false}) {
    final rect = Rect.fromLTWH(x, y, n * unit, h);
    if (dashed) {
      c.drawRRect(
        RRect.fromRectAndRadius(rect, const Radius.circular(4)),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = _ink.withValues(alpha: 0.4),
      );
      _text(c, '?', rect.center, size: h * 0.6);
      return;
    }
    c.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(4)),
      Paint()..color = rodColors[(n - 1).clamp(0, 9)],
    );
    c.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(4)),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..color = _ink.withValues(alpha: 0.6),
    );
    final dark = n == 7 || n == 9 || n == 6 || n == 4 || n == 2 || n == 8;
    final tp = TextPainter(
      text: TextSpan(
        text: '$n',
        style: TextStyle(
          fontSize: h * 0.5,
          fontWeight: FontWeight.w700,
          color: dark ? Colors.white : _ink,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    if (rect.width > tp.width + 4) {
      tp.paint(c, rect.center - Offset(tp.width / 2, tp.height / 2));
    }
  }

  /// A row of rods for a length: tens, then the rest.
  void _length(Canvas c, double x, double y, int n, double unit, double h) {
    var at = x;
    for (var i = 0; i < n ~/ 10; i++) {
      _rod(c, at, y, 10, unit, h);
      at += 10 * unit;
    }
    if (n % 10 != 0) _rod(c, at, y, n % 10, unit, h);
  }

  void _rods(Canvas c, Rect r) {
    final (a, b, kind) = _setup;
    final total = switch (kind) {
      'mul' => a * b,
      'div' => a,
      'sub' || 'missing' => math.max(a, a + b),
      _ => a + b,
    };
    final unit = r.width / math.max(10, total + 1);
    final h = math.min(36.0, r.height / 4);
    final x = r.left + (r.width - total * unit) / 2;
    var y = r.top + 6;
    switch (kind) {
      case 'add':
        _rod(c, x, y, a, unit, h);
        _rod(c, x + a * unit, y, b, unit, h);
        y += h + 8;
        if (reveal || a + b > 10) {
          if (a + b > 10) {
            _rod(c, x, y, 10, unit, h);
            if (reveal) {
              _rod(c, x + 10 * unit, y, a + b - 10, unit, h);
            } else {
              _rod(c, x + 10 * unit, y, a + b - 10, unit, h, dashed: true);
            }
          } else {
            _rod(c, x, y, a + b, unit, h);
          }
        } else {
          _rod(c, x, y, a + b, unit, h, dashed: true);
        }
      case 'sub':
        _length(c, x, y, a, unit, h);
        y += h + 8;
        _rod(c, x, y, b, unit, h);
        if (a - b > 0) {
          _rod(c, x + b * unit, y, a - b, unit, h, dashed: !reveal);
        }
      case 'missing':
        final whole = a + b;
        _length(c, x, y, whole, unit, h);
        y += h + 8;
        _rod(c, x, y, a, unit, h);
        if (b > 0) _rod(c, x + a * unit, y, b, unit, h, dashed: !reveal);
      case 'mul':
        for (var i = 0; i < a; i++) {
          _rod(c, x + i * b * unit, y, b, unit, h);
        }
        y += h + 8;
        if (reveal) _length(c, x, y, a * b, unit, h);
      case 'div':
        _length(c, x, y, a, unit, h);
        y += h + 8;
        final n = b == 0 ? 0 : a ~/ b;
        for (var i = 0; i < n; i++) {
          _rod(c, x + i * b * unit, y, b, unit, h);
        }
        if (b != 0 && a % b != 0) {
          _rod(c, x + n * b * unit, y, a % b, unit, h, dashed: !reveal);
        }
    }
    if (reveal) {
      _text(c, q.format().replaceFirst('?', '${q.answer}'),
          Offset(r.center.dx, y + h + 26));
    }
  }

  /// Hunderterpunktefeld with the Malwinkel: a rows of b dots.
  void _hundred(Canvas c, Rect r) {
    final (a, b, kind) = _setup;
    final cell = math.min(r.width, r.height - 30) / 10.6;
    final left = r.center.dx - cell * 5.3;
    final top = r.top;
    Offset at(int row, int col) => Offset(
      left + col * cell + (col >= 5 ? cell * 0.6 : 0) + cell / 2,
      top + row * cell + (row >= 5 ? cell * 0.6 : 0) + cell / 2,
    );
    bool on(int row, int col) {
      if (kind == 'div') {
        final i = row * b + col;
        return col < b && i < a;
      }
      return row < a && col < b;
    }

    for (var row = 0; row < 10; row++) {
      for (var col = 0; col < 10; col++) {
        final lit = on(row, col);
        final rest = kind == 'div' && lit && b > 0 && row == a ~/ b;
        c.drawCircle(
          at(row, col),
          cell * 0.3,
          Paint()
            ..color = lit
                ? (rest && reveal ? const Color(0xFF9E9E9E) : _red)
                : _ink.withValues(alpha: 0.15),
        );
      }
    }
    // The Malwinkel: an L along the edge of the uncovered rows and columns.
    // Division: the full rows inside the Winkel, the remainder outside.
    final rows = kind == 'div' ? (b == 0 ? 0 : a ~/ b) : a;
    final cols = b;
    if (rows > 0 && cols > 0 && rows <= 10 && cols <= 10) {
      final corner = at(rows - 1, cols - 1) + Offset(cell / 2 + 3, cell / 2 + 3);
      final p = Paint()
        ..color = const Color(0xFF6B3E22)
        ..strokeWidth = 5
        ..strokeCap = StrokeCap.round;
      c.drawLine(Offset(corner.dx, top), corner, p);
      c.drawLine(Offset(left, corner.dy), corner, p);
    }
    if (reveal) {
      _text(c, q.format().replaceFirst('?', '${q.answer}'),
          Offset(r.center.dx, r.bottom - 14));
    }
  }

  /// Fingerbilder: two hands of five, raised fingers filled.
  void _fingers(Canvas c, Rect r) {
    final (a, b, kind) = _setup;
    final shown = kind == 'sub' ? a : (kind == 'missing' && !reveal ? a : a + b);
    final w = r.width / 12;
    final h = math.min(r.height * 0.55, w * 3);
    final y = r.top + 10;
    for (var i = 0; i < 10; i++) {
      final hand = i ~/ 5;
      final x = r.left + w * (1 + i + hand * 1.0);
      final up = i < shown;
      final folded = kind == 'sub' && i >= a - b && i < a;
      final color = !up
          ? _ink.withValues(alpha: 0.12)
          : folded
          ? _ink.withValues(alpha: 0.25)
          : i < a
          ? const Color(0xFFF2B8A0)
          : const Color(0xFF9CC9F5);
      final len = up && !folded ? h : h * 0.35;
      c.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(x, y + h - len, w * 0.8, len),
          Radius.circular(w * 0.4),
        ),
        Paint()..color = color,
      );
    }
    if (reveal) {
      _text(c, q.format().replaceFirst('?', '${q.answer}'),
          Offset(r.center.dx, y + h + 28));
    }
  }

  /// Plustafel / Maltafel: row a, column b; the cell shows the result only
  /// after the answer.
  void _table(Canvas c, Rect r) {
    final from = aid == Aid.timesTable ? 1 : 0;
    final n = 11 - from;
    final cell = math.min(r.width, r.height) / (n + 1);
    final left = r.center.dx - cell * (n + 1) / 2;
    final top = r.top;
    for (var i = 0; i < n; i++) {
      _text(c, '${i + from}', Offset(left + cell * (i + 1.5), top + cell / 2), size: cell * 0.45);
      _text(c, '${i + from}', Offset(left + cell / 2, top + cell * (i + 1.5)), size: cell * 0.45);
    }
    final ra = q.a - from, cb = q.b - from;
    if (ra < 0 || cb < 0 || ra >= n || cb >= n) return;
    final hl = Paint()..color = const Color(0x55FFD36B);
    c.drawRect(Rect.fromLTWH(left + cell, top + cell * (ra + 1), cell * n, cell), hl);
    c.drawRect(Rect.fromLTWH(left + cell * (cb + 1), top + cell, cell, cell * n), hl);
    final target = Rect.fromLTWH(left + cell * (cb + 1), top + cell * (ra + 1), cell, cell);
    c.drawRect(target, Paint()..color = const Color(0xFFFFD36B));
    _text(c, reveal ? '${q.result}' : '?', target.center, size: cell * 0.45);
  }

  @override
  bool shouldRepaint(_AidPainter old) =>
      old.aid != aid || old.q != q || old.reveal != reveal;
}
