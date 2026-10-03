import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../core/format/money.dart';
import '../../../core/load_status.dart';
import '../../../core/theme.dart';
import '../../../core/widgets/async_views.dart';
import '../../sales/data/sale_repository.dart';
import '../data/customer_repository.dart';
import '../domain/customer.dart';
import 'customer_form_dialog.dart';
import 'customer_list_cubit.dart';

class CustomerListPage extends StatelessWidget {
  const CustomerListPage({this.pendingOnly = false, super.key});

  final bool pendingOnly;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => CustomerListCubit(
        context.read<CustomerRepository>(),
        pendingOnly: pendingOnly,
        saleChanges: context.read<SaleRepository>().changes,
      )..load(),
      child: Builder(
        builder: (context) => Scaffold(
          appBar: AppBar(title: const Text('Customers')),
          floatingActionButton: FloatingActionButton.extended(
            icon: const Icon(Icons.person_add_alt),
            label: const Text('Add customer'),
            onPressed: () => showCustomerForm(context),
          ),
          body: Column(
            children: [
              const _CustomerSearch(),
              Expanded(
                child: _CustomerList(
                  onTap: (customer) => context.push('/customers/${customer.id}'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Lets the shopkeeper choose (or quickly add) the customer for a sale.
Future<Customer?> pickCustomer(BuildContext context) {
  return Navigator.of(context).push<Customer>(
    MaterialPageRoute(
      fullscreenDialog: true,
      builder: (_) => BlocProvider(
        create: (_) => CustomerListCubit(context.read<CustomerRepository>())..load(),
        child: Builder(
          builder: (context) => Scaffold(
            appBar: AppBar(
              title: const Text('Choose customer'),
              actions: [
                TextButton.icon(
                  icon: const Icon(Icons.person_add_alt),
                  label: const Text('New'),
                  onPressed: () async {
                    final navigator = Navigator.of(context);
                    final customer = await showCustomerForm(context);
                    if (customer != null) navigator.pop(customer);
                  },
                ),
              ],
            ),
            body: Column(
              children: [
                const _CustomerSearch(autofocus: true),
                Expanded(
                  child: _CustomerList(onTap: (customer) => Navigator.of(context).pop(customer)),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

class _CustomerSearch extends StatelessWidget {
  const _CustomerSearch({this.autofocus = false});

  final bool autofocus;

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<CustomerListCubit>();
    final pendingOnly = context.select((CustomerListCubit cubit) => cubit.state.pendingOnly);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            autofocus: autofocus,
            onChanged: cubit.search,
            decoration: const InputDecoration(
              hintText: 'Search name or phone',
              prefixIcon: Icon(Icons.search),
            ),
          ),
          const SizedBox(height: 8),
          FilterChip(
            label: const Text('Owes money'),
            selected: pendingOnly,
            onSelected: cubit.showPendingOnly,
          ),
        ],
      ),
    );
  }
}

class _CustomerList extends StatelessWidget {
  const _CustomerList({required this.onTap});

  final ValueChanged<Customer> onTap;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<CustomerListCubit>().state;
    final cubit = context.read<CustomerListCubit>();
    final colors = Theme.of(context).colorScheme;

    if (state.customers.isEmpty) {
      return switch (state.status) {
        LoadStatus.failure => ErrorView(message: state.errorMessage!, onRetry: cubit.load),
        LoadStatus.success => EmptyView(
            icon: Icons.people_outline,
            message: state.pendingOnly ? 'Nobody owes you money.' : 'No customers yet.',
          ),
        _ => const LoadingView(),
      };
    }

    return RefreshIndicator(
      onRefresh: cubit.load,
      child: ListView.separated(
        padding: const EdgeInsets.only(bottom: 88),
        itemCount: state.customers.length,
        separatorBuilder: (_, __) => const Divider(height: 1),
        itemBuilder: (context, index) {
          final customer = state.customers[index];
          return ListTile(
            leading: CircleAvatar(child: Text(customer.name.characters.first.toUpperCase())),
            title: Text(customer.name),
            subtitle: Text(customer.phone ?? '${customer.transactionCount} purchases'),
            trailing: customer.owesMoney
                ? Text(
                    '${formatRupees(customer.pendingAmount)} due',
                    style: TextStyle(color: colors.warning, fontWeight: FontWeight.bold),
                  )
                : null,
            onTap: () => onTap(customer),
          );
        },
      ),
    );
  }
}
