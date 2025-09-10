import 'dart:async';
import 'package:flutter/widgets.dart';
import 'package:firebase_analytics/firebase_analytics.dart';

/// Centralized, safe wrappers around Firebase Analytics.
/// - Never throws (errors are swallowed)
/// - Helpers for common events in your app
class Analytics {
  Analytics._();

  static FirebaseAnalytics? _inst;
  static bool _inited = false;

  /// Call once after Firebase.initializeApp().
  static Future<void> init() async {
    if (_inited) return;
    _inst = FirebaseAnalytics.instance;
    _inited = true;
  }

  static Future<void> enableCollection([bool enabled = true]) =>
      _safe(() => _inst!.setAnalyticsCollectionEnabled(enabled));

  /// Lifecycle
  static Future<void> logAppOpen() => _safe(() => _inst!.logAppOpen());

  /// Screen tracking (manual; see [observer] for auto-tracking).
  static Future<void> logScreenView(String name, {String? className}) =>
      _safe(() => _inst!.logScreenView(
            screenName: name,
            screenClass: className ?? name,
          ));

  /// Identity
  static Future<void> setUserId(String id) =>
      _safe(() => _inst!.setUserId(id: id));

  static Future<void> setUserProperty(String name, String value) =>
      _safe(() => _inst!.setUserProperty(name: name, value: value));

  // -------------------- App events --------------------

  static Future<void> logSearch(String term) =>
      _safe(() => _inst!.logSearch(searchTerm: term));

  /// Use a custom event to avoid strict non-null signature issues.
  static Future<void> logShare({
    String? contentType,
    String? itemId,
    String? method,
  }) =>
      _safe(() => _inst!.logEvent(
            name: 'share',
            parameters: _clean({
              if (contentType != null) 'content_type': contentType,
              if (itemId != null) 'item_id': itemId,
              if (method != null) 'method': method,
            }),
          ));

  static Future<void> logSelectContent({
    required String contentType,
    required String itemId,
  }) =>
      _safe(() => _inst!.logSelectContent(
            contentType: contentType,
            itemId: itemId,
          ));

  static Future<void> logQuizResult({
    required int total,
    required int correct,
  }) =>
      _safe(() => _inst!.logEvent(
            name: 'quiz_result',
            parameters: _clean({
              'total': total,
              'correct': correct,
              'score_pct': total == 0 ? 0 : ((correct / total) * 100).round(),
            }),
          ));

  static Future<void> logBadgeEarned(String badgeKey) =>
      _safe(() => _inst!.logEvent(
            name: 'badge_earned',
            parameters: _clean({'badge': badgeKey}),
          ));

  static Future<void> logFavoriteToggled({
    required String term,
    required bool isFavorite,
  }) =>
      _safe(() => _inst!.logEvent(
            name: 'favorite_toggled',
            parameters: _clean({
              'term': term,
              'is_favorite': isFavorite,
            }),
          ));

  /// Add this to GoRouter (or MaterialApp) observers for auto screen_view.
  static NavigatorObserver get observer =>
      FirebaseAnalyticsObserver(analytics: FirebaseAnalytics.instance);

  // -------------------- internals --------------------

  static Future<void> _safe(Future<void> Function() run) async {
    try {
      if (!_inited) await init();
      final i = _inst;
      if (i == null) return;
      await run();
    } catch (_) {
      // swallow analytics errors
    }
  }

  /// Remove nulls and cast to Map<String, Object> for plugin API.
  static Map<String, Object> _clean(Map<String, Object?> src) {
    final out = <String, Object>{};
    src.forEach((k, v) {
      if (v != null) out[k] = v as Object;
    });
    return out;
    }
}