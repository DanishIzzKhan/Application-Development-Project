import 'package:flutter/material.dart';
import '../models/vehicle.dart';
import '../services/api.dart';
import '../theme.dart';
import 'o10_add_vehicle.dart';

/// O9 Vehicles Management Screen (Connected to Supabase)
class O9VehiclesScreen extends StatefulWidget {
  const O9VehiclesScreen({super.key});

  @override
  State<O9VehiclesScreen> createState() => _O9VehiclesScreenState();
}

class _O9VehiclesScreenState extends State<O9VehiclesScreen> {
  String _selectedCategory = 'All';
  List<Vehicle> _vehicles = [];
  bool _loading = true;
  String? _error;

  final List<String> _categories = [
    'All',
    'Bicycles',
    'Scooters',
    'Pushbike',
    'Bubble Stick',
  ];

  @override
  void initState() {
    super.initState();
    _loadVehicles();
  }

  Future<void> _loadVehicles() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final list = await Api.fetchOwnerVehicles();
      if (mounted) {
        setState(() {
          _vehicles = list;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _loading = false;
        });
      }
    }
  }

  bool _matchesCategory(Vehicle v) {
    switch (_selectedCategory) {
      case 'Bicycles':
        return v.type == 'Bicycle';
      case 'Scooters':
        return v.type == 'Scooter';
      case 'Pushbike':
        return v.type == 'Pushbike';
      case 'Bubble Stick':
        return v.type == 'Bubble Stick';
      default:
        return true;
    }
  }

  String _badgeText(String status) {
    switch (status) {
      case 'Rented':
        return 'ON RENTAL';
      case 'Maintenance':
        return 'UNDER REPAIR';
      case 'Not in use':
        return 'NOT IN USE';
      default:
        return 'AVAILABLE';
    }
  }

  IconData _typeIcon(String type) {
    switch (type) {
      case 'Scooter':
        return Icons.electric_scooter;
      case 'Bubble Stick':
        return Icons.auto_awesome;
      default:
        return Icons.pedal_bike;
    }
  }

  Future<void> _openAddVehicle() async {
    final changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const O10AddVehicleScreen()),
    );
    if (changed == true && mounted) {
      await _loadVehicles();
    }
  }

  Future<void> _openEditVehicle(Vehicle vehicle) async {
    final changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => O10AddVehicleScreen(vehicle: vehicle),
      ),
    );
    if (changed == true && mounted) {
      await _loadVehicles();
    }
  }

  @override
  Widget build(BuildContext context) {
    final filteredVehicles = _vehicles.where(_matchesCategory).toList();

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(
          'Vehicles',
          style: inter(20, weight: FontWeight.bold, color: AppColors.ink),
        ),
        elevation: 0,
        backgroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: AppColors.ink, size: 22),
            onPressed: _loadVehicles,
          ),
          IconButton(
            icon: const Icon(Icons.add, color: AppColors.ink, size: 26),
            onPressed: _openAddVehicle,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadVehicles,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding:
                    const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                child: Row(
                  children: _categories.map((cat) {
                    return Padding(
                      padding: const EdgeInsets.only(right: 8.0),
                      child: _buildFilterChip(cat),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 8),
              if (_loading)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 48),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (_error != null)
                Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    children: [
                      Text(
                        'Failed to load vehicles:\n$_error',
                        textAlign: TextAlign.center,
                        style: inter(13, color: Colors.red),
                      ),
                      const SizedBox(height: 12),
                      OutlinedButton(
                        onPressed: _loadVehicles,
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              else if (filteredVehicles.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 48),
                  child: Center(
                    child: Text(
                      'No vehicles in this category',
                      style: inter(14, color: AppColors.hint),
                    ),
                  ),
                )
              else
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: Container(
                    decoration: BoxDecoration(
                      border: Border.all(color: AppColors.divider),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: filteredVehicles.length,
                      separatorBuilder: (context, index) =>
                          const Divider(height: 1, color: AppColors.divider),
                      itemBuilder: (context, index) {
                        final item = filteredVehicles[index];
                        final badge = _badgeText(item.status);
                        return ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 4),
                          leading: Icon(
                            _typeIcon(item.type),
                            color: AppColors.dark,
                            size: 24,
                          ),
                          title: Text(
                            item.name,
                            style: inter(15,
                                weight: FontWeight.bold, color: AppColors.ink),
                          ),
                          subtitle: Text(
                            '${item.type} • ${item.priceLabel} / 20 min • Late: ${item.latePriceLabel}',
                            style: inter(12, color: AppColors.hint),
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              _buildWireframeBadge(badge),
                              const SizedBox(width: 6),
                              const Icon(Icons.chevron_right,
                                  size: 18, color: AppColors.hint),
                            ],
                          ),
                          onTap: () => _openEditVehicle(item),
                        );
                      },
                    ),
                  ),
                ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFilterChip(String label) {
    final isSelected = _selectedCategory == label;
    return GestureDetector(
      onTap: () => setState(() => _selectedCategory = label),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.dark : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? AppColors.dark : AppColors.border,
          ),
        ),
        child: Text(
          label,
          style: inter(
            13,
            weight: isSelected ? FontWeight.w600 : FontWeight.w400,
            color: isSelected ? Colors.white : AppColors.ink,
          ),
        ),
      ),
    );
  }

  Widget _buildWireframeBadge(String status) {
    final isDark = status == 'UNDER REPAIR' || status == 'NOT IN USE';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: isDark ? AppColors.dark : Colors.transparent,
        border: Border.all(color: AppColors.dark, width: 1.2),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        status,
        style: inter(
          10,
          weight: FontWeight.bold,
          color: isDark ? Colors.white : AppColors.dark,
        ),
      ),
    );
  }
}
