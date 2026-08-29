import 'dart:io';
import 'package:mongo_dart/mongo_dart.dart';

/// Singleton database manager.
/// Call [Database.connect] once at startup; then use [Database.instance]
/// anywhere in the app to obtain typed collection references.
class Database {
  static Database? _instance;
  static Db? _db;

  Database._();

  static Database get instance {
    _instance ??= Database._();
    return _instance!;
  }

  /// Reads the MongoDB connection URI from the MONGO_URI environment variable
  /// and opens a persistent connection.
  static Future<void> connect() async {
    final uri = Platform.environment['MONGO_URI'] ??
        'mongodb://localhost:27017/project_management';

    try {
      _db = await Db.create(uri);
      await _db!.open();
      print('[DB] Connected to MongoDB at $uri');
    } catch (e) {
      print('[DB] Failed to connect to MongoDB: $e');
      rethrow;
    }
  }

  /// Returns the raw [Db] instance (for advanced queries).
  static Db get db {
    if (_db == null || !_db!.isConnected) {
      throw StateError('Database not connected. Call Database.connect() first.');
    }
    return _db!;
  }

  // ---------------------------------------------------------------------------
  // Named collection accessors
  // ---------------------------------------------------------------------------

  static DbCollection get users => db.collection('users');
  static DbCollection get projects => db.collection('projects');
  static DbCollection get tasks => db.collection('tasks');
  static DbCollection get milestones => db.collection('milestones');
  static DbCollection get comments => db.collection('comments');

  /// Gracefully closes the database connection.
  static Future<void> close() async {
    await _db?.close();
    print('[DB] Connection closed.');
  }
}
