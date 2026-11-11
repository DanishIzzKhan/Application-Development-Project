import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../theme.dart';
import '../widgets/common.dart';

class ReportProblemScreen extends StatefulWidget {
  final String bookingId;
  const ReportProblemScreen({super.key, required this.bookingId});

  @override
  State<ReportProblemScreen> createState() => _ReportProblemScreenState();
}

class _ReportProblemScreenState extends State<ReportProblemScreen> {
  bool _submitting = false;
  String _selectedCategory = 'Vehicle Damage';
  final TextEditingController _descriptionController = TextEditingController();

  final List<String> _categories = [
    'Vehicle Damage',
    'Flat Tire / Chain Issue',
    'Parking / Lock Problem',
    'Payment / Billing Issue',
    'Others',
  ];

  @override
  void dispose() {
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _submitReport() async {
    final description = _descriptionController.text.trim();
    if (description.isEmpty) {
      showToast(context, 'Please describe the problem.');
      return;
    }

    setState(() => _submitting = true);
    try {
      // Simpan aduan ke Supabase (pastikan table 'reports' wujud, atau hantar ke table 'bookings' / custom table korang)
      await Supabase.instance.client.from('reports').insert({
        'booking_id': widget.bookingId,
        'category': _selectedCategory,
        'description': description,
        'status': 'pending',
        'created_at': DateTime.now().toIso8601String(),
      });

      if (!mounted) return;
      showToast(context,
          'Report submitted successfully. Support team will contact you.');
      Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        showToast(context, 'Failed to submit report: $e');
        setState(() => _submitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const AppHeader(title: 'Report a Problem (C11)'),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 8),
              Text('What went wrong?',
                  style: inter(20, weight: FontWeight.w700)),
              const SizedBox(height: 4),
              Text('Select a category and describe the issue you faced.',
                  style: inter(14, color: AppColors.text2)),
              const SizedBox(height: 20),
              DropdownButtonFormField<String>(
                initialValue: _selectedCategory,
                dropdownColor: Colors.white,
                decoration: InputDecoration(
                  labelText: 'Problem Category',
                  labelStyle: inter(14, color: AppColors.hint),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide:
                        const BorderSide(color: AppColors.divider, width: 1.5),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide:
                        const BorderSide(color: AppColors.divider, width: 1.5),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide:
                        const BorderSide(color: AppColors.dark, width: 1.5),
                  ),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                ),
                items: _categories.map((category) {
                  return DropdownMenuItem(
                    value: category,
                    child: Text(category,
                        style: inter(14, weight: FontWeight.w500)),
                  );
                }).toList(),
                onChanged: (value) {
                  if (value != null) {
                    setState(() => _selectedCategory = value);
                  }
                },
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _descriptionController,
                maxLines: 5,
                style: inter(14),
                decoration: InputDecoration(
                  hintText: 'Describe the issue in detail...',
                  hintStyle: inter(14, color: AppColors.hint),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide:
                        const BorderSide(color: AppColors.divider, width: 1.5),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide:
                        const BorderSide(color: AppColors.divider, width: 1.5),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide:
                        const BorderSide(color: AppColors.dark, width: 1.5),
                  ),
                  contentPadding: const EdgeInsets.all(16),
                ),
              ),
              const Spacer(),
              PrimaryButton(
                label: _submitting ? 'Submitting Report...' : 'Submit Report',
                onPressed: _submitting ? null : _submitReport,
              ),
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: () => Navigator.pop(context),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 48),
                  side: const BorderSide(color: AppColors.border, width: 1.5),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                ),
                child: Text('Cancel',
                    style: inter(14,
                        weight: FontWeight.w600, color: AppColors.ink)),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}
