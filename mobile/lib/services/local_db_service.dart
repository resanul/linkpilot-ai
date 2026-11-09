import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/post_model.dart';

class LocalDbService {
  static final LocalDbService instance = LocalDbService._internal();
  LocalDbService._internal();

  Database? _db;

  Future<Database> get database async {
    if (_db != null) return _db!;
    _db = await _initDb();
    return _db!;
  }

  Future<Database> _initDb() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'linkpilot_local.db');
    return await openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE posts (
            id TEXT PRIMARY KEY,
            client_id TEXT UNIQUE,
            title TEXT,
            topic TEXT,
            body TEXT NOT NULL,
            status TEXT NOT NULL,
            approval_required INTEGER NOT NULL,
            scheduled_at TEXT,
            published_at TEXT,
            linkedin_post_id TEXT,
            error_message TEXT,
            retry_count INTEGER DEFAULT 0,
            created_at TEXT NOT NULL,
            updated_at TEXT,
            is_synced INTEGER DEFAULT 1
          )
        ''');
      },
    );
  }

  Future<void> insertOrUpdatePost(PostModel post) async {
    final db = await database;
    await db.insert(
      'posts',
      post.toSqliteMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<PostModel>> getAllPosts() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'posts',
      orderBy: 'created_at DESC',
    );
    return maps.map((m) => PostModel.fromSqliteMap(m)).toList();
  }

  Future<PostModel?> getPostById(String id) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'posts',
      where: 'id = ? OR client_id = ?',
      whereArgs: [id, id],
      limit: 1,
    );
    if (maps.isNotEmpty) {
      return PostModel.fromSqliteMap(maps.first);
    }
    return null;
  }

  Future<void> deletePost(String id) async {
    final db = await database;
    await db.delete(
      'posts',
      where: 'id = ? OR client_id = ?',
      whereArgs: [id, id],
    );
  }

  Future<List<PostModel>> getUnsyncedPosts() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'posts',
      where: 'is_synced = 0',
    );
    return maps.map((m) => PostModel.fromSqliteMap(m)).toList();
  }

  Future<void> markAsSynced(String id) async {
    final db = await database;
    await db.update(
      'posts',
      {'is_synced': 1},
      where: 'id = ? OR client_id = ?',
      whereArgs: [id, id],
    );
  }

  Future<void> clearAllPosts() async {
    final db = await database;
    await db.delete('posts');
  }
}
