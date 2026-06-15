import 'package:flutter/material.dart';
import '../models/restaurant.dart';

class RestaurantCard extends StatelessWidget {
  final Restaurant restaurant;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final VoidCallback? onFavoriteToggle;

  const RestaurantCard({
    super.key,
    required this.restaurant,
    required this.onTap,
    this.onLongPress,
    this.onFavoriteToggle,
  });

  @override
  Widget build(BuildContext context) {
    final lastVisit = restaurant.mostRecentEntry;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: ListTile(
        onLongPress: onLongPress,
        contentPadding: const EdgeInsets.only(left: 12, right: 4, top: 4, bottom: 4),
        title: Text(
          restaurant.name,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (restaurant.address != null) Text(restaurant.address!),
            const SizedBox(height: 4),
            Row(
              children: [
                const Icon(Icons.star, size: 16, color: Colors.amber),
                Text(' ${restaurant.averageRating.toStringAsFixed(1)}'),
                const SizedBox(width: 12),
                Text('Visited ${restaurant.visitCount}x'),
              ],
            ),
            if (lastVisit != null)
              Text(
                'Last visit: ${lastVisit.date.month}/${lastVisit.date.day}/${lastVisit.date.year}',
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
            if (restaurant.spendRangeLabel != null)
              Text(
                restaurant.spendRangeLabel!,
                style: const TextStyle(fontSize: 12, color: Colors.teal),
              ),
          ],
        ),
        trailing: IconButton(
          icon: Icon(
            restaurant.isFavorite ? Icons.favorite : Icons.favorite_border,
            color: restaurant.isFavorite ? Colors.red : Colors.grey,
          ),
          onPressed: onFavoriteToggle,
          tooltip: restaurant.isFavorite ? 'Remove from favorites' : 'Add to favorites',
        ),
        onTap: onTap,
      ),
    );
  }
}