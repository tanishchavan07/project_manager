import 'package:mongo_dart/mongo_dart.dart';

class User {
  final String? id;
  final String name;
  final String email;
  final String password;
  final DateTime createdAt;

  User({
    this.id,
    required this.name,
    required this.email,
    required this.password,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now().toUtc();

  factory User.fromMap(Map<String, dynamic> map) {
    return User(
      id: map['_id'] is ObjectId
          ? (map['_id'] as ObjectId).oid
          : map['_id']?.toString(),
      name: map['name'] as String? ?? '',
      email: map['email'] as String? ?? '',
      password: map['password'] as String? ?? '',
      createdAt: map['createdAt'] is DateTime
          ? (map['createdAt'] as DateTime).toUtc()
          : DateTime.tryParse(map['createdAt']?.toString() ?? '')?.toUtc() ??
              DateTime.now().toUtc(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'email': email,
      'password': password,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  /// Serializes to JSON for API responses — password is intentionally excluded.
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'createdAt': createdAt.toIso8601String(),
    };
  }
}
