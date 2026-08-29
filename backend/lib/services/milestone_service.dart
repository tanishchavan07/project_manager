import 'package:mongo_dart/mongo_dart.dart';

import '../config/database.dart';
import '../models/milestone.dart';

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

/// Handles complete Milestone CRUD operations.
class MilestoneService {
  // ---------------------------------------------------------------------------
  // Create  POST /api/milestones
  // Owner or collaborator may create milestones.
  // ---------------------------------------------------------------------------

  static Future<Map<String, dynamic>> createMilestone(
      Map<String, dynamic> body, String requestingUserId) async {
    final projectId = body['projectId']?.toString().trim();
    final title = body['title']?.toString().trim();
    final status = body['status']?.toString().trim() ?? 'pending';

    if (projectId == null || projectId.isEmpty) {
      return _error(400, 'Project ID is required.');
    }
    if (!_isValidObjectId(projectId)) {
      return _error(400, 'Invalid project ID format.');
    }
    if (title == null || title.isEmpty) {
      return _error(400, 'Milestone title is required.');
    }
    if (!Milestone.validStatuses.contains(status)) {
      return _error(400,
          'Invalid status. Valid values: ${Milestone.validStatuses.join(', ')}');
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

    final milestone = Milestone(
      projectId: projectId,
      title: title,
      description: body['description']?.toString() ?? '',
      dueDate: _parseDate(body['dueDate']),
      status: status,
    );

    final result = await Database.milestones.insertOne(milestone.toMap());
    final insertedOid = result.id as ObjectId;
    final insertedId = insertedOid.oid;

    final created = Milestone.fromMap({...milestone.toMap(), '_id': result.id});

    return {
      'statusCode': 201,
      'body': {
        'success': true,
        'message': 'Milestone created successfully.',
        'data': {...created.toJson(), 'id': insertedId},
      },
    };
  }

  // ---------------------------------------------------------------------------
  // Get by project  GET /api/milestones/project/:projectId
  // Owner or collaborator.
  // ---------------------------------------------------------------------------

  static Future<Map<String, dynamic>> getMilestonesByProject(
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

    final docs = await Database.milestones
        .find(where.eq('projectId', projectId))
        .toList();
    final milestones =
        docs.map((d) => Milestone.fromMap(d).toJson()).toList();

    return {
      'statusCode': 200,
      'body': {
        'success': true,
        'message': 'Milestones retrieved successfully.',
        'data': milestones,
      },
    };
  }

  // ---------------------------------------------------------------------------
  // Get one  GET /api/milestones/:id
  // Owner or collaborator of the parent project.
  // ---------------------------------------------------------------------------

  static Future<Map<String, dynamic>> getMilestoneById(
      String id, String requestingUserId) async {
    if (!_isValidObjectId(id)) {
      return _error(400, 'Invalid milestone ID format.');
    }

    final doc =
        await Database.milestones.findOne(where.id(ObjectId.fromHexString(id)));
    if (doc == null) {
      return _error(404, 'Milestone not found.');
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
        'message': 'Milestone retrieved successfully.',
        'data': Milestone.fromMap(doc).toJson(),
      },
    };
  }

  // ---------------------------------------------------------------------------
  // Update  PUT /api/milestones/:id
  // Owner or collaborator of the parent project.
  // ---------------------------------------------------------------------------

  static Future<Map<String, dynamic>> updateMilestone(
      String id, Map<String, dynamic> body, String requestingUserId) async {
    if (!_isValidObjectId(id)) {
      return _error(400, 'Invalid milestone ID format.');
    }

    final existing =
        await Database.milestones.findOne(where.id(ObjectId.fromHexString(id)));
    if (existing == null) {
      return _error(404, 'Milestone not found.');
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
      if (t.isEmpty) return _error(400, 'Milestone title cannot be empty.');
      updates['title'] = t;
    }
    if (body.containsKey('description')) {
      updates['description'] = body['description']?.toString() ?? '';
    }
    if (body.containsKey('status')) {
      final s = body['status'].toString();
      if (!Milestone.validStatuses.contains(s)) {
        return _error(400,
            'Invalid status. Valid values: ${Milestone.validStatuses.join(', ')}');
      }
      updates['status'] = s;
    }
    if (body.containsKey('dueDate')) {
      updates['dueDate'] = _parseDate(body['dueDate'])?.toIso8601String();
    }

    updates['updatedAt'] = DateTime.now().toUtc().toIso8601String();

    await Database.milestones.updateOne(
      where.id(ObjectId.fromHexString(id)),
      {'\$set': updates},
    );

    final updated =
        await Database.milestones.findOne(where.id(ObjectId.fromHexString(id)));

    return {
      'statusCode': 200,
      'body': {
        'success': true,
        'message': 'Milestone updated successfully.',
        'data': Milestone.fromMap(updated!).toJson(),
      },
    };
  }

  // ---------------------------------------------------------------------------
  // Delete  DELETE /api/milestones/:id
  // Owner or collaborator of the parent project.
  // ---------------------------------------------------------------------------

  static Future<Map<String, dynamic>> deleteMilestone(
      String id, String requestingUserId) async {
    if (!_isValidObjectId(id)) {
      return _error(400, 'Invalid milestone ID format.');
    }

    final existing =
        await Database.milestones.findOne(where.id(ObjectId.fromHexString(id)));
    if (existing == null) {
      return _error(404, 'Milestone not found.');
    }

    final projectId = existing['projectId']?.toString() ?? '';
    if (_isValidObjectId(projectId)) {
      final project = await Database.projects
          .findOne(where.id(ObjectId.fromHexString(projectId)));
      if (project != null && !_canAccessProject(project, requestingUserId)) {
        return _forbidden();
      }
    }

    await Database.milestones
        .deleteOne(where.id(ObjectId.fromHexString(id)));

    return {
      'statusCode': 200,
      'body': {
        'success': true,
        'message': 'Milestone deleted successfully.',
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
