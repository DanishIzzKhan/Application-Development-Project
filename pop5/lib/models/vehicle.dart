class Vehicle {
  final String id;
  final String name; // e.g. "Bicycle B01"
  final String type; // 'bicycle' | 'scooter'
  final double pricePer20Min;
  final String status; // 'available' | 'rented' | 'maintenance'
  final String? photoUrl;

  const Vehicle({
    required this.id,
    required this.name,
    required this.type,
    required this.pricePer20Min,
    required this.status,
    this.photoUrl,
  });

  bool get isAvailable => status == 'available';
  String get typeLabel => type == 'scooter' ? 'Scooter' : 'Bicycle';
  String get statusLabel => switch (status) {
        'available' => 'Available',
        'rented' => 'Rented',
        _ => 'Under maintenance',
      };
  String get priceLabel => 'RM ${pricePer20Min.toStringAsFixed(2)}';

  factory Vehicle.fromMap(Map<String, dynamic> m) => Vehicle(
        id: m['id'] as String,
        name: m['name'] as String,
        type: m['type'] as String,
        pricePer20Min: (m['price_per_20min'] as num).toDouble(),
        status: m['status'] as String,
        photoUrl: m['photo_url'] as String?,
      );
}

enum VehicleSort { lowestPrice, name }

/// State of the C4 filter panel. Defaults match the wireframe.
class VehicleFilter {
  final String? type; // null = All
  final bool availableOnly;
  final VehicleSort sort;

  const VehicleFilter({
    this.type,
    this.availableOnly = true,
    this.sort = VehicleSort.lowestPrice,
  });

  String get typeLabel => switch (type) {
        'bicycle' => 'Bicycles',
        'scooter' => 'Scooters',
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