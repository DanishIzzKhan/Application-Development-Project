import 'package:flutter/material.dart';

import '../theme.dart';

void showToast(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));
}

/// Header used by C2, C2b, C3, C5: 60px, bottom border, optional back arrow.
class AppHeader extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final String? trailing;
  final bool showBack;

  const AppHeader({
    super.key,
    required this.title,
    this.trailing,
    this.showBack = true,
  });

  @override
  Size get preferredSize => const Size.fromHeight(61.5);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      toolbarHeight: 60,
      automaticallyImplyLeading: false,
      titleSpacing: showBack ? 0 : 16,
      leadingWidth: showBack ? 52 : 0,
      leading: showBack
          ? IconButton(
              icon: const Icon(Icons.arrow_back, color: AppColors.ink),
              onPressed: () => Navigator.of(context).maybePop(),
            )
          : null,
      title: Text(title, style: inter(20, weight: FontWeight.w700)),
      actions: [
        if (trailing != null)
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Center(
              child: Text(trailing!,
                  style: inter(14,
                      weight: FontWeight.w600, color: AppColors.text2)),
            ),
          ),
      ],
      bottom: const PreferredSize(
        preferredSize: Size.fromHeight(1.5),
        child: SizedBox(
          height: 1.5,
          width: double.infinity,
          child: ColoredBox(color: AppColors.divider),
        ),
      ),
    );
  }
}

OutlineInputBorder _border(Color c) => OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: BorderSide(color: c, width: 1.5),
    );

/// Label above a 48px outlined input, as in the wireframe.
class AppField extends StatelessWidget {
  final String label;
  final String hint;
  final TextEditingController controller;
  final bool obscure;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final String? Function(String?)? validator;

  const AppField({
    super.key,
    required this.label,
    required this.hint,
    required this.controller,
    this.obscure = false,
    this.keyboardType,
    this.textInputAction,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: inter(14, weight: FontWeight.w600)),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          obscureText: obscure,
          keyboardType: keyboardType,
          textInputAction: textInputAction,
          validator: validator,
          style: inter(15),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: inter(15, color: AppColors.hint),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
            enabledBorder: _border(AppColors.border),
            focusedBorder: _border(AppColors.ink),
            errorBorder: _border(Colors.red.shade700),
            focusedErrorBorder: _border(Colors.red.shade700),
          ),
        ),
      ],
    );
  }
}

class PrimaryButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool loading;

  const PrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.loading = false,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 52,
      width: double.infinity,
      child: FilledButton(
        onPressed: loading ? null : onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.dark,
          disabledBackgroundColor: AppColors.dark.withValues(alpha: 0.6),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
        child: loading
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                    strokeWidth: 2.5, color: Colors.white),
              )
            : Text(label,
                style: inter(15, weight: FontWeight.w600, color: Colors.white)),
      ),
    );
  }
}

class AppCheckRow extends StatelessWidget {
  final bool value;
  final ValueChanged<bool> onChanged;
  final String text;

  const AppCheckRow({
    super.key,
    required this.value,
    required this.onChanged,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => onChanged(!value),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 20,
            height: 20,
            child: Checkbox(
              value: value,
              onChanged: (v) => onChanged(v ?? false),
              activeColor: AppColors.dark,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              visualDensity: VisualDensity.compact,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(4)),
              side: const BorderSide(color: AppColors.dark, width: 1.5),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(child: Text(text, style: inter(13))),
        ],
      ),
    );
  }
}

/// Scrollable column that still lets a Spacer push the last widgets to the bottom.
class FormScroll extends StatelessWidget {
  final List<Widget> children;
  final EdgeInsets padding;

  const FormScroll({
    super.key,
    required this.children,
    this.padding = const EdgeInsets.all(16),
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, box) => SingleChildScrollView(
        padding: padding,
        child: ConstrainedBox(
          constraints:
              BoxConstraints(minHeight: box.maxHeight - padding.vertical),
          child: IntrinsicHeight(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: children,
            ),
          ),
        ),
      ),
    );
  }
}

/// Dashed rounded rectangle (photo / IC upload placeholders).
class DashedBox extends StatelessWidget {
  final double? width;
  final double? height;
  final double radius;
  final Widget? child;

  const DashedBox({
    super.key,
    this.width,
    this.height,
    this.radius = 10,
    this.child,
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      foregroundPainter: _DashPainter(radius),
      child: Container(
        width: width,
        height: height,
        alignment: Alignment.center,
        child: child,
      ),
    );
  }
}

class _DashPainter extends CustomPainter {
  final double radius;
  _DashPainter(this.radius);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.border
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    final rrect = RRect.fromRectAndRadius(
            Offset.zero & size, Radius.circular(radius))
        .deflate(0.75);
    final path = Path()..addRRect(rrect);
    for (final m in path.computeMetrics()) {
      double d = 0;
      while (d < m.length) {
        canvas.drawPath(m.extractPath(d, d + 5), paint);
        d += 9;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DashPainter old) => old.radius != radius;
}

String formatDateTime(DateTime t) {
  final h12 = t.hour % 12 == 0 ? 12 : t.hour % 12;
  final ampm = t.hour >= 12 ? 'PM' : 'AM';
  String two(int n) => n.toString().padLeft(2, '0');
  return '${two(t.day)}/${two(t.month)}/${t.year}  $h12:${two(t.minute)} $ampm';
}