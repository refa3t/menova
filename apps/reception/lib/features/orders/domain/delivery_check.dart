import 'package:core/core.dart';
import 'package:pricing/pricing.dart';

enum DeliveryCheckResult { matches, mismatch, unverified }

/// Re-check of a delivery fee (amended SEC-02): the road distance is
/// measured again from the store to the guest's location and priced with
/// the same pricing library.
class DeliveryCheck {
  const DeliveryCheck(this.result, {this.expectedFee, this.roadMeters});

  const DeliveryCheck.unverified() : this(DeliveryCheckResult.unverified);

  final DeliveryCheckResult result;

  /// Fee for the re-measured distance; null when it is out of range.
  final Piasters? expectedFee;
  final int? roadMeters;
}

/// Compares the fee the guest paid with the fee for [roadMeters] under
/// [settings].
DeliveryCheck checkDelivery(
  Piasters orderFee,
  StoreSettings settings,
  int roadMeters,
) {
  try {
    final fee = deliveryFee(roadMeters, settings.delivery);
    return DeliveryCheck(
      fee == orderFee
          ? DeliveryCheckResult.matches
          : DeliveryCheckResult.mismatch,
      expectedFee: fee,
      roadMeters: roadMeters,
    );
  } on PricingException {
    return DeliveryCheck(DeliveryCheckResult.mismatch, roadMeters: roadMeters);
  }
}
