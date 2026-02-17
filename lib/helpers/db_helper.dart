import 'package:dev_scanner/models/scan_history_model.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

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
            code TEXT,
            type TEXT,
            date TEXT,
            product TEXT
          )
        ''');
      },
    );
  }

  Future<int> insertScan(ScanHistoryModel scan) async {
    final db = await database;
    return await db.insert('scan_history', scan.toMap());
  }

  Future<List<ScanHistoryModel>> getScans() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'scan_history',
      orderBy: 'id DESC',
    );
    return List.generate(maps.length, (i) => ScanHistoryModel.fromMap(maps[i]));
  }
  Future<int> deleteScan(ScanHistoryModel scan) async {
    final db = await database;
    return await db.delete(
      'scan_history',
      where: 'code = ? AND date = ?',
      whereArgs: [scan.code, scan.date],
    );
  }

  Future<int> clearScans() async {
    final db = await database;
    return await db.delete('scan_history');
  }

}
