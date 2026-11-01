import 'package:cloud_firestore/cloud_firestore.dart'
    show FirebaseFirestore, GetOptions, Source;
import 'package:core/core.dart';

/// Offers and coupons as the guest may read them (P3-09): automatic offers
/// are listed; a coupon is fetched only by its exact code.
class OffersRepository {
  OffersRepository(this._db);

  final FirebaseFirestore _db;

  /// The automatic offers switched on, live.
  Stream<List<Offer>> watchActive() => _db
      .collection('offers')
      .where('isActive', isEqualTo: true)
      .snapshots()
      .map((s) => [for (final d in s.docs) Offer.fromJson(d.data())]);

  /// The same, straight from the server, for the check before sending.
  Future<List<Offer>> activeFromServer() async {
    final s = await _db
        .collection('offers')
        .where('isActive', isEqualTo: true)
        .get(const GetOptions(source: Source.server));
    return [for (final d in s.docs) Offer.fromJson(d.data())];
  }

  /// The coupon with [code] (as `couponCode` gives it), or null.
  Future<Offer?> coupon(String code, {bool fromServer = false}) async {
    final snap = await _db
        .collection('coupons')
        .doc(code)
        .get(
          GetOptions(
            source: fromServer ? Source.server : Source.serverAndCache,
          ),
        );
    final data = snap.data();
    return data == null ? null : Offer.fromJson(data);
  }
}
