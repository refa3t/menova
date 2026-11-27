import 'package:core/core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/strings/app_strings.dart';
import '../../auth/domain/admin_access.dart';
import '../../auth/presentation/auth_providers.dart';
import '../data/audited_writer.dart';
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
    this.progress,
  });

  final int selected;
  final VoidCallback? onSelectAllShown;
  final VoidCallback onClear;
  final ValueChanged<bool> onSet;

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

/// Asks to confirm, then saves [changes] (each audited in its batch) and
/// reports the result. [onProgress] follows the save; returns true when
/// every change was saved.
Future<bool> runBulkAvailability({
  required BuildContext context,
  required WidgetRef ref,
  required bool value,
  required List<AuditedChange> changes,
  required void Function(int done, int total) onProgress,
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
        value
            ? AppStrings.confirmStart(changes.length)
            : AppStrings.confirmStop(changes.length),
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
