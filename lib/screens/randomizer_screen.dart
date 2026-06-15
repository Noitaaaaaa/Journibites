import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import '../data/journibites_repository.dart';
import '../data/tag_definitions.dart';
import '../models/restaurant.dart';

class RandomizerScreen extends StatefulWidget {
  const RandomizerScreen({super.key});

  @override
  State<RandomizerScreen> createState() => _RandomizerScreenState();
}

class _RandomizerScreenState extends State<RandomizerScreen> {
  final _repository = JourniBitesRepository();
  final _random = Random();

  List<Restaurant> _allRestaurants = [];
  bool _loading = true;

  // Toggle filters
  bool _onlyHighlyRated = false;
  bool _onlyNotRecent = false;

  // Sheet filters
  Set<int> _selectedPriceRanges = {};
  double? _minSpend;
  double? _maxSpend;
  Set<String> _selectedDiningTypes = {};
  Set<String> _selectedCuisines = {};
  Set<String> _selectedDietaryPrefs = {};

  Restaurant? _result;

  int get _activeFilterCount =>
      (_onlyHighlyRated ? 1 : 0) +
      (_onlyNotRecent ? 1 : 0) +
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
  }

  @override
  void dispose() {
    dataVersionNotifier.removeListener(_loadData);
    super.dispose();
  }

  Future<void> _loadData() async {
    final restaurants = await _repository.getAllRestaurants();
    if (!mounted) return;
    setState(() {
      _allRestaurants = restaurants;
      _loading = false;
      if (_result != null && !_filteredRestaurants.any((r) => r.id == _result!.id)) {
        _result = null;
      }
    });
  }

  List<Restaurant> get _filteredRestaurants {
    return _allRestaurants.where((r) {
      if (r.entries.isEmpty) return false;

      if (_onlyHighlyRated && r.averageRating < 4.0) return false;

      if (_onlyNotRecent) {
        final lastVisit = r.mostRecentEntry?.date;
        if (lastVisit != null) {
          final daysSince = DateTime.now().difference(lastVisit).inDays;
          if (daysSince < 30) return false;
        }
      }

      if (_selectedPriceRanges.isNotEmpty &&
          !_selectedPriceRanges.contains(r.priceRange)) return false;

      if (_minSpend != null || _maxSpend != null) {
        final spends = r.entries
            .where((e) => e.spendAmount != null)
            .map((e) => e.spendAmount!)
            .toList();
        if (spends.isEmpty) return false;
        final avg = spends.reduce((a, b) => a + b) / spends.length;
        if (_minSpend != null && avg < _minSpend!) return false;
        if (_maxSpend != null && avg > _maxSpend!) return false;
      }

      if (_selectedDiningTypes.isNotEmpty) {
        final types = r.tags['Dining Type'] ?? [];
        if (!_selectedDiningTypes.any((t) => types.contains(t))) return false;
      }

      if (_selectedCuisines.isNotEmpty) {
        final cuisines = r.tags['Cuisine'] ?? [];
        if (!_selectedCuisines.any((c) => cuisines.contains(c))) return false;
      }

      if (_selectedDietaryPrefs.isNotEmpty) {
        final prefs = r.tags['Dietary Preferences'] ?? [];
        if (!_selectedDietaryPrefs.any((p) => prefs.contains(p))) return false;
      }

      return true;
    }).toList();
  }

  void _pickRandom() {
    final candidates = _filteredRestaurants;
    if (candidates.isEmpty) {
      setState(() => _result = null);
      return;
    }

    List<Restaurant> pool = candidates;
    if (candidates.length > 1 && _result != null) {
      pool = candidates.where((r) => r.id != _result!.id).toList();
    }

    setState(() => _result = pool[_random.nextInt(pool.length)]);
  }

  void _clearAllFilters() {
    setState(() {
      _onlyHighlyRated = false;
      _onlyNotRecent = false;
      _selectedPriceRanges = {};
      _minSpend = null;
      _maxSpend = null;
      _selectedDiningTypes = {};
      _selectedCuisines = {};
      _selectedDietaryPrefs = {};
      _result = null;
    });
  }

  void _showFilterSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => _RandomizerFilterSheet(
        initialOnlyHighlyRated: _onlyHighlyRated,
        initialOnlyNotRecent: _onlyNotRecent,
        initialPriceRanges: _selectedPriceRanges,
        initialMinSpend: _minSpend,
        initialMaxSpend: _maxSpend,
        initialDiningTypes: _selectedDiningTypes,
        initialCuisines: _selectedCuisines,
        initialDietaryPrefs: _selectedDietaryPrefs,
        onApply: (onlyHighlyRated, onlyNotRecent, priceRanges, minSpend,
            maxSpend, diningTypes, cuisines, dietaryPrefs) {
          setState(() {
            _onlyHighlyRated = onlyHighlyRated;
            _onlyNotRecent = onlyNotRecent;
            _selectedPriceRanges = priceRanges;
            _minSpend = minSpend;
            _maxSpend = maxSpend;
            _selectedDiningTypes = diningTypes;
            _selectedCuisines = cuisines;
            _selectedDietaryPrefs = dietaryPrefs;
            _result = null;
          });
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final candidates = _filteredRestaurants;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Randomizer'),
        actions: [
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
          if (_activeFilterCount > 0)
            IconButton(
              tooltip: 'Clear filters',
              icon: const Icon(Icons.filter_alt_off),
              onPressed: _clearAllFilters,
            ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const Text(
              "Can't decide where to eat?",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),

            Text(
              '${candidates.length} restaurant${candidates.length == 1 ? '' : 's'} match your filters',
              style: const TextStyle(color: Colors.grey, fontSize: 13),
            ),
            const SizedBox(height: 16),

            // Main action button
            ElevatedButton.icon(
              onPressed: candidates.isEmpty ? null : _pickRandom,
              icon: const Icon(Icons.casino),
              label: const Text('What should I eat?'),
              style: ElevatedButton.styleFrom(
                padding:
                    const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
                textStyle: const TextStyle(fontSize: 16),
              ),
            ),
            const SizedBox(height: 24),

            // Result
            Expanded(
              child: candidates.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.search_off,
                              size: 48, color: Colors.grey),
                          const SizedBox(height: 12),
                          Text(
                            _allRestaurants.isEmpty
                                ? 'No restaurants saved yet.\nAdd some visits first!'
                                : 'No restaurants match your filters.\nTry adjusting them.',
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: Colors.grey),
                          ),
                          if (_activeFilterCount > 0) ...[
                            const SizedBox(height: 12),
                            TextButton(
                              onPressed: _clearAllFilters,
                              child: const Text('Clear all filters'),
                            ),
                          ],
                        ],
                      ),
                    )
                  : _result == null
                      ? const Center(
                          child: Text(
                            'Tap the button to get a suggestion!',
                            style: TextStyle(color: Colors.grey),
                          ),
                        )
                      : _buildResultCard(_result!),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResultCard(Restaurant restaurant) {
    final lastVisit = restaurant.mostRecentEntry;

    return Center(
      child: Card(
        elevation: 4,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.restaurant, size: 48, color: Colors.deepOrange),
              const SizedBox(height: 12),
              Text(
                restaurant.name,
                textAlign: TextAlign.center,
                style:
                    const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
              if (restaurant.address != null) ...[
                const SizedBox(height: 4),
                Text(
                  restaurant.address!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.grey),
                ),
              ],
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.star, color: Colors.amber, size: 18),
                  Text(' ${restaurant.averageRating.toStringAsFixed(1)}'),
                  const SizedBox(width: 16),
                  Text('Visited ${restaurant.visitCount}x'),
                  if (restaurant.spendRangeLabel != null) ...[
                    const SizedBox(width: 16),
                    Text(
                      restaurant.spendRangeLabel!,
                      style:
                          const TextStyle(color: Colors.teal, fontSize: 13),
                    ),
                  ],
                ],
              ),
              if (lastVisit != null) ...[
                const SizedBox(height: 4),
                Text(
                  'Last visit: ${lastVisit.date.month}/${lastVisit.date.day}/${lastVisit.date.year}',
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  OutlinedButton.icon(
                    onPressed: _pickRandom,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Reroll'),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton.icon(
                    onPressed: () =>
                        context.push('/restaurant/${restaurant.id}'),
                    icon: const Icon(Icons.arrow_forward),
                    label: const Text('View'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Filter sheet ───────────────────────────────────────────────────────────────

typedef _RandomizerFilterApplyCallback = void Function(
  bool onlyHighlyRated,
  bool onlyNotRecent,
  Set<int> priceRanges,
  double? minSpend,
  double? maxSpend,
  Set<String> diningTypes,
  Set<String> cuisines,
  Set<String> dietaryPrefs,
);

class _RandomizerFilterSheet extends StatefulWidget {
  final bool initialOnlyHighlyRated;
  final bool initialOnlyNotRecent;
  final Set<int> initialPriceRanges;
  final double? initialMinSpend;
  final double? initialMaxSpend;
  final Set<String> initialDiningTypes;
  final Set<String> initialCuisines;
  final Set<String> initialDietaryPrefs;
  final _RandomizerFilterApplyCallback onApply;

  const _RandomizerFilterSheet({
    required this.initialOnlyHighlyRated,
    required this.initialOnlyNotRecent,
    required this.initialPriceRanges,
    required this.initialMinSpend,
    required this.initialMaxSpend,
    required this.initialDiningTypes,
    required this.initialCuisines,
    required this.initialDietaryPrefs,
    required this.onApply,
  });

  @override
  State<_RandomizerFilterSheet> createState() =>
      _RandomizerFilterSheetState();
}

class _RandomizerFilterSheetState extends State<_RandomizerFilterSheet> {
  late bool _onlyHighlyRated;
  late bool _onlyNotRecent;
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
    _onlyHighlyRated = widget.initialOnlyHighlyRated;
    _onlyNotRecent = widget.initialOnlyNotRecent;
    _priceRanges = Set.from(widget.initialPriceRanges);
    _minSpend = widget.initialMinSpend;
    _maxSpend = widget.initialMaxSpend;
    _diningTypes = Set.from(widget.initialDiningTypes);
    _cuisines = Set.from(widget.initialCuisines);
    _dietaryPrefs = Set.from(widget.initialDietaryPrefs);
    _minController =
        TextEditingController(text: _minSpend?.toStringAsFixed(0) ?? '');
    _maxController =
        TextEditingController(text: _maxSpend?.toStringAsFixed(0) ?? '');
  }

  @override
  void dispose() {
    _minController.dispose();
    _maxController.dispose();
    super.dispose();
  }

  void _clearAll() {
    setState(() {
      _onlyHighlyRated = false;
      _onlyNotRecent = false;
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

  void _toggleAccordion(String key) => setState(() =>
      _expanded.contains(key) ? _expanded.remove(key) : _expanded.add(key));

  void _toggleChip(Set<String> set, String tag) =>
      setState(() => set.contains(tag) ? set.remove(tag) : set.add(tag));

  int get _priceSelectedCount =>
      _priceRanges.length + (_minSpend != null || _maxSpend != null ? 1 : 0);

  int get _quickFilterCount =>
      (_onlyHighlyRated ? 1 : 0) + (_onlyNotRecent ? 1 : 0);

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
              border:
                  Border(bottom: BorderSide(color: Colors.grey.shade200)),
            ),
            padding: const EdgeInsets.fromLTRB(16, 14, 8, 10),
            child: Row(
              children: [
                const Text('Filters',
                    style: TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 17)),
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
                // 1. Quick filters
                _FilterAccordion(
                  title: 'Quick Filters',
                  selectedCount: _quickFilterCount,
                  isExpanded: _expanded.contains('quick'),
                  onToggle: () => _toggleAccordion('quick'),
                  child: Column(
                    children: [
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        dense: true,
                        title: const Text('Only highly rated (4.0+)',
                            style: TextStyle(fontSize: 13)),
                        value: _onlyHighlyRated,
                        onChanged: (v) =>
                            setState(() => _onlyHighlyRated = v),
                      ),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        dense: true,
                        title: const Text("Haven't visited in 30+ days",
                            style: TextStyle(fontSize: 13)),
                        value: _onlyNotRecent,
                        onChanged: (v) =>
                            setState(() => _onlyNotRecent = v),
                      ),
                    ],
                  ),
                ),

                // 2. Price Range
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
                              onChanged: (v) => setState(() => _minSpend =
                                  v.isEmpty ? null : double.tryParse(v)),
                            ),
                          ),
                          const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 8),
                            child: Text('–',
                                style: TextStyle(fontSize: 18)),
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
                              onChanged: (v) => setState(() => _maxSpend =
                                  v.isEmpty ? null : double.tryParse(v)),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // 3. Dining Type
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

                // 4. Cuisine
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

                // 5. Dietary Preferences
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
                      _onlyHighlyRated,
                      _onlyNotRecent,
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

// ── Reusable accordion widget ──────────────────────────────────────────────────

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
  final String category;

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