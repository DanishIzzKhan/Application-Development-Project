import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../models/rental.dart';
import '../models/vehicle.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/rental_widgets.dart';

/// O4 Walk-in booking — opened from "+ Walk-in" on O3.
/// For customers without a phone or the app: the owner books for them,
/// payment is taken at the counter, and the rental is not tracked on the map.
///
/// Pops with the new [OwnerRental]; O3 adds it to "Ready for handover"
/// and opens O5 for it.
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

  // Sample data for now. Later: Api.fetchAvailableVehicles().
  final List<Vehicle> _vehicles = sampleAvailableVehicles();
  late Vehicle _vehicle = _vehicles.first;

  int _minutes = 60; // wireframe default: 1 hr 0 min
  int _payment = 0; // Cash by default
  // Optional IC photos, front and back (security record).
  Uint8List? _icFront;
  Uint8List? _icBack;

  int get _blocks => _minutes ~/ OwnerRental.blockMinutes;
  double get _total => _blocks * _vehicle.pricePer20Min;

  bool get _phoneOk =>
      _phone.text.replaceAll(RegExp(r'[^0-9]'), '').length >= 9;

  /// What is still missing before the booking can be created.
  List<String> get _missing => [
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

  void _create() {
    // Later: Api.createWalkInBooking(...) inserts a rental with
    // is_walk_in = true, is_tracked = false, and a 'Cash'/'TnG'/'Bank QR'
    // payment; the IC photo goes to the private ic-documents bucket.
    final rental = OwnerRental.newWalkIn(
      name: _name.text.trim(),
      phone: _phone.text.trim(),
      vehicle: _vehicle,
      minutes: _minutes,
      paymentMethod: _payValues[_payment],
      icFront: _icFront,
      icBack: _icBack,
    );
    showTopNotice(context,
        title: 'Booking ${rental.bookingCode} created',
        lines: ['${formatRM(_total)} paid by ${_payLabels[_payment]}'],
        type: NoticeType.success);
    Navigator.of(context).pop(rental);
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
            onTap: _canCreate ? null : _showMissing,
            child: PrimaryButton(
              label: 'Create booking · ${formatRM(_total)} paid',
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
