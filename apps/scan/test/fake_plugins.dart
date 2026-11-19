import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// The test machine has no sensors, sound, app links or store: every
/// plugin call simply succeeds and returns nothing. (Left on until the
/// test file ends: widgets still cancel their streams after the test.)
void fakePlugins(WidgetTester t) {
  final m = t.binding.defaultBinaryMessenger;
  m.allMessagesHandler = (channel, handler, message) {
    if (handler != null) return handler(message);
    if (channel.startsWith('flutter/')) return null;
    return Future.value(
      const StandardMethodCodec().encodeSuccessEnvelope(null),
    );
  };
}
