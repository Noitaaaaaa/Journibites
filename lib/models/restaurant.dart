import 'dart:convert';
import 'dart:math';
import 'journal_entry.dart';

class Restaurant {
  final String id;
  final String name;
  final String? address;
  final double? latitude;
  final double? longitude;
  final Map<String, List<String>> tags;
  final int priceRange; // 1=₱, 2=₱₱, 3=₱₱₱, 4=₱₱₱₱
  final bool isFavorite;
  final List<JournalEntry> entries;

  Restaurant({
    required this.id,
    required this.name,
    this.address,
    this.latitude,
    this.longitude,
    this.tags = const {},
    this.priceRange = 1,
    this.isFavorite = false,
    this.entries = const [],
  });

  double get averageRating {
    if (entries.isEmpty) return 0;
    return entries.map((e) => e.rating).reduce((a, b) => a + b) / entries.length;
  }

  int get visitCount => entries.length;

  JournalEntry? get mostRecentEntry {
    if (entries.isEmpty) return null;
    return entries.reduce((a, b) => a.date.isAfter(b.date) ? a : b);
  }

  String get priceRangeLabel => '₱' * priceRange;

  List<String> get allTags =>
      tags.values.expand((list) => list).toList();

  // Entries that have a spend amount recorded
  List<double> get _spends =>
      entries.map((e) => e.spendAmount).whereType<double>().toList();

  // Lowest spend rounded DOWN to nearest hundred
  double? get minSpend {
    if (_spends.isEmpty) return null;
    final lowest = _spends.reduce(min);
    return (lowest / 100).floor() * 100;
  }

  // Highest spend rounded UP to nearest hundred
  double? get maxSpend {
    if (_spends.isEmpty) return null;
    final highest = _spends.reduce(max);
    return (highest / 100).ceil() * 100;
  }

  // Display string e.g. "₱100 – ₱500" or null if no spend data
  String? get spendRangeLabel {
    if (minSpend == null || maxSpend == null) return null;
    if (minSpend == maxSpend) return '~₱${minSpend!.toInt()}';
    return '₱${minSpend!.toInt()} – ₱${maxSpend!.toInt()}';
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'address': address,
      'latitude': latitude,
      'longitude': longitude,
      'tags': jsonEncode(tags),
      'price_range': priceRange,
      'is_favorite': isFavorite ? 1 : 0,
    };
  }

  factory Restaurant.fromMap(
    Map<String, dynamic> map, {
    List<JournalEntry> entries = const [],
  }) {
    final rawTags = map['tags'];
    Map<String, List<String>> parsedTags = {};
    if (rawTags != null) {
      final decoded = jsonDecode(rawTags as String) as Map;
      parsedTags = decoded.map(
        (k, v) => MapEntry(k as String, List<String>.from(v as List)),
      );
    }

    return Restaurant(
      id: map['id'] as String,
      name: map['name'] as String,
      address: map['address'] as String?,
      latitude: map['latitude'] as double?,
      longitude: map['longitude'] as double?,
      tags: parsedTags,
      priceRange: (map['price_range'] as int?) ?? 1,
      isFavorite: ((map['is_favorite'] as int?) ?? 0) == 1,
      entries: entries,
    );
  }

  Restaurant copyWith({
    String? name,
    String? address,
    double? latitude,
    double? longitude,
    Map<String, List<String>>? tags,
    int? priceRange,
    bool? isFavorite,
    List<JournalEntry>? entries,
  }) {
    return Restaurant(
      id: id,
      name: name ?? this.name,
      address: address ?? this.address,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      tags: tags ?? this.tags,
      priceRange: priceRange ?? this.priceRange,
      isFavorite: isFavorite ?? this.isFavorite,
      entries: entries ?? this.entries,
    );
  }
}