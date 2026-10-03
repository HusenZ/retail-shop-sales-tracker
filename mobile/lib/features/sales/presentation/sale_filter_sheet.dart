import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/format/dates.dart';
import '../../products/data/category_repository.dart';
import '../../products/domain/category.dart';
import '../data/sale_type_repository.dart';
import '../domain/sale.dart';
import '../domain/sale_type.dart';

enum _DateRange { all, today, week, month, custom }

/// Lets the shopkeeper narrow sale history by date, type, category and payment.
Future<SaleFilters?> showSaleFilters(BuildContext context, SaleFilters current) {
  return showModalBottomSheet<SaleFilters>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => _SaleFilterSheet(
      initial: current,
      saleTypes: context.read<SaleTypeRepository>().list(includeInactive: true),
      categories: context.read<CategoryRepository>().list(includeInactive: true),
    ),
  );
}

class _SaleFilterSheet extends StatefulWidget {
  const _SaleFilterSheet({
    required this.initial,
    required this.saleTypes,
    required this.categories,
  });

  final SaleFilters initial;
  final Future<List<SaleType>> saleTypes;
  final Future<List<Category>> categories;

  @override
  State<_SaleFilterSheet> createState() => _SaleFilterSheetState();
}

class _SaleFilterSheetState extends State<_SaleFilterSheet> {
  late DateTime? _firstDay = widget.initial.firstDay;
  late DateTime? _lastDay = widget.initial.lastDay;
  late String? _saleTypeId = widget.initial.saleTypeId;
  late String? _categoryId = widget.initial.categoryId;
  late PaymentMethod? _paymentMethod = widget.initial.paymentMethod;
  late bool _pendingOnly = widget.initial.pendingOnly;

  _DateRange get _range {
    if (_firstDay == null) return _DateRange.all;
    final today = dateOnly(DateTime.now());
    if (_lastDay == today) {
      if (_firstDay == today) return _DateRange.today;
      if (_firstDay == startOfWeek(today)) return _DateRange.week;
      if (_firstDay == startOfMonth(today)) return _DateRange.month;
    }
    return _DateRange.custom;
  }

  Future<void> _selectRange(_DateRange range) async {
    final today = dateOnly(DateTime.now());
    switch (range) {
      case _DateRange.all:
        setState(() => _firstDay = _lastDay = null);
      case _DateRange.today:
        setState(() => _firstDay = _lastDay = today);
      case _DateRange.week:
        setState(() {
          _firstDay = startOfWeek(today);
          _lastDay = today;
        });
      case _DateRange.month:
        setState(() {
          _firstDay = startOfMonth(today);
          _lastDay = today;
        });
      case _DateRange.custom:
        final picked = await showDateRangePicker(
          context: context,
          firstDate: DateTime(2020),
          lastDate: today,
        );
        if (picked != null && mounted) {
          setState(() {
            _firstDay = picked.start;
            _lastDay = picked.end;
          });
        }
    }
  }

  @override
  Widget build(BuildContext context) {
    const rangeLabels = {
      _DateRange.all: 'All time',
      _DateRange.today: 'Today',
      _DateRange.week: 'This week',
      _DateRange.month: 'This month',
      _DateRange.custom: 'Pick dates',
    };
    final range = _range;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('Filter sales', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final entry in rangeLabels.entries)
                ChoiceChip(
                  label: Text(
                    entry.key == _DateRange.custom && range == _DateRange.custom
                        ? '${formatDate(_firstDay!)} – ${formatDate(_lastDay!)}'
                        : entry.value,
                  ),
                  selected: range == entry.key,
                  onSelected: (_) => _selectRange(entry.key),
                ),
            ],
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ChoiceChip(
                label: const Text('Any payment'),
                selected: _paymentMethod == null,
                onSelected: (_) => setState(() => _paymentMethod = null),
              ),
              for (final method in PaymentMethod.values)
                ChoiceChip(
                  label: Text(method.label),
                  selected: _paymentMethod == method,
                  onSelected: (_) => setState(() => _paymentMethod = method),
                ),
            ],
          ),
          const SizedBox(height: 16),
          FutureBuilder<List<SaleType>>(
            future: widget.saleTypes,
            builder: (context, snapshot) => _Dropdown(
              label: 'Sale type',
              value: _saleTypeId,
              options: {for (final type in snapshot.data ?? <SaleType>[]) type.id: type.name},
              onChanged: (value) => setState(() => _saleTypeId = value),
            ),
          ),
          const SizedBox(height: 16),
          FutureBuilder<List<Category>>(
            future: widget.categories,
            builder: (context, snapshot) => _Dropdown(
              label: 'Category',
              value: _categoryId,
              options: {
                for (final category in snapshot.data ?? <Category>[]) category.id: category.name,
              },
              onChanged: (value) => setState(() => _categoryId = value),
            ),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Only sales with money pending'),
            value: _pendingOnly,
            onChanged: (value) => setState(() => _pendingOnly = value),
          ),
          const SizedBox(height: 8),
          FilledButton(
            onPressed: () => Navigator.pop(
              context,
              SaleFilters(
                firstDay: _firstDay,
                lastDay: _lastDay,
                saleTypeId: _saleTypeId,
                categoryId: _categoryId,
                paymentMethod: _paymentMethod,
                pendingOnly: _pendingOnly,
              ),
            ),
            child: const Text('Show sales'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, const SaleFilters()),
            child: const Text('Clear filters'),
          ),
        ],
      ),
    );
  }
}

class _Dropdown extends StatelessWidget {
  const _Dropdown({
    required this.label,
    required this.value,
    required this.options,
    required this.onChanged,
  });

  final String label;
  final String? value;
  final Map<String, String> options;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<String?>(
      // Until options load, a selected id has no matching item.
      value: options.containsKey(value) ? value : null,
      decoration: InputDecoration(labelText: label),
      items: [
        const DropdownMenuItem<String?>(child: Text('Any')),
        for (final entry in options.entries)
          DropdownMenuItem<String?>(value: entry.key, child: Text(entry.value)),
      ],
      onChanged: onChanged,
    );
  }
}
