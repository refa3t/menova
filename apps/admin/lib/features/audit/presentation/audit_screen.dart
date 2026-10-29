import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/strings/app_strings.dart';
import '../domain/audit_entry.dart';

/// The latest admin changes, newest first (P3-07). Read-only: the rules
/// never let anyone edit or delete an entry, and only the owner reads them.
final auditProvider = StreamProvider<List<AuditEntry>>(
  (ref) => FirebaseFirestore.instance
      .collection('auditLog')
      .orderBy('at', descending: true)
      .limit(200)
      .snapshots()
      .map(
        (s) => [
          for (final d in s.docs)
            AuditEntry(
              id: d.id,
              action: d['action'] as String,
              target: d['target'] as String,
              by: d['by'] as String,
              byEmail: d.data()['byEmail'] as String?,
              at: (d.data()['at'] as Timestamp?)?.toDate(),
              before: (d.data()['before'] as Map?)?.cast<String, dynamic>(),
              after: (d.data()['after'] as Map).cast<String, dynamic>(),
            ),
        ],
      ),
);

class AuditScreen extends ConsumerWidget {
  const AuditScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final entries = ref.watch(auditProvider);
    return Scaffold(
      appBar: AppBar(title: const Text(AppStrings.auditLog)),
      body: entries.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => const Center(child: Text(AppStrings.loadError)),
        data: (list) => list.isEmpty
            ? const Center(child: Text(AppStrings.auditEmpty))
            : ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  for (final e in list)
                    Card(
                      child: ExpansionTile(
                        title: Text(
                          '${AppStrings.action(e.action)} · '
                          '${(e.after['name'] as String?) ?? e.target}',
                        ),
                        subtitle: Text(
                          '${e.byEmail ?? e.by} · ${AppStrings.when(e.at)}',
                        ),
                        childrenPadding: const EdgeInsets.fromLTRB(
                          16,
                          0,
                          16,
                          12,
                        ),
                        expandedCrossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            e.target,
                            textDirection: TextDirection.ltr,
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                          for (final c in e.changes.entries)
                            Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Text(
                                '${c.key}: ${c.value.$1 ?? '—'} ← ${c.value.$2}',
                                textDirection: TextDirection.ltr,
                              ),
                            ),
                        ],
                      ),
                    ),
                ],
              ),
      ),
    );
  }
}
