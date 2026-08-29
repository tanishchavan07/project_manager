import 'dart:convert';
import 'package:http/http.dart' as http;

// =============================================================================
// DATA MODELS
// =============================================================================

class User {
  final String id;
  final String name;
  final String email;
  final String? createdAt;

  User({
    required this.id,
    required this.name,
    required this.email,
    this.createdAt,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      email: json['email']?.toString() ?? '',
      createdAt: json['createdAt']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'createdAt': createdAt,
    };
  }
}

class Project {
  final String id;
  final String name;
  final String description;
  final String category;
  final String status;
  final String priority;
  final String? startDate;
  final String? endDate;
  final String ownerId;
  final List<String> collaboratorIds;
  final String? createdAt;
  final String? updatedAt;

  Project({
    required this.id,
    required this.name,
    this.description = '',
    this.category = '',
    this.status = 'planning',
    this.priority = 'medium',
    this.startDate,
    this.endDate,
    required this.ownerId,
    this.collaboratorIds = const [],
    this.createdAt,
    this.updatedAt,
  });

  factory Project.fromJson(Map<String, dynamic> json) {
    List<String> parseList(dynamic raw) {
      if (raw is List) return raw.map((e) => e.toString()).toList();
      return [];
    }

    return Project(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      category: json['category']?.toString() ?? '',
      status: json['status']?.toString() ?? 'planning',
      priority: json['priority']?.toString() ?? 'medium',
      startDate: json['startDate']?.toString(),
      endDate: json['endDate']?.toString(),
      ownerId: json['ownerId']?.toString() ?? '',
      collaboratorIds: parseList(json['collaboratorIds']),
      createdAt: json['createdAt']?.toString(),
      updatedAt: json['updatedAt']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'category': category,
      'status': status,
      'priority': priority,
      'startDate': startDate,
      'endDate': endDate,
      'ownerId': ownerId,
      'collaboratorIds': collaboratorIds,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
    };
  }
}

class Task {
  final String id;
  final String projectId;
  final String title;
  final String description;
  final String status;
  final String priority;
  final String? dueDate;
  final String? assignedTo;
  final String? createdAt;
  final String? updatedAt;

  Task({
    required this.id,
    required this.projectId,
    required this.title,
    this.description = '',
    this.status = 'todo',
    this.priority = 'medium',
    this.dueDate,
    this.assignedTo,
    this.createdAt,
    this.updatedAt,
  });

  factory Task.fromJson(Map<String, dynamic> json) {
    return Task(
      id: json['id']?.toString() ?? '',
      projectId: json['projectId']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      status: json['status']?.toString() ?? 'todo',
      priority: json['priority']?.toString() ?? 'medium',
      dueDate: json['dueDate']?.toString(),
      assignedTo: json['assignedTo']?.toString(),
      createdAt: json['createdAt']?.toString(),
      updatedAt: json['updatedAt']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'projectId': projectId,
      'title': title,
      'description': description,
      'status': status,
      'priority': priority,
      'dueDate': dueDate,
      'assignedTo': assignedTo,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
    };
  }
}

class Milestone {
  final String id;
  final String projectId;
  final String title;
  final String description;
  final String? dueDate;
  final String status;
  final String? createdAt;
  final String? updatedAt;

  Milestone({
    required this.id,
    required this.projectId,
    required this.title,
    this.description = '',
    this.dueDate,
    this.status = 'pending',
    this.createdAt,
    this.updatedAt,
  });

  factory Milestone.fromJson(Map<String, dynamic> json) {
    return Milestone(
      id: json['id']?.toString() ?? '',
      projectId: json['projectId']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      dueDate: json['dueDate']?.toString(),
      status: json['status']?.toString() ?? 'pending',
      createdAt: json['createdAt']?.toString(),
      updatedAt: json['updatedAt']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'projectId': projectId,
      'title': title,
      'description': description,
      'dueDate': dueDate,
      'status': status,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
    };
  }
}

class Comment {
  final String id;
  final String projectId;
  final String userId;
  final String message;
  final String? createdAt;

  Comment({
    required this.id,
    required this.projectId,
    required this.userId,
    required this.message,
    this.createdAt,
  });

  factory Comment.fromJson(Map<String, dynamic> json) {
    return Comment(
      id: json['id']?.toString() ?? '',
      projectId: json['projectId']?.toString() ?? '',
      userId: json['userId']?.toString() ?? '',
      message: json['message']?.toString() ?? '',
      createdAt: json['createdAt']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'projectId': projectId,
      'userId': userId,
      'message': message,
      'createdAt': createdAt,
    };
  }
}

// =============================================================================
// API SERVICE
// =============================================================================

class ApiService {
  static const String baseUrl = 'http://localhost:8080';

  // In-memory active session
  static String? token;
  static User? currentUser;

  static Map<String, String> get _headers {
    final headers = <String, String>{
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };
    if (token != null && token!.isNotEmpty) {
      headers['Authorization'] = 'Bearer $token';
    }
    return headers;
  }

  // ---------------------------------------------------------------------------
  // AUTHENTICATION
  // ---------------------------------------------------------------------------

  static Future<Map<String, dynamic>> register({
    required String name,
    required String email,
    required String password,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/api/auth/register'),
      headers: _headers,
      body: jsonEncode({'name': name, 'email': email, 'password': password}),
    );
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode == 201 && data['success'] == true) {
      final resData = data['data'] as Map<String, dynamic>;
      token = resData['token']?.toString();
      if (resData['user'] != null) {
        currentUser = User.fromJson(resData['user'] as Map<String, dynamic>);
      }
    }
    return data;
  }

  static Future<Map<String, dynamic>> login({
    required String email,
    required String password,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/api/auth/login'),
      headers: _headers,
      body: jsonEncode({'email': email, 'password': password}),
    );
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode == 200 && data['success'] == true) {
      final resData = data['data'] as Map<String, dynamic>;
      token = resData['token']?.toString();
      if (resData['user'] != null) {
        currentUser = User.fromJson(resData['user'] as Map<String, dynamic>);
      }
    }
    return data;
  }

  static void logout() {
    token = null;
    currentUser = null;
  }

  // ---------------------------------------------------------------------------
  // PROJECTS
  // ---------------------------------------------------------------------------

  static Future<List<Project>> getProjects() async {
    final response = await http.get(
      Uri.parse('$baseUrl/api/projects'),
      headers: _headers,
    );
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      if (data['success'] == true && data['data'] is List) {
        final list = data['data'] as List;
        return list.map((e) => Project.fromJson(e as Map<String, dynamic>)).toList();
      }
    }
    throw Exception('Failed to load projects');
  }

  static Future<Project> getProject(String id) async {
    final response = await http.get(
      Uri.parse('$baseUrl/api/projects/$id'),
      headers: _headers,
    );
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      if (data['success'] == true && data['data'] != null) {
        return Project.fromJson(data['data'] as Map<String, dynamic>);
      }
    }
    throw Exception('Failed to load project details');
  }

  static Future<Map<String, dynamic>> createProject({
    required String name,
    String description = '',
    String category = '',
    String status = 'planning',
    String priority = 'medium',
    String? startDate,
    String? endDate,
    List<String> collaboratorIds = const [],
  }) async {
    final payload = {
      'name': name,
      'description': description,
      'category': category,
      'status': status,
      'priority': priority,
      'collaboratorIds': collaboratorIds,
    };
    if (startDate != null) payload['startDate'] = startDate;
    if (endDate != null) payload['endDate'] = endDate;

    final response = await http.post(
      Uri.parse('$baseUrl/api/projects'),
      headers: _headers,
      body: jsonEncode(payload),
    );
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  static Future<Map<String, dynamic>> updateProject(
    String id,
    Map<String, dynamic> fields,
  ) async {
    final response = await http.put(
      Uri.parse('$baseUrl/api/projects/$id'),
      headers: _headers,
      body: jsonEncode(fields),
    );
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  static Future<Map<String, dynamic>> deleteProject(String id) async {
    final response = await http.delete(
      Uri.parse('$baseUrl/api/projects/$id'),
      headers: _headers,
    );
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  // ---------------------------------------------------------------------------
  // TASKS
  // ---------------------------------------------------------------------------

  static Future<List<Task>> getTasks(String projectId) async {
    final response = await http.get(
      Uri.parse('$baseUrl/api/tasks/project/$projectId'),
      headers: _headers,
    );
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      if (data['success'] == true && data['data'] is List) {
        final list = data['data'] as List;
        return list.map((e) => Task.fromJson(e as Map<String, dynamic>)).toList();
      }
    }
    throw Exception('Failed to load tasks');
  }

  static Future<Task> getTask(String id) async {
    final response = await http.get(
      Uri.parse('$baseUrl/api/tasks/$id'),
      headers: _headers,
    );
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      if (data['success'] == true && data['data'] != null) {
        return Task.fromJson(data['data'] as Map<String, dynamic>);
      }
    }
    throw Exception('Failed to load task');
  }

  static Future<Map<String, dynamic>> createTask({
    required String projectId,
    required String title,
    String description = '',
    String status = 'todo',
    String priority = 'medium',
    String? dueDate,
    String? assignedTo,
  }) async {
    final payload = {
      'projectId': projectId,
      'title': title,
      'description': description,
      'status': status,
      'priority': priority,
    };
    if (dueDate != null) payload['dueDate'] = dueDate;
    if (assignedTo != null) payload['assignedTo'] = assignedTo;

    final response = await http.post(
      Uri.parse('$baseUrl/api/tasks'),
      headers: _headers,
      body: jsonEncode(payload),
    );
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  static Future<Map<String, dynamic>> updateTask(
    String id,
    Map<String, dynamic> fields,
  ) async {
    final response = await http.put(
      Uri.parse('$baseUrl/api/tasks/$id'),
      headers: _headers,
      body: jsonEncode(fields),
    );
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  static Future<Map<String, dynamic>> deleteTask(String id) async {
    final response = await http.delete(
      Uri.parse('$baseUrl/api/tasks/$id'),
      headers: _headers,
    );
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  // ---------------------------------------------------------------------------
  // MILESTONES
  // ---------------------------------------------------------------------------

  static Future<List<Milestone>> getMilestones(String projectId) async {
    final response = await http.get(
      Uri.parse('$baseUrl/api/milestones/project/$projectId'),
      headers: _headers,
    );
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      if (data['success'] == true && data['data'] is List) {
        final list = data['data'] as List;
        return list.map((e) => Milestone.fromJson(e as Map<String, dynamic>)).toList();
      }
    }
    throw Exception('Failed to load milestones');
  }

  static Future<Milestone> getMilestone(String id) async {
    final response = await http.get(
      Uri.parse('$baseUrl/api/milestones/$id'),
      headers: _headers,
    );
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      if (data['success'] == true && data['data'] != null) {
        return Milestone.fromJson(data['data'] as Map<String, dynamic>);
      }
    }
    throw Exception('Failed to load milestone');
  }

  static Future<Map<String, dynamic>> createMilestone({
    required String projectId,
    required String title,
    String description = '',
    String status = 'pending',
    String? dueDate,
  }) async {
    final payload = {
      'projectId': projectId,
      'title': title,
      'description': description,
      'status': status,
    };
    if (dueDate != null) payload['dueDate'] = dueDate;

    final response = await http.post(
      Uri.parse('$baseUrl/api/milestones'),
      headers: _headers,
      body: jsonEncode(payload),
    );
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  static Future<Map<String, dynamic>> updateMilestone(
    String id,
    Map<String, dynamic> fields,
  ) async {
    final response = await http.put(
      Uri.parse('$baseUrl/api/milestones/$id'),
      headers: _headers,
      body: jsonEncode(fields),
    );
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  static Future<Map<String, dynamic>> deleteMilestone(String id) async {
    final response = await http.delete(
      Uri.parse('$baseUrl/api/milestones/$id'),
      headers: _headers,
    );
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  // ---------------------------------------------------------------------------
  // COLLABORATION
  // ---------------------------------------------------------------------------

  static Future<List<User>> getCollaborators(String projectId) async {
    final response = await http.get(
      Uri.parse('$baseUrl/api/projects/$projectId/collaborators'),
      headers: _headers,
    );
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      if (data['success'] == true && data['data'] is List) {
        final list = data['data'] as List;
        return list.map((e) => User.fromJson(e as Map<String, dynamic>)).toList();
      }
    }
    throw Exception('Failed to load collaborators');
  }

  static Future<Map<String, dynamic>> addCollaborator(
    String projectId,
    String email,
  ) async {
    final response = await http.post(
      Uri.parse('$baseUrl/api/projects/$projectId/collaborators'),
      headers: _headers,
      body: jsonEncode({'email': email}),
    );
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  static Future<Map<String, dynamic>> removeCollaborator(
    String projectId,
    String userId,
  ) async {
    final response = await http.delete(
      Uri.parse('$baseUrl/api/projects/$projectId/collaborators/$userId'),
      headers: _headers,
    );
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  // ---------------------------------------------------------------------------
  // COMMENTS / DISCUSSION
  // ---------------------------------------------------------------------------

  static Future<List<Comment>> getComments(String projectId) async {
    final response = await http.get(
      Uri.parse('$baseUrl/api/projects/$projectId/comments'),
      headers: _headers,
    );
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      if (data['success'] == true && data['data'] is List) {
        final list = data['data'] as List;
        return list.map((e) => Comment.fromJson(e as Map<String, dynamic>)).toList();
      }
    }
    throw Exception('Failed to load comments');
  }

  static Future<Map<String, dynamic>> addComment({
    required String projectId,
    required String message,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/api/projects/$projectId/comments'),
      headers: _headers,
      body: jsonEncode({'message': message}),
    );
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  static Future<Map<String, dynamic>> deleteComment(String id) async {
    final response = await http.delete(
      Uri.parse('$baseUrl/api/comments/$id'),
      headers: _headers,
    );
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  // ---------------------------------------------------------------------------
  // AI PROJECT ASSISTANT
  // ---------------------------------------------------------------------------

  static Future<Map<String, dynamic>> sendAIMessage({
    required String message,
    String? projectId,
  }) async {
    final payload = <String, dynamic>{'message': message};
    if (projectId != null && projectId.isNotEmpty) {
      payload['projectId'] = projectId;
    }

    final response = await http.post(
      Uri.parse('$baseUrl/api/ai/chat'),
      headers: _headers,
      body: jsonEncode(payload),
    );
    return jsonDecode(response.body) as Map<String, dynamic>;
  }
}
