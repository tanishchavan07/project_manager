import 'package:mongo_dart/mongo_dart.dart';

import '../config/database.dart';
import '../models/task.dart';

/// Validates whether [id] is a valid MongoDB ObjectId hex string.
bool _isValidObjectId(String id) {
  try {
    ObjectId.fromHexString(id);
    return true;
  } catch (_) {
    return false;
  }
}

/// Returns true if [userId] is the owner OR a collaborator of the project doc.
bool _canAccessProject(Map<String, dynamic> projectDoc, String userId) {
  if (projectDoc['ownerId']?.toString() == userId) return true;
  final collaboratorIds =
      List<String>.from(projectDoc['collaboratorIds'] as List? ?? []);
  return collaboratorIds.contains(userId);
}

Map<String, dynamic> _forbidden() => {
      'statusCode': 403,
      'body': {
        'success': false,
        'message': 'You are not authorized to access this project.',
      },
    };

/// Handles complete Task CRUD operations.
class TaskService {
  // ---------------------------------------------------------------------------
  // Create  POST /api/tasks
  // Owner or collaborator may create tasks.
  // ---------------------------------------------------------------------------

  static Future<Map<String, dynamic>> createTask(
      Map<String, dynamic> body, String requestingUserId) async {
    final projectId = body['projectId']?.toString().trim();
    final title = body['title']?.toString().trim();
    final status = body['status']?.toString().trim() ?? 'todo';
    final priority = body['priority']?.toString().trim() ?? 'medium';

    if (projectId == null || projectId.isEmpty) {
      return _error(400, 'Project ID is required.');
    }
    if (!_isValidObjectId(projectId)) {
      return _error(400, 'Invalid project ID format.');
    }
    if (title == null || title.isEmpty) {
      return _error(400, 'Task title is required.');
    }
    if (!Task.validStatuses.contains(status)) {
      return _error(
          400, 'Invalid status. Valid values: ${Task.validStatuses.join(', ')}');
    }
    if (!Task.validPriorities.contains(priority)) {
      return _error(400,
          'Invalid priority. Valid values: ${Task.validPriorities.join(', ')}');
    }

    // Verify the project exists and the user can access it
    final project = await Database.projects
        .findOne(where.id(ObjectId.fromHexString(projectId)));
    if (project == null) {
      return _error(404, 'Project not found.');
    }
    if (!_canAccessProject(project, requestingUserId)) {
      return _forbidden();
    }

    final task = Task(
      projectId: projectId,
      title: title,
      description: body['description']?.toString() ?? '',
      status: status,
      priority: priority,
      dueDate: _parseDate(body['dueDate']),
      assignedTo: body['assignedTo']?.toString(),
    );

    final result = await Database.tasks.insertOne(task.toMap());
    final insertedOid = result.id as ObjectId;
    final insertedId = insertedOid.oid;

    final created = Task.fromMap({...task.toMap(), '_id': result.id});

    return {
      'statusCode': 201,
      'body': {
        'success': true,
        'message': 'Task created successfully.',
        'data': {...created.toJson(), 'id': insertedId},
      },
    };
  }

  // ---------------------------------------------------------------------------
  // Get tasks by project  GET /api/tasks/project/:projectId
  // Owner or collaborator may list tasks.
  // ---------------------------------------------------------------------------

  static Future<Map<String, dynamic>> getTasksByProject(
      String projectId, String requestingUserId) async {
    if (!_isValidObjectId(projectId)) {
      return _error(400, 'Invalid project ID format.');
    }

    final project = await Database.projects
        .findOne(where.id(ObjectId.fromHexString(projectId)));
    if (project == null) {
      return _error(404, 'Project not found.');
    }
    if (!_canAccessProject(project, requestingUserId)) {
      return _forbidden();
    }

    final docs =
        await Database.tasks.find(where.eq('projectId', projectId)).toList();
    final tasks = docs.map((d) => Task.fromMap(d).toJson()).toList();

    return {
      'statusCode': 200,
      'body': {
        'success': true,
        'message': 'Tasks retrieved successfully.',
        'data': tasks,
      },
    };
  }

  // ---------------------------------------------------------------------------
  // Get one  GET /api/tasks/:id
  // Owner or collaborator of the parent project.
  // ---------------------------------------------------------------------------

  static Future<Map<String, dynamic>> getTaskById(
      String id, String requestingUserId) async {
    if (!_isValidObjectId(id)) {
      return _error(400, 'Invalid task ID format.');
    }

    final doc =
        await Database.tasks.findOne(where.id(ObjectId.fromHexString(id)));
    if (doc == null) {
      return _error(404, 'Task not found.');
    }

    final projectId = doc['projectId']?.toString() ?? '';
    if (_isValidObjectId(projectId)) {
      final project = await Database.projects
          .findOne(where.id(ObjectId.fromHexString(projectId)));
      if (project != null && !_canAccessProject(project, requestingUserId)) {
        return _forbidden();
      }
    }

    return {
      'statusCode': 200,
      'body': {
        'success': true,
        'message': 'Task retrieved successfully.',
        'data': Task.fromMap(doc).toJson(),
      },
    };
  }

  // ---------------------------------------------------------------------------
  // Update  PUT /api/tasks/:id
  // Owner or collaborator of the parent project.
  // ---------------------------------------------------------------------------

  static Future<Map<String, dynamic>> updateTask(
      String id, Map<String, dynamic> body, String requestingUserId) async {
    if (!_isValidObjectId(id)) {
      return _error(400, 'Invalid task ID format.');
    }

    final existing =
        await Database.tasks.findOne(where.id(ObjectId.fromHexString(id)));
    if (existing == null) {
      return _error(404, 'Task not found.');
    }

    final projectId = existing['projectId']?.toString() ?? '';
    if (_isValidObjectId(projectId)) {
      final project = await Database.projects
          .findOne(where.id(ObjectId.fromHexString(projectId)));
      if (project != null && !_canAccessProject(project, requestingUserId)) {
        return _forbidden();
      }
    }

    final updates = <String, dynamic>{};

    if (body.containsKey('title')) {
      final t = body['title']?.toString().trim() ?? '';
      if (t.isEmpty) return _error(400, 'Task title cannot be empty.');
      updates['title'] = t;
    }
    if (body.containsKey('description')) {
      updates['description'] = body['description']?.toString() ?? '';
    }
    if (body.containsKey('status')) {
      final s = body['status'].toString();
      if (!Task.validStatuses.contains(s)) {
        return _error(400,
            'Invalid status. Valid values: ${Task.validStatuses.join(', ')}');
      }
      updates['status'] = s;
    }
    if (body.containsKey('priority')) {
      final p = body['priority'].toString();
      if (!Task.validPriorities.contains(p)) {
        return _error(400,
            'Invalid priority. Valid values: ${Task.validPriorities.join(', ')}');
      }
      updates['priority'] = p;
    }
    if (body.containsKey('dueDate')) {
      updates['dueDate'] = _parseDate(body['dueDate'])?.toIso8601String();
    }
    if (body.containsKey('assignedTo')) {
      updates['assignedTo'] = body['assignedTo']?.toString();
    }

    updates['updatedAt'] = DateTime.now().toUtc().toIso8601String();

    await Database.tasks.updateOne(
      where.id(ObjectId.fromHexString(id)),
      {'\$set': updates},
    );

    final updated =
        await Database.tasks.findOne(where.id(ObjectId.fromHexString(id)));

    return {
      'statusCode': 200,
      'body': {
        'success': true,
        'message': 'Task updated successfully.',
        'data': Task.fromMap(updated!).toJson(),
      },
    };
  }

  // ---------------------------------------------------------------------------
  // Delete  DELETE /api/tasks/:id
  // Owner or collaborator of the parent project.
  // ---------------------------------------------------------------------------

  static Future<Map<String, dynamic>> deleteTask(
      String id, String requestingUserId) async {
    if (!_isValidObjectId(id)) {
      return _error(400, 'Invalid task ID format.');
    }

    final existing =
        await Database.tasks.findOne(where.id(ObjectId.fromHexString(id)));
    if (existing == null) {
      return _error(404, 'Task not found.');
    }

    final projectId = existing['projectId']?.toString() ?? '';
    if (_isValidObjectId(projectId)) {
      final project = await Database.projects
          .findOne(where.id(ObjectId.fromHexString(projectId)));
      if (project != null && !_canAccessProject(project, requestingUserId)) {
        return _forbidden();
      }
    }

    await Database.tasks.deleteOne(where.id(ObjectId.fromHexString(id)));

    return {
      'statusCode': 200,
      'body': {
        'success': true,
        'message': 'Task deleted successfully.',
      },
    };
  }

  // ---------------------------------------------------------------------------
  // Internal helpers
  // ---------------------------------------------------------------------------

  static DateTime? _parseDate(dynamic raw) {
    if (raw == null) return null;
    if (raw is DateTime) return raw.toUtc();
    return DateTime.tryParse(raw.toString())?.toUtc();
  }

  static Map<String, dynamic> _error(int statusCode, String message) {
    return {
      'statusCode': statusCode,
      'body': {'success': false, 'message': message},
    };
  }
}
