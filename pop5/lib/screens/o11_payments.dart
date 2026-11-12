import 'package:flutter/material.dart';

class O11PaymentsScreen extends StatelessWidget {
  const O11PaymentsScreen({super.key});

  static const Color _dark = Color(0xFF262626);
  static const Color _muted = Color(0xFF6B6B6B);
  static const Color _border = Color(0xFFD0D0D0);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: _dark),
          onPressed: () => Navigator.pop(context),
        ),
        titleSpacing: 0,
        title: const Text(
          'Payments',
          style: TextStyle(
            color: _dark,
            fontSize: 20,
            fontWeight: FontWeight.w700,
          ),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: const Color(0xFFEAEAEA)),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top KPI Cards
            Row(
              children: [
                Expanded(child: _buildSummaryCard('RM 180', 'Today')),
                const SizedBox(width: 12),
                Expanded(child: _buildSummaryCard('RM 1,420', 'This month')),
              ],
            ),
            const SizedBox(height: 18),

            // Failed auto-charges
            const Text(
              'Failed auto-charges',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: _dark,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _border, width: 1.2),
              ),
              child: Row(
                children: [
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Scooter S02 · mei_ling',
                          style: TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w700,
                            color: _dark,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Card declined · RM 10.00',
                          style: TextStyle(fontSize: 12, color: _muted),
                        ),
                      ],
                    ),
                  ),
                  _buildBadge('FAILED', filled: false),
                  const SizedBox(width: 8),
                  _buildSmallDarkButton(
                    'Collect',
                    onTap: () => _showSnack(context, 'Collecting RM 10.00...'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),

            // Waiting for confirmation
            const Text(
              'Waiting for confirmation',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: _dark,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _border, width: 1.2),
              ),
              child: Row(
                children: [
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Scooter S01 · ahmad_rides',
                          style: TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w700,
                            color: _dark,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Pay at counter · RM 30.00',
                          style: TextStyle(fontSize: 12, color: _muted),
                        ),
                      ],
                    ),
                  ),
                  _buildSmallDarkButton(
                    'Open',
                    onTap: () =>
                        _showSnack(context, 'Opening counter payment...'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),

            // Recent payments
            const Text(
              'Recent payments',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: _dark,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _border, width: 1.2),
              ),
              child: Column(
                children: [
                  _buildPaymentRow(
                    title: 'Scooter S02 · late charge',
                    subtitle: 'Visa •••• 4417 · RM 10.00',
                    badge: 'AUTO',
                    filledBadge: true,
                  ),
                  const Divider(height: 1, color: _border),
                  _buildPaymentRow(
                    title: 'Bicycle B02 · ahmad_rides',
                    subtitle: 'Touch \'n Go · RM 24.00',
                    badge: 'PAID',
                  ),
                  const Divider(height: 1, color: _border),
                  _buildPaymentRow(
                    title: 'Bicycle B04 · Walk-in',
                    subtitle: 'Cash · RM 16.00',
                    badge: 'PAID',
                  ),
                  const Divider(height: 1, color: _border),
                  _buildPaymentRow(
                    title: 'Scooter S02 · mei_ling',
                    subtitle: 'Bank QR · RM 20.00',
                    badge: 'PAID',
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Record cash payment button
            SizedBox(
              width: double.infinity,
              height: 46,
              child: OutlinedButton.icon(
                onPressed: () =>
                    _showSnack(context, 'Record cash payment dialog'),
                icon: const Icon(Icons.add, color: _dark, size: 20),
                label: const Text(
                  'Record cash payment',
                  style: TextStyle(
                    color: _dark,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: _dark, width: 1.4),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryCard(String value, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _border, width: 1.2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: _dark,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(fontSize: 12, color: _muted),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentRow({
    required String title,
    required String subtitle,
    required String badge,
    bool filledBadge = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: _dark,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: const TextStyle(fontSize: 12, color: _muted),
                ),
              ],
            ),
          ),
          _buildBadge(badge, filled: filledBadge),
        ],
      ),
    );
  }

  Widget _buildBadge(String label, {required bool filled}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: filled ? _dark : Colors.white,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: _dark, width: 1.2),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: filled ? Colors.white : _dark,
        ),
      ),
    );
  }

  Widget _buildSmallDarkButton(String label, {required VoidCallback onTap}) {
    return SizedBox(
      height: 34,
      child: ElevatedButton(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: _dark,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
        child: Text(
          label,
          style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }

  void _showSnack(BuildContext context, String text) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(text), duration: const Duration(seconds: 1)),
    );
  }
}
