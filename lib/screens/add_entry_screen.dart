import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';
import '../data/journibites_repository.dart';
import '../models/journal_entry.dart';
import '../models/food_item.dart';
import '../models/restaurant.dart';
import '../widgets/tag_selector.dart';
import '../widgets/food_item_cart.dart';
import 'package:go_router/go_router.dart';
import '../data/tag_definitions.dart';

class AddEntryScreen extends StatefulWidget {
  final String? restaurantId;
  final String? restaurantName;

  const AddEntryScreen({
    super.key,
    this.restaurantId,
    this.restaurantName,
  });

  @override
  State<AddEntryScreen> createState() => _AddEntryScreenState();
}

class _SubRatingItem {
  final TextEditingController nameController;
  double value;
  _SubRatingItem(String name, this.value)
      : nameController = TextEditingController(text: name);
}

class _FoodItemData {
  String name;
  Map<String, List<String>> tags;
  List<String> liked;
  List<String> disliked;

  _FoodItemData({
    this.name = '',
    this.tags = const {},
    this.liked = const [],
    this.disliked = const [],
  });

  FoodItem toFoodItem() => FoodItem(
        name: name,
        tags: tags,
        liked: liked,
        disliked: disliked,
      );
}

class _AddEntryScreenState extends State<AddEntryScreen> {
  final _repository = JourniBitesRepository();
  static const _uuid = Uuid();
  final _picker = ImagePicker();

  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  List<Restaurant> _allRestaurants = [];
  bool _loadingRestaurants = true;
  Restaurant? _selectedRestaurant;

  final _notesController = TextEditingController();
  final _spendController = TextEditingController();

  List<_SubRatingItem> _subRatings = [
    _SubRatingItem('Taste', 5),
    _SubRatingItem('Ambiance', 5),
    _SubRatingItem('Staff', 5),
  ];

  List<TextEditingController> _likedControllers = [TextEditingController()];
  List<TextEditingController> _dislikedControllers = [TextEditingController()];

  // Food items with stable keys to prevent widget disposal bugs
  List<_FoodItemData> _foodItems = [_FoodItemData()];
  List<String> _foodItemKeys = [const Uuid().v4()];

  Map<String, List<String>> _selectedTags = {};
  List<String> _photoPaths = [];
  DateTime _selectedDate = DateTime.now();
  double _rating = 3.0;
  bool _wouldVisitAgain = true;
  bool _saving = false;

  bool get _hasPreselectedRestaurant => widget.restaurantId != null;

  @override
  void initState() {
    super.initState();
    if (!_hasPreselectedRestaurant) {
      _loadRestaurants();
    } else {
      _loadingRestaurants = false;
    }
  }

  Future<void> _loadRestaurants() async {
    final restaurants = await _repository.getAllRestaurants();
    if (!mounted) return;
    setState(() {
      _allRestaurants = restaurants;
      _loadingRestaurants = false;
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _notesController.dispose();
    _spendController.dispose();
    for (final c in _likedControllers) { c.dispose(); }
    for (final c in _dislikedControllers) { c.dispose(); }
    for (final s in _subRatings) { s.nameController.dispose(); }
    super.dispose();
  }

  List<Restaurant> get _filteredRestaurants {
    if (_searchQuery.isEmpty) return [];
    return _allRestaurants
        .where((r) => r.name.toLowerCase().contains(_searchQuery.toLowerCase()))
        .toList();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked != null) setState(() => _selectedDate = picked);
  }

  void _showAddPhotoOptions() {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Wrap(children: [
          ListTile(
            leading: const Icon(Icons.photo_camera),
            title: const Text('Take Photo'),
            onTap: () { Navigator.pop(context); _pickImage(ImageSource.camera); },
          ),
          ListTile(
            leading: const Icon(Icons.photo_library),
            title: const Text('Choose from Gallery'),
            onTap: () { Navigator.pop(context); _pickImage(ImageSource.gallery); },
          ),
        ]),
      ),
    );
  }

  Future<void> _pickImage(ImageSource source) async {
    final pickedFile = await _picker.pickImage(source: source, imageQuality: 80);
    if (pickedFile == null) return;
    final appDir = await getApplicationDocumentsDirectory();
    final fileName = '${_uuid.v4()}${p.extension(pickedFile.path)}';
    final savedPath = p.join(appDir.path, fileName);
    await File(pickedFile.path).copy(savedPath);
    if (!mounted) return;
    setState(() => _photoPaths.add(savedPath));
  }

  void _removePhoto(int index) => setState(() => _photoPaths.removeAt(index));
  void _addSubRating() => setState(() => _subRatings.add(_SubRatingItem('', 5)));
  void _removeSubRating(int index) {
    setState(() { _subRatings[index].nameController.dispose(); _subRatings.removeAt(index); });
  }
  void _addLiked() => setState(() => _likedControllers.add(TextEditingController()));
  void _removeLiked(int index) {
    setState(() { _likedControllers[index].dispose(); _likedControllers.removeAt(index); });
  }
  void _addDisliked() => setState(() => _dislikedControllers.add(TextEditingController()));
  void _removeDisliked(int index) {
    setState(() { _dislikedControllers[index].dispose(); _dislikedControllers.removeAt(index); });
  }

  Future<void> _saveEntry() async {
    final restaurantId = widget.restaurantId ?? _selectedRestaurant?.id;
    final restaurantName = widget.restaurantName ?? _selectedRestaurant?.name;

    if (restaurantId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a restaurant first.')),
      );
      return;
    }

    setState(() => _saving = true);

    final subRatings = <String, double>{
      for (final item in _subRatings)
        if (item.nameController.text.trim().isNotEmpty)
          item.nameController.text.trim(): item.value
    };

    final liked = _likedControllers.map((c) => c.text.trim()).where((s) => s.isNotEmpty).toList();
    final disliked = _dislikedControllers.map((c) => c.text.trim()).where((s) => s.isNotEmpty).toList();
    final foodItems = _foodItems
        .where((f) => f.name.isNotEmpty)
        .map((f) => f.toFoodItem())
        .toList();

    final entry = JournalEntry(
      id: _uuid.v4(),
      restaurantId: restaurantId,
      date: _selectedDate,
      rating: _rating,
      subRatings: subRatings,
      tags: _selectedTags,
      photoUrls: _photoPaths,
      foodItems: foodItems,
      liked: liked,
      disliked: disliked,
      notes: _notesController.text.trim(),
      wouldVisitAgain: _wouldVisitAgain,
      spendAmount: double.tryParse(_spendController.text.trim()),
    );

    await _repository.insertEntry(entry);
    dataVersionNotifier.value++;

    if (!mounted) return;
    setState(() => _saving = false);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Saved entry for "$restaurantName"!')),
    );
    context.go('/');
  }

  @override
  Widget build(BuildContext context) {
    if (!_hasPreselectedRestaurant && _selectedRestaurant == null) {
      return _buildSearchStep();
    }
    return _buildEntryForm();
  }

  Widget _buildSearchStep() {
    return Scaffold(
      appBar: AppBar(title: const Text('Select Restaurant')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Which restaurant did you revisit?',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            TextField(
              controller: _searchController,
              decoration: const InputDecoration(
                hintText: 'Search saved restaurants...',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
              onChanged: (v) => setState(() => _searchQuery = v),
            ),
            const SizedBox(height: 16),
            if (_loadingRestaurants)
              const Expanded(child: Center(child: CircularProgressIndicator()))
            else
              Expanded(
                child: _searchQuery.isEmpty
                    ? const Center(
                        child: Text('Start typing to search...',
                            style: TextStyle(color: Colors.grey)))
                    : _filteredRestaurants.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Text('No matches found.',
                                    style: TextStyle(color: Colors.grey)),
                                const SizedBox(height: 12),
                                TextButton.icon(
                                  icon: const Icon(Icons.add_business),
                                  label: const Text('Add as new restaurant instead'),
                                  onPressed: () => context.push('/new-restaurant'),
                                ),
                              ],
                            ),
                          )
                        : ListView(
                            children: _filteredRestaurants
                                .map((r) => Card(
                                      child: ListTile(
                                        leading: const Icon(Icons.restaurant),
                                        title: Text(r.name),
                                        subtitle: r.address != null ? Text(r.address!) : null,
                                        trailing: Text('Visited ${r.visitCount}x'),
                                        onTap: () => setState(() => _selectedRestaurant = r),
                                      ),
                                    ))
                                .toList(),
                          ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildEntryForm() {
    final title = widget.restaurantName ?? _selectedRestaurant?.name ?? 'New Entry';

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (_hasPreselectedRestaurant) {
              context.pop();
            } else {
              setState(() => _selectedRestaurant = null);
            }
          },
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Date
          const Text('Date', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          OutlinedButton.icon(
            onPressed: _pickDate,
            icon: const Icon(Icons.calendar_today),
            label: Text('${_selectedDate.month}/${_selectedDate.day}/${_selectedDate.year}'),
          ),
          const SizedBox(height: 20),

          // Photos
          const Text('Photos', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          SizedBox(
            height: 100,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                ..._photoPaths.asMap().entries.map((e) => Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: Stack(children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.file(File(e.value),
                              width: 100, height: 100, fit: BoxFit.cover),
                        ),
                        Positioned(
                          top: 2, right: 2,
                          child: GestureDetector(
                            onTap: () => _removePhoto(e.key),
                            child: Container(
                              padding: const EdgeInsets.all(2),
                              decoration: const BoxDecoration(
                                  color: Colors.black54, shape: BoxShape.circle),
                              child: const Icon(Icons.close, color: Colors.white, size: 16),
                            ),
                          ),
                        ),
                      ]),
                    )),
                GestureDetector(
                  onTap: _showAddPhotoOptions,
                  child: Container(
                    width: 100, height: 100,
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.add_a_photo, color: Colors.grey),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Overall rating
          const Text('Overall Rating', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Row(
            children: List.generate(5, (index) {
              final val = index + 1;
              return IconButton(
                icon: Icon(
                  val <= _rating ? Icons.star : Icons.star_border,
                  color: Colors.amber, size: 32,
                ),
                onPressed: () => setState(() => _rating = val.toDouble()),
              );
            }),
          ),
          const SizedBox(height: 8),

          // Would visit again
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Would visit again',
                style: TextStyle(fontWeight: FontWeight.bold)),
            value: _wouldVisitAgain,
            onChanged: (v) => setState(() => _wouldVisitAgain = v),
          ),
          const SizedBox(height: 8),

          // Spend
          TextField(
            controller: _spendController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'How much did you spend? (optional)',
              border: OutlineInputBorder(),
              prefixText: '₱ ',
            ),
          ),
          const SizedBox(height: 20),

          // Sub-ratings
          const Text('Rate Specific Aspects',
              style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          ...List.generate(_subRatings.length, (index) {
            final item = _subRatings[index];
            return Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Expanded(
                    child: TextField(
                      controller: item.nameController,
                      decoration: const InputDecoration(
                        hintText: 'Category (e.g. Taste)',
                        isDense: true,
                        border: UnderlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  SizedBox(
                    width: 36,
                    child: Text(item.value.toStringAsFixed(1),
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                  ),
                  IconButton(
                    icon: const Icon(Icons.remove_circle_outline, size: 20),
                    onPressed: () => _removeSubRating(index),
                  ),
                ]),
                Slider(
                  value: item.value, min: 0, max: 10, divisions: 10,
                  label: item.value.toStringAsFixed(1),
                  onChanged: (v) => setState(() => item.value = v),
                ),
              ]),
            );
          }),
          TextButton.icon(
            onPressed: _addSubRating,
            icon: const Icon(Icons.add),
            label: const Text('Add category'),
          ),
          const SizedBox(height: 20),

          // Food items section
          const Text('Food Items', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 8),
          ...List.generate(_foodItems.length, (index) {
            final data = _foodItems[index];
            return FoodItemCard(
              key: ValueKey(_foodItemKeys[index]), // stable key, not index
              index: index,
              initialName: data.name,
              initialTags: data.tags,
              initialLiked: data.liked,
              initialDisliked: data.disliked,
              onRemove: _foodItems.length > 1
                  ? () => setState(() {
                        _foodItems.removeAt(index);
                        _foodItemKeys.removeAt(index);
                      })
                  : () {},
              onNameChanged: (v) => _foodItems[index].name = v,
              onTagsChanged: (v) => _foodItems[index].tags = v,
              onLikedChanged: (v) => _foodItems[index].liked = v,
              onDislikedChanged: (v) => _foodItems[index].disliked = v,
            );
          }),
          OutlinedButton.icon(
            onPressed: () => setState(() {
              _foodItems.add(_FoodItemData());
              _foodItemKeys.add(const Uuid().v4());
            }),
            icon: const Icon(Icons.add),
            label: const Text('Add Food Item'),
          ),
          const SizedBox(height: 20),

          // Overall liked/disliked
          const Text('Overall Visit',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 8),
          const Text('Liked',
              style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green)),
          const SizedBox(height: 4),
          ...List.generate(_likedControllers.length, (index) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(children: [
                  Expanded(
                    child: TextField(
                      controller: _likedControllers[index],
                      decoration: const InputDecoration(
                        hintText: 'e.g. Great vibe',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.thumb_up_outlined, color: Colors.green),
                      ),
                    ),
                  ),
                  if (_likedControllers.length > 1)
                    IconButton(
                      icon: const Icon(Icons.remove_circle_outline),
                      onPressed: () => _removeLiked(index),
                    ),
                ]),
              )),
          TextButton.icon(
            onPressed: _addLiked,
            icon: const Icon(Icons.add),
            label: const Text('Add another'),
          ),
          const SizedBox(height: 8),
          const Text('Disliked',
              style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red)),
          const SizedBox(height: 4),
          ...List.generate(_dislikedControllers.length, (index) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(children: [
                  Expanded(
                    child: TextField(
                      controller: _dislikedControllers[index],
                      decoration: const InputDecoration(
                        hintText: 'e.g. Noisy environment',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.thumb_down_outlined, color: Colors.red),
                      ),
                    ),
                  ),
                  if (_dislikedControllers.length > 1)
                    IconButton(
                      icon: const Icon(Icons.remove_circle_outline),
                      onPressed: () => _removeDisliked(index),
                    ),
                ]),
              )),
          TextButton.icon(
            onPressed: _addDisliked,
            icon: const Icon(Icons.add),
            label: const Text('Add another'),
          ),
          const SizedBox(height: 16),

          // Entry-level tags
          TagSelector(
            tagType: 'restaurant',
            sectionTitle: '🍽️ Visit Tags',
            categories: restaurantTagCategories,
            selected: _selectedTags,
            onChanged: (updated) => setState(() => _selectedTags = updated),
          ),
          const SizedBox(height: 16),

          // Notes
          TextField(
            controller: _notesController,
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: 'Notes',
              border: OutlineInputBorder(),
              alignLabelWithHint: true,
            ),
          ),
          const SizedBox(height: 24),

          // Save
          ElevatedButton(
            onPressed: _saving ? null : _saveEntry,
            style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14)),
            child: _saving
                ? const SizedBox(
                    height: 20, width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('Save Entry', style: TextStyle(fontSize: 16)),
          ),
        ],
      ),
    );
  }
}