import 'dart:ui';
import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';

/// Reusable subtle glassmorphic card widget.
/// Carefully calibrated for high contrast and readability in bright industrial factory settings.
class GlassCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry? margin;
  final double borderRadius;
  final VoidCallback? onTap;
  final Color? color;
  final Color? borderColor;
  final double blur;

  const GlassCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(AppTheme.space16),
    this.margin,
    this.borderRadius = AppTheme.radiusLarge,
    this.onTap,
    this.color,
    this.borderColor,
    this.blur = AppTheme.glassBlur,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveColor = color ?? AppTheme.glassFill;
    final effectiveBorderColor = borderColor ?? AppTheme.glassBorder;

    Widget content = ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
        child: Container(
          decoration: BoxDecoration(
            color: effectiveColor,
            borderRadius: BorderRadius.circular(borderRadius),
            border: Border.all(color: effectiveBorderColor, width: 1.5),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            child: onTap != null
                ? InkWell(
                    borderRadius: BorderRadius.circular(borderRadius),
                    onTap: onTap,
                    child: Padding(padding: padding, child: child),
                  )
                : Padding(padding: padding, child: child),
          ),
        ),
      ),
    );

    if (margin != null) {
      content = Padding(padding: margin!, child: content);
    }

    return content;
  }
}
