import 'package:mongo_dart/mongo_dart.dart';

class Comment {
  final String? id;
  final String projectId;
  final String userId;
  final String message;
  final DateTime createdAt;

  Comment({
    this.id,
    required this.projectId,
    required this.userId,
    required this.message,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now().toUtc();

  factory Comment.fromMap(Map<String, dynamic> map) {
    DateTime parseDate(dynamic raw) {
      if (raw is DateTime) return raw.toUtc();
      return DateTime.tryParse(raw?.toString() ?? '')?.toUtc() ??
          DateTime.now().toUtc();
    }

    return Comment(
      id: map['_id'] is ObjectId
          ? (map['_id'] as ObjectId).oid
          : map['_id']?.toString(),
      projectId: map['projectId'] as String? ?? '',
      userId: map['userId'] as String? ?? '',
      message: map['message'] as String? ?? '',
      createdAt: parseDate(map['createdAt']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'projectId': projectId,
      'userId': userId,
      'message': message,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'projectId': projectId,
      'userId': userId,
      'message': message,
      'createdAt': createdAt.toIso8601String(),
    };
  }
}
