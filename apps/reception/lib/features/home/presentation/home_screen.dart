import 'package:flutter/material.dart';

import '../../../core/strings/app_strings.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text(AppStrings.appTitle)),
      body: const Center(child: Text(AppStrings.homeHeading)),
    );
  }
}
