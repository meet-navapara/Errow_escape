import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';

class OutOfHeartsDialog extends StatelessWidget {
  final VoidCallback onRetry;
  final VoidCallback onHome;

  const OutOfHeartsDialog({
    super.key,
    required this.onRetry,
    required this.onHome,
  });

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 28),
        child: Container(
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(28),
            boxShadow: const [
              BoxShadow(
                color: Color(0x1A000000),
                blurRadius: 30,
                offset: Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Broken heart visual
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: AppColors.heartActive.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.heart_broken_rounded,
                  size: 40,
                  color: AppColors.heartActive,
                ),
              ),
              const SizedBox(height: 20),

              // Title
              const Text(
                'Out of Hearts!',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 8),

              // Subtitle
              const Text(
                'You hit too many blocked arrows. Clear obstacles in the right order to win!',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: AppColors.textSecondary,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 28),

              // Retry Button
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton.icon(
                  onPressed: onRetry,
                  icon: const Icon(Icons.refresh_rounded, size: 20),
                  label: const Text('Retry Level (3 ❤️)'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.textPrimary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // Return Home Button
              SizedBox(
                width: double.infinity,
                height: 48,
                child: TextButton(
                  onPressed: onHome,
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.textSecondary,
                  ),
                  child: const Text('Return to Home'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
