import 'dart:io';
import 'package:bcrypt/bcrypt.dart';
import 'package:dart_jsonwebtoken/dart_jsonwebtoken.dart';
import 'package:mongo_dart/mongo_dart.dart';

import '../config/database.dart';
import '../models/user.dart';

/// Handles user registration, login, and JWT generation.
class AuthService {
  static String get _jwtSecret =>
      Platform.environment['JWT_SECRET'] ?? 'default_jwt_secret_change_me';

  // ---------------------------------------------------------------------------
  // Register  POST /api/auth/register
  // ---------------------------------------------------------------------------

  static Future<Map<String, dynamic>> register(
      Map<String, dynamic> body) async {
    final name = body['name']?.toString().trim();
    final email = body['email']?.toString().trim().toLowerCase();
    final password = body['password']?.toString();

    // --- Validation ---
    if (name == null || name.isEmpty) {
      return _error(400, 'Name is required.');
    }
    if (email == null || email.isEmpty) {
      return _error(400, 'Email is required.');
    }
    if (!_isValidEmail(email)) {
      return _error(400, 'Invalid email address.');
    }
    if (password == null || password.length < 6) {
      return _error(400, 'Password must be at least 6 characters.');
    }

    // --- Duplicate check ---
    final existing =
        await Database.users.findOne(where.eq('email', email));
    if (existing != null) {
      return _error(409, 'An account with this email already exists.');
    }

    // --- Hash password ---
    final hashedPassword = BCrypt.hashpw(password, BCrypt.gensalt());

    final user = User(
      name: name,
      email: email,
      password: hashedPassword,
    );

    final result = await Database.users.insertOne(user.toMap());
    final insertedOid = result.id as ObjectId;
    final insertedId = insertedOid.oid;

    final token = _generateToken(insertedId, email);

    return {
      'statusCode': 201,
      'body': {
        'success': true,
        'message': 'User registered successfully.',
        'data': {
          'token': token,
          'user': {
            'id': insertedId,
            'name': name,
            'email': email,
            'createdAt': user.createdAt.toIso8601String(),
          },
        },
      },
    };
  }

  // ---------------------------------------------------------------------------
  // Login  POST /api/auth/login
  // ---------------------------------------------------------------------------

  static Future<Map<String, dynamic>> login(Map<String, dynamic> body) async {
    final email = body['email']?.toString().trim().toLowerCase();
    final password = body['password']?.toString();

    if (email == null || email.isEmpty) {
      return _error(400, 'Email is required.');
    }
    if (password == null || password.isEmpty) {
      return _error(400, 'Password is required.');
    }

    final doc = await Database.users.findOne(where.eq('email', email));
    if (doc == null) {
      return _error(401, 'Invalid email or password.');
    }

    final storedHash = doc['password'] as String? ?? '';
    final isValid = BCrypt.checkpw(password, storedHash);
    if (!isValid) {
      return _error(401, 'Invalid email or password.');
    }

    final user = User.fromMap(doc);
    final token = _generateToken(user.id!, user.email);

    return {
      'statusCode': 200,
      'body': {
        'success': true,
        'message': 'Login successful.',
        'data': {
          'token': token,
          'user': user.toJson(),
        },
      },
    };
  }

  // ---------------------------------------------------------------------------
  // JWT helpers
  // ---------------------------------------------------------------------------

  static String _generateToken(String userId, String email) {
    final jwt = JWT(
      {
        'userId': userId,
        'email': email,
      },
      issuer: 'project-management-api',
    );
    // Token valid for 7 days
    return jwt.sign(
      SecretKey(_jwtSecret),
      expiresIn: const Duration(days: 7),
    );
  }

  /// Verifies a JWT from the Authorization header.
  /// Returns the decoded payload map or null on failure.
  static Map<String, dynamic>? verifyToken(String? authHeader) {
    if (authHeader == null || !authHeader.startsWith('Bearer ')) return null;
    final token = authHeader.substring(7);
    try {
      final jwt = JWT.verify(token, SecretKey(_jwtSecret));
      return jwt.payload as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  // ---------------------------------------------------------------------------
  // Internal helpers
  // ---------------------------------------------------------------------------

  static bool _isValidEmail(String email) {
    return RegExp(r'^[\w.+-]+@[\w-]+\.[a-zA-Z]{2,}$').hasMatch(email);
  }

  static Map<String, dynamic> _error(int statusCode, String message) {
    return {
      'statusCode': statusCode,
      'body': {'success': false, 'message': message},
    };
  }
}
