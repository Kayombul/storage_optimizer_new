import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/file_metadata.dart';
import '../models/storage_snapshot.dart';

class DatabaseService {
  static final DatabaseService instance = DatabaseService._();
  DatabaseService._();

  Database? _db;

  Future<Database> get database async {
    return _db ??= await _initDb();
  }

  Future<Database> _initDb() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'storage_optimizer.db');
    return openDatabase(
      path,
      version: 1,
      onCreate: (db, _) async {
        await db.execute('''
          CREATE TABLE file_metadata (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            path TEXT UNIQUE NOT NULL,
            name TEXT NOT NULL,
            sizeBytes INTEGER NOT NULL,
            fileType TEXT NOT NULL,
            createdAt INTEGER NOT NULL,
            lastAccessedAt INTEGER NOT NULL,
            accessCount INTEGER NOT NULL DEFAULT 1,
            valueScore REAL NOT NULL DEFAULT 0.0,
            isRecommendedForDeletion INTEGER NOT NULL DEFAULT 0,
            scoreReason TEXT NOT NULL DEFAULT ''
          )
        ''');
        await db.execute('''
          CREATE TABLE storage_snapshots (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            timestamp INTEGER NOT NULL,
            totalBytes INTEGER NOT NULL,
            usedBytes INTEGER NOT NULL,
            freeBytes INTEGER NOT NULL
          )
        ''');
      },
    );
  }

  Future<void> upsertAllFiles(List<FileMetadata> files) async {
    final db = await database;
    final batch = db.batch();
    for (final f in files) {
      batch.insert(
        'file_metadata',
        f.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    await batch.commit(noResult: true);
  }

  Future<List<FileMetadata>> getAllFiles() async {
    final db = await database;
    final maps =
        await db.query('file_metadata', orderBy: 'valueScore ASC');
    return maps.map(FileMetadata.fromMap).toList();
  }

  Future<int> getFileCount() async {
    final db = await database;
    final result =
        await db.rawQuery('SELECT COUNT(*) as count FROM file_metadata');
    return (result.first['count'] as int?) ?? 0;
  }

  Future<int> getRecommendedCount() async {
    final db = await database;
    final result = await db.rawQuery(
        'SELECT COUNT(*) as count FROM file_metadata WHERE isRecommendedForDeletion = 1');
    return (result.first['count'] as int?) ?? 0;
  }

  Future<void> deleteFileById(int id) async {
    final db = await database;
    await db.delete('file_metadata', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> clearFileMetadata() async {
    final db = await database;
    await db.delete('file_metadata');
  }

  Future<void> insertSnapshot(StorageSnapshot snapshot) async {
    final db = await database;
    await db.insert('storage_snapshots', snapshot.toMap());
  }

  /// Returns the most recent [limit] snapshots, oldest first.
  ///
  /// Ordering ASC before applying the limit would return the *oldest* rows once
  /// the table grows past [limit], so the forecast would be computed from stale
  /// history and stop reacting to current usage. Take the newest rows first,
  /// then flip them back into chronological order for the regression.
  Future<List<StorageSnapshot>> getSnapshots({int limit = 90}) async {
    final db = await database;
    final maps = await db.query(
      'storage_snapshots',
      orderBy: 'timestamp DESC',
      limit: limit,
    );
    return maps.reversed.map(StorageSnapshot.fromMap).toList();
  }

  Future<StorageSnapshot?> getLatestSnapshot() async {
    final db = await database;
    final maps = await db
        .query('storage_snapshots', orderBy: 'timestamp DESC', limit: 1);
    if (maps.isEmpty) return null;
    return StorageSnapshot.fromMap(maps.first);
  }

  Future<void> pruneOldSnapshots({int keepDays = 90}) async {
    final db = await database;
    final cutoff = DateTime.now()
        .subtract(Duration(days: keepDays))
        .millisecondsSinceEpoch;
    await db.delete('storage_snapshots',
        where: 'timestamp < ?', whereArgs: [cutoff]);
  }
}
