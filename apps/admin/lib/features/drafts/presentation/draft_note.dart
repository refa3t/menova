import 'package:flutter/material.dart';

import '../../../core/strings/app_strings.dart';
import '../domain/draft.dart';

/// A pending draft of the record being edited: who saved it and when, and
/// a way to drop it (P3-09).
class DraftNote extends StatelessWidget {
  const DraftNote({super.key, required this.draft, required this.onDiscard});

  final Draft draft;
  final VoidCallback onDiscard;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Theme.of(context).colorScheme.tertiaryContainer,
      child: ListTile(
        leading: const Icon(Icons.edit_note),
        title: const Text(AppStrings.pendingDraft),
        subtitle: Text(
          '${draft.byEmail ?? draft.by ?? ''} · ${AppStrings.when(draft.at)}',
        ),
        trailing: TextButton(
          onPressed: onDiscard,
          child: const Text(AppStrings.discardDraft),
        ),
      ),
    );
  }
}
