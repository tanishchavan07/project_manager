import 'package:mongo_dart/mongo_dart.dart' hide Project;

import '../config/database.dart';
import '../models/project.dart';

/// Validates whether [id] is a valid MongoDB ObjectId hex string.
bool _isValidObjectId(String id) {
  try {
    ObjectId.fromHexString(id);
    return true;
  } catch (_) {
    return false;
  }
}

/// Handles complete Project CRUD operations.
class ProjectService {
  // ---------------------------------------------------------------------------
  // Create  POST /api/projects
  // ---------------------------------------------------------------------------

  static Future<Map<String, dynamic>> createProject(
      Map<String, dynamic> body, String requestingUserId) async {
    final name = body['name']?.toString().trim();
    // ownerId is always the authenticated user — never trust the body for this.
    final ownerId = requestingUserId;
    final status = body['status']?.toString().trim() ?? 'planning';
    final priority = body['priority']?.toString().trim() ?? 'medium';

    if (name == null || name.isEmpty) {
      return _error(400, 'Project name is required.');
    }
    if (!Project.validStatuses.contains(status)) {
      return _error(400,
          'Invalid status. Valid values: ${Project.validStatuses.join(', ')}');
    }
    if (!Project.validPriorities.contains(priority)) {
      return _error(400,
          'Invalid priority. Valid values: ${Project.validPriorities.join(', ')}');
    }

    // Validate dates if provided
    DateTime? startDate = _parseDate(body['startDate']);
    DateTime? endDate = _parseDate(body['endDate']);
    if (startDate != null && endDate != null && endDate.isBefore(startDate)) {
      return _error(400, 'End date cannot be before start date.');
    }

    final project = Project(
      name: name,
      description: body['description']?.toString() ?? '',
      category: body['category']?.toString() ?? '',
      status: status,
      priority: priority,
      startDate: startDate,
      endDate: endDate,
      ownerId: ownerId,
      collaboratorIds: _parseStringList(body['collaboratorIds']),
    );

    final result = await Database.projects.insertOne(project.toMap());
    final insertedOid = result.id as ObjectId;
    final insertedId = insertedOid.oid;

    final created = Project.fromMap({...project.toMap(), '_id': result.id});

    return {
      'statusCode': 201,
      'body': {
        'success': true,
        'message': 'Project created successfully.',
        'data': {...created.toJson(), 'id': insertedId},
      },
    };
  }

  // ---------------------------------------------------------------------------
  // Get all  GET /api/projects
  // Returns ONLY projects owned by the authenticated user.
  // ---------------------------------------------------------------------------

  static Future<Map<String, dynamic>> getAllProjects(
      String requestingUserId) async {
    final docs = await Database.projects
        .find(where
            .eq('ownerId', requestingUserId)
            .or(where.eq('collaboratorIds', requestingUserId)))
        .toList();
    final projects = docs.map((d) => Project.fromMap(d).toJson()).toList();
    return {
      'statusCode': 200,
      'body': {
        'success': true,
        'message': 'Projects retrieved successfully.',
        'data': projects,
      },
    };
  }

  // ---------------------------------------------------------------------------
  // Get one  GET /api/projects/:id
  // Accessible by owner OR collaborator.
  // ---------------------------------------------------------------------------

  static Future<Map<String, dynamic>> getProjectById(
      String id, String requestingUserId) async {
    if (!_isValidObjectId(id)) {
      return _error(400, 'Invalid project ID format.');
    }

    final doc =
        await Database.projects.findOne(where.id(ObjectId.fromHexString(id)));
    if (doc == null) {
      return _error(404, 'Project not found.');
    }

    if (!_canAccess(doc, requestingUserId)) {
      return _forbidden();
    }

    return {
      'statusCode': 200,
      'body': {
        'success': true,
        'message': 'Project retrieved successfully.',
        'data': Project.fromMap(doc).toJson(),
      },
    };
  }

  // ---------------------------------------------------------------------------
  // Update  PUT /api/projects/:id
  // Owner only.
  // ---------------------------------------------------------------------------

  static Future<Map<String, dynamic>> updateProject(
      String id, Map<String, dynamic> body, String requestingUserId) async {
    if (!_isValidObjectId(id)) {
      return _error(400, 'Invalid project ID format.');
    }

    final existing = await Database.projects
        .findOne(where.id(ObjectId.fromHexString(id)));
    if (existing == null) {
      return _error(404, 'Project not found.');
    }

    if (!_isOwner(existing, requestingUserId)) {
      return _forbidden();
    }

    final updates = <String, dynamic>{};

    if (body.containsKey('name')) {
      final name = body['name']?.toString().trim() ?? '';
      if (name.isEmpty) return _error(400, 'Project name cannot be empty.');
      updates['name'] = name;
    }
    if (body.containsKey('description')) {
      updates['description'] = body['description']?.toString() ?? '';
    }
    if (body.containsKey('category')) {
      updates['category'] = body['category']?.toString() ?? '';
    }
    if (body.containsKey('status')) {
      final s = body['status'].toString();
      if (!Project.validStatuses.contains(s)) {
        return _error(400,
            'Invalid status. Valid values: ${Project.validStatuses.join(', ')}');
      }
      updates['status'] = s;
    }
    if (body.containsKey('priority')) {
      final p = body['priority'].toString();
      if (!Project.validPriorities.contains(p)) {
        return _error(400,
            'Invalid priority. Valid values: ${Project.validPriorities.join(', ')}');
      }
      updates['priority'] = p;
    }
    if (body.containsKey('startDate')) {
      updates['startDate'] = _parseDate(body['startDate'])?.toIso8601String();
    }
    if (body.containsKey('endDate')) {
      updates['endDate'] = _parseDate(body['endDate'])?.toIso8601String();
    }
    if (body.containsKey('collaboratorIds')) {
      updates['collaboratorIds'] = _parseStringList(body['collaboratorIds']);
    }

    updates['updatedAt'] = DateTime.now().toUtc().toIso8601String();

    await Database.projects.updateOne(
      where.id(ObjectId.fromHexString(id)),
      {'\$set': updates},
    );

    final updated = await Database.projects
        .findOne(where.id(ObjectId.fromHexString(id)));

    return {
      'statusCode': 200,
      'body': {
        'success': true,
        'message': 'Project updated successfully.',
        'data': Project.fromMap(updated!).toJson(),
      },
    };
  }

  // ---------------------------------------------------------------------------
  // Delete  DELETE /api/projects/:id
  // Owner only.
  // ---------------------------------------------------------------------------

  static Future<Map<String, dynamic>> deleteProject(
      String id, String requestingUserId) async {
    if (!_isValidObjectId(id)) {
      return _error(400, 'Invalid project ID format.');
    }

    final existing = await Database.projects
        .findOne(where.id(ObjectId.fromHexString(id)));
    if (existing == null) {
      return _error(404, 'Project not found.');
    }

    if (!_isOwner(existing, requestingUserId)) {
      return _forbidden();
    }

    await Database.projects
        .deleteOne(where.id(ObjectId.fromHexString(id)));

    // Cascade: remove related tasks, milestones, comments
    await Database.tasks.deleteMany(where.eq('projectId', id));
    await Database.milestones.deleteMany(where.eq('projectId', id));
    await Database.comments.deleteMany(where.eq('projectId', id));

    return {
      'statusCode': 200,
      'body': {
        'success': true,
        'message': 'Project deleted successfully.',
      },
    };
  }

  // ---------------------------------------------------------------------------
  // Internal helpers
  // ---------------------------------------------------------------------------

  /// Returns true if [requestingUserId] is the project owner.
  static bool _isOwner(Map<String, dynamic> projectDoc, String requestingUserId) {
    return projectDoc['ownerId']?.toString() == requestingUserId;
  }

  /// Returns true if [requestingUserId] is the owner OR an explicit collaborator.
  static bool _canAccess(Map<String, dynamic> projectDoc, String requestingUserId) {
    if (_isOwner(projectDoc, requestingUserId)) return true;
    final collaboratorIds =
        List<String>.from(projectDoc['collaboratorIds'] as List? ?? []);
    return collaboratorIds.contains(requestingUserId);
  }

  static Map<String, dynamic> _forbidden() => {
        'statusCode': 403,
        'body': {
          'success': false,
          'message': 'You are not authorized to access this project.',
        },
      };

  static DateTime? _parseDate(dynamic raw) {
    if (raw == null) return null;
    if (raw is DateTime) return raw.toUtc();
    return DateTime.tryParse(raw.toString())?.toUtc();
  }

  static List<String> _parseStringList(dynamic raw) {
    if (raw == null) return [];
    if (raw is List) return raw.map((e) => e.toString()).toList();
    return [];
  }

  static Map<String, dynamic> _error(int statusCode, String message) {
    return {
      'statusCode': statusCode,
      'body': {'success': false, 'message': message},
    };
  }
}
