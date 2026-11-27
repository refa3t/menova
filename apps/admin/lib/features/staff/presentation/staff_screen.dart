import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/strings/app_strings.dart';
import '../../auth/domain/admin_access.dart';
import '../../auth/presentation/auth_providers.dart';
import '../data/staff_repository.dart';
import '../domain/staff_member.dart';

/// The owner adds, re-roles and removes staff by email (P3-01). A record
/// grants its role once the person signs in with a verified email; the
/// owner and claim-based staff stay with tools/bin/set_staff_role.dart.
class StaffScreen extends ConsumerWidget {
  const StaffScreen({super.key});

  Future<void> _write(
    BuildContext context,
    WidgetRef ref,
    Future<void> Function(StaffRepository repo, Granted who) action,
  ) async {
    final who = ref.read(adminAccessProvider).value;
    if (who is! Granted) return;
    final messenger = ScaffoldMessenger.of(context);
    try {
      await action(ref.read(staffRepositoryProvider), who);
    } on Object {
      messenger.showSnackBar(
        const SnackBar(content: Text(AppStrings.saveFailed)),
      );
    }
  }

  Future<void> _add(
    BuildContext context,
    WidgetRef ref,
    List<StaffMember> current,
  ) async {
    final added = await showDialog<(String, String)>(
      context: context,
      builder: (context) =>
          _AddStaffDialog(taken: {for (final m in current) m.email}),
    );
    if (added == null || !context.mounted) return;
    final (email, role) = added;
    await _write(
      context,
      ref,
      (repo, who) => repo.save(who: who, email: email, role: role),
    );
  }

  Future<void> _remove(
    BuildContext context,
    WidgetRef ref,
    StaffMember m,
  ) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        content: Text(AppStrings.removeStaffConfirm(m.email)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text(AppStrings.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(AppStrings.removeStaff),
          ),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    await _write(context, ref, (repo, who) => repo.remove(who: who, member: m));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final members = ref.watch(staffMembersProvider);
    return Scaffold(
      appBar: AppBar(title: const Text(AppStrings.staff)),
      floatingActionButton: members.hasValue
          ? FloatingActionButton.extended(
              onPressed: () => _add(context, ref, members.value!),
              icon: const Icon(Icons.person_add_alt),
              label: const Text(AppStrings.addStaff),
            )
          : null,
      body: members.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => const Center(child: Text(AppStrings.loadError)),
        data: (list) => ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
          children: [
            const Text(AppStrings.staffNote),
            const SizedBox(height: 12),
            if (list.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Text(AppStrings.staffEmpty, textAlign: TextAlign.center),
              ),
            for (final m in list)
              Card(
                child: ListTile(
                  minTileHeight: 64,
                  title: Text(m.email, textDirection: TextDirection.ltr),
                  subtitle: m.addedByEmail == null
                      ? null
                      : Text(AppStrings.staffAddedBy(m.addedByEmail)),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      DropdownButton<String>(
                        value: grantableStaffRoles.contains(m.role)
                            ? m.role
                            : null,
                        items: [
                          for (final r in grantableStaffRoles)
                            DropdownMenuItem(
                              value: r,
                              child: Text(AppStrings.staffRoleName(r)),
                            ),
                        ],
                        onChanged: (r) => r == null || r == m.role
                            ? null
                            : _write(
                                context,
                                ref,
                                (repo, who) => repo.save(
                                  who: who,
                                  email: m.email,
                                  role: r,
                                  before: m,
                                ),
                              ),
                      ),
                      IconButton(
                        tooltip: AppStrings.removeStaff,
                        onPressed: () => _remove(context, ref, m),
                        icon: const Icon(Icons.person_remove_outlined),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _AddStaffDialog extends StatefulWidget {
  const _AddStaffDialog({required this.taken});

  final Set<String> taken;

  @override
  State<_AddStaffDialog> createState() => _AddStaffDialogState();
}

class _AddStaffDialogState extends State<_AddStaffDialog> {
  final _form = GlobalKey<FormState>();
  final _email = TextEditingController();
  String _role = grantableStaffRoles.first;

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_form.currentState!.validate()) return;
    Navigator.pop(context, (staffRecordId(_email.text), _role));
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text(AppStrings.addStaff),
      content: Form(
        key: _form,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: _email,
              autofocus: true,
              keyboardType: TextInputType.emailAddress,
              textDirection: TextDirection.ltr,
              decoration: const InputDecoration(labelText: AppStrings.email),
              validator: (v) {
                final email = v ?? '';
                if (!isValidStaffEmail(email)) return AppStrings.invalidEmail;
                if (widget.taken.contains(staffRecordId(email))) {
                  return AppStrings.staffAlreadyAdded;
                }
                return null;
              },
              onFieldSubmitted: (_) => _submit(),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _role,
              decoration: const InputDecoration(
                labelText: AppStrings.staffRole,
              ),
              items: [
                for (final r in grantableStaffRoles)
                  DropdownMenuItem(
                    value: r,
                    child: Text(AppStrings.staffRoleName(r)),
                  ),
              ],
              onChanged: (r) => setState(() => _role = r ?? _role),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text(AppStrings.cancel),
        ),
        FilledButton(onPressed: _submit, child: const Text(AppStrings.save)),
      ],
    );
  }
}
