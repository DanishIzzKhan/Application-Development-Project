import 'package:flutter/material.dart';
import '../theme.dart';
import 'o10_add_vehicle.dart';

/// ADP-117: O9 Vehicles Management Screen (Figma Wireframe Version)
class O9VehiclesScreen extends StatefulWidget {
  const O9VehiclesScreen({super.key});

  @override
  State<O9VehiclesScreen> createState() => _O9VehiclesScreenState();
}

class _O9VehiclesScreenState extends State<O9VehiclesScreen> {
  String _selectedCategory = 'All';

  final _vehicles = [
    {
      'name': 'Bicycle B01',
      'type': 'Bicycles',
      'detail': 'Bicycle • RM 10.00 / 20 min',
      'status': 'ON RENTAL'
    },
    {
      'name': 'Bicycle B02',
      'type': 'Bicycles',
      'detail': 'Bicycle • RM 10.00 / 20 min',
      'status': 'AVAILABLE'
    },
    {
      'name': 'Bicycle B03',
      'type': 'Bicycles',
      'detail': 'Bicycle • RM 10.00 / 20 min',
      'status': 'UNDER REPAIR'
    },
    {
      'name': 'Scooter S01',
      'type': 'Scooters',
      'detail': 'Scooter • RM 10.00 / 20 min',
      'status': 'AVAILABLE'
    },
    {
      'name': 'Scooter S02',
      'type': 'Scooters',
      'detail': 'Scooter • RM 10.00 / 20 min',
      'status': 'ON RENTAL'
    },
  ];

  @override
  Widget build(BuildContext context) {
    final filteredVehicles = _selectedCategory == 'All'
        ? _vehicles
        : _vehicles.where((v) => v['type'] == _selectedCategory).toList();

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
            icon: const Icon(Icons.add, color: AppColors.ink, size: 26),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const O10AddVehicleScreen()),
              );
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: Row(
                children: [
                  _buildFilterChip('All'),
                  const SizedBox(width: 8),
                  _buildFilterChip('Bicycles'),
                  const SizedBox(width: 8),
                  _buildFilterChip('Scooters'),
                ],
              ),
            ),
            const SizedBox(height: 8),
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
                    return ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 4),
                      leading: const Icon(Icons.pedal_bike,
                          color: AppColors.dark, size: 24),
                      title: Text(
                        item['name']!,
                        style: inter(15,
                            weight: FontWeight.bold, color: AppColors.ink),
                      ),
                      subtitle: Text(
                        item['detail']!,
                        style: inter(12, color: AppColors.hint),
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _buildWireframeBadge(item['status']!),
                          const SizedBox(width: 6),
                          const Icon(Icons.chevron_right,
                              size: 18, color: AppColors.hint),
                        ],
                      ),
                      onTap: () {},
                    );
                  },
                ),
              ),
            ),
            const SizedBox(height: 24),
          ],
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
    bool isDark = status == 'UNDER REPAIR';
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
