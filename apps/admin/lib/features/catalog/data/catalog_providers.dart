import 'dart:async';

import 'package:category_definitions/category_definitions.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:core/core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../drafts/data/drafts_providers.dart';
import '../../drafts/domain/draft.dart';

/// The developer's category definitions (bundled, read-only for the admin).
final definitionsProvider = Provider<Map<String, CategoryDefinition>>(
  (ref) => loadBundledDefinitions().definitions,
);

/// Every product, live (the admin also sees unavailable ones).
final productsProvider = StreamProvider<List<Product>>(
  (ref) => FirebaseFirestore.instance
      .collection('products')
      .snapshots()
      .map(
        (s) => [for (final d in s.docs) Product.fromJson(d.data())]
          ..sort(
            (a, b) => a.categoryId == b.categoryId
                ? a.displayOrder.compareTo(b.displayOrder)
                : a.categoryId.compareTo(b.categoryId),
          ),
      ),
);

/// Every ingredient record by id, live.
final ingredientsProvider = StreamProvider<Map<String, Ingredient>>(
  (ref) => FirebaseFirestore.instance
      .collection('ingredients')
      .snapshots()
      .map(
        (s) => {for (final d in s.docs) d.id: Ingredient.fromJson(d.data())},
      ),
);

/// Every asset record by id, live (images to pick from).
final assetsProvider = StreamProvider<Map<String, Asset>>(
  (ref) => FirebaseFirestore.instance
      .collection('assets')
      .snapshots()
      .map((s) => {for (final d in s.docs) d.id: Asset.fromJson(d.data())}),
);

/// Admin-owned category visibility and order, live.
final categoryContentProvider = StreamProvider<List<CategoryContent>>(
  (ref) => FirebaseFirestore.instance
      .collection('categoryContent')
      .snapshots()
      .map(
        (s) =>
            [for (final d in s.docs) CategoryContent.fromJson(d.data())]
              ..sort((a, b) => a.displayOrder.compareTo(b.displayOrder)),
      ),
);

/// Targets (`products/{id}`, `ingredients/{id}`) with a pending draft, live.
final draftTargetsProvider = Provider<Set<String>>(
  (ref) => {
    for (final d in ref.watch(draftsProvider).value ?? const <Draft>[])
      d.target,
  },
);

/// The time the lists decide availability for, given [next] (epoch
/// milliseconds): the earliest «stopped until» still ahead among what they
/// show, or null. One timer refreshes it then, so a row stopped until a
/// time turns available by itself; no polling.
final availabilityNowProvider = Provider.autoDispose.family<DateTime, int?>((
  ref,
  next,
) {
  final now = DateTime.now();
  if (next != null) {
    var wait = Duration(milliseconds: next - now.millisecondsSinceEpoch);
    if (wait.isNegative) wait = Duration.zero;
    // Browsers fire overlong timers at once: wait in steps.
    if (wait > const Duration(hours: 12)) wait = const Duration(hours: 12);
    final timer = Timer(wait, ref.invalidateSelf);
    ref.onDispose(timer.cancel);
  }
  return now;
});

/// The store location and delivery pricing, live.
final storeSettingsProvider = StreamProvider<StoreSettings?>(
  (ref) => FirebaseFirestore.instance
      .doc('settings/store')
      .snapshots()
      .map((d) => d.data() == null ? null : StoreSettings.fromJson(d.data()!)),
);
