import '../models/json.dart';
import '../models/money.dart';

enum PriceLineKind { base, size, option, extra, refund }

/// One line of a price breakdown. `amount` is signed (refunds negative).
class PriceLine {
  const PriceLine({
    required this.kind,
    required this.amount,
    this.refId,
    this.qty = 1,
  });

  final PriceLineKind kind;

  /// Size, option choice or ingredient id the line refers to.
  final String? refId;
  final int qty;
  final Piasters amount;

  factory PriceLine.fromJson(Json j) => PriceLine(
    kind: PriceLineKind.values.byName(req(j, 'kind')),
    refId: opt(j, 'refId'),
    qty: opt(j, 'qty') ?? 1,
    amount: req(j, 'amount'),
  );

  Json toJson() => {
    'kind': kind.name,
    if (refId != null) 'refId': refId,
    'qty': qty,
    'amount': amount,
  };

  @override
  bool operator ==(Object other) =>
      other is PriceLine &&
      other.kind == kind &&
      other.refId == refId &&
      other.qty == qty &&
      other.amount == amount;

  @override
  int get hashCode => Object.hash(kind, refId, qty, amount);
}

/// Output of the pricing engine for one item (CLAUDE.md 4.2, 5.1).
/// Stored as a frozen snapshot inside each order item (SEC-03).
class PriceBreakdown {
  const PriceBreakdown({
    required this.lines,
    required this.unitSubtotal,
    required this.itemQty,
    required this.rounding,
    required this.total,
    required this.ruleVersion,
  });

  /// Lines for a single unit of the item.
  final List<PriceLine> lines;

  /// Sum of [lines], before quantity and rounding.
  final Piasters unitSubtotal;
  final int itemQty;

  /// Adjustment applied once on the final item total.
  final Piasters rounding;
  final Piasters total;
  final int ruleVersion;

  factory PriceBreakdown.fromJson(Json j) => PriceBreakdown(
    lines: reqList(j, 'lines', PriceLine.fromJson),
    unitSubtotal: req(j, 'unitSubtotal'),
    itemQty: req(j, 'itemQty'),
    rounding: req(j, 'rounding'),
    total: req(j, 'total'),
    ruleVersion: req(j, 'ruleVersion'),
  );

  Json toJson() => {
    'lines': [for (final l in lines) l.toJson()],
    'unitSubtotal': unitSubtotal,
    'itemQty': itemQty,
    'rounding': rounding,
    'total': total,
    'ruleVersion': ruleVersion,
  };

  @override
  bool operator ==(Object other) =>
      other is PriceBreakdown &&
      listEq(other.lines, lines) &&
      other.unitSubtotal == unitSubtotal &&
      other.itemQty == itemQty &&
      other.rounding == rounding &&
      other.total == total &&
      other.ruleVersion == ruleVersion;

  @override
  int get hashCode => Object.hash(
    Object.hashAll(lines),
    unitSubtotal,
    itemQty,
    rounding,
    total,
    ruleVersion,
  );
}
