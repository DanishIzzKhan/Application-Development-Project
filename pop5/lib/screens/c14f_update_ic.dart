import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/api.dart';
import '../theme.dart';
import '../widgets/common.dart';

/// Settings -> Update IC photos. Replaces the front and/or back of the IC that
/// was uploaded on C2b. Files stay at `ic-documents/<user id>/front.jpg|back.jpg`.
class UpdateIcScreen extends StatefulWidget {
  const UpdateIcScreen({super.key});

  @override
  State<UpdateIcScreen> createState() => _UpdateIcScreenState();
}

class _UpdateIcScreenState extends State<UpdateIcScreen> {
  final _picker = ImagePicker();
  XFile? _front, _back;
  Uint8List? _frontBytes, _backBytes;
  String? _frontUrl, _backUrl; // signed links to the IC already on file
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _loadCurrent();
  }

  Future<void> _loadCurrent() async {
    try {
      final uid = supabase.auth.currentUser?.id;
      if (uid == null) return;
      final row = await supabase
          .from('users')
          .select('ic_front_path, ic_back_path')
          .eq('id', uid)
          .maybeSingle();
      final bucket = supabase.storage.from('ic-documents');
      Future<String?> link(Object? path) async => path == null
          ? null
          : await bucket.createSignedUrl(path as String, 300);
      final front = await link(row?['ic_front_path']);
      final back = await link(row?['ic_back_path']);
      if (mounted) {
        setState(() {
          _frontUrl = front;
          _backUrl = back;
        });
      }
    } catch (_) {
      // No photo on file yet, or the link failed: the boxes just stay empty.
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

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
    final file =
        await _picker.pickImage(source: source, maxWidth: 1600, imageQuality: 85);
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

  Future<void> _save() async {
    if (_front == null && _back == null) {
      showToast(context, 'Choose a new photo for the front or the back first.');
      return;
    }
    final uid = supabase.auth.currentUser?.id;
    if (uid == null) return;

    setState(() => _saving = true);
    try {
      final bucket = supabase.storage.from('ic-documents');
      final update = <String, dynamic>{'accepted_ic_storage': true};

      if (_front != null) {
        await bucket.uploadBinary('$uid/front.jpg', _frontBytes!,
            fileOptions: FileOptions(
                upsert: true, contentType: _front!.mimeType ?? 'image/jpeg'));
        update['ic_front_path'] = '$uid/front.jpg';
      }
      if (_back != null) {
        await bucket.uploadBinary('$uid/back.jpg', _backBytes!,
            fileOptions: FileOptions(
                upsert: true, contentType: _back!.mimeType ?? 'image/jpeg'));
        update['ic_back_path'] = '$uid/back.jpg';
      }

      await supabase.from('users').update(update).eq('id', uid);

      if (!mounted) return;
      showToast(context, 'IC photos updated.');
      Navigator.of(context).pop(true);
    } on StorageException catch (e) {
      if (mounted) showToast(context, 'Upload failed: ${e.message}');
    } on PostgrestException catch (e) {
      if (mounted) showToast(context, 'Could not save: ${e.message}');
    } catch (e) {
      if (mounted) showToast(context, 'Something went wrong: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const AppHeader(title: 'Update IC photos'),
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : FormScroll(
                children: [
                  Row(
                    children: [
                      const Icon(Icons.shield_outlined, size: 24),
                      const SizedBox(width: 10),
                      Text('Your IC (MyKad)',
                          style: inter(18, weight: FontWeight.w700)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Replace the front, the back or both. The new photo replaces the one on file. Only the shop owner can view your IC.',
                    style: inter(13, color: AppColors.text2),
                  ),
                  const SizedBox(height: 14),
                  _box('Front of IC', _frontBytes, _frontUrl, () => _pick(true)),
                  const SizedBox(height: 14),
                  _box('Back of IC', _backBytes, _backUrl, () => _pick(false)),
                  const Spacer(),
                  const SizedBox(height: 16),
                  PrimaryButton(
                      label: 'Save new IC photos',
                      loading: _saving,
                      onPressed: _save),
                ],
              ),
      ),
    );
  }

  /// New photo if one was picked, else the one on file, else an empty prompt.
  Widget _box(String label, Uint8List? picked, String? currentUrl,
      VoidCallback onTap) {
    final hasImage = picked != null || currentUrl != null;
    return GestureDetector(
      onTap: onTap,
      child: DashedBox(
        height: 120,
        child: hasImage
            ? Stack(
                children: [
                  Positioned.fill(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(9),
                      child: picked != null
                          ? Image.memory(picked, fit: BoxFit.cover)
                          : Image.network(currentUrl!, fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => Center(
                                    child: Text('Photo on file',
                                        style: inter(13, color: AppColors.text2)),
                                  )),
                    ),
                  ),
                  Positioned(
                    right: 8,
                    bottom: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.dark, width: 1.5),
                      ),
                      child: Text(picked != null ? 'New · tap to change' : 'Tap to replace',
                          style: inter(12, weight: FontWeight.w600)),
                    ),
                  ),
                ],
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