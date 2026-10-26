import 'package:core/core.dart';

import 'geo_locator_stub.dart'
    if (dart.library.js_interop) 'geo_locator_web.dart'
    as impl;

/// The device's current position.
abstract interface class GeoLocator {
  /// Throws [LocationDenied] or [LocationUnavailable].
  Future<LatLng> current();
}

class LocationDenied implements Exception {
  const LocationDenied();
}

class LocationUnavailable implements Exception {
  const LocationUnavailable();
}

/// The browser's geolocation (asks the guest for permission).
GeoLocator platformGeoLocator() => impl.BrowserGeoLocator();
