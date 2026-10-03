import 'package:equatable/equatable.dart';

import '../../../core/api/api_client.dart';

class User extends Equatable {
  const User({required this.id, required this.email, required this.fullName});

  factory User.fromJson(Json json) => User(
        id: json['id'] as String,
        email: json['email'] as String,
        fullName: json['full_name'] as String,
      );

  final String id;
  final String email;
  final String fullName;

  @override
  List<Object?> get props => [id, email, fullName];
}
