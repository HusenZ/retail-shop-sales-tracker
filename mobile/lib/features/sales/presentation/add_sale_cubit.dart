import 'package:decimal/decimal.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:uuid/uuid.dart';

import '../../../core/api/api_exception.dart';
import '../../customers/domain/customer.dart';
import '../../products/domain/product.dart';
import '../data/sale_repository.dart';
import '../data/sale_type_repository.dart';
import '../domain/sale.dart';
import '../domain/sale_type.dart';

enum AddSaleStatus { loading, loadFailed, ready, saving, saved }

class AddSaleState extends Equatable {
  const AddSaleState({
    required this.clientRef,
    this.status = AddSaleStatus.loading,
    this.saleTypes = const [],
    this.saleType,
    this.product,
    this.quantity = 1,
    this.unitPrice,
    this.discount,
    this.paymentMethod = PaymentMethod.cash,
    this.isPartPayment = false,
    this.amountPaid,
    this.customer,
    this.notes = '',
    this.exchangeDeviceName = '',
    this.exchangeImei = '',
    this.exchangeValue,
    this.errorMessage,
    this.savedSale,
  });

  /// Stays the same while retrying, so a sale the server already saved is not duplicated.
  final String clientRef;
  final AddSaleStatus status;
  final List<SaleType> saleTypes;
  final SaleType? saleType;
  final Product? product;
  final int quantity;

  /// Null while the product's usual selling price is used.
  final Decimal? unitPrice;
  final Decimal? discount;
  final PaymentMethod paymentMethod;

  /// The customer paid only part now; the rest stays pending.
  final bool isPartPayment;
  final Decimal? amountPaid;
  final Customer? customer;
  final String notes;
  final String exchangeDeviceName;
  final String exchangeImei;
  final Decimal? exchangeValue;
  final String? errorMessage;

  /// The sale as saved by the server, with its real totals and profit.
  final SaleDetail? savedSale;

  // The amounts below are an on-screen preview only; the server calculates the
  // saved figures and the profit.

  Decimal get price => unitPrice ?? product?.sellingPrice ?? Decimal.zero;

  Decimal get subtotal => price * Decimal.fromInt(quantity);

  Decimal get total => subtotal - (discount ?? Decimal.zero);

  bool get isExchange => saleType?.isExchange ?? false;

  Decimal get exchangeAmount => isExchange ? (exchangeValue ?? Decimal.zero) : Decimal.zero;

  Decimal get customerPays => total - exchangeAmount;

  Decimal get paidNow {
    if (paymentMethod == PaymentMethod.credit) return Decimal.zero;
    if (isPartPayment) return amountPaid ?? Decimal.zero;
    return customerPays;
  }

  Decimal get pendingAmount => customerPays - paidNow;

  bool get hasPending => pendingAmount > Decimal.zero;

  /// The first thing stopping the sale from being saved, in words the shopkeeper understands.
  String? get problem {
    final product = this.product;
    if (saleType == null) return 'Choose a sale type';
    if (product == null) return 'Choose a product';
    if (product.trackStock && quantity > product.stockQty) {
      return 'Only ${product.stockQty} in stock';
    }
    if ((discount ?? Decimal.zero) > subtotal) return 'Discount is more than the price';
    if (isExchange) {
      if (exchangeDeviceName.trim().isEmpty) return 'Enter the old phone model';
      if (exchangeValue == null) return 'Enter the old phone value';
      if (exchangeAmount > total) return 'Old phone value is more than the sale';
    }
    if (isPartPayment && amountPaid == null) return 'Enter the amount paid now';
    if (paidNow > customerPays) return 'Amount paid is more than the total';
    if (hasPending && customer == null) return 'Choose the customer who will pay the rest';
    return null;
  }

  bool get canSave => status == AddSaleStatus.ready && problem == null;

  AddSaleState copyWith({
    AddSaleStatus? status,
    List<SaleType>? saleTypes,
    ValueGetter<SaleType?>? saleType,
    ValueGetter<Product?>? product,
    int? quantity,
    ValueGetter<Decimal?>? unitPrice,
    ValueGetter<Decimal?>? discount,
    PaymentMethod? paymentMethod,
    bool? isPartPayment,
    ValueGetter<Decimal?>? amountPaid,
    ValueGetter<Customer?>? customer,
    String? notes,
    String? exchangeDeviceName,
    String? exchangeImei,
    ValueGetter<Decimal?>? exchangeValue,
    ValueGetter<String?>? errorMessage,
    ValueGetter<SaleDetail?>? savedSale,
  }) =>
      AddSaleState(
        clientRef: clientRef,
        status: status ?? this.status,
        saleTypes: saleTypes ?? this.saleTypes,
        saleType: saleType != null ? saleType() : this.saleType,
        product: product != null ? product() : this.product,
        quantity: quantity ?? this.quantity,
        unitPrice: unitPrice != null ? unitPrice() : this.unitPrice,
        discount: discount != null ? discount() : this.discount,
        paymentMethod: paymentMethod ?? this.paymentMethod,
        isPartPayment: isPartPayment ?? this.isPartPayment,
        amountPaid: amountPaid != null ? amountPaid() : this.amountPaid,
        customer: customer != null ? customer() : this.customer,
        notes: notes ?? this.notes,
        exchangeDeviceName: exchangeDeviceName ?? this.exchangeDeviceName,
        exchangeImei: exchangeImei ?? this.exchangeImei,
        exchangeValue: exchangeValue != null ? exchangeValue() : this.exchangeValue,
        errorMessage: errorMessage != null ? errorMessage() : this.errorMessage,
        savedSale: savedSale != null ? savedSale() : this.savedSale,
      );

  @override
  List<Object?> get props => [
        clientRef,
        status,
        saleTypes,
        saleType,
        product,
        quantity,
        unitPrice,
        discount,
        paymentMethod,
        isPartPayment,
        amountPaid,
        customer,
        notes,
        exchangeDeviceName,
        exchangeImei,
        exchangeValue,
        errorMessage,
        savedSale,
      ];
}

/// Drives the Add Sale screen: sale type → product → quantity → payment → save.
class AddSaleCubit extends Cubit<AddSaleState> {
  AddSaleCubit(this._saleTypes, this._sales, {String Function()? newClientRef})
      : _newClientRef = newClientRef ?? _randomId,
        super(AddSaleState(clientRef: (newClientRef ?? _randomId)()));

  final SaleTypeRepository _saleTypes;
  final SaleRepository _sales;
  final String Function() _newClientRef;

  static String _randomId() => const Uuid().v4();

  Future<void> load() async {
    emit(state.copyWith(status: AddSaleStatus.loading, errorMessage: () => null));
    try {
      final saleTypes = await _saleTypes.list();
      emit(
        state.copyWith(
          status: AddSaleStatus.ready,
          saleTypes: saleTypes,
          saleType: () => state.saleType ?? _defaultOf(saleTypes),
        ),
      );
    } on ApiException catch (error) {
      emit(state.copyWith(status: AddSaleStatus.loadFailed, errorMessage: () => error.message));
    }
  }

  void selectSaleType(SaleType saleType) => emit(state.copyWith(saleType: () => saleType));

  void selectProduct(Product product) => emit(
        state.copyWith(product: () => product, unitPrice: () => null, quantity: 1),
      );

  void setQuantity(int quantity) {
    if (quantity >= 1) emit(state.copyWith(quantity: quantity));
  }

  void increaseQuantity() => setQuantity(state.quantity + 1);

  void decreaseQuantity() => setQuantity(state.quantity - 1);

  void setUnitPrice(Decimal? price) {
    final usualPrice = state.product?.sellingPrice;
    emit(state.copyWith(unitPrice: () => price == usualPrice ? null : price));
  }

  void setDiscount(Decimal? discount) => emit(
        state.copyWith(discount: () => discount == Decimal.zero ? null : discount),
      );

  void selectPaymentMethod(PaymentMethod method) {
    final isCredit = method == PaymentMethod.credit;
    emit(
      state.copyWith(
        paymentMethod: method,
        isPartPayment: isCredit ? false : null,
        amountPaid: isCredit ? () => null : null,
      ),
    );
  }

  void setPartPayment(bool isPartPayment) => emit(
        state.copyWith(isPartPayment: isPartPayment, amountPaid: () => null),
      );

  void setAmountPaid(Decimal? amount) => emit(state.copyWith(amountPaid: () => amount));

  void selectCustomer(Customer? customer) => emit(state.copyWith(customer: () => customer));

  void setNotes(String notes) => emit(state.copyWith(notes: notes));

  void setExchangeDeviceName(String name) => emit(state.copyWith(exchangeDeviceName: name));

  void setExchangeImei(String imei) => emit(state.copyWith(exchangeImei: imei));

  void setExchangeValue(Decimal? value) => emit(state.copyWith(exchangeValue: () => value));

  Future<void> submit() async {
    if (!state.canSave) return;
    emit(state.copyWith(status: AddSaleStatus.saving, errorMessage: () => null));
    try {
      final saved = await _sales.create(_buildSale());
      emit(state.copyWith(status: AddSaleStatus.saved, savedSale: () => saved));
    } on ApiException catch (error) {
      emit(state.copyWith(status: AddSaleStatus.ready, errorMessage: () => error.message));
    }
  }

  /// Clears the form for the next customer, keeping the chosen sale type.
  void startNew() => emit(
        AddSaleState(
          clientRef: _newClientRef(),
          status: AddSaleStatus.ready,
          saleTypes: state.saleTypes,
          saleType: state.saleType,
        ),
      );

  NewSale _buildSale() {
    final current = state;
    final imei = current.exchangeImei.trim();
    final notes = current.notes.trim();
    return NewSale(
      saleTypeId: current.saleType!.id,
      items: [
        NewSaleItem(
          productId: current.product!.id,
          quantity: current.quantity,
          unitPrice: current.unitPrice,
        ),
      ],
      paymentMethod: current.paymentMethod,
      clientRef: current.clientRef,
      discount: current.discount,
      amountPaid: current.isPartPayment ? current.amountPaid : null,
      customerId: current.customer?.id,
      notes: notes.isEmpty ? null : notes,
      exchange: current.isExchange
          ? ExchangeDetails(
              deviceName: current.exchangeDeviceName.trim(),
              imei: imei.isEmpty ? null : imei,
              value: current.exchangeValue!,
            )
          : null,
    );
  }

  static SaleType? _defaultOf(List<SaleType> saleTypes) =>
      saleTypes.where((saleType) => saleType.isDefault).firstOrNull ?? saleTypes.firstOrNull;
}
