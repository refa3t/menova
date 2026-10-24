import '../models/json.dart';
import '../models/money.dart';
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

  int get qty => price.itemQty;

  factory OrderItem.fromJson(Json j) => OrderItem(
    lineId: req(j, 'lineId'),
    selection: Selection.fromJson(req(j, 'selection')),
    price: PriceBreakdown.fromJson(req(j, 'price')),
    productName: req(j, 'productName'),
    sizeName: opt(j, 'sizeName'),
    optionNames: mapOf(j, 'optionNames', (v) => v as String),
    ingredientNames: mapOf(j, 'ingredientNames', (v) => v as String),
  );

  Json toJson() => {
    'lineId': lineId,
    'selection': selection.toJson(),
    'price': price.toJson(),
    'productName': productName,
    if (sizeName != null) 'sizeName': sizeName,
    'optionNames': optionNames,
    'ingredientNames': ingredientNames,
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
      mapEq(other.ingredientNames, ingredientNames);

  @override
  int get hashCode => Object.hash(
    lineId,
    selection,
    price,
    productName,
    sizeName,
    mapHash(optionNames),
    mapHash(ingredientNames),
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
  });

  final String name;
  final String phone;
  final Fulfillment fulfillment;
  final String? address;

  factory GuestCustomer.fromJson(Json j) => GuestCustomer(
    name: req(j, 'name'),
    phone: req(j, 'phone'),
    fulfillment: Fulfillment.values.byName(req(j, 'fulfillment')),
    address: opt(j, 'address'),
  );

  Json toJson() => {
    'name': name,
    'phone': phone,
    'fulfillment': fulfillment.name,
    if (address != null) 'address': address,
  };

  @override
  bool operator ==(Object other) =>
      other is GuestCustomer &&
      other.name == name &&
      other.phone == phone &&
      other.fulfillment == fulfillment &&
      other.address == address;

  @override
  int get hashCode => Object.hash(name, phone, fulfillment, address);
}

/// Who changed an order or payment status, and when (CLAUDE.md 5.3).
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
      listEq(other.history, history);

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
  );
}
