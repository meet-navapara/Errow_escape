import 'package:flutter/material.dart';

import '../../core/storage/storage_service.dart';
import '../../core/theme/app_colors.dart';
import '../../models/power_up.dart';
import '../widgets/power_up_bar.dart';

/// How to play, power-up reference and tutorial replay.
class HelpScreen extends StatelessWidget {
  final StorageService storage;

  const HelpScreen({super.key, required this.storage});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.pageBackground,
      appBar: AppBar(
        title: const Text('Help'),
        backgroundColor: AppColors.pageBackground,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const _Section(
            title: 'How to play',
            lines: [
              'Tap an arrow to launch it in the direction its head points.',
              'It escapes only if no other arrow is in that path, all the way to the edge of the board.',
              'Tapping a blocked arrow costs one heart. With no hearts left you retry the level.',
              'Clear every arrow to finish the level.',
              'Pinch to zoom, drag to pan, and tap "Reset View" to fit the board again.',
              'Undo takes back your last move but never refunds hearts. Restart gives you three fresh hearts.',
            ],
          ),
          _Section(
            title: 'Power-ups',
            lines: [
              for (final t in PowerUpType.values)
                '${t.label}: ${t.description}',
              'Every player gets ${PowerUpType.starterAllowance} free uses of each tool, once. '
                  'When a tool is empty you can choose to watch a short ad for one more use. '
                  'Ads are optional and never required to finish a level.',
              'Finishing a daily challenge for the first time gives a bonus hint.',
            ],
            icons: [for (final t in PowerUpType.values) t.icon],
          ),
          const _Section(
            title: 'Progress',
            lines: [
              'As a guest, progress is saved on this device only.',
              'Sign in with Google (Me > Sign in) to back it up and continue on other devices. Your guest progress is merged into your account, never discarded.',
            ],
          ),
          const SizedBox(height: 8),
          FilledButton.icon(
            onPressed: () async {
              await storage.resetTutorials();
              if (!context.mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                    'Tutorials will play again on the home screen, in your '
                    'next game and in levels 1-3.',
                  ),
                ),
              );
            },
            icon: const Icon(Icons.replay_rounded),
            label: const Text('Replay tutorials'),
          ),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  final String title;
  final List<String> lines;
  final List<IconData>? icons;

  const _Section({required this.title, required this.lines, this.icons});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      color: Colors.white,
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            for (var i = 0; i < lines.length; i++)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      icons != null && i < icons!.length
                          ? icons![i]
                          : Icons.circle,
                      size: icons != null && i < icons!.length ? 18 : 6,
                      color: AppColors.primary,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        lines[i],
                        style: const TextStyle(height: 1.4),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
