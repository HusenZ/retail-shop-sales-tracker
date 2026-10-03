import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/api/api_exception.dart';
import '../../../core/format/dates.dart';
import '../../../core/format/money.dart';
import '../../../core/load_status.dart';
import '../../../core/widgets/async_views.dart';
import '../../../core/widgets/inputs.dart';
import '../../../core/widgets/stat_tile.dart';
import '../data/expense_repository.dart';
import '../domain/expense.dart';

class ExpensesState extends Equatable {
  const ExpensesState({
    required this.month,
    this.status = LoadStatus.initial,
    this.expenses,
    this.errorMessage,
  });

  /// First day of the month being shown.
  final DateTime month;
  final LoadStatus status;
  final ExpenseList? expenses;
  final String? errorMessage;

  @override
  List<Object?> get props => [month, status, expenses, errorMessage];
}

class ExpensesCubit extends Cubit<ExpensesState> {
  ExpensesCubit(this._expenses, {DateTime Function()? now})
      : _now = now ?? DateTime.now,
        super(ExpensesState(month: startOfMonth((now ?? DateTime.now)())));

  final ExpenseRepository _expenses;
  final DateTime Function() _now;

  DateTime get thisMonth => startOfMonth(_now());

  DateTime get lastMonth => DateTime(thisMonth.year, thisMonth.month - 1);

  Future<void> load() async {
    emit(ExpensesState(month: state.month, status: LoadStatus.loading, expenses: state.expenses));
    try {
      final nextMonth = DateTime(state.month.year, state.month.month + 1);
      final expenses = await _expenses.list(
        firstDay: state.month,
        lastDay: nextMonth.subtract(const Duration(days: 1)),
      );
      emit(ExpensesState(month: state.month, status: LoadStatus.success, expenses: expenses));
    } on ApiException catch (error) {
      emit(
        ExpensesState(
          month: state.month,
          status: state.expenses == null ? LoadStatus.failure : LoadStatus.success,
          expenses: state.expenses,
          errorMessage: error.message,
        ),
      );
    }
  }

  Future<void> showMonth(DateTime month) {
    emit(ExpensesState(month: month));
    return load();
  }

  Future<void> add(ExpenseInput input) => _change(() => _expenses.create(input));

  Future<void> delete(Expense expense) => _change(() => _expenses.delete(expense.id));

  Future<void> _change(Future<void> Function() change) async {
    try {
      await change();
      await load();
    } on ApiException catch (error) {
      emit(
        ExpensesState(
          month: state.month,
          status: state.status,
          expenses: state.expenses,
          errorMessage: error.message,
        ),
      );
    }
  }
}

class ExpensesPage extends StatelessWidget {
  const ExpensesPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => ExpensesCubit(context.read<ExpenseRepository>())..load(),
      child: BlocConsumer<ExpensesCubit, ExpensesState>(
        listenWhen: (_, current) => current.errorMessage != null,
        listener: (context, state) => showMessage(context, state.errorMessage!),
        builder: (context, state) {
          final cubit = context.read<ExpensesCubit>();
          final expenses = state.expenses;
          return Scaffold(
            appBar: AppBar(title: const Text('Expenses')),
            floatingActionButton: FloatingActionButton.extended(
              icon: const Icon(Icons.add),
              label: const Text('Add expense'),
              onPressed: () async {
                final input = await _askExpense(context);
                if (input != null) await cubit.add(input);
              },
            ),
            body: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                  child: Row(
                    children: [
                      ChoiceChip(
                        label: const Text('This month'),
                        selected: state.month == cubit.thisMonth,
                        onSelected: (_) => cubit.showMonth(cubit.thisMonth),
                      ),
                      const SizedBox(width: 8),
                      ChoiceChip(
                        label: const Text('Last month'),
                        selected: state.month == cubit.lastMonth,
                        onSelected: (_) => cubit.showMonth(cubit.lastMonth),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: switch (state.status) {
                    LoadStatus.failure => ErrorView(
                        message: state.errorMessage ?? 'Could not load',
                        onRetry: cubit.load,
                      ),
                    _ when expenses == null => const LoadingView(),
                    _ => _ExpenseList(expenses: expenses!),
                  },
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _ExpenseList extends StatelessWidget {
  const _ExpenseList({required this.expenses});

  final ExpenseList expenses;

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<ExpensesCubit>();
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 88),
      children: [
        StatTile(label: 'Total', value: formatRupees(expenses.total), large: true),
        const SizedBox(height: 8),
        if (expenses.expenses.isEmpty)
          const Padding(
            padding: EdgeInsets.only(top: 24),
            child: Text('No expenses recorded.', textAlign: TextAlign.center),
          ),
        for (final expense in expenses.expenses)
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(expense.name),
            subtitle: Text(
              [formatDate(expense.spentOn), if (expense.note != null) expense.note!].join(' · '),
            ),
            trailing: Text(
              formatRupees(expense.amount),
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            onLongPress: () async {
              final remove = await confirm(
                context,
                title: 'Delete "${expense.name}"?',
                action: 'Delete',
              );
              if (remove) await cubit.delete(expense);
            },
          ),
        if (expenses.expenses.isNotEmpty)
          const Padding(
            padding: EdgeInsets.only(top: 8),
            child: Text('Long-press an expense to delete it.'),
          ),
      ],
    );
  }
}

Future<ExpenseInput?> _askExpense(BuildContext context) {
  return showModalBottomSheet<ExpenseInput>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => const _ExpenseForm(),
  );
}

class _ExpenseForm extends StatefulWidget {
  const _ExpenseForm();

  @override
  State<_ExpenseForm> createState() => _ExpenseFormState();
}

class _ExpenseFormState extends State<_ExpenseForm> {
  static const _commonNames = ['Rent', 'Electricity', 'Salary', 'Transport', 'Other'];

  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _amount = TextEditingController();
  final _note = TextEditingController();
  DateTime _spentOn = dateOnly(DateTime.now());

  @override
  void dispose() {
    _name.dispose();
    _amount.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _spentOn,
      firstDate: DateTime(2020),
      lastDate: dateOnly(DateTime.now()),
    );
    if (picked != null && mounted) setState(() => _spentOn = picked);
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    Navigator.pop(
      context,
      ExpenseInput(
        name: _name.text.trim(),
        amount: parseMoneyInput(_amount.text)!,
        spentOn: _spentOn,
        note: cleanOptional(_note.text),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + MediaQuery.of(context).viewInsets.bottom),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('New expense', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              children: [
                for (final name in _commonNames)
                  ActionChip(label: Text(name), onPressed: () => _name.text = name),
              ],
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _name,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(labelText: 'What for?'),
              validator: requiredText,
            ),
            const SizedBox(height: 12),
            MoneyField(label: 'Amount', controller: _amount, isRequired: true, allowZero: false),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              icon: const Icon(Icons.calendar_today),
              label: Text(formatDate(_spentOn)),
              onPressed: _pickDate,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _note,
              decoration: const InputDecoration(labelText: 'Note (optional)'),
            ),
            const SizedBox(height: 16),
            FilledButton(onPressed: _save, child: const Text('Save expense')),
          ],
        ),
      ),
    );
  }
}
