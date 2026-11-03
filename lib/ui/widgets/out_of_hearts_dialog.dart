import 'package:flutter/material.dart';

import '../../core/ads/ad_service.dart';
import '../../core/theme/app_colors.dart';

class OutOfHeartsDialog extends StatefulWidget {
  final VoidCallback onRetry;
  final VoidCallback onHome;

  /// Plays a rewarded ad to continue the same board. When null, the
  /// "Watch Ad" option is hidden.
  final Future<RewardedAdOutcome> Function()? onWatchAd;

  /// Hearts the player gets back after the ad.
  final int reviveHearts;

  const OutOfHeartsDialog({
    super.key,
    required this.onRetry,
    required this.onHome,
    this.onWatchAd,
    this.reviveHearts = 1,
  });

  @override
  State<OutOfHeartsDialog> createState() => _OutOfHeartsDialogState();
}

class _OutOfHeartsDialogState extends State<OutOfHeartsDialog> {
  bool _loading = false;
  String? _message;

  Future<void> _watchAd() async {
    setState(() {
      _loading = true;
      _message = null;
    });
    final outcome = await widget.onWatchAd!();
    if (!mounted) return;
    setState(() {
      _loading = false;
      _message = switch (outcome) {
        // The caller closes the dialog on success.
        RewardedAdOutcome.rewarded => null,
        RewardedAdOutcome.dismissed =>
          'The ad was closed early, so no heart was given.',
        RewardedAdOutcome.failed =>
          'No ad is available right now. Please try again later.',
        RewardedAdOutcome.unavailable =>
          'Ads are not available on this device or build.',
      };
    });
  }

  @override
  Widget build(BuildContext context) {
    final hearts = widget.reviveHearts;
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
          child: SingleChildScrollView(
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
                Text(
                  widget.onWatchAd == null
                      ? 'You hit too many blocked arrows. Clear obstacles in the right order to win!'
                      : 'Watch a short ad to keep this board and continue '
                            'with $hearts ${hearts == 1 ? 'heart' : 'hearts'}, '
                            'or start the level again.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 14,
                    color: AppColors.textSecondary,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 28),

                // Watch Ad to Continue
                if (widget.onWatchAd != null) ...[
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton.icon(
                      key: const ValueKey('revive-with-ad'),
                      onPressed: _loading ? null : _watchAd,
                      icon: _loading
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(
                              Icons.play_circle_fill_rounded,
                              size: 20,
                            ),
                      label: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          _loading
                              ? 'Loading ad...'
                              : 'Watch Ad to Continue (+$hearts ❤️)',
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        disabledBackgroundColor: AppColors.primary.withValues(
                          alpha: 0.7,
                        ),
                        disabledForegroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                    ),
                  ),
                  if (_message != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 10),
                      child: Text(
                        _message!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                  const SizedBox(height: 12),
                ],

                // Retry Button
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton.icon(
                    onPressed: _loading ? null : widget.onRetry,
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
                    onPressed: _loading ? null : widget.onHome,
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
      ),
    );
  }
}
