import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/api/api_exception.dart';
import '../../../core/format/money.dart';
import '../../../core/load_status.dart';
import '../../../core/theme.dart';
import '../../../core/widgets/async_views.dart';
import '../../../core/widgets/stat_tile.dart';
import '../../sales/data/sale_repository.dart';
import '../../sales/domain/sale.dart';
import '../../sales/presentation/sale_tile.dart';
import '../data/customer_repository.dart';
import '../domain/customer.dart';
import 'customer_form_dialog.dart';

class CustomerDetailState extends Equatable {
  const CustomerDetailState({
    this.status = LoadStatus.initial,
    this.customer,
    this.sales = const [],
    this.errorMessage,
  });

  final LoadStatus status;
  final Customer? customer;
  final List<SaleSummary> sales;
  final String? errorMessage;

  @override
  List<Object?> get props => [status, customer, sales, errorMessage];
}

class CustomerDetailCubit extends Cubit<CustomerDetailState> {
  CustomerDetailCubit(this._customers, this._sales, this.customerId)
      : super(const CustomerDetailState()) {
    _subscriptions = [
      _customers.changes.listen((_) => load()),
      _sales.changes.listen((_) => load()),
    ];
  }

  static const _salesShown = 100;

  final CustomerRepository _customers;
  final SaleRepository _sales;
  final String customerId;
  late final List<StreamSubscription<void>> _subscriptions;

  Future<void> load() async {
    if (state.customer == null) emit(const CustomerDetailState(status: LoadStatus.loading));
    try {
      final customer = await _customers.get(customerId);
      final sales = await _sales.list(
        filters: SaleFilters(customerId: customerId),
        limit: _salesShown,
      );
      if (!isClosed) {
        emit(CustomerDetailState(status: LoadStatus.success, customer: customer, sales: sales));
      }
    } on ApiException catch (error) {
      if (!isClosed) {
        emit(
          CustomerDetailState(
            status: state.customer == null ? LoadStatus.failure : LoadStatus.success,
            customer: state.customer,
            sales: state.sales,
            errorMessage: error.message,
          ),
        );
      }
    }
  }

  @override
  Future<void> close() {
    for (final subscription in _subscriptions) {
      subscription.cancel();
    }
    return super.close();
  }
}

class CustomerDetailPage extends StatelessWidget {
  const CustomerDetailPage({required this.customerId, super.key});

  final String customerId;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => CustomerDetailCubit(
        context.read<CustomerRepository>(),
        context.read<SaleRepository>(),
        customerId,
      )..load(),
      child: BlocBuilder<CustomerDetailCubit, CustomerDetailState>(
        builder: (context, state) {
          final customer = state.customer;
          return Scaffold(
            appBar: AppBar(
              title: Text(customer?.name ?? 'Customer'),
              actions: [
                if (customer != null)
                  IconButton(
                    tooltip: 'Edit',
                    icon: const Icon(Icons.edit_outlined),
                    onPressed: () => showCustomerForm(context, existing: customer),
                  ),
              ],
            ),
            body: switch (state.status) {
              LoadStatus.success => _CustomerDetails(customer: customer!, sales: state.sales),
              LoadStatus.failure => ErrorView(
                  message: state.errorMessage!,
                  onRetry: context.read<CustomerDetailCubit>().load,
                ),
              _ => const LoadingView(),
            },
          );
        },
      ),
    );
  }
}

class _CustomerDetails extends StatelessWidget {
  const _CustomerDetails({required this.customer, required this.sales});

  final Customer customer;
  final List<SaleSummary> sales;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return RefreshIndicator(
      onRefresh: context.read<CustomerDetailCubit>().load,
      child: ListView(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (customer.phone != null) Text(customer.phone!),
                if (customer.notes != null) Text(customer.notes!),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: StatTile(
                        label: 'Purchases',
                        value: formatRupees(customer.totalPurchases),
                      ),
                    ),
                    Expanded(
                      child: StatTile(
                        label: 'Transactions',
                        value: '${customer.transactionCount}',
                      ),
                    ),
                    Expanded(
                      child: StatTile(
                        label: 'Pending',
                        value: formatRupees(customer.pendingAmount),
                        color: customer.owesMoney ? colors.warning : null,
                      ),
                    ),
                  ],
                ),
                if (customer.owesMoney) ...[
                  const SizedBox(height: 12),
                  const Text('Open a sale below to record a payment.'),
                ],
              ],
            ),
          ),
          const Divider(height: 1),
          if (sales.isEmpty)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Text('No purchases yet.', textAlign: TextAlign.center),
            ),
          for (final sale in sales) SaleTile(sale: sale, showDate: true),
        ],
      ),
    );
  }
}
