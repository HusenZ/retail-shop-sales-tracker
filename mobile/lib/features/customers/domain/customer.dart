import 'package:decimal/decimal.dart';
import 'package:equatable/equatable.dart';

import '../../../core/api/api_client.dart';
import '../../../core/format/money.dart';

class Customer extends Equatable {
  const Customer({
    required this.id,
    required this.name,
    required this.totalPurchases,
    required this.transactionCount,
    required this.pendingAmount,
    this.phone,
    this.notes,
  });

  factory Customer.fromJson(Json json) => Customer(
        id: json['id'] as String,
        name: json['name'] as String,
        phone: json['phone'] as String?,
        notes: json['notes'] as String?,
        totalPurchases: parseMoney(json['total_purchases']),
        transactionCount: json['transaction_count'] as int,
        pendingAmount: parseMoney(json['pending_amount']),
      );

  final String id;
  final String name;
  final String? phone;
  final String? notes;
  final Decimal totalPurchases;
  final int transactionCount;
  final Decimal pendingAmount;

  bool get owesMoney => pendingAmount > Decimal.zero;

  @override
  List<Object?> get props =>
      [id, name, phone, notes, totalPurchases, transactionCount, pendingAmount];
}

class CustomerInput {
  const CustomerInput({required this.name, this.phone, this.notes});

  final String name;
  final String? phone;
  final String? notes;

  Json toJson() => {'name': name, 'phone': phone, 'notes': notes};
}
