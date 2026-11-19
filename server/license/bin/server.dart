/// Runs the licence server.
///
///   LICENSE_SEED   base64url signing seed (from bin/keygen.dart). Without
///                  it the server signs with the public DEV seed, which
///                  only debug builds of the apps trust.
///   STORE          firestore:PROJECT | file:PATH | memory (default)
///   PLAY_PACKAGE   com.goabacus.scan, to check Google Play purchases
///                  (credentials: the service account of Cloud Run, which
///                  needs access in Play Console > Users and permissions)
///   PORT           8080
library;

import 'dart:convert';
import 'dart:io';

import 'package:goabacus_license/limits.dart';
import 'package:goabacus_license/purchases.dart';
import 'package:goabacus_license/service.dart';
import 'package:goabacus_license/store.dart';
import 'package:googleapis/androidpublisher/v3.dart' as ap;
import 'package:googleapis/firestore/v1.dart' as fs;
import 'package:googleapis_auth/auth_io.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as io;
import 'package:tutor_tasks/tutor_tasks.dart';

Future<void> main() async {
  final env = Platform.environment;
  final seedText = env['LICENSE_SEED'];
  if (seedText == null) {
    stderr.writeln('LICENSE_SEED not set: signing with the DEV seed.');
  }
  final seed = seedText == null
      ? devSeedBytes
      : base64Url.decode(
          seedText.padRight((seedText.length + 3) ~/ 4 * 4, '='),
        );

  AutoRefreshingAuthClient? auth;
  Future<AutoRefreshingAuthClient> google() async =>
      auth ??= await clientViaApplicationDefaultCredentials(
        scopes: [
          fs.FirestoreApi.datastoreScope,
          ap.AndroidPublisherApi.androidpublisherScope,
        ],
      );

  final storeSpec = env['STORE'] ?? 'memory';
  final Store store;
  if (storeSpec.startsWith('firestore:')) {
    store = FirestoreStore(
      fs.FirestoreApi(await google()),
      storeSpec.substring(10),
    );
  } else if (storeSpec.startsWith('file:')) {
    store = FileStore(storeSpec.substring(5));
  } else {
    store = MemoryStore();
  }
  final package = env['PLAY_PACKAGE'];
  final service = LicenseService(
    store: store,
    seed: seed,
    play: package == null
        ? null
        : PlayVerifier(ap.AndroidPublisherApi(await google()), package),
  );
  final handler = const Pipeline()
      .addMiddleware(logRequests())
      .addMiddleware(limits())
      .addHandler(service.router.call);
  final port = int.parse(env['PORT'] ?? '8080');
  await io.serve(handler, InternetAddress.anyIPv4, port);
  stderr.writeln('licence server on :$port, store $storeSpec');
}
