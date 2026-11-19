import 'package:shelf/shelf.dart';

/// Per-client request limit (sliding minute) and a body size cap: guessing
/// kit codes or flooding the server costs the attacker, not us. In memory,
/// per instance: enough at this size; Cloud Armor can take over later.
Middleware limits({
  int perMinute = 30,
  int maxBody = 16 * 1024,
  DateTime Function()? clock,
}) {
  final now = clock ?? DateTime.now;
  final seen = <String, List<DateTime>>{};
  return (inner) => (request) async {
    final len = request.contentLength;
    if (len != null && len > maxBody) {
      return Response(413, body: '{"error":"too big"}');
    }
    // Cloud Run puts the client first in X-Forwarded-For.
    final client =
        request.headers['x-forwarded-for']?.split(',').first.trim() ?? 'local';
    final t = now();
    final list = seen.putIfAbsent(client, () => [])
      ..removeWhere((x) => t.difference(x).inSeconds >= 60)
      ..add(t);
    if (seen.length > 10000) seen.removeWhere((_, v) => v.isEmpty);
    if (list.length > perMinute) {
      return Response(
        429,
        body: '{"error":"slow down"}',
        headers: {'retry-after': '60'},
      );
    }
    return inner(request);
  };
}
