import 'package:flutter/material.dart';

import '../../core/ads/ad_service.dart';
import '../../core/theme/app_colors.dart';
import '../../game/game_controller.dart';
import '../../models/power_up.dart';

extension PowerUpVisuals on PowerUpType {
  IconData get icon => switch (this) {
    PowerUpType.hint => Icons.lightbulb_rounded,
    PowerUpType.eraser => Icons.cleaning_services_rounded,
    PowerUpType.wand => Icons.auto_fix_high_rounded,
    PowerUpType.scanner => Icons.straighten_rounded,
  };

  Color get color => switch (this) {
    PowerUpType.hint => const Color(0xFFF59E0B),
    PowerUpType.eraser => const Color(0xFFEC4899),
    PowerUpType.wand => const Color(0xFF8B5CF6),
    PowerUpType.scanner => const Color(0xFF6366F1),
  };
}

/// Bottom panel with the four power-ups. Each shows its remaining uses, or
/// "Ad" when empty (an optional rewarded ad can refill it).
class PowerUpBar extends StatelessWidget {
  final GameController controller;
  final void Function(PowerUpType) onPressed;
  final void Function(PowerUpType) onInfo;
  final bool busy;

  const PowerUpBar({
    super.key,
    required this.controller,
    required this.onPressed,
    required this.onInfo,
    this.busy = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        for (final type in PowerUpType.values)
          Flexible(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: _PowerUpButton(
                type: type,
                count: controller.balanceOf(type),
                active:
                    controller.activeTool == type ||
                    (type == PowerUpType.hint &&
                        controller.hintedArrow != null),
                enabled: controller.isPlayable && !busy,
                onTap: () => onPressed(type),
                onLongPress: () => onInfo(type),
              ),
            ),
          ),
      ],
    );
  }
}

class _PowerUpButton extends StatelessWidget {
  final PowerUpType type;
  final int count;
  final bool active;
  final bool enabled;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  const _PowerUpButton({
    required this.type,
    required this.count,
    required this.active,
    required this.enabled,
    required this.onTap,
    required this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final empty = count <= 0;
    return Semantics(
      button: true,
      label:
          '${type.label}, ${empty ? 'empty, watch ad to refill' : '$count left'}',
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Material(
                  color: Colors.transparent,
                  shape: const CircleBorder(),
                  child: InkWell(
                    customBorder: const CircleBorder(),
                    onTap: enabled ? onTap : null,
                    onLongPress: onLongPress,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: 62,
                      height: 62,
                      decoration: BoxDecoration(
                        color: active
                            ? Color.alphaBlend(
                                type.color.withValues(alpha: 0.14),
                                Colors.white,
                              )
                            : Colors.white,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: active ? type.color : AppColors.border,
                          width: active ? 2.5 : 1.5,
                        ),
                        boxShadow: AppShadows.floating,
                      ),
                      child: Opacity(
                        opacity: enabled ? 1 : 0.4,
                        child: Icon(type.icon, color: type.color, size: 30),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  top: -4,
                  right: -6,
                  child: Container(
                    constraints: const BoxConstraints(minWidth: 22),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(11),
                      border: Border.all(color: Colors.white, width: 1.5),
                    ),
                    child: Text(
                      empty ? 'Ad' : '$count',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              type.label,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Explains a power-up and, when it is empty, offers an optional rewarded
/// ad. Resolves to true when the player chose "Use it now".
class PowerUpSheet extends StatefulWidget {
  final GameController controller;
  final PowerUpType type;
  final bool introduction;

  const PowerUpSheet({
    super.key,
    required this.controller,
    required this.type,
    this.introduction = false,
  });

  static Future<bool> show(
    BuildContext context,
    GameController controller,
    PowerUpType type, {
    bool introduction = false,
  }) async {
    final use = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: Colors.white,
      builder: (_) => PowerUpSheet(
        controller: controller,
        type: type,
        introduction: introduction,
      ),
    );
    return use ?? false;
  }

  @override
  State<PowerUpSheet> createState() => _PowerUpSheetState();
}

class _PowerUpSheetState extends State<PowerUpSheet> {
  bool _loading = false;
  String? _message;

  Future<void> _watchAd() async {
    setState(() {
      _loading = true;
      _message = null;
    });
    final outcome = await widget.controller.earnWithAd(widget.type);
    if (!mounted) return;
    setState(() {
      _loading = false;
      _message = switch (outcome) {
        RewardedAdOutcome.rewarded => '+1 ${widget.type.label} added!',
        RewardedAdOutcome.dismissed =>
          'The ad was closed early, so no reward was given.',
        RewardedAdOutcome.failed =>
          'No ad is available right now. Please try again later.',
        RewardedAdOutcome.unavailable =>
          'Ads are not available on this device or build.',
      };
    });
  }

  @override
  Widget build(BuildContext context) {
    final type = widget.type;
    final count = widget.controller.balanceOf(type);
    return SafeArea(
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircleAvatar(
                radius: 30,
                backgroundColor: type.color.withValues(alpha: 0.12),
                child: Icon(type.icon, color: type.color, size: 32),
              ),
              const SizedBox(height: 10),
              Text(
                widget.introduction ? 'New tool: ${type.label}' : type.label,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                type.description,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 14,
                  height: 1.4,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                count > 0
                    ? 'You have $count use${count == 1 ? '' : 's'} left. '
                          'New players get ${PowerUpType.starterAllowance} free uses of every tool.'
                    : 'You are out of ${type.label}s. You can watch an optional '
                          'short ad to earn one more. Ads are never required to finish a level.',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 13,
                  color: AppColors.textMuted,
                ),
              ),
              if (_message != null) ...[
                const SizedBox(height: 10),
                Text(
                  _message!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primary,
                  ),
                ),
              ],
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(context).pop(false),
                      child: const Text('Not now'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: count > 0
                        ? FilledButton(
                            onPressed: () => Navigator.of(context).pop(true),
                            child: const Text('Use it now'),
                          )
                        : FilledButton.icon(
                            onPressed: _loading ? null : _watchAd,
                            icon: _loading
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Icon(Icons.ondemand_video_rounded),
                            label: const Text('Watch ad'),
                          ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
