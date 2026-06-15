import 'package:flutter/material.dart';
import '../data/tag_definitions.dart';
import '../widgets/tag_selector.dart';

class FoodItemCard extends StatefulWidget {
  final int index;
  final String initialName;
  final Map<String, List<String>> initialTags;
  final List<String> initialLiked;
  final List<String> initialDisliked;
  final VoidCallback onRemove;
  final void Function(String name) onNameChanged;
  final void Function(Map<String, List<String>> tags) onTagsChanged;
  final void Function(List<String> liked) onLikedChanged;
  final void Function(List<String> disliked) onDislikedChanged;

  const FoodItemCard({
    super.key,
    required this.index,
    this.initialName = '',
    this.initialTags = const {},
    this.initialLiked = const [],
    this.initialDisliked = const [],
    required this.onRemove,
    required this.onNameChanged,
    required this.onTagsChanged,
    required this.onLikedChanged,
    required this.onDislikedChanged,
  });

  @override
  State<FoodItemCard> createState() => _FoodItemCardState();
}

class _FoodItemCardState extends State<FoodItemCard> {
  late final TextEditingController _nameController;
  late List<TextEditingController> _likedControllers;
  late List<TextEditingController> _dislikedControllers;
  late Map<String, List<String>> _selectedTags;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.initialName);
    _selectedTags = Map.from(widget.initialTags);
    _likedControllers = widget.initialLiked.isEmpty
        ? [TextEditingController()]
        : widget.initialLiked.map((s) => TextEditingController(text: s)).toList();
    _dislikedControllers = widget.initialDisliked.isEmpty
        ? [TextEditingController()]
        : widget.initialDisliked.map((s) => TextEditingController(text: s)).toList();
  }

  @override
  void dispose() {
    _nameController.dispose();
    for (final c in _likedControllers) c.dispose();
    for (final c in _dislikedControllers) c.dispose();
    super.dispose();
  }

  void _notifyLiked() {
    widget.onLikedChanged(
      _likedControllers.map((c) => c.text.trim()).where((s) => s.isNotEmpty).toList(),
    );
  }

  void _notifyDisliked() {
    widget.onDislikedChanged(
      _dislikedControllers.map((c) => c.text.trim()).where((s) => s.isNotEmpty).toList(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header row
            Row(
              children: [
                Text(
                  'Food ${widget.index + 1}',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close, size: 20, color: Colors.grey),
                  onPressed: widget.onRemove,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Name
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                hintText: 'Food name (e.g. Soy Garlic Wings)',
                border: OutlineInputBorder(),
                isDense: true,
              ),
              onChanged: widget.onNameChanged,
            ),
            const SizedBox(height: 10),

            // Food tags
            TagSelector(
              tagType: 'food',
              sectionTitle: 'Food Tags',
              categories: foodTagCategories,
              selected: _selectedTags,
              onChanged: (updated) {
                setState(() => _selectedTags = updated);
                widget.onTagsChanged(updated);
              },
            ),
            const SizedBox(height: 10),

            // Liked
            const Text('Liked',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.green)),
            const SizedBox(height: 4),
            ...List.generate(_likedControllers.length, (i) => Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(children: [
                    Expanded(
                      child: TextField(
                        controller: _likedControllers[i],
                        decoration: const InputDecoration(
                          hintText: 'e.g. Crispy skin',
                          border: OutlineInputBorder(),
                          isDense: true,
                          prefixIcon: Icon(Icons.thumb_up_outlined, color: Colors.green, size: 18),
                        ),
                        onChanged: (_) => _notifyLiked(),
                      ),
                    ),
                    if (_likedControllers.length > 1)
                      IconButton(
                        icon: const Icon(Icons.remove_circle_outline, size: 18),
                        onPressed: () {
                          setState(() {
                            _likedControllers[i].dispose();
                            _likedControllers.removeAt(i);
                          });
                          _notifyLiked();
                        },
                      ),
                  ]),
                )),
            TextButton.icon(
              onPressed: () => setState(() => _likedControllers.add(TextEditingController())),
              icon: const Icon(Icons.add, size: 16),
              label: const Text('Add', style: TextStyle(fontSize: 13)),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
            const SizedBox(height: 8),

            // Disliked
            const Text('Disliked',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.red)),
            const SizedBox(height: 4),
            ...List.generate(_dislikedControllers.length, (i) => Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(children: [
                    Expanded(
                      child: TextField(
                        controller: _dislikedControllers[i],
                        decoration: const InputDecoration(
                          hintText: 'e.g. Too salty',
                          border: OutlineInputBorder(),
                          isDense: true,
                          prefixIcon: Icon(Icons.thumb_down_outlined, color: Colors.red, size: 18),
                        ),
                        onChanged: (_) => _notifyDisliked(),
                      ),
                    ),
                    if (_dislikedControllers.length > 1)
                      IconButton(
                        icon: const Icon(Icons.remove_circle_outline, size: 18),
                        onPressed: () {
                          setState(() {
                            _dislikedControllers[i].dispose();
                            _dislikedControllers.removeAt(i);
                          });
                          _notifyDisliked();
                        },
                      ),
                  ]),
                )),
            TextButton.icon(
              onPressed: () => setState(() => _dislikedControllers.add(TextEditingController())),
              icon: const Icon(Icons.add, size: 16),
              label: const Text('Add', style: TextStyle(fontSize: 13)),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
          ],
        ),
      ),
    );
  }
}