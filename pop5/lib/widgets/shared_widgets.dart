import 'package:flutter/material.dart';
import '../theme.dart';

/// ADP-116: Status Badge Widget
class StatusBadge extends StatelessWidget {
  final String status;

  const StatusBadge({
    super.key,
    required this.status,
  });

  @override
  Widget build(BuildContext context) {
    final normalized = status.toLowerCase().trim();
    Color bgColor;
    Color textColor;

    switch (normalized) {
      case 'active':
      case 'in_use':
      case 'rented':
        bgColor = Colors.green.shade100;
        textColor = Colors.green.shade800;
        break;
      case 'available':
      case 'ready':
        bgColor = Colors.blue.shade100;
        textColor = Colors.blue.shade800;
        break;
      case 'overdue':
      case 'late':
        bgColor = Colors.red.shade100;
        textColor = Colors.red.shade800;
        break;
      case 'pending':
      case 'waiting':
        bgColor = Colors.orange.shade100;
        textColor = Colors.orange.shade800;
        break;
      case 'completed':
      case 'ended':
        bgColor = AppColors.surface;
        textColor = AppColors.text2;
        break;
      default:
        bgColor = AppColors.surface;
        textColor = AppColors.dark;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        status.toUpperCase(),
        style: inter(12, weight: FontWeight.bold, color: textColor),
      ),
    );
  }
}

/// ADP-116: Standard List Row Widget
class StandardListRow extends StatelessWidget {
  final String title;
  final String? subtitle;
  final String? trailingText;
  final Widget? trailingWidget;
  final VoidCallback? onTap;

  const StandardListRow({
    super.key,
    required this.title,
    this.subtitle,
    this.trailingText,
    this.trailingWidget,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      title: Text(
        title,
        style: inter(15, weight: FontWeight.w600, color: AppColors.ink),
      ),
      subtitle: subtitle != null
          ? Text(
              subtitle!,
              style: inter(13, color: AppColors.text2),
            )
          : null,
      trailing: trailingWidget ??
          (trailingText != null
              ? Text(
                  trailingText!,
                  style:
                      inter(14, weight: FontWeight.bold, color: AppColors.ink),
                )
              : null),
    );
  }
}
