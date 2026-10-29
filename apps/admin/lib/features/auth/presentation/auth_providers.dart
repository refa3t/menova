import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/admin_access.dart';

/// Signed-in admin user and their access, re-evaluated on every token change
/// (so a newly granted role applies after the token refreshes).
final adminAccessProvider = StreamProvider<AdminAccess>((ref) {
  return FirebaseAuth.instance.idTokenChanges().asyncMap((user) async {
    if (user == null) return const SignedOut();
    final token = await user.getIdTokenResult();
    return adminAccessFor(
      uid: user.uid,
      email: user.email,
      roleClaim: token.claims?['role'],
    );
  });
});
