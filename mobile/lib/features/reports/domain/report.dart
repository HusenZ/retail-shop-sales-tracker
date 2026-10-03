import 'package:decimal/decimal.dart';
import 'package:equatable/equatable.dart';

import '../../../core/api/api_client.dart';
import '../../../core/format/money.dart';

class ReportTotals extends Equatable {
  const ReportTotals({
    required this.saleCount,
    required this.revenue,
    required this.cost,
    required this.grossProfit,
    required this.discount,
    required this.expenses,
    required this.netProfit,
  });

  factory ReportTotals.fromJson(Json json) => ReportTotals(
        saleCount: json['sale_count'] as int,
        revenue: parseMoney(json['revenue']),
        cost: parseMoney(json['cost']),
        grossProfit: parseMoney(json['gross_profit']),
        discount: parseMoney(json['discount']),
        expenses: parseMoney(json['expenses']),
        netProfit: parseMoney(json['net_profit']),
      );

  final int saleCount;
  final Decimal revenue;
  final Decimal cost;
  final Decimal grossProfit;
  final Decimal discount;
  final Decimal expenses;
  final Decimal netProfit;

  @override
  List<Object?> get props => [saleCount, revenue, cost, grossProfit, discount, expenses, netProfit];
}

/// A category or sale type with its revenue and profit.
class GroupRow extends Equatable {
  const GroupRow({
    required this.name,
    required this.revenue,
    required this.profit,
    required this.quantity,
  });

  factory GroupRow.fromJson(Json json) => GroupRow(
        name: json['name'] as String,
        revenue: parseMoney(json['revenue']),
        profit: parseMoney(json['profit']),
        quantity: json['quantity'] as int,
      );

  final String name;
  final Decimal revenue;
  final Decimal profit;
  final int quantity;

  @override
  List<Object?> get props => [name, revenue, profit, quantity];
}

/// How the period's revenue was settled; the rows add up to revenue.
class MoneyRow extends Equatable {
  const MoneyRow({required this.method, required this.amount});

  factory MoneyRow.fromJson(Json json) =>
      MoneyRow(method: json['method'] as String, amount: parseMoney(json['amount']));

  final String method;
  final Decimal amount;

  String get label => switch (method) {
        'cash' => 'Cash',
        'upi' => 'UPI',
        'card' => 'Card',
        'credit' => 'Pending (credit)',
        'exchange' => 'Old phones taken',
        _ => 'Other',
      };

  @override
  List<Object?> get props => [method, amount];
}

class ReportSummary extends Equatable {
  const ReportSummary({
    required this.totals,
    required this.byCategory,
    required this.bySaleType,
    required this.byPaymentMethod,
  });

  factory ReportSummary.fromJson(Json json) => ReportSummary(
        totals: ReportTotals.fromJson(json['totals'] as Json),
        byCategory: _rows(json['by_category'], GroupRow.fromJson),
        bySaleType: _rows(json['by_sale_type'], GroupRow.fromJson),
        byPaymentMethod: _rows(json['by_payment_method'], MoneyRow.fromJson),
      );

  final ReportTotals totals;
  final List<GroupRow> byCategory;
  final List<GroupRow> bySaleType;
  final List<MoneyRow> byPaymentMethod;

  static List<T> _rows<T>(Object? rows, T Function(Json) fromJson) =>
      (rows as List<dynamic>).cast<Json>().map(fromJson).toList();

  @override
  List<Object?> get props => [totals, byCategory, bySaleType, byPaymentMethod];
}
