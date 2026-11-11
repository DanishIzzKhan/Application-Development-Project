import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/registration_data.dart';
import '../services/api.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'c3_vehicles.dart';

class UploadIcScreen extends StatefulWidget {
  final RegistrationData data;
  const UploadIcScreen({super.key, required this.data});

  @override
  State<UploadIcScreen> createState() => _UploadIcScreenState();
}

class _UploadIcScreenState extends State<UploadIcScreen> {
  final _picker = ImagePicker();
  XFile? _front, _back;
  Uint8List? _frontBytes, _backBytes;
  bool _agreeIc = false;
  bool _agreeTerms = false;
  bool _loading = false;

  Future<void> _pick(bool front) async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: Colors.white,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt_outlined),
              title: const Text('Take a photo'),
              onTap: () => Navigator.pop(ctx, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Upload from gallery'),
              onTap: () => Navigator.pop(ctx, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
    if (source == null) return;
    final file = await _picker.pickImage(
        source: source, maxWidth: 1600, imageQuality: 85);
    if (file == null) return;
    final bytes = await file.readAsBytes();
    setState(() {
      if (front) {
        _front = file;
        _frontBytes = bytes;
      } else {
        _back = file;
        _backBytes = bytes;
      }
    });
  }

  Future<void> _submit() async {
    if (_front == null || _back == null) {
      showToast(context, 'Please add both the front and back of your IC.');
      return;
    }
    if (!_agreeIc || !_agreeTerms) {
      showToast(context, 'Please tick both agreements to continue.');
      return;
    }
    setState(() => _loading = true);
    try {
      await Api.createAccount(widget.data, icFront: _front!, icBack: _back!);
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const VehiclesScreen()),
        (_) => false,
      );
    } on AuthException catch (e) {
      if (mounted) showToast(context, e.message);
    } on StorageException catch (e) {
      if (mounted) showToast(context, 'Upload failed: ${e.message}');
    } on PostgrestException catch (e) {
      if (mounted) {
        showToast(
            context,
            e.code == '23505'
                ? 'That username or phone number is already taken.'
                : e.message);
      }
    } catch (e) {
      if (mounted) showToast(context, 'Something went wrong: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const AppHeader(title: 'Upload IC', trailing: 'Step 2 of 2'),
      body: SafeArea(
        child: FormScroll(
          children: [
            Row(
              children: [
                const Icon(Icons.shield_outlined, size: 24),
                const SizedBox(width: 10),
                Text('Your IC (MyKad)', style: inter(18, weight: FontWeight.w700)),
              ],
            ),
            const SizedBox(height: 14),
            Text(
              'We keep a copy of your IC for security. It is only used if a rented vehicle is lost, stolen or damaged, for example to make a police report.',
              style: inter(13, color: AppColors.text2),
            ),
            const SizedBox(height: 14),
            _UploadBox(
                label: 'Front of IC',
                bytes: _frontBytes,
                onTap: () => _pick(true)),
            const SizedBox(height: 14),
            _UploadBox(
                label: 'Back of IC',
                bytes: _backBytes,
                onTap: () => _pick(false)),
            const SizedBox(height: 14),
            AppCheckRow(
              value: _agreeIc,
              onChanged: (v) => setState(() => _agreeIc = v),
              text:
                  'I agree that ISYGEAR may store my IC and use it only in case of loss, theft or damage of a rented vehicle.',
            ),
            const SizedBox(height: 14),
            AppCheckRow(
              value: _agreeTerms,
              onChanged: (v) => setState(() => _agreeTerms = v),
              text:
                  'I agree to the rental terms, late-return charges and sharing my location during rentals.',
            ),
            const Spacer(),
            const SizedBox(height: 16),
            Text(
              'Only the shop owner can view your IC. It is deleted when you delete your account.',
              style: inter(12, color: AppColors.text2),
            ),
            const SizedBox(height: 12),
            PrimaryButton(
                label: 'Create account', loading: _loading, onPressed: _submit),
          ],
        ),
      ),
    );
  }
}

class _UploadBox extends StatelessWidget {
  final String label;
  final Uint8List? bytes;
  final VoidCallback onTap;

  const _UploadBox({required this.label, required this.bytes, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: DashedBox(
        height: 100,
        child: bytes != null
            ? ClipRRect(
                borderRadius: BorderRadius.circular(9),
                child: SizedBox.expand(
                    child: Image.memory(bytes!, fit: BoxFit.cover)),
              )
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.camera_alt_outlined, size: 28),
                  const SizedBox(height: 6),
                  Text(label, style: inter(13, weight: FontWeight.w600)),
                  const SizedBox(height: 6),
                  Text('Take a photo or upload',
                      style: inter(12, color: AppColors.text2)),
                ],
              ),
      ),
    );
  }
}
