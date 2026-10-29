/// Id for a new product: `<category>_<slug of its name>`, made unique among
/// [taken]. Arabic-only names fall back to a short counter-based id.
String newProductId({
  required String categoryId,
  required String name,
  required Set<String> taken,
}) {
  final slug = name
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
      .replaceAll(RegExp(r'^_+|_+$'), '');
  final stem = '${categoryId}_${slug.isEmpty ? 'item' : slug}';
  if (!taken.contains(stem)) return stem;
  for (var n = 2; ; n++) {
    final id = '${stem}_$n';
    if (!taken.contains(id)) return id;
  }
}
