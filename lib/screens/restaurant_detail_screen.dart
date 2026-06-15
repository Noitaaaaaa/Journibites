import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../data/journibites_repository.dart';
import '../models/restaurant.dart';

class RestaurantDetailScreen extends StatefulWidget {
  final String restaurantId;

  const RestaurantDetailScreen({super.key, required this.restaurantId});

  @override
  State<RestaurantDetailScreen> createState() => _RestaurantDetailScreenState();
}

class _RestaurantDetailScreenState extends State<RestaurantDetailScreen> {
  final _repository = JourniBitesRepository();
  Restaurant? _restaurant;
  bool _loading = true;

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
    final restaurant = await _repository.getRestaurantById(widget.restaurantId);
    if (!mounted) return;
    setState(() {
      _restaurant = restaurant;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final restaurant = _restaurant;
    if (restaurant == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Not Found')),
        body: const Center(child: Text('This restaurant could not be found.')),
      );
    }

    // Sort entries newest first
    final sortedEntries = [...restaurant.entries]
      ..sort((a, b) => b.date.compareTo(a.date));

    return Scaffold(
      appBar: AppBar(title: Text(restaurant.name)),
      body: ListView(
        children: [
          // Restaurant info header
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (restaurant.address != null)
                  Row(
                    children: [
                      const Icon(Icons.location_on, size: 18, color: Colors.grey),
                      const SizedBox(width: 4),
                      Expanded(child: Text(restaurant.address!)),
                    ],
                  ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(Icons.star, size: 18, color: Colors.amber),
                    Text(' ${restaurant.averageRating.toStringAsFixed(1)} average'),
                    const SizedBox(width: 16),
                    Text('${restaurant.visitCount} visit${restaurant.visitCount == 1 ? '' : 's'}'),
                  ],
                ),
              ],
            ),
          ),
          const Divider(),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Text(
              'Your Visits',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
          ),
          if (sortedEntries.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Text(
                'No visits logged yet.',
                style: TextStyle(color: Colors.grey),
              ),
            ),
          ...sortedEntries.map((entry) => Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: ListTile(
        title: Text('${entry.date.month}/${entry.date.day}/${entry.date.year}'),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (entry.foodItems.isNotEmpty)
              Text('Ordered: ${entry.foodItems.map((f) => f.name).where((n) => n.isNotEmpty).join(', ')}'),
            Row(
              children: [
                const Icon(Icons.star, size: 14, color: Colors.amber),
                Text(' ${entry.rating}'),
              ],
            ),
          ],
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => context.push('/entry/${entry.id}'),
        onLongPress: () => _showEntryOptions(context, entry.id),
      ),
    )),
        ],
      ),
    );
  }
  void _showEntryOptions(BuildContext context, String entryId) {
  showModalBottomSheet(
    context: context,
    builder: (context) => SafeArea(
      child: Wrap(
        children: [
          ListTile(
            leading: const Icon(Icons.edit),
            title: const Text('Edit Entry'),
            onTap: () {
              Navigator.pop(context);
              context.push('/edit-entry/$entryId').then((_) => _loadData());
            },
          ),
          ListTile(
            leading: const Icon(Icons.delete, color: Colors.red),
            title: const Text('Delete Entry',
                style: TextStyle(color: Colors.red)),
            onTap: () {
              Navigator.pop(context);
              _confirmDeleteEntry(context, entryId);
            },
          ),
        ],
      ),
    ),
  );
}

void _confirmDeleteEntry(BuildContext context, String entryId) {
  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Delete Entry'),
      content: const Text(
          'Are you sure you want to delete this entry? This cannot be undone.'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () async {
            Navigator.pop(context);
            await _repository.deleteEntry(entryId);
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
}