import 'package:equatable/equatable.dart';

import '../../../core/api/api_client.dart';

class SaleType extends Equatable {
  const SaleType({
    required this.id,
    required this.name,
    required this.isActive,
    required this.isDefault,
    required this.isExchange,
  });

  factory SaleType.fromJson(Json json) => SaleType(
        id: json['id'] as String,
        name: json['name'] as String,
        isActive: json['is_active'] as bool,
        isDefault: json['is_default'] as bool,
        isExchange: json['is_exchange'] as bool,
      );

  final String id;
  final String name;
  final bool isActive;
  final bool isDefault;

  /// Exchange sale types ask for the customer's old phone.
  final bool isExchange;

  @override
  List<Object?> get props => [id, name, isActive, isDefault, isExchange];
}
