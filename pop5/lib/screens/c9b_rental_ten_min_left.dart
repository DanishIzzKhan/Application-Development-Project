import 'package:flutter/material.dart';

import 'c9_active_rental.dart';

/// C9b is now a look of C9 (it switches by itself at 10 minutes left).
/// This wrapper only keeps older imports working.
class RentalTenMinLeftScreen extends StatelessWidget {
  final String bookingId;
  const RentalTenMinLeftScreen({super.key, required this.bookingId});

  @override
  Widget build(BuildContext context) =>
      ActiveRentalScreen(bookingId: bookingId);
}