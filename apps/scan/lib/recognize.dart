import 'dart:ui' as ui;

import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image_picker/image_picker.dart';
import 'package:tutor_tasks/tutor_tasks.dart';

/// Reads a homework photo on the phone: ML Kit text recognition (Latin
/// script, bundled model, no network) and the rule parser from
/// `tutor_tasks`. Nothing leaves the phone.
Future<ParsedPage> recognizePage(XFile file) async {
  final recognizer = TextRecognizer(script: TextRecognitionScript.latin);
  try {
    final text = await recognizer.processImage(InputImage.fromFilePath(file.path));
    final boxes = <OcrBox>[
      for (final block in text.blocks)
        for (final line in block.lines)
          OcrBox(
            line.text,
            line.boundingBox.left,
            line.boundingBox.top,
            line.boundingBox.right,
            line.boundingBox.bottom,
          ),
    ];
    var (w, h) = await _imageSize(file);
    // ML Kit reports boxes in the upright image; the file may be stored
    // turned (EXIF), so swap the sides when the boxes say so.
    final maxX = boxes.fold<double>(0, (m, b) => b.x1 > m ? b.x1 : m);
    final maxY = boxes.fold<double>(0, (m, b) => b.y1 > m ? b.y1 : m);
    if (maxX > w * 1.02 || maxY > h * 1.02) (w, h) = (h, w);
    return parsePage(boxes, w, h);
  } finally {
    await recognizer.close();
  }
}

Future<(double, double)> _imageSize(XFile file) async {
  final bytes = await file.readAsBytes();
  final buffer = await ui.ImmutableBuffer.fromUint8List(bytes);
  final descriptor = await ui.ImageDescriptor.encoded(buffer);
  final size = (descriptor.width.toDouble(), descriptor.height.toDouble());
  descriptor.dispose();
  buffer.dispose();
  return size;
}
