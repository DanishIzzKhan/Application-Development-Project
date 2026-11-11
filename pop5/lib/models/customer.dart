import 'rental.dart';

/// One line in the O3c "Rentals" history list.
class PastRental {
  final String title; // e.g. "Scooter S02"
  final String line; // e.g. "15 Oct · returned 25 min late"
  final String? badge; // 'LATE' | 'ISSUE' | null
  const PastRental(this.title, this.line, {this.badge});
}

/// What the owner sees on O3c Customer details.
/// App customers come from the `users` table; walk-ins only have the
/// name and phone saved on the rental (walk_in_name / walk_in_phone).
class CustomerProfile {
  final String displayName; // username, or the walk-in's name
  final String? fullName; // as in IC (app customers only)
  final String phone;
  final String? email;
  final DateTime? since; // users.created_at
  final int rentalCount;
  final List<PastRental> history;
  final bool isWalkIn;

  const CustomerProfile({
    required this.displayName,
    required this.phone,
    this.fullName,
    this.email,
    this.since,
    this.rentalCount = 0,
    this.history = const [],
    this.isWalkIn = false,
  });
}

/// Sample profile for the customer of [r] (AppConfig.uiPreviewMode).
/// Later: Api.fetchCustomer(rental.customerId) reads users + past rentals.
CustomerProfile sampleCustomerFor(OwnerRental r) {
  if (r.isWalkIn) {
    return CustomerProfile(
      displayName: r.customerName.replaceFirst('Walk-in: ', ''),
      phone: r.walkInPhone ?? '012-345 6789',
      isWalkIn: true,
    );
  }
  const fullNames = {
    'ahmad_rides': 'Ahmad bin Ismail',
    'mei_ling': 'Tan Mei Ling',
  };
  return CustomerProfile(
    displayName: r.customerName,
    fullName: fullNames[r.customerName] ?? 'Full name as in IC',
    phone: '012-345 6789',
    email: '${r.customerName}@email.com',
    since: DateTime(2026, 3, 14),
    rentalCount: 12,
    history: const [
      PastRental('Road bike R01', '28 Oct · 40 min · returned on time'),
      PastRental('Scooter S02', '15 Oct · returned 25 min late', badge: 'LATE'),
      PastRental('MTB M01', '2 Oct · reported: brakes feel loose',
          badge: 'ISSUE'),
    ],
  );
}

/// 2026-03-14 -> "14 Mar 2026"
String formatDate(DateTime d) {
  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  return '${d.day} ${months[d.month - 1]} ${d.year}';
}
