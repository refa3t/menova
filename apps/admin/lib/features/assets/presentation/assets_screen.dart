import 'package:category_definitions/category_definitions.dart';
import 'package:core/core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/strings/app_strings.dart';
import '../../auth/domain/admin_access.dart';
import '../../auth/presentation/auth_providers.dart';
import '../../catalog/data/audited_writer.dart';
import '../../catalog/data/catalog_providers.dart';
import '../data/cloudinary_uploader.dart';
import '../data/image_picker.dart';
import '../domain/inspect_image.dart';

final uploaderProvider = Provider<CloudinaryUploader>(
  (ref) => CloudinaryUploader(),
);

/// Product photos and ingredient images (P3-04): pick, check against the
/// kind's AssetSpec, preview, then upload as new files and switch the asset
/// to the new version in one audited write. A refused file changes nothing;
/// old files stay on Cloudinary. Bases and animation images are not here.
class AssetsScreen extends ConsumerStatefulWidget {
  const AssetsScreen({super.key});

  @override
  ConsumerState<AssetsScreen> createState() => _AssetsScreenState();
}

class _AssetsScreenState extends ConsumerState<AssetsScreen> {
  bool _busy = false;

  /// The spec of [kind] from the definitions (all categories share it).
  AssetSpec? _spec(String kind) {
    for (final d in ref.read(definitionsProvider).values) {
      if (d.assetSpecs[kind] case final s?) return s;
    }
    return null;
  }

  Future<void> _replace({
    required String kind,
    required bool multiple,
    required Json Function(List<UploadedFile> files) after,
    required String path,
    Json? before,
  }) async {
    final who = ref.read(adminAccessProvider).value;
    final spec = _spec(kind);
    if (who is! Granted || spec == null || _busy) return;
    final picked = await pickImages(multiple: multiple);
    if (picked.isEmpty || !mounted) return;
    final files = picked.take(5).toList();
    final checks = [for (final f in files) await inspectImage(f.bytes)];
    final issues = <String>{
      for (final c in checks)
        for (final i in validateAssetFile(c, spec))
          AppStrings.fileIssue(i.path, spec),
    };
    if (!mounted) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text(AppStrings.replaceTitle),
        content: SizedBox(
          width: 420,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final f in files)
                    Container(
                      width: 96,
                      height: 96,
                      padding: const EdgeInsets.all(4),
                      // A checkerboard-like backdrop shows transparency.
                      color: const Color(0xFFE6E0D8),
                      child: Image.memory(f.bytes, fit: BoxFit.contain),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              for (final i in issues)
                Text(
                  '• $i',
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text(AppStrings.cancel),
          ),
          FilledButton(
            onPressed: issues.isEmpty
                ? () => Navigator.pop(context, true)
                : null,
            child: const Text(AppStrings.confirmReplace),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    setState(() => _busy = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final uploader = ref.read(uploaderProvider);
      final uploaded = [
        for (final f in files) await uploader.upload(f.bytes, f.name),
      ];
      await ref
          .read(auditedWriterProvider)
          .write(
            who: who,
            action: 'replaceAsset',
            path: path,
            before: before,
            after: after(uploaded),
          );
      messenger.showSnackBar(
        const SnackBar(content: Text(AppStrings.replaced)),
      );
    } on Object {
      messenger.showSnackBar(
        const SnackBar(content: Text(AppStrings.uploadFailed)),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// A product's photo: replace its `final` asset, or create the first one.
  Future<void> _productPhoto(Product p, Asset? current) => _replace(
    kind: 'final',
    multiple: false,
    path: 'assets/${p.imageAssetId}',
    before: current?.toJson(),
    after: (files) => Asset(
      id: p.imageAssetId,
      kind: 'final',
      name: p.name,
      publicId: files.first.publicId,
      secureUrl: files.first.secureUrl,
      version: (current?.version ?? 0) + 1,
      layerOrder: current?.layerOrder ?? 0,
      allowedCategoryIds: current?.allowedCategoryIds ?? [p.categoryId],
      adminReplaceable: true,
    ).toJson(),
  );

  /// An ingredient image: the first file is the main image, the rest are
  /// piece variants. Structure (layer order, categories) stays as it was.
  Future<void> _ingredientImage(Asset current) => _replace(
    kind: 'ingredient',
    multiple: true,
    path: 'assets/${current.id}',
    before: current.toJson(),
    after: (files) => {
      ...current.toJson(),
      'publicId': files.first.publicId,
      'secureUrl': files.first.secureUrl,
      'version': current.version + 1,
      'variants': [for (final f in files.skip(1)) f.secureUrl],
    },
  );

  @override
  Widget build(BuildContext context) {
    final products = ref.watch(productsProvider).value;
    final assets = ref.watch(assetsProvider).value;
    final ingredients = ref.watch(ingredientsProvider).value ?? const {};
    final loading = products == null || assets == null;
    Widget thumb(String? url, {double size = 56}) => SizedBox.square(
      dimension: size,
      child: url == null
          ? const Icon(Icons.image_not_supported_outlined)
          : Image.network(
              url,
              errorBuilder: (_, _, _) =>
                  const Icon(Icons.broken_image_outlined),
            ),
    );
    final busy = _busy
        ? const LinearProgressIndicator()
        : const SizedBox(height: 4);

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text(AppStrings.images),
          bottom: const TabBar(
            tabs: [
              Tab(text: AppStrings.productPhotos),
              Tab(text: AppStrings.ingredientImages),
            ],
          ),
        ),
        body: loading
            ? const Center(child: CircularProgressIndicator())
            : TabBarView(
                children: [
                  ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      busy,
                      const Text(AppStrings.imagesNote),
                      const SizedBox(height: 8),
                      for (final p in products)
                        Card(
                          child: ListTile(
                            minTileHeight: 72,
                            leading: thumb(assets[p.imageAssetId]?.secureUrl),
                            title: Text(p.name),
                            subtitle: assets[p.imageAssetId] == null
                                ? const Text(AppStrings.noPhoto)
                                : null,
                            trailing: OutlinedButton(
                              onPressed: _busy
                                  ? null
                                  : () => _productPhoto(
                                      p,
                                      assets[p.imageAssetId],
                                    ),
                              child: Text(
                                assets[p.imageAssetId] == null
                                    ? AppStrings.uploadPhoto
                                    : AppStrings.replace,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                  ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      busy,
                      const Text(AppStrings.imagesNote),
                      const Text(AppStrings.variantsNote),
                      const SizedBox(height: 8),
                      for (final a in assets.values.where(
                        (a) => a.kind == 'ingredient',
                      ))
                        Card(
                          child: ListTile(
                            minTileHeight: 72,
                            leading: thumb(a.secureUrl),
                            title: Text(
                              [
                                    for (final i in ingredients.values)
                                      if (i.assetId == a.id)
                                        i.names['ar'] ?? i.name,
                                  ].firstOrNull ??
                                  a.name,
                            ),
                            subtitle: Wrap(
                              spacing: 4,
                              children: [
                                for (final v in a.variants) thumb(v, size: 28),
                              ],
                            ),
                            trailing: OutlinedButton(
                              onPressed: _busy
                                  ? null
                                  : () => _ingredientImage(a),
                              child: const Text(AppStrings.replace),
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
      ),
    );
  }
}
