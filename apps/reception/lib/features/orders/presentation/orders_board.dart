import 'package:flutter/material.dart';

import '../../../core/strings/app_strings.dart';
import '../domain/order_board.dart';

/// Below this width the board shows one column at a time, as tabs.
const boardTabsBelow = 700.0;

/// Narrowest a board column gets; narrower screens scroll sideways.
const boardColumnMinWidth = 300.0;

String boardColumnTitle(BoardColumn c) => switch (c) {
  BoardColumn.incoming => AppStrings.columnIncoming,
  BoardColumn.kitchen => AppStrings.columnKitchen,
  BoardColumn.ready => AppStrings.columnReady,
  BoardColumn.onTheWay => AppStrings.columnOnTheWay,
};

/// Active orders by status: side-by-side columns on a wide screen, tabs
/// with counts on a phone. [cardBuilder] draws each order.
class OrdersBoard extends StatelessWidget {
  const OrdersBoard({
    super.key,
    required this.orders,
    required this.cardBuilder,
  });

  final List<BoardOrder> orders;
  final Widget Function(BuildContext context, BoardOrder order) cardBuilder;

  @override
  Widget build(BuildContext context) {
    final board = groupByColumn(orders);
    return LayoutBuilder(
      builder: (context, box) => box.maxWidth < boardTabsBelow
          ? _Tabs(board: board, cardBuilder: cardBuilder)
          : _Columns(
              board: board,
              cardBuilder: cardBuilder,
              width: box.maxWidth,
            ),
    );
  }
}

class _Columns extends StatelessWidget {
  const _Columns({
    required this.board,
    required this.cardBuilder,
    required this.width,
  });

  final Map<BoardColumn, List<BoardOrder>> board;
  final Widget Function(BuildContext, BoardOrder) cardBuilder;
  final double width;

  @override
  Widget build(BuildContext context) {
    const gap = 12.0;
    final n = BoardColumn.values.length;
    final fit = (width - gap * (n + 1)) / n;
    final columnWidth = fit < boardColumnMinWidth ? boardColumnMinWidth : fit;
    final row = Padding(
      padding: const EdgeInsets.symmetric(horizontal: gap / 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final c in BoardColumn.values)
            Container(
              key: ValueKey('column-${c.name}'),
              width: columnWidth,
              margin: const EdgeInsets.symmetric(
                horizontal: gap / 2,
                vertical: gap,
              ),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerLow,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
                    child: Text(
                      AppStrings.withCount(
                        boardColumnTitle(c),
                        board[c]!.length,
                      ),
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  Expanded(
                    child: _OrderList(
                      orders: board[c]!,
                      cardBuilder: cardBuilder,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
    if (columnWidth == fit) return row;
    return SingleChildScrollView(scrollDirection: Axis.horizontal, child: row);
  }
}

class _Tabs extends StatelessWidget {
  const _Tabs({required this.board, required this.cardBuilder});

  final Map<BoardColumn, List<BoardOrder>> board;
  final Widget Function(BuildContext, BoardOrder) cardBuilder;

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: BoardColumn.values.length,
      child: Column(
        children: [
          TabBar(
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            tabs: [
              for (final c in BoardColumn.values)
                Tab(
                  key: ValueKey('tab-${c.name}'),
                  text: AppStrings.withCount(
                    boardColumnTitle(c),
                    board[c]!.length,
                  ),
                ),
            ],
          ),
          Expanded(
            child: TabBarView(
              children: [
                for (final c in BoardColumn.values)
                  _OrderList(orders: board[c]!, cardBuilder: cardBuilder),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _OrderList extends StatelessWidget {
  const _OrderList({required this.orders, required this.cardBuilder});

  final List<BoardOrder> orders;
  final Widget Function(BuildContext, BoardOrder) cardBuilder;

  @override
  Widget build(BuildContext context) {
    if (orders.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Text(AppStrings.emptyColumn),
        ),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(8, 4, 8, 12),
      itemCount: orders.length,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (context, i) => KeyedSubtree(
        key: ValueKey(orders[i].id),
        child: cardBuilder(context, orders[i]),
      ),
    );
  }
}
