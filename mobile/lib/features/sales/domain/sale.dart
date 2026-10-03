import 'package:decimal/decimal.dart';
import 'package:equatable/equatable.dart';

import '../../../core/api/api_client.dart';
import '../../../core/format/dates.dart';
import '../../../core/format/money.dart';

enum PaymentMethod {
  cash('Cash'),
  upi('UPI'),
  card('Card'),
  credit('Credit'),
  other('Other');

  const PaymentMethod(this.label);

  final String label;

  String get apiValue => name;

  static PaymentMethod fromApi(String value) => values.byName(value);

  /// Methods that money can actually be received by (everything except credit).
  static const received = [cash, upi, card, other];
}

/// One row of sale history.
class SaleSummary extends Equatable {
  const SaleSummary({
    required this.id,
    required this.soldAt,
    required this.saleTypeId,
    required this.saleTypeName,
    required this.productNames,
    required this.paymentMethod,
    required this.total,
    required this.profit,
    required this.amountDue,
    required this.amountPaid,
    required this.pendingAmount,
    this.customerId,
    this.customerName,
  });

  factory SaleSummary.fromJson(Json json) => SaleSummary(
        id: json['id'] as String,
        soldAt: DateTime.parse(json['sold_at'] as String),
        saleTypeId: json['sale_type_id'] as String,
        saleTypeName: json['sale_type_name'] as String,
        customerId: json['customer_id'] as String?,
        customerName: json['customer_name'] as String?,
        productNames: (json['product_names'] as List<dynamic>).cast<String>(),
        paymentMethod: PaymentMethod.fromApi(json['payment_method'] as String),
        total: parseMoney(json['total']),
        profit: parseMoney(json['profit']),
        amountDue: parseMoney(json['amount_due']),
        amountPaid: parseMoney(json['amount_paid']),
        pendingAmount: parseMoney(json['pending_amount']),
      );

  final String id;
  final DateTime soldAt;
  final String saleTypeId;
  final String saleTypeName;
  final String? customerId;
  final String? customerName;
  final List<String> productNames;
  final PaymentMethod paymentMethod;

  /// Revenue after discount.
  final Decimal total;
  final Decimal profit;

  /// What the customer pays: total minus any old-phone exchange value.
  final Decimal amountDue;
  final Decimal amountPaid;
  final Decimal pendingAmount;

  bool get hasPending => pendingAmount > Decimal.zero;

  String get title => switch (productNames.length) {
        0 => saleTypeName,
        1 => productNames.first,
        _ => '${productNames.first} +${productNames.length - 1} more',
      };

  @override
  List<Object?> get props => [
        id,
        soldAt,
        saleTypeId,
        saleTypeName,
        customerId,
        customerName,
        productNames,
        paymentMethod,
        total,
        profit,
        amountDue,
        amountPaid,
        pendingAmount,
      ];
}

class SaleItem extends Equatable {
  const SaleItem({
    required this.productId,
    required this.productName,
    required this.quantity,
    required this.unitPrice,
    required this.discount,
    required this.revenue,
    required this.cost,
    required this.profit,
  });

  factory SaleItem.fromJson(Json json) => SaleItem(
        productId: json['product_id'] as String,
        productName: json['product_name'] as String,
        quantity: json['quantity'] as int,
        unitPrice: parseMoney(json['unit_price']),
        discount: parseMoney(json['discount']),
        revenue: parseMoney(json['revenue']),
        cost: parseMoney(json['cost']),
        profit: parseMoney(json['profit']),
      );

  final String productId;
  final String productName;
  final int quantity;
  final Decimal unitPrice;
  final Decimal discount;
  final Decimal revenue;
  final Decimal cost;
  final Decimal profit;

  @override
  List<Object?> get props =>
      [productId, productName, quantity, unitPrice, discount, revenue, cost, profit];
}

class Payment extends Equatable {
  const Payment({required this.amount, required this.method, required this.paidAt});

  factory Payment.fromJson(Json json) => Payment(
        amount: parseMoney(json['amount']),
        method: PaymentMethod.fromApi(json['method'] as String),
        paidAt: DateTime.parse(json['paid_at'] as String),
      );

  final Decimal amount;
  final PaymentMethod method;
  final DateTime paidAt;

  @override
  List<Object?> get props => [amount, method, paidAt];
}

class SaleDetail extends Equatable {
  const SaleDetail({
    required this.summary,
    required this.subtotal,
    required this.discount,
    required this.totalCost,
    required this.exchangeValue,
    required this.items,
    required this.payments,
    this.exchangeDeviceName,
    this.exchangeDeviceImei,
    this.notes,
  });

  factory SaleDetail.fromJson(Json json) => SaleDetail(
        summary: SaleSummary.fromJson(json),
        subtotal: parseMoney(json['subtotal']),
        discount: parseMoney(json['discount']),
        totalCost: parseMoney(json['total_cost']),
        exchangeValue: parseMoney(json['exchange_value']),
        exchangeDeviceName: json['exchange_device_name'] as String?,
        exchangeDeviceImei: json['exchange_device_imei'] as String?,
        notes: json['notes'] as String?,
        items: (json['items'] as List<dynamic>).cast<Json>().map(SaleItem.fromJson).toList(),
        payments:
            (json['payments'] as List<dynamic>).cast<Json>().map(Payment.fromJson).toList(),
      );

  final SaleSummary summary;
  final Decimal subtotal;
  final Decimal discount;
  final Decimal totalCost;
  final Decimal exchangeValue;
  final String? exchangeDeviceName;
  final String? exchangeDeviceImei;
  final String? notes;
  final List<SaleItem> items;
  final List<Payment> payments;

  bool get isExchange => exchangeDeviceName != null;

  @override
  List<Object?> get props => [
        summary,
        subtotal,
        discount,
        totalCost,
        exchangeValue,
        exchangeDeviceName,
        exchangeDeviceImei,
        notes,
        items,
        payments,
      ];
}

class NewSaleItem extends Equatable {
  const NewSaleItem({required this.productId, required this.quantity, this.unitPrice});

  final String productId;
  final int quantity;

  /// Sent only when the shopkeeper changed the product's usual price.
  final Decimal? unitPrice;

  Json toJson() => {
        'product_id': productId,
        'quantity': quantity,
        if (unitPrice != null) 'unit_price': unitPrice.toString(),
      };

  @override
  List<Object?> get props => [productId, quantity, unitPrice];
}

class ExchangeDetails extends Equatable {
  const ExchangeDetails({required this.deviceName, required this.value, this.imei});

  final String deviceName;
  final String? imei;
  final Decimal value;

  Json toJson() => {'device_name': deviceName, 'imei': imei, 'value': value.toString()};

  @override
  List<Object?> get props => [deviceName, imei, value];
}

/// A sale as entered on the phone. The server calculates every total and the profit.
class NewSale extends Equatable {
  const NewSale({
    required this.saleTypeId,
    required this.items,
    required this.paymentMethod,
    required this.clientRef,
    this.discount,
    this.amountPaid,
    this.customerId,
    this.notes,
    this.exchange,
    this.soldAt,
  });

  final String saleTypeId;
  final List<NewSaleItem> items;
  final PaymentMethod paymentMethod;

  /// Unique per sale so a retried upload is never saved twice.
  final String clientRef;
  final Decimal? discount;

  /// Null means paid in full (or nothing, for credit).
  final Decimal? amountPaid;
  final String? customerId;
  final String? notes;
  final ExchangeDetails? exchange;
  final DateTime? soldAt;

  Json toJson() => {
        'sale_type_id': saleTypeId,
        'items': [for (final item in items) item.toJson()],
        'payment_method': paymentMethod.apiValue,
        'client_ref': clientRef,
        if (discount != null) 'discount': discount.toString(),
        if (amountPaid != null) 'amount_paid': amountPaid.toString(),
        if (customerId != null) 'customer_id': customerId,
        if (notes != null) 'notes': notes,
        if (exchange != null) 'exchange': exchange!.toJson(),
        if (soldAt != null) 'sold_at': soldAt!.toUtc().toIso8601String(),
      };

  @override
  List<Object?> get props => [
        saleTypeId,
        items,
        paymentMethod,
        clientRef,
        discount,
        amountPaid,
        customerId,
        notes,
        exchange,
        soldAt,
      ];
}

class SaleFilters extends Equatable {
  const SaleFilters({
    this.firstDay,
    this.lastDay,
    this.saleTypeId,
    this.categoryId,
    this.paymentMethod,
    this.customerId,
    this.pendingOnly = false,
  });

  final DateTime? firstDay;
  final DateTime? lastDay;
  final String? saleTypeId;
  final String? categoryId;
  final PaymentMethod? paymentMethod;
  final String? customerId;
  final bool pendingOnly;

  bool get isEmpty => this == const SaleFilters();

  Map<String, Object?> toQuery() => {
        'date_from': firstDay == null ? null : apiDate(firstDay!),
        'date_to': lastDay == null ? null : apiDate(lastDay!),
        'sale_type_id': saleTypeId,
        'category_id': categoryId,
        'payment_method': paymentMethod?.apiValue,
        'customer_id': customerId,
        'pending_only': pendingOnly ? true : null,
      };

  @override
  List<Object?> get props =>
      [firstDay, lastDay, saleTypeId, categoryId, paymentMethod, customerId, pendingOnly];
}

class PendingPayments extends Equatable {
  const PendingPayments({required this.totalPending, required this.saleCount, required this.sales});

  factory PendingPayments.fromJson(Json json) => PendingPayments(
        totalPending: parseMoney(json['total_pending']),
        saleCount: json['sale_count'] as int,
        sales: (json['sales'] as List<dynamic>).cast<Json>().map(SaleSummary.fromJson).toList(),
      );

  final Decimal totalPending;
  final int saleCount;
  final List<SaleSummary> sales;

  @override
  List<Object?> get props => [totalPending, saleCount, sales];
}
