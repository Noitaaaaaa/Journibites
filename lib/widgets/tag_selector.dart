import 'package:flutter/material.dart';
import '../data/journibites_repository.dart';

class TagSelector extends StatefulWidget {
  final String sectionTitle;
  final Map<String, List<String>> categories;
  final Map<String, List<String>> selected;
  final void Function(Map<String, List<String>> updated) onChanged;
  final String tagType; // 'restaurant' or 'food'

  const TagSelector({
    super.key,
    required this.sectionTitle,
    required this.categories,
    required this.selected,
    required this.onChanged,
    required this.tagType,
  });

  @override
  State<TagSelector> createState() => _TagSelectorState();
}

class _TagSelectorState extends State<TagSelector> {
  final _repository = JourniBitesRepository();
  final Set<String> _expanded = {};
  Map<String, List<String>> _customTags = {};
  bool _loadingCustomTags = true;

  @override
  void initState() {
    super.initState();
    _loadCustomTags();
  }

  Future<void> _loadCustomTags() async {
    final tags = await _repository.getCustomTags(widget.tagType);
    if (!mounted) return;
    setState(() {
      _customTags = tags;
      _loadingCustomTags = false;
    });
  }

  bool _isSelected(String category, String tag) {
    return widget.selected[category]?.contains(tag) ?? false;
  }

  void _toggle(String category, String tag) {
    final updated = Map<String, List<String>>.from(
      widget.selected.map((k, v) => MapEntry(k, List<String>.from(v))),
    );
    final list = updated.putIfAbsent(category, () => []);
    if (list.contains(tag)) {
      list.remove(tag);
      if (list.isEmpty) updated.remove(category);
    } else {
      list.add(tag);
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) widget.onChanged(updated);
    });
  }

  void _addCustomTag(String category) async {
    final controller = TextEditingController();
    if (!mounted) return;
    final result = await showDialog<String>(
      context: context,
      useRootNavigator: true,
      builder: (context) => AlertDialog(
        title: Text('Add to $category'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'Custom tag...'),
          textCapitalization: TextCapitalization.words,
          onSubmitted: (v) => Navigator.pop(context, v.trim()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('Add'),
          ),
        ],
      ),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) => controller.dispose());
    if (!mounted) return;
    if (result != null && result.isNotEmpty) {
      final prebuilt = widget.categories[category] ?? [];
      if (prebuilt.contains(result)) {
        _toggle(category, result);
        return;
      }
      await _repository.insertCustomTag(widget.tagType, category, result);
      if (!mounted) return;
      setState(() {
        _customTags.putIfAbsent(category, () => []);
        if (!_customTags[category]!.contains(result)) {
          _customTags[category]!.add(result);
        }
      });
      _toggle(category, result);
    }
  }

  void _deleteCustomTag(String category, String tag) async {
    await _repository.deleteCustomTag(widget.tagType, category, tag);
    if (!mounted) return;
    setState(() {
      _customTags[category]?.remove(tag);
      if (_customTags[category]?.isEmpty ?? false) _customTags.remove(category);
    });
    if (_isSelected(category, tag)) _toggle(category, tag);
  }

  void _showDeleteConfirm(String category, String tag) {
    showDialog(
      context: context,
      useRootNavigator: true,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Custom Tag'),
        content: Text('Remove "$tag" from your custom tags?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () { Navigator.pop(ctx); _deleteCustomTag(category, tag); },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  int _selectedCountInCategory(String category) =>
      widget.selected[category]?.length ?? 0;

  int get _totalSelected =>
      widget.selected.values.fold(0, (sum, list) => sum + list.length);

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(widget.sectionTitle,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(width: 8),
            if (_totalSelected > 0)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: colorScheme.primary,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text('$_totalSelected selected',
                    style: TextStyle(color: colorScheme.onPrimary, fontSize: 11)),
              ),
          ],
        ),
        const SizedBox(height: 8),

        if (_loadingCustomTags)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 4),
            child: LinearProgressIndicator(),
          ),

        ...widget.categories.entries.map((catEntry) {
          final category = catEntry.key;
          final prebuiltOptions = catEntry.value;
          final customOptions = _customTags[category] ?? [];
          final isExpanded = _expanded.contains(category);
          final selectedCount = _selectedCountInCategory(category);

          return Card(
            margin: const EdgeInsets.only(bottom: 6),
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
              side: BorderSide(color: Colors.grey.shade300),
            ),
            child: Column(
              children: [
                InkWell(
                  borderRadius: BorderRadius.circular(8),
                  onTap: () => setState(() {
                    isExpanded ? _expanded.remove(category) : _expanded.add(category);
                  }),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    child: Row(
                      children: [
                        Expanded(child: Text(category,
                            style: const TextStyle(fontWeight: FontWeight.w500))),
                        if (selectedCount > 0)
                          Container(
                            margin: const EdgeInsets.only(right: 8),
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1),
                            decoration: BoxDecoration(
                              color: colorScheme.primaryContainer,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text('$selectedCount',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: colorScheme.onPrimaryContainer,
                                  fontWeight: FontWeight.bold,
                                )),
                          ),
                        Icon(
                          isExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                          color: Colors.grey,
                        ),
                      ],
                    ),
                  ),
                ),

                if (isExpanded)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Divider(height: 1),
                        const SizedBox(height: 10),

                        // ── Prebuilt tags ──────────────────────────
                        Text('$category Tags',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: Colors.grey.shade600,
                              letterSpacing: 0.5,
                            )),
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: prebuiltOptions.map((tag) {
                            final selected = _isSelected(category, tag);
                            return FilterChip(
                              label: Text(tag),
                              selected: selected,
                              onSelected: (_) => _toggle(category, tag),
                              selectedColor: colorScheme.primaryContainer,
                              checkmarkColor: colorScheme.onPrimaryContainer,
                              labelStyle: TextStyle(
                                fontSize: 12,
                                color: selected ? colorScheme.onPrimaryContainer : null,
                              ),
                            );
                          }).toList(),
                        ),

                        // ── Custom tags ────────────────────────────
                        const SizedBox(height: 12),
                        Row(children: [
                          Expanded(child: Divider(color: Colors.grey.shade300)),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            child: Text('Custom Tags',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.grey.shade600,
                                  letterSpacing: 0.5,
                                )),
                          ),
                          Expanded(child: Divider(color: Colors.grey.shade300)),
                        ]),
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: [
                            ...customOptions.map((tag) {
                              final selected = _isSelected(category, tag);
                              return FilterChip(
                                label: Text(tag),
                                selected: selected,
                                onSelected: (_) => _toggle(category, tag),
                                selectedColor: colorScheme.secondaryContainer,
                                checkmarkColor: colorScheme.onSecondaryContainer,
                                labelStyle: TextStyle(
                                  fontSize: 12,
                                  color: selected ? colorScheme.onSecondaryContainer : null,
                                ),
                                onDeleted: () => _showDeleteConfirm(category, tag),
                                deleteIcon: const Icon(Icons.close, size: 14),
                                deleteIconColor: Colors.grey,
                              );
                            }),
                            ActionChip(
                              avatar: Icon(Icons.add, size: 16, color: colorScheme.primary),
                              label: Text('Custom',
                                  style: TextStyle(fontSize: 12, color: colorScheme.primary)),
                              onPressed: () => _addCustomTag(category),
                              side: BorderSide(color: colorScheme.primary),
                              backgroundColor: Colors.transparent,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          );
        }),
      ],
    );
  }
}