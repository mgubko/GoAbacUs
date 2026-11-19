/// Handing codes between the two apps on ONE phone: the parent scans the
/// page and gives the phone to the child. The same codes as in the QR
/// codes travel in an app link instead (no network, no camera):
/// `goabacus-tutor://open?p=PAIRING&c=PACKET` and
/// `goabacus-scan://open?r=REPORT`.
///
/// The task packet and the report stay signed with the family key, so a
/// link from anywhere else is refused just like a foreign QR code.
library;

const tutorScheme = 'goabacus-tutor';
const scanScheme = 'goabacus-scan';

class Handoff {
  const Handoff({this.pairing, this.packet, this.report});

  /// `GAP1.` code: pairs the tutor on this phone if it is not paired yet.
  final String? pairing;

  /// `GA1.` code.
  final String? packet;

  /// `GR1.` code.
  final String? report;

  Uri toTutor() => Uri(
    scheme: tutorScheme,
    host: 'open',
    queryParameters: {'p': ?pairing, 'c': ?packet},
  );

  Uri toScan() => Uri(
    scheme: scanScheme,
    host: 'open',
    queryParameters: {'r': ?report},
  );

  /// Null when [uri] is not one of our links.
  static Handoff? parse(Uri uri) {
    if (uri.scheme != tutorScheme && uri.scheme != scanScheme) return null;
    final q = uri.queryParameters;
    String? take(String k, String prefix) {
      final v = q[k];
      return v != null && v.startsWith(prefix) ? v : null;
    }

    final h = Handoff(
      pairing: take('p', 'GAP1.'),
      packet: take('c', 'GA1.'),
      report: take('r', 'GR1.'),
    );
    return h.pairing == null && h.packet == null && h.report == null
        ? null
        : h;
  }
}
