import 'package:flutter/material.dart';

import '../../core/storage/cloud_sync_service.dart';
import '../../core/theme/app_colors.dart';
import '../app_services.dart';
import 'about_screen.dart';
import 'achievements_screen.dart';
import 'help_screen.dart';
import 'privacy_policy_screen.dart';
import 'privacy_preferences_screen.dart';
import 'settings_screen.dart';
import 'terms_screen.dart';

/// "Me" tab: account, awards, achievements, settings, help and privacy.
class ProfileScreen extends StatefulWidget {
  final AppServices services;

  const ProfileScreen({super.key, required this.services});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  AppServices get s => widget.services;

  Future<void> _open(Widget screen) async {
    s.tapFeedback();
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final auth = s.auth;
    return ColoredBox(
      color: AppColors.pageBackground,
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          children: [
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Center(
                child: Text(
                  'Me',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
                ),
              ),
            ),
            if (auth != null)
              ListenableBuilder(
                listenable: Listenable.merge([auth, auth.cloudSync.status]),
                builder: (context, _) => _Card(
                  children: [
                    ListTile(
                      leading: CircleAvatar(
                        backgroundColor: AppColors.primary.withValues(
                          alpha: 0.12,
                        ),
                        child: Icon(
                          auth.isAuthenticated
                              ? Icons.cloud_done_rounded
                              : Icons.person_rounded,
                          color: AppColors.primary,
                        ),
                      ),
                      title: Text(auth.displayName),
                      subtitle: Text(
                        auth.isAuthenticated
                            ? syncStatusLabel(auth.cloudSync.status.value)
                            : 'Guest · progress saved on this device only',
                      ),
                      trailing: auth.isAuthenticated
                          ? null
                          : TextButton(
                              onPressed: auth.isLoading
                                  ? null
                                  : () async {
                                      final ok = await auth.signInWithGoogle();
                                      if (!context.mounted) return;
                                      if (!ok && auth.errorMessage != null) {
                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
                                          SnackBar(
                                            content: Text(auth.errorMessage!),
                                          ),
                                        );
                                      }
                                    },
                              child: const Text('Sign in'),
                            ),
                    ),
                  ],
                ),
              ),
            _Card(
              children: [
                _Item(
                  icon: Icons.military_tech_rounded,
                  color: const Color(0xFFF59E0B),
                  title: 'Awards',
                  large: true,
                  onTap: () => _open(AwardsScreen(storage: s.storage)),
                ),
              ],
            ),
            _Card(
              children: [
                _Item(
                  icon: Icons.sports_esports_rounded,
                  color: const Color(0xFF84CC16),
                  title: 'Achievements',
                  large: true,
                  onTap: () => _open(AchievementsScreen(storage: s.storage)),
                ),
              ],
            ),
            _Card(
              children: [
                _Item(
                  icon: Icons.settings_rounded,
                  color: AppColors.primary,
                  title: 'Settings',
                  onTap: () => _open(
                    SettingsScreen(
                      storage: s.storage,
                      sound: s.sound,
                      haptic: s.haptic,
                      auth: s.auth,
                    ),
                  ),
                ),
              ],
            ),
            _Card(
              children: [
                _Item(
                  icon: Icons.help_rounded,
                  color: AppColors.success,
                  title: 'Help',
                  onTap: () => _open(HelpScreen(storage: s.storage)),
                ),
                _Item(
                  icon: Icons.info_rounded,
                  color: AppColors.primary,
                  title: 'About Game',
                  onTap: () => _open(const AboutScreen()),
                ),
                _Item(
                  icon: Icons.policy_rounded,
                  color: const Color(0xFF6366F1),
                  title: 'Privacy Policy',
                  onTap: () => _open(const PrivacyPolicyScreen()),
                ),
                _Item(
                  icon: Icons.gavel_rounded,
                  color: const Color(0xFF64748B),
                  title: 'Terms of Service',
                  onTap: () => _open(const TermsScreen()),
                ),
                _Item(
                  icon: Icons.manage_accounts_rounded,
                  color: const Color(0xFF06B6D4),
                  title: 'Privacy Preferences',
                  onTap: () => _open(const PrivacyPreferencesScreen()),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

String syncStatusLabel(SyncStatus status) => switch (status) {
  SyncStatus.signedOut => 'Not signed in',
  SyncStatus.idle => 'Signed in · cloud backup on',
  SyncStatus.pending => 'Changes waiting to sync…',
  SyncStatus.syncing => 'Syncing…',
  SyncStatus.synced => 'All progress backed up',
  SyncStatus.offline => 'Offline · will sync when connected',
};

class _Card extends StatelessWidget {
  final List<Widget> children;

  const _Card({required this.children});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppRadii.card),
        clipBehavior: Clip.antiAlias,
        child: Column(
          children: [
            for (var i = 0; i < children.length; i++) ...[
              if (i > 0) const Divider(height: 1, indent: 72),
              children[i],
            ],
          ],
        ),
      ),
    );
  }
}

class _Item extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final bool large;
  final VoidCallback onTap;

  const _Item({
    required this.icon,
    required this.color,
    required this.title,
    required this.onTap,
    this.large = false,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      minTileHeight: large ? 84 : 60,
      leading: large
          ? CircleAvatar(
              radius: 26,
              backgroundColor: color.withValues(alpha: 0.15),
              child: Icon(icon, color: color, size: 30),
            )
          : Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: Colors.white, size: 22),
            ),
      title: Text(
        title,
        style: TextStyle(
          fontSize: large ? 20 : 17,
          fontWeight: FontWeight.w500,
        ),
      ),
      trailing: const Icon(
        Icons.chevron_right_rounded,
        color: AppColors.textMuted,
      ),
      onTap: onTap,
    );
  }
}
