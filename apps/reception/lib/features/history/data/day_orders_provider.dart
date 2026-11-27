import 'package:cloud_firestore/cloud_firestore.dart'
    show FirebaseFirestore, Timestamp;
import 'package:core/core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/order_history.dart';

/// Every order placed on the local day of [day] (any status), newest
/// first, live. A range and an order on the one field `serverCreatedAt`
/// need no composite index. Staff roles may read orders (firestore.rules).
final dayOrdersProvider = StreamProvider.autoDispose
    .family<List<DayOrder>, DateTime>((ref, day) {
      final range = dayRange(day);
      return FirebaseFirestore.instance
          .collection('orders')
          .where(
            'serverCreatedAt',
            isGreaterThanOrEqualTo: Timestamp.fromDate(range.from),
          )
          .where('serverCreatedAt', isLessThan: Timestamp.fromDate(range.to))
          .orderBy('serverCreatedAt', descending: true)
          .snapshots()
          .map((s) => [for (final d in s.docs) ?_read(d.data())]);
    });

/// An order the board can show, or null for a document it cannot read.
DayOrder? _read(Map<String, dynamic> data) {
  try {
    final at = (data['serverCreatedAt'] as Timestamp).toDate();
    return DayOrder(Order.fromJson(data), at);
  } on Object {
    return null;
  }
}
