import 'package:cloud_firestore/cloud_firestore.dart'
    show FirebaseFirestore, Timestamp;
import 'package:core/core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/sales_report.dart';

/// Report periods offered to the owner, in days.
const reportPeriods = [7, 30, 90];

/// The sales report for the last [days] days (P3-08): one read of the
/// period's orders by the server time they were placed (no live listener;
/// the screen refreshes on demand). Only staff roles (the owner here) may
/// read orders.
final salesReportProvider = FutureProvider.autoDispose.family<SalesReport, int>(
  (ref, days) async {
    final period = lastDays(DateTime.now(), days);
    final snap = await FirebaseFirestore.instance
        .collection('orders')
        .where(
          'serverCreatedAt',
          isGreaterThanOrEqualTo: Timestamp.fromDate(period.from),
        )
        .where('serverCreatedAt', isLessThan: Timestamp.fromDate(period.to))
        .get();
    final placed = <PlacedOrder>[];
    var unreadable = 0;
    for (final d in snap.docs) {
      try {
        final at = (d.data()['serverCreatedAt'] as Timestamp).toDate();
        placed.add(PlacedOrder(Order.fromJson(d.data()), at));
      } on Object {
        unreadable++;
      }
    }
    return SalesReport.build(
      placed,
      from: period.from,
      to: period.to,
      unreadable: unreadable,
    );
  },
);
