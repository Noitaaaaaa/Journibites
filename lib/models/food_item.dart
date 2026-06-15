import 'dart:convert';

class FoodItem {
  final String name;
  final Map<String, List<String>> tags;
  final List<String> liked;
  final List<String> disliked;

  FoodItem({
    required this.name,
    this.tags = const {},
    this.liked = const [],
    this.disliked = const [],
  });

  List<String> get allTags =>
      tags.values.expand((list) => list).toList();

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'tags': tags,
      'liked': liked,
      'disliked': disliked,
    };
  }

  factory FoodItem.fromMap(Map<String, dynamic> map) {
    final rawTags = map['tags'] as Map? ?? {};
    final parsedTags = rawTags.map(
      (k, v) => MapEntry(k as String, List<String>.from(v as List)),
    );

    return FoodItem(
      name: map['name'] as String,
      tags: parsedTags,
      liked: List<String>.from(map['liked'] as List? ?? []),
      disliked: List<String>.from(map['disliked'] as List? ?? []),
    );
  }

  // Encode a list of FoodItems to a JSON string for DB storage
  static String encodeList(List<FoodItem> items) {
    return jsonEncode(items.map((i) => i.toMap()).toList());
  }

  // Decode a JSON string back to a list of FoodItems
  static List<FoodItem> decodeList(String json) {
    final list = jsonDecode(json) as List;
    return list.map((e) => FoodItem.fromMap(e as Map<String, dynamic>)).toList();
  }

  FoodItem copyWith({
    String? name,
    Map<String, List<String>>? tags,
    List<String>? liked,
    List<String>? disliked,
  }) {
    return FoodItem(
      name: name ?? this.name,
      tags: tags ?? this.tags,
      liked: liked ?? this.liked,
      disliked: disliked ?? this.disliked,
    );
  }
}