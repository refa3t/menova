import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart'
    show FieldValue, FirebaseException, FirebaseFirestore;
import 'package:core/core.dart';
import 'package:flutter/foundation.dart';

/// Result of sending an order (CLAUDE.md 5.2).
sealed class SubmitResult {
  const SubmitResult();
}

/// Created now, or already existed with the same content (lost reply).
class Submitted extends SubmitResult {
  const Submitted(this.orderId, {required this.alreadyExisted});
  final String orderId;
  final bool alreadyExisted;
}

/// The id exists with different content (scenario 5).
class Conflict extends SubmitResult {
  const Conflict();
}

/// Not reached / not confirmed (offline, timeout). Retry with the same id.
class NotConfirmed extends SubmitResult {
  const NotConfirmed();
}

/// The order's coupon ran out just before it was sent: nothing was written.
class OfferUnavailable extends SubmitResult {
  const OfferUnavailable();
}

/// Where orders are written and looked up. Implemented by Firestore in the
/// app and by an in-memory fake in tests.
abstract interface class OrderGateway {
  Future<SubmitResult> submit(Order order);

  /// The payloadHash of an existing order, null if none, or throws when
  /// the server cannot be reached.
  Future<String?> find(String requestId);
}

/// The decision taken inside the transaction (CLAUDE.md 5.2 step 4).
SubmitResult decideExisting({
  required String? existingHash,
  required Order order,
}) => existingHash == null
    ? Submitted(order.requestId, alreadyExisted: false)
    : existingHash == order.payloadHash
    ? Submitted(order.requestId, alreadyExisted: true)
    : const Conflict();

/// Writes the order once, inside a transaction keyed by its requestId:
/// an existing order with the same payloadHash is returned, a different one
/// is a conflict, otherwise it is created. Transactions never run offline
/// and are not queued, so nothing is sent automatically after the app is
/// closed (CLAUDE.md 5.2).
class OrderSubmitter implements OrderGateway {
  OrderSubmitter(this._db, {this.timeout = const Duration(seconds: 15)});

  final FirebaseFirestore _db;
  final Duration timeout;

  @override
  Future<String?> find(String requestId) async {
    final snap = await _db
        .collection('orders')
        .doc(requestId)
        .get()
        .timeout(timeout);
    return snap.exists ? (snap.data()?['payloadHash'] as String?) : null;
  }

  @override
  Future<SubmitResult> submit(Order order) async {
    final ref = _db.collection('orders').doc(order.requestId);
    try {
      return await _db
          .runTransaction<SubmitResult>((tx) async {
            final existing = await tx.get(ref);
            // A coupon order counts one use in the same write (P3-09).
            final code = order.offer?.code;
            final couponRef = code == null
                ? null
                : _db.collection('coupons').doc(code);
            final coupon = couponRef == null ? null : await tx.get(couponRef);
            final decision = decideExisting(
              existingHash: existing.exists
                  ? (existing.data()?['payloadHash'] as String?)
                  : null,
              order: order,
            );
            if (decision case Submitted(alreadyExisted: false)) {
              if (couponRef != null) {
                final data = coupon?.data();
                final uses = data?['uses'] as int? ?? 0;
                final max = data?['maxUses'] as int?;
                if (data == null || (max != null && uses >= max)) {
                  return const OfferUnavailable();
                }
                tx.update(couponRef, {
                  'uses': uses + 1,
                  'lastOrderId': order.requestId,
                });
              }
              tx.set(ref, {
                ...order.toJson(),
                'serverCreatedAt': FieldValue.serverTimestamp(),
              });
            }
            return decision;
          })
          .timeout(timeout);
    } on TimeoutException {
      debugPrint('checkout: submit timed out');
      return const NotConfirmed();
    } on FirebaseException catch (e) {
      debugPrint('checkout: submit failed: ${e.code} ${e.message}');
      // permission-denied here means the id exists but belongs to someone
      // else or the payload broke the rules: treat as a conflict.
      return e.code == 'permission-denied'
          ? const Conflict()
          : const NotConfirmed();
    }
  }
}
