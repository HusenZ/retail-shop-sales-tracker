import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../core/format/money.dart';
import '../../../core/theme.dart';
import '../../../core/widgets/async_views.dart';
import '../../../core/widgets/inputs.dart';
import '../../../core/widgets/stat_tile.dart';
import '../../customers/presentation/customer_list_page.dart';
import '../../products/presentation/product_picker_page.dart';
import '../data/sale_repository.dart';
import '../data/sale_type_repository.dart';
import '../domain/sale.dart';
import 'add_sale_cubit.dart';

/// The most used screen: record a sale in a few taps. Pops with `true` once saved.
class AddSalePage extends StatelessWidget {
  const AddSalePage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => AddSaleCubit(
        context.read<SaleTypeRepository>(),
        context.read<SaleRepository>(),
      )..load(),
      child: const AddSaleView(),
    );
  }
}

class AddSaleView extends StatefulWidget {
  const AddSaleView({super.key});

  @override
  State<AddSaleView> createState() => _AddSaleViewState();
}

class _AddSaleViewState extends State<AddSaleView> {
  final _price = TextEditingController();
  final _discount = TextEditingController();
  final _amountPaid = TextEditingController();
  final _notes = TextEditingController();
  final _exchangeName = TextEditingController();
  final _exchangeImei = TextEditingController();
  final _exchangeValue = TextEditingController();

  List<TextEditingController> get _controllers =>
      [_price, _discount, _amountPaid, _notes, _exchangeName, _exchangeImei, _exchangeValue];

  @override
  void dispose() {
    for (final controller in _controllers) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _onSaved(BuildContext context, SaleDetail sale) async {
    final cubit = context.read<AddSaleCubit>();
    final addAnother = await showModalBottomSheet<bool>(
      context: context,
      isDismissible: false,
      enableDrag: false,
      builder: (_) => _SavedSheet(sale: sale),
    );
    if (!context.mounted) return;
    if (addAnother ?? false) {
      cubit.startNew();
    } else {
      context.pop(true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return MultiBlocListener(
      listeners: [
        BlocListener<AddSaleCubit, AddSaleState>(
          listenWhen: (previous, current) =>
              current.status == AddSaleStatus.saved && previous.status != AddSaleStatus.saved,
          listener: (context, state) => _onSaved(context, state.savedSale!),
        ),
        BlocListener<AddSaleCubit, AddSaleState>(
          listenWhen: (previous, current) =>
              current.status == AddSaleStatus.ready &&
              current.errorMessage != null &&
              current.errorMessage != previous.errorMessage,
          listener: (context, state) => showMessage(context, state.errorMessage!),
        ),
        BlocListener<AddSaleCubit, AddSaleState>(
          listenWhen: (previous, current) => previous.product != current.product,
          listener: (context, state) {
            final product = state.product;
            _price.text = product == null ? '' : moneyInputText(product.sellingPrice);
          },
        ),
        BlocListener<AddSaleCubit, AddSaleState>(
          // A new client reference means the form was reset for the next sale.
          listenWhen: (previous, current) => previous.clientRef != current.clientRef,
          listener: (context, state) {
            for (final controller in _controllers) {
              controller.clear();
            }
          },
        ),
      ],
      child: BlocBuilder<AddSaleCubit, AddSaleState>(
        buildWhen: (previous, current) => previous.status != current.status,
        builder: (context, state) {
          final cubit = context.read<AddSaleCubit>();
          return Scaffold(
            appBar: AppBar(title: const Text('New sale')),
            body: switch (state.status) {
              AddSaleStatus.loading => const LoadingView(),
              AddSaleStatus.loadFailed => ErrorView(
                  message: state.errorMessage ?? 'Could not load',
                  onRetry: cubit.load,
                ),
              _ => ListView(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                  children: [
                    const SectionTitle('Sale type'),
                    const _SaleTypeChips(),
                    const SectionTitle('Product'),
                    const _ProductCard(),
                    const SizedBox(height: 16),
                    _QuantityAndPrice(priceController: _price),
                    const SizedBox(height: 16),
                    MoneyField(
                      label: 'Discount (optional)',
                      controller: _discount,
                      onChanged: (text) => cubit.setDiscount(parseMoneyInput(text)),
                    ),
                    _ExchangeFields(
                      nameController: _exchangeName,
                      imeiController: _exchangeImei,
                      valueController: _exchangeValue,
                    ),
                    const SectionTitle('Payment'),
                    _PaymentSection(amountPaidController: _amountPaid),
                    const SizedBox(height: 8),
                    const _CustomerTile(),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _notes,
                      onChanged: cubit.setNotes,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: const InputDecoration(labelText: 'Note (optional)'),
                    ),
                    const SizedBox(height: 16),
                    const _Summary(),
                  ],
                ),
            },
            bottomNavigationBar: const _SaveBar(),
          );
        },
      ),
    );
  }
}

class _SaleTypeChips extends StatelessWidget {
  const _SaleTypeChips();

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AddSaleCubit>().state;
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final saleType in state.saleTypes)
          ChoiceChip(
            label: Text(saleType.name),
            selected: saleType == state.saleType,
            onSelected: (_) => context.read<AddSaleCubit>().selectSaleType(saleType),
          ),
      ],
    );
  }
}

class _ProductCard extends StatelessWidget {
  const _ProductCard();

  @override
  Widget build(BuildContext context) {
    final product = context.select((AddSaleCubit cubit) => cubit.state.product);
    final cubit = context.read<AddSaleCubit>();
    return Card(
      child: ListTile(
        leading: const Icon(Icons.smartphone),
        title: Text(product?.name ?? 'Tap to choose product'),
        subtitle: product == null
            ? null
            : Text('${formatRupees(product.sellingPrice)} · ${product.stockLabel}'),
        trailing: Icon(product == null ? Icons.search : Icons.swap_horiz),
        onTap: () async {
          final chosen = await pickProduct(context);
          if (chosen != null) cubit.selectProduct(chosen);
        },
      ),
    );
  }
}

class _QuantityAndPrice extends StatelessWidget {
  const _QuantityAndPrice({required this.priceController});

  final TextEditingController priceController;

  @override
  Widget build(BuildContext context) {
    final quantity = context.select((AddSaleCubit cubit) => cubit.state.quantity);
    final cubit = context.read<AddSaleCubit>();
    return Row(
      children: [
        IconButton.outlined(
          tooltip: 'Less',
          onPressed: quantity > 1 ? cubit.decreaseQuantity : null,
          icon: const Icon(Icons.remove),
        ),
        SizedBox(
          width: 48,
          child: Text(
            '$quantity',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.headlineSmall,
          ),
        ),
        IconButton.outlined(
          tooltip: 'More',
          onPressed: cubit.increaseQuantity,
          icon: const Icon(Icons.add),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: MoneyField(
            label: 'Price each',
            controller: priceController,
            onChanged: (text) => cubit.setUnitPrice(parseMoneyInput(text)),
          ),
        ),
      ],
    );
  }
}

class _ExchangeFields extends StatelessWidget {
  const _ExchangeFields({
    required this.nameController,
    required this.imeiController,
    required this.valueController,
  });

  final TextEditingController nameController;
  final TextEditingController imeiController;
  final TextEditingController valueController;

  @override
  Widget build(BuildContext context) {
    final isExchange = context.select((AddSaleCubit cubit) => cubit.state.isExchange);
    if (!isExchange) return const SizedBox.shrink();
    final cubit = context.read<AddSaleCubit>();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SectionTitle('Old phone'),
        TextField(
          controller: nameController,
          onChanged: cubit.setExchangeDeviceName,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(labelText: 'Model, e.g. iPhone 12'),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: MoneyField(
                label: 'Exchange value',
                controller: valueController,
                onChanged: (text) => cubit.setExchangeValue(parseMoneyInput(text)),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextField(
                controller: imeiController,
                onChanged: cubit.setExchangeImei,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'IMEI (optional)'),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _PaymentSection extends StatelessWidget {
  const _PaymentSection({required this.amountPaidController});

  final TextEditingController amountPaidController;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AddSaleCubit>().state;
    final cubit = context.read<AddSaleCubit>();
    final isCredit = state.paymentMethod == PaymentMethod.credit;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final method in PaymentMethod.values)
              ChoiceChip(
                label: Text(method.label),
                selected: method == state.paymentMethod,
                onSelected: (_) {
                  amountPaidController.clear();
                  cubit.selectPaymentMethod(method);
                },
              ),
          ],
        ),
        if (isCredit)
          const Padding(
            padding: EdgeInsets.only(top: 8),
            child: Text('The full amount will be pending until the customer pays.'),
          )
        else ...[
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Customer paid only part'),
            value: state.isPartPayment,
            onChanged: (value) {
              amountPaidController.clear();
              cubit.setPartPayment(value);
            },
          ),
          if (state.isPartPayment)
            MoneyField(
              label: 'Amount paid now',
              controller: amountPaidController,
              onChanged: (text) => cubit.setAmountPaid(parseMoneyInput(text)),
            ),
        ],
      ],
    );
  }
}

class _CustomerTile extends StatelessWidget {
  const _CustomerTile();

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AddSaleCubit>().state;
    final cubit = context.read<AddSaleCubit>();
    final customer = state.customer;
    final needed = state.hasPending && customer == null;
    return Card(
      child: ListTile(
        leading: const Icon(Icons.person_outline),
        title: Text(customer?.name ?? 'Add customer (optional)'),
        subtitle: needed
            ? Text(
                'Needed to track the pending amount',
                style: TextStyle(color: Theme.of(context).colorScheme.warning),
              )
            : (customer?.phone == null ? null : Text(customer!.phone!)),
        trailing: customer == null
            ? const Icon(Icons.chevron_right)
            : IconButton(
                tooltip: 'Remove customer',
                icon: const Icon(Icons.close),
                onPressed: () => cubit.selectCustomer(null),
              ),
        onTap: () async {
          final chosen = await pickCustomer(context);
          if (chosen != null) cubit.selectCustomer(chosen);
        },
      ),
    );
  }
}

class _Summary extends StatelessWidget {
  const _Summary();

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AddSaleCubit>().state;
    if (state.product == null) return const SizedBox.shrink();
    final colors = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            AmountRow(label: 'Total', value: formatRupees(state.total), bold: true),
            if (state.isExchange) ...[
              AmountRow(label: 'Old phone', value: '-${formatRupees(state.exchangeAmount)}'),
              AmountRow(
                label: 'Customer pays',
                value: formatRupees(state.customerPays),
                bold: true,
              ),
            ],
            if (state.hasPending)
              AmountRow(
                label: 'Pending',
                value: formatRupees(state.pendingAmount),
                color: colors.warning,
              ),
          ],
        ),
      ),
    );
  }
}

class _SaveBar extends StatelessWidget {
  const _SaveBar();

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AddSaleCubit>().state;
    if (state.status == AddSaleStatus.loading || state.status == AddSaleStatus.loadFailed) {
      return const SizedBox.shrink();
    }
    final problem = state.product == null ? null : state.problem;
    final saving = state.status == AddSaleStatus.saving;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (problem != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  problem,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
            FilledButton(
              onPressed: state.canSave ? context.read<AddSaleCubit>().submit : null,
              child: saving
                  ? const SizedBox.square(
                      dimension: 24,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(
                      state.product == null
                          ? 'Save sale'
                          : 'Save sale · ${formatRupees(state.customerPays)}',
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Confirms the saved sale with the server's figures, and offers the next sale.
class _SavedSheet extends StatelessWidget {
  const _SavedSheet({required this.sale});

  final SaleDetail sale;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final summary = sale.summary;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Icon(Icons.check_circle, color: colors.gain, size: 56),
            const SizedBox(height: 8),
            Text(
              'Sale saved',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 16),
            AmountRow(label: 'Total', value: formatRupees(summary.total), bold: true),
            AmountRow(label: 'Profit', value: formatRupees(summary.profit), color: colors.gain),
            if (summary.hasPending)
              AmountRow(
                label: 'Pending from ${summary.customerName ?? 'customer'}',
                value: formatRupees(summary.pendingAmount),
                color: colors.warning,
              ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Add another sale'),
            ),
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Done'),
            ),
          ],
        ),
      ),
    );
  }
}
