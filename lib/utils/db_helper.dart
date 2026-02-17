import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/scan_history_model.dart';

class DBHelper {
  static final DBHelper _instance = DBHelper._internal();
  factory DBHelper() => _instance;
  DBHelper._internal();

  static Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB();
    return _database!;
  }

  Future<Database> _initDB() async {
    String dbPath = await getDatabasesPath();
    String path = join(dbPath, 'scan_history.db');
    return await openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE scan_history(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            code TEXT NOT NULL,
            type TEXT NOT NULL,
            date TEXT NOT NULL,
            product TEXT
          )
        ''');
      },
    );
  }

  // Insert a new scan
  Future<int> insertScan(ScanHistoryModel scan) async {
    final db = await database;
    return await db.insert('scan_history', {
      'code': scan.code,
      'type': scan.type,
      'date': scan.date,
      'product': scan.product,
    });
  }

  // Get all scans
  Future<List<ScanHistoryModel>> getScans() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'scan_history',
      orderBy: 'id DESC',
    );
    return List.generate(maps.length, (i) => ScanHistoryModel.fromMap(maps[i]));
  }

  // Delete a specific scan
  Future<int> deleteScan(int id) async {
    final db = await database;
    return await db.delete(
      'scan_history',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // Clear all scans
  Future<int> clearAllScans() async {
    final db = await database;
    return await db.delete('scan_history');
  }

  // Get scan count
  Future<int> getScanCount() async {
    final db = await database;
    final result = await db.rawQuery('SELECT COUNT(*) FROM scan_history');
    return Sqflite.firstIntValue(result) ?? 0;
  }

  // Search scans by code or product
  Future<List<ScanHistoryModel>> searchScans(String query) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'scan_history',
      where: 'code LIKE ? OR product LIKE ?',
      whereArgs: ['%$query%', '%$query%'],
      orderBy: 'id DESC',
    );
    return List.generate(maps.length, (i) => ScanHistoryModel.fromMap(maps[i]));
  }
}