import 'dart:convert';

import 'package:core/core.dart';
import 'package:http/http.dart' as http;

/// Road distance between two points.
abstract interface class RouteService {
  /// Driving distance in meters. Throws on any failure.
  Future<int> roadMeters(LatLng from, LatLng to);
}

/// OSRM (OpenStreetMap routing): free, no API key (owner decision).
/// The public server is fair-use; move to a self-hosted OSRM if volume
/// grows.
class OsrmRouteService implements RouteService {
  OsrmRouteService({http.Client? client, this.baseUrl = defaultBaseUrl})
    : _client = client ?? http.Client();

  static const defaultBaseUrl = 'https://router.project-osrm.org';

  final http.Client _client;
  final String baseUrl;

  @override
  Future<int> roadMeters(LatLng from, LatLng to) async {
    // OSRM takes lng,lat.
    final uri = Uri.parse(
      '$baseUrl/route/v1/driving/'
      '${from.lng},${from.lat};${to.lng},${to.lat}?overview=false',
    );
    final res = await _client.get(uri).timeout(const Duration(seconds: 12));
    if (res.statusCode != 200) {
      throw StateError('OSRM ${res.statusCode}');
    }
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    final routes = body['routes'] as List?;
    if (body['code'] != 'Ok' || routes == null || routes.isEmpty) {
      throw StateError('OSRM ${body['code']}');
    }
    return ((routes.first as Map)['distance'] as num).round();
  }
}
