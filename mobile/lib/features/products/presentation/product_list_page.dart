import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../core/format/money.dart';
import '../../../core/load_status.dart';
import '../../../core/widgets/async_views.dart';
import '../../sales/data/sale_repository.dart';
import '../data/product_repository.dart';
import '../domain/product.dart';
import 'product_list_cubit.dart';
import 'stock_badge.dart';

class ProductListPage extends StatelessWidget {
  const ProductListPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => ProductListCubit(
        context.read<ProductRepository>(),
        saleChanges: context.read<SaleRepository>().changes,
      )..load(),
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Products'),
          actions: [
            IconButton(
              tooltip: 'Categories',
              icon: const Icon(Icons.category_outlined),
              onPressed: () => context.push('/settings/categories'),
            ),
          ],
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () => context.push('/products/new'),
          icon: const Icon(Icons.add),
          label: const Text('Add product'),
        ),
        body: const Column(
          children: [
            _SearchAndFilters(),
            Expanded(child: _ProductList()),
          ],
        ),
      ),
    );
  }
}

class _SearchAndFilters extends StatelessWidget {
  const _SearchAndFilters();

  static const _filters = <StockStatus?, String>{
    null: 'All',
    StockStatus.low: 'Low stock',
    StockStatus.out: 'Out of stock',
  };

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<ProductListCubit>();
    final selected = context.select((ProductListCubit cubit) => cubit.state.stockFilter);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Column(
        children: [
          TextField(
            onChanged: cubit.search,
            decoration: const InputDecoration(
              hintText: 'Search name, brand, IMEI',
              prefixIcon: Icon(Icons.search),
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              for (final entry in _filters.entries)
                ChoiceChip(
                  label: Text(entry.value),
                  selected: selected == entry.key,
                  onSelected: (_) => cubit.filterByStock(entry.key),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ProductList extends StatelessWidget {
  const _ProductList();

  @override
  Widget build(BuildContext context) {
    final state = context.watch<ProductListCubit>().state;
    final cubit = context.read<ProductListCubit>();

    if (state.products.isEmpty) {
      return switch (state.status) {
        LoadStatus.initial || LoadStatus.loading => const LoadingView(),
        LoadStatus.failure => ErrorView(message: state.errorMessage!, onRetry: cubit.load),
        LoadStatus.success => EmptyView(
            icon: Icons.inventory_2_outlined,
            message: state.search.isEmpty && state.stockFilter == null
                ? 'No products yet. Add the phones and accessories you sell.'
                : 'No products match.',
          ),
      };
    }

    return RefreshIndicator(
      onRefresh: cubit.load,
      child: ListView.separated(
        padding: const EdgeInsets.only(bottom: 88),
        itemCount: state.products.length,
        separatorBuilder: (_, __) => const Divider(height: 1),
        itemBuilder: (context, index) {
          final product = state.products[index];
          return ListTile(
            title: Text(product.name),
            subtitle: Text(
              [
                formatRupees(product.sellingPrice),
                if (product.brand != null) product.brand!,
              ].join(' · '),
            ),
            trailing: StockBadge(product: product),
            onTap: () => context.push('/products/${product.id}'),
          );
        },
      ),
    );
  }
}
