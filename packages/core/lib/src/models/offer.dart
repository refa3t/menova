import 'json.dart';
import 'money.dart';

/// What an offer takes off (P3-09).
enum OfferKind {
  /// [Offer.value] percent of the eligible items.
  percent,

  /// [Offer.value] piasters off the eligible items.
  amount,

  /// The delivery fee.
  freeDelivery,
}

/// A discount set up in the admin panel (P3-09): automatic for every order
/// in its dates (Firestore `offers`), or a coupon the guest types (Firestore
/// `coupons`, keyed by its code). One offer per order, taken from the items
/// before delivery and never below zero (CLAUDE.md 5.1); free delivery takes
/// the fee instead (owner decision).
class Offer {
  const Offer({
    required this.id,
    required this.name,
    this.names = const {},
    required this.kind,
    this.value = 0,
    this.categoryId,
    this.minSubtotal = 0,
    this.maxDiscount,
    this.startsAtMs,
    this.endsAtMs,
    this.isActive = true,
    this.code,
    this.maxUses,
    this.uses = 0,
  });

  final String id;
  final String name;

  /// Display name per language code (UX-01).
  final Map<String, String> names;
  final OfferKind kind;

  /// Percent (1-100) for [OfferKind.percent], piasters for
  /// [OfferKind.amount], 0 for [OfferKind.freeDelivery].
  final int value;

  /// Only this category's items count; null for the whole order.
  final String? categoryId;

  /// The order's items must reach this to qualify; 0 for no minimum.
  final Piasters minSubtotal;

  /// The most a discount takes off; null for no cap.
  final Piasters? maxDiscount;

  /// When it runs, in epoch milliseconds; a null bound is open.
  final int? startsAtMs;
  final int? endsAtMs;
  final bool isActive;

  /// A coupon's code (also its document id); null for an automatic offer.
  final String? code;

  /// How many orders a coupon may serve in all (null: no limit), and how
  /// many it has served.
  final int? maxUses;
  final int uses;

  bool get isCoupon => code != null;

  String nameFor(String lang) => names[lang] ?? name;

  factory Offer.fromJson(Json j) => Offer(
    id: req(j, 'id'),
    name: req(j, 'name'),
    names: mapOf(j, 'names', (v) => v as String),
    kind: OfferKind.values.byName(req(j, 'kind')),
    value: opt(j, 'value') ?? 0,
    categoryId: opt(j, 'categoryId'),
    minSubtotal: opt(j, 'minSubtotal') ?? 0,
    maxDiscount: opt(j, 'maxDiscount'),
    startsAtMs: opt(j, 'startsAtMs'),
    endsAtMs: opt(j, 'endsAtMs'),
    isActive: opt(j, 'isActive') ?? true,
    code: opt(j, 'code'),
    maxUses: opt(j, 'maxUses'),
    uses: opt(j, 'uses') ?? 0,
  );

  /// Every field, nulls included: the Firestore rules compare them.
  Json toJson() => {
    'id': id,
    'name': name,
    'names': names,
    'kind': kind.name,
    'value': value,
    'categoryId': categoryId,
    'minSubtotal': minSubtotal,
    'maxDiscount': maxDiscount,
    'startsAtMs': startsAtMs,
    'endsAtMs': endsAtMs,
    'isActive': isActive,
    'code': code,
    'maxUses': maxUses,
    'uses': uses,
  };

  @override
  bool operator ==(Object other) =>
      other is Offer &&
      other.id == id &&
      other.name == name &&
      mapEq(other.names, names) &&
      other.kind == kind &&
      other.value == value &&
      other.categoryId == categoryId &&
      other.minSubtotal == minSubtotal &&
      other.maxDiscount == maxDiscount &&
      other.startsAtMs == startsAtMs &&
      other.endsAtMs == endsAtMs &&
      other.isActive == isActive &&
      other.code == code &&
      other.maxUses == maxUses &&
      other.uses == uses;

  @override
  int get hashCode => Object.hash(
    id,
    name,
    mapHash(names),
    kind,
    value,
    categoryId,
    minSubtotal,
    maxDiscount,
    startsAtMs,
    endsAtMs,
    isActive,
    code,
    maxUses,
    uses,
  );
}

/// A typed coupon code in the one form it is stored and looked up by
/// (`coupons/{code}`): no spaces, upper case, Latin digits. Null when it
/// cannot be a code (3 to 20 of A-Z, 0-9 and dashes).
String? couponCode(String typed) {
  const arabic = '٠١٢٣٤٥٦٧٨٩';
  final s = typed.replaceAll(RegExp(r'\s+'), '').toUpperCase().split('').map((
    c,
  ) {
    final i = arabic.indexOf(c);
    return i >= 0 ? '$i' : c;
  }).join();
  return RegExp(r'^[A-Z0-9-]{3,20}$').hasMatch(s) ? s : null;
}
