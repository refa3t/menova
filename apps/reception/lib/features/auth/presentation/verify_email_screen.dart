import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../../core/strings/app_strings.dart';

/// Shown to a signed-in user whose email has a staff record but is not
/// verified yet: the record grants nothing until it is (P3-01).
class VerifyEmailScreen extends StatefulWidget {
  const VerifyEmailScreen({super.key});

  @override
  State<VerifyEmailScreen> createState() => _VerifyEmailScreenState();
}

class _VerifyEmailScreenState extends State<VerifyEmailScreen> {
  bool _busy = false;
  String? _message;

  Future<void> _run(Future<String?> Function(User user) action) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || _busy) return;
    setState(() {
      _busy = true;
      _message = null;
    });
    String? message;
    try {
      message = await action(user);
    } on FirebaseAuthException catch (e) {
      message = e.code == 'too-many-requests'
          ? AppStrings.loginTooMany
          : AppStrings.verifyFailed;
    } on Object {
      message = AppStrings.verifyFailed;
    }
    if (mounted) {
      setState(() {
        _busy = false;
        _message = message;
      });
    }
  }

  Future<String?> _send(User user) async {
    await FirebaseAuth.instance.setLanguageCode('ar');
    await user.sendEmailVerification();
    return AppStrings.verifySent;
  }

  /// Reloads the user and refreshes the token (the rules read
  /// email_verified from it); access is re-evaluated on the new token.
  Future<String?> _check(User user) async {
    await user.reload();
    final fresh = FirebaseAuth.instance.currentUser;
    if (fresh == null || !fresh.emailVerified) return AppStrings.notVerifiedYet;
    await fresh.getIdToken(true);
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.all(24),
            children: [
              Text(
                AppStrings.verifyTitle,
                textAlign: TextAlign.center,
                style: theme.textTheme.headlineSmall,
              ),
              const SizedBox(height: 16),
              Text(
                AppStrings.verifyBody(FirebaseAuth.instance.currentUser?.email),
              ),
              if (_message != null) ...[
                const SizedBox(height: 12),
                Text(_message!, style: theme.textTheme.bodyMedium),
              ],
              const SizedBox(height: 20),
              FilledButton(
                onPressed: _busy ? null : () => _run(_send),
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(48),
                ),
                child: const Text(AppStrings.sendVerification),
              ),
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: _busy ? null : () => _run(_check),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(48),
                ),
                child: const Text(AppStrings.checkAgain),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: FirebaseAuth.instance.signOut,
                style: TextButton.styleFrom(minimumSize: const Size(44, 44)),
                child: const Text(AppStrings.signOut),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
