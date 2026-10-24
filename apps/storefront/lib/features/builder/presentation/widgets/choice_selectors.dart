import 'package:core/core.dart';
import 'package:flutter/material.dart';

import '../../../../core/strings/app_strings.dart';

/// Size selector (P1-C01). Renders nothing when the category has no sizes.
class SizeSelector extends StatelessWidget {
  const SizeSelector({
    super.key,
    required this.sizes,
    required this.selectedId,
    required this.onSelected,
  });

  final List<SizeOption> sizes;
  final String? selectedId;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    if (sizes.isEmpty) return const SizedBox.shrink();
    return _Chips(
      items: [
        for (final s in sizes) (s.id, AppStrings.localized(s.name, s.names)),
      ],
      selectedId: selectedId,
      onSelected: onSelected,
    );
  }
}

/// Generic option group selector (P1-C02): dough is just one group. Renders
/// nothing when the group offers a single choice.
class OptionGroupSelector extends StatelessWidget {
  const OptionGroupSelector({
    super.key,
    required this.group,
    required this.selectedId,
    required this.onSelected,
  });

  final OptionGroup group;
  final String? selectedId;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    if (group.choices.length < 2) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          AppStrings.localized(group.name, group.names),
          style: Theme.of(context).textTheme.titleSmall,
        ),
        const SizedBox(height: 8),
        _Chips(
          items: [
            for (final c in group.choices)
              (c.id, AppStrings.localized(c.name, c.names)),
          ],
          selectedId: selectedId,
          onSelected: onSelected,
        ),
      ],
    );
  }
}

class _Chips extends StatelessWidget {
  const _Chips({
    required this.items,
    required this.selectedId,
    required this.onSelected,
  });

  final List<(String, String)> items;
  final String? selectedId;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final (id, name) in items)
          ChoiceChip(
            label: Text(name),
            selected: id == selectedId,
            materialTapTargetSize: MaterialTapTargetSize.padded,
            onSelected: (_) => onSelected(id),
          ),
      ],
    );
  }
}
