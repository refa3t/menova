import 'package:flutter/material.dart';

import '../../../core/strings/app_strings.dart';
import '../../../core/theme/app_theme.dart';

/// Pill chip used for product groups (reference design).
class GroupChip extends StatelessWidget {
  const GroupChip({
    super.key,
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final fg = selected ? Colors.white : AppColors.text;
    return Material(
      color: selected ? AppColors.primary : AppColors.surface,
      shape: const StadiumBorder(),
      child: InkWell(
        onTap: onTap,
        customBorder: const StadiumBorder(),
        child: Container(
          height: 46,
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 20, color: fg),
              const SizedBox(width: 10),
              Text(label, style: TextStyle(color: fg)),
            ],
          ),
        ),
      ),
    );
  }
}

/// Menu failed to load: message and retry.
class MenuErrorView extends StatelessWidget {
  const MenuErrorView({super.key, required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(AppStrings.menuLoadError),
          const SizedBox(height: 12),
          FilledButton(onPressed: onRetry, child: Text(AppStrings.retry)),
        ],
      ),
    );
  }
}

/// A wooden board under a pizza preview (drawn in code; no photo yet).
class PreviewBoard extends StatelessWidget {
  const PreviewBoard({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 1,
      child: DecoratedBox(
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [Color(0xFFB98552), Color(0xFF8A5A33)],
          ),
          boxShadow: AppShadows.soft,
        ),
        child: Padding(padding: const EdgeInsets.all(14), child: child),
      ),
    );
  }
}
