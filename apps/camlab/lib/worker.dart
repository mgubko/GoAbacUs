import 'dart:async';
import 'dart:isolate';

import 'lab.dart';

/// Runs [Lab] in its own isolate so the camera preview never stutters.
class LabWorker {
  LabWorker._(this._send, this._results);

  final SendPort _send;
  final Stream<LabResult> _results;

  Stream<LabResult> get results => _results;

  static Future<LabWorker> start() async {
    final rp = ReceivePort();
    await Isolate.spawn(_main, rp.sendPort);
    final stream = rp.asBroadcastStream();
    final send = await stream.first as SendPort;
    return LabWorker._(send, stream.where((m) => m is LabResult).cast<LabResult>());
  }

  void frame(FrameData f) => _send.send(f);
  void learnEmpty() => _send.send('learnEmpty');

  static void _main(SendPort out) {
    final inbox = ReceivePort();
    out.send(inbox.sendPort);
    final lab = Lab();
    inbox.listen((m) {
      if (m == 'learnEmpty') {
        lab.learnEmpty();
      } else if (m is FrameData) {
        try {
          out.send(lab.process(m));
        } catch (e) {
          out.send(LabResult(status: 'Ошибка: $e'));
        }
      }
    });
  }
}
