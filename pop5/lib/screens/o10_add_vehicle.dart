import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../models/vehicle.dart';
import '../services/api.dart';
import '../widgets/common.dart';

class O10AddVehicleScreen extends StatefulWidget {
  final Vehicle? vehicle;

  const O10AddVehicleScreen({
    super.key,
    this.vehicle,
  });

  bool get isEditing => vehicle != null;

  @override
  State<O10AddVehicleScreen> createState() => _O10AddVehicleScreenState();
}

class _O10AddVehicleScreenState extends State<O10AddVehicleScreen> {
  static const Color _dark = Color(0xFF262626);
  static const Color _muted = Color(0xFF6B6B6B);
  static const Color _border = Color(0xFFD0D0D0);

  late final TextEditingController _idController;
  late final TextEditingController _priceController;
  late final TextEditingController _overchargeController;
  late String _selectedType;
  late String _selectedStatus;

  XFile? _pickedPhoto;
  bool _saving = false;
  bool _overchargeEditedManually = false;

  final List<String> _types = [
    'Bicycle',
    'Scooter',
    'Pushbike',
    'Bubble Stick',
  ];
  final List<String> _statuses = ['Available', 'Under repair', 'Not in use'];

  @override
  void initState() {
    super.initState();
    final v = widget.vehicle;
    _idController = TextEditingController(text: v?.id ?? '');
    _priceController = TextEditingController(
      text: v != null ? v.pricePer20Min.toStringAsFixed(2) : '10.00',
    );
    _overchargeController = TextEditingController(
      text: v != null ? v.lateRatePer20Min.toStringAsFixed(2) : '10.00',
    );
    _selectedType = (v != null && _types.contains(v.type)) ? v.type : 'Bicycle';
    _selectedStatus = _mapDbStatusToUi(v?.status);
    _overchargeEditedManually = v != null;
  }

  String _mapDbStatusToUi(String? dbStatus) {
    switch (dbStatus) {
      case 'Maintenance':
        return 'Under repair';
      case 'Not in use':
        return 'Not in use';
      default:
        return 'Available';
    }
  }

  String _mapUiStatusToDb(String uiStatus) {
    switch (uiStatus) {
      case 'Under repair':
        return 'Maintenance';
      case 'Not in use':
        return 'Not in use';
      default:
        return 'Available';
    }
  }

  @override
  void dispose() {
    _idController.dispose();
    _priceController.dispose();
    _overchargeController.dispose();
    super.dispose();
  }

  Future<void> _pickPhoto() async {
    final picker = ImagePicker();
    final file = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1200,
      imageQuality: 85,
    );
    if (file != null && mounted) {
      setState(() => _pickedPhoto = file);
    }
  }

  double? _parseAmount(String raw) {
    final cleaned = raw.replaceAll(RegExp(r'[^0-9.]'), '');
    if (cleaned.isEmpty) return null;
    return double.tryParse(cleaned);
  }

  Future<void> _handleSave() async {
    final id = _idController.text.trim();
    final price = _parseAmount(_priceController.text);
    final overcharge = _parseAmount(_overchargeController.text);

    final errors = <String>[];
    if (id.isEmpty) {
      errors.add('Enter a vehicle code or name (e.g. BK-03)');
    }
    if (price == null || price <= 0) {
      errors.add('Enter a valid rental price per 20 minutes');
    }
    if (overcharge == null || overcharge < 0) {
      errors.add('Enter a valid overcharge rate per 20 minutes');
    }

    if (errors.isNotEmpty) {
      showTopErrorAlert(
        context,
        title: "Can't save vehicle yet",
        bullets: errors,
      );
      return;
    }

    setState(() => _saving = true);
    try {
      await Api.upsertVehicle(
        id: id,
        type: _selectedType,
        ratePerBlock: price!,
        lateRatePerBlock: overcharge!,
        status: _mapUiStatusToDb(_selectedStatus),
        photoFile: _pickedPhoto,
        existingPhotoUrl: widget.vehicle?.photoUrl,
      );
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        showTopErrorAlert(
          context,
          title: 'Failed to save vehicle',
          bullets: [e.toString()],
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _handleRemove() async {
    final v = widget.vehicle;
    if (v == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove vehicle?'),
        content: Text('${v.name} will be removed from your active fleet.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel', style: TextStyle(color: _muted)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Remove', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _saving = true);
    try {
      await Api.deleteVehicle(v.id);
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        showTopErrorAlert(
          context,
          title: 'Failed to remove vehicle',
          bullets: [e.toString()],
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasExistingPhoto =
        _pickedPhoto != null || (widget.vehicle?.photoUrl?.isNotEmpty ?? false);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: _dark),
          onPressed: _saving ? null : () => Navigator.pop(context),
        ),
        titleSpacing: 0,
        title: Text(
          widget.isEditing ? 'Edit vehicle' : 'Add vehicle',
          style: const TextStyle(
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
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Dashed photo upload box
                    GestureDetector(
                      onTap: _saving ? null : _pickPhoto,
                      child: CustomPaint(
                        painter: _DashedBorderPainter(
                          color: _border,
                          strokeWidth: 1.4,
                          radius: 10,
                        ),
                        child: Container(
                          width: double.infinity,
                          height: 112,
                          alignment: Alignment.center,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                hasExistingPhoto
                                    ? Icons.check_circle_outline
                                    : Icons.camera_alt_outlined,
                                size: 28,
                                color: _muted,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                _pickedPhoto != null
                                    ? 'Selected: ${_pickedPhoto!.name}'
                                    : hasExistingPhoto
                                        ? 'Photo attached (tap to change)'
                                        : 'Add vehicle photo',
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: _muted,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Vehicle code or name
                    const Text(
                      'Vehicle code or name',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: _dark,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _idController,
                      enabled: !widget.isEditing,
                      style: TextStyle(
                        fontSize: 14,
                        color: widget.isEditing ? _muted : _dark,
                      ),
                      decoration: _inputDecoration('e.g. BK-03 or PB-01'),
                    ),
                    const SizedBox(height: 20),

                    // Type selector
                    const Text(
                      'Type',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: _dark,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: _types.map((type) {
                        final selected = _selectedType == type;
                        return _buildOptionChip(
                          label: type,
                          selected: selected,
                          onTap: () {
                            setState(() {
                              _selectedType = type;
                              if (!widget.isEditing &&
                                  !_overchargeEditedManually) {
                                final defaultRate = (type == 'Pushbike' ||
                                        type == 'Bubble Stick')
                                    ? '5.00'
                                    : '10.00';
                                _priceController.text = defaultRate;
                                _overchargeController.text = defaultRate;
                              }
                            });
                          },
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 20),

                    // Rental price & Overcharge rate per 20 min
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Price / 20 min (RM)',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: _dark,
                                ),
                              ),
                              const SizedBox(height: 8),
                              TextField(
                                controller: _priceController,
                                keyboardType:
                                    const TextInputType.numberWithOptions(
                                  decimal: true,
                                ),
                                onChanged: (val) {
                                  if (!_overchargeEditedManually) {
                                    _overchargeController.text = val;
                                  }
                                },
                                style:
                                    const TextStyle(fontSize: 14, color: _dark),
                                decoration: _inputDecoration('10.00'),
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
                                'Overcharge / 20 min (RM)',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: _dark,
                                ),
                              ),
                              const SizedBox(height: 8),
                              TextField(
                                controller: _overchargeController,
                                keyboardType:
                                    const TextInputType.numberWithOptions(
                                  decimal: true,
                                ),
                                onChanged: (_) =>
                                    _overchargeEditedManually = true,
                                style:
                                    const TextStyle(fontSize: 14, color: _dark),
                                decoration: _inputDecoration('10.00'),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // Status selector
                    const Text(
                      'Status',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: _dark,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: _statuses.map((status) {
                        final selected = _selectedStatus == status;
                        return _buildOptionChip(
                          label: status,
                          selected: selected,
                          onTap: () => setState(() => _selectedStatus = status),
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
            ),

            // Bottom action buttons
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
              child: Column(
                children: [
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      onPressed: _saving ? null : _handleSave,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _dark,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: _saving
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Text(
                              'Save vehicle',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                    ),
                  ),
                  if (widget.isEditing) ...[
                    const SizedBox(height: 10),
                    TextButton(
                      onPressed: _saving ? null : _handleRemove,
                      child: const Text(
                        'Remove this vehicle',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: _muted,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: _muted, fontSize: 14),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: _border, width: 1.2),
      ),
      disabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: Color(0xFFE6E6E6), width: 1.2),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: _dark, width: 1.5),
      ),
    );
  }

  Widget _buildOptionChip({
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? _dark : Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: selected ? _dark : _border,
            width: 1.2,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: selected ? Colors.white : _dark,
          ),
        ),
      ),
    );
  }
}

class _DashedBorderPainter extends CustomPainter {
  final Color color;
  final double strokeWidth;
  final double radius;

  _DashedBorderPainter({
    required this.color,
    required this.strokeWidth,
    required this.radius,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke;

    final path = Path()
      ..addRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(0, 0, size.width, size.height),
          Radius.circular(radius),
        ),
      );

    const dashWidth = 6.0;
    const dashSpace = 4.0;
    for (final metric in path.computeMetrics()) {
      double distance = 0;
      while (distance < metric.length) {
        final next = distance + dashWidth;
        canvas.drawPath(
          metric.extractPath(distance, next.clamp(0, metric.length)),
          paint,
        );
        distance = next + dashSpace;
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
