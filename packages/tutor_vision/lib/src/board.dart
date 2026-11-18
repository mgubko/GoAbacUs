import 'dart:math' as math;
import 'dart:typed_data';

import 'aruco.dart';
import 'homography.dart';
import 'image.dart';
import 'layout.dart';

/// What the user should do so that the sheet is seen well.
enum BoardHint {
  ok,
  noSheet,
  /// Part of the sheet is outside the picture on this side.
  cutLeft,
  cutRight,
  cutTop,
  cutBottom,

  /// The sheet is too small in the picture.
  closer,

  /// A corner marker is inside the picture but hidden (hand, glare).
  covered,
}

/// The sheet found in one frame: which sheet, where (sheet mm → image px),
/// how well, and the colour reference measured on its strip.
class BoardPose {
  BoardPose({
    required this.sheet,
    required this.toImage,
    required this.markers,
    required this.reprojectionPx,
    required this.mirrored,
    required this.hint,
    required this.pxPerMm,
  });

  final SheetLayout sheet;

  /// Sheet mm → image pixels.
  final Homography toImage;
  final List<Marker> markers;

  /// RMS distance between detected and predicted marker corners.
  final double reprojectionPx;

  /// The camera sees the sheet mirror-imaged (from behind, or via a mirror).
  final bool mirrored;
  final BoardHint hint;

  /// Image pixels per sheet mm at the field centre.
  final double pxPerMm;

  late final Homography toSheet = toImage.inverse();

  Set<int> get cornerIds => {for (final m in markers) if (m.id <= 3) m.id};
}

/// Finds a GoAbacUs sheet in a frame and normalises it.
class BoardLocator {
  BoardLocator({ArucoDetector? detector, this.defaultSheet = SheetLayout.calibration})
      : detector = detector ??
            ArucoDetector(allowedIds: {0, 1, 2, 3, for (final s in SheetLayout.all) s.id});

  final ArucoDetector detector;

  /// Used when the sheet-id marker is hidden.
  SheetLayout defaultSheet;

  SheetLayout? _lastSheet;

  BoardPose? locate(ColorSource frame) {
    final markers = detector.detect(frame.luma);
    SheetLayout? sheet;
    for (final m in markers) {
      final s = SheetLayout.byId(m.id);
      if (s != null) sheet = s;
    }
    sheet ??= _lastSheet ?? defaultSheet;
    _lastSheet = sheet;
    final used = [for (final m in markers) if (sheet.markers.containsKey(m.id)) m];
    if (used.length < 2) return null;
    final src = <Pt>[], dst = <Pt>[];
    for (final m in used) {
      src.addAll(sheet.markerCorners(m.id));
      dst.addAll(m.corners);
    }
    final hm = Homography.fit(src, dst);
    if (hm == null) return null;
    var se = 0.0;
    for (var i = 0; i < src.length; i++) {
      final p = hm.map(src[i]);
      se += p.dist(dst[i]) * p.dist(dst[i]);
    }
    final rms = math.sqrt(se / src.length);
    final c = Pt(sheet.field.x + sheet.field.w / 2, sheet.field.y + sheet.field.h / 2);
    final pxPerMm = hm.map(c).dist(hm.map(Pt(c.x + 1, c.y)));
    // Sheet y is up and image y is down, so a direct view flips orientation.
    final mirrored = hm.orientationAt(c) > 0;
    return BoardPose(
      sheet: sheet,
      toImage: hm,
      markers: used,
      reprojectionPx: rms,
      mirrored: mirrored,
      hint: _hint(sheet, used, hm, frame, pxPerMm),
      pxPerMm: pxPerMm,
    );
  }

  BoardHint _hint(SheetLayout sheet, List<Marker> found, Homography hm, ColorSource f, double pxPerMm) {
    final ids = {for (final m in found) m.id};
    if (pxPerMm < 1.6) return BoardHint.closer;
    // Where the missing corners would be in the picture.
    final missing = [for (var id = 0; id <= 3; id++) if (!ids.contains(id)) id];
    if (missing.isEmpty) return BoardHint.ok;
    if (missing.length == 4) return BoardHint.noSheet;
    var mx = 0.0, my = 0.0;
    for (final id in missing) {
      final corners = sheet.markerCorners(id);
      final p = hm.map(Pt((corners[0].x + corners[2].x) / 2, (corners[0].y + corners[2].y) / 2));
      mx += p.x;
      my += p.y;
    }
    mx /= missing.length;
    my /= missing.length;
    final dx = mx - f.width / 2, dy = my - f.height / 2;
    final outside = mx < 0 || my < 0 || mx > f.width || my > f.height;
    if (!outside) return BoardHint.covered;
    if (dx.abs() / f.width > dy.abs() / f.height) {
      return dx > 0 ? BoardHint.cutRight : BoardHint.cutLeft;
    }
    return dy > 0 ? BoardHint.cutBottom : BoardHint.cutTop;
  }

  /// Raster of [rect] (sheet mm) at [scale] px/mm, as the child sees it.
  static PlaneImage warp(ColorSource frame, BoardPose pose, MmRect rect, {double scale = 2}) {
    final w = (rect.w * scale).round(), h = (rect.h * scale).round();
    final out = PlaneImage(w, h, scale, rect.x, rect.top);
    final hm = pose.toImage.h;
    for (var v = 0; v < h; v++) {
      final ym = out.yMm(v);
      for (var u = 0; u < w; u++) {
        final xm = out.xMm(u);
        final iw = hm[6] * xm + hm[7] * ym + hm[8];
        final ix = (hm[0] * xm + hm[1] * ym + hm[2]) / iw;
        final iy = (hm[3] * xm + hm[4] * ym + hm[5]) / iw;
        frame.sampleRgb(ix, iy, out.rgb, (v * w + u) * 3);
      }
    }
    return out;
  }

  /// Mean colour of each strip patch (white, grey, rods 1-10), inset 1.5 mm.
  static List<Rgb> measurePatches(ColorSource frame, BoardPose pose) {
    final buf = Float32List(3);
    return [
      for (final p in pose.sheet.patches)
        () {
          var r = 0.0, g = 0.0, b = 0.0, n = 0;
          for (var i = 0; i < 5; i++) {
            for (var j = 0; j < 5; j++) {
              final q = pose.toImage.map(Pt(p.x + 1.5 + (p.w - 3) * i / 4, p.y + 1.5 + (p.h - 3) * j / 4));
              frame.sampleRgb(q.x, q.y, buf, 0);
              r += buf[0];
              g += buf[1];
              b += buf[2];
              n++;
            }
          }
          return Rgb(r / n, g / n, b / n);
        }(),
    ];
  }
}

/// A colour with float channels 0..255.
class Rgb {
  const Rgb(this.r, this.g, this.b);
  final double r, g, b;
  double get lum => 0.299 * r + 0.587 * g + 0.114 * b;
  @override
  String toString() => 'Rgb(${r.round()}, ${g.round()}, ${b.round()})';
}

/// White balance and colour references from the printed strip.
class ColorCalibration {
  ColorCalibration(this.gains, this.references);

  /// Per-channel gains that map the strip's white to 235.
  final Rgb gains;

  /// Corrected colours of white, grey and rods 1-10.
  final List<Rgb> references;

  factory ColorCalibration.fromPatches(List<Rgb> p) {
    final w = p[0];
    final gains = Rgb(235 / math.max(w.r, 20), 235 / math.max(w.g, 20), 235 / math.max(w.b, 20));
    return ColorCalibration(gains, [for (final c in p) Rgb(c.r * gains.r, c.g * gains.g, c.b * gains.b)]);
  }

  /// No strip seen: the nominal printed colours.
  factory ColorCalibration.nominal() => ColorCalibration(const Rgb(1, 1, 1), nominalColors);

  static const nominalColors = [
    Rgb(255, 255, 255), Rgb(154, 154, 154), Rgb(242, 230, 207), Rgb(228, 26, 28), Rgb(143, 209, 106),
    Rgb(166, 76, 166), Rgb(255, 217, 47), Rgb(27, 120, 55), Rgb(17, 17, 17), Rgb(140, 81, 10),
    Rgb(33, 102, 172), Rgb(255, 127, 0),
  ];

  /// Applies the gains to a plane raster in place.
  void correct(PlaneImage img) {
    final px = img.rgb;
    for (var i = 0; i < px.length; i += 3) {
      px[i] = px[i] * gains.r;
      px[i + 1] = px[i + 1] * gains.g;
      px[i + 2] = px[i + 2] * gains.b;
    }
  }
}
