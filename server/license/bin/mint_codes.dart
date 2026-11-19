/// Mints activation codes for kit boxes.
///
///   dart run bin/mint_codes.dart 500 --days 90 --store file:codes.json > batch.csv
///   dart run bin/mint_codes.dart 500 --store firestore:PROJECT > batch.csv
///
/// Prints CSV: code as printed, and the link for the QR code in the box
/// (opens GoAbacUs Scan with the code filled in).
library;

import 'dart:io';
import 'dart:math';

import 'package:goabacus_license/service.dart';
import 'package:goabacus_license/store.dart';
import 'package:googleapis/firestore/v1.dart' as fs;
import 'package:googleapis_auth/auth_io.dart';

Future<void> main(List<String> args) async {
  if (args.isEmpty) {
    stderr.writeln(
      'usage: mint_codes.dart N [--days 90] [--store file:x|firestore:p]',
    );
    exit(64);
  }
  final n = int.parse(args.first);
  String? opt(String name) {
    final i = args.indexOf(name);
    return i >= 0 && i + 1 < args.length ? args[i + 1] : null;
  }

  final days = int.parse(opt('--days') ?? '90');
  final spec = opt('--store') ?? 'file:codes.json';
  final Store store;
  AutoRefreshingAuthClient? client;
  if (spec.startsWith('firestore:')) {
    client = await clientViaApplicationDefaultCredentials(
      scopes: [fs.FirestoreApi.datastoreScope],
    );
    store = FirestoreStore(fs.FirestoreApi(client), spec.substring(10));
  } else {
    store = FileStore(spec.substring(5));
  }
  final r = Random.secure();
  print('code,link');
  var made = 0;
  while (made < n) {
    final c = newCode(r.nextInt);
    if (await store.code(c) != null) continue;
    await store.putCode(CodeRecord(code: c, days: days));
    print('${showCode(c)},goabacus-scan://activate?code=$c');
    made++;
  }
  client?.close();
}
