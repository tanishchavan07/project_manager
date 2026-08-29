import 'package:mongo_dart/mongo_dart.dart';

class Task {
  final String? id;
  final String projectId;
  final String title;
  final String description;
  final String status;
  final String priority;
  final DateTime? dueDate;
  final String? assignedTo;
  final DateTime createdAt;
  final DateTime updatedAt;

  static const List<String> validStatuses = [
    'todo',
    'in_progress',
    'in_review',
    'done',
    'cancelled',
  ];

  static const List<String> validPriorities = [
    'low',
    'medium',
    'high',
    'critical',
  ];

  Task({
    this.id,
    required this.projectId,
    required this.title,
    this.description = '',
    this.status = 'todo',
    this.priority = 'medium',
    this.dueDate,
    this.assignedTo,
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : createdAt = createdAt ?? DateTime.now().toUtc(),
        updatedAt = updatedAt ?? DateTime.now().toUtc();

  factory Task.fromMap(Map<String, dynamic> map) {
    DateTime? parseDate(dynamic raw) {
      if (raw == null) return null;
      if (raw is DateTime) return raw.toUtc();
      return DateTime.tryParse(raw.toString())?.toUtc();
    }

    return Task(
      id: map['_id'] is ObjectId
          ? (map['_id'] as ObjectId).oid
          : map['_id']?.toString(),
      projectId: map['projectId'] as String? ?? '',
      title: map['title'] as String? ?? '',
      description: map['description'] as String? ?? '',
      status: map['status'] as String? ?? 'todo',
      priority: map['priority'] as String? ?? 'medium',
      dueDate: parseDate(map['dueDate']),
      assignedTo: map['assignedTo'] as String?,
      createdAt: parseDate(map['createdAt']) ?? DateTime.now().toUtc(),
      updatedAt: parseDate(map['updatedAt']) ?? DateTime.now().toUtc(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'projectId': projectId,
      'title': title,
      'description': description,
      'status': status,
      'priority': priority,
      'dueDate': dueDate?.toIso8601String(),
      'assignedTo': assignedTo,
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
      'status': status,
      'priority': priority,
      'dueDate': dueDate?.toIso8601String(),
      'assignedTo': assignedTo,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  Task copyWith({
    String? projectId,
    String? title,
    String? description,
    String? status,
    String? priority,
    DateTime? dueDate,
    String? assignedTo,
  }) {
    return Task(
      id: id,
      projectId: projectId ?? this.projectId,
      title: title ?? this.title,
      description: description ?? this.description,
      status: status ?? this.status,
      priority: priority ?? this.priority,
      dueDate: dueDate ?? this.dueDate,
      assignedTo: assignedTo ?? this.assignedTo,
      createdAt: createdAt,
      updatedAt: DateTime.now().toUtc(),
    );
  }
}
