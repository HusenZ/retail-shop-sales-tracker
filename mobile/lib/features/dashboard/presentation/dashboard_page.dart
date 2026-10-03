import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../core/format/money.dart';
import '../../../core/load_status.dart';
import '../../../core/theme.dart';
import '../../../core/widgets/async_views.dart';
import '../../../core/widgets/stat_tile.dart';
import '../../auth/presentation/auth_cubit.dart';
import '../../sales/data/sale_repository.dart';
import '../data/dashboard_repository.dart';
import '../domain/dashboard.dart';
import 'dashboard_cubit.dart';

class DashboardPage extends StatelessWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => DashboardCubit(
        context.read<DashboardRepository>(),
        saleChanges: context.read<SaleRepository>().changes,
      )..load(),
      child: const DashboardView(),
    );
  }
}

class DashboardView extends StatelessWidget {
  const DashboardView({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<DashboardCubit>().state;
    final shopName = context.select((AuthCubit cubit) => cubit.state.shop?.name);
    return Scaffold(
      appBar: AppBar(title: Text(shopName ?? 'Dashboard')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/sales/new'),
        icon: const Icon(Icons.add),
        label: const Text('Add Sale', style: TextStyle(fontSize: 18)),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      body: switch (state.status) {
        LoadStatus.success => RefreshIndicator(
            onRefresh: context.read<DashboardCubit>().load,
            child: _DashboardContent(dashboard: state.dashboard!),
          ),
        LoadStatus.failure => ErrorView(
            message: state.errorMessage!,
            onRetry: context.read<DashboardCubit>().load,
          ),
        _ => const LoadingView(),
      },
    );
  }
}

String greeting(DateTime now) {
  if (now.hour < 12) return 'Good morning 👋';
  if (now.hour < 17) return 'Good afternoon 👋';
  return 'Good evening 👋';
}

class _DashboardContent extends StatelessWidget {
  const _DashboardContent({required this.dashboard});

  final Dashboard dashboard;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final today = dashboard.today;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
      children: [
        Text(greeting(DateTime.now()), style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 12),
        Card(
          color: colors.primaryContainer,
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                StatTile(
                  label: "Today's sales",
                  value: formatRupees(today.salesTotal),
                  large: true,
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: StatTile(
                        label: 'Profit',
                        value: formatRupees(today.profit),
                        color: colors.gain,
                      ),
                    ),
                    Expanded(
                      child: StatTile(
                        label: 'Transactions',
                        value: '${today.saleCount}',
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        _PeriodCard(title: 'This week', totals: dashboard.thisWeek),
        const SizedBox(height: 12),
        _PeriodCard(title: 'This month', totals: dashboard.thisMonth),
        const SizedBox(height: 12),
        Card(
          child: ListTile(
            leading: Icon(Icons.schedule, color: colors.warning),
            title: const Text('Pending from customers'),
            subtitle: Text('${dashboard.pendingSaleCount} unpaid sales'),
            trailing: Text(
              formatRupees(dashboard.pendingTotal),
              style: TextStyle(
                color: dashboard.pendingSaleCount > 0 ? colors.warning : null,
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
            onTap: () => context.push('/customers?pending=true'),
          ),
        ),
      ],
    );
  }
}

class _PeriodCard extends StatelessWidget {
  const _PeriodCard({required this.title, required this.totals});

  final String title;
  final PeriodTotals totals;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 4),
            AmountRow(label: 'Sales', value: formatRupees(totals.salesTotal)),
            AmountRow(
              label: 'Profit',
              value: formatRupees(totals.profit),
              color: Theme.of(context).colorScheme.gain,
            ),
          ],
        ),
      ),
    );
  }
}
