import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/strings/app_strings.dart';
import '../data/sales_report_provider.dart';
import '../domain/sales_report.dart';

/// The owner's reports (P3-08): totals, daily and weekly sales, best sellers
/// and the most requested add-ons over the chosen period.
class ReportsScreen extends ConsumerStatefulWidget {
  const ReportsScreen({super.key});

  @override
  ConsumerState<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends ConsumerState<ReportsScreen> {
  var _days = 30;
  var _dailyTable = false;

  /// The last report shown: kept, dimmed, while another period loads.
  SalesReport? _shown;

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(salesReportProvider(_days));
    if (async.value case final r?) _shown = r;
    final loading = async.isLoading;
    // A failed read never leaves older figures on screen.
    final failed = async.hasError && !loading;
    final report = failed ? null : async.value ?? (loading ? _shown : null);
    void reload() => ref.invalidate(salesReportProvider(_days));

    return Scaffold(
      appBar: AppBar(
        title: const Text(AppStrings.reports),
        actions: [
          IconButton(
            tooltip: AppStrings.refresh,
            onPressed: loading ? null : reload,
            icon: const Icon(Icons.refresh),
          ),
        ],
        bottom: loading
            ? const PreferredSize(
                preferredSize: Size.fromHeight(4),
                child: LinearProgressIndicator(),
              )
            : null,
      ),
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1000),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // One row of filters above everything they scope.
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: SegmentedButton<int>(
                  segments: [
                    for (final d in reportPeriods)
                      ButtonSegment(
                        value: d,
                        label: Text(AppStrings.lastDaysLabel(d)),
                      ),
                  ],
                  selected: {_days},
                  showSelectedIcon: false,
                  onSelectionChanged: (s) => setState(() => _days = s.first),
                ),
              ),
              const SizedBox(height: 16),
              if (report != null)
                AnimatedOpacity(
                  opacity: loading ? 0.5 : 1,
                  duration: const Duration(milliseconds: 150),
                  child: _ReportBody(
                    report,
                    dailyTable: _dailyTable,
                    onToggleDaily: () =>
                        setState(() => _dailyTable = !_dailyTable),
                  ),
                )
              else if (failed)
                Column(
                  children: [
                    const Text(AppStrings.loadError),
                    const SizedBox(height: 8),
                    OutlinedButton(
                      onPressed: reload,
                      child: const Text(AppStrings.refresh),
                    ),
                  ],
                )
              else
                const Padding(
                  padding: EdgeInsets.all(32),
                  child: Center(child: CircularProgressIndicator()),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ReportBody extends StatelessWidget {
  const _ReportBody(
    this.report, {
    required this.dailyTable,
    required this.onToggleDaily,
  });

  final SalesReport report;
  final bool dailyTable;
  final VoidCallback onToggleDaily;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    final t = report.totals;
    final to = report.to;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          AppStrings.period(
            report.from,
            DateTime(to.year, to.month, to.day - 1),
          ),
          style: theme.textTheme.titleMedium,
        ),
        const SizedBox(height: 4),
        Text(AppStrings.reportsNote, style: muted),
        if (report.excluded > 0)
          Text(AppStrings.excluded(report.excluded), style: muted),
        if (report.unreadable > 0)
          Text(
            AppStrings.unreadable(report.unreadable),
            style: muted?.copyWith(color: theme.colorScheme.error),
          ),
        const SizedBox(height: 16),
        LayoutBuilder(
          builder: (context, box) {
            // Two to a row on a phone.
            final w = min(220.0, (box.maxWidth - 12) / 2);
            return Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                _StatTile(
                  AppStrings.ordersLabel,
                  AppStrings.grouped(t.orders),
                  w,
                ),
                _StatTile(AppStrings.salesLabel, AppStrings.amount(t.sales), w),
                _StatTile(
                  AppStrings.deliveryFees,
                  AppStrings.amount(t.delivery),
                  w,
                ),
                _StatTile(
                  AppStrings.discounts,
                  AppStrings.amount(t.discount),
                  w,
                ),
                _StatTile(
                  AppStrings.averageOrder,
                  AppStrings.amount(t.average),
                  w,
                ),
              ],
            );
          },
        ),
        if (t.orders == 0)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 32),
            child: Text(AppStrings.noSales, textAlign: TextAlign.center),
          )
        else ...[
          _Section(
            AppStrings.dailySales,
            action: TextButton(
              onPressed: onToggleDaily,
              child: Text(
                dailyTable ? AppStrings.showChart : AppStrings.showTable,
              ),
            ),
          ),
          if (dailyTable)
            _Table(
              columns: const [
                AppStrings.dayCol,
                AppStrings.ordersLabel,
                AppStrings.salesCol,
              ],
              rows: [
                for (final d in report.days.reversed)
                  [
                    AppStrings.day(d.start),
                    AppStrings.grouped(d.totals.orders),
                    AppStrings.pounds(d.totals.sales),
                  ],
              ],
            )
          else
            _DailyChart(report.days),
          const _Section(AppStrings.weeklySales, note: AppStrings.weekNote),
          _Table(
            columns: const [
              AppStrings.weekCol,
              AppStrings.ordersLabel,
              AppStrings.salesCol,
              AppStrings.averageCol,
            ],
            rows: [
              for (final w in report.weeks.reversed)
                [
                  AppStrings.week(w.start),
                  AppStrings.grouped(w.totals.orders),
                  AppStrings.pounds(w.totals.sales),
                  AppStrings.pounds(w.totals.average),
                ],
            ],
          ),
          const _Section(
            AppStrings.bestSellers,
            note: AppStrings.bestSellersNote,
          ),
          _RankList(report.bestSellers.take(10).toList()),
          const _Section(AppStrings.topAddOns, note: AppStrings.addOnsNote),
          if (report.addOns.isEmpty)
            const Text('—', textAlign: TextAlign.center)
          else
            _RankList(report.addOns.take(10).toList()),
        ],
      ],
    );
  }
}

/// A headline number with its label.
class _StatTile extends StatelessWidget {
  const _StatTile(this.label, this.value, this.width);

  final String label;
  final String value;
  final double width;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox(
      width: width,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 6),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: AlignmentDirectional.centerStart,
                child: Text(
                  value,
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section(this.title, {this.note, this.action});

  final String title;
  final String? note;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 28, bottom: 8),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: theme.textTheme.titleLarge),
                if (note != null)
                  Text(
                    note!,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
              ],
            ),
          ),
          ?action,
        ],
      ),
    );
  }
}

const _tabular = TextStyle(fontFeatures: [FontFeature.tabularFigures()]);

/// Rows of figures, as wide as the card (scrolling sideways on a phone).
class _Table extends StatelessWidget {
  const _Table({required this.columns, required this.rows});

  final List<String> columns;
  final List<List<String>> rows;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: LayoutBuilder(
        builder: (context, box) => SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: ConstrainedBox(
            constraints: BoxConstraints(minWidth: box.maxWidth),
            child: DataTable(
              columnSpacing: 24,
              horizontalMargin: 16,
              columns: [for (final c in columns) DataColumn(label: Text(c))],
              rows: [
                for (final r in rows)
                  DataRow(
                    cells: [
                      for (final v in r)
                        DataCell(
                          Text(
                            v,
                            maxLines: 1,
                            softWrap: false,
                            style: _tabular,
                          ),
                        ),
                    ],
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Sales per day as columns (one series, one colour): the time runs with the
/// reading direction, each day shows its figures on hover or long press,
/// and the best day carries its value. The table view holds every value.
class _DailyChart extends StatelessWidget {
  const _DailyChart(this.days);

  final List<PeriodSales> days;

  static const _plot = 180.0, _headroom = 20.0, _axis = 26.0;

  /// A clean scale reaching [peak] (piasters): the smallest step of 1, 2,
  /// 2.5 or 5 times a power of ten (a pound at least) that gets there in at
  /// most five steps, and the number of steps.
  static (int, int) _scale(int peak) {
    final pounds = peak / 100;
    if (pounds <= 0) return (100 * 100, 4);
    var magnitude = max(1.0, pow(10, (log(pounds / 5) / ln10).floor()) * 1.0);
    for (;;) {
      for (final m in const [1, 2, 2.5, 5]) {
        final step = m * magnitude;
        final n = (pounds / step).ceil();
        if (n <= 5) return ((step * 100).round(), max(1, n));
      }
      magnitude *= 10;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final small = theme.textTheme.labelSmall?.copyWith(
      color: scheme.onSurfaceVariant,
    );
    final peak = days.fold(0, (m, d) => max(m, d.totals.sales));
    final (step, steps) = _scale(peak);
    final top = step * steps;
    final peakAt = days.indexWhere((d) => d.totals.sales == peak);
    final week = days.length <= 7;
    String label(DateTime d) =>
        week ? AppStrings.weekday(d) : '${d.day}/${d.month}';

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 16, 12, 8),
        child: SizedBox(
          height: _headroom + _plot + _axis,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // The scale, on the side the days start from.
              SizedBox(
                width: 56,
                child: Stack(
                  children: [
                    for (var i = 0; i <= steps; i++)
                      PositionedDirectional(
                        top: _headroom + _plot * (1 - i / steps) - 8,
                        start: 0,
                        end: 8,
                        child: Text(
                          AppStrings.pounds(step * i),
                          style: small?.merge(_tabular),
                          textAlign: TextAlign.end,
                        ),
                      ),
                  ],
                ),
              ),
              Expanded(
                child: Stack(
                  children: [
                    Positioned(
                      top: _headroom,
                      left: 0,
                      right: 0,
                      height: _plot,
                      child: CustomPaint(
                        painter: _GridPainter(scheme.outlineVariant, steps),
                      ),
                    ),
                    Positioned.fill(
                      child: LayoutBuilder(
                        builder: (context, box) {
                          final slot = box.maxWidth / days.length;
                          // Thin columns with a 2px gap, never wider than 24.
                          final width = min(24.0, max(1.0, slot - 2));
                          // Date labels where they fit.
                          final every = max(
                            1,
                            (days.length * (week ? 56 : 44) / box.maxWidth)
                                .ceil(),
                          );
                          return Row(
                            children: [
                              for (final (i, d) in days.indexed)
                                Expanded(
                                  child: _DayColumn(
                                    day: d,
                                    width: width,
                                    height: _plot * d.totals.sales / top,
                                    peakValue: i == peakAt && peak > 0
                                        ? AppStrings.pounds(peak)
                                        : null,
                                    label: i % every == 0
                                        ? label(d.start)
                                        : null,
                                    labelStyle: small,
                                  ),
                                ),
                            ],
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// One day: its column grown from the baseline (the best day's value just
/// above it), and the whole slot as the hover and long-press target.
class _DayColumn extends StatefulWidget {
  const _DayColumn({
    required this.day,
    required this.width,
    required this.height,
    required this.peakValue,
    required this.label,
    required this.labelStyle,
  });

  final PeriodSales day;
  final double width;
  final double height;
  final String? peakValue;
  final String? label;
  final TextStyle? labelStyle;

  @override
  State<_DayColumn> createState() => _DayColumnState();
}

class _DayColumnState extends State<_DayColumn> {
  var _hover = false;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final d = widget.day;
    final tip = AppStrings.dayTip(d.start, d.totals.orders, d.totals.sales);
    return Tooltip(
      message: tip,
      child: MouseRegion(
        onEnter: (_) => setState(() => _hover = true),
        onExit: (_) => setState(() => _hover = false),
        child: Semantics(
          label: tip,
          child: ColoredBox(
            // Transparent, but part of the hit target.
            color: _hover
                ? scheme.primary.withValues(alpha: 0.06)
                : const Color(0x00000000),
            child: Column(
              children: [
                SizedBox(
                  height: _DailyChart._headroom + _DailyChart._plot,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      if (widget.peakValue case final v?)
                        SizedBox(
                          height: 16,
                          child: OverflowBox(
                            maxWidth: 80,
                            child: Text(
                              v,
                              style: widget.labelStyle?.copyWith(
                                color: scheme.onSurface,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      Container(
                        width: widget.width,
                        height: widget.height,
                        decoration: BoxDecoration(
                          color: _hover
                              ? Color.lerp(scheme.primary, Colors.white, 0.2)
                              : scheme.primary,
                          borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(4),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(
                  height: _DailyChart._axis,
                  child: widget.label == null
                      ? null
                      : Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: OverflowBox(
                            maxWidth: 80,
                            child: Text(
                              widget.label!,
                              style: widget.labelStyle,
                            ),
                          ),
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Hairline gridlines at each step of the scale, the lowest the baseline.
class _GridPainter extends CustomPainter {
  const _GridPainter(this.color, this.steps);

  final Color color;
  final int steps;

  @override
  void paint(Canvas canvas, Size size) {
    final line = Paint()
      ..color = color
      ..strokeWidth = 1;
    for (var i = 0; i <= steps; i++) {
      final y = size.height * i / steps;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), line);
    }
  }

  @override
  bool shouldRepaint(_GridPainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.steps != steps;
}

/// A ranking: name, a bar for how many (one colour) with the count at its
/// tip, and the revenue. On a phone the bar goes under the name.
class _RankList extends StatelessWidget {
  const _RankList(this.items);

  final List<Ranked> items;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final most = items.fold(1, (m, r) => max(m, r.count));
    Widget bar(Ranked r) => LayoutBuilder(
      builder: (context, box) => Row(
        children: [
          Container(
            width: max(2.0, (box.maxWidth - 56) * r.count / most),
            height: 12,
            decoration: BoxDecoration(
              color: scheme.primary,
              borderRadius: const BorderRadiusDirectional.horizontal(
                end: Radius.circular(4),
              ),
            ),
          ),
          const SizedBox(width: 6),
          Text(AppStrings.grouped(r.count), style: _tabular),
        ],
      ),
    );
    return Card(
      child: LayoutBuilder(
        builder: (context, box) {
          final narrow = box.maxWidth < 560;
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Column(
              children: [
                for (final (i, r) in items.indexed)
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            SizedBox(
                              width: 28,
                              child: Text(
                                '${i + 1}',
                                style: TextStyle(
                                  color: scheme.onSurfaceVariant,
                                ),
                              ),
                            ),
                            Expanded(
                              flex: 3,
                              child: Text(
                                r.name,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (!narrow) Expanded(flex: 4, child: bar(r)),
                            SizedBox(
                              width: 110,
                              child: Text(
                                AppStrings.amount(r.revenue),
                                textAlign: TextAlign.end,
                                style: _tabular,
                              ),
                            ),
                          ],
                        ),
                        if (narrow)
                          Padding(
                            padding: const EdgeInsetsDirectional.only(
                              start: 28,
                              top: 6,
                            ),
                            child: bar(r),
                          ),
                      ],
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}
