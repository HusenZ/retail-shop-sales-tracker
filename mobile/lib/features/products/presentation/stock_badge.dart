import 'package:flutter/material.dart';

import '../../../core/theme.dart';
import '../domain/product.dart';

class StockBadge extends StatelessWidget {
  const StockBadge({required this.product, super.key});

  final Product product;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final color = switch (product.stockStatus) {
      StockStatus.out => colors.error,
      StockStatus.low => colors.warning,
      StockStatus.inStock => colors.gain,
      StockStatus.notTracked => colors.outline,
    };
    final label = switch (product.stockStatus) {
      StockStatus.inStock || StockStatus.low => '${product.stockQty} left',
      StockStatus.out => 'Out',
      StockStatus.notTracked => '—',
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        border: Border.all(color: color),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(label, style: TextStyle(color: color, fontWeight: FontWeight.w600)),
    );
  }
}
