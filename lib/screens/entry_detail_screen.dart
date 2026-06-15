import 'dart:io';
import 'package:flutter/material.dart';
import '../data/journibites_repository.dart';
import '../models/journal_entry.dart';
import '../models/restaurant.dart';

class EntryDetailScreen extends StatefulWidget {
  final String entryId;

  const EntryDetailScreen({super.key, required this.entryId});

  @override
  State<EntryDetailScreen> createState() => _EntryDetailScreenState();
}

class _EntryDetailScreenState extends State<EntryDetailScreen> {
  final _repository = JourniBitesRepository();
  JournalEntry? _entry;
  Restaurant? _restaurant;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final entry = await _repository.getEntryById(widget.entryId);
    Restaurant? restaurant;
    if (entry != null) {
      restaurant = await _repository.getRestaurantById(entry.restaurantId);
    }
    if (!mounted) return;
    setState(() {
      _entry = entry;
      _restaurant = restaurant;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final foundEntry = _entry;
    final foundRestaurant = _restaurant;

    if (foundEntry == null || foundRestaurant == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Entry Not Found')),
        body: const Center(child: Text('This entry could not be found.')),
      );
    }

    return Scaffold(
      appBar: AppBar(title: Text(foundRestaurant.name)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Date, rating, would visit again
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${foundEntry.date.month}/${foundEntry.date.day}/${foundEntry.date.year}',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              Row(children: [
                const Icon(Icons.star, color: Colors.amber),
                Text(' ${foundEntry.rating}',
                    style: const TextStyle(fontSize: 18)),
              ]),
            ],
          ),
          const SizedBox(height: 4),
          Row(children: [
            Icon(
              foundEntry.wouldVisitAgain ? Icons.check_circle : Icons.cancel,
              size: 16,
              color: foundEntry.wouldVisitAgain ? Colors.green : Colors.red,
            ),
            const SizedBox(width: 4),
            Text(
              foundEntry.wouldVisitAgain ? 'Would visit again' : 'Would not visit again',
              style: TextStyle(
                fontSize: 13,
                color: foundEntry.wouldVisitAgain ? Colors.green : Colors.red,
              ),
            ),
            if (foundEntry.spendAmount != null) ...[
              const SizedBox(width: 16),
              const Icon(Icons.payments_outlined, size: 16, color: Colors.grey),
              const SizedBox(width: 4),
              Text(
                '₱${foundEntry.spendAmount!.toStringAsFixed(0)}',
                style: const TextStyle(fontSize: 13, color: Colors.grey),
              ),
            ],
          ]),
          const SizedBox(height: 16),

          // Sub-ratings
          if (foundEntry.subRatings.isNotEmpty) ...[
            const Text('Ratings',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            const SizedBox(height: 8),
            ...foundEntry.subRatings.entries.map((sub) => Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(children: [
                    SizedBox(
                      width: 80,
                      child: Text(sub.key,
                          style: const TextStyle(fontSize: 13)),
                    ),
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: sub.value / 10,
                          minHeight: 8,
                          backgroundColor: Colors.grey[300],
                          color: Colors.teal,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    SizedBox(
                      width: 32,
                      child: Text(
                        sub.value.toStringAsFixed(1),
                        style: const TextStyle(
                            fontSize: 13, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ]),
                )),
            const SizedBox(height: 16),
          ],

          // Photos
          if (foundEntry.photoUrls.isNotEmpty) ...[
            const Text('Photos',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            const SizedBox(height: 8),
            SizedBox(
              height: 150,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: foundEntry.photoUrls.length,
                itemBuilder: (context, index) => Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.file(
                      File(foundEntry.photoUrls[index]),
                      width: 150,
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],

          // Food items
          if (foundEntry.foodItems.isNotEmpty) ...[
            const Text('Food Items',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            const SizedBox(height: 8),
            ...foundEntry.foodItems.map((food) => Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade300),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Food name
                      Text(
                        food.name,
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 15),
                      ),

                      // Food tags
                      if (food.allTags.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 6,
                          runSpacing: 4,
                          children: food.allTags
                              .map((tag) => Chip(
                                    label: Text(tag,
                                        style: const TextStyle(fontSize: 11)),
                                    materialTapTargetSize:
                                        MaterialTapTargetSize.shrinkWrap,
                                    padding: EdgeInsets.zero,
                                    visualDensity: VisualDensity.compact,
                                  ))
                              .toList(),
                        ),
                      ],

                      // Liked
                      if (food.liked.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        ...food.liked.map((item) => Padding(
                              padding: const EdgeInsets.only(bottom: 2),
                              child: Row(children: [
                                const Icon(Icons.thumb_up,
                                    size: 14, color: Colors.green),
                                const SizedBox(width: 6),
                                Text(item, style: const TextStyle(fontSize: 13)),
                              ]),
                            )),
                      ],

                      // Disliked
                      if (food.disliked.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        ...food.disliked.map((item) => Padding(
                              padding: const EdgeInsets.only(bottom: 2),
                              child: Row(children: [
                                const Icon(Icons.thumb_down,
                                    size: 14, color: Colors.red),
                                const SizedBox(width: 6),
                                Text(item, style: const TextStyle(fontSize: 13)),
                              ]),
                            )),
                      ],
                    ],
                  ),
                )),
            const SizedBox(height: 8),
          ],

          // Overall liked
          if (foundEntry.liked.isNotEmpty) ...[
            const Text('Overall Liked',
                style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    color: Colors.green)),
            const SizedBox(height: 4),
            ...foundEntry.liked.map((item) => Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Row(children: [
                    const Icon(Icons.thumb_up, size: 16, color: Colors.green),
                    const SizedBox(width: 8),
                    Text(item),
                  ]),
                )),
            const SizedBox(height: 16),
          ],

          // Overall disliked
          if (foundEntry.disliked.isNotEmpty) ...[
            const Text('Overall Disliked',
                style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    color: Colors.red)),
            const SizedBox(height: 4),
            ...foundEntry.disliked.map((item) => Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Row(children: [
                    const Icon(Icons.thumb_down, size: 16, color: Colors.red),
                    const SizedBox(width: 8),
                    Text(item),
                  ]),
                )),
            const SizedBox(height: 16),
          ],

          // Visit tags
          if (foundEntry.allTags.isNotEmpty) ...[
            const Text('Tags',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: foundEntry.allTags
                  .map((tag) => Chip(
                        label: Text(tag, style: const TextStyle(fontSize: 12)),
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        padding: EdgeInsets.zero,
                        visualDensity: VisualDensity.compact,
                      ))
                  .toList(),
            ),
            const SizedBox(height: 16),
          ],

          // Notes
          if (foundEntry.notes.isNotEmpty) ...[
            const Text('Notes',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            const SizedBox(height: 4),
            Text(foundEntry.notes),
          ],
        ],
      ),
    );
  }
}