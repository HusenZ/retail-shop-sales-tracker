import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/format/dates.dart';
import '../../../core/format/money.dart';
import '../../../core/theme.dart';
import '../domain/sale.dart';

/// One sale in a history list: product, type, payment, amount and profit.
class SaleTile extends StatelessWidget {
  const SaleTile({required this.sale, this.showDate = false, super.key});

  final SaleSummary sale;
  final bool showDate;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final when = showDate ? formatDateTime(sale.soldAt) : formatTime(sale.soldAt);
    return ListTile(
      onTap: () => context.push('/sales/${sale.id}'),
      title: Text(sale.title, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text(
        [
          sale.saleTypeName,
          sale.paymentMethod.label,
          if (sale.customerName != null) sale.customerName!,
          when,
        ].join(' · '),
      ),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            formatRupees(sale.total),
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          Text(
            sale.hasPending
                ? '${formatRupees(sale.pendingAmount)} due'
                : 'Profit ${formatRupees(sale.profit)}',
            style: TextStyle(color: sale.hasPending ? colors.warning : colors.gain, fontSize: 12),
          ),
        ],
      ),
    );
  }
}
