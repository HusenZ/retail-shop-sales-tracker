import 'package:decimal/decimal.dart';
import 'package:equatable/equatable.dart';

import '../../../core/api/api_client.dart';
import '../../../core/format/money.dart';

class PeriodTotals extends Equatable {
  const PeriodTotals({
    required this.firstDay,
    required this.salesTotal,
    required this.saleCount,
    required this.profit,
  });

  factory PeriodTotals.fromJson(Json json) => PeriodTotals(
        firstDay: DateTime.parse(json['first_day'] as String),
        salesTotal: parseMoney(json['sales_total']),
        saleCount: json['sale_count'] as int,
        profit: parseMoney(json['profit']),
      );

  final DateTime firstDay;
  final Decimal salesTotal;
  final int saleCount;
  final Decimal profit;

  @override
  List<Object?> get props => [firstDay, salesTotal, saleCount, profit];
}

/// Figures for the home screen, all calculated by the server.
class Dashboard extends Equatable {
  const Dashboard({
    required this.today,
    required this.thisWeek,
    required this.thisMonth,
    required this.pendingTotal,
    required this.pendingSaleCount,
  });

  factory Dashboard.fromJson(Json json) => Dashboard(
        today: PeriodTotals.fromJson(json['today'] as Json),
        thisWeek: PeriodTotals.fromJson(json['this_week'] as Json),
        thisMonth: PeriodTotals.fromJson(json['this_month'] as Json),
        pendingTotal: parseMoney(json['pending_total']),
        pendingSaleCount: json['pending_sale_count'] as int,
      );

  final PeriodTotals today;
  final PeriodTotals thisWeek;
  final PeriodTotals thisMonth;
  final Decimal pendingTotal;
  final int pendingSaleCount;

  @override
  List<Object?> get props => [today, thisWeek, thisMonth, pendingTotal, pendingSaleCount];
}
