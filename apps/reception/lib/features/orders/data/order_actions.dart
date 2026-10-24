import 'package:cloud_firestore/cloud_firestore.dart'
    show FieldValue, FirebaseFirestore;
import 'package:core/core.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Status and payment changes by staff (P1-F04, P1-F05). Each change appends
/// one history entry recording who and when; Firestore rules check the role,
/// the allowed transition and the entry (D-INFRA-01 = B).
class OrderActions {
  OrderActions(this._db, this._auth);

  final FirebaseFirestore _db;
  final FirebaseAuth _auth;

  Future<void> setStatus(Order order, OrderStatus to, {String? reason}) =>
      _apply(order.id, 'status', to.wire, reason: reason);

  Future<void> setPayment(Order order, PaymentStatus to) =>
      _apply(order.id, 'paymentStatus', to.name);

  Future<void> _apply(
    String orderId,
    String field,
    String value, {
    String? reason,
  }) {
    final entry = StatusChange(
      field: field,
      value: value,
      by: _auth.currentUser!.uid,
      at: DateTime.now().toUtc().toIso8601String(),
      reason: reason,
    );
    return _db.collection('orders').doc(orderId).update({
      field: value,
      'history': FieldValue.arrayUnion([entry.toJson()]),
    });
  }
}
