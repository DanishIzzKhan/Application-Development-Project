import 'dart:async';

import 'package:flutter/material.dart';

import '../models/rental.dart';
import '../theme.dart';

/// Red for reminders and errors. Same red as the error border in
/// common.dart (AppField). Could move into AppColors if the group agrees.
final errorRed = Colors.red.shade700;

/// Small rounded label. Filled = PAID, OVERDUE, CURRENT, AVAILABLE.
/// Outline = PENDING, LATE, ISSUE.
class RentalBadge extends StatelessWidget {
  final String text;
  final bool filled;

  const RentalBadge(this.text, {super.key, this.filled = true});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: filled ? AppColors.dark : Colors.white,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AppColors.dark, width: 1.5),
      ),
      child: Text(
        text,
        style: inter(11,
            weight: FontWeight.w700,
            color: filled ? Colors.white : AppColors.dark),
      ),
    );
  }
}

/// Bold section heading, e.g. "Waiting for payment".
class SectionTitle extends StatelessWidget {
  final String text;
  const SectionTitle(this.text, {super.key});

  @override
  Widget build(BuildContext context) {
    return Text(text, style: inter(15, weight: FontWeight.w700));
  }
}

/// White card, 1.5 grey border, radius 10, padding 12.
/// Use [strong] for the dark 2px border (payment card on O5).
/// Set [error] to show a red 2px border (something still needs doing).
class OutlinedCard extends StatelessWidget {
  final Widget child;
  final bool strong;
  final bool error;
  final Color color;

  const OutlinedCard({
    super.key,
    required this.child,
    this.strong = false,
    this.error = false,
    this.color = Colors.white,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: error
              ? errorRed
              : (strong ? AppColors.dark : AppColors.divider),
          width: (strong || error) ? 2 : 1.5,
        ),
      ),
      child: child,
    );
  }
}

/// Small button used inside rows ("Open", "Start", "End", "View IC").
/// [primary] = dark fill + white text, otherwise white with dark border.
class SmallButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool primary;
  final IconData? icon;

  const SmallButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.primary = true,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final shape =
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(8));
    const padding = EdgeInsets.symmetric(horizontal: 14);
    final text = Text(label,
        style: inter(13,
            weight: FontWeight.w600,
            color: primary ? Colors.white : AppColors.dark));
    final child = icon == null
        ? text
        : Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon,
                size: 16, color: primary ? Colors.white : AppColors.dark),
            const SizedBox(width: 6),
            text,
          ]);

    return SizedBox(
      height: 36,
      child: primary
          ? FilledButton(
              onPressed: onPressed,
              style: FilledButton.styleFrom(
                  backgroundColor: AppColors.dark,
                  padding: padding,
                  shape: shape),
              child: child,
            )
          : OutlinedButton(
              onPressed: onPressed,
              style: OutlinedButton.styleFrom(
                  padding: padding,
                  shape: shape,
                  side: const BorderSide(color: AppColors.dark, width: 1.5)),
              child: child,
            ),
    );
  }
}

/// Card at the top of O5 / O6 / O6c:
/// "Scooter S01 · ahmad_rides" / "Booking ISY-4821 · now · 1 hr 0 min" / optional link.
class RentalSummaryCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final String? linkText;
  final VoidCallback? onLinkTap;

  const RentalSummaryCard({
    super.key,
    required this.title,
    required this.subtitle,
    this.linkText,
    this.onLinkTap,
  });

  @override
  Widget build(BuildContext context) {
    return OutlinedCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: inter(16, weight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text(subtitle, style: inter(13, color: AppColors.text2)),
          if (linkText != null) ...[
            const SizedBox(height: 10),
            InkWell(
              onTap: onLinkTap,
              child: Text(linkText!,
                  style: inter(13,
                      weight: FontWeight.w600, color: AppColors.ink)),
            ),
          ],
        ],
      ),
    );
  }
}

/// Good / Minor issue / Damaged — compact pills in one row, one selected (O5, O6).
class ConditionChips extends StatelessWidget {
  final VehicleCondition value;
  final ValueChanged<VehicleCondition> onChanged;

  const ConditionChips({
    super.key,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (final c in VehicleCondition.values) ...[
          if (c != VehicleCondition.values.first) const SizedBox(width: 8),
          _Chip(
            label: c.label,
            selected: c == value,
            onTap: () => onChanged(c),
          ),
        ],
      ],
    );
  }
}

/// Same compact pills as ConditionChips, for any list of choices
/// (e.g. O4 "Payment received": Cash / Touch 'n Go / Bank QR).
class OptionChips extends StatelessWidget {
  final List<String> options;
  final int selected; // index of the chosen option
  final ValueChanged<int> onChanged;

  const OptionChips({
    super.key,
    required this.options,
    required this.selected,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (var i = 0; i < options.length; i++)
          _Chip(
            label: options[i],
            selected: i == selected,
            onTap: () => onChanged(i),
          ),
      ],
    );
  }
}

/// − / "1 hr 0 min" / +  with a hint underneath.
/// Each tap adds or removes [step] minutes (20-minute blocks).
class DurationStepper extends StatelessWidget {
  final int minutes;
  final ValueChanged<int> onChanged;
  final int step;
  final int min;
  final int max;
  final String hint;

  const DurationStepper({
    super.key,
    required this.minutes,
    required this.onChanged,
    this.step = 20,
    this.min = 20,
    this.max = 480,
    this.hint = 'Each tap adds or removes 20 minutes',
  });

  @override
  Widget build(BuildContext context) {
    Widget button(IconData icon, VoidCallback? onTap) => SizedBox(
          width: 48,
          height: 48,
          child: OutlinedButton(
            onPressed: onTap,
            style: OutlinedButton.styleFrom(
              padding: EdgeInsets.zero,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
              side: BorderSide(
                  color: onTap == null ? AppColors.divider : AppColors.dark,
                  width: 1.5),
            ),
            child: Icon(icon,
                color: onTap == null ? AppColors.divider : AppColors.dark),
          ),
        );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            button(Icons.remove,
                minutes > min ? () => onChanged(minutes - step) : null),
            Expanded(
              child: Text(formatDuration(minutes),
                  textAlign: TextAlign.center,
                  style: inter(18, weight: FontWeight.w700)),
            ),
            button(Icons.add,
                minutes < max ? () => onChanged(minutes + step) : null),
          ],
        ),
        const SizedBox(height: 6),
        Text(hint,
            textAlign: TextAlign.center,
            style: inter(12, color: AppColors.hint)),
      ],
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _Chip(
      {required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        height: 32,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? AppColors.dark : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.dark, width: 1.5),
        ),
        child: Text(label,
            style: inter(13,
                weight: FontWeight.w600,
                color: selected ? Colors.white : AppColors.dark)),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Top notification: slides in at the top of the screen, then disappears.
// ---------------------------------------------------------------------------

/// success = something worked (dark ✓), info = for your information (grey ⓘ),
/// error = something is missing or failed (red ⚠).
enum NoticeType { success, info, error }

OverlayEntry? _currentNotice;

/// Shows a notification at the top for about 3 seconds, then it slides away.
/// Tap it to close it early. Use this for every short message on owner screens.
///
///   showTopNotice(context, title: 'Payment recorded', type: NoticeType.success);
///   showTopNotice(context, title: "Can't start rental yet",
///       lines: ['Confirm payment to start'], type: NoticeType.error);
void showTopNotice(BuildContext context,
    {required String title,
    List<String> lines = const [],
    NoticeType type = NoticeType.info}) {
  // Only one notification at a time.
  if (_currentNotice?.mounted ?? false) _currentNotice!.remove();

  late final OverlayEntry entry;
  entry = OverlayEntry(
    builder: (_) => _TopNotice(
      title: title,
      lines: lines,
      type: type,
      onDone: () {
        if (entry.mounted) entry.remove();
        if (_currentNotice == entry) _currentNotice = null;
      },
    ),
  );
  _currentNotice = entry;
  Overlay.of(context).insert(entry);
}

class _TopNotice extends StatefulWidget {
  final String title;
  final List<String> lines;
  final NoticeType type;
  final VoidCallback onDone;

  const _TopNotice({
    required this.title,
    required this.lines,
    required this.type,
    required this.onDone,
  });

  @override
  State<_TopNotice> createState() => _TopNoticeState();
}

class _TopNoticeState extends State<_TopNotice>
    with SingleTickerProviderStateMixin {
  late final _anim = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 250));
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _anim.forward(); // slide in
    _timer = Timer(const Duration(seconds: 3), _close);
  }

  Future<void> _close() async {
    _timer?.cancel();
    if (!mounted) return;
    await _anim.reverse(); // slide out
    if (mounted) widget.onDone();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _anim.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.of(context).padding.top + 8;
    final (Color color, IconData icon) = switch (widget.type) {
      NoticeType.success => (AppColors.dark, Icons.check_circle_outline),
      NoticeType.info => (AppColors.text2, Icons.info_outline),
      NoticeType.error => (errorRed, Icons.error_outline),
    };
    return Positioned(
      top: top,
      left: 16,
      right: 16,
      child: SlideTransition(
        position: Tween(begin: const Offset(0, -1.5), end: Offset.zero)
            .animate(CurvedAnimation(parent: _anim, curve: Curves.easeOut)),
        child: Material(
          color: Colors.transparent,
          child: GestureDetector(
            onTap: _close,
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: color, width: 1.5),
                boxShadow: const [
                  BoxShadow(
                      color: Color(0x33000000),
                      blurRadius: 12,
                      offset: Offset(0, 4)),
                ],
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(icon, size: 20, color: color),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(widget.title,
                            style: inter(14,
                                weight: FontWeight.w700, color: color)),
                        for (final line in widget.lines) ...[
                          const SizedBox(height: 4),
                          Text('• $line', style: inter(13, color: color)),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
