import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show ProviderOrFamily;

import '../data/menu_repository.dart';
import '../domain/menu.dart';

final menuRepositoryProvider = Provider<MenuRepository>(
  (ref) => MenuRepository(FirebaseFirestore.instance),
);

/// The raw menu collections, loaded once (see [reloadMenu]).
final menuSourceProvider = FutureProvider<MenuSource>(
  (ref) => ref.watch(menuRepositoryProvider).loadSource(),
);

/// The time the shown menu decides availability for. It only moves when a
/// record stopped until a time comes back ([menuProvider] schedules one
/// timer for the earliest), never by polling.
final availabilityClockProvider = NotifierProvider<AvailabilityClock, DateTime>(
  AvailabilityClock.new,
);

class AvailabilityClock extends Notifier<DateTime> {
  @override
  DateTime build() => DateTime.now();

  void tick() => state = DateTime.now();
}

/// Longest single wait: a far-off time is reached in steps, as browsers
/// fire overlong timers at once.
const _maxWait = Duration(hours: 12);

/// The menu as it stands at [availabilityClockProvider]. When a product or
/// ingredient stopped until a time is pending, one timer moves the clock
/// then, and the menu (cards, builder, cart) updates without a reload.
final menuProvider = FutureProvider<Menu>((ref) async {
  final now = ref.watch(availabilityClockProvider);
  final source = await ref.watch(menuSourceProvider.future);
  final menu = source.at(now);
  if (menu.nextAvailabilityChange case final next?) {
    var wait = next.difference(DateTime.now());
    if (wait.isNegative) wait = Duration.zero;
    if (wait > _maxWait) wait = _maxWait;
    final timer = Timer(
      wait,
      () => ref.read(availabilityClockProvider.notifier).tick(),
    );
    ref.onDispose(timer.cancel);
  }
  return menu;
});

/// Loads the menu again from Firestore (retry, corrected prices).
void reloadMenu(void Function(ProviderOrFamily provider) invalidate) {
  invalidate(menuSourceProvider);
  invalidate(menuProvider);
}

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
