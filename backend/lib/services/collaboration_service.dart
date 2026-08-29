import 'package:mongo_dart/mongo_dart.dart';

import '../config/database.dart';
import '../models/user.dart';

/// Validates whether [id] is a valid MongoDB ObjectId hex string.
bool _isValidObjectId(String id) {
  try {
    ObjectId.fromHexString(id);
    return true;
  } catch (_) {
    return false;
  }
}

/// Handles adding, listing, and removing project collaborators.
class CollaborationService {
  // ---------------------------------------------------------------------------
  // Add collaborator  POST /api/projects/:projectId/collaborators
  // Owner only may add collaborators.
  // ---------------------------------------------------------------------------

  static Future<Map<String, dynamic>> addCollaborator(
      String projectId, Map<String, dynamic> body, String requestingUserId) async {
    if (!_isValidObjectId(projectId)) {
      return _error(400, 'Invalid project ID format.');
    }

    final email = body['email']?.toString().trim().toLowerCase();

    if (email == null || email.isEmpty) {
      return _error(400, 'Email is required.');
    }

    // Verify project exists
    final projectDoc = await Database.projects
        .findOne(where.id(ObjectId.fromHexString(projectId)));
    if (projectDoc == null) {
      return _error(404, 'Project not found.');
    }

    // Only the owner can manage collaborators
    final ownerId = projectDoc['ownerId']?.toString() ?? '';
    if (ownerId != requestingUserId) {
      return _forbidden();
    }

    // Look up user by email
    final userDoc = await Database.users.findOne(where.eq('email', email));
    if (userDoc == null) {
      return _error(404, 'User with this email not found.');
    }

    final user = User.fromMap(userDoc);
    final targetUserId = user.id!;

    final collaboratorIds =
        List<String>.from(projectDoc['collaboratorIds'] as List? ?? []);

    // Owner is always implicitly a collaborator — don't duplicate
    if (targetUserId == ownerId) {
      return _error(409,
          'User is the project owner and cannot be added as a collaborator.');
    }

    // Prevent duplicate collaborators
    if (collaboratorIds.contains(targetUserId)) {
      return _error(409, 'User is already a collaborator on this project.');
    }

    collaboratorIds.add(targetUserId);

    await Database.projects.updateOne(
      where.id(ObjectId.fromHexString(projectId)),
      {
        '\$set': {
          'collaboratorIds': collaboratorIds,
          'updatedAt': DateTime.now().toUtc().toIso8601String(),
        }
      },
    );

    return {
      'statusCode': 200,
      'body': {
        'success': true,
        'message': 'Collaborator added successfully.',
        'data': {
          'projectId': projectId,
          'collaborator': user.toJson(),
        },
      },
    };
  }

  // ---------------------------------------------------------------------------
  // Get collaborators  GET /api/projects/:projectId/collaborators
  // Owner or collaborator may view the list.
  // ---------------------------------------------------------------------------

  static Future<Map<String, dynamic>> getCollaborators(
      String projectId, String requestingUserId) async {
    if (!_isValidObjectId(projectId)) {
      return _error(400, 'Invalid project ID format.');
    }

    final projectDoc = await Database.projects
        .findOne(where.id(ObjectId.fromHexString(projectId)));
    if (projectDoc == null) {
      return _error(404, 'Project not found.');
    }

    // Access check: owner or collaborator
    final ownerId = projectDoc['ownerId']?.toString() ?? '';
    final collaboratorIds =
        List<String>.from(projectDoc['collaboratorIds'] as List? ?? []);
    if (ownerId != requestingUserId &&
        !collaboratorIds.contains(requestingUserId)) {
      return _forbidden();
    }

    final collaborators = <Map<String, dynamic>>[];
    for (final uid in collaboratorIds) {
      if (!_isValidObjectId(uid)) continue;
      final userDoc = await Database.users
          .findOne(where.id(ObjectId.fromHexString(uid)));
      if (userDoc != null) {
        collaborators.add(User.fromMap(userDoc).toJson());
      }
    }

    return {
      'statusCode': 200,
      'body': {
        'success': true,
        'message': 'Collaborators retrieved successfully.',
        'data': collaborators,
      },
    };
  }

  // ---------------------------------------------------------------------------
  // Remove collaborator  DELETE /api/projects/:projectId/collaborators/:memberId
  // Owner only may remove collaborators.
  // ---------------------------------------------------------------------------

  static Future<Map<String, dynamic>> removeCollaborator(
      String projectId, String memberId, String requestingUserId) async {
    if (!_isValidObjectId(projectId)) {
      return _error(400, 'Invalid project ID format.');
    }
    if (!_isValidObjectId(memberId)) {
      return _error(400, 'Invalid user ID format.');
    }

    final projectDoc = await Database.projects
        .findOne(where.id(ObjectId.fromHexString(projectId)));
    if (projectDoc == null) {
      return _error(404, 'Project not found.');
    }

    // Only the owner can remove collaborators
    final ownerId = projectDoc['ownerId']?.toString() ?? '';
    if (ownerId != requestingUserId) {
      return _forbidden();
    }

    // Protect the owner from being removed
    if (memberId == ownerId) {
      return _error(403, 'Project owner cannot be removed from collaborators.');
    }

    final collaboratorIds =
        List<String>.from(projectDoc['collaboratorIds'] as List? ?? []);

    if (!collaboratorIds.contains(memberId)) {
      return _error(404, 'User is not a collaborator on this project.');
    }

    collaboratorIds.remove(memberId);

    await Database.projects.updateOne(
      where.id(ObjectId.fromHexString(projectId)),
      {
        '\$set': {
          'collaboratorIds': collaboratorIds,
          'updatedAt': DateTime.now().toUtc().toIso8601String(),
        }
      },
    );

    return {
      'statusCode': 200,
      'body': {
        'success': true,
        'message': 'Collaborator removed successfully.',
      },
    };
  }

  // ---------------------------------------------------------------------------
  // Internal helpers
  // ---------------------------------------------------------------------------

  static Map<String, dynamic> _forbidden() => {
        'statusCode': 403,
        'body': {
          'success': false,
          'message': 'You are not authorized to access this project.',
        },
      };

  static Map<String, dynamic> _error(int statusCode, String message) {
    return {
      'statusCode': statusCode,
      'body': {'success': false, 'message': message},
    };
  }
}
