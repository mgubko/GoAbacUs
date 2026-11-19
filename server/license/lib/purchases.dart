import 'package:googleapis/androidpublisher/v3.dart' as ap;

/// Checks a store purchase and tells until when it is paid.
abstract class PurchaseVerifier {
  /// The paid-up time of the subscription, or null if it is not active.
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
    const active = {
      'SUBSCRIPTION_STATE_ACTIVE',
      'SUBSCRIPTION_STATE_IN_GRACE_PERIOD',
      'SUBSCRIPTION_STATE_CANCELED', // cancelled but paid to the end
    };
    if (!active.contains(s.subscriptionState)) return null;
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
