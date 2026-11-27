import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../staff/domain/staff_member.dart';
import '../domain/admin_access.dart';

/// The signed-in user and their token claims, on every token change (so a
/// newly granted claim or a verified email applies after a refresh).
typedef SignIn = ({
  String uid,
  String? email,
  Object? roleClaim,
  bool emailVerified,
});

final signInProvider = StreamProvider<SignIn?>((ref) {
  return FirebaseAuth.instance.idTokenChanges().asyncMap((user) async {
    if (user == null) return null;
    final claims = (await user.getIdTokenResult()).claims ?? const {};
    return (
      uid: user.uid,
      email: user.email,
      roleClaim: claims['role'],
      // What the rules see (request.auth.token.email_verified).
      emailVerified: claims['email_verified'] == true,
    );
  });
});

/// Signed-in admin user and their access: the claim, else their staff
/// record, followed live (a removed record locks the panel at once).
final adminAccessProvider = StreamProvider<AdminAccess>((ref) async* {
  final s = await ref.watch(signInProvider.future);
  if (s == null) {
    yield const SignedOut();
    return;
  }
  AdminAccess accessWith(Object? staffRole) => adminAccessFor(
    uid: s.uid,
    email: s.email,
    roleClaim: s.roleClaim,
    emailVerified: s.emailVerified,
    staffRole: staffRole,
  );
  final byClaim = accessWith(null);
  final email = s.email;
  if (byClaim is Granted || email == null || email.isEmpty) {
    yield byClaim;
    return;
  }
  yield* FirebaseFirestore.instance
      .doc('staff/${staffRecordId(email)}')
      .snapshots()
      .map((d) => accessWith(d.data()?['role']))
      .transform(
        StreamTransformer.fromHandlers(
          handleError: (_, _, sink) => sink.add(const Denied()),
        ),
      );
});
