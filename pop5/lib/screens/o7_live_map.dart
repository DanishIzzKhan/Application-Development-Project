import 'package:flutter/material.dart';

class O7LiveMapScreen extends StatelessWidget {
  const O7LiveMapScreen({super.key});

  static const Color _dark = Color(0xFF262626);
  static const Color _muted = Color(0xFF6B6B6B);
  static const Color _border = Color(0xFFD0D0D0);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: const Text(
          'Live map',
          style: TextStyle(
            color: _dark,
            fontSize: 22,
            fontWeight: FontWeight.w700,
          ),
        ),
        actions: const [
          Center(
            child: Padding(
              padding: EdgeInsets.only(right: 16),
              child: Text(
                '3 tracked',
                style: TextStyle(
                  fontSize: 13,
                  color: _muted,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: const Color(0xFFEAEAEA)),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Simulated OpenStreetMap & Geofence Wireframe Box
            CustomPaint(
              painter: _DashedRRectPainter(
                color: const Color(0xFF9E9E9E),
                strokeWidth: 1.2,
                radius: 10,
              ),
              child: SizedBox(
                width: double.infinity,
                height: 310,
                child: Stack(
                  children: [
                    const Positioned(
                      left: 14,
                      top: 10,
                      child: Text(
                        'MAP (OpenStreetMap)',
                        style: TextStyle(
                          fontSize: 11,
                          color: _muted,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),

                    // Park geofence boundary
                    Positioned(
                      left: 34,
                      right: 92,
                      top: 34,
                      bottom: 24,
                      child: CustomPaint(
                        painter: _DashedRRectPainter(
                          color: _dark,
                          strokeWidth: 1.6,
                          radius: 36,
                        ),
                      ),
                    ),

                    // Pin B01 (Inside)
                    Positioned(
                      left: 96,
                      top: 104,
                      child: _buildInsidePin('B01'),
                    ),

                    // Pin B03 (Inside)
                    Positioned(
                      left: 142,
                      top: 188,
                      child: _buildInsidePin('B03'),
                    ),

                    // Pin S02 · OUT (Outside park boundary)
                    Positioned(
                      right: 14,
                      top: 78,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 14,
                            height: 14,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                              border: Border.all(color: _dark, width: 3),
                            ),
                          ),
                          const SizedBox(width: 5),
                          const Text(
                            'S02 · OUT',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: _dark,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Tracked Vehicles Bounded List
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _border, width: 1.2),
              ),
              child: Column(
                children: [
                  _buildVehicleStatusRow(
                    title: 'S02 · outside park',
                    subtitle: '0:25 left',
                    isOut: true,
                  ),
                  const Divider(height: 1, color: _border),
                  _buildVehicleStatusRow(
                    title: 'B01 · inside',
                    subtitle: '1:42 left',
                  ),
                  const Divider(height: 1, color: _border),
                  _buildVehicleStatusRow(
                    title: 'B03 · inside',
                    subtitle: '0:50 left',
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'B04 (walk-in) is not tracked and does not appear on the map.',
              style: TextStyle(fontSize: 12, color: _muted),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInsidePin(String code) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 14,
          height: 14,
          decoration: const BoxDecoration(
            color: _dark,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 6),
        Text(
          code,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w800,
            color: _dark,
          ),
        ),
      ],
    );
  }

  Widget _buildVehicleStatusRow({
    required String title,
    required String subtitle,
    bool isOut = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: _dark,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: const TextStyle(fontSize: 12, color: _muted),
                ),
              ],
            ),
          ),
          if (isOut)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: _dark,
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Text(
                'OUT',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _DashedRRectPainter extends CustomPainter {
  final Color color;
  final double strokeWidth;
  final double radius;

  _DashedRRectPainter({
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

    const dashWidth = 5.0;
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
