import 'package:animation/animation.dart';
import 'package:core/core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:product_builder/product_builder.dart';

import '../../../core/strings/app_strings.dart';
import '../../cart/presentation/cart_button.dart';
import '../../cart/presentation/cart_providers.dart';
import '../../menu/domain/menu.dart';
import '../../menu/presentation/menu_providers.dart';
import '../../menu/presentation/product_preview.dart';
import 'builder_providers.dart';
import 'price_providers.dart';
import 'widgets/add_bar.dart';
import 'widgets/choice_selectors.dart';
import 'widgets/ingredient_grid.dart';
import 'widgets/notes_field.dart';

/// The orchestrator screen: wires the builder, pricing and animation
/// engines to the UI and the cart, with no category logic (ARC-03).
class BuilderScreen extends ConsumerStatefulWidget {
  const BuilderScreen({super.key, required this.productId, this.lineId});

  final String productId;

  /// Cart line being edited, if any (AC-18).
  final String? lineId;

  @override
  ConsumerState<BuilderScreen> createState() => _BuilderScreenState();
}

class _BuilderScreenState extends ConsumerState<BuilderScreen> {
  final _canvasKey = GlobalKey();
  final _cartKey = GlobalKey();
  OverlayEntry? _animation;
  AddStatus _status = AddStatus.idle;

  BuilderKey get _key => (productId: widget.productId, lineId: widget.lineId);

  bool _exists(Menu menu) => menu.categories.any(
    (c) => c.products.any((p) => p.id == widget.productId),
  );

  @override
  void dispose() {
    // Leaving mid-animation cancels it; the cart item is already committed.
    _animation?.remove();
    _animation = null;
    super.dispose();
  }

  /// Adds the item (or updates the edited line) in one atomic step BEFORE
  /// any animation (ARC-07). The button stays locked while the sequence
  /// runs, so repeated taps add a single item (AC-16).
  void _commit() {
    if (_status != AddStatus.idle) return;
    final state = ref.read(builderProvider(_key));
    final cart = ref.read(cartProvider.notifier);
    if (widget.lineId != null &&
        ref.read(cartProvider).line(widget.lineId!) != null) {
      cart.replace(widget.lineId!, state.selection);
      context.pop();
      return;
    }
    cart.add(state.selection);
    setState(() => _status = AddStatus.busy);
    if (!_playSequence(state)) _finish();
  }

  void _finish() {
    if (!mounted) return;
    setState(() => _status = AddStatus.done);
    Future<void>.delayed(const Duration(milliseconds: 1200), () {
      if (mounted) setState(() => _status = AddStatus.idle);
    });
  }

  /// Runs the category's add-to-cart sequence over the screen. Display
  /// only: a failure or cancellation never touches the cart (ARC-05).
  bool _playSequence(BuilderState state) {
    final overlay = Overlay.maybeOf(context);
    final menu = ref.read(menuProvider).value;
    final canvasBox =
        _canvasKey.currentContext?.findRenderObject() as RenderBox?;
    final overlayBox = overlay?.context.findRenderObject() as RenderBox?;
    if (overlay == null ||
        menu == null ||
        canvasBox == null ||
        overlayBox == null ||
        !canvasBox.hasSize) {
      return false;
    }
    Rect rectOf(RenderBox box) =>
        box.localToGlobal(Offset.zero, ancestor: overlayBox) & box.size;
    final cartBox = _cartKey.currentContext?.findRenderObject() as RenderBox?;
    final def = state.definition;

    // The customer's product exactly as built, frozen at the press.
    final snapshot = ProductPreview(
      menu: menu,
      definition: def,
      product: state.product,
      selection: state.selection,
    );
    final images = <String, List<String>>{
      for (final s in def.animation)
        if (s.params['images'] case final Map roles)
          for (final e in roles.entries)
            if (menu.assets[e.value] case final a?)
              '${e.key}': [a.secureUrl, ...a.variants],
    };
    final sequence = StepSequence.fromDefinition(def);
    final plan = planSequence(
      sequence: sequence,
      registry: animSteps,
      total: sequenceDuration(sequence, const Duration(milliseconds: 2000)),
      reduceMotion: MediaQuery.of(context).disableAnimations,
    );
    if (plan.steps.isEmpty) return false;
    final entry = OverlayEntry(
      builder: (_) => StepRunner(
        steps: plan.steps,
        total: plan.total,
        input: AnimStepInput(
          product: snapshot,
          productRect: rectOf(canvasBox),
          cartTarget: cartBox == null ? null : rectOf(cartBox).center,
          images: images,
          reduceMotion: MediaQuery.of(context).disableAnimations,
        ),
        onEvent: (e) {
          if (e == AnimEvent.completed) {
            _animation?.remove();
            _animation = null;
            _finish();
          }
        },
      ),
    );
    _animation = entry;
    overlay.insert(entry);
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final menu = ref.watch(menuProvider);
    return Scaffold(
      appBar: AppBar(actions: [CartButton(key: _cartKey)]),
      bottomNavigationBar: menu.hasValue && _exists(menu.requireValue)
          ? Consumer(
              builder: (context, ref, _) => AddBar(
                total: ref.watch(priceProvider(_key))?.total,
                label: widget.lineId == null
                    ? AppStrings.add
                    : AppStrings.update,
                status: _status,
                onAdd: _commit,
              ),
            )
          : null,
      body: menu.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => const Center(child: Text(AppStrings.menuLoadError)),
        data: (menu) {
          if (!_exists(menu)) {
            return const Center(child: Text(AppStrings.productNotFound));
          }
          return _BuilderBody(
            menu: menu,
            builderKey: _key,
            canvasKey: _canvasKey,
          );
        },
      ),
    );
  }
}

class _BuilderBody extends ConsumerStatefulWidget {
  const _BuilderBody({
    required this.menu,
    required this.builderKey,
    required this.canvasKey,
  });

  final Menu menu;
  final BuilderKey builderKey;

  /// Marks the canvas so the orchestrator can start the animation from it.
  final GlobalKey canvasKey;

  @override
  ConsumerState<_BuilderBody> createState() => _BuilderBodyState();
}

class _BuilderBodyState extends ConsumerState<_BuilderBody> {
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Precache every asset of the category when the product opens (5.6), so
    // added ingredients appear without a loading gap.
    final def = ref.read(builderProvider(widget.builderKey)).definition;
    final urls = <String>{
      for (final id in def.allowedIngredientIds)
        if (widget.menu.ingredients[id] case final i?)
          if (widget.menu.assets[i.assetId] case final a?) ...[
            a.secureUrl,
            ...a.variants,
          ],
      for (final a in widget.menu.assets.values)
        if ((a.kind == 'base' || a.kind == 'animation') &&
            a.allowedCategoryIds.contains(def.id)) ...[
          a.secureUrl,
          ...a.variants,
        ],
    };
    for (final url in urls) {
      precacheImage(NetworkImage(url), context, onError: (_, _) {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final menu = widget.menu;
    final state = ref.watch(builderProvider(widget.builderKey));
    final controller = ref.read(builderProvider(widget.builderKey).notifier);
    final def = state.definition;
    final strategy = placementStrategies[def.placement.strategy];
    final base = menu.assets[state.activeBase.rawAssetId];
    if (strategy == null || base == null) {
      return const Center(child: Text(AppStrings.productNotFound));
    }

    List<String> urlsFor(Ingredient i) {
      final a = menu.assets[i.assetId];
      return a == null ? const [] : [a.secureUrl, ...a.variants];
    }

    // Everything that can be drawn (the canvas needs any selected piece).
    final available = [
      for (final id in def.allowedIngredientIds)
        if (menu.ingredients[id] case final i? when urlsFor(i).isNotEmpty) i,
    ];
    // The grid offers this product's own ingredients only (owner request),
    // plus anything already selected, e.g. an extra on an edited cart line.
    final productIds = {for (final d in state.product.defaults) d.ingredientId};
    final gridItems = [
      for (final i in available)
        if (productIds.contains(i.id) || state.qtyOf(i.id) > 0) i,
    ];

    void report(BuilderRejection? r) {
      final message = switch (r) {
        null => null,
        BuilderRejection.maxQty => AppStrings.maxQtyReached,
        BuilderRejection.notRemovable => AppStrings.notRemovable,
        BuilderRejection.unavailable => AppStrings.unavailable,
        BuilderRejection.notAllowed ||
        BuilderRejection.unknownChoice => AppStrings.notAllowed,
      };
      if (message == null) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(message)));
    }

    final canvas = Padding(
      padding: const EdgeInsets.all(16),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: BuilderCanvas(
          key: widget.canvasKey,
          baseImageUrl: base.secureUrl,
          strategy: strategy,
          placementParams: def.placement.params,
          scale: state.sizeScale,
          density: state.sizeDensity,
          layers: [
            for (final i in available)
              CanvasLayer(
                ingredientId: i.id,
                imageUrls: urlsFor(i),
                enterProfile:
                    def.ingredientMotion[i.id]?.enter ?? defaultEnterProfile,
                exitProfile:
                    def.ingredientMotion[i.id]?.exit ?? defaultExitProfile,
                qty: state.qtyOf(i.id),
                layerOrder:
                    def.layerOverrides[i.id] ??
                    menu.assets[i.assetId]!.layerOrder,
              ),
          ],
        ),
      ),
    );

    final controls = <Widget>[
      Text(
        state.product.name,
        style: Theme.of(context).textTheme.headlineSmall,
      ),
      const SizedBox(height: 16),
      SizeSelector(
        sizes: def.sizes,
        selectedId: state.selection.sizeId,
        onSelected: (id) => report(controller.selectSize(id)),
      ),
      for (final g in def.optionGroups) ...[
        const SizedBox(height: 16),
        OptionGroupSelector(
          group: g,
          selectedId: state.selection.options[g.id],
          onSelected: (id) => report(controller.selectOption(g.id, id)),
        ),
      ],
      const SizedBox(height: 20),
      Text(
        AppStrings.ingredients,
        style: Theme.of(context).textTheme.titleMedium,
      ),
      const SizedBox(height: 8),
      IngredientGrid(
        items: [
          for (final i in gridItems)
            IngredientTileData(
              id: i.id,
              name: i.name,
              imageUrl: urlsFor(i).first,
              qty: state.qtyOf(i.id),
              defaultQty: state.defaultQtyOf(i.id),
              canRemove: state.canRemove(i.id),
            ),
        ],
        onAdd: (id) => report(controller.add(id)),
        onRemove: (id) => report(controller.remove(id)),
      ),
      const SizedBox(height: 16),
      NotesField(
        initial: state.selection.notes,
        onChanged: controller.setNotes,
      ),
      const SizedBox(height: 12),
      OutlinedButton(
        onPressed: state.isModified ? controller.reset : null,
        style: OutlinedButton.styleFrom(minimumSize: const Size(44, 44)),
        child: const Text(AppStrings.reset),
      ),
    ];

    return LayoutBuilder(
      builder: (context, box) {
        // Narrow screens scroll as one page so the controls are never
        // squeezed out by the canvas.
        if (box.maxWidth >= 840) {
          return Row(
            children: [
              Expanded(flex: 3, child: Center(child: canvas)),
              Expanded(
                flex: 2,
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: controls,
                ),
              ),
            ],
          );
        }
        return ListView(
          padding: const EdgeInsets.only(bottom: 24),
          children: [
            Center(child: canvas),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: controls,
              ),
            ),
          ],
        );
      },
    );
  }
}
