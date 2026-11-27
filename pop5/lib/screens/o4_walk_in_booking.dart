import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config.dart';
import '../models/rental.dart';
import '../models/vehicle.dart';
import '../services/owner_api.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/rental_widgets.dart';

/// O4 Walk-in booking — opened from "+ Walk-in" on O3.
/// For customers without a phone or the app: the owner books for them,
/// payment is taken at the counter, and the rental is not tracked on the map.
///
/// Saved in Supabase (OwnerApi.createWalkIn): the booking, the optional IC
/// photos and the counter payment. Pops with the new [OwnerRental] (already
/// paid, status 'ready'); O3 opens Start rental (O5) for it.
class WalkInBookingScreen extends StatefulWidget {
  const WalkInBookingScreen({super.key});

  @override
  State<WalkInBookingScreen> createState() => _WalkInBookingScreenState();
}

class _WalkInBookingScreenState extends State<WalkInBookingScreen> {
  // Payment chip labels, and the matching value saved in the payments table.
  static const _payLabels = ['Cash', 'Touch ’n Go', 'Bank QR'];
  static const _payValues = ['Cash', 'TnG', 'Bank QR'];

  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _picker = ImagePicker();

  // Vehicles free right now (sample fleet only in AppConfig.uiPreviewMode).
  List<Vehicle> _vehicles =
      AppConfig.uiPreviewMode ? sampleAvailableVehicles() : [];
  Vehicle? _vehicle =
      AppConfig.uiPreviewMode ? sampleAvailableVehicles().first : null;
  bool _loadingVehicles = !AppConfig.uiPreviewMode;
  bool _busy = false; // saving the booking

  int _minutes = 60; // wireframe default: 1 hr 0 min
  int _payment = 0; // Cash by default
  // Optional IC photos, front and back (security record).
  Uint8List? _icFront;
  Uint8List? _icBack;

  int get _blocks => _minutes ~/ OwnerRental.blockMinutes;
  double get _total => _blocks * (_vehicle?.pricePer20Min ?? 0);

  bool get _phoneOk =>
      _phone.text.replaceAll(RegExp(r'[^0-9]'), '').length >= 9;

  /// What is still missing before the booking can be created.
  List<String> get _missing => [
        if (_vehicle == null) 'No vehicle is available right now',
        if (_name.text.trim().isEmpty) 'Enter the customer name',
        if (!_phoneOk) 'Enter a valid contact number',
      ];

  bool get _canCreate => _missing.isEmpty;

  @override
  void initState() {
    super.initState();
    // Redraw while typing, so the button turns dark once everything is filled.
    for (final c in [_name, _phone]) {
      c.addListener(() => setState(() {}));
    }
    if (!AppConfig.uiPreviewMode) _loadVehicles();
  }

  Future<void> _loadVehicles() async {
    setState(() => _loadingVehicles = true);
    try {
      final list = await OwnerApi.fetchAvailableVehicles();
      if (!mounted) return;
      setState(() {
        _vehicles = list;
        _vehicle = list.isEmpty ? null : list.first;
      });
    } catch (e) {
      debugPrint('Walk-in: could not load vehicles. $e');
      if (mounted) {
        showTopNotice(context,
            title: "Couldn't load vehicles",
            lines: ['Check your internet connection and try again.'],
            type: NoticeType.error);
      }
    } finally {
      if (mounted) setState(() => _loadingVehicles = false);
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    super.dispose();
  }

  Future<void> _takeIcPhoto({required bool front}) async {
    try {
      final file = await _picker.pickImage(
          source: ImageSource.camera, maxWidth: 1600, imageQuality: 85);
      if (file == null) return;
      final bytes = await file.readAsBytes();
      if (!mounted) return;
      setState(() => front ? _icFront = bytes : _icBack = bytes);
    } catch (e) {
      if (mounted) {
        showTopNotice(context,
            title: 'Could not open the camera', type: NoticeType.error);
      }
    }
  }

  /// Grey button tapped: say what is missing.
  void _showMissing() {
    showTopNotice(context,
        title: "Can't create booking yet",
        lines: _missing,
        type: NoticeType.error);
  }

  Future<void> _create() async {
    final vehicle = _vehicle!;
    final OwnerRental rental;
    if (AppConfig.uiPreviewMode) {
      rental = OwnerRental.newWalkIn(
        name: _name.text.trim(),
        phone: _phone.text.trim(),
        vehicle: vehicle,
        minutes: _minutes,
        paymentMethod: _payValues[_payment],
        icFront: _icFront,
        icBack: _icBack,
      );
    } else {
      setState(() => _busy = true);
      try {
        rental = await OwnerApi.createWalkIn(
          name: _name.text.trim(),
          phone: _phone.text.trim(),
          vehicle: vehicle,
          minutes: _minutes,
          method: _payValues[_payment],
          icFront: _icFront,
          icBack: _icBack,
        );
      } on PostgrestException catch (e) {
        // e.g. "This vehicle is already booked for that time."
        _failed([e.message]);
        return;
      } catch (e) {
        debugPrint('Walk-in failed: $e');
        _failed([
          'Check your internet connection and try again.',
          'If it was created, it is on Rentals under Waiting for payment.',
        ]);
        return;
      } finally {
        if (mounted) setState(() => _busy = false);
      }
    }
    if (!mounted) return;
    showTopNotice(context,
        title: 'Booking ${rental.bookingCode} created',
        lines: ['${formatRM(_total)} paid by ${_payLabels[_payment]}'],
        type: NoticeType.success);
    Navigator.of(context).pop(rental);
  }

  void _failed(List<String> lines) {
    if (!mounted) return;
    showTopNotice(context,
        title: "Couldn't create the booking",
        lines: lines,
        type: NoticeType.error);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const AppHeader(title: 'Walk-in booking'),
      body: FormScroll(
        children: [
          AppField(
            label: 'Customer name',
            hint: 'e.g. Ali bin Ahmad',
            controller: _name,
            textInputAction: TextInputAction.next,
          ),
          const SizedBox(height: 12),
          AppField(
            label: 'Contact number',
            hint: 'e.g. 012-345 6789',
            controller: _phone,
            keyboardType: TextInputType.phone,
            textInputAction: TextInputAction.next,
          ),
          const SizedBox(height: 12),

          // ---- Vehicle dropdown ----
          Text('Vehicle', style: inter(14, weight: FontWeight.w600)),
          const SizedBox(height: 6),
          if (_loadingVehicles)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 14),
              child: LinearProgressIndicator(color: AppColors.dark),
            )
          else if (_vehicles.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Row(
                children: [
                  Expanded(
                    child: Text('No vehicle is available right now.',
                        style: inter(14, color: AppColors.text2)),
                  ),
                  SmallButton(
                      label: 'Refresh',
                      primary: false,
                      onPressed: _loadVehicles),
                ],
              ),
            )
          else
            DropdownButtonFormField<Vehicle>(
              initialValue: _vehicle,
              style: inter(15),
              icon: const Icon(Icons.expand_more, color: AppColors.ink),
              decoration: InputDecoration(
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                enabledBorder: _border(AppColors.border),
                focusedBorder: _border(AppColors.ink),
              ),
              items: [
                for (final v in _vehicles)
                  DropdownMenuItem(
                    value: v,
                    child: Text('${v.name} · ${v.priceLabel} / 20 min'),
                  ),
              ],
              onChanged: (v) {
                if (v != null) setState(() => _vehicle = v);
              },
            ),
          const SizedBox(height: 14),

          // ---- Duration ----
          const SectionTitle('Duration'),
          const SizedBox(height: 8),
          DurationStepper(
            minutes: _minutes,
            onChanged: (m) => setState(() => _minutes = m),
          ),
          const SizedBox(height: 14),

          // ---- Optional IC photos, front + back (if taken: View IC on O5 / O3c) ----
          Text('Customer IC (optional)',
              style: inter(14, weight: FontWeight.w600)),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: _IcPhotoBox(
                  label: 'Front',
                  photo: _icFront,
                  onTap: () => _takeIcPhoto(front: true),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _IcPhotoBox(
                  label: 'Back',
                  photo: _icBack,
                  onTap: () => _takeIcPhoto(front: false),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text('Security record. Only the owner can see it.',
              style: inter(12, color: AppColors.text2)),
          const SizedBox(height: 14),

          // ---- Payment received ----
          const SectionTitle('Payment received'),
          const SizedBox(height: 8),
          OptionChips(
            options: _payLabels,
            selected: _payment,
            onChanged: (i) => setState(() => _payment = i),
          ),

          const Spacer(),
          const SizedBox(height: 16),
          // Grey until name and contact number are filled (IC photos optional).
          // A tap on the grey button shows what is missing.
          GestureDetector(
            onTap: _canCreate || _busy ? null : _showMissing,
            child: PrimaryButton(
              label: 'Create booking · ${formatRM(_total)} paid',
              loading: _busy,
              onPressed: _canCreate ? _create : null,
            ),
          ),
        ],
      ),
    );
  }
}

OutlineInputBorder _border(Color c) => OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: BorderSide(color: c, width: 1.5),
    );

/// One dashed photo box on O4 (IC front or back). Tap to take / retake.
class _IcPhotoBox extends StatelessWidget {
  final String label;
  final Uint8List? photo;
  final VoidCallback onTap;

  const _IcPhotoBox(
      {required this.label, required this.photo, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: DashedBox(
        height: 96,
        child: photo != null
            ? Stack(
                children: [
                  Positioned.fill(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(9),
                      child: Image.memory(photo!, fit: BoxFit.cover),
                    ),
                  ),
                  Positioned(
                    left: 6,
                    bottom: 6,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.dark,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text('$label ✓',
                          style: inter(11,
                              weight: FontWeight.w700, color: Colors.white)),
                    ),
                  ),
                ],
              )
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.camera_alt_outlined, size: 24),
                  const SizedBox(height: 4),
                  Text('IC $label', style: inter(13, weight: FontWeight.w600)),
                  Text('Tap to take photo',
                      style: inter(11, color: AppColors.text2)),
                ],
              ),
      ),
    );
  }
}
