import 'package:decimal/decimal.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../core/api/api_exception.dart';
import '../../../core/format/dates.dart';
import '../../../core/format/money.dart';
import '../../../core/load_status.dart';
import '../../../core/theme.dart';
import '../../../core/widgets/async_views.dart';
import '../../../core/widgets/inputs.dart';
import '../../../core/widgets/stat_tile.dart';
import '../data/sale_repository.dart';
import '../domain/sale.dart';

class SaleDetailState extends Equatable {
  const SaleDetailState({
    this.status = LoadStatus.initial,
    this.sale,
    this.isSaving = false,
    this.errorMessage,
  });

  final LoadStatus status;
  final SaleDetail? sale;
  final bool isSaving;
  final String? errorMessage;

  @override
  List<Object?> get props => [status, sale, isSaving, errorMessage];
}

class SaleDetailCubit extends Cubit<SaleDetailState> {
  SaleDetailCubit(this._sales, this.saleId) : super(const SaleDetailState());

  final SaleRepository _sales;
  final String saleId;

  Future<void> load() async {
    emit(const SaleDetailState(status: LoadStatus.loading));
    try {
      emit(SaleDetailState(status: LoadStatus.success, sale: await _sales.get(saleId)));
    } on ApiException catch (error) {
      emit(SaleDetailState(status: LoadStatus.failure, errorMessage: error.message));
    }
  }

  /// Returns true once the payment is saved.
  Future<bool> recordPayment(Decimal amount, PaymentMethod method) async {
    emit(SaleDetailState(status: state.status, sale: state.sale, isSaving: true));
    try {
      final sale = await _sales.recordPayment(saleId, amount: amount, method: method);
      emit(SaleDetailState(status: LoadStatus.success, sale: sale));
      return true;
    } on ApiException catch (error) {
      emit(SaleDetailState(status: state.status, sale: state.sale, errorMessage: error.message));
      return false;
    }
  }
}

class SaleDetailPage extends StatelessWidget {
  const SaleDetailPage({required this.saleId, super.key});

  final String saleId;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => SaleDetailCubit(context.read<SaleRepository>(), saleId)..load(),
      child: BlocConsumer<SaleDetailCubit, SaleDetailState>(
        listenWhen: (_, current) =>
            current.errorMessage != null && current.status == LoadStatus.success,
        listener: (context, state) => showMessage(context, state.errorMessage!),
        builder: (context, state) => Scaffold(
          appBar: AppBar(title: const Text('Sale')),
          body: switch (state.status) {
            LoadStatus.success => _SaleDetails(sale: state.sale!),
            LoadStatus.failure => ErrorView(
                message: state.errorMessage!,
                onRetry: context.read<SaleDetailCubit>().load,
              ),
            _ => const LoadingView(),
          },
        ),
      ),
    );
  }
}

class _SaleDetails extends StatelessWidget {
  const _SaleDetails({required this.sale});

  final SaleDetail sale;

  @override
  Widget build(BuildContext context) {
    final summary = sale.summary;
    final colors = Theme.of(context).colorScheme;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        StatTile(label: summary.saleTypeName, value: formatRupees(summary.total), large: true),
        const SizedBox(height: 4),
        Text(formatDateTime(summary.soldAt)),
        if (summary.customerName != null)
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.person_outline),
            title: Text(summary.customerName!),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('/customers/${summary.customerId}'),
          ),
        const SectionTitle('Items'),
        for (final item in sale.items)
          AmountRow(
            label: '${item.productName}  ×${item.quantity}',
            value: formatRupees(item.unitPrice * Decimal.fromInt(item.quantity)),
          ),
        const Divider(),
        if (sale.discount > Decimal.zero)
          AmountRow(label: 'Discount', value: '-${formatRupees(sale.discount)}'),
        AmountRow(label: 'Total', value: formatRupees(summary.total), bold: true),
        AmountRow(label: 'Cost', value: formatRupees(sale.totalCost)),
        AmountRow(
          label: 'Profit',
          value: formatRupees(summary.profit),
          bold: true,
          color: summary.profit < Decimal.zero ? colors.error : colors.gain,
        ),
        if (sale.isExchange) ...[
          const SectionTitle('Old phone taken'),
          AmountRow(
            label: [sale.exchangeDeviceName!, if (sale.exchangeDeviceImei != null) sale.exchangeDeviceImei!]
                .join(' · '),
            value: '-${formatRupees(sale.exchangeValue)}',
          ),
          AmountRow(label: 'Customer pays', value: formatRupees(summary.amountDue), bold: true),
        ],
        const SectionTitle('Payment'),
        for (final payment in sale.payments)
          AmountRow(
            label: '${payment.method.label} · ${formatDate(payment.paidAt)}',
            value: formatRupees(payment.amount),
          ),
        if (sale.payments.isEmpty) const Text('Nothing paid yet.'),
        if (summary.hasPending) ...[
          AmountRow(
            label: 'Pending',
            value: formatRupees(summary.pendingAmount),
            bold: true,
            color: colors.warning,
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            icon: const Icon(Icons.payments_outlined),
            label: const Text('Record payment'),
            onPressed: () => _showPaymentSheet(context, summary.pendingAmount),
          ),
        ],
        if (sale.notes != null) ...[
          const SectionTitle('Note'),
          Text(sale.notes!),
        ],
      ],
    );
  }
}

Future<void> _showPaymentSheet(BuildContext context, Decimal pending) {
  final cubit = context.read<SaleDetailCubit>();
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => BlocProvider.value(value: cubit, child: _PaymentSheet(pending: pending)),
  );
}

class _PaymentSheet extends StatefulWidget {
  const _PaymentSheet({required this.pending});

  final Decimal pending;

  @override
  State<_PaymentSheet> createState() => _PaymentSheetState();
}

class _PaymentSheetState extends State<_PaymentSheet> {
  final _formKey = GlobalKey<FormState>();
  late final _amount = TextEditingController(text: moneyInputText(widget.pending));
  PaymentMethod _method = PaymentMethod.cash;

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final saved = await context
        .read<SaleDetailCubit>()
        .recordPayment(parseMoneyInput(_amount.text)!, _method);
    if (saved && mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final isSaving = context.select((SaleDetailCubit cubit) => cubit.state.isSaving);
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + MediaQuery.of(context).viewInsets.bottom),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Record payment', style: Theme.of(context).textTheme.titleLarge),
            Text('${formatRupees(widget.pending)} pending'),
            const SizedBox(height: 16),
            MoneyField(label: 'Amount received', controller: _amount, isRequired: true, allowZero: false),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              children: [
                for (final method in PaymentMethod.received)
                  ChoiceChip(
                    label: Text(method.label),
                    selected: method == _method,
                    onSelected: (_) => setState(() => _method = method),
                  ),
              ],
            ),
            const SizedBox(height: 24),
            FilledButton(onPressed: isSaving ? null : _save, child: const Text('Save payment')),
          ],
        ),
      ),
    );
  }
}
