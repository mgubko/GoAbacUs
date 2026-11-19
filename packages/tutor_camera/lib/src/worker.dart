import 'dart:async';
import 'dart:isolate';

import 'lab.dart';

/// Runs [DeskLab] in its own isolate so the camera preview never stutters.
class DeskWorker {
  DeskWorker._(this._isolate, this._send, this._results);

  final Isolate _isolate;

  final SendPort _send;
  final Stream<DeskView> _results;

  Stream<DeskView> get results => _results;

  static Future<DeskWorker> start() async {
    final rp = ReceivePort();
    final iso = await Isolate.spawn(_main, rp.sendPort);
    final stream = rp.asBroadcastStream();
    final send = await stream.first as SendPort;
    return DeskWorker._(iso, send, stream.where((m) => m is DeskView).cast<DeskView>());
  }

  void stop() => _isolate.kill(priority: Isolate.immediate);

  void frame(FrameData f) => _send.send(f);
  void learnEmpty() => _send.send('learnEmpty');
  void showRaw(bool on) => _send.send(on ? 'raw:on' : 'raw:off');

  static void _main(SendPort out) {
    final inbox = ReceivePort();
    out.send(inbox.sendPort);
    final lab = DeskLab();
    inbox.listen((m) {
      if (m == 'learnEmpty') {
        lab.learnEmpty();
      } else if (m == 'raw:on' || m == 'raw:off') {
        lab.wantRaw = m == 'raw:on';
      } else if (m is FrameData) {
        try {
          out.send(lab.process(m));
        } catch (e) {
          out.send(DeskView(status: 'Ошибка: $e'));
        }
      }
    });
  }
}
