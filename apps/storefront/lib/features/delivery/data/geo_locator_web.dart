import 'dart:async';
import 'dart:js_interop';

import 'package:core/core.dart';
import 'package:web/web.dart' as web;

import 'geo_locator.dart';

class BrowserGeoLocator implements GeoLocator {
  @override
  Future<LatLng> current() {
    final done = Completer<LatLng>();
    web.window.navigator.geolocation.getCurrentPosition(
      ((web.GeolocationPosition p) {
        done.complete(LatLng(p.coords.latitude, p.coords.longitude));
      }).toJS,
      ((web.GeolocationPositionError e) {
        done.completeError(
          e.code == 1 ? const LocationDenied() : const LocationUnavailable(),
        );
      }).toJS,
      web.PositionOptions(
        enableHighAccuracy: true,
        timeout: 15000,
        maximumAge: 60000,
      ),
    );
    return done.future;
  }
}
