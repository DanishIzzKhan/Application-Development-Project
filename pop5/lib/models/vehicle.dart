/// Maps to the `vehicles` table.
class Vehicle {
  final String id; // e.g. 'BK-01', 'SC-02'
  final String type; // 'Bicycle' | 'Scooter'
  final double pricePer20Min; // vehicles.rate_per_block
  final String status; // 'Available' | 'Rented' | 'Maintenance'
  final String? photoUrl;

  const Vehicle({
    required this.id,
    required this.type,
    required this.pricePer20Min,
    required this.status,
    this.photoUrl,
  });

  String get name => '$type $id'; // e.g. "Bicycle BK-01"
  bool get isAvailable => status == 'Available';
  String get typeLabel => type;
  String get statusLabel => switch (status) {
        'Available' => 'Available',
        'Rented' => 'Rented',
        _ => 'Under maintenance',
      };
  String get priceLabel => 'RM ${pricePer20Min.toStringAsFixed(2)}';

  factory Vehicle.fromMap(Map<String, dynamic> m) => Vehicle(
        id: m['id'] as String,
        type: m['type'] as String,
        pricePer20Min: (m['rate_per_block'] as num).toDouble(),
        status: m['status'] as String,
        photoUrl: m['photo_url'] as String?,
      );
}

enum VehicleSort { lowestPrice, name }

/// State of the C4 filter panel. Defaults match the wireframe.
class VehicleFilter {
  final String? type; // null = All, else 'Bicycle' / 'Scooter'
  final bool availableOnly;
  final VehicleSort sort;

  const VehicleFilter({
    this.type,
    this.availableOnly = true,
    this.sort = VehicleSort.lowestPrice,
  });

  String get typeLabel => switch (type) {
        'Bicycle' => 'Bicycles',
        'Scooter' => 'Scooters',
        _ => 'All types',
      };

  VehicleFilter copyWith({
    String? type,
    bool clearType = false,
    bool? availableOnly,
    VehicleSort? sort,
  }) =>
      VehicleFilter(
        type: clearType ? null : (type ?? this.type),
        availableOnly: availableOnly ?? this.availableOnly,
        sort: sort ?? this.sort,
      );
}
