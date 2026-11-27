import 'dart:math' as math;

import 'json.dart';
import 'money.dart';

/// A point on the map (WGS84 degrees).
class LatLng {
  const LatLng(this.lat, this.lng);

  final double lat;
  final double lng;

  factory LatLng.fromJson(Json j) =>
      LatLng(toDouble(j['lat']), toDouble(j['lng']));

  Json toJson() => {'lat': lat, 'lng': lng};

  @override
  bool operator ==(Object other) =>
      other is LatLng && other.lat == lat && other.lng == lng;

  @override
  int get hashCode => Object.hash(lat, lng);

  @override
  String toString() => 'LatLng($lat, $lng)';
}

/// Great-circle distance in meters. A lower bound for any road route
/// between the two points.
double haversineMeters(LatLng a, LatLng b) {
  const earthRadius = 6371000.0;
  double rad(double d) => d * math.pi / 180;
  final dLat = rad(b.lat - a.lat);
  final dLng = rad(b.lng - a.lng);
  final h =
      math.pow(math.sin(dLat / 2), 2) +
      math.cos(rad(a.lat)) *
          math.cos(rad(b.lat)) *
          math.pow(math.sin(dLng / 2), 2);
  return 2 * earthRadius * math.asin(math.sqrt(h));
}

/// Delivery pricing inputs, owned by the admin (Firestore `settings/store`).
class DeliverySettings {
  const DeliverySettings({
    required this.perKm,
    required this.minFee,
    required this.maxDistanceMeters,
  });

  /// Fee per started kilometer of road distance.
  final Piasters perKm;
  final Piasters minFee;
  final int maxDistanceMeters;

  factory DeliverySettings.fromJson(Json j) {
    final s = DeliverySettings(
      perKm: req(j, 'perKm'),
      minFee: req(j, 'minFee'),
      maxDistanceMeters: req(j, 'maxDistanceMeters'),
    );
    if (s.perKm < 0 || s.minFee < 0 || s.maxDistanceMeters <= 0) {
      throw const FormatException('Invalid delivery settings');
    }
    return s;
  }

  Json toJson() => {
    'perKm': perKm,
    'minFee': minFee,
    'maxDistanceMeters': maxDistanceMeters,
  };
}

/// End of the business day when the owner has not set one: 4 AM, for a
/// restaurant open past midnight. An interim default; the owner sets the
/// real hour in the admin settings (`settings/store.dayEndHour`).
const defaultDayEndHour = 4;

/// The next [hour]:00 strictly after [now], in [now]'s time zone: today at
/// that hour if still ahead, else tomorrow.
DateTime nextDayEndAt(DateTime now, int hour) {
  DateTime at(int day) => now.isUtc
      ? DateTime.utc(now.year, now.month, day, hour)
      : DateTime(now.year, now.month, day, hour);
  final today = at(now.day);
  return today.isAfter(now) ? today : at(now.day + 1);
}

/// Store-wide settings (Firestore `settings/store`), one document.
class StoreSettings {
  const StoreSettings({
    required this.location,
    required this.delivery,
    this.dayEndHour = defaultDayEndHour,
    this.temp = false,
  });

  /// Where deliveries start from.
  final LatLng location;
  final DeliverySettings delivery;

  /// Local hour (0..23) the business day ends: a record stopped «لنهاية
  /// اليوم» comes back by itself at its next occurrence.
  final int dayEndHour;

  /// When a record stopped now «لنهاية اليوم» comes back.
  DateTime nextDayEnd(DateTime now) => nextDayEndAt(now, dayEndHour);

  /// TEMP data marker (development only).
  final bool temp;

  factory StoreSettings.fromJson(Json j) {
    final hour = opt<num>(j, 'dayEndHour')?.toInt() ?? defaultDayEndHour;
    if (hour < 0 || hour > 23) {
      throw const FormatException('dayEndHour must be 0..23');
    }
    return StoreSettings(
      location: LatLng.fromJson(req(j, 'location')),
      delivery: DeliverySettings.fromJson(req(j, 'delivery')),
      dayEndHour: hour,
      temp: opt<bool>(j, 'temp') ?? false,
    );
  }

  Json toJson() => {
    'location': location.toJson(),
    'delivery': delivery.toJson(),
    'dayEndHour': dayEndHour,
    if (temp) 'temp': true,
  };
}
