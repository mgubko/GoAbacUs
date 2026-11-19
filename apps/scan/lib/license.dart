import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:tutor_tasks/tutor_tasks.dart';

import 'store.dart';

/// The licence server, set at build time:
/// `flutter build apk --dart-define=LICENSE_SERVER=https://...`.
const licenseServer = String.fromEnvironment('LICENSE_SERVER');

/// The store subscriptions (set up the same ids in Play Console and App
/// Store Connect).
const subscriptionIds = {'goabacus_family_monthly', 'goabacus_family_yearly'};

class LicenseError implements Exception {
  const LicenseError(this.key);

  /// A key of the strings: code_unknown, code_used, not_paid, offline, ...
  final String key;
}

/// The family's subscription on the parent's phone: the licence the server
/// signed, kit codes, store purchases. Everything else in Scan works on
/// the phone; only this talks to the network.
class Licensing extends ChangeNotifier {
  Licensing(this.store) {
    _purchases = InAppPurchase.instance.purchaseStream.listen(
      _onPurchases,
      onError: (_) {},
    );
  }

  final FamilyStore store;
  StreamSubscription<List<PurchaseDetails>>? _purchases;
  bool busy = false;
  String? error;

  static final trusted = trustedLicenseKeys(debug: kDebugMode);

  String? get code => store.license;

  License? get license {
    final c = code;
    final l = c == null ? null : License.verify(c, trusted);
    return l != null && l.fits(store.key) ? l : null;
  }

  bool get active => license?.validOn(DateTime.now()) ?? false;

  Map<String, String> get _family => {
    'family': store.key.id,
    'keyHash': License.hashOf(store.key),
  };

  Future<void> _call(String path, Map<String, String> body) async {
    if (licenseServer.isEmpty) throw const LicenseError('no_server');
    final http.Response r;
    try {
      r = await http
          .post(
            Uri.parse('$licenseServer$path'),
            headers: {'content-type': 'application/json'},
            body: jsonEncode({..._family, ...body}),
          )
          .timeout(const Duration(seconds: 20));
    } catch (_) {
      throw const LicenseError('offline');
    }
    final j = jsonDecode(r.body) as Map<String, Object?>;
    if (r.statusCode != 200) {
      throw LicenseError(switch (j['error']) {
        'code' => 'code_unknown',
        'used' => 'code_used',
        'not paid' => 'not_paid',
        'family' => 'family_mismatch',
        'apple' || 'play' => 'store_not_ready',
        _ => 'server_error',
      });
    }
    final lic = j['license'] as String;
    if (License.verify(lic, trusted) == null) {
      throw const LicenseError('server_error');
    }
    await store.setLicense(lic);
  }

  Future<bool> _run(Future<void> Function() f) async {
    busy = true;
    error = null;
    notifyListeners();
    try {
      await f();
      return true;
    } on LicenseError catch (e) {
      error = e.key;
      return false;
    } finally {
      busy = false;
      notifyListeners();
    }
  }

  /// A kit code (typed, or from the QR code in the box).
  Future<bool> redeem(String code) =>
      _run(() => _call('/v1/redeem', {'code': code.trim()}));

  /// Gets the latest licence (a store renewal shows up here). Quiet: no
  /// error when offline.
  Future<void> refresh() async {
    if (licenseServer.isEmpty || store.license == null) return;
    try {
      await _call('/v1/refresh', {});
      notifyListeners();
    } on LicenseError catch (_) {}
  }

  /// Refresh when it runs out within a week, at most once a day.
  Future<void> refreshIfDue() async {
    final l = license;
    if (l == null || l.daysLeft(DateTime.now()) > 7) return;
    final last = store.lastRefresh;
    if (last != null && DateTime.now().difference(last).inHours < 20) return;
    await store.setLastRefresh(DateTime.now());
    await refresh();
  }

  /// Debug builds only: a 90-day licence signed with the public dev key,
  /// to try everything before the server is up.
  Future<void> devLicense() async {
    assert(kDebugMode);
    final now = DateTime.now().toUtc();
    await store.setLicense(
      License(
        family: store.key.id,
        keyHash: License.hashOf(store.key),
        until: now.add(const Duration(days: 89)),
        plan: Plan.gift,
        issued: now,
      ).sign(devSeedBytes),
    );
    notifyListeners();
  }

  // --- Store subscriptions ---------------------------------------------

  List<ProductDetails> products = [];

  Future<void> loadProducts() async {
    try {
      if (!await InAppPurchase.instance.isAvailable()) return;
      final r = await InAppPurchase.instance.queryProductDetails(
        subscriptionIds,
      );
      products = r.productDetails..sort((a, b) => a.rawPrice.compareTo(b.rawPrice));
      notifyListeners();
    } catch (_) {}
  }

  Future<void> buy(ProductDetails p) async {
    error = null;
    await InAppPurchase.instance.buyNonConsumable(
      purchaseParam: PurchaseParam(productDetails: p),
    );
  }

  Future<void> restore() => InAppPurchase.instance.restorePurchases();

  Future<void> _onPurchases(List<PurchaseDetails> list) async {
    for (final p in list) {
      if (p.status == PurchaseStatus.error) {
        error = 'store_error';
        notifyListeners();
      }
      if (p.status != PurchaseStatus.purchased &&
          p.status != PurchaseStatus.restored) {
        continue;
      }
      final path = defaultTargetPlatform == TargetPlatform.iOS
          ? '/v1/apple'
          : '/v1/play';
      final ok = await _run(
        () => _call(path, {
          'product': p.productID,
          'token': p.verificationData.serverVerificationData,
        }),
      );
      // Only once the server has it; otherwise the store delivers it again
      // on the next start.
      if (ok && p.pendingCompletePurchase) {
        await InAppPurchase.instance.completePurchase(p);
      }
    }
  }

  @override
  void dispose() {
    _purchases?.cancel();
    super.dispose();
  }
}
