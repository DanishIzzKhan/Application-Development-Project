import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/api.dart';
import '../theme.dart';
import '../widgets/common.dart';

/// C11 Report a problem: saved to `maintenance_logs` as a customer_report.
class ReportProblemScreen extends StatefulWidget {
  final String bookingId; // rentals.id
  const ReportProblemScreen({super.key, required this.bookingId});

  @override
  State<ReportProblemScreen> createState() => _ReportProblemScreenState();
}

class _ReportProblemScreenState extends State<ReportProblemScreen> {
  static const _issues = [
    'Brakes',
    'Tyre or puncture',
    'Chain or gears',
    'Battery (scooters)',
    'Other',
  ];

  final _selected = <String>{};
  final _description = TextEditingController();
  final _picker = ImagePicker();
  XFile? _photo;
  Uint8List? _photoBytes;

  String _vehicleName = 'your vehicle';
  String? _vehicleId;
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    _loadRental();
  }

  @override
  void dispose() {
    _description.dispose();
    super.dispose();
  }

  Future<void> _loadRental() async {
    try {
      final row = await supabase
          .from('rentals')
          .select('vehicle_id, vehicles(id, type)')
          .eq('id', widget.bookingId)
          .single();
      final v = row['vehicles'];
      if (!mounted) return;
      setState(() {
        _vehicleId = row['vehicle_id'] as String;
        if (v != null) _vehicleName = '${v['type']} ${v['id']}';
      });
    } catch (_) {
      // The form still shows; sending will explain if the rental is missing.
    }
  }

  Future<void> _pickPhoto() async {
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
      _photo = file;
      _photoBytes = bytes;
    });
  }

  Future<void> _send() async {
    final text = _description.text.trim();
    if (_selected.isEmpty && text.isEmpty) {
      showToast(context, 'Tick what is wrong or describe the problem.');
      return;
    }
    final uid = supabase.auth.currentUser?.id;
    final vehicleId = _vehicleId;
    if (uid == null || vehicleId == null) {
      showToast(context, 'Could not find this rental. Please go back and try again.');
      return;
    }

    setState(() => _sending = true);
    try {
      String? photoPath;
      if (_photo != null && _photoBytes != null) {
        photoPath = '$uid/${DateTime.now().millisecondsSinceEpoch}.jpg';
        await supabase.storage.from('report-photos').uploadBinary(
              photoPath,
              _photoBytes!,
              fileOptions:
                  FileOptions(contentType: _photo!.mimeType ?? 'image/jpeg'),
            );
      }

      final description = [
        if (_selected.isNotEmpty) 'Problems: ${_selected.join(', ')}',
        if (text.isNotEmpty) text,
      ].join('\n');

      await supabase.from('maintenance_logs').insert({
        'vehicle_id': vehicleId,
        'reported_by': uid,
        'rental_id': widget.bookingId,
        'log_type': 'customer_report',
        'issue_description': description,
        'photo_path': photoPath,
      });

      if (!mounted) return;
      showToast(context, 'Report sent. Thank you, the shop will check it.');
      Navigator.of(context).pop();
    } on StorageException catch (e) {
      if (mounted) showToast(context, 'Photo upload failed: ${e.message}');
    } on PostgrestException catch (e) {
      if (mounted) showToast(context, 'Could not send report: ${e.message}');
    } catch (e) {
      if (mounted) showToast(context, 'Could not send report: $e');
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const AppHeader(title: 'Report a problem'),
      body: SafeArea(
        child: FormScroll(
          children: [
            Text('What is wrong with $_vehicleName?',
                style: inter(15, weight: FontWeight.w600)),
            const SizedBox(height: 14),
            for (final issue in _issues) ...[
              AppCheckRow(
                value: _selected.contains(issue),
                onChanged: (v) => setState(() {
                  v ? _selected.add(issue) : _selected.remove(issue);
                }),
                text: issue,
              ),
              const SizedBox(height: 12),
            ],
            const SizedBox(height: 2),
            Text('Describe the problem (optional)',
                style: inter(14, weight: FontWeight.w600)),
            const SizedBox(height: 6),
            TextField(
              controller: _description,
              maxLines: 3,
              style: inter(15),
              decoration: InputDecoration(
                hintText: 'e.g. the rear brake is loose',
                hintStyle: inter(15, color: AppColors.hint),
                contentPadding: const EdgeInsets.all(12),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide:
                      const BorderSide(color: AppColors.border, width: 1.5),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: AppColors.ink, width: 1.5),
                ),
              ),
            ),
            const SizedBox(height: 12),
            GestureDetector(
              onTap: _pickPhoto,
              child: DashedBox(
                height: 80,
                radius: 10,
                child: _photoBytes != null
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(9),
                        child: SizedBox.expand(
                          child: Image.memory(_photoBytes!, fit: BoxFit.cover),
                        ),
                      )
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.camera_alt_outlined, size: 22),
                          const SizedBox(width: 8),
                          Text('Add a photo (optional)',
                              style: inter(13, color: AppColors.text2)),
                        ],
                      ),
              ),
            ),
            const Spacer(),
            const SizedBox(height: 14),
            PrimaryButton(
                label: 'Send report', loading: _sending, onPressed: _send),
          ],
        ),
      ),
    );
  }
}
