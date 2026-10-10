import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../core/format/money.dart';
import '../../../core/load_status.dart';
import '../../../core/widgets/async_views.dart';
import '../../../core/widgets/inputs.dart';
import '../data/category_repository.dart';
import '../data/product_repository.dart';
import '../domain/product.dart';
import 'product_form_cubit.dart';

/// Add a product (no [productId]) or edit one.
class ProductFormPage extends StatelessWidget {
  const ProductFormPage({this.productId, super.key});

  final String? productId;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => ProductFormCubit(
        context.read<ProductRepository>(),
        context.read<CategoryRepository>(),
        productId: productId,
      )..load(),
      child: BlocConsumer<ProductFormCubit, ProductFormState>(
        listenWhen: (previous, current) =>
            current.errorMessage != null || (current.isSaved && !previous.isSaved),
        listener: (context, state) {
          if (state.isSaved) {
            context.pop();
          } else {
            showMessage(context, state.errorMessage!);
          }
        },
        buildWhen: (previous, current) => previous.status != current.status,
        builder: (context, state) => Scaffold(
          appBar: AppBar(title: Text(productId == null ? 'Add product' : 'Edit product')),
          body: switch (state.status) {
            LoadStatus.success => _ProductForm(product: state.product),
            LoadStatus.failure => ErrorView(
                message: state.errorMessage ?? 'Could not load',
                onRetry: context.read<ProductFormCubit>().load,
              ),
            _ => const LoadingView(),
          },
        ),
      ),
    );
  }
}

class _ProductForm extends StatefulWidget {
  const _ProductForm({this.product});

  final Product? product;

  @override
  State<_ProductForm> createState() => _ProductFormState();
}

class _ProductFormState extends State<_ProductForm> {
  final _formKey = GlobalKey<FormState>();
  late final Product? _initial = widget.product;
  late final _name = TextEditingController(text: _initial?.name);
  late final _purchasePrice = TextEditingController(text: _moneyText(_initial?.purchasePrice));
  late final _sellingPrice = TextEditingController(text: _moneyText(_initial?.sellingPrice));
  final _openingStock = TextEditingController(text: '1');
  late final _lowStock = TextEditingController(text: '${_initial?.lowStockThreshold ?? 2}');
  late final _brand = TextEditingController(text: _initial?.brand);
  late final _model = TextEditingController(text: _initial?.model);
  late final _sku = TextEditingController(text: _initial?.sku);
  late final _imei = TextEditingController(text: _initial?.imei);
  late String? _categoryId = _initial?.categoryId;
  late bool _trackStock = _initial?.trackStock ?? true;
  late bool _isActive = _initial?.isActive ?? true;

  bool get _isNew => _initial == null;

  static String _moneyText(Decimal? amount) => amount == null ? '' : moneyInputText(amount);

  @override
  void dispose() {
    for (final controller in [
      _name,
      _purchasePrice,
      _sellingPrice,
      _openingStock,
      _lowStock,
      _brand,
      _model,
      _sku,
      _imei,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    context.read<ProductFormCubit>().save(
          ProductInput(
            name: _name.text.trim(),
            categoryId: _categoryId!,
            purchasePrice: parseMoneyInput(_purchasePrice.text)!,
            sellingPrice: parseMoneyInput(_sellingPrice.text)!,
            trackStock: _trackStock,
            lowStockThreshold: int.parse(_lowStock.text),
            initialStock: _trackStock ? int.parse(_openingStock.text) : 0,
            isActive: _isActive,
            brand: cleanOptional(_brand.text),
            model: cleanOptional(_model.text),
            sku: cleanOptional(_sku.text),
            imei: cleanOptional(_imei.text),
          ),
        );
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<ProductFormCubit>().state;
    return Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextFormField(
            controller: _name,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(labelText: 'Product name'),
            validator: requiredText,
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            initialValue: _categoryId,
            decoration: const InputDecoration(labelText: 'Category'),
            items: [
              for (final category in state.categories)
                DropdownMenuItem(value: category.id, child: Text(category.name)),
            ],
            onChanged: (value) => setState(() => _categoryId = value),
            validator: (value) => value == null ? 'Choose a category' : null,
          ),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: MoneyField(
                  label: 'Purchase price',
                  controller: _purchasePrice,
                  isRequired: true,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: MoneyField(
                  label: 'Selling price',
                  controller: _sellingPrice,
                  isRequired: true,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Track stock'),
            subtitle: const Text('Turn off for services like repairs'),
            value: _trackStock,
            onChanged: (value) => setState(() => _trackStock = value),
          ),
          if (_trackStock) ...[
            if (_isNew) ...[
              _CountField(controller: _openingStock, label: 'Stock in shop now'),
              const SizedBox(height: 16),
            ] else
              _StockAdjuster(product: state.product!),
            _CountField(
              controller: _lowStock,
              label: 'Warn when stock falls to',
            ),
          ],
          ExpansionTile(
            tilePadding: EdgeInsets.zero,
            title: const Text('More details (optional)'),
            initiallyExpanded: (_initial?.brand ?? _initial?.imei) != null,
            children: [
              TextFormField(
                controller: _brand,
                decoration: const InputDecoration(labelText: 'Brand'),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _model,
                decoration: const InputDecoration(labelText: 'Model'),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _sku,
                decoration: const InputDecoration(labelText: 'SKU / code'),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _imei,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'IMEI'),
              ),
              const SizedBox(height: 12),
            ],
          ),
          if (!_isNew)
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Available for sale'),
              subtitle: const Text('Turn off to hide this product'),
              value: _isActive,
              onChanged: (value) => setState(() => _isActive = value),
            ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: state.isSaving ? null : _save,
            child: Text(_isNew ? 'Add product' : 'Save changes'),
          ),
        ],
      ),
    );
  }
}

class _CountField extends StatelessWidget {
  const _CountField({required this.controller, required this.label});

  final TextEditingController controller;
  final String label;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      keyboardType: TextInputType.number,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      decoration: InputDecoration(labelText: label),
      validator: requiredText,
    );
  }
}

/// Stock is changed by adding or removing a count, never by overwriting the number.
class _StockAdjuster extends StatelessWidget {
  const _StockAdjuster({required this.product});

  final Product product;

  Future<void> _adjust(BuildContext context, {required bool adding}) async {
    final cubit = context.read<ProductFormCubit>();
    final count = await _askCount(context, adding ? 'Add stock' : 'Remove stock');
    if (count != null && count > 0) await cubit.adjustStock(adding ? count : -count);
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Expanded(
              child: Text(
                product.stockLabel,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            IconButton.filledTonal(
              tooltip: 'Remove stock',
              onPressed: product.stockQty == 0 ? null : () => _adjust(context, adding: false),
              icon: const Icon(Icons.remove),
            ),
            const SizedBox(width: 8),
            IconButton.filled(
              tooltip: 'Add stock',
              onPressed: () => _adjust(context, adding: true),
              icon: const Icon(Icons.add),
            ),
          ],
        ),
      ),
    );
  }
}

Future<int?> _askCount(BuildContext context, String title) {
  final controller = TextEditingController();
  return showDialog<int>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: TextField(
        controller: controller,
        autofocus: true,
        keyboardType: TextInputType.number,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        decoration: const InputDecoration(labelText: 'How many?'),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        TextButton(
          onPressed: () => Navigator.pop(context, int.tryParse(controller.text)),
          child: const Text('OK'),
        ),
      ],
    ),
  );
}
