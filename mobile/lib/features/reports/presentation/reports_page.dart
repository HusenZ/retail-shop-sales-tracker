import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../core/format/dates.dart';
import '../../../core/format/money.dart';
import '../../../core/load_status.dart';
import '../../../core/theme.dart';
import '../../../core/widgets/async_views.dart';
import '../../../core/widgets/stat_tile.dart';
import '../../expenses/data/expense_repository.dart';
import '../../sales/data/sale_repository.dart';
import '../data/report_repository.dart';
import '../domain/report.dart';
import 'report_cubit.dart';

class ReportsPage extends StatelessWidget {
  const ReportsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => ReportCubit(
        context.read<ReportRepository>(),
        refreshOn: [
          context.read<SaleRepository>().changes,
          context.read<ExpenseRepository>().changes,
        ],
      )..load(),
      child: const ReportsView(),
    );
  }
}

class ReportsView extends StatelessWidget {
  const ReportsView({super.key});

  Future<void> _pickRange(BuildContext context) async {
    final cubit = context.read<ReportCubit>();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange: DateTimeRange(start: cubit.state.firstDay, end: cubit.state.lastDay),
    );
    if (picked != null) await cubit.selectRange(picked.start, picked.end);
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<ReportCubit>().state;
    final cubit = context.read<ReportCubit>();
    final summary = state.summary;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Reports'),
        actions: [
          TextButton.icon(
            icon: const Icon(Icons.receipt_outlined),
            label: const Text('Expenses'),
            onPressed: () => context.push('/expenses'),
          ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final period in ReportPeriod.values)
                  ChoiceChip(
                    label: Text(period.label),
                    selected: state.period == period,
                    onSelected: (_) => period == ReportPeriod.custom
                        ? _pickRange(context)
                        : cubit.selectPeriod(period),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Text(
              state.firstDay == state.lastDay
                  ? formatDate(state.firstDay)
                  : '${formatDate(state.firstDay)} – ${formatDate(state.lastDay)}',
            ),
          ),
          if (state.status == LoadStatus.loading) const LinearProgressIndicator(),
          Expanded(
            child: switch (state.status) {
              LoadStatus.failure when summary == null => ErrorView(
                  message: state.errorMessage!,
                  onRetry: cubit.load,
                ),
              _ when summary == null => const LoadingView(),
              _ => RefreshIndicator(
                  onRefresh: cubit.load,
                  child: _ReportContent(summary: summary!),
                ),
            },
          ),
        ],
      ),
    );
  }
}

class _ReportContent extends StatelessWidget {
  const _ReportContent({required this.summary});

  final ReportSummary summary;

  @override
  Widget build(BuildContext context) {
    final totals = summary.totals;
    final colors = Theme.of(context).colorScheme;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: StatTile(label: 'Sales', value: formatRupees(totals.revenue), large: true),
                ),
                StatTile(label: 'Transactions', value: '${totals.saleCount}'),
              ],
            ),
          ),
        ),
        const SectionTitle('Profit'),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                AmountRow(label: 'Sales', value: formatRupees(totals.revenue)),
                AmountRow(label: 'Cost of goods', value: '-${formatRupees(totals.cost)}'),
                AmountRow(
                  label: 'Gross profit',
                  value: formatRupees(totals.grossProfit),
                  bold: true,
                ),
                AmountRow(label: 'Expenses', value: '-${formatRupees(totals.expenses)}'),
                const Divider(),
                AmountRow(
                  label: 'Net profit',
                  value: formatRupees(totals.netProfit),
                  bold: true,
                  color: totals.netProfit < Decimal.zero ? colors.error : colors.gain,
                ),
                if (totals.discount > Decimal.zero)
                  AmountRow(label: 'Discounts given', value: formatRupees(totals.discount)),
              ],
            ),
          ),
        ),
        const SectionTitle('Categories'),
        _GroupList(rows: summary.byCategory, unit: 'items'),
        const SectionTitle('Sale types'),
        _GroupList(rows: summary.bySaleType, unit: 'sales'),
        const SectionTitle('Payments'),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: summary.byPaymentMethod.isEmpty
                ? const Text('No sales in this period.')
                : Column(
                    children: [
                      for (final row in summary.byPaymentMethod)
                        AmountRow(
                          label: row.label,
                          value: formatRupees(row.amount),
                          color: row.method == 'credit' ? colors.warning : null,
                        ),
                    ],
                  ),
          ),
        ),
      ],
    );
  }
}

/// Rows with a bar showing each one's share of the largest, so the leader stands out.
class _GroupList extends StatelessWidget {
  const _GroupList({required this.rows, required this.unit});

  final List<GroupRow> rows;
  final String unit;

  @override
  Widget build(BuildContext context) {
    if (rows.isEmpty) {
      return const Card(
        child: Padding(padding: EdgeInsets.all(16), child: Text('No sales in this period.')),
      );
    }
    final colors = Theme.of(context).colorScheme;
    final largest = rows.first.revenue.toDouble();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            for (final row in rows)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AmountRow(label: row.name, value: formatRupees(row.revenue), bold: true),
                    // Display only: the bar is a visual share, not a business figure.
                    LinearProgressIndicator(
                      value: largest <= 0 ? 0 : row.revenue.toDouble() / largest,
                      minHeight: 6,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${row.quantity} $unit · profit ${formatRupees(row.profit)}',
                      style: TextStyle(color: colors.outline),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
