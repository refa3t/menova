import 'json.dart';
import 'money.dart';

/// Admin-owned visibility of a developer-defined category.
class CategoryContent {
  const CategoryContent({
    required this.categoryId,
    required this.isVisible,
    required this.displayOrder,
  });

  final String categoryId;
  final bool isVisible;
  final int displayOrder;

  factory CategoryContent.fromJson(Json j) => CategoryContent(
    categoryId: req(j, 'categoryId'),
    isVisible: req(j, 'isVisible'),
    displayOrder: req(j, 'displayOrder'),
  );

  Json toJson() => {
    'categoryId': categoryId,
    'isVisible': isVisible,
    'displayOrder': displayOrder,
  };

  @override
  bool operator ==(Object other) =>
      other is CategoryContent &&
      other.categoryId == categoryId &&
      other.isVisible == isVisible &&
      other.displayOrder == displayOrder;

  @override
  int get hashCode => Object.hash(categoryId, isVisible, displayOrder);
}

class Product {
  const Product({
    required this.id,
    required this.categoryId,
    required this.name,
    required this.description,
    required this.basePrice,
    required this.imageAssetId,
    required this.defaults,
    required this.isAvailable,
    this.sizeDeltas = const {},
    this.optionDeltas = const {},
    this.displayOrder = 0,
  });

  final String id;
  final String categoryId;
  final String name;
  final String description;

  /// Always includes every default ingredient; a default is never an extra.
  final Piasters basePrice;
  final String imageAssetId;
  final List<ProductIngredient> defaults;
  final bool isAvailable;

  /// Price delta per supported size id.
  final Map<String, Piasters> sizeDeltas;

  /// Price delta per option choice id.
  final Map<String, Piasters> optionDeltas;
  final int displayOrder;

  factory Product.fromJson(Json j) => Product(
    id: req(j, 'id'),
    categoryId: req(j, 'categoryId'),
    name: req(j, 'name'),
    description: opt(j, 'description') ?? '',
    basePrice: req(j, 'basePrice'),
    imageAssetId: req(j, 'imageAssetId'),
    defaults: reqList(j, 'defaults', ProductIngredient.fromJson),
    isAvailable: req(j, 'isAvailable'),
    sizeDeltas: mapOf(j, 'sizeDeltas', toInt),
    optionDeltas: mapOf(j, 'optionDeltas', toInt),
    displayOrder: opt(j, 'displayOrder') ?? 0,
  );

  Json toJson() => {
    'id': id,
    'categoryId': categoryId,
    'name': name,
    'description': description,
    'basePrice': basePrice,
    'imageAssetId': imageAssetId,
    'defaults': [for (final d in defaults) d.toJson()],
    'isAvailable': isAvailable,
    'sizeDeltas': sizeDeltas,
    'optionDeltas': optionDeltas,
    'displayOrder': displayOrder,
  };

  @override
  bool operator ==(Object other) =>
      other is Product &&
      other.id == id &&
      other.categoryId == categoryId &&
      other.name == name &&
      other.description == description &&
      other.basePrice == basePrice &&
      other.imageAssetId == imageAssetId &&
      listEq(other.defaults, defaults) &&
      other.isAvailable == isAvailable &&
      mapEq(other.sizeDeltas, sizeDeltas) &&
      mapEq(other.optionDeltas, optionDeltas) &&
      other.displayOrder == displayOrder;

  @override
  int get hashCode => Object.hash(
    id,
    categoryId,
    name,
    description,
    basePrice,
    imageAssetId,
    Object.hashAll(defaults),
    isAvailable,
    mapHash(sizeDeltas),
    mapHash(optionDeltas),
    displayOrder,
  );
}

class ProductIngredient {
  const ProductIngredient({
    required this.ingredientId,
    required this.qty,
    required this.removable,
    this.refundOnRemove = false,
    this.refundAmount = 0,
  });

  final String ingredientId;
  final int qty;
  final bool removable;
  final bool refundOnRemove;
  final Piasters refundAmount;

  factory ProductIngredient.fromJson(Json j) => ProductIngredient(
    ingredientId: req(j, 'ingredientId'),
    qty: req(j, 'qty'),
    removable: req(j, 'removable'),
    refundOnRemove: opt(j, 'refundOnRemove') ?? false,
    refundAmount: opt(j, 'refundAmount') ?? 0,
  );

  Json toJson() => {
    'ingredientId': ingredientId,
    'qty': qty,
    'removable': removable,
    'refundOnRemove': refundOnRemove,
    'refundAmount': refundAmount,
  };

  @override
  bool operator ==(Object other) =>
      other is ProductIngredient &&
      other.ingredientId == ingredientId &&
      other.qty == qty &&
      other.removable == removable &&
      other.refundOnRemove == refundOnRemove &&
      other.refundAmount == refundAmount;

  @override
  int get hashCode =>
      Object.hash(ingredientId, qty, removable, refundOnRemove, refundAmount);
}

class Ingredient {
  const Ingredient({
    required this.id,
    required this.name,
    required this.assetId,
    required this.extraPrice,
    required this.isAvailable,
    this.sizeMultipliers = const {},
  });

  final String id;
  final String name;
  final String assetId;
  final Piasters extraPrice;
  final bool isAvailable;

  /// Extra-price multiplier per size id; missing sizes default to 1.
  final Map<String, double> sizeMultipliers;

  double multiplierFor(String? sizeId) =>
      sizeId == null ? 1 : sizeMultipliers[sizeId] ?? 1;

  factory Ingredient.fromJson(Json j) => Ingredient(
    id: req(j, 'id'),
    name: req(j, 'name'),
    assetId: req(j, 'assetId'),
    extraPrice: req(j, 'extraPrice'),
    isAvailable: req(j, 'isAvailable'),
    sizeMultipliers: mapOf(j, 'sizeMultipliers', toDouble),
  );

  Json toJson() => {
    'id': id,
    'name': name,
    'assetId': assetId,
    'extraPrice': extraPrice,
    'isAvailable': isAvailable,
    'sizeMultipliers': sizeMultipliers,
  };

  @override
  bool operator ==(Object other) =>
      other is Ingredient &&
      other.id == id &&
      other.name == name &&
      other.assetId == assetId &&
      other.extraPrice == extraPrice &&
      other.isAvailable == isAvailable &&
      mapEq(other.sizeMultipliers, sizeMultipliers);

  @override
  int get hashCode => Object.hash(
    id,
    name,
    assetId,
    extraPrice,
    isAvailable,
    mapHash(sizeMultipliers),
  );
}

/// Asset record. `publicId`/`secureUrl`/`version` are content as returned by
/// Cloudinary (the source of truth); the rest is structural.
class Asset {
  const Asset({
    required this.id,
    required this.kind,
    required this.name,
    required this.publicId,
    required this.secureUrl,
    required this.version,
    required this.layerOrder,
    required this.allowedCategoryIds,
    this.variants = const [],
    this.placementRef,
    this.adminReplaceable = false,
  });

  final String id;

  /// Asset kind matching a definition `assetSpecs` key.
  final String kind;
  final String name;
  final String publicId;
  final String secureUrl;
  final int version;

  /// Secure URLs of extra shape variants of the same piece, for scattering.
  final List<String> variants;
  final int layerOrder;
  final String? placementRef;
  final List<String> allowedCategoryIds;
  final bool adminReplaceable;

  factory Asset.fromJson(Json j) => Asset(
    id: req(j, 'id'),
    kind: req(j, 'kind'),
    name: req(j, 'name'),
    publicId: req(j, 'publicId'),
    secureUrl: req(j, 'secureUrl'),
    version: req(j, 'version'),
    variants: strList(j, 'variants'),
    layerOrder: req(j, 'layerOrder'),
    placementRef: opt(j, 'placementRef'),
    allowedCategoryIds: strList(j, 'allowedCategoryIds'),
    adminReplaceable: opt(j, 'adminReplaceable') ?? false,
  );

  Json toJson() => {
    'id': id,
    'kind': kind,
    'name': name,
    'publicId': publicId,
    'secureUrl': secureUrl,
    'version': version,
    'variants': variants,
    'layerOrder': layerOrder,
    if (placementRef != null) 'placementRef': placementRef,
    'allowedCategoryIds': allowedCategoryIds,
    'adminReplaceable': adminReplaceable,
  };

  @override
  bool operator ==(Object other) =>
      other is Asset &&
      other.id == id &&
      other.kind == kind &&
      other.name == name &&
      other.publicId == publicId &&
      other.secureUrl == secureUrl &&
      other.version == version &&
      listEq(other.variants, variants) &&
      other.layerOrder == layerOrder &&
      other.placementRef == placementRef &&
      listEq(other.allowedCategoryIds, allowedCategoryIds) &&
      other.adminReplaceable == adminReplaceable;

  @override
  int get hashCode => Object.hash(
    id,
    kind,
    name,
    publicId,
    secureUrl,
    version,
    Object.hashAll(variants),
    layerOrder,
    placementRef,
    Object.hashAll(allowedCategoryIds),
    adminReplaceable,
  );
}
