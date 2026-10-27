import 'package:flutter/material.dart';

import '../../core/ads/ad_service.dart';
import '../../core/theme/app_colors.dart';

/// Lets players review or change advertising consent through Google's User
/// Messaging Platform, where regional rules require it (e.g. EEA, UK).
class PrivacyPreferencesScreen extends StatefulWidget {
  const PrivacyPreferencesScreen({super.key});

  @override
  State<PrivacyPreferencesScreen> createState() =>
      _PrivacyPreferencesScreenState();
}

class _PrivacyPreferencesScreenState extends State<PrivacyPreferencesScreen> {
  late final Future<bool> _required = ConsentService.privacyOptionsRequired();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Privacy Preferences')),
      body: FutureBuilder<bool>(
        future: _required,
        builder: (context, snap) {
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          return ListView(
            padding: const EdgeInsets.all(24),
            children: [
              const Text(
                'Advertising',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 8),
              const Text(
                'Arrow Escape only shows ads when you choose to watch one to '
                'earn a power-up. Ads are provided by Google AdMob. Where the '
                'law requires it, you are asked for consent before any ad is '
                'requested.',
                style: TextStyle(height: 1.5, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 20),
              if (snap.data!)
                FilledButton.icon(
                  onPressed: () async {
                    await ConsentService.showPrivacyOptions();
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Preferences updated.')),
                    );
                  },
                  icon: const Icon(Icons.tune_rounded),
                  label: const Text('Manage ad consent'),
                )
              else
                const Card(
                  elevation: 0,
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: Text(
                      'No additional ad-consent choices are required for your '
                      'region on this device. You can still simply never tap '
                      '"Watch ad"; no ads will be shown.',
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}
