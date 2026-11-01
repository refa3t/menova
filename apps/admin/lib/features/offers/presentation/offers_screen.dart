import 'package:core/core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/strings/app_strings.dart';
import '../../auth/domain/admin_access.dart';
import '../../auth/presentation/auth_providers.dart';
import '../../catalog/data/audited_writer.dart';
import '../../catalog/data/catalog_providers.dart';
import '../data/offers_providers.dart';

/// Automatic offers and coupons (P3-09): what each gives and when, whether
/// it runs now, and a switch to stop or restart it (audited).
class OffersScreen extends ConsumerWidget {
  const OffersScreen({super.key});

  Future<void> _setActive(
    BuildContext context,
    WidgetRef ref,
    Offer o,
    bool on,
  ) async {
    final who = ref.read(adminAccessProvider).value;
    if (who is! Granted) return;
    final list = OfferList.of(o);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref
          .read(auditedWriterProvider)
          .write(
            who: who,
            action: list.action,
            path: list.pathOf(o),
            before: o.toJson(),
            after: {...o.toJson(), 'isActive': on},
          );
    } on Object {
      messenger.showSnackBar(
        const SnackBar(content: Text(AppStrings.saveFailed)),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final defs = ref.watch(definitionsProvider);
    final now = DateTime.now();

    Widget section(OfferList list) {
      final coupons = list == OfferList.coupons;
      final offers = ref.watch(offersProvider(list));
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      coupons ? AppStrings.coupons : AppStrings.autoOffers,
                      style: theme.textTheme.titleLarge,
                    ),
                    Text(
                      coupons
                          ? AppStrings.couponsNote
                          : AppStrings.autoOffersNote,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              FilledButton.tonalIcon(
                onPressed: () => context.push(
                  coupons ? '/offers/new?coupon=1' : '/offers/new',
                ),
                icon: const Icon(Icons.add),
                label: Text(
                  coupons ? AppStrings.newCoupon : AppStrings.newOffer,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          offers.when(
            loading: () => const LinearProgressIndicator(),
            error: (_, _) => const Text(AppStrings.loadError),
            data: (items) => items.isEmpty
                ? Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    child: Text(
                      coupons ? AppStrings.noCoupons : AppStrings.noOffers,
                    ),
                  )
                : Column(
                    children: [
                      for (final o in items)
                        Card(
                          child: ListTile(
                            title: Text(
                              o.isCoupon ? '${o.code} · ${o.name}' : o.name,
                            ),
                            subtitle: Text(
                              [
                                AppStrings.offerSummary(
                                  o,
                                  defs[o.categoryId]?.name,
                                ),
                                [
                                  AppStrings.offerState(o, now),
                                  if (o.isCoupon)
                                    AppStrings.usedTimes(o.uses, o.maxUses),
                                ].join(' · '),
                              ].join('\n'),
                            ),
                            isThreeLine: true,
                            trailing: Switch(
                              value: o.isActive,
                              onChanged: (on) =>
                                  _setActive(context, ref, o, on),
                            ),
                            onTap: () => context.push(
                              o.isCoupon
                                  ? '/offers/coupon/${o.id}'
                                  : '/offers/auto/${o.id}',
                            ),
                          ),
                        ),
                    ],
                  ),
          ),
        ],
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text(AppStrings.offers)),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 800),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              section(OfferList.auto),
              const SizedBox(height: 28),
              section(OfferList.coupons),
            ],
          ),
        ),
      ),
    );
  }
}
