import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:tutor_tasks/tutor_tasks.dart';

import 'license.dart';
import 'qr.dart';
import 'strings.dart';

/// The subscription: what is paid until when, the code from the kit box,
/// and the store subscription.
class SubscriptionScreen extends StatefulWidget {
  const SubscriptionScreen({super.key, required this.licensing, this.code});
  final Licensing licensing;

  /// A code that came with the kit's QR link.
  final String? code;

  @override
  State<SubscriptionScreen> createState() => _SubscriptionScreenState();
}

class _SubscriptionScreenState extends State<SubscriptionScreen> {
  late final _code = TextEditingController(text: widget.code ?? '');
  Licensing get l => widget.licensing;

  @override
  void initState() {
    super.initState();
    l.addListener(_changed);
    l.loadProducts();
    if (widget.code != null) WidgetsBinding.instance.addPostFrameCallback((_) => _redeem());
  }

  @override
  void dispose() {
    l.removeListener(_changed);
    _code.dispose();
    super.dispose();
  }

  void _changed() => setState(() {});

  Future<void> _redeem() async {
    if (_code.text.trim().isEmpty) return;
    if (await l.redeem(_code.text) && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(tr('code_ok'))),
      );
    }
  }

  Future<void> _scan() async {
    final c = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (_) => QrScanPage(
          title: tr('kit_code'),
          hint: tr('kit_code_hint'),
          accept: (c) => _codeFrom(c) == null ? tr('not_ours') : null,
        ),
      ),
    );
    if (c == null) return;
    _code.text = _codeFrom(c)!;
    await _redeem();
  }

  /// The QR code in the box is a link; a plain code works too.
  static String? _codeFrom(String text) {
    final uri = Uri.tryParse(text);
    final fromLink = uri == null ? null : Handoff.parse(uri)?.activation;
    if (fromLink != null) return fromLink;
    return RegExp(r'^[A-Za-z0-9-]{8,24}$').hasMatch(text.trim())
        ? text.trim()
        : null;
  }

  @override
  Widget build(BuildContext context) {
    final lic = l.license;
    final now = DateTime.now();
    final left = lic?.daysLeft(now) ?? 0;
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(tr('subscription'))),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            color: lic != null && left > 0
                ? const Color(0xFFDDEFD0)
                : const Color(0xFFFFF4D6),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                lic == null
                    ? tr('sub_none')
                    : left > 0
                    ? tr('sub_until', {
                        'date': _date(lic.until),
                        'n': left,
                        'plan': tr('plan_${lic.plan.name}'),
                      })
                    : tr('sub_ended', {'date': _date(lic.until)}),
                style: theme.textTheme.titleMedium,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(tr('sub_why'), style: theme.textTheme.bodySmall),
          const SizedBox(height: 24),
          Text(tr('kit_code'), style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          TextField(
            controller: _code,
            textCapitalization: TextCapitalization.characters,
            decoration: InputDecoration(
              hintText: 'GA7K-3MQ9-X2PD',
              border: const OutlineInputBorder(),
              suffixIcon: IconButton(
                tooltip: tr('scan_code'),
                icon: const Icon(Icons.qr_code_scanner),
                onPressed: l.busy ? null : _scan,
              ),
            ),
            onSubmitted: (_) => _redeem(),
          ),
          const SizedBox(height: 8),
          FilledButton(
            onPressed: l.busy ? null : _redeem,
            child: Text(tr('activate')),
          ),
          if (l.error != null) ...[
            const SizedBox(height: 8),
            Text(
              tr('lerr_${l.error}'),
              style: TextStyle(color: theme.colorScheme.error),
            ),
          ],
          const SizedBox(height: 24),
          Text(tr('store_sub'), style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          if (l.products.isEmpty)
            Text(tr('store_unavailable'), style: theme.textTheme.bodySmall),
          for (final p in l.products)
            Card(
              child: ListTile(
                title: Text(p.title.replaceAll(RegExp(r'\s*\(.*\)$'), '')),
                subtitle: Text(p.description),
                trailing: FilledButton.tonal(
                  onPressed: l.busy ? null : () => l.buy(p),
                  child: Text(p.price),
                ),
              ),
            ),
          TextButton(
            onPressed: l.busy ? null : l.restore,
            child: Text(tr('restore')),
          ),
          if (l.busy) const LinearProgressIndicator(),
          if (kDebugMode) ...[
            const Divider(height: 32),
            OutlinedButton(
              onPressed: l.devLicense,
              child: const Text('DEBUG: test licence for 90 days (dev key)'),
            ),
          ],
        ],
      ),
    );
  }

  static String _date(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}.${d.year}';
}
