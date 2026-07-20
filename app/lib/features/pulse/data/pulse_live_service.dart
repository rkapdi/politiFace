// lib/features/pulse/data/pulse_live_service.dart
//
// The live layer over the bundled feed. Two sources, both optional:
//
//   1. Federal Register (keyless, public): executive orders signed in the
//      last ~60 days, fetched straight from the device. No API key, no
//      user data in the request.
//   2. The `pulse` Edge Function (when a backend is configured): fresh
//      congress.gov bills and laws, proxied server-side because the
//      congress.gov key cannot ship inside a public client.
//
// Both fail soft: offline or unconfigured, the feed falls back to the
// bundled content and says so.

import 'dart:convert';
import 'dart:io';

import '../../../core/sync/supabase_config.dart';

class LiveOrder {
  const LiveOrder({
    required this.number,
    required this.title,
    required this.president,
    required this.signingDate,
    required this.url,
  });

  final int number;
  final String title;
  final String president;
  final String signingDate;
  final String url;
}

class LiveBillAction {
  const LiveBillAction({
    required this.bill,
    required this.title,
    required this.actionDate,
    required this.action,
    required this.url,
    this.congress,
  });

  final String bill;
  final String title;
  final String actionDate;
  final String action;
  final String url;
  final int? congress;
}

/// A CRS bill summary served by the `pulse` Edge Function.
class LiveBillSummary {
  const LiveBillSummary({
    required this.text,
    required this.version,
    required this.date,
    required this.truncated,
  });

  final String text;
  final String version; // e.g. "Introduced in House"
  final String date; // ISO yyyy-mm-dd
  final bool truncated;
}

class LivePulse {
  const LivePulse({required this.orders, required this.bills});

  final List<LiveOrder> orders;
  final List<LiveBillAction> bills;

  bool get isEmpty => orders.isEmpty && bills.isEmpty;
}

class PulseLiveService {
  PulseLiveService({HttpClient? client}) : _client = client ?? HttpClient();

  final HttpClient _client;

  static const _userAgent = 'politiface-app (rkapdi4@gmail.com)';

  Future<dynamic> _getJson(Uri uri, {Map<String, String>? headers}) async {
    final request = await _client.getUrl(uri)
      ..headers.set(HttpHeaders.userAgentHeader, _userAgent);
    headers?.forEach(request.headers.set);
    final response = await request.close().timeout(const Duration(seconds: 12));
    if (response.statusCode != 200) {
      throw HttpException('HTTP ${response.statusCode}', uri: uri);
    }
    return json.decode(await response.transform(utf8.decoder).join());
  }

  /// Executive orders signed since [since], newest first. Keyless.
  Future<List<LiveOrder>> fetchRecentOrders({DateTime? since}) async {
    final gte = (since ?? DateTime.now().subtract(const Duration(days: 60)))
        .toIso8601String()
        .substring(0, 10);
    final uri = Uri.parse(
      'https://www.federalregister.gov/api/v1/documents.json'
      '?conditions%5Btype%5D%5B%5D=PRESDOCU'
      '&conditions%5Bpresidential_document_type%5D%5B%5D=executive_order'
      '&conditions%5Bsigning_date%5D%5Bgte%5D=$gte'
      '&per_page=40&order=newest'
      '&fields%5B%5D=executive_order_number&fields%5B%5D=title'
      '&fields%5B%5D=signing_date&fields%5B%5D=president'
      '&fields%5B%5D=html_url',
    );
    final data = await _getJson(uri) as Map<String, dynamic>;
    return [
      for (final r in data['results'] as List? ?? const [])
        if (r['executive_order_number'] != null)
          LiveOrder(
            number: int.parse(r['executive_order_number'].toString()),
            title: (r['title'] as String? ?? '').trim(),
            president: ((r['president'] as Map?)?['name'] as String?) ?? '',
            signingDate: r['signing_date'] as String? ?? '',
            url: r['html_url'] as String? ?? '',
          ),
    ];
  }

  /// Fresh bill actions via the backend proxy. Returns empty when no
  /// backend is configured.
  Future<List<LiveBillAction>> fetchRecentBills() async {
    if (!SupabaseConfig.isConfigured) return const [];
    final uri = Uri.parse('${SupabaseConfig.url}/functions/v1/pulse');
    final data = await _getJson(
      uri,
      headers: {
        'apikey': SupabaseConfig.anonKey,
        'authorization': 'Bearer ${SupabaseConfig.anonKey}',
      },
    ) as Map<String, dynamic>;
    return [
      for (final b in data['bills'] as List? ?? const [])
        LiveBillAction(
          bill: b['bill'] as String? ?? '',
          title: (b['title'] as String? ?? '').trim(),
          actionDate: b['action_date'] as String? ?? '',
          action: (b['action'] as String? ?? '').trim(),
          url: b['url'] as String? ?? '',
          congress: b['congress'] as int?,
        ),
    ];
  }

  /// One bill's CRS summary via the backend proxy. Returns null when no
  /// backend is configured or congress.gov has no summary yet.
  Future<LiveBillSummary?> fetchBillSummary({
    required int congress,
    required String type,
    required String number,
  }) async {
    if (!SupabaseConfig.isConfigured) return null;
    final uri = Uri.parse(
      '${SupabaseConfig.url}/functions/v1/pulse'
      '?bill=$congress/${type.toLowerCase()}/$number',
    );
    final data = await _getJson(
      uri,
      headers: {
        'apikey': SupabaseConfig.anonKey,
        'authorization': 'Bearer ${SupabaseConfig.anonKey}',
      },
    ) as Map<String, dynamic>;
    final summary = data['summary'];
    if (summary is! Map) return null;
    final text = (summary['text'] as String? ?? '').trim();
    if (text.isEmpty) return null;
    return LiveBillSummary(
      text: text,
      version: summary['version'] as String? ?? '',
      date: summary['date'] as String? ?? '',
      truncated: summary['truncated'] == true,
    );
  }

  /// Everything live that is reachable right now. Sources fail
  /// independently: EOs can be live while bills ride the bundle.
  Future<LivePulse> fetch() async {
    var orders = const <LiveOrder>[];
    var bills = const <LiveBillAction>[];
    try {
      orders = await fetchRecentOrders();
    } catch (_) {/* offline or blocked: bundled EOs cover it */}
    try {
      bills = await fetchRecentBills();
    } catch (_) {/* no backend yet or offline */}
    return LivePulse(orders: orders, bills: bills);
  }
}
