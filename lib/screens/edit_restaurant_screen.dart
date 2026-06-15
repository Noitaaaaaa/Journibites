import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import '../data/journibites_repository.dart';
import '../data/tag_definitions.dart';
import '../models/restaurant.dart';
import '../widgets/tag_selector.dart';

class EditRestaurantScreen extends StatefulWidget {
  final String restaurantId;

  const EditRestaurantScreen({super.key, required this.restaurantId});

  @override
  State<EditRestaurantScreen> createState() => _EditRestaurantScreenState();
}

class _EditRestaurantScreenState extends State<EditRestaurantScreen> {
  final _repository = JourniBitesRepository();

  late TextEditingController _nameController;
  late TextEditingController _addressController;

  int _priceRange = 1;
  Map<String, List<String>> _selectedTags = {};
  bool _loading = true;
  bool _saving = false;
  bool _locating = false;
  Restaurant? _restaurant;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _addressController = TextEditingController();
    _loadData();
  }

  Future<void> _loadData() async {
    final restaurant = await _repository.getRestaurantById(widget.restaurantId);
    if (!mounted) return;
    if (restaurant != null) {
      _nameController.text = restaurant.name;
      _addressController.text = restaurant.address ?? '';
      setState(() {
        _restaurant = restaurant;
        _priceRange = restaurant.priceRange;
        _selectedTags = Map.from(restaurant.tags);
        _loading = false;
      });
    }
  }

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

  Future<void> _save() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a restaurant name.')),
      );
      return;
    }

    setState(() => _saving = true);

    final updated = _restaurant!.copyWith(
      name: name,
      address: _addressController.text.trim().isEmpty
          ? null
          : _addressController.text.trim(),
      tags: _selectedTags,
      priceRange: _priceRange,
    );

    await _repository.updateRestaurant(updated);
    dataVersionNotifier.value++;

    if (!mounted) return;
    setState(() => _saving = false);
    context.pop();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Edit Restaurant')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _nameController,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(
              labelText: 'Restaurant Name *',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
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
          const Text('Price Range', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Row(
            children: List.generate(4, (index) {
              final value = index + 1;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  label: Text('₱' * value),
                  selected: _priceRange == value,
                  onSelected: (_) => setState(() => _priceRange = value),
                ),
              );
            }),
          ),
          const SizedBox(height: 20),
          TagSelector(
            tagType: 'restaurant',
            sectionTitle: '🍽️ Restaurant Tags',
            categories: restaurantTagCategories,
            selected: _selectedTags,
            onChanged: (updated) => setState(() => _selectedTags = updated),
          ),
          const SizedBox(height: 32),
          ElevatedButton(
            onPressed: _saving ? null : _save,
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
            child: _saving
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Save Changes', style: TextStyle(fontSize: 16)),
          ),
        ],
      ),
    );
  }
}