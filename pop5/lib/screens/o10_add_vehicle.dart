import 'package:flutter/material.dart';
import '../widgets/common.dart';

class O10AddVehicleScreen extends StatefulWidget {
  final String? initialName;
  final String? initialType;
  final String? initialPrice;
  final String? initialStatus;
  final bool isEditing;

  const O10AddVehicleScreen({
    super.key,
    this.initialName,
    this.initialType,
    this.initialPrice,
    this.initialStatus,
    this.isEditing = false,
  });

  @override
  State<O10AddVehicleScreen> createState() => _O10AddVehicleScreenState();
}

class _O10AddVehicleScreenState extends State<O10AddVehicleScreen> {
  static const Color _dark = Color(0xFF262626);
  static const Color _muted = Color(0xFF6B6B6B);
  static const Color _border = Color(0xFFD0D0D0);

  late final TextEditingController _nameController;
  late final TextEditingController _priceController;
  late String _selectedType;
  late String _selectedStatus;
  bool _hasPhoto = false;

  final List<String> _types = ['Bicycle', 'Scooter'];
  final List<String> _statuses = ['Available', 'Under repair', 'Not in use'];

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.initialName ?? '');
    _priceController = TextEditingController(text: widget.initialPrice ?? '');
    _selectedType = widget.initialType ?? 'Bicycle';
    _selectedStatus = widget.initialStatus ?? 'Available';
  }

  @override
  void dispose() {
    _nameController.dispose();
    _priceController.dispose();
    super.dispose();
  }

  void _handleSave() {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      showTopErrorAlert(
        context,
        title: "Can't save vehicle yet",
        bullets: ['Enter a vehicle name or code to save'],
      );
      return;
    }

    Navigator.pop(context, {
      'name': name,
      'type': _selectedType,
      'price': _priceController.text.trim().isEmpty
          ? 'RM 10'
          : _priceController.text.trim(),
      'status': _selectedStatus.toUpperCase(),
    });
  }

  void _handleRemove() {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove vehicle?'),
        content: const Text('This vehicle will be removed from your fleet.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: _muted)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.pop(context, {'removed': true});
            },
            child: const Text('Remove', style: TextStyle(color: Colors.red)),
          ),
        ],
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
          'Add / edit vehicle',
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
                      onTap: () => setState(() => _hasPhoto = !_hasPhoto),
                      child: CustomPaint(
                        painter: _DashedBorderPainter(
                          color: _border,
                          strokeWidth: 1.4,
                          radius: 10,
                        ),
                        child: Container(
                          width: double.infinity,
                          height: 120,
                          alignment: Alignment.center,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                _hasPhoto
                                    ? Icons.check_circle_outline
                                    : Icons.camera_alt_outlined,
                                size: 28,
                                color: _muted,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                _hasPhoto
                                    ? 'Vehicle photo selected'
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

                    // Vehicle name or code
                    const Text(
                      'Vehicle name or code',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: _dark,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _nameController,
                      style: const TextStyle(fontSize: 14, color: _dark),
                      decoration: _inputDecoration('e.g. Bicycle B05'),
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
                          onTap: () => setState(() => _selectedType = type),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 20),

                    // Price per 20 minutes
                    const Text(
                      'Price per 20 minutes',
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
                          const TextInputType.numberWithOptions(decimal: true),
                      style: const TextStyle(fontSize: 14, color: _dark),
                      decoration: _inputDecoration('[RM X]'),
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
                      onPressed: _handleSave,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _dark,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: const Text(
                        'Save vehicle',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextButton(
                    onPressed: _handleRemove,
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
