import 'package:core/core.dart';

import 'geo_locator.dart';

/// Non-web builds (tests): no geolocation.
class BrowserGeoLocator implements GeoLocator {
  @override
  Future<LatLng> current() async => throw const LocationUnavailable();
}
