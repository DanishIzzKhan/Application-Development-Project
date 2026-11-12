import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/customer.dart';
import '../models/rental.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/rental_widgets.dart';

/// O3c Customer details — opened from "View customer details ›" on O5 / O6.
/// App customers: profile, contact, IC (security record) and rental history.
/// Walk-ins: name, contact number, and the IC photo if one was taken on O4.
class CustomerDetailsScreen extends StatelessWidget {
  final OwnerRental rental; // the rental the owner came from
  const CustomerDetailsScreen({super.key, required this.rental});

  /// Until url_launcher is added (group OK needed), copy the number so the
  /// owner can paste it into the phone app.
  void _call(BuildContext context, String phone) {
    // Later: launchUrl(Uri(scheme: 'tel', path: phone)) opens the dialer.
    Clipboard.setData(ClipboardData(text: phone));
    showTopNotice(context,
        title: 'Number copied: $phone',
        lines: ['Paste it into the phone app to call.'],
        type: NoticeType.success);
  }

  @override
  Widget build(BuildContext context) {
    // Sample data for now. Later: Api.fetchCustomer(...).
    final c = sampleCustomerFor(rental);

    return Scaffold(
      appBar: const AppHeader(title: 'Customer details'),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _profileCard(c),
          const SizedBox(height: 12),
          _contactCard(context, c),
          // IC on file: app customers from sign-up (C2b); walk-ins only if
          // the owner took the (optional) photo on O4.
          if (!c.isWalkIn || rental.walkInIcPhotoTaken) ...[
            const SizedBox(height: 12),
            _icCard(context, c),
          ],
          if (!c.isWalkIn) ...[
            const SizedBox(height: 18),
            const SectionTitle('Rentals'),
            const SizedBox(height: 4),
            _historyRow(
              title: '${rental.vehicleName} · ${rental.bookingCode}',
              line: 'Today · ${_statusLabel(rental)}',
              badge: const RentalBadge('CURRENT'),
              // Back to the rental screen the owner came from (O5 / O6).
              onTap: () => Navigator.of(context).pop(),
            ),
            for (final h in c.history)
              _historyRow(
                title: h.title,
                line: h.line,
                badge: h.badge == null
                    ? null
                    : RentalBadge(h.badge!, filled: false),
              ),
          ],
        ],
      ),
    );
  }

  String _statusLabel(OwnerRental r) => switch (r.status) {
        'pending_payment' => 'waiting for payment',
        'ready' => 'ready for handover',
        'active' => r.isReturned ? 'returned, not ended yet' : 'on rental',
        _ => r.status,
      };

  // ---------- Cards ----------

  Widget _profileCard(CustomerProfile c) {
    return OutlinedCard(
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: const BoxDecoration(
                color: AppColors.surface, shape: BoxShape.circle),
            child: const Icon(Icons.person_outline,
                size: 30, color: AppColors.text2),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(c.displayName, style: inter(16, weight: FontWeight.w700)),
                if (c.fullName != null)
                  Text(c.fullName!, style: inter(13, color: AppColors.text2)),
                const SizedBox(height: 2),
                Text(
                  c.isWalkIn
                      ? 'Walk-in customer'
                      : 'Customer since ${formatDate(c.since!)} · ${c.rentalCount} rentals',
                  style: inter(12, color: AppColors.hint),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _contactCard(BuildContext context, CustomerProfile c) {
    return OutlinedCard(
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(c.phone, style: inter(15, weight: FontWeight.w600)),
                    Text('Phone', style: inter(12, color: AppColors.text2)),
                  ],
                ),
              ),
              SmallButton(
                  label: 'Call', onPressed: () => _call(context, c.phone)),
            ],
          ),
          if (c.email != null) ...[
            const Divider(color: AppColors.divider, thickness: 1.5, height: 24),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(c.email!, style: inter(15, weight: FontWeight.w600)),
                      Text('Email', style: inter(12, color: AppColors.text2)),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _icCard(BuildContext context, CustomerProfile c) {
    return OutlinedCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.shield_outlined, color: AppColors.ink, size: 22),
              const SizedBox(width: 8),
              Expanded(
                child: Text('IC on file (security record)',
                    style: inter(15, weight: FontWeight.w600)),
              ),
              SmallButton(
                label: 'View IC',
                primary: false,
                onPressed: () => showIcViewer(context, c.displayName,
                    front: rental.walkInIcFront, back: rental.walkInIcBack),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Open only when needed, e.g. if a vehicle is lost, stolen or '
            'damaged. Every view is recorded.',
            style: inter(12, color: AppColors.hint),
          ),
        ],
      ),
    );
  }

  Widget _historyRow({
    required String title,
    required String line,
    Widget? badge,
    VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: const BoxDecoration(
          border:
              Border(bottom: BorderSide(color: AppColors.divider, width: 1.5)),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: inter(15, weight: FontWeight.w600)),
                  const SizedBox(height: 3),
                  Text(line, style: inter(13, color: AppColors.text2)),
                ],
              ),
            ),
            if (badge != null) badge,
          ],
        ),
      ),
    );
  }
}
