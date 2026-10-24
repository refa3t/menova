import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../../core/strings/app_strings.dart';

/// Orders dashboard. The live list and new-order alert land in P1-F02.
class OrdersScreen extends StatelessWidget {
  const OrdersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(AppStrings.orders),
        actions: [
          TextButton(
            onPressed: FirebaseAuth.instance.signOut,
            child: const Text(AppStrings.signOut),
          ),
        ],
      ),
      body: const Center(child: Text(AppStrings.noOrders)),
      bottomNavigationBar: const SafeArea(
        child: Padding(
          padding: EdgeInsets.all(12),
          child: Text(AppStrings.credit, textAlign: TextAlign.center),
        ),
      ),
    );
  }
}
