import 'package:decimal/decimal.dart';
import 'package:equatable/equatable.dart';

import '../../../core/api/api_client.dart';
import '../../../core/format/dates.dart';
import '../../../core/format/money.dart';

class Expense extends Equatable {
  const Expense({
    required this.id,
    required this.name,
    required this.amount,
    required this.spentOn,
    this.note,
  });

  factory Expense.fromJson(Json json) => Expense(
        id: json['id'] as String,
        name: json['name'] as String,
        amount: parseMoney(json['amount']),
        spentOn: DateTime.parse(json['spent_on'] as String),
        note: json['note'] as String?,
      );

  final String id;
  final String name;
  final Decimal amount;
  final DateTime spentOn;
  final String? note;

  @override
  List<Object?> get props => [id, name, amount, spentOn, note];
}

class ExpenseInput {
  const ExpenseInput({required this.name, required this.amount, required this.spentOn, this.note});

  final String name;
  final Decimal amount;
  final DateTime spentOn;
  final String? note;

  Json toJson() => {
        'name': name,
        'amount': amount.toString(),
        'spent_on': apiDate(spentOn),
        'note': note,
      };
}

class ExpenseList extends Equatable {
  const ExpenseList({required this.total, required this.expenses});

  factory ExpenseList.fromJson(Json json) => ExpenseList(
        total: parseMoney(json['total']),
        expenses: (json['expenses'] as List<dynamic>).cast<Json>().map(Expense.fromJson).toList(),
      );

  final Decimal total;
  final List<Expense> expenses;

  @override
  List<Object?> get props => [total, expenses];
}
