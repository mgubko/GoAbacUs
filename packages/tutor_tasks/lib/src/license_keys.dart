/// Which licence signatures the apps trust.
library;

import 'dart:convert';

/// The DEVELOPMENT signing seed. It is public (it is in this repository),
/// so only debug builds and tests trust its key: anybody can sign with it.
/// The dev licence server (`server/license` without `LICENSE_SEED`) uses it.
const devLicenseSeed = 'LxcNxuLBKQfM5y6NDvn8MQVe1le99btt5iu4TEHaVD0';
const devLicenseKey = 'Ry75dOHyMi8CtFSTpEKPFKwIYDYygjswakY03U_PuNg';

/// The production public keys (base64url, 32 bytes). The seed stays only on
/// the licence server: `dart run bin/keygen.dart` in server/license makes
/// a pair. Keep old keys here for a while after rotating, so that licences
/// already out keep working.
const productionLicenseKeys = <String>[];

List<int> _key(String s) =>
    base64Url.decode(s.padRight((s.length + 3) ~/ 4 * 4, '='));

/// The keys an app trusts: production keys, plus the dev key in debug.
List<List<int>> trustedLicenseKeys({required bool debug}) => [
  for (final k in productionLicenseKeys) _key(k),
  if (debug) _key(devLicenseKey),
];

List<int> get devSeedBytes => _key(devLicenseSeed);
