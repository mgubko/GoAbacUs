/// Makes a production signing key pair. Put the SEED into the server's
/// secret (LICENSE_SEED, e.g. Secret Manager) and nowhere else; put the
/// PUBLIC key into productionLicenseKeys in
/// packages/tutor_tasks/lib/src/license_keys.dart.
library;

import 'dart:convert';
import 'dart:math';

import 'package:tutor_tasks/tutor_tasks.dart';

void main() {
  final r = Random.secure();
  final seed = List<int>.generate(32, (_) => r.nextInt(256));
  String b(List<int> x) => base64Url.encode(x).replaceAll('=', '');
  print('LICENSE_SEED (secret!): ${b(seed)}');
  print('public key:             ${b(License.publicKeyOf(seed))}');
}
