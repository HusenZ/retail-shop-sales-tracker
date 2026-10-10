import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../core/format/dates.dart';
import '../../../core/load_status.dart';
import '../../../core/widgets/async_views.dart';
import '../data/sale_repository.dart';
import '../domain/sale.dart';
import 'sale_filter_sheet.dart';
import 'sale_list_cubit.dart';
import 'sale_tile.dart';

class SaleListPage extends StatelessWidget {
  const SaleListPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => SaleListCubit(context.read<SaleRepository>())..load(),
      child: Builder(
        builder: (context) {
          final cubit = context.read<SaleListCubit>();
          final filtered = context.select((SaleListCubit cubit) => !cubit.state.filters.isEmpty);
          return Scaffold(
            appBar: AppBar(
              title: const Text('Sales'),
              actions: [
                IconButton(
                  tooltip: 'Customers',
                  icon: const Icon(Icons.people_outline),
                  onPressed: () => context.push('/customers'),
                ),
                IconButton(
                  tooltip: 'Filter',
                  icon: Badge(
                    isLabelVisible: filtered,
                    child: const Icon(Icons.filter_list),
                  ),
                  onPressed: () async {
                    final filters = await showSaleFilters(context, cubit.state.filters);
                    if (filters != null) await cubit.applyFilters(filters);
                  },
                ),
              ],
            ),
            floatingActionButton: FloatingActionButton.extended(
              onPressed: () => context.push('/sales/new'),
              icon: const Icon(Icons.add),
              label: const Text('Add Sale'),
            ),
            body: const _SaleHistory(),
          );
        },
      ),
    );
  }
}

class _SaleHistory extends StatelessWidget {
  const _SaleHistory();

  @override
  Widget build(BuildContext context) {
    final state = context.watch<SaleListCubit>().state;
    final cubit = context.read<SaleListCubit>();

    if (state.sales.isEmpty) {
      return switch (state.status) {
        LoadStatus.failure => ErrorView(message: state.errorMessage!, onRetry: cubit.load),
        LoadStatus.success => EmptyView(
            icon: Icons.receipt_long_outlined,
            message: state.filters.isEmpty
                ? 'No sales yet. Tap Add Sale to record your first one.'
                : 'No sales match these filters.',
          ),
        _ => const LoadingView(),
      };
    }

    final rows = _withDayHeadings(state.sales);
    return NotificationListener<ScrollNotification>(
      onNotification: (notification) {
        final nearEnd = notification.metrics.extentAfter < 300;
        if (nearEnd) cubit.loadMore();
        return false;
      },
      child: RefreshIndicator(
        onRefresh: cubit.load,
        child: ListView.builder(
          padding: const EdgeInsets.only(bottom: 88),
          itemCount: rows.length + (state.hasMore ? 1 : 0),
          itemBuilder: (context, index) {
            if (index == rows.length) {
              return const Padding(padding: EdgeInsets.all(16), child: LoadingView());
            }
            final row = rows[index];
            if (row is String) {
              return Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
                child: Text(row, style: Theme.of(context).textTheme.titleSmall),
              );
            }
            return SaleTile(sale: row as SaleSummary);
          },
        ),
      ),
    );
  }

  /// Interleaves "Today", "Yesterday", "12 Sep 2026" headings with the sales.
  static List<Object> _withDayHeadings(List<SaleSummary> sales) {
    final rows = <Object>[];
    String? lastHeading;
    for (final sale in sales) {
      final heading = formatDayHeading(sale.soldAt);
      if (heading != lastHeading) {
        rows.add(heading);
        lastHeading = heading;
      }
      rows.add(sale);
    }
    return rows;
  }
}
