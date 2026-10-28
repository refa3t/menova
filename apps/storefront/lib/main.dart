import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart' show SemanticsBinding, SemanticsHandle;
import 'package:flutter_web_plugins/url_strategy.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/app.dart';
import 'features/cart/presentation/cart_providers.dart';
import 'firebase_options.dart';

/// Kept alive for the whole session when `?semantics` is set.
SemanticsHandle? acceptanceSemantics;

Future<void> main() async {
  // Clean URLs (/product/x) instead of /#/product/x; Hosting rewrites to index.
  usePathUrlStrategy();
  WidgetsFlutterBinding.ensureInitialized();
  // Pages opened with push (category, product) show their own URL, so a
  // refresh or a shared link lands on the same page.
  GoRouter.optionURLReflectsImperativeAPIs = true;
  // `?semantics` turns the accessibility tree on from the first frame, so
  // the acceptance run (tools/perf/acceptance.mjs) can tap by visible text.
  if (Uri.base.queryParameters.containsKey('semantics')) {
    acceptanceSemantics = SemanticsBinding.instance.ensureSemantics();
  }
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  // Menu browsing works from the local cache on weak connections (P1-A05).
  FirebaseFirestore.instance.settings = const Settings(
    persistenceEnabled: true,
  );
  final prefs = await SharedPreferences.getInstance();
  runApp(
    ProviderScope(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      child: const App(),
    ),
  );
}
