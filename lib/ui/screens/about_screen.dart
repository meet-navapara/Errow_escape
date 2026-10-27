import 'package:flutter/material.dart';

import '../../core/app_info.dart';
import '../../core/theme/app_colors.dart';
import '../widgets/game_logo_widget.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('About Game')),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          const Center(child: GameLogoWidget(size: 96)),
          const SizedBox(height: 16),
          const Center(
            child: Text(
              'Version ${AppInfo.version} (${AppInfo.buildNumber})',
              style: TextStyle(color: AppColors.textSecondary),
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'Arrow Escape is a logic puzzle: clear the board by launching each '
            'arrow in the right order. 100 levels, a daily puzzle and a weekly '
            'challenge, all checked by a solver so every puzzle can be solved.',
            style: TextStyle(height: 1.5),
          ),
          const SizedBox(height: 24),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.mail_outline_rounded),
            title: const Text('Support'),
            subtitle: const Text(AppInfo.supportEmail),
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.description_outlined),
            title: const Text('Open-source licenses'),
            onTap: () => showLicensePage(
              context: context,
              applicationName: AppInfo.name,
              applicationVersion: AppInfo.version,
            ),
          ),
        ],
      ),
    );
  }
}
