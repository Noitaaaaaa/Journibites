import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import '../data/journibites_repository.dart';
import '../data/tag_definitions.dart';
import '../models/restaurant.dart';
import '../widgets/restaurant_card.dart';

enum SortOption { name, rating, mostVisited, mostRecent }

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _repository = JourniBitesRepository();
  final _searchController = TextEditingController();

  List<Restaurant> _allRestaurants = [];
  bool _loading = true;

  // Search
  String _searchQuery = '';

  // Sort
  SortOption _sortOption = SortOption.name;

  // Filters
  Set<int> _selectedPriceRanges = {};
  double? _minSpend;
  double? _maxSpend;
  Set<String> _selectedDiningTypes = {};
  Set<String> _selectedCuisines = {};
  Set<String> _selectedDietaryPrefs = {};

  int get _activeFilterCount =>
      _selectedPriceRanges.length +
      (_minSpend != null || _maxSpend != null ? 1 : 0) +
      _selectedDiningTypes.length +
      _selectedCuisines.length +
      _selectedDietaryPrefs.length;

  @override
  void initState() {
    super.initState();
    _loadData();
    dataVersionNotifier.addListener(_loadData);
    _searchController.addListener(() {
      setState(() => _searchQuery = _searchController.text.trim().toLowerCase());
    });
  }

  @override
  void dispose() {
    dataVersionNotifier.removeListener(_loadData);
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    final restaurants = await _repository.getAllRestaurants();
    if (!mounted) return;
    setState(() {
      _allRestaurants = restaurants;
      _loading = false;
    });
  }

  // Returns matched food item names per restaurant id (only populated during food searches)
  Map<String, List<String>> get _foodMatchMap {
    if (_searchQuery.isEmpty) return {};
    final result = <String, List<String>>{};
    for (final r in _allRestaurants) {
      if (r.name.toLowerCase().contains(_searchQuery)) continue;
      final matched = <String>{};
      for (final entry in r.entries) {
        for (final food in entry.foodItems) {
          if (food.name.toLowerCase().contains(_searchQuery)) {
            matched.add(food.name);
          }
        }
      }
      if (matched.isNotEmpty) result[r.id] = matched.toList();
    }
    return result;
  }

  List<Restaurant> get _filteredAndSorted {
    var list = List<Restaurant>.from(_allRestaurants);

    // Search — match restaurant name OR any food item name across entries
    if (_searchQuery.isNotEmpty) {
      list = list.where((r) {
        if (r.name.toLowerCase().contains(_searchQuery)) return true;
        return r.entries.any((e) =>
            e.foodItems.any((f) => f.name.toLowerCase().contains(_searchQuery)));
      }).toList();
    }

    // Price range chips
    if (_selectedPriceRanges.isNotEmpty) {
      list = list.where((r) => _selectedPriceRanges.contains(r.priceRange)).toList();
    }

    // Price spend text range — filter by average spend across entries
    if (_minSpend != null || _maxSpend != null) {
      list = list.where((r) {
        final spends = r.entries
            .where((e) => e.spendAmount != null)
            .map((e) => e.spendAmount!)
            .toList();
        if (spends.isEmpty) return false;
        final avg = spends.reduce((a, b) => a + b) / spends.length;
        if (_minSpend != null && avg < _minSpend!) return false;
        if (_maxSpend != null && avg > _maxSpend!) return false;
        return true;
      }).toList();
    }

    // Dining type
    if (_selectedDiningTypes.isNotEmpty) {
      list = list.where((r) {
        final types = r.tags['Dining Type'] ?? [];
        return _selectedDiningTypes.any((t) => types.contains(t));
      }).toList();
    }

    // Cuisine
    if (_selectedCuisines.isNotEmpty) {
      list = list.where((r) {
        final cuisines = r.tags['Cuisine'] ?? [];
        return _selectedCuisines.any((c) => cuisines.contains(c));
      }).toList();
    }

    // Dietary preferences
    if (_selectedDietaryPrefs.isNotEmpty) {
      list = list.where((r) {
        final prefs = r.tags['Dietary Preferences'] ?? [];
        return _selectedDietaryPrefs.any((p) => prefs.contains(p));
      }).toList();
    }

    // Sort
    switch (_sortOption) {
      case SortOption.name:
        list.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
      case SortOption.rating:
        list.sort((a, b) => b.averageRating.compareTo(a.averageRating));
      case SortOption.mostVisited:
        list.sort((a, b) => b.visitCount.compareTo(a.visitCount));
      case SortOption.mostRecent:
        list.sort((a, b) {
          final aDate = a.entries.isNotEmpty ? a.entries.first.date : DateTime(0);
          final bDate = b.entries.isNotEmpty ? b.entries.first.date : DateTime(0);
          return bDate.compareTo(aDate);
        });
    }

    // Favorites pinned to top
    return [
      ...list.where((r) => r.isFavorite),
      ...list.where((r) => !r.isFavorite),
    ];
  }

  void _clearAllFilters() {
    setState(() {
      _selectedPriceRanges = {};
      _minSpend = null;
      _maxSpend = null;
      _selectedDiningTypes = {};
      _selectedCuisines = {};
      _selectedDietaryPrefs = {};
    });
  }

  // ── Bottom sheets ──────────────────────────────────────────────────────────

  void _showSortSheet() {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Text('Sort by',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            ),
            ...[
              (SortOption.name, Icons.sort_by_alpha, 'Name'),
              (SortOption.rating, Icons.star_outline, 'Rating'),
              (SortOption.mostVisited, Icons.repeat, 'Most Visited'),
              (SortOption.mostRecent, Icons.access_time, 'Most Recent'),
            ].map((item) {
              final (option, icon, label) = item;
              return RadioListTile<SortOption>(
                title: Text(label),
                secondary: Icon(icon),
                value: option,
                groupValue: _sortOption,
                onChanged: (val) {
                  if (val != null) setState(() => _sortOption = val);
                  Navigator.pop(ctx);
                },
              );
            }),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  void _showFilterSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => _FilterSheet(
        initialPriceRanges: _selectedPriceRanges,
        initialMinSpend: _minSpend,
        initialMaxSpend: _maxSpend,
        initialDiningTypes: _selectedDiningTypes,
        initialCuisines: _selectedCuisines,
        initialDietaryPrefs: _selectedDietaryPrefs,
        onApply: (priceRanges, minSpend, maxSpend, diningTypes, cuisines, dietaryPrefs) {
          setState(() {
            _selectedPriceRanges = priceRanges;
            _minSpend = minSpend;
            _maxSpend = maxSpend;
            _selectedDiningTypes = diningTypes;
            _selectedCuisines = cuisines;
            _selectedDietaryPrefs = dietaryPrefs;
          });
        },
      ),
    );
  }


  // ── Restaurant options ─────────────────────────────────────────────────────

  void _showRestaurantOptions(BuildContext context, Restaurant restaurant) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.edit),
              title: const Text('Edit Restaurant'),
              onTap: () {
                Navigator.pop(ctx);
                context
                    .push('/edit-restaurant/${restaurant.id}')
                    .then((_) => _loadData());
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete, color: Colors.red),
              title: const Text('Delete Restaurant',
                  style: TextStyle(color: Colors.red)),
              onTap: () {
                Navigator.pop(ctx);
                _confirmDeleteRestaurant(context, restaurant);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDeleteRestaurant(BuildContext context, Restaurant restaurant) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Restaurant'),
        content: Text(
            'Are you sure you want to delete "${restaurant.name}" and all its entries? This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await _repository.deleteRestaurant(restaurant.id);
              dataVersionNotifier.value++;
              _loadData();
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  Future<void> _toggleFavorite(Restaurant restaurant) async {
    final updated = restaurant.copyWith(isFavorite: !restaurant.isFavorite);
    await _repository.updateRestaurant(updated);
    _loadData();
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final results = _filteredAndSorted;

    return Scaffold(
      appBar: AppBar(
        title: const Text('JourniBites'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(56),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
            child: Row(
              children: [
                // Search bar
                Expanded(
                  child: SizedBox(
                    height: 40,
                    child: TextField(
                      controller: _searchController,
                      decoration: InputDecoration(
                        hintText: 'Search restaurants...',
                        prefixIcon: const Icon(Icons.search, size: 20),
                        suffixIcon: _searchQuery.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear, size: 18),
                                onPressed: _searchController.clear,
                              )
                            : null,
                        contentPadding: EdgeInsets.zero,
                        isDense: true,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(20),
                          borderSide: BorderSide.none,
                        ),
                        filled: true,
                        fillColor:
                            Theme.of(context).colorScheme.surfaceVariant,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 4),

                // Sort
                IconButton(
                  tooltip: 'Sort',
                  icon: const Icon(Icons.sort),
                  onPressed: _showSortSheet,
                ),

                // Filter with badge
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    IconButton(
                      tooltip: 'Filter',
                      icon: const Icon(Icons.tune),
                      onPressed: _showFilterSheet,
                    ),
                    if (_activeFilterCount > 0)
                      Positioned(
                        right: 4,
                        top: 4,
                        child: Container(
                          padding: const EdgeInsets.all(3),
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.error,
                            shape: BoxShape.circle,
                          ),
                          child: Text(
                            '$_activeFilterCount',
                            style: TextStyle(
                              fontSize: 9,
                              color: Theme.of(context).colorScheme.onError,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : results.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.search_off,
                            size: 48, color: Colors.grey),
                        const SizedBox(height: 12),
                        Text(
                          _allRestaurants.isEmpty
                              ? 'No restaurants yet.\nTap the + button to add your first visit!'
                              : 'No restaurants match your search or filters.',
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Colors.grey),
                        ),
                        if (_activeFilterCount > 0 ||
                            _searchQuery.isNotEmpty) ...[
                          const SizedBox(height: 12),
                          TextButton(
                            onPressed: () {
                              _searchController.clear();
                              _clearAllFilters();
                            },
                            child: const Text('Clear search & filters'),
                          ),
                        ],
                      ],
                    ),
                  ),
                )
              : ListView.builder(
                  itemCount: results.length,
                  itemBuilder: (context, index) {
                    final restaurant = results[index];
                    final foodMatches = _foodMatchMap[restaurant.id];
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (foodMatches != null)
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 8, 16, 2),
                            child: Row(
                              children: [
                                const Icon(Icons.restaurant_menu,
                                    size: 13, color: Colors.grey),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text(
                                    'Found: ${foodMatches.take(3).join(', ')}${foodMatches.length > 3 ? ' +${foodMatches.length - 3} more' : ''}',
                                    style: const TextStyle(
                                        fontSize: 11, color: Colors.grey),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        RestaurantCard(
                          restaurant: restaurant,
                          onTap: () =>
                              context.push('/restaurant/${restaurant.id}'),
                          onLongPress: () =>
                              _showRestaurantOptions(context, restaurant),
                          onFavoriteToggle: () => _toggleFavorite(restaurant),
                        ),
                      ],
                    );
                  },
                ),
    );
  }
}

// ── Filter sheet widget (proper StatefulWidget for safe controller lifecycle) ─

typedef _FilterApplyCallback = void Function(
  Set<int> priceRanges,
  double? minSpend,
  double? maxSpend,
  Set<String> diningTypes,
  Set<String> cuisines,
  Set<String> dietaryPrefs,
);

class _FilterSheet extends StatefulWidget {
  final Set<int> initialPriceRanges;
  final double? initialMinSpend;
  final double? initialMaxSpend;
  final Set<String> initialDiningTypes;
  final Set<String> initialCuisines;
  final Set<String> initialDietaryPrefs;
  final _FilterApplyCallback onApply;

  const _FilterSheet({
    required this.initialPriceRanges,
    required this.initialMinSpend,
    required this.initialMaxSpend,
    required this.initialDiningTypes,
    required this.initialCuisines,
    required this.initialDietaryPrefs,
    required this.onApply,
  });

  @override
  State<_FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends State<_FilterSheet> {
  late Set<int> _priceRanges;
  late double? _minSpend;
  late double? _maxSpend;
  late Set<String> _diningTypes;
  late Set<String> _cuisines;
  late Set<String> _dietaryPrefs;
  final Set<String> _expanded = {};

  late final TextEditingController _minController;
  late final TextEditingController _maxController;

  @override
  void initState() {
    super.initState();
    _priceRanges = Set.from(widget.initialPriceRanges);
    _minSpend = widget.initialMinSpend;
    _maxSpend = widget.initialMaxSpend;
    _diningTypes = Set.from(widget.initialDiningTypes);
    _cuisines = Set.from(widget.initialCuisines);
    _dietaryPrefs = Set.from(widget.initialDietaryPrefs);
    _minController = TextEditingController(
        text: _minSpend?.toStringAsFixed(0) ?? '');
    _maxController = TextEditingController(
        text: _maxSpend?.toStringAsFixed(0) ?? '');
  }

  @override
  void dispose() {
    _minController.dispose();
    _maxController.dispose();
    super.dispose();
  }

  void _clearAll() {
    setState(() {
      _priceRanges = {};
      _minSpend = null;
      _maxSpend = null;
      _diningTypes = {};
      _cuisines = {};
      _dietaryPrefs = {};
    });
    _minController.clear();
    _maxController.clear();
  }

  void _toggleAccordion(String key) =>
      setState(() => _expanded.contains(key)
          ? _expanded.remove(key)
          : _expanded.add(key));

  void _toggleChip(Set<String> set, String tag) =>
      setState(() => set.contains(tag) ? set.remove(tag) : set.add(tag));

  int get _priceSelectedCount =>
      _priceRanges.length + (_minSpend != null || _maxSpend != null ? 1 : 0);

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.7,
      maxChildSize: 0.95,
      minChildSize: 0.4,
      builder: (_, scrollCtrl) => Column(
        children: [
          // ── Header ──
          Container(
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
            ),
            padding: const EdgeInsets.fromLTRB(16, 14, 8, 10),
            child: Row(
              children: [
                const Text('Filters',
                    style:
                        TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
                const Spacer(),
                TextButton(
                  onPressed: _clearAll,
                  child: const Text('Clear all'),
                ),
              ],
            ),
          ),

          // ── Body ──
          Expanded(
            child: ListView(
              controller: scrollCtrl,
              padding: const EdgeInsets.symmetric(vertical: 8),
              children: [
                // 1. Price Range
                _FilterAccordion(
                  title: 'Price Range',
                  selectedCount: _priceSelectedCount,
                  isExpanded: _expanded.contains('price'),
                  onToggle: () => _toggleAccordion('price'),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        spacing: 8,
                        runSpacing: 6,
                        children: List.generate(4, (i) {
                          final val = i + 1;
                          final label = '₱' * val;
                          final sel = _priceRanges.contains(val);
                          return FilterChip(
                            label: Text(label,
                                style: const TextStyle(fontSize: 12)),
                            selected: sel,
                            onSelected: (_) => setState(() => sel
                                ? _priceRanges.remove(val)
                                : _priceRanges.add(val)),
                          );
                        }),
                      ),
                      const SizedBox(height: 14),
                      const Text('Average spend range (₱)',
                          style:
                              TextStyle(fontSize: 12, color: Colors.grey)),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _minController,
                              keyboardType: TextInputType.number,
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly
                              ],
                              decoration: const InputDecoration(
                                labelText: 'Min',
                                prefixText: '₱',
                                border: OutlineInputBorder(),
                                isDense: true,
                                contentPadding: EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 10),
                              ),
                              onChanged: (v) => setState(() =>
                                  _minSpend =
                                      v.isEmpty ? null : double.tryParse(v)),
                            ),
                          ),
                          const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 8),
                            child:
                                Text('–', style: TextStyle(fontSize: 18)),
                          ),
                          Expanded(
                            child: TextField(
                              controller: _maxController,
                              keyboardType: TextInputType.number,
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly
                              ],
                              decoration: const InputDecoration(
                                labelText: 'Max',
                                prefixText: '₱',
                                border: OutlineInputBorder(),
                                isDense: true,
                                contentPadding: EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 10),
                              ),
                              onChanged: (v) => setState(() =>
                                  _maxSpend =
                                      v.isEmpty ? null : double.tryParse(v)),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // 2. Dining Type
                _FilterAccordion(
                  title: 'Dining Type',
                  selectedCount: _diningTypes.length,
                  isExpanded: _expanded.contains('dining'),
                  onToggle: () => _toggleAccordion('dining'),
                  child: _TagChipGrid(
                    options: restaurantTagCategories['Dining Type'] ?? [],
                    selected: _diningTypes,
                    onToggle: (tag) => _toggleChip(_diningTypes, tag),
                    category: 'Dining Type',
                  ),
                ),

                // 3. Cuisine
                _FilterAccordion(
                  title: 'Cuisine',
                  selectedCount: _cuisines.length,
                  isExpanded: _expanded.contains('cuisine'),
                  onToggle: () => _toggleAccordion('cuisine'),
                  child: _TagChipGrid(
                    options: restaurantTagCategories['Cuisine'] ?? [],
                    selected: _cuisines,
                    onToggle: (tag) => _toggleChip(_cuisines, tag),
                    category: 'Cuisine',
                  ),
                ),

                // 4. Dietary Preferences
                _FilterAccordion(
                  title: 'Dietary Preferences',
                  selectedCount: _dietaryPrefs.length,
                  isExpanded: _expanded.contains('dietary'),
                  onToggle: () => _toggleAccordion('dietary'),
                  child: _TagChipGrid(
                    options:
                        restaurantTagCategories['Dietary Preferences'] ?? [],
                    selected: _dietaryPrefs,
                    onToggle: (tag) => _toggleChip(_dietaryPrefs, tag),
                    category: 'Dietary Preferences',
                  ),
                ),

                const SizedBox(height: 16),
              ],
            ),
          ),

          // ── Apply ──
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    widget.onApply(
                      _priceRanges,
                      _minSpend,
                      _maxSpend,
                      _diningTypes,
                      _cuisines,
                      _dietaryPrefs,
                    );
                    Navigator.pop(context);
                  },
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: const Text('Apply Filters',
                      style: TextStyle(fontSize: 16)),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Reusable accordion widget ──────────────────────────────────────────────

class _FilterAccordion extends StatelessWidget {
  final String title;
  final int selectedCount;
  final bool isExpanded;
  final VoidCallback onToggle;
  final Widget child;

  const _FilterAccordion({
    required this.title,
    required this.selectedCount,
    required this.isExpanded,
    required this.onToggle,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      children: [
        InkWell(
          onTap: onToggle,
          child: Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
            child: Row(
              children: [
                Text(title,
                    style: const TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 14)),
                const SizedBox(width: 8),
                if (selectedCount > 0)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 7, vertical: 1),
                    decoration: BoxDecoration(
                      color: colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '$selectedCount',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: colorScheme.onPrimaryContainer,
                      ),
                    ),
                  ),
                const Spacer(),
                Icon(
                  isExpanded
                      ? Icons.keyboard_arrow_up
                      : Icons.keyboard_arrow_down,
                  color: Colors.grey,
                ),
              ],
            ),
          ),
        ),
        if (isExpanded)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
            child: child,
          ),
        const Divider(height: 1),
      ],
    );
  }
}

// ── Reusable chip grid (loads custom tags from DB) ────────────────────────

class _TagChipGrid extends StatefulWidget {
  final List<String> options;
  final Set<String> selected;
  final void Function(String tag) onToggle;
  final String category; // e.g. 'Dining Type'

  const _TagChipGrid({
    required this.options,
    required this.selected,
    required this.onToggle,
    required this.category,
  });

  @override
  State<_TagChipGrid> createState() => _TagChipGridState();
}

class _TagChipGridState extends State<_TagChipGrid> {
  final _repository = JourniBitesRepository();
  List<String> _customTags = [];

  @override
  void initState() {
    super.initState();
    _loadCustomTags();
  }

  Future<void> _loadCustomTags() async {
    final all = await _repository.getCustomTags('restaurant');
    if (!mounted) return;
    setState(() => _customTags = all[widget.category] ?? []);
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    Widget dividerLabel(String label) => Row(children: [
          Expanded(child: Divider(color: Colors.grey.shade300)),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Text(label,
                style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade600,
                    letterSpacing: 0.5)),
          ),
          Expanded(child: Divider(color: Colors.grey.shade300)),
        ]);

    Widget chipWrap(List<String> tags, bool isCustom) => Wrap(
          spacing: 8,
          runSpacing: 6,
          children: tags.map((tag) {
            final sel = widget.selected.contains(tag);
            return FilterChip(
              label: Text(tag, style: const TextStyle(fontSize: 12)),
              selected: sel,
              onSelected: (_) => widget.onToggle(tag),
              selectedColor: isCustom
                  ? colorScheme.secondaryContainer
                  : colorScheme.primaryContainer,
              checkmarkColor: isCustom
                  ? colorScheme.onSecondaryContainer
                  : colorScheme.onPrimaryContainer,
              labelStyle: TextStyle(
                fontSize: 12,
                color: sel
                    ? (isCustom
                        ? colorScheme.onSecondaryContainer
                        : colorScheme.onPrimaryContainer)
                    : null,
              ),
            );
          }).toList(),
        );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        dividerLabel('${widget.category} Tags'),
        const SizedBox(height: 6),
        chipWrap(widget.options, false),
        if (_customTags.isNotEmpty) ...[
          const SizedBox(height: 10),
          dividerLabel('Custom Tags'),
          const SizedBox(height: 6),
          chipWrap(_customTags, true),
        ],
      ],
    );
  }
}