import 'dart:convert';
import 'dart:io';

import '../lib/config/env.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:shelf_cors_headers/shelf_cors_headers.dart';
import 'package:shelf_router/shelf_router.dart';

import '../lib/config/database.dart';
import '../lib/services/ai_service.dart';
import '../lib/services/auth_service.dart';
import '../lib/services/collaboration_service.dart';
import '../lib/services/comment_service.dart';
import '../lib/services/milestone_service.dart';
import '../lib/services/project_service.dart';
import '../lib/services/task_service.dart';

// =============================================================================
// Entry point
// =============================================================================

Future<void> main() async {
  // Load .env file once before any service is used.
  AppEnv.load();

  // Connect to MongoDB
  await Database.connect();

  // Build router
  final router = _buildRouter();

  // Configure middleware stack:
  //   1. CORS  — allows Flutter Web (any origin in dev; restrict in prod)
  //   2. Logger
  //   3. Error handler
  final corsHeadersMap = {
    ACCESS_CONTROL_ALLOW_ORIGIN: '*',
    ACCESS_CONTROL_ALLOW_METHODS: 'GET, POST, PUT, DELETE, OPTIONS',
    ACCESS_CONTROL_ALLOW_HEADERS:
        'Origin, Content-Type, Authorization, Accept',
  };

  final handler = Pipeline()
      .addMiddleware(corsHeaders(headers: corsHeadersMap))
      .addMiddleware(logRequests())
      .addMiddleware(_errorHandler())
      .addHandler(router.call);

  final port = int.tryParse(AppEnv.get('PORT') ?? '') ?? 8080;
  final server = await shelf_io.serve(handler, InternetAddress.anyIPv4, port);

  print('');
  print('╔══════════════════════════════════════════════════╗');
  print('║   AI Project Management System — Dart Backend   ║');
  print('╠══════════════════════════════════════════════════╣');
  print('║  Server running on  http://localhost:$port         ║');
  print('║  MongoDB connected  ✓                            ║');
  print('╚══════════════════════════════════════════════════╝');
  print('');

  // Graceful shutdown
  ProcessSignal.sigint.watch().listen((_) async {
    print('\n[Server] Shutting down gracefully…');
    await Database.close();
    server.close(force: false);
    exit(0);
  });
}

// =============================================================================
// Router
// =============================================================================

Router _buildRouter() {
  final router = Router();

  // Health check
  router.get('/health', (_) => _json({'status': 'ok'}, 200));

  // ---------------------------------------------------------------------------
  // Auth  (public — no JWT required)
  // ---------------------------------------------------------------------------
  router.post('/api/auth/register', (Request req) async {
    final body = await _parseBody(req);
    final result = await AuthService.register(body);
    return _fromResult(result);
  });

  router.post('/api/auth/login', (Request req) async {
    final body = await _parseBody(req);
    final result = await AuthService.login(body);
    return _fromResult(result);
  });

  // ---------------------------------------------------------------------------
  // Projects  (JWT required)
  // ---------------------------------------------------------------------------
  router.post('/api/projects', (Request req) async {
    final userId = _requireAuth(req);
    if (userId == null) return _unauthorized();
    final body = await _parseBody(req);
    final result = await ProjectService.createProject(body, userId);
    return _fromResult(result);
  });

  router.get('/api/projects', (Request req) async {
    final userId = _requireAuth(req);
    if (userId == null) return _unauthorized();
    final result = await ProjectService.getAllProjects(userId);
    return _fromResult(result);
  });

  router.get('/api/projects/<id>', (Request req, String id) async {
    final userId = _requireAuth(req);
    if (userId == null) return _unauthorized();
    final result = await ProjectService.getProjectById(id, userId);
    return _fromResult(result);
  });

  router.put('/api/projects/<id>', (Request req, String id) async {
    final userId = _requireAuth(req);
    if (userId == null) return _unauthorized();
    final body = await _parseBody(req);
    final result = await ProjectService.updateProject(id, body, userId);
    return _fromResult(result);
  });

  router.delete('/api/projects/<id>', (Request req, String id) async {
    final userId = _requireAuth(req);
    if (userId == null) return _unauthorized();
    final result = await ProjectService.deleteProject(id, userId);
    return _fromResult(result);
  });

  // ---------------------------------------------------------------------------
  // Tasks  (JWT required)
  // ---------------------------------------------------------------------------
  router.post('/api/tasks', (Request req) async {
    final userId = _requireAuth(req);
    if (userId == null) return _unauthorized();
    final body = await _parseBody(req);
    final result = await TaskService.createTask(body, userId);
    return _fromResult(result);
  });

  router.get('/api/tasks/project/<projectId>',
      (Request req, String projectId) async {
    final userId = _requireAuth(req);
    if (userId == null) return _unauthorized();
    final result = await TaskService.getTasksByProject(projectId, userId);
    return _fromResult(result);
  });

  router.get('/api/tasks/<id>', (Request req, String id) async {
    final userId = _requireAuth(req);
    if (userId == null) return _unauthorized();
    final result = await TaskService.getTaskById(id, userId);
    return _fromResult(result);
  });

  router.put('/api/tasks/<id>', (Request req, String id) async {
    final userId = _requireAuth(req);
    if (userId == null) return _unauthorized();
    final body = await _parseBody(req);
    final result = await TaskService.updateTask(id, body, userId);
    return _fromResult(result);
  });

  router.delete('/api/tasks/<id>', (Request req, String id) async {
    final userId = _requireAuth(req);
    if (userId == null) return _unauthorized();
    final result = await TaskService.deleteTask(id, userId);
    return _fromResult(result);
  });

  // ---------------------------------------------------------------------------
  // Milestones  (JWT required)
  // ---------------------------------------------------------------------------
  router.post('/api/milestones', (Request req) async {
    final userId = _requireAuth(req);
    if (userId == null) return _unauthorized();
    final body = await _parseBody(req);
    final result = await MilestoneService.createMilestone(body, userId);
    return _fromResult(result);
  });

  router.get('/api/milestones/project/<projectId>',
      (Request req, String projectId) async {
    final userId = _requireAuth(req);
    if (userId == null) return _unauthorized();
    final result =
        await MilestoneService.getMilestonesByProject(projectId, userId);
    return _fromResult(result);
  });

  router.get('/api/milestones/<id>', (Request req, String id) async {
    final userId = _requireAuth(req);
    if (userId == null) return _unauthorized();
    final result = await MilestoneService.getMilestoneById(id, userId);
    return _fromResult(result);
  });

  router.put('/api/milestones/<id>', (Request req, String id) async {
    final userId = _requireAuth(req);
    if (userId == null) return _unauthorized();
    final body = await _parseBody(req);
    final result = await MilestoneService.updateMilestone(id, body, userId);
    return _fromResult(result);
  });

  router.delete('/api/milestones/<id>', (Request req, String id) async {
    final userId = _requireAuth(req);
    if (userId == null) return _unauthorized();
    final result = await MilestoneService.deleteMilestone(id, userId);
    return _fromResult(result);
  });

  // ---------------------------------------------------------------------------
  // Collaboration  (JWT required — owner-only for add/remove)
  // ---------------------------------------------------------------------------
  router.post('/api/projects/<projectId>/collaborators',
      (Request req, String projectId) async {
    final userId = _requireAuth(req);
    if (userId == null) return _unauthorized();
    final body = await _parseBody(req);
    final result =
        await CollaborationService.addCollaborator(projectId, body, userId);
    return _fromResult(result);
  });

  router.get('/api/projects/<projectId>/collaborators',
      (Request req, String projectId) async {
    final userId = _requireAuth(req);
    if (userId == null) return _unauthorized();
    final result =
        await CollaborationService.getCollaborators(projectId, userId);
    return _fromResult(result);
  });

  router.delete(
      '/api/projects/<projectId>/collaborators/<memberId>',
      (Request req, String projectId, String memberId) async {
    final userId = _requireAuth(req);
    if (userId == null) return _unauthorized();
    final result =
        await CollaborationService.removeCollaborator(projectId, memberId, userId);
    return _fromResult(result);
  });

  // ---------------------------------------------------------------------------
  // Comments  (JWT required)
  // ---------------------------------------------------------------------------
  router.post('/api/projects/<projectId>/comments',
      (Request req, String projectId) async {
    final userId = _requireAuth(req);
    if (userId == null) return _unauthorized();
    final body = await _parseBody(req);
    final result = await CommentService.addComment(projectId, body, userId);
    return _fromResult(result);
  });

  router.get('/api/projects/<projectId>/comments',
      (Request req, String projectId) async {
    final userId = _requireAuth(req);
    if (userId == null) return _unauthorized();
    final result = await CommentService.getComments(projectId, userId);
    return _fromResult(result);
  });

  router.delete('/api/comments/<id>', (Request req, String id) async {
    final userId = _requireAuth(req);
    if (userId == null) return _unauthorized();
    final result = await CommentService.deleteComment(id, userId);
    return _fromResult(result);
  });

  // ---------------------------------------------------------------------------
  // AI  (JWT required)
  // ---------------------------------------------------------------------------
  router.post('/api/ai/chat', (Request req) async {
    final userId = _requireAuth(req);
    if (userId == null) return _unauthorized();
    final body = await _parseBody(req);
    final result = await AIService.chat(body);
    return _fromResult(result);
  });

  // ---------------------------------------------------------------------------
  // Fallback 404
  // ---------------------------------------------------------------------------
  router.all('/<ignored|.*>', (Request req) {
    // Handle CORS preflight (OPTIONS)
    if (req.method == 'OPTIONS') {
      return Response.ok('', headers: {
        'Access-Control-Allow-Origin': '*',
        'Access-Control-Allow-Methods': 'GET, POST, PUT, DELETE, OPTIONS',
        'Access-Control-Allow-Headers':
            'Origin, Content-Type, Authorization, Accept',
      });
    }
    return _json({
      'success': false,
      'message': 'Route not found: ${req.method} ${req.url.path}',
    }, 404);
  });

  return router;
}

// =============================================================================
// Auth helper
// =============================================================================

/// Extracts and verifies the JWT from the Authorization header.
/// Returns the authenticated user's ID, or null if missing/invalid.
String? _requireAuth(Request req) {
  final authHeader = req.headers['authorization'];
  final payload = AuthService.verifyToken(authHeader);
  return payload?['userId'] as String?;
}

Response _unauthorized() => _json({
      'success': false,
      'message': 'Unauthorized. Please provide a valid Bearer token.',
    }, 401);

// =============================================================================
// Middleware
// =============================================================================

Middleware _errorHandler() {
  return (Handler inner) {
    return (Request request) async {
      try {
        return await inner(request);
      } on FormatException catch (e) {
        return _json({
          'success': false,
          'message': 'Invalid JSON body: ${e.message}',
        }, 400);
      } catch (e, stack) {
        stderr.writeln('[ERROR] Unhandled exception: $e');
        stderr.writeln(stack);
        return _json({
          'success': false,
          'message': 'An unexpected server error occurred.',
        }, 500);
      }
    };
  };
}

// =============================================================================
// Helpers
// =============================================================================

/// Reads and parses the request body as JSON.
Future<Map<String, dynamic>> _parseBody(Request request) async {
  final bodyStr = await request.readAsString();
  if (bodyStr.isEmpty) return {};
  final decoded = jsonDecode(bodyStr);
  if (decoded is Map<String, dynamic>) return decoded;
  return {};
}

/// Builds a shelf [Response] from a service result map.
Response _fromResult(Map<String, dynamic> result) {
  final statusCode = result['statusCode'] as int? ?? 500;
  final body = result['body'] as Map<String, dynamic>? ?? {};
  return _json(body, statusCode);
}

/// Creates a JSON [Response] with proper Content-Type header.
Response _json(Map<String, dynamic> body, int statusCode) {
  return Response(
    statusCode,
    body: jsonEncode(body),
    headers: {
      'Content-Type': 'application/json',
      'Access-Control-Allow-Origin': '*',
    },
  );
}
