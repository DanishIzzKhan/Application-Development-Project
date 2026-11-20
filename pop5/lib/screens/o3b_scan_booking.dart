import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../models/rental.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/rental_widgets.dart';

/// O3b Scan booking — opened from "Scan booking QR" on O3.
///
/// The camera reads the customer's booking QR. The QR holds the booking's
/// `qr_token` (a long secret from the database). If the camera can't read it,
/// the owner types the 8-character `booking_code` instead (e.g. 3F9A1C2B).
///
/// When a booking that can be handed over is found, this screen closes and
/// returns it, and O3 opens Start rental for it.
///
/// Sample data for now: it searches the [rentals] O3 already has.
/// Later: Api.findRentalByQr(token) / Api.findRentalByCode(code).
class ScanBookingScreen extends StatefulWidget {
  final List<OwnerRental> rentals;
  const ScanBookingScreen({super.key, required this.rentals});

  @override
  State<ScanBookingScreen> createState() => _ScanBookingScreenState();
}

class _ScanBookingScreenState extends State<ScanBookingScreen> {
  static const _codeLength = 8;
  static const _background = AppColors.ink; // dark screen, as in Figma

  final _camera = MobileScannerController(
    formats: const [BarcodeFormat.qrCode],
    detectionSpeed: DetectionSpeed.noDuplicates,
  );
  final _code = TextEditingController();

  /// True while a scanned QR is being checked, so one QR = one result.
  bool _busy = false;

  bool get _codeReady => _code.text.length == _codeLength;

  @override
  void initState() {
    super.initState();
    _code.addListener(() => setState(() {})); // button turns dark at 8 chars
  }

  @override
  void dispose() {
    _camera.dispose();
    _code.dispose();
    super.dispose();
  }

  // ---------- Finding the booking ----------

  /// The camera found a QR code.
  void _onDetect(BarcodeCapture capture) {
    if (_busy || capture.barcodes.isEmpty) return;
    final value = capture.barcodes.first.rawValue;
    if (value == null || value.isEmpty) return;
    _busy = true;
    final rental = widget.rentals
        .where((r) => r.qrToken != null && r.qrToken == value)
        .firstOrNull;
    _open(rental, notFoundLine: 'This QR is not an ISYGEAR booking.');
    // Let the owner try another QR after the message has been read.
    Future.delayed(const Duration(seconds: 2), () => _busy = false);
  }

  /// "Find booking" with the typed code.
  void _findByCode() {
    FocusScope.of(context).unfocus();
    final code = _code.text.trim().toUpperCase();
    final rental =
        widget.rentals.where((r) => r.bookingCode == code).firstOrNull;
    _open(rental, notFoundLine: 'Check the code $code and try again.');
  }

  /// Tap on the grey "Find booking" button.
  void _explainCode() {
    showTopNotice(context,
        title: 'Enter the booking code',
        lines: [
          'The code has $_codeLength letters and numbers, e.g. 3F9A1C2B.',
          "It's under the QR on the customer's booking.",
        ],
        type: NoticeType.error);
  }

  /// Closes with [rental] if it can be handed over, otherwise explains why not.
  void _open(OwnerRental? rental, {required String notFoundLine}) {
    if (!mounted) return;
    if (rental == null) {
      showTopNotice(context,
          title: 'No booking found',
          lines: [notFoundLine],
          type: NoticeType.error);
      return;
    }
    switch (rental.status) {
      case 'pending_payment':
      case 'ready':
      case 'checked_in':
        Navigator.of(context).pop(rental); // O3 opens Start rental
      case 'active':
      case 'completed':
        showTopNotice(context,
            title: 'This booking has already started',
            lines: [
              '${rental.vehicleName} · ${rental.customerName}',
              'Find it under Active on Rentals.',
            ],
            type: NoticeType.error);
      default: // 'cancelled', 'expired'
        showTopNotice(context,
            title: 'This booking is cancelled or expired',
            lines: ['Ask the customer to make a new booking.'],
            type: NoticeType.error);
    }
  }

  // ---------- Screen ----------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _background,
      appBar: AppBar(
        backgroundColor: _background,
        toolbarHeight: 60,
        automaticallyImplyLeading: false,
        titleSpacing: 0,
        leadingWidth: 52,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        title: Text('Scan booking',
            style: inter(20, weight: FontWeight.w700, color: Colors.white)),
        actions: [
          // Torch for dark shops / evenings.
          ValueListenableBuilder<MobileScannerState>(
            valueListenable: _camera,
            builder: (_, state, __) {
              if (state.torchState == TorchState.unavailable) {
                return const SizedBox.shrink();
              }
              final on = state.torchState == TorchState.on;
              return IconButton(
                tooltip: on ? 'Turn off light' : 'Turn on light',
                icon: Icon(on ? Icons.flash_on : Icons.flash_off,
                    color: Colors.white),
                onPressed: _camera.toggleTorch,
              );
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              const SizedBox(height: 16),
              Center(child: _cameraBox()),
              const SizedBox(height: 20),
              Text("Point the camera at the customer's booking QR",
                  textAlign: TextAlign.center,
                  style:
                      inter(15, weight: FontWeight.w600, color: Colors.white)),
              if (kDebugMode) _debugSimulate(),
              const SizedBox(height: 28),
              _manualCard(),
            ],
          ),
        ),
      ),
    );
  }

  /// 300 × 300 rounded live camera with viewfinder corners and a scan line.
  Widget _cameraBox() {
    return SizedBox(
      width: 300,
      height: 300,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Stack(
          fit: StackFit.expand,
          children: [
            MobileScanner(
              controller: _camera,
              onDetect: _onDetect,
              errorBuilder: (context, error) => _cameraError(error),
              placeholderBuilder: (_) => const ColoredBox(color: Colors.black),
            ),
            const IgnorePointer(child: _Viewfinder()),
          ],
        ),
      ),
    );
  }

  /// Shown inside the camera box if the camera can't open.
  /// Typing the code below still works.
  Widget _cameraError(MobileScannerException error) {
    final denied = error.errorCode == MobileScannerErrorCode.permissionDenied;
    return ColoredBox(
      color: Colors.black,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.no_photography_outlined,
                size: 40, color: Colors.white70),
            const SizedBox(height: 12),
            Text(denied ? 'Camera not allowed' : "Camera can't open",
                style: inter(16, weight: FontWeight.w700, color: Colors.white)),
            const SizedBox(height: 6),
            Text(
                denied
                    ? 'Allow camera for this app in your phone Settings, '
                        'or enter the booking code below.'
                    : 'Enter the booking code below instead.',
                textAlign: TextAlign.center,
                style: inter(13, color: Colors.white70)),
            if (denied) ...[
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: () => _camera.start(), // asks again if allowed
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Colors.white70),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                ),
                child: Text('Try again',
                    style: inter(14,
                        weight: FontWeight.w600, color: Colors.white)),
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// White card: "Can't scan? Enter the booking code".
  Widget _manualCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text("Can't scan? Enter the booking code",
              style: inter(15, weight: FontWeight.w700)),
          const SizedBox(height: 10),
          TextField(
            controller: _code,
            textCapitalization: TextCapitalization.characters,
            textInputAction: TextInputAction.search,
            onSubmitted: (_) => _codeReady ? _findByCode() : _explainCode(),
            // Booking codes are 0-9 and A-F only, always shown in capitals.
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp('[0-9a-fA-F]')),
              LengthLimitingTextInputFormatter(_codeLength),
              _UpperCase(),
            ],
            style: inter(18, weight: FontWeight.w600).copyWith(letterSpacing: 3),
            decoration: InputDecoration(
              hintText: '3F9A1C2B',
              hintStyle: inter(18, color: AppColors.hint)
                  .copyWith(letterSpacing: 3),
              counterText: '',
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              enabledBorder: _border(AppColors.border),
              focusedBorder: _border(AppColors.ink),
            ),
          ),
          const SizedBox(height: 12),
          // Grey until 8 characters are typed. A tap on the grey button
          // still reaches the GestureDetector and explains what's missing.
          GestureDetector(
            onTap: _codeReady ? null : _explainCode,
            child: PrimaryButton(
              label: 'Find booking',
              onPressed: _codeReady ? _findByCode : null,
            ),
          ),
        ],
      ),
    );
  }

  /// Debug builds only (running from VS Code / terminal), never in the real
  /// app: pretend the camera read a QR, because there's no customer QR to
  /// scan yet.
  Widget _debugSimulate() {
    final withQr = widget.rentals.where((r) => r.qrToken != null).toList();
    if (withQr.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: TextButton.icon(
        onPressed: () => _open(withQr.first,
            notFoundLine: 'This QR is not an ISYGEAR booking.'),
        icon: const Icon(Icons.bug_report_outlined,
            size: 18, color: Colors.white54),
        label: Text('Simulate scan (debug only)',
            style: inter(13, color: Colors.white54)),
      ),
    );
  }

  static OutlineInputBorder _border(Color c) => OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: c, width: 1.5),
      );
}

/// Turns typed letters into capitals (3f9a -> 3F9A).
class _UpperCase extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
          TextEditingValue oldValue, TextEditingValue newValue) =>
      newValue.copyWith(text: newValue.text.toUpperCase());
}

/// White corner brackets plus a scan line that moves up and down.
class _Viewfinder extends StatefulWidget {
  const _Viewfinder();

  @override
  State<_Viewfinder> createState() => _ViewfinderState();
}

class _ViewfinderState extends State<_Viewfinder>
    with SingleTickerProviderStateMixin {
  late final _line = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 2),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _line.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(28),
      child: Stack(
        children: [
          const Positioned.fill(child: CustomPaint(painter: _CornersPainter())),
          AnimatedBuilder(
            animation: _line,
            builder: (_, __) => Align(
              alignment: Alignment(0, _line.value * 2 - 1),
              child: Container(
                height: 2,
                margin: const EdgeInsets.symmetric(horizontal: 12),
                color: Colors.white70,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CornersPainter extends CustomPainter {
  const _CornersPainter();

  @override
  void paint(Canvas canvas, Size size) {
    const len = 32.0;
    final p = Paint()
      ..color = Colors.white
      ..strokeWidth = 4
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    final w = size.width, h = size.height;
    for (final (start, a, b) in [
      (Offset.zero, const Offset(len, 0), const Offset(0, len)),
      (Offset(w, 0), Offset(w - len, 0), Offset(w, len)),
      (Offset(0, h), Offset(len, h), Offset(0, h - len)),
      (Offset(w, h), Offset(w - len, h), Offset(w, h - len)),
    ]) {
      canvas.drawLine(start, a, p);
      canvas.drawLine(start, b, p);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
