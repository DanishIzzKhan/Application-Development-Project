import 'package:flutter/material.dart';

import 'c9_active_rental.dart';

/// C9c is now a look of C9 (it switches by itself when the rental is overdue).
/// This wrapper only keeps older imports working.
class RentalOverdueScreen extends StatelessWidget {
  final String bookingId;
  const RentalOverdueScreen({super.key, required this.bookingId});

  @override
  Widget build(BuildContext context) =>
      ActiveRentalScreen(bookingId: bookingId);
}