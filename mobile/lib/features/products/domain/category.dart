import 'package:equatable/equatable.dart';

import '../../../core/api/api_client.dart';

class Category extends Equatable {
  const Category({required this.id, required this.name, required this.isActive});

  factory Category.fromJson(Json json) => Category(
        id: json['id'] as String,
        name: json['name'] as String,
        isActive: json['is_active'] as bool,
      );

  final String id;
  final String name;
  final bool isActive;

  @override
  List<Object?> get props => [id, name, isActive];
}
