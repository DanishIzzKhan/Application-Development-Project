import 'package:flutter/material.dart';

import '../models/rental.dart';
import '../theme.dart';

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
class OutlinedCard extends StatelessWidget {
  final Widget child;
  final bool strong;
  final Color color;

  const OutlinedCard({
    super.key,
    required this.child,
    this.strong = false,
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
          color: strong ? AppColors.dark : AppColors.divider,
          width: strong ? 2 : 1.5,
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

/// Good / Minor issue / Damaged — one can be selected (O5, O6).
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
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final c in VehicleCondition.values)
          _Chip(
            label: c.label,
            selected: c == value,
            onTap: () => onChanged(c),
          ),
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
      borderRadius: BorderRadius.circular(20),
      child: Container(
        height: 40,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? AppColors.dark : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.dark, width: 1.5),
        ),
        child: Text(label,
            style: inter(14,
                weight: FontWeight.w600,
                color: selected ? Colors.white : AppColors.dark)),
      ),
    );
  }
}
