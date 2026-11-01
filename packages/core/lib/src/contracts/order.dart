import '../models/json.dart';
import '../models/money.dart';
import '../models/offer.dart';
import '../models/store_settings.dart';
import 'price_breakdown.dart';
import 'selection.dart';

/// A cart line as sent to and stored by the order flow (CLAUDE.md 4.2):
/// the selection plus a frozen price snapshot and frozen display names.
class OrderItem {
  const OrderItem({
    required this.lineId,
    required this.selection,
    required this.price,
    required this.productName,
    this.sizeName,
    this.optionNames = const {},
    this.ingredientNames = const {},
    this.defaultQty = const {},
  });

  /// Stable id of the cart line (editing a line keeps it).
  final String lineId;
  final Selection selection;
  final PriceBreakdown price;
  final String productName;
  final String? sizeName;

  /// Choice name per option choice id.
  final Map<String, String> optionNames;

  /// Name per ingredient id, for every ingredient shown on the ticket.
  final Map<String, String> ingredientNames;

  /// Frozen default quantity per ingredient at order time, so the kitchen
  /// sees exactly what was added and removed even if the product changes.
  final Map<String, int> defaultQty;

  int get qty => price.itemQty;

  /// Quantity above the default per ingredient.
  Map<String, int> get extras => {
    for (final e in selection.ingredients.entries)
      if (e.value > (defaultQty[e.key] ?? 0))
        e.key: e.value - (defaultQty[e.key] ?? 0),
  };

  /// Defaults fully removed ("بدون X").
  List<String> get removed => [
    for (final e in defaultQty.entries)
      if (selection.qtyOf(e.key) == 0) e.key,
  ];

  /// Defaults kept (up to their default quantity).
  Map<String, int> get kept => {
    for (final e in defaultQty.entries)
      if (selection.qtyOf(e.key) > 0)
        e.key: selection.qtyOf(e.key) < e.value
            ? selection.qtyOf(e.key)
            : e.value,
  };

  factory OrderItem.fromJson(Json j) => OrderItem(
    lineId: req(j, 'lineId'),
    selection: Selection.fromJson(req(j, 'selection')),
    price: PriceBreakdown.fromJson(req(j, 'price')),
    productName: req(j, 'productName'),
    sizeName: opt(j, 'sizeName'),
    optionNames: mapOf(j, 'optionNames', (v) => v as String),
    ingredientNames: mapOf(j, 'ingredientNames', (v) => v as String),
    defaultQty: mapOf(j, 'defaultQty', toInt),
  );

  Json toJson() => {
    'lineId': lineId,
    'selection': selection.toJson(),
    'price': price.toJson(),
    'productName': productName,
    if (sizeName != null) 'sizeName': sizeName,
    'optionNames': optionNames,
    'ingredientNames': ingredientNames,
    'defaultQty': defaultQty,
  };

  @override
  bool operator ==(Object other) =>
      other is OrderItem &&
      other.lineId == lineId &&
      other.selection == selection &&
      other.price == price &&
      other.productName == productName &&
      other.sizeName == sizeName &&
      mapEq(other.optionNames, optionNames) &&
      mapEq(other.ingredientNames, ingredientNames) &&
      mapEq(other.defaultQty, defaultQty);

  @override
  int get hashCode => Object.hash(
    lineId,
    selection,
    price,
    productName,
    sizeName,
    mapHash(optionNames),
    mapHash(ingredientNames),
    mapHash(defaultQty),
  );
}

enum OrderStatus {
  newOrder('new'),
  accepted('accepted'),
  preparing('preparing'),
  ready('ready'),
  outForDelivery('out_for_delivery'),
  completed('completed'),
  cancelled('cancelled');

  const OrderStatus(this.wire);
  final String wire;

  static OrderStatus fromWire(String s) => values.firstWhere(
    (v) => v.wire == s,
    orElse: () => throw FormatException('Unknown order status "$s"'),
  );
}

enum PaymentStatus { unpaid, paid, refunded }

enum PaymentMethod { cash }

enum Fulfillment { pickup, delivery }

class GuestCustomer {
  const GuestCustomer({
    required this.name,
    required this.phone,
    required this.fulfillment,
    this.address,
    this.location,
    this.distanceMeters,
  });

  final String name;
  final String phone;
  final Fulfillment fulfillment;
  final String? address;

  /// Delivery only: where the guest is, and the road distance from the
  /// store the delivery fee was priced on.
  final LatLng? location;
  final int? distanceMeters;

  factory GuestCustomer.fromJson(Json j) => GuestCustomer(
    name: req(j, 'name'),
    phone: req(j, 'phone'),
    fulfillment: Fulfillment.values.byName(req(j, 'fulfillment')),
    address: opt(j, 'address'),
    location: j['location'] == null
        ? null
        : LatLng.fromJson(req(j, 'location')),
    distanceMeters: opt(j, 'distanceMeters'),
  );

  Json toJson() => {
    'name': name,
    'phone': phone,
    'fulfillment': fulfillment.name,
    if (address != null) 'address': address,
    if (location != null) 'location': location!.toJson(),
    if (distanceMeters != null) 'distanceMeters': distanceMeters,
  };

  @override
  bool operator ==(Object other) =>
      other is GuestCustomer &&
      other.name == name &&
      other.phone == phone &&
      other.fulfillment == fulfillment &&
      other.address == address &&
      other.location == location &&
      other.distanceMeters == distanceMeters;

  @override
  int get hashCode =>
      Object.hash(name, phone, fulfillment, address, location, distanceMeters);
}

class StatusChange {
  const StatusChange({
    required this.field,
    required this.value,
    required this.by,
    required this.at,
    this.reason,
  });

  /// `status` or `paymentStatus`.
  final String field;
  final String value;
  final String by;

  /// ISO-8601 UTC timestamp.
  final String at;
  final String? reason;

  factory StatusChange.fromJson(Json j) => StatusChange(
    field: req(j, 'field'),
    value: req(j, 'value'),
    by: req(j, 'by'),
    at: req(j, 'at'),
    reason: opt(j, 'reason'),
  );

  Json toJson() => {
    'field': field,
    'value': value,
    'by': by,
    'at': at,
    if (reason != null) 'reason': reason,
  };

  @override
  bool operator ==(Object other) =>
      other is StatusChange &&
      other.field == field &&
      other.value == value &&
      other.by == by &&
      other.at == at &&
      other.reason == reason;

  @override
  int get hashCode => Object.hash(field, value, by, at, reason);
}

/// The offer an order got, frozen at order time (SEC-03): enough to
/// recompute its discount (reception, SEC-02) whatever the offer becomes.
class OrderOffer {
  const OrderOffer({
    required this.id,
    required this.name,
    required this.kind,
    required this.value,
    this.categoryId,
    this.minSubtotal = 0,
    this.maxDiscount,
    this.code,
  });

  factory OrderOffer.of(Offer o) => OrderOffer(
    id: o.id,
    name: o.name,
    kind: o.kind,
    value: o.value,
    categoryId: o.categoryId,
    minSubtotal: o.minSubtotal,
    maxDiscount: o.maxDiscount,
    code: o.code,
  );

  final String id;
  final String name;
  final OfferKind kind;
  final int value;
  final String? categoryId;
  final Piasters minSubtotal;
  final Piasters? maxDiscount;

  /// Set when the offer was a coupon.
  final String? code;

  /// The offer as it was when ordered, to recompute the discount.
  Offer get asOffer => Offer(
    id: id,
    name: name,
    kind: kind,
    value: value,
    categoryId: categoryId,
    minSubtotal: minSubtotal,
    maxDiscount: maxDiscount,
    code: code,
  );

  factory OrderOffer.fromJson(Json j) => OrderOffer(
    id: req(j, 'id'),
    name: req(j, 'name'),
    kind: OfferKind.values.byName(req(j, 'kind')),
    value: req(j, 'value'),
    categoryId: opt(j, 'categoryId'),
    minSubtotal: opt(j, 'minSubtotal') ?? 0,
    maxDiscount: opt(j, 'maxDiscount'),
    code: opt(j, 'code'),
  );

  /// Every field, nulls included: the Firestore rules compare them with
  /// the offer.
  Json toJson() => {
    'id': id,
    'name': name,
    'kind': kind.name,
    'value': value,
    'categoryId': categoryId,
    'minSubtotal': minSubtotal,
    'maxDiscount': maxDiscount,
    'code': code,
  };

  @override
  bool operator ==(Object other) =>
      other is OrderOffer &&
      other.id == id &&
      other.name == name &&
      other.kind == kind &&
      other.value == value &&
      other.categoryId == categoryId &&
      other.minSubtotal == minSubtotal &&
      other.maxDiscount == maxDiscount &&
      other.code == code;

  @override
  int get hashCode => Object.hash(
    id,
    name,
    kind,
    value,
    categoryId,
    minSubtotal,
    maxDiscount,
    code,
  );
}

/// A confirmed order. Written by the server only (SEC-01).
class Order {
  const Order({
    required this.id,
    required this.requestId,
    required this.payloadHash,
    required this.customerUid,
    required this.customer,
    required this.items,
    required this.status,
    required this.paymentStatus,
    required this.paymentMethod,
    required this.deliveryFee,
    required this.total,
    required this.definitionVersions,
    required this.rulesVersion,
    required this.createdAt,
    this.notes = '',
    this.history = const [],
    this.discount = 0,
    this.offer,
  });

  final String id;
  final String requestId;
  final String payloadHash;

  /// Anonymous auth uid of the guest, for reading their own order.
  final String customerUid;
  final GuestCustomer customer;
  final List<OrderItem> items;
  final OrderStatus status;
  final PaymentStatus paymentStatus;
  final PaymentMethod paymentMethod;
  final Piasters deliveryFee;

  /// Snapshot computed by the server; never trusted from a client (SEC-02).
  final Piasters total;

  /// Taken off by [offer], 0 without one: total = items − discount + fee.
  final Piasters discount;

  /// The one offer applied (P3-09), frozen; null for none.
  final OrderOffer? offer;

  /// The items' frozen totals, before any discount and delivery.
  Piasters get itemsTotal => items.fold(0, (s, i) => s + i.price.total);

  /// Definition version per category id at order time.
  final Map<String, int> definitionVersions;
  final int rulesVersion;

  /// ISO-8601 UTC timestamp.
  final String createdAt;
  final String notes;
  final List<StatusChange> history;

  factory Order.fromJson(Json j) => Order(
    id: req(j, 'id'),
    requestId: req(j, 'requestId'),
    payloadHash: req(j, 'payloadHash'),
    customerUid: req(j, 'customerUid'),
    customer: GuestCustomer.fromJson(req(j, 'customer')),
    items: reqList(j, 'items', OrderItem.fromJson),
    status: OrderStatus.fromWire(req(j, 'status')),
    paymentStatus: PaymentStatus.values.byName(req(j, 'paymentStatus')),
    paymentMethod: PaymentMethod.values.byName(req(j, 'paymentMethod')),
    deliveryFee: req(j, 'deliveryFee'),
    total: req(j, 'total'),
    definitionVersions: mapOf(j, 'definitionVersions', toInt),
    rulesVersion: req(j, 'rulesVersion'),
    createdAt: req(j, 'createdAt'),
    notes: opt(j, 'notes') ?? '',
    history: j['history'] == null
        ? const []
        : reqList(j, 'history', StatusChange.fromJson),
    discount: opt(j, 'discount') ?? 0,
    offer: j['offer'] == null ? null : OrderOffer.fromJson(req(j, 'offer')),
  );

  Json toJson() => {
    'id': id,
    'requestId': requestId,
    'payloadHash': payloadHash,
    'customerUid': customerUid,
    'customer': customer.toJson(),
    'items': [for (final i in items) i.toJson()],
    'status': status.wire,
    'paymentStatus': paymentStatus.name,
    'paymentMethod': paymentMethod.name,
    'deliveryFee': deliveryFee,
    'total': total,
    'definitionVersions': definitionVersions,
    'rulesVersion': rulesVersion,
    'createdAt': createdAt,
    'notes': notes,
    'history': [for (final h in history) h.toJson()],
    // Only with an offer: an order without one keeps its earlier shape.
    if (offer != null) ...{'discount': discount, 'offer': offer!.toJson()},
  };

  @override
  bool operator ==(Object other) =>
      other is Order &&
      other.id == id &&
      other.requestId == requestId &&
      other.payloadHash == payloadHash &&
      other.customerUid == customerUid &&
      other.customer == customer &&
      listEq(other.items, items) &&
      other.status == status &&
      other.paymentStatus == paymentStatus &&
      other.paymentMethod == paymentMethod &&
      other.deliveryFee == deliveryFee &&
      other.total == total &&
      mapEq(other.definitionVersions, definitionVersions) &&
      other.rulesVersion == rulesVersion &&
      other.createdAt == createdAt &&
      other.notes == notes &&
      listEq(other.history, history) &&
      other.discount == discount &&
      other.offer == offer;

  @override
  int get hashCode => Object.hash(
    id,
    requestId,
    payloadHash,
    customerUid,
    customer,
    Object.hashAll(items),
    status,
    paymentStatus,
    paymentMethod,
    deliveryFee,
    total,
    mapHash(definitionVersions),
    rulesVersion,
    createdAt,
    notes,
    Object.hashAll(history),
    discount,
    offer,
  );
}
