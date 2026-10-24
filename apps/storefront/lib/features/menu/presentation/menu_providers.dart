import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/menu_repository.dart';
import '../domain/menu.dart';

final menuRepositoryProvider = Provider<MenuRepository>(
  (ref) => MenuRepository(FirebaseFirestore.instance),
);

final menuProvider = FutureProvider<Menu>(
  (ref) => ref.watch(menuRepositoryProvider).load(),
);

/// Warms the image cache for every product card in the menu.
Future<void> precacheMenuImages(BuildContext context, Menu menu) async {
  final urls = {
    for (final c in menu.categories)
      for (final p in c.products) menu.cardImageUrl(p, c.definition),
  }.whereType<String>();
  await Future.wait([
    for (final url in urls)
      precacheImage(NetworkImage(url), context, onError: (_, _) {}),
  ]);
}
