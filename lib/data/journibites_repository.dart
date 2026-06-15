import 'package:flutter/foundation.dart';
import 'database_helper.dart';
import '../models/restaurant.dart';
import '../models/journal_entry.dart';
import 'package:sqflite/sqflite.dart';

final ValueNotifier<int> dataVersionNotifier = ValueNotifier<int>(0);

class JourniBitesRepository {
  final dbHelper = DatabaseHelper.instance;

  // ─── Restaurants ────────────────────────────────────────────────────────────

  Future<List<Restaurant>> getAllRestaurants() async {
    final db = await dbHelper.database;
    final restaurantMaps = await db.query('restaurants');

    final restaurants = <Restaurant>[];
    for (final rMap in restaurantMaps) {
      final entryMaps = await db.query(
        'journal_entries',
        where: 'restaurant_id = ?',
        whereArgs: [rMap['id']],
        orderBy: 'date DESC',
      );
      final entries = entryMaps.map((e) => JournalEntry.fromMap(e)).toList();
      restaurants.add(Restaurant.fromMap(rMap, entries: entries));
    }
    return restaurants;
  }

  Future<Restaurant?> getRestaurantById(String id) async {
    final db = await dbHelper.database;
    final rMaps = await db.query('restaurants', where: 'id = ?', whereArgs: [id]);
    if (rMaps.isEmpty) return null;

    final entryMaps = await db.query(
      'journal_entries',
      where: 'restaurant_id = ?',
      whereArgs: [id],
      orderBy: 'date DESC',
    );
    final entries = entryMaps.map((e) => JournalEntry.fromMap(e)).toList();
    return Restaurant.fromMap(rMaps.first, entries: entries);
  }

  Future<void> insertRestaurant(Restaurant restaurant) async {
    final db = await dbHelper.database;
    await db.insert('restaurants', restaurant.toMap());
  }

  Future<void> updateRestaurant(Restaurant restaurant) async {
    final db = await dbHelper.database;
    await db.update(
      'restaurants',
      restaurant.toMap(),
      where: 'id = ?',
      whereArgs: [restaurant.id],
    );
  }

  Future<void> deleteRestaurant(String id) async {
    final db = await dbHelper.database;
    await db.delete('restaurants', where: 'id = ?', whereArgs: [id]);
  }

  // ─── Journal Entries ─────────────────────────────────────────────────────────

  Future<JournalEntry?> getEntryById(String id) async {
    final db = await dbHelper.database;
    final maps = await db.query('journal_entries', where: 'id = ?', whereArgs: [id]);
    if (maps.isEmpty) return null;
    return JournalEntry.fromMap(maps.first);
  }

  Future<void> insertEntry(JournalEntry entry) async {
    final db = await dbHelper.database;
    try {
      await db.insert('journal_entries', entry.toMap());
    } catch (e) {
      // Try to add missing column and retry once (migration safety net)
      try {
        await db.execute("ALTER TABLE journal_entries ADD COLUMN food_items TEXT NOT NULL DEFAULT '[]'");
        await db.insert('journal_entries', entry.toMap());
      } catch (e2) {
        rethrow;
      }
    }
  }

  Future<void> updateEntry(JournalEntry entry) async {
    final db = await dbHelper.database;
    await db.update(
      'journal_entries',
      entry.toMap(),
      where: 'id = ?',
      whereArgs: [entry.id],
    );
  }

  Future<void> deleteEntry(String id) async {
    final db = await dbHelper.database;
    await db.delete('journal_entries', where: 'id = ?', whereArgs: [id]);
  }

  // ─── Custom Tags ─────────────────────────────────────────────────────────────

  /// [tagType] is either 'restaurant' or 'food'
  Future<Map<String, List<String>>> getCustomTags(String tagType) async {
    final db = await dbHelper.database;
    final rows = await db.query(
      'custom_tags',
      where: 'tag_type = ?',
      whereArgs: [tagType],
      orderBy: 'category, tag',
    );

    final result = <String, List<String>>{};
    for (final row in rows) {
      final category = row['category'] as String;
      final tag = row['tag'] as String;
      result.putIfAbsent(category, () => []).add(tag);
    }
    return result;
  }

  Future<void> insertCustomTag(String tagType, String category, String tag) async {
    final db = await dbHelper.database;
    await db.insert(
      'custom_tags',
      {'tag_type': tagType, 'category': category, 'tag': tag},
      conflictAlgorithm: ConflictAlgorithm.ignore, // no duplicates
    );
  }

  Future<void> deleteCustomTag(String tagType, String category, String tag) async {
    final db = await dbHelper.database;
    await db.delete(
      'custom_tags',
      where: 'tag_type = ? AND category = ? AND tag = ?',
      whereArgs: [tagType, category, tag],
    );
  }
}