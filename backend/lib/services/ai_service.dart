import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:mongo_dart/mongo_dart.dart';

import '../config/database.dart';
import '../models/milestone.dart';
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

/// AI assistant service backed by Google Gemini.
///
/// The provider is abstracted behind [_callAI] so it can be swapped without
/// touching the rest of the application.
class AIService {
  static const String _geminiBaseUrl =
      'https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash:generateContent';

  static String get _apiKey =>
      Platform.environment['GEMINI_API_KEY'] ?? '';

  // ---------------------------------------------------------------------------
  // Chat  POST /api/ai/chat
  // ---------------------------------------------------------------------------

  static Future<Map<String, dynamic>> chat(Map<String, dynamic> body) async {
    final userMessage = body['message']?.toString().trim();
    final projectId = body['projectId']?.toString().trim();

    if (userMessage == null || userMessage.isEmpty) {
      return _error(400, 'Message is required.');
    }

    if (_apiKey.isEmpty) {
      return _error(500,
          'AI service is not configured. Please set the GEMINI_API_KEY environment variable.');
    }

    // --- Build context from MongoDB if projectId is provided ---
    String systemContext = _buildBaseSystemPrompt();

    if (projectId != null && projectId.isNotEmpty) {
      if (!_isValidObjectId(projectId)) {
        return _error(400, 'Invalid project ID format.');
      }
      final contextData = await _buildProjectContext(projectId);
      if (contextData['error'] != null) {
        return _error(404, contextData['error'] as String);
      }
      systemContext += '\n\n${contextData['context']}';
    }

    // --- Call AI provider ---
    try {
      final aiResponse = await _callAI(systemContext, userMessage);
      return {
        'statusCode': 200,
        'body': {
          'success': true,
          'message': 'AI response generated.',
          'data': {
            'reply': aiResponse,
            'projectId': projectId,
          },
        },
      };
    } catch (e) {
      return _error(500, 'Failed to get AI response. Please try again later.');
    }
  }

  // ---------------------------------------------------------------------------
  // Build project context from MongoDB
  // ---------------------------------------------------------------------------

  static Future<Map<String, dynamic>> _buildProjectContext(
      String projectId) async {
    final projectDoc = await Database.projects
        .findOne(where.id(ObjectId.fromHexString(projectId)));
    if (projectDoc == null) {
      return {'error': 'Project not found.'};
    }

    final taskDocs =
        await Database.tasks.find(where.eq('projectId', projectId)).toList();
    final milestoneDocs = await Database.milestones
        .find(where.eq('projectId', projectId))
        .toList();

    final tasks = taskDocs.map((d) => Task.fromMap(d)).toList();
    final milestones = milestoneDocs.map((d) => Milestone.fromMap(d)).toList();

    final pendingTasks =
        tasks.where((t) => t.status != 'done' && t.status != 'cancelled').toList();
    final completedTasks =
        tasks.where((t) => t.status == 'done').toList();
    final highPriorityTasks =
        tasks.where((t) => t.priority == 'high' || t.priority == 'critical').toList();

    final pendingMilestones =
        milestones.where((m) => m.status != 'completed').toList();

    final buffer = StringBuffer();
    buffer.writeln('=== PROJECT CONTEXT ===');
    buffer.writeln('Project Name: ${projectDoc['name']}');
    buffer.writeln('Description: ${projectDoc['description'] ?? 'N/A'}');
    buffer.writeln('Status: ${projectDoc['status']}');
    buffer.writeln('Priority: ${projectDoc['priority']}');
    buffer.writeln('Category: ${projectDoc['category'] ?? 'N/A'}');
    buffer.writeln('Start Date: ${projectDoc['startDate'] ?? 'N/A'}');
    buffer.writeln('End Date: ${projectDoc['endDate'] ?? 'N/A'}');
    buffer.writeln('');
    buffer.writeln('--- TASKS SUMMARY ---');
    buffer.writeln('Total Tasks: ${tasks.length}');
    buffer.writeln('Pending Tasks: ${pendingTasks.length}');
    buffer.writeln('Completed Tasks: ${completedTasks.length}');
    buffer.writeln('High Priority Tasks: ${highPriorityTasks.length}');
    buffer.writeln('');

    if (pendingTasks.isNotEmpty) {
      buffer.writeln('Pending Tasks Detail:');
      for (final t in pendingTasks) {
        buffer.writeln(
            '  - [${t.priority.toUpperCase()}] ${t.title} (status: ${t.status}${t.dueDate != null ? ', due: ${t.dueDate!.toIso8601String().split('T')[0]}' : ''})');
      }
      buffer.writeln('');
    }

    buffer.writeln('--- MILESTONES SUMMARY ---');
    buffer.writeln('Total Milestones: ${milestones.length}');
    buffer.writeln('Pending Milestones: ${pendingMilestones.length}');

    if (pendingMilestones.isNotEmpty) {
      buffer.writeln('Pending Milestones Detail:');
      for (final m in pendingMilestones) {
        buffer.writeln(
            '  - ${m.title} (status: ${m.status}${m.dueDate != null ? ', due: ${m.dueDate!.toIso8601String().split('T')[0]}' : ''})');
      }
    }

    return {'context': buffer.toString()};
  }

  // ---------------------------------------------------------------------------
  // Base system prompt
  // ---------------------------------------------------------------------------

  static String _buildBaseSystemPrompt() {
    return '''You are an intelligent AI project management assistant.
Your role is to help users understand and manage their projects, tasks, and milestones.
Be concise, helpful, and actionable in your responses.
When project context is provided, base your answers on the actual project data.
If you're asked about tasks, priorities, deadlines, or project status, reference the provided context.
Do not make up data that is not in the context.''';
  }

  // ---------------------------------------------------------------------------
  // AI provider call (Gemini 1.5 Flash)
  // Swap this method to change AI providers without touching the rest.
  // ---------------------------------------------------------------------------

  static Future<String> _callAI(
      String systemPrompt, String userMessage) async {
    final url = Uri.parse('$_geminiBaseUrl?key=$_apiKey');

    final requestBody = {
      'contents': [
        {
          'parts': [
            {
              'text':
                  '$systemPrompt\n\nUser question: $userMessage',
            }
          ],
          'role': 'user',
        }
      ],
      'generationConfig': {
        'temperature': 0.7,
        'maxOutputTokens': 1024,
      },
    };

    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(requestBody),
    );

    if (response.statusCode != 200) {
      throw Exception(
          'Gemini API error: ${response.statusCode} ${response.body}');
    }

    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    final candidates = decoded['candidates'] as List?;
    if (candidates == null || candidates.isEmpty) {
      throw Exception('No candidates returned from Gemini API.');
    }

    final content = candidates[0]['content'] as Map<String, dynamic>?;
    final parts = content?['parts'] as List?;
    if (parts == null || parts.isEmpty) {
      throw Exception('No parts in Gemini response.');
    }

    return parts[0]['text'] as String? ?? 'No response text.';
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
