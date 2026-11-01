import 'package:cloud_firestore/cloud_firestore.dart' show FirebaseFirestore;
import 'package:core/core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Automatic offers (`offers`) or coupons (`coupons`), live, by name.
final offersProvider = StreamProvider.family<List<Offer>, OfferList>(
  (ref, list) => FirebaseFirestore.instance
      .collection(list.collection)
      .snapshots()
      .map(
        (s) =>
            [for (final d in s.docs) Offer.fromJson(d.data())]
              ..sort((a, b) => a.name.compareTo(b.name)),
      ),
);

/// The two kinds of offer the admin manages (P3-09).
enum OfferList {
  auto('offers', 'saveOffer'),
  coupons('coupons', 'saveCoupon');

  const OfferList(this.collection, this.action);

  final String collection;

  /// The audit action of a save.
  final String action;

  static OfferList of(Offer o) => o.isCoupon ? coupons : auto;

  String pathOf(Offer o) => '$collection/${o.id}';
}
