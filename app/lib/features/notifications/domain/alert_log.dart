// lib/features/notifications/domain/alert_log.dart
//
// The record of Washington notifications this device delivered, shared by
// the writer (NotificationOrchestrator) and the reader (The Pulse).
//
// Each entry is self-contained: it stores the title, date, kind and link
// of every item the notification covered, captured at send time. The Pulse
// renders an alert from this record alone, so a digest of nine updates
// always opens to those nine, however much the live feed has moved on and
// however many later actions the same bill has had since.

import 'dart:convert';

import 'package:flutter/foundation.dart';

/// AppMeta key holding the JSON list of [AlertLogEntry], newest first.
const kAlertLogKey = 'watch.alert_log';

/// Entries kept. The Pulse only shows the last 7 days of them.
const kAlertLogMaxEntries = 20;

/// Items stored per entry. Far above any real sweep (the feed itself is
/// 50 bills and 40 orders wide); a hard cap only so one row cannot grow
/// without bound.
const kAlertLogMaxItems = 120;

/// The route a Washington notification opens on tap: The Pulse, with the
/// alert it belongs to named so the screen can open it directly.
String pulseAlertRoute(String alertId) =>
    '/pulse?alert=${Uri.encodeQueryComponent(alertId)}';

/// One thing a notification covered: an executive order, a law, or a
/// single action on a bill. Everything needed to show it and to open its
/// official record, with no lookup against the live feed.
@immutable
class AlertItem {
  const AlertItem({
    required this.key,
    required this.kind,
    required this.title,
    required this.date,
    required this.url,
    this.bill,
    this.action,
    this.congress,
    this.number,
  });

  static const kindOrder = 'eo';
  static const kindLaw = 'law';
  static const kindBill = 'bill';

  /// Identity of this exact update: 'eo:14418', 'law:HR 100:2026-07-20',
  /// 'bill:HR 100:2026-07-20'. Two actions on one bill have two keys.
  final String key;

  /// [kindOrder], [kindLaw] or [kindBill].
  final String kind;

  /// Official title, verbatim.
  final String title;

  /// ISO date of the update (signing date, or action date).
  final String date;

  /// The official record (Federal Register or congress.gov).
  final String url;

  /// Bill and law items: the bill number, e.g. 'HR 8121'.
  final String? bill;

  /// Bill and law items: the congress.gov action text, verbatim.
  final String? action;

  /// Bill and law items: the congress number, when the feed carried it.
  final int? congress;

  /// Executive orders: the order number.
  final int? number;

  Map<String, Object?> toJson() => {
        'k': key,
        'c': kind,
        't': title,
        'd': date,
        'u': url,
        if (bill != null) 'b': bill,
        if (action != null) 'a': action,
        if (congress != null) 'g': congress,
        if (number != null) 'n': number,
      };

  static AlertItem? fromJson(Object? raw) {
    if (raw is! Map) return null;
    final key = raw['k'];
    final kind = raw['c'];
    final title = raw['t'];
    if (key is! String || kind is! String || title is! String) return null;
    return AlertItem(
      key: key,
      kind: kind,
      title: title,
      date: raw['d'] is String ? raw['d'] as String : '',
      url: raw['u'] is String ? raw['u'] as String : '',
      bill: raw['b'] is String ? raw['b'] as String : null,
      action: raw['a'] is String ? raw['a'] as String : null,
      congress: raw['g'] is int ? raw['g'] as int : null,
      number: raw['n'] is int ? raw['n'] as int : null,
    );
  }
}

/// One delivered Washington notification.
@immutable
class AlertLogEntry {
  const AlertLogEntry({
    required this.title,
    required this.body,
    required this.at,
    this.id,
    this.items = const [],
    this.legacyItemKey,
    this.legacyItemKeys = const [],
  });

  /// The notification's dedupe key ('wash:summary:2026-11-15',
  /// 'eo:14418'). The notification's tap route carries it, which is how
  /// The Pulse finds this entry. Null for entries written before ids
  /// existed.
  final String? id;

  final String title;
  final String body;

  /// When it was (or is scheduled to be) delivered.
  final DateTime at;

  /// Everything this notification covered: one item for a single alert,
  /// all of them for a digest.
  final List<AlertItem> items;

  /// Entries written by older builds stored only keys. Kept readable so
  /// an alert delivered just before an update still opens.
  final String? legacyItemKey;
  final List<String> legacyItemKeys;

  bool get isDigest => items.length > 1 || legacyItemKeys.isNotEmpty;

  Map<String, Object?> toJson() => {
        if (id != null) 'id': id,
        't': title,
        'b': body,
        'at': at.millisecondsSinceEpoch,
        if (items.isNotEmpty) 'items': [for (final i in items) i.toJson()],
        if (legacyItemKey != null) 'k': legacyItemKey,
        if (legacyItemKeys.isNotEmpty) 'ks': legacyItemKeys,
      };

  static AlertLogEntry? fromJson(Object? raw) {
    if (raw is! Map || raw['at'] is! int) return null;
    return AlertLogEntry(
      id: raw['id'] is String ? raw['id'] as String : null,
      title: raw['t'] is String ? raw['t'] as String : '',
      body: raw['b'] is String ? raw['b'] as String : '',
      at: DateTime.fromMillisecondsSinceEpoch(raw['at'] as int),
      items: [
        for (final i in raw['items'] is List ? raw['items'] as List : const [])
          if (AlertItem.fromJson(i) case final item?) item,
      ],
      legacyItemKey: raw['k'] is String ? raw['k'] as String : null,
      legacyItemKeys: [
        for (final k in raw['ks'] is List ? raw['ks'] as List : const [])
          if (k is String) k,
      ],
    );
  }
}

/// Parses the stored log. Malformed input yields an empty list, and a
/// malformed entry is skipped, so one bad row never hides the rest.
List<AlertLogEntry> parseAlertLog(String? raw) {
  if (raw == null || raw.isEmpty) return const [];
  try {
    final list = jsonDecode(raw);
    if (list is! List) return const [];
    return [
      for (final e in list)
        if (AlertLogEntry.fromJson(e) case final entry?) entry,
    ];
  } catch (_) {
    return const [];
  }
}

String encodeAlertLog(List<AlertLogEntry> entries) =>
    jsonEncode([for (final e in entries) e.toJson()]);
