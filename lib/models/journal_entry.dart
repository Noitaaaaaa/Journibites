import 'dart:convert';
import 'food_item.dart';

class JournalEntry {
  final String id;
  final String restaurantId;
  final DateTime date;
  final double rating;
  final Map<String, double> subRatings;
  final Map<String, List<String>> tags;
  final List<String> photoUrls;
  final List<FoodItem> foodItems; // replaces whatIOrdered
  final List<String> liked;
  final List<String> disliked;
  final String notes;
  final bool wouldVisitAgain;
  final double? spendAmount;

  JournalEntry({
    required this.id,
    required this.restaurantId,
    required this.date,
    required this.rating,
    this.subRatings = const {},
    this.tags = const {},
    this.photoUrls = const [],
    this.foodItems = const [],
    this.liked = const [],
    this.disliked = const [],
    this.notes = '',
    this.wouldVisitAgain = true,
    this.spendAmount,
  });

  List<String> get allTags =>
      tags.values.expand((list) => list).toList();

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'restaurant_id': restaurantId,
      'date': date.toIso8601String(),
      'rating': rating,
      'sub_ratings': jsonEncode(subRatings),
      'tags': jsonEncode(tags),
      'photo_urls': jsonEncode(photoUrls),
      'food_items': FoodItem.encodeList(foodItems),
      'liked': jsonEncode(liked),
      'disliked': jsonEncode(disliked),
      'notes': notes,
      'would_visit_again': wouldVisitAgain ? 1 : 0,
      'spend_amount': spendAmount,
    };
  }

  factory JournalEntry.fromMap(Map<String, dynamic> map) {
    final rawTags = map['tags'];
    Map<String, List<String>> parsedTags = {};
    if (rawTags != null) {
      final decoded = jsonDecode(rawTags as String) as Map;
      parsedTags = decoded.map(
        (k, v) => MapEntry(k as String, List<String>.from(v as List)),
      );
    }

    // Support both old what_i_ordered (string) and new food_items (JSON list)
    List<FoodItem> foodItems = [];
    final rawFoodItems = map['food_items'];
    final rawWhatIOrdered = map['what_i_ordered'];
    if (rawFoodItems != null && (rawFoodItems as String).isNotEmpty && rawFoodItems != '[]') {
      foodItems = FoodItem.decodeList(rawFoodItems);
    } else if (rawWhatIOrdered != null && (rawWhatIOrdered as String).isNotEmpty) {
      // Migrate old single-string orders into a single FoodItem
      foodItems = [FoodItem(name: rawWhatIOrdered)];
    }

    return JournalEntry(
      id: map['id'] as String,
      restaurantId: map['restaurant_id'] as String,
      date: DateTime.parse(map['date'] as String),
      rating: (map['rating'] as num).toDouble(),
      subRatings: Map<String, double>.from(
        (jsonDecode(map['sub_ratings'] as String) as Map).map(
          (k, v) => MapEntry(k as String, (v as num).toDouble()),
        ),
      ),
      tags: parsedTags,
      photoUrls: List<String>.from(
        jsonDecode(map['photo_urls'] as String) as List,
      ),
      foodItems: foodItems,
      liked: List<String>.from(jsonDecode(map['liked'] as String) as List),
      disliked: List<String>.from(jsonDecode(map['disliked'] as String) as List),
      notes: map['notes'] as String,
      wouldVisitAgain: ((map['would_visit_again'] as int?) ?? 1) == 1,
      spendAmount: map['spend_amount'] as double?,
    );
  }

  JournalEntry copyWith({
    DateTime? date,
    double? rating,
    Map<String, double>? subRatings,
    Map<String, List<String>>? tags,
    List<String>? photoUrls,
    List<FoodItem>? foodItems,
    List<String>? liked,
    List<String>? disliked,
    String? notes,
    bool? wouldVisitAgain,
    double? spendAmount,
  }) {
    return JournalEntry(
      id: id,
      restaurantId: restaurantId,
      date: date ?? this.date,
      rating: rating ?? this.rating,
      subRatings: subRatings ?? this.subRatings,
      tags: tags ?? this.tags,
      photoUrls: photoUrls ?? this.photoUrls,
      foodItems: foodItems ?? this.foodItems,
      liked: liked ?? this.liked,
      disliked: disliked ?? this.disliked,
      notes: notes ?? this.notes,
      wouldVisitAgain: wouldVisitAgain ?? this.wouldVisitAgain,
      spendAmount: spendAmount ?? this.spendAmount,
    );
  }
}