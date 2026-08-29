import 'package:mongo_dart/mongo_dart.dart';

class Milestone {
  final String? id;
  final String projectId;
  final String title;
  final String description;
  final DateTime? dueDate;
  final String status;
  final DateTime createdAt;
  final DateTime updatedAt;

  static const List<String> validStatuses = [
    'pending',
    'in_progress',
    'completed',
    'missed',
  ];

  Milestone({
    this.id,
    required this.projectId,
    required this.title,
    this.description = '',
    this.dueDate,
    this.status = 'pending',
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : createdAt = createdAt ?? DateTime.now().toUtc(),
        updatedAt = updatedAt ?? DateTime.now().toUtc();

  factory Milestone.fromMap(Map<String, dynamic> map) {
    DateTime? parseDate(dynamic raw) {
      if (raw == null) return null;
      if (raw is DateTime) return raw.toUtc();
      return DateTime.tryParse(raw.toString())?.toUtc();
    }

    return Milestone(
      id: map['_id'] is ObjectId
          ? (map['_id'] as ObjectId).oid
          : map['_id']?.toString(),
      projectId: map['projectId'] as String? ?? '',
      title: map['title'] as String? ?? '',
      description: map['description'] as String? ?? '',
      dueDate: parseDate(map['dueDate']),
      status: map['status'] as String? ?? 'pending',
      createdAt: parseDate(map['createdAt']) ?? DateTime.now().toUtc(),
      updatedAt: parseDate(map['updatedAt']) ?? DateTime.now().toUtc(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'projectId': projectId,
      'title': title,
      'description': description,
      'dueDate': dueDate?.toIso8601String(),
      'status': status,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'projectId': projectId,
      'title': title,
      'description': description,
      'dueDate': dueDate?.toIso8601String(),
      'status': status,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  Milestone copyWith({
    String? title,
    String? description,
    DateTime? dueDate,
    String? status,
  }) {
    return Milestone(
      id: id,
      projectId: projectId,
      title: title ?? this.title,
      description: description ?? this.description,
      dueDate: dueDate ?? this.dueDate,
      status: status ?? this.status,
      createdAt: createdAt,
      updatedAt: DateTime.now().toUtc(),
    );
  }
}
