import 'package:core/core.dart';

/// A priced delivery: where the guest is, the road distance from the store
/// and the fee for it (pricing `deliveryFee`).
class DeliveryQuote {
  const DeliveryQuote({
    required this.location,
    required this.distanceMeters,
    required this.fee,
  });

  final LatLng location;
  final int distanceMeters;
  final Piasters fee;
}

/// Why a delivery could not be priced.
enum DeliveryError { denied, unavailable, routeFailed, outOfRange }
