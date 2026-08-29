import 'package:mongo_dart/mongo_dart.dart';

class Project {
  final String? id;
  final String name;
  final String description;
  final String category;
  final String status;
  final String priority;
  final DateTime? startDate;
  final DateTime? endDate;
  final String ownerId;
  final List<String> collaboratorIds;
  final DateTime createdAt;
  final DateTime updatedAt;

  static const List<String> validStatuses = [
    'planning',
    'active',
    'on_hold',
    'completed',
    'cancelled',
  ];

  static const List<String> validPriorities = [
    'low',
    'medium',
    'high',
    'critical',
  ];

  Project({
    this.id,
    required this.name,
    this.description = '',
    this.category = '',
    this.status = 'planning',
    this.priority = 'medium',
    this.startDate,
    this.endDate,
    required this.ownerId,
    List<String>? collaboratorIds,
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : collaboratorIds = collaboratorIds ?? [],
        createdAt = createdAt ?? DateTime.now().toUtc(),
        updatedAt = updatedAt ?? DateTime.now().toUtc();

  factory Project.fromMap(Map<String, dynamic> map) {
    List<String> parseCollaborators(dynamic raw) {
      if (raw == null) return [];
      if (raw is List) return raw.map((e) => e.toString()).toList();
      return [];
    }

    DateTime? parseDate(dynamic raw) {
      if (raw == null) return null;
      if (raw is DateTime) return raw.toUtc();
      return DateTime.tryParse(raw.toString())?.toUtc();
    }

    return Project(
      id: map['_id'] is ObjectId
          ? (map['_id'] as ObjectId).oid
          : map['_id']?.toString(),
      name: map['name'] as String? ?? '',
      description: map['description'] as String? ?? '',
      category: map['category'] as String? ?? '',
      status: map['status'] as String? ?? 'planning',
      priority: map['priority'] as String? ?? 'medium',
      startDate: parseDate(map['startDate']),
      endDate: parseDate(map['endDate']),
      ownerId: map['ownerId'] as String? ?? '',
      collaboratorIds: parseCollaborators(map['collaboratorIds']),
      createdAt: parseDate(map['createdAt']) ?? DateTime.now().toUtc(),
      updatedAt: parseDate(map['updatedAt']) ?? DateTime.now().toUtc(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'description': description,
      'category': category,
      'status': status,
      'priority': priority,
      'startDate': startDate?.toIso8601String(),
      'endDate': endDate?.toIso8601String(),
      'ownerId': ownerId,
      'collaboratorIds': collaboratorIds,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'category': category,
      'status': status,
      'priority': priority,
      'startDate': startDate?.toIso8601String(),
      'endDate': endDate?.toIso8601String(),
      'ownerId': ownerId,
      'collaboratorIds': collaboratorIds,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  Project copyWith({
    String? name,
    String? description,
    String? category,
    String? status,
    String? priority,
    DateTime? startDate,
    DateTime? endDate,
    String? ownerId,
    List<String>? collaboratorIds,
  }) {
    return Project(
      id: id,
      name: name ?? this.name,
      description: description ?? this.description,
      category: category ?? this.category,
      status: status ?? this.status,
      priority: priority ?? this.priority,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      ownerId: ownerId ?? this.ownerId,
      collaboratorIds: collaboratorIds ?? this.collaboratorIds,
      createdAt: createdAt,
      updatedAt: DateTime.now().toUtc(),
    );
  }
}
