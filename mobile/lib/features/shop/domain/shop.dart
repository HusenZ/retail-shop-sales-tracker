import 'package:equatable/equatable.dart';

import '../../../core/api/api_client.dart';

class Shop extends Equatable {
  const Shop({
    required this.id,
    required this.name,
    required this.ownerName,
    required this.phone,
    this.address,
  });

  factory Shop.fromJson(Json json) => Shop(
        id: json['id'] as String,
        name: json['name'] as String,
        ownerName: json['owner_name'] as String,
        phone: json['phone'] as String,
        address: json['address'] as String?,
      );

  final String id;
  final String name;
  final String ownerName;
  final String phone;
  final String? address;

  @override
  List<Object?> get props => [id, name, ownerName, phone, address];
}

class ShopInput {
  const ShopInput({required this.name, required this.ownerName, required this.phone, this.address});

  final String name;
  final String ownerName;
  final String phone;
  final String? address;

  Json toJson() => {
        'name': name,
        'owner_name': ownerName,
        'phone': phone,
        'address': address,
      };
}
