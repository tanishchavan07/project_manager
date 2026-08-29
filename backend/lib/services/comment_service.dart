import 'package:mongo_dart/mongo_dart.dart';

import '../config/database.dart';
import '../models/comment.dart';

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

/// Handles project comment operations.
class CommentService {
  // ---------------------------------------------------------------------------
  // Add comment  POST /api/projects/:projectId/comments
  // Owner or collaborator may post comments. userId comes from the JWT.
  // ---------------------------------------------------------------------------

  static Future<Map<String, dynamic>> addComment(
      String projectId, Map<String, dynamic> body, String requestingUserId) async {
    if (!_isValidObjectId(projectId)) {
      return _error(400, 'Invalid project ID format.');
    }

    final message = body['message']?.toString().trim();

    if (message == null || message.isEmpty) {
      return _error(400, 'Comment message is required.');
    }

    // Verify project exists and user can access it
    final project = await Database.projects
        .findOne(where.id(ObjectId.fromHexString(projectId)));
    if (project == null) {
      return _error(404, 'Project not found.');
    }
    if (!_canAccessProject(project, requestingUserId)) {
      return _forbidden();
    }

    final comment = Comment(
      projectId: projectId,
      userId: requestingUserId, // always from JWT, not body
      message: message,
    );

    final result = await Database.comments.insertOne(comment.toMap());
    final insertedOid = result.id as ObjectId;
    final insertedId = insertedOid.oid;

    final created = Comment.fromMap({...comment.toMap(), '_id': result.id});

    return {
      'statusCode': 201,
      'body': {
        'success': true,
        'message': 'Comment added successfully.',
        'data': {...created.toJson(), 'id': insertedId},
      },
    };
  }

  // ---------------------------------------------------------------------------
  // Get comments  GET /api/projects/:projectId/comments
  // Owner or collaborator.
  // ---------------------------------------------------------------------------

  static Future<Map<String, dynamic>> getComments(
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

    final docs = await Database.comments
        .find(where.eq('projectId', projectId).sortBy('createdAt'))
        .toList();
    final comments = docs.map((d) => Comment.fromMap(d).toJson()).toList();

    return {
      'statusCode': 200,
      'body': {
        'success': true,
        'message': 'Comments retrieved successfully.',
        'data': comments,
      },
    };
  }

  // ---------------------------------------------------------------------------
  // Delete comment  DELETE /api/comments/:id
  // Only the comment author (userId from JWT) may delete their own comment.
  // ---------------------------------------------------------------------------

  static Future<Map<String, dynamic>> deleteComment(
      String id, String requestingUserId) async {
    if (!_isValidObjectId(id)) {
      return _error(400, 'Invalid comment ID format.');
    }

    final existing =
        await Database.comments.findOne(where.id(ObjectId.fromHexString(id)));
    if (existing == null) {
      return _error(404, 'Comment not found.');
    }

    // Only the author may delete their comment
    if (existing['userId']?.toString() != requestingUserId) {
      return {
        'statusCode': 403,
        'body': {
          'success': false,
          'message': 'You can only delete your own comments.',
        },
      };
    }

    await Database.comments.deleteOne(where.id(ObjectId.fromHexString(id)));

    return {
      'statusCode': 200,
      'body': {
        'success': true,
        'message': 'Comment deleted successfully.',
      },
    };
  }

  // ---------------------------------------------------------------------------
  // Internal helpers
  // ---------------------------------------------------------------------------

  static Map<String, dynamic> _error(int statusCode, String message) {
    return {
      'statusCode': statusCode,
      'body': {'success': false, 'message': message},
    };
  }
}
