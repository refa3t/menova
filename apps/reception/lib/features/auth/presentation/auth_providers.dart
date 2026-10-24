import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/staff_access.dart';

/// Signed-in staff user and their access, re-evaluated on every token change
/// (so a newly granted role applies after the token refreshes).
final staffAccessProvider = StreamProvider<StaffAccess>((ref) {
  return FirebaseAuth.instance.idTokenChanges().asyncMap((user) async {
    if (user == null) return StaffAccess.signedOut;
    final token = await user.getIdTokenResult();
    return staffAccessFor(signedIn: true, role: token.claims?['role']);
  });
});
