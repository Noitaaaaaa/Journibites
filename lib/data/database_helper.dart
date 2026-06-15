import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('journibites.db');
    return _database!;
  }

  Future<Database> _initDB(String fileName) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, fileName);

    return await openDatabase(
      path,
      version: 5,
      onCreate: _createDB,
      onUpgrade: _upgradeDB,
    );
  }

  Future _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE restaurants (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        address TEXT,
        latitude REAL,
        longitude REAL,
        tags TEXT NOT NULL DEFAULT '{}',
        price_range INTEGER NOT NULL DEFAULT 1,
        is_favorite INTEGER NOT NULL DEFAULT 0
      )
    ''');

    await db.execute('''
      CREATE TABLE journal_entries (
        id TEXT PRIMARY KEY,
        restaurant_id TEXT NOT NULL,
        date TEXT NOT NULL,
        rating REAL NOT NULL,
        sub_ratings TEXT NOT NULL,
        tags TEXT NOT NULL DEFAULT '{}',
        photo_urls TEXT NOT NULL,
        food_items TEXT NOT NULL DEFAULT '[]',
        liked TEXT NOT NULL,
        disliked TEXT NOT NULL,
        notes TEXT NOT NULL,
        would_visit_again INTEGER NOT NULL DEFAULT 1,
        spend_amount REAL,
        FOREIGN KEY (restaurant_id) REFERENCES restaurants (id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE custom_tags (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        tag_type TEXT NOT NULL,
        category TEXT NOT NULL,
        tag TEXT NOT NULL,
        UNIQUE(tag_type, category, tag)
      )
    ''');
  }

  Future _upgradeDB(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute("ALTER TABLE restaurants ADD COLUMN tags TEXT NOT NULL DEFAULT '{}'");
      await db.execute('ALTER TABLE restaurants ADD COLUMN price_range INTEGER NOT NULL DEFAULT 1');
      await db.execute('ALTER TABLE restaurants ADD COLUMN is_favorite INTEGER NOT NULL DEFAULT 0');
      await db.execute("ALTER TABLE journal_entries ADD COLUMN tags TEXT NOT NULL DEFAULT '{}'");
      await db.execute('ALTER TABLE journal_entries ADD COLUMN would_visit_again INTEGER NOT NULL DEFAULT 1');
    }
    if (oldVersion < 3) {
      await db.execute('ALTER TABLE journal_entries ADD COLUMN spend_amount REAL');
    }
    if (oldVersion < 4) {
      await db.execute("ALTER TABLE journal_entries ADD COLUMN food_items TEXT NOT NULL DEFAULT '[]'");
    }
    if (oldVersion < 5) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS custom_tags (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          tag_type TEXT NOT NULL,
          category TEXT NOT NULL,
          tag TEXT NOT NULL,
          UNIQUE(tag_type, category, tag)
        )
      ''');
    }
  }
}