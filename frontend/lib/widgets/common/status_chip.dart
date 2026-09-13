import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';

/// Highly readable status indicator chip with high contrast styling.
class StatusChip extends StatelessWidget {
  final String label;
  final Color backgroundColor;
  final Color textColor;
  final IconData? icon;

  const StatusChip({
    super.key,
    required this.label,
    required this.backgroundColor,
    required this.textColor,
    this.icon,
  });

  /// Factory for 'PENDING' / 'IN_PROGRESS' states (Amber/Gold)
  factory StatusChip.pending({
    Key? key,
    String label = 'Pending',
    IconData icon = Icons.hourglass_top_rounded,
  }) {
    return StatusChip(
      key: key,
      label: label,
      backgroundColor: AppTheme.statusPendingBg,
      textColor: AppTheme.statusPending,
      icon: icon,
    );
  }

  /// Factory for 'COMPLETED' / 'WORK_DONE' states (Emerald Green)
  factory StatusChip.completed({
    Key? key,
    String label = 'Completed',
    IconData icon = Icons.check_circle_rounded,
  }) {
    return StatusChip(
      key: key,
      label: label,
      backgroundColor: AppTheme.statusCompletedBg,
      textColor: AppTheme.statusCompleted,
      icon: icon,
    );
  }

  /// Factory for 'CANCELLED' / 'ERROR' states (Vibrant Red)
  factory StatusChip.cancelled({
    Key? key,
    String label = 'Cancelled',
    IconData icon = Icons.cancel_rounded,
  }) {
    return StatusChip(
      key: key,
      label: label,
      backgroundColor: AppTheme.statusCancelledBg,
      textColor: AppTheme.statusCancelled,
      icon: icon,
    );
  }

  /// Factory for 'IN_PROGRESS' states (Blue)
  factory StatusChip.inProgress({
    Key? key,
    String label = 'In Progress',
    IconData icon = Icons.play_circle_fill_rounded,
  }) {
    return StatusChip(
      key: key,
      label: label,
      backgroundColor: const Color(0xFFDBEAFE),
      textColor: AppTheme.primaryBlue,
      icon: icon,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppTheme.space12,
        vertical: AppTheme.space4 + 2,
      ),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(AppTheme.radiusFull),
        border: Border.all(color: textColor.withValues(alpha: 0.3), width: 1.0),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 16, color: textColor),
            const SizedBox(width: AppTheme.space4),
          ],
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: textColor,
            ),
          ),
        ],
      ),
    );
  }
}
