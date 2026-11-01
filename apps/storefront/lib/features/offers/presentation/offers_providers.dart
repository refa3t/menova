import 'package:cloud_firestore/cloud_firestore.dart' show FirebaseFirestore;
import 'package:core/core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/offers_repository.dart';

final offersRepositoryProvider = Provider<OffersRepository>(
  (ref) => OffersRepository(FirebaseFirestore.instance),
);

/// The automatic offers switched on, live (P3-09).
final activeOffersProvider = StreamProvider<List<Offer>>(
  (ref) => ref.watch(offersRepositoryProvider).watchActive(),
);

/// The coupon the guest typed (P3-09).
sealed class CouponState {
  const CouponState();
}

class NoCoupon extends CouponState {
  const NoCoupon();
}

class CouponChecking extends CouponState {
  const CouponChecking();
}

class CouponFound extends CouponState {
  const CouponFound(this.coupon);
  final Offer coupon;
}

class CouponNotFound extends CouponState {
  const CouponNotFound();
}

/// Could not be checked (offline).
class CouponFailed extends CouponState {
  const CouponFailed();
}

/// Kept while the guest moves between the cart and checkout; cleared once
/// the order is placed.
final couponProvider = NotifierProvider<CouponController, CouponState>(
  CouponController.new,
);

class CouponController extends Notifier<CouponState> {
  @override
  CouponState build() => const NoCoupon();

  Future<void> apply(String typed) async {
    final code = couponCode(typed);
    if (code == null) {
      state = const CouponNotFound();
      return;
    }
    state = const CouponChecking();
    try {
      final c = await ref.read(offersRepositoryProvider).coupon(code);
      state = c == null ? const CouponNotFound() : CouponFound(c);
    } on Object {
      state = const CouponFailed();
    }
  }

  /// The coupon as the server has it now (it may have changed or run out).
  void refreshed(Offer? coupon) =>
      state = coupon == null ? const CouponNotFound() : CouponFound(coupon);

  void clear() => state = const NoCoupon();
}

/// The guest's coupon when one was found.
Offer? couponOf(CouponState s) => switch (s) {
  CouponFound(:final coupon) => coupon,
  _ => null,
};
