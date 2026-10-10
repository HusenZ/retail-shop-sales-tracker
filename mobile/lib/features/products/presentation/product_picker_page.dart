import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/format/money.dart';
import '../../../core/load_status.dart';
import '../../../core/widgets/async_views.dart';
import '../data/product_repository.dart';
import '../domain/product.dart';
import 'product_list_cubit.dart';
import 'stock_badge.dart';

/// Full-screen product search used while recording a sale. Pops with the chosen product.
Future<Product?> pickProduct(BuildContext context) {
  return Navigator.of(context).push<Product>(
    MaterialPageRoute(
      fullscreenDialog: true,
      builder: (_) => BlocProvider(
        create: (_) => ProductListCubit(context.read<ProductRepository>())..load(),
        child: const _ProductPickerView(),
      ),
    ),
  );
}

class _ProductPickerView extends StatelessWidget {
  const _ProductPickerView();

  @override
  Widget build(BuildContext context) {
    final state = context.watch<ProductListCubit>().state;
    final cubit = context.read<ProductListCubit>();
    return Scaffold(
      appBar: AppBar(
        title: TextField(
          autofocus: true,
          onChanged: cubit.search,
          decoration: const InputDecoration(
            hintText: 'Search product',
            border: InputBorder.none,
          ),
        ),
      ),
      body: switch (state.status) {
        _ when state.products.isNotEmpty => ListView.separated(
            itemCount: state.products.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final product = state.products[index];
              return ListTile(
                enabled: product.canBeSold,
                title: Text(product.name),
                subtitle: Text('${formatRupees(product.sellingPrice)} · ${product.stockLabel}'),
                trailing: StockBadge(product: product),
                onTap: () => Navigator.of(context).pop(product),
              );
            },
          ),
        LoadStatus.failure => ErrorView(message: state.errorMessage!, onRetry: cubit.load),
        LoadStatus.success => const EmptyView(
            icon: Icons.search_off,
            message: 'No product found. Add it from the Products tab.',
          ),
        _ => const LoadingView(),
      },
    );
  }
}
