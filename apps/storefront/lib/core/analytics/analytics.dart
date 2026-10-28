import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Product events for the limited trial (P1-H07): open product, add to
/// cart, start checkout, order placed, and errors. Never carries personal
/// data (no name, phone or address).
abstract interface class Analytics {
  void event(String name, [Map<String, Object> params = const {}]);
}

/// Default (tests, and before Firebase starts): records nothing.
class NoAnalytics implements Analytics {
  const NoAnalytics();

  @override
  void event(String name, [Map<String, Object> params = const {}]) {}
}

/// Google Analytics for Firebase (GA4 recommended event names where they
/// exist, so the standard funnel reports work).
class FirebaseAppAnalytics implements Analytics {
  FirebaseAppAnalytics(this._analytics);

  final FirebaseAnalytics _analytics;

  @override
  void event(String name, [Map<String, Object> params = const {}]) {
    _analytics.logEvent(name: name, parameters: params).catchError((Object e) {
      debugPrint('analytics: $name not sent: $e');
    });
  }
}

final analyticsProvider = Provider<Analytics>((ref) => const NoAnalytics());

/// Event names and helpers, in one place.
abstract final class AppEvents {
  static const currency = 'EGP';

  static Map<String, Object> item(String productId, String categoryId) => {
    'item_id': productId,
    'item_category': categoryId,
  };

  /// Money in pounds, as GA4 expects a decimal value.
  static double pounds(int piasters) => piasters / 100;

  /// Error text trimmed to GA4's 100-character parameter limit.
  static String clip(Object error) {
    final s = '$error';
    return s.length <= 100 ? s : s.substring(0, 100);
  }
}
