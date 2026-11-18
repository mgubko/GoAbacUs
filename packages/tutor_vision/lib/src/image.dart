import 'dart:math' as math;
import 'dart:typed_data';

/// An 8-bit grey image, row-major, no padding.
class GrayImage {
  GrayImage(this.width, this.height, [Uint8List? data])
      : data = data ?? Uint8List(width * height);

  final int width;
  final int height;
  final Uint8List data;

  int at(int x, int y) => data[y * width + x];

  /// Bilinear sample; coordinates are clamped to the image.
  double sample(double x, double y) {
    if (x < 0) x = 0;
    if (y < 0) y = 0;
    if (x > width - 1) x = (width - 1).toDouble();
    if (y > height - 1) y = (height - 1).toDouble();
    final x0 = x.floor(), y0 = y.floor();
    final x1 = math.min(x0 + 1, width - 1), y1 = math.min(y0 + 1, height - 1);
    final fx = x - x0, fy = y - y0;
    final a = data[y0 * width + x0], b = data[y0 * width + x1];
    final c = data[y1 * width + x0], d = data[y1 * width + x1];
    return (a + (b - a) * fx) * (1 - fy) + (c + (d - c) * fx) * fy;
  }
}

/// A source of colour that the warp can sample at any image position.
/// Camera frames (YUV or BGRA) and decoded pictures both implement it, so the
/// full frame is never converted to RGB: only the plane raster is.
abstract class ColorSource {
  int get width;
  int get height;

  /// Writes the bilinear-sampled colour at (x, y) to out[o], out[o+1], out[o+2].
  void sampleRgb(double x, double y, Float32List out, int o);

  /// The luma image used for marker detection.
  GrayImage get luma;
}

/// Interleaved 8-bit RGB image.
class RgbImage implements ColorSource {
  RgbImage(this.width, this.height, [Uint8List? rgb])
      : rgb = rgb ?? Uint8List(width * height * 3);

  @override
  final int width;
  @override
  final int height;
  final Uint8List rgb;

  GrayImage? _luma;

  @override
  GrayImage get luma {
    final l = _luma;
    if (l != null) return l;
    final g = GrayImage(width, height);
    for (var i = 0, j = 0; i < g.data.length; i++, j += 3) {
      g.data[i] = (rgb[j] * 77 + rgb[j + 1] * 150 + rgb[j + 2] * 29) >> 8;
    }
    return _luma = g;
  }

  @override
  void sampleRgb(double x, double y, Float32List out, int o) {
    if (x < 0) x = 0;
    if (y < 0) y = 0;
    if (x > width - 1) x = (width - 1).toDouble();
    if (y > height - 1) y = (height - 1).toDouble();
    final x0 = x.floor(), y0 = y.floor();
    final x1 = math.min(x0 + 1, width - 1), y1 = math.min(y0 + 1, height - 1);
    final fx = x - x0, fy = y - y0;
    final i00 = (y0 * width + x0) * 3, i01 = (y0 * width + x1) * 3;
    final i10 = (y1 * width + x0) * 3, i11 = (y1 * width + x1) * 3;
    for (var c = 0; c < 3; c++) {
      final a = rgb[i00 + c], b = rgb[i01 + c], cc = rgb[i10 + c], d = rgb[i11 + c];
      out[o + c] = (a + (b - a) * fx) * (1 - fy) + (cc + (d - cc) * fx) * fy;
    }
  }
}

/// A camera frame in YUV 4:2:0 (Android `ImageFormat.YUV_420_888`): a full
/// size Y plane and quarter size U and V planes with their own strides.
class YuvFrame implements ColorSource {
  YuvFrame({
    required this.width,
    required this.height,
    required this.y,
    required this.yRowStride,
    required this.u,
    required this.v,
    required this.uvRowStride,
    required this.uvPixelStride,
  });

  @override
  final int width;
  @override
  final int height;
  final Uint8List y, u, v;
  final int yRowStride, uvRowStride, uvPixelStride;

  GrayImage? _luma;

  @override
  GrayImage get luma {
    final l = _luma;
    if (l != null) return l;
    final g = GrayImage(width, height);
    if (yRowStride == width) {
      g.data.setRange(0, width * height, y);
    } else {
      for (var r = 0; r < height; r++) {
        g.data.setRange(r * width, (r + 1) * width, y, r * yRowStride);
      }
    }
    return _luma = g;
  }

  @override
  void sampleRgb(double x, double yy, Float32List out, int o) {
    final lum = luma.sample(x, yy);
    final cx = (x / 2).round().clamp(0, (width >> 1) - 1);
    final cy = (yy / 2).round().clamp(0, (height >> 1) - 1);
    final i = cy * uvRowStride + cx * uvPixelStride;
    final cb = u[i] - 128.0, cr = v[i] - 128.0;
    out[o] = (lum + 1.402 * cr).clamp(0, 255);
    out[o + 1] = (lum - 0.344136 * cb - 0.714136 * cr).clamp(0, 255);
    out[o + 2] = (lum + 1.772 * cb).clamp(0, 255);
  }
}

/// A camera frame in BGRA 8888 (iOS).
class BgraFrame implements ColorSource {
  BgraFrame(this.width, this.height, this.bytes, this.rowStride);

  @override
  final int width;
  @override
  final int height;
  final Uint8List bytes;
  final int rowStride;

  GrayImage? _luma;

  @override
  GrayImage get luma {
    final l = _luma;
    if (l != null) return l;
    final g = GrayImage(width, height);
    for (var r = 0; r < height; r++) {
      var j = r * rowStride;
      for (var c = 0; c < width; c++, j += 4) {
        g.data[r * width + c] = (bytes[j + 2] * 77 + bytes[j + 1] * 150 + bytes[j] * 29) >> 8;
      }
    }
    return _luma = g;
  }

  @override
  void sampleRgb(double x, double y, Float32List out, int o) {
    final xi = x.round().clamp(0, width - 1), yi = y.round().clamp(0, height - 1);
    final j = yi * rowStride + xi * 4;
    out[o] = bytes[j + 2].toDouble();
    out[o + 1] = bytes[j + 1].toDouble();
    out[o + 2] = bytes[j].toDouble();
  }
}

/// A float RGB raster of the sheet plane ("as the child sees it"): pixel
/// (u, v) is sheet point (x0 + (u + 0.5) / scale, y1 - (v + 0.5) / scale) in mm.
class PlaneImage {
  PlaneImage(this.width, this.height, this.scale, this.x0, this.y1)
      : rgb = Float32List(width * height * 3);

  final int width, height;

  /// Pixels per mm.
  final double scale;
  final double x0, y1;
  final Float32List rgb;

  double xMm(num u) => x0 + (u + 0.5) / scale;
  double yMm(num v) => y1 - (v + 0.5) / scale;
  double uOf(double xMm) => (xMm - x0) * scale - 0.5;
  double vOf(double yMm) => (y1 - yMm) * scale - 0.5;

  double lum(int i) => (rgb[i * 3] * 0.299 + rgb[i * 3 + 1] * 0.587 + rgb[i * 3 + 2] * 0.114);

  Uint8List toRgb8() {
    final out = Uint8List(rgb.length);
    for (var i = 0; i < rgb.length; i++) {
      out[i] = rgb[i].round().clamp(0, 255);
    }
    return out;
  }
}
