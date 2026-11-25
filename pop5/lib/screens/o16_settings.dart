import 'package:flutter/material.dart';
import '../services/api.dart';

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
  static const Color _successGreen = Color(0xFF1E7E34);

  final _defaultPriceController = TextEditingController(text: 'RM 8.00');
  final _gracePeriodController = TextEditingController(text: '5 min');
  final _lateChargeController = TextEditingController(text: 'RM 10.00');

  int _autoChargeLimit = 3;
  bool _autoChargeLate = true;
  bool _notifyOverdue = true;
  bool _notifyLeavesPark = true;
  bool _notifyLostSignal = true;

  bool _loading = true;
  bool _saving = false;
  ScaffoldMessengerState? _messenger;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _messenger = ScaffoldMessenger.of(context);
  }

  @override
  void dispose() {
    final messenger = _messenger;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      messenger?.hideCurrentSnackBar();
    });
    _defaultPriceController.dispose();
    _gracePeriodController.dispose();
    _lateChargeController.dispose();
    super.dispose();
  }

  Future<void> _loadSettings() async {
    try {
      final data = await Api.fetchShopSettings();
      if (!mounted) return;
      final defaultRate =
          double.tryParse(data['default_rate']?.toString() ?? '') ?? 8.0;
      final graceMinutes =
          int.tryParse(data['grace_minutes']?.toString() ?? '') ?? 5;
      final lateRate =
          double.tryParse(data['late_rate']?.toString() ?? '') ?? 10.0;
      final limit =
          int.tryParse(data['auto_charge_limit']?.toString() ?? '') ?? 3;

      setState(() {
        _defaultPriceController.text = 'RM ${defaultRate.toStringAsFixed(2)}';
        _gracePeriodController.text = '$graceMinutes min';
        _lateChargeController.text = 'RM ${lateRate.toStringAsFixed(2)}';
        _autoChargeLimit = limit.clamp(1, 6);
        _autoChargeLate = data['auto_charge_late'] != false;
        _notifyOverdue = data['notify_overdue'] != false;
        _notifyLeavesPark = data['notify_leaves_park'] != false;
        _notifyLostSignal = data['notify_lost_signal'] != false;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      _showToast('Failed to load settings: $e', isError: true);
    }
  }

  double _parseCurrency(String raw, double fallback) {
    final cleaned = raw.replaceAll(RegExp(r'[^0-9.]'), '');
    return double.tryParse(cleaned) ?? fallback;
  }

  int _parseMinutes(String raw, int fallback) {
    final cleaned = raw.replaceAll(RegExp(r'[^0-9]'), '');
    return int.tryParse(cleaned) ?? fallback;
  }

  Future<void> _saveSettings() async {
    if (_saving) return;
    final defaultRate = _parseCurrency(_defaultPriceController.text, 8.0);
    final graceMinutes = _parseMinutes(_gracePeriodController.text, 5);
    final lateRate = _parseCurrency(_lateChargeController.text, 10.0);

    setState(() => _saving = true);
    try {
      await Api.updateShopSettings({
        'default_rate': defaultRate,
        'grace_minutes': graceMinutes,
        'late_rate': lateRate,
        'auto_charge_limit': _autoChargeLimit,
        'auto_charge_late': _autoChargeLate,
        'notify_overdue': _notifyOverdue,
        'notify_leaves_park': _notifyLeavesPark,
        'notify_lost_signal': _notifyLostSignal,
      });
      if (!mounted) return;
      setState(() {
        _defaultPriceController.text = 'RM ${defaultRate.toStringAsFixed(2)}';
        _gracePeriodController.text = '$graceMinutes min';
        _lateChargeController.text = 'RM ${lateRate.toStringAsFixed(2)}';
        _saving = false;
      });
      _showToast('Shop settings saved');
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      _showToast('Failed to save settings: $e', isError: true);
    }
  }

  Future<void> _handleLogout() async {
    await Api.signOut();
    if (!mounted) return;
    if (widget.onLogout != null) {
      widget.onLogout!();
    }
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  String _formatLimitLabel(int blocks) {
    final mins = blocks * 20;
    if (mins % 60 == 0) {
      final hrs = mins ~/ 60;
      return '$blocks ${blocks == 1 ? 'block' : 'blocks'} ($hrs hr)';
    }
    return '$blocks ${blocks == 1 ? 'block' : 'blocks'} ($mins min)';
  }

  void _showToast(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: isError ? const Color(0xFFB00020) : _successGreen,
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        duration: const Duration(seconds: 2),
        content: Row(
          children: [
            Icon(
              isError ? Icons.error_outline : Icons.check_circle_outline,
              color: Colors.white,
              size: 18,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                msg,
                style: const TextStyle(color: Colors.white, fontSize: 13),
              ),
            ),
          ],
        ),
      ),
    );
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
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: _dark))
          : SingleChildScrollView(
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
                              style:
                                  const TextStyle(fontSize: 14, color: _dark),
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
                              style:
                                  const TextStyle(fontSize: 14, color: _dark),
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
                        onChanged: (val) =>
                            setState(() => _autoChargeLate = val),
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
                      PopupMenuButton<int>(
                        initialValue: _autoChargeLimit,
                        onSelected: (val) =>
                            setState(() => _autoChargeLimit = val),
                        itemBuilder: (context) => [1, 2, 3, 4, 5, 6]
                            .map(
                              (b) => PopupMenuItem<int>(
                                value: b,
                                child: Text(_formatLimitLabel(b)),
                              ),
                            )
                            .toList(),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 7,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: _dark, width: 1.2),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                _formatLimitLabel(_autoChargeLimit),
                                style: const TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w700,
                                  color: _dark,
                                ),
                              ),
                              const SizedBox(width: 4),
                              const Icon(
                                Icons.keyboard_arrow_down,
                                size: 16,
                                color: _dark,
                              ),
                            ],
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
                  const SizedBox(height: 20),

                  // Save settings button
                  SizedBox(
                    width: double.infinity,
                    height: 46,
                    child: ElevatedButton(
                      onPressed: _saving ? null : _saveSettings,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _dark,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: _saving
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Text(
                              'Save settings',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Log out button
                  SizedBox(
                    width: double.infinity,
                    height: 46,
                    child: OutlinedButton.icon(
                      onPressed: _handleLogout,
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
