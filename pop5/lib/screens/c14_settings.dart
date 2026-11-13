import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
 
import '../services/api.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'c1_login.dart';
import 'c1e_reset_password.dart';
import 'c3_vehicles.dart';
import 'c12_my_rentals.dart';
import 'c13_notifications.dart';
 
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});
 
  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}
 
class _SettingsScreenState extends State<SettingsScreen> {
  bool _loading = true;
  String _username = '';
  String _fullName = '';
  String _email = '';
  String _phone = '';
  bool _icVerified = true;
 
  bool _rentalReminders = true;
  bool _paymentUpdates = true;
  bool _promotions = false;
  int _unread = 0;
 
  @override
  void initState() {
    super.initState();
    _load();
  }
 
  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final client = Supabase.instance.client;
      final user = client.auth.currentUser;
      if (user == null) return;
 
      final results = await Future.wait<dynamic>([
        client.from('users').select().eq('id', user.id).maybeSingle(),
        Api.fetchUnreadCount(),
      ]);
      final profile = results[0] as Map<String, dynamic>?;
      if (!mounted) return;
      setState(() {
        _email = user.email ?? '';
        _username =
            (profile?['username'] ?? user.userMetadata?['username'] ?? 'user')
                .toString();
        _fullName =
            (profile?['full_name'] ?? user.userMetadata?['full_name'] ?? '')
                .toString();
        _phone =
            (profile?['phone'] ?? user.userMetadata?['phone'] ?? '').toString();
        _icVerified = profile?['ic_front_path'] != null &&
            profile?['ic_back_path'] != null;
        _rentalReminders = (profile?['notify_reminders'] ?? true) == true;
        _paymentUpdates = (profile?['notify_payments'] ?? true) == true;
        _promotions = (profile?['notify_promotions'] ?? false) == true;
        _unread = results[1] as int;
      });
    } catch (_) {
      // Fallback gracefully to auth metadata if profile query fails
      final user = Supabase.instance.client.auth.currentUser;
      if (mounted && user != null) {
        setState(() {
          _email = user.email ?? '';
          _username = (user.userMetadata?['username'] ?? 'user').toString();
          _fullName = (user.userMetadata?['full_name'] ?? '').toString();
          _phone = (user.userMetadata?['phone'] ?? '').toString();
        });
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }
 
  Future<void> _updatePref(String column, bool value) async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return;
    try {
      await Supabase.instance.client
          .from('users')
          .update({column: value}).eq('id', userId);
    } catch (e) {
      if (mounted) showToast(context, 'Could not save setting: $e');
    }
  }
 
  Future<void> _editProfile() async {
    final nameCtrl = TextEditingController(text: _fullName);
    final userCtrl = TextEditingController(text: _username);
    final phoneCtrl = TextEditingController(text: _phone);
 
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(
          16,
          20,
          16,
          MediaQuery.of(ctx).viewInsets.bottom + 24,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Edit profile', style: inter(18, weight: FontWeight.w700)),
            const SizedBox(height: 14),
            AppField(
              label: 'Username',
              hint: 'Enter username',
              controller: userCtrl,
            ),
            const SizedBox(height: 12),
            AppField(
              label: 'Full name',
              hint: 'Enter full name',
              controller: nameCtrl,
            ),
            const SizedBox(height: 12),
            AppField(
              label: 'Phone',
              hint: 'e.g. 0123456789',
              controller: phoneCtrl,
              keyboardType: TextInputType.phone,
            ),
            const SizedBox(height: 16),
            PrimaryButton(
              label: 'Save changes',
              onPressed: () async {
                final userId = Supabase.instance.client.auth.currentUser?.id;
                if (userId == null) return;
                try {
                  await Supabase.instance.client.from('users').update({
                    'username': userCtrl.text.trim(),
                    'full_name': nameCtrl.text.trim(),
                    'phone': Api.normalizePhone(phoneCtrl.text),
                  }).eq('id', userId);
                  if (ctx.mounted) Navigator.pop(ctx, true);
                } on PostgrestException catch (e) {
                  if (ctx.mounted) {
                    showToast(
                        ctx,
                        e.code == '23505'
                            ? 'That username or phone number is already taken.'
                            : 'Could not update profile: ${e.message}');
                  }
                } catch (e) {
                  if (ctx.mounted) {
                    showToast(ctx, 'Could not update profile: $e');
                  }
                }
              },
            ),
          ],
        ),
      ),
    );
 
    nameCtrl.dispose();
    userCtrl.dispose();
    phoneCtrl.dispose();
 
    if (saved == true && mounted) {
      showToast(context, 'Profile updated.');
      _load();
    }
  }
 
  void _showTerms() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Rental terms & late charges',
                  style: inter(18, weight: FontWeight.w700)),
              const SizedBox(height: 12),
              Text(
                '• Vehicles must be ridden inside Kulai Park boundaries only.\n'
                '• Rentals are billed in 20-minute blocks.\n'
                '• A 5-minute grace period applies after your rental ends.\n'
                '• Late returns beyond the grace period incur automatic charges every 20 minutes to your saved payment method.\n'
                '• Your IC is stored securely and used only in case of loss, theft, or damage.',
                style: inter(13, color: AppColors.text2),
              ),
              const SizedBox(height: 18),
              PrimaryButton(
                label: 'Close',
                onPressed: () => Navigator.pop(ctx),
              ),
            ],
          ),
        ),
      ),
    );
  }
 
  Future<void> _logout() async {
    await Supabase.instance.client.auth.signOut();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (_) => false,
    );
  }
 
  void _switchTab(int index) {
    if (index == 3) return;
    final Widget dest = switch (index) {
      0 => const VehiclesScreen(),
      1 => const MyRentalsScreen(),
      _ => const NotificationsScreen(),
    };
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => dest,
        transitionDuration: Duration.zero,
      ),
    );
  }
 
  @override
  Widget build(BuildContext context) {
    final subtitleParts = [
      if (_fullName.isNotEmpty) _fullName,
      if (_phone.isNotEmpty) _phone,
    ];
 
    return Scaffold(
      appBar: const AppHeader(title: 'Settings', showBack: false),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: _loading
                  ? const Center(
                      child: CircularProgressIndicator(color: AppColors.dark),
                    )
                  : ListView(
                      padding: const EdgeInsets.all(16),
                      children: [
                        // Profile summary card
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                                color: AppColors.divider, width: 1.5),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 56,
                                height: 56,
                                decoration: const BoxDecoration(
                                  color: AppColors.surface,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.person_outline,
                                    size: 28, color: AppColors.ink),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(_username,
                                        style:
                                            inter(17, weight: FontWeight.w700)),
                                    if (subtitleParts.isNotEmpty) ...[
                                      const SizedBox(height: 2),
                                      Text(subtitleParts.join(' · '),
                                          style: inter(13,
                                              color: AppColors.text2)),
                                    ],
                                    const SizedBox(height: 4),
                                    Row(
                                      children: [
                                        Icon(
                                          _icVerified
                                              ? Icons.shield_outlined
                                              : Icons.hourglass_empty,
                                          size: 15,
                                          color: AppColors.ink,
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          _icVerified
                                              ? 'IC on file'
                                              : 'IC not uploaded',
                                          style: inter(12,
                                              weight: FontWeight.w600),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),
 
                        // Account section
                        Text('Account',
                            style: inter(14, weight: FontWeight.w600)),
                        const SizedBox(height: 10),
                        _groupedCard([
                          _navTile(
                            icon: Icons.person_outline,
                            title: 'Edit profile',
                            subtitle: 'Username, name, phone',
                            onTap: _editProfile,
                          ),
                          _navTile(
                            icon: Icons.shield_outlined,
                            title: 'Change password',
                            onTap: () => Navigator.of(context).push(
                              MaterialPageRoute(
                                  builder: (_) => const ResetPasswordScreen()),
                            ),
                          ),
                        ]),
                        const SizedBox(height: 20),
 
                        // Notifications section
                        Text('Notifications',
                            style: inter(14, weight: FontWeight.w600)),
                        const SizedBox(height: 10),
                        _groupedCard([
                          _switchTile(
                            label: 'Rental reminders',
                            value: _rentalReminders,
                            onChanged: (v) {
                              setState(() => _rentalReminders = v);
                              _updatePref('notify_reminders', v);
                            },
                          ),
                          _switchTile(
                            label: 'Payment updates',
                            value: _paymentUpdates,
                            onChanged: (v) {
                              setState(() => _paymentUpdates = v);
                              _updatePref('notify_payments', v);
                            },
                          ),
                          _switchTile(
                            label: 'Promotions',
                            value: _promotions,
                            onChanged: (v) {
                              setState(() => _promotions = v);
                              _updatePref('notify_promotions', v);
                            },
                          ),
                        ]),
                        const SizedBox(height: 20),
 
                        // Terms & Log out section
                        _groupedCard([
                          _navTile(
                            icon: Icons.receipt_long_outlined,
                            title: 'Rental terms & late charges',
                            onTap: _showTerms,
                          ),
                          _navTile(
                            icon: Icons.logout,
                            title: 'Log out',
                            showChevron: false,
                            onTap: _logout,
                          ),
                        ]),
                      ],
                    ),
            ),
            _SettingsBottomNav(
              unread: _unread,
              onSelect: _switchTab,
            ),
          ],
        ),
      ),
    );
  }
 
  Widget _groupedCard(List<Widget> children) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.divider, width: 1.5),
      ),
      child: Column(
        children: [
          for (int i = 0; i < children.length; i++) ...[
            if (i > 0)
              const Divider(height: 1, thickness: 1, color: AppColors.divider),
            children[i],
          ],
        ],
      ),
    );
  }
 
  Widget _navTile({
    required IconData icon,
    required String title,
    String? subtitle,
    bool showChevron = true,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        child: Row(
          children: [
            Icon(icon, size: 22, color: AppColors.ink),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: inter(15, weight: FontWeight.w600)),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(subtitle, style: inter(12, color: AppColors.text2)),
                  ],
                ],
              ),
            ),
            if (showChevron)
              const Icon(Icons.chevron_right, size: 20, color: AppColors.hint),
          ],
        ),
      ),
    );
  }
 
  Widget _switchTile({
    required String label,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: inter(15)),
          Switch(
            value: value,
            onChanged: onChanged,
            activeTrackColor: AppColors.dark,
            activeThumbColor: Colors.white,
            inactiveTrackColor: AppColors.divider,
            inactiveThumbColor: Colors.white,
            trackOutlineColor: WidgetStateProperty.all(Colors.transparent),
          ),
        ],
      ),
    );
  }
}
 
class _SettingsBottomNav extends StatelessWidget {
  final int unread;
  final ValueChanged<int> onSelect;
 
  const _SettingsBottomNav({
    required this.unread,
    required this.onSelect,
  });
 
  @override
  Widget build(BuildContext context) {
    return Container(
      height: 64,
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: AppColors.divider, width: 1.5)),
      ),
      child: Row(
        children: [
          _item(Icons.pedal_bike, 'Rent', 0),
          _item(Icons.receipt_long_outlined, 'My rentals', 1),
          _item(Icons.notifications_none, 'Notifications', 2, badge: unread),
          _item(Icons.settings, 'Settings', 3),
        ],
      ),
    );
  }
 
  Widget _item(IconData icon, String label, int index, {int badge = 0}) {
    final current = index == 3;
    final color = current ? AppColors.ink : AppColors.hint;
    return Expanded(
      child: InkWell(
        onTap: () => onSelect(index),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 22, color: color),
                const SizedBox(height: 3),
                Text(
                  label,
                  style: inter(11,
                      weight: current ? FontWeight.w700 : FontWeight.w400,
                      color: color),
                ),
              ],
            ),
            if (badge > 0)
              Positioned(
                top: 8,
                left: 53,
                child: Container(
                  width: 18,
                  height: 18,
                  alignment: Alignment.center,
                  decoration: const BoxDecoration(
                    color: AppColors.ink,
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    '$badge',
                    style:
                        inter(10, weight: FontWeight.w700, color: Colors.white),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
