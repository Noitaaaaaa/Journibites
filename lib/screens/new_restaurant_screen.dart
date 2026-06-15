import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import '../data/journibites_repository.dart';
import '../data/tag_definitions.dart';
import '../models/restaurant.dart';
import '../widgets/tag_selector.dart';

class NewRestaurantScreen extends StatefulWidget {
  const NewRestaurantScreen({super.key});

  @override
  State<NewRestaurantScreen> createState() => _NewRestaurantScreenState();
}

class _NewRestaurantScreenState extends State<NewRestaurantScreen> {
  final _repository = JourniBitesRepository();
  static const _uuid = Uuid();

  final _nameController = TextEditingController();
  final _addressController = TextEditingController();

  int _priceRange = 1;
  Map<String, List<String>> _selectedTags = {};
  bool _saving = false;
  bool _locating = false;

  @override
  void dispose() {
    _nameController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  Future<void> _fillCurrentLocation() async {
    setState(() => _locating = true);

    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          _showLocationError('Location permission denied.');
          return;
        }
      }
      if (permission == LocationPermission.deniedForever) {
        _showLocationError('Location permission permanently denied. Enable it in settings.');
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      final placemarks = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );

      if (!mounted) return;

      if (placemarks.isNotEmpty) {
        final p = placemarks.first;
        final address = [p.street, p.locality, p.administrativeArea]
            .where((s) => s != null && s.isNotEmpty)
            .join(', ');
        _addressController.text = address;
      } else {
        _showLocationError('Could not determine address from location.');
      }
    } catch (e) {
      _showLocationError('Could not get location. Check permissions.');
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  void _showLocationError(String message) {
    if (!mounted) return;
    setState(() => _locating = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Future<void> _next() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a restaurant name.')),
      );
      return;
    }

    setState(() => _saving = true);

    final restaurantId = _uuid.v4();
    final address = _addressController.text.trim();
    final restaurant = Restaurant(
      id: restaurantId,
      name: name,
      address: address.isEmpty ? null : address,
      tags: _selectedTags,
      priceRange: _priceRange,
    );

    await _repository.insertRestaurant(restaurant);
    dataVersionNotifier.value++;

    if (!mounted) return;
setState(() => _saving = false);

final navigator = Navigator.of(context);
final router = GoRouter.of(context);

await showDialog(
  context: context,
  barrierDismissible: false,
  builder: (ctx) => AlertDialog(
    title: const Text('Restaurant Added!'),
    content: Text('"$name" has been saved. What would you like to do next?'),
    actions: [
      TextButton.icon(
        icon: const Icon(Icons.home_outlined),
        label: const Text('Go to Home'),
        onPressed: () {
          navigator.pop();
          router.go('/');
        },
      ),
      ElevatedButton.icon(
        icon: const Icon(Icons.edit_note),
        label: const Text('Log a Visit'),
        onPressed: () {
          navigator.pop();
          router.pushReplacement(
            '/add-entry?restaurantId=$restaurantId&restaurantName=${Uri.encodeComponent(name)}',
          );
        },
      ),
    ],
  ),
);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('New Restaurant')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Name
          TextField(
            controller: _nameController,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(
              labelText: 'Restaurant Name *',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),

          // Address
          TextField(
            controller: _addressController,
            decoration: InputDecoration(
              labelText: 'Address (optional)',
              border: const OutlineInputBorder(),
              suffixIcon: _locating
                  ? const Padding(
                      padding: EdgeInsets.all(12),
                      child: SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    )
                  : IconButton(
                      icon: const Icon(Icons.my_location),
                      tooltip: 'Use current location',
                      onPressed: _fillCurrentLocation,
                    ),
            ),
          ),
          const SizedBox(height: 20),

          // Price range
          const Text('Price Range', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Row(
            children: List.generate(4, (index) {
              final value = index + 1;
              final selected = _priceRange == value;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  label: Text('₱' * value),
                  selected: selected,
                  onSelected: (_) => setState(() => _priceRange = value),
                ),
              );
            }),
          ),
          const SizedBox(height: 20),

          // Restaurant tags
          TagSelector(
            tagType: 'restaurant',
            sectionTitle: '🍽️ Restaurant Tags',
            categories: restaurantTagCategories,
            selected: _selectedTags,
            onChanged: (updated) => setState(() => _selectedTags = updated),
          ),
          const SizedBox(height: 32),

          // Next button
          ElevatedButton(
            onPressed: _saving ? null : _next,
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
            child: _saving
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text(
                    'Next: Log Your Visit →',
                    style: TextStyle(fontSize: 16),
                  ),
          ),
        ],
      ),
    );
  }
}