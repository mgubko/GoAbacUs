import 'package:googleapis/androidpublisher/v3.dart' as ap;

/// Checks a store purchase and tells until when it is paid.
abstract class PurchaseVerifier {
  /// The time the subscription is paid up to, as the store says now (in
  /// the past after a refund or when it lapsed); null for a purchase the
  /// store does not know or that is not paid yet.
  Future<DateTime?> paidUntil(String product, String token);
}

/// Google Play: purchases.subscriptionsv2.get, and acknowledges the
/// purchase (Play refunds a subscription not acknowledged within 3 days).
class PlayVerifier implements PurchaseVerifier {
  PlayVerifier(this.api, this.packageName);
  final ap.AndroidPublisherApi api;
  final String packageName;

  @override
  Future<DateTime?> paidUntil(String product, String token) async {
    final s = await api.purchases.subscriptionsv2.get(packageName, token);
    if (s.subscriptionState == 'SUBSCRIPTION_STATE_PENDING' ||
        s.subscriptionState == 'SUBSCRIPTION_STATE_UNSPECIFIED') {
      return null;
    }
    DateTime? until;
    for (final i in s.lineItems ?? const <ap.SubscriptionPurchaseLineItem>[]) {
      final e = i.expiryTime == null ? null : DateTime.parse(i.expiryTime!);
      if (e != null && (until == null || e.isAfter(until))) until = e;
    }
    if (s.acknowledgementState == 'ACKNOWLEDGEMENT_STATE_PENDING') {
      await api.purchases.subscriptions.acknowledge(
        ap.SubscriptionPurchasesAcknowledgeRequest(),
        packageName,
        product,
        token,
      );
    }
    return until;
  }
}
