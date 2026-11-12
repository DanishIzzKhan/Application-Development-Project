import 'package:flutter/material.dart';

class O16SettingsScreen extends StatefulWidget {
  final VoidCallback? onLogout;

  const O16SettingsScreen({super.key, this.onLogout});

  @override
  State<O16SettingsScreen> createState() => _O16SettingsScreenState();
}

class _O16SettingsScreenState extends State<O16SettingsScreen> {
  static const Color _dark = Color(0xFF262626);
  static const Color _muted = Color(0xFF6B6B6B);
  static const Color _border = Color(0xFFD0D0D0);

  final _defaultPriceController = TextEditingController(text: 'RM 8.00');
  final _gracePeriodController = TextEditingController(text: '5 min');
  final _lateChargeController = TextEditingController(text: 'RM 10.00');

  bool _autoChargeLate = true;
  bool _notifyOverdue = true;
  bool _notifyLeavesPark = true;
  bool _notifyLostSignal = true;

  @override
  void dispose() {
    _defaultPriceController.dispose();
    _gracePeriodController.dispose();
    _lateChargeController.dispose();
    super.dispose();
  }

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
          'Settings',
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
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Shop Profile Card
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _border, width: 1.2),
              ),
              child: Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: const BoxDecoration(
                      color: Color(0xFFEDEDED),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.storefront_outlined,
                      color: _dark,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 14),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'ISYGEAR VENTURES',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: _dark,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Owner · Kulai Park',
                          style: TextStyle(fontSize: 12.5, color: _muted),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Pricing rules
            const Text(
              'Pricing rules',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: _dark,
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Default price per 20 minutes',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: _dark,
              ),
            ),
            const SizedBox(height: 6),
            TextField(
              controller: _defaultPriceController,
              style: const TextStyle(fontSize: 14, color: _dark),
              decoration: _inputDecoration(),
            ),
            const SizedBox(height: 14),

            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Grace period',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: _dark,
                        ),
                      ),
                      const SizedBox(height: 6),
                      TextField(
                        controller: _gracePeriodController,
                        style: const TextStyle(fontSize: 14, color: _dark),
                        decoration: _inputDecoration(),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Late charge / 20 min',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: _dark,
                        ),
                      ),
                      const SizedBox(height: 6),
                      TextField(
                        controller: _lateChargeController,
                        style: const TextStyle(fontSize: 14, color: _dark),
                        decoration: _inputDecoration(),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Auto-charge late returns',
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                    color: _dark,
                  ),
                ),
                Switch(
                  value: _autoChargeLate,
                  activeColor: Colors.white,
                  activeTrackColor: _dark,
                  onChanged: (val) => setState(() => _autoChargeLate = val),
                ),
              ],
            ),
            const SizedBox(height: 8),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Stop auto-charging after',
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                    color: _dark,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 7,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: _dark, width: 1.2),
                  ),
                  child: const Text(
                    '3 blocks (1 hr)',
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: _dark,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Notifications
            const Text(
              'Notifications',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: _dark,
              ),
            ),
            const SizedBox(height: 10),
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _border, width: 1.2),
              ),
              child: Column(
                children: [
                  _buildSwitchRow(
                    'Overdue rentals',
                    _notifyOverdue,
                    (v) => setState(() => _notifyOverdue = v),
                  ),
                  const Divider(height: 1, color: _border),
                  _buildSwitchRow(
                    'Vehicle leaves the park',
                    _notifyLeavesPark,
                    (v) => setState(() => _notifyLeavesPark = v),
                  ),
                  const Divider(height: 1, color: _border),
                  _buildSwitchRow(
                    'Lost location signal',
                    _notifyLostSignal,
                    (v) => setState(() => _notifyLostSignal = v),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Log out button
            SizedBox(
              width: double.infinity,
              height: 46,
              child: OutlinedButton.icon(
                onPressed: widget.onLogout ??
                    () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Logged out')),
                      );
                    },
                icon: const Icon(Icons.logout, color: _dark, size: 18),
                label: const Text(
                  'Log out',
                  style: TextStyle(
                    color: _dark,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: _border, width: 1.2),
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

  InputDecoration _inputDecoration() {
    return InputDecoration(
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: _border, width: 1.2),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: _dark, width: 1.5),
      ),
    );
  }

  Widget _buildSwitchRow(
    String label,
    bool value,
    ValueChanged<bool> onChanged,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w600,
              color: _dark,
            ),
          ),
          Switch(
            value: value,
            activeColor: Colors.white,
            activeTrackColor: _dark,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}
