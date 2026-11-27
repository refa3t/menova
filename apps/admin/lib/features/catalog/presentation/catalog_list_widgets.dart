import 'package:core/core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/strings/app_strings.dart';
import '../../auth/domain/admin_access.dart';
import '../../auth/presentation/auth_providers.dart';
import '../data/audited_writer.dart';
import '../data/catalog_providers.dart';
import '../domain/catalog_list.dart';

/// A small square image of a record: the asset's original secure_url sized
/// by the widget (no Cloudinary transformations, CLAUDE.md 3.1), or a
/// neutral placeholder when there is none.
class CatalogThumb extends StatelessWidget {
  const CatalogThumb({super.key, required this.asset, this.size = 48});

  final Asset? asset;
  final double size;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final placeholder = ColoredBox(
      color: scheme.surfaceContainerHighest,
      child: Icon(
        Icons.image_outlined,
        size: size * 0.5,
        color: scheme.onSurfaceVariant,
        semanticLabel: AppStrings.noImage,
      ),
    );
    final dpr = MediaQuery.devicePixelRatioOf(context);
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: SizedBox.square(
        dimension: size,
        child: asset == null
            ? placeholder
            : Image.network(
                asset!.secureUrl,
                fit: BoxFit.cover,
                // Decoded at thumbnail size: the file stays the original.
                cacheWidth: (size * dpr).round(),
                errorBuilder: (_, _, _) => placeholder,
              ),
      ),
    );
  }
}

/// Chips for the status filter.
class StatusFilterChips extends StatelessWidget {
  const StatusFilterChips({
    super.key,
    required this.value,
    required this.onChanged,
  });

  final StatusFilter value;
  final ValueChanged<StatusFilter> onChanged;

  static String label(StatusFilter s) => switch (s) {
    StatusFilter.all => AppStrings.statusAll,
    StatusFilter.available => AppStrings.statusAvailable,
    StatusFilter.stopped => AppStrings.statusStopped,
    StatusFilter.drafted => AppStrings.statusDrafted,
  };

  @override
  Widget build(BuildContext context) => Wrap(
    spacing: 8,
    runSpacing: 8,
    children: [
      for (final s in StatusFilter.values)
        ChoiceChip(
          label: Text(label(s)),
          selected: value == s,
          onSelected: (_) => onChanged(s),
        ),
    ],
  );
}

/// The bar shown while records are selected: count, select all shown,
/// clear, stop and start, and the progress of a running bulk save.
class BulkAvailabilityBar extends StatelessWidget {
  const BulkAvailabilityBar({
    super.key,
    required this.selected,
    required this.onSelectAllShown,
    required this.onClear,
    required this.onSet,
    this.onStopForDay,
    this.progress,
  });

  final int selected;
  final VoidCallback? onSelectAllShown;
  final VoidCallback onClear;
  final ValueChanged<bool> onSet;

  /// Stops the selected until the end of the business day.
  final VoidCallback? onStopForDay;

  /// (done, total) while saving; the buttons are locked meanwhile.
  final (int, int)? progress;

  @override
  Widget build(BuildContext context) {
    final busy = progress != null;
    return Card(
      color: Theme.of(context).colorScheme.secondaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(AppStrings.selectedCount(selected)),
                TextButton(
                  onPressed: busy ? null : onSelectAllShown,
                  child: const Text(AppStrings.selectAllShown),
                ),
                TextButton(
                  onPressed: busy ? null : onClear,
                  child: const Text(AppStrings.clearSelection),
                ),
                FilledButton.tonalIcon(
                  onPressed: busy ? null : () => onSet(false),
                  icon: const Icon(Icons.pause_circle_outline),
                  label: const Text(AppStrings.stopSelected),
                ),
                if (onStopForDay != null)
                  FilledButton.tonalIcon(
                    onPressed: busy ? null : onStopForDay,
                    icon: const Icon(Icons.bedtime_outlined),
                    label: const Text(AppStrings.stopForDay),
                  ),
                FilledButton.icon(
                  onPressed: busy ? null : () => onSet(true),
                  icon: const Icon(Icons.play_circle_outline),
                  label: const Text(AppStrings.startSelected),
                ),
              ],
            ),
            if (progress case (final done, final total)) ...[
              const SizedBox(height: 8),
              LinearProgressIndicator(value: total == 0 ? null : done / total),
              const SizedBox(height: 4),
              Text(AppStrings.bulkProgress(done, total)),
            ],
          ],
        ),
      ),
    );
  }
}

/// A row's availability: its state («متاح», «غير متاح» or «موقوف حتى
/// 4:00 ص»), the stop/start switch and a menu with «إيقاف لنهاية اليوم».
class AvailabilityControls extends StatelessWidget {
  const AvailabilityControls({
    super.key,
    required this.availableNow,
    required this.stoppedUntil,
    required this.onSet,
    required this.onStopForDay,
  });

  /// Availability at the time the list is drawn (`isAvailableAt`).
  final bool availableNow;

  /// When the record comes back by itself, if it is stopped until a time.
  final DateTime? stoppedUntil;

  /// Null while a bulk save runs.
  final ValueChanged<bool>? onSet;
  final VoidCallback? onStopForDay;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Text(
        stoppedUntil != null
            ? AppStrings.stoppedUntil(stoppedUntil!)
            : availableNow
            ? AppStrings.available
            : AppStrings.unavailable,
      ),
      Switch(value: availableNow, onChanged: onSet),
      PopupMenuButton<void>(
        tooltip: AppStrings.moreActions,
        enabled: onStopForDay != null,
        itemBuilder: (_) => [
          PopupMenuItem<void>(
            onTap: onStopForDay,
            child: const Text(AppStrings.stopForDay),
          ),
        ],
      ),
    ],
  );
}

/// The availability switch of the edit screens. A record stopped until a
/// time shows it («موقوف حتى 4:00 ص») with the switch off; using the switch
/// ends that stop.
class AvailabilitySwitchTile extends StatelessWidget {
  const AvailabilitySwitchTile({
    super.key,
    required this.isAvailable,
    required this.until,
    required this.onChanged,
  });

  final bool isAvailable;
  final int? until;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final stopped = pendingUntil(
      isAvailable: isAvailable,
      unavailableUntil: until,
      now: now,
    );
    final on = availableAt(
      isAvailable: isAvailable,
      unavailableUntil: until,
      now: now,
    );
    return SwitchListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(
        stopped != null
            ? AppStrings.stoppedUntil(stopped)
            : on
            ? AppStrings.available
            : AppStrings.unavailable,
      ),
      value: on,
      onChanged: onChanged,
    );
  }
}

/// When a record stopped now «لنهاية اليوم» comes back (epoch
/// milliseconds): the next end of the business day the owner set in
/// `settings/store` (the interim default if unset or unreadable), in the
/// device's local time.
Future<int> stopForDayUntil(WidgetRef ref) async {
  var hour = defaultDayEndHour;
  // Listened while read: a provider nobody listens to is paused.
  final sub = ref.listenManual(storeSettingsProvider, (_, _) {});
  try {
    hour = (await ref.read(storeSettingsProvider.future))?.dayEndHour ?? hour;
  } on Object {
    // Keep the default: stopping must still work.
  } finally {
    sub.close();
  }
  return dayEndUntil(DateTime.now(), hour);
}

/// Saves one row's availability [change] (audited), reporting a failure.
/// Nothing happens when [change] is null (already in that state).
Future<void> saveAvailabilityChange({
  required BuildContext context,
  required WidgetRef ref,
  required AuditedChange? change,
  String? doneMessage,
}) async {
  final who = ref.read(adminAccessProvider).value;
  if (who is! Granted || change == null) return;
  final messenger = ScaffoldMessenger.of(context);
  try {
    await ref
        .read(auditedWriterProvider)
        .write(
          who: who,
          action: change.action,
          path: change.path,
          before: change.before,
          after: change.after,
        );
    if (doneMessage != null) {
      messenger.showSnackBar(SnackBar(content: Text(doneMessage)));
    }
  } on Object {
    messenger.showSnackBar(
      const SnackBar(content: Text(AppStrings.saveFailed)),
    );
  }
}

/// Asks to confirm, then saves [changes] (each audited in its batch) and
/// reports the result. [onProgress] follows the save; returns true when
/// every change was saved. [confirmText] replaces the stop/start question.
Future<bool> runBulkAvailability({
  required BuildContext context,
  required WidgetRef ref,
  required bool value,
  required List<AuditedChange> changes,
  required void Function(int done, int total) onProgress,
  String? confirmText,
}) async {
  final messenger = ScaffoldMessenger.of(context);
  if (changes.isEmpty) {
    messenger.showSnackBar(
      const SnackBar(content: Text(AppStrings.bulkNothing)),
    );
    return true;
  }
  final who = ref.read(adminAccessProvider).value;
  if (who is! Granted) return false;
  final ok = await showDialog<bool>(
    context: context,
    builder: (c) => AlertDialog(
      content: Text(
        confirmText ??
            (value
                ? AppStrings.confirmStart(changes.length)
                : AppStrings.confirmStop(changes.length)),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(c, false),
          child: const Text(AppStrings.cancel),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(c, true),
          child: const Text(AppStrings.confirm),
        ),
      ],
    ),
  );
  if (ok != true) return false;
  onProgress(0, changes.length);
  final failed = await ref
      .read(auditedWriterProvider)
      .writeAll(who: who, changes: changes, onProgress: onProgress);
  messenger.showSnackBar(
    SnackBar(
      content: Text(
        failed.isEmpty
            ? AppStrings.bulkDone(changes.length)
            : AppStrings.bulkPartial(
                changes.length - failed.length,
                failed.length,
              ),
      ),
    ),
  );
  return failed.isEmpty;
}
