import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/storage/storage_service.dart';
import '../../core/audio/sound_service.dart';
import '../../core/audio/haptic_service.dart';
import '../../core/auth/auth_service.dart';
import 'privacy_policy_screen.dart';
import 'terms_screen.dart';
import 'profile_screen.dart' show syncStatusLabel;
import '../../core/app_info.dart';

class SettingsScreen extends StatefulWidget {
  final StorageService storage;
  final SoundService sound;
  final HapticService haptic;
  final AuthService? auth;

  const SettingsScreen({
    super.key,
    required this.storage,
    required this.sound,
    required this.haptic,
    this.auth,
  });

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late bool _soundEnabled;
  late bool _hapticEnabled;

  @override
  void initState() {
    super.initState();
    _soundEnabled = widget.storage.isSoundEnabled();
    _hapticEnabled = widget.storage.isHapticEnabled();
  }

  Future<void> _toggleSound(bool value) async {
    widget.haptic.selectionClick();
    await widget.storage.setSoundEnabled(value);
    setState(() => _soundEnabled = value);
  }

  Future<void> _toggleHaptic(bool value) async {
    await widget.storage.setHapticEnabled(value);
    setState(() => _hapticEnabled = value);
    if (value) widget.haptic.lightImpact();
  }

  Future<void> _confirmResetProgress() async {
    widget.haptic.heavyImpact();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text(
          'Reset All Progress?',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: const Text(
          'This will permanently reset all unlocked levels, completed puzzles, and streaks. This action cannot be undone.',
          style: TextStyle(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.blocked,
              foregroundColor: Colors.white,
            ),
            child: const Text('Reset'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await widget.storage.resetAllProgress();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('All progress has been reset.'),
            backgroundColor: AppColors.textPrimary,
          ),
        );
        setState(() {});
      }
    }
  }

  Future<void> _confirmDeleteAccount() async {
    if (widget.auth == null) return;

    widget.haptic.heavyImpact();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text(
          'Delete Account Permanently?',
          style: TextStyle(
            color: AppColors.blocked,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: const Text(
          'This permanently deletes your Arrow Escape account, its cloud progress (levels, power-ups, achievements, daily history) and the game data on this device. Your Google account itself is not affected. This cannot be undone.',
          style: TextStyle(color: AppColors.textSecondary, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.blocked,
              foregroundColor: Colors.white,
            ),
            child: const Text('Delete Permanently'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final success = await widget.auth!.deleteAccount();
      if (mounted) {
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Account and data deleted successfully.'),
              backgroundColor: AppColors.textPrimary,
            ),
          );
          Navigator.of(context).pop();
        } else if (widget.auth!.errorMessage != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(widget.auth!.errorMessage!),
              backgroundColor: AppColors.blocked,
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = widget.auth;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Settings'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        children: [
          // Account & Cloud Section
          if (auth != null) ...[
            const Text(
              'ACCOUNT & CLOUD PROGRESS',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: AppColors.textMuted,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              decoration: BoxDecoration(
                color: AppColors.surfaceSubtle,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: AppColors.border),
              ),
              child: auth.isAuthenticated
                  ? Column(
                      children: [
                        ListTile(
                          leading: const CircleAvatar(
                            backgroundColor: AppColors.primary,
                            child: Icon(
                              Icons.person_rounded,
                              color: Colors.white,
                            ),
                          ),
                          title: Text(
                            auth.displayName,
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          subtitle: Text(
                            '${auth.email ?? 'Google account'}\n'
                            '${syncStatusLabel(auth.cloudSync.status.value)}',
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.textMuted,
                            ),
                          ),
                          trailing: TextButton(
                            onPressed: () async {
                              await auth.signOut();
                              setState(() {});
                            },
                            child: const Text('Sign Out'),
                          ),
                        ),
                        ListTile(
                          leading: const Icon(Icons.sync_rounded),
                          title: const Text('Sync now'),
                          onTap: () async {
                            final ok = await auth.cloudSync.syncProgress();
                            if (!context.mounted) return;
                            setState(() {});
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  ok ? 'Progress synced.' : 'Could not sync now. It will retry automatically.',
                                ),
                              ),
                            );
                          },
                        ),
                      ],
                    )
                  : ListTile(
                      leading: const CircleAvatar(
                        backgroundColor: AppColors.textSecondary,
                        child: Icon(
                          Icons.person_outline_rounded,
                          color: Colors.white,
                        ),
                      ),
                      title: const Text(
                        'Guest Mode',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                      subtitle: const Text(
                        'Sign in to sync progress across devices',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textMuted,
                        ),
                      ),
                      trailing: ElevatedButton(
                        onPressed: () async {
                          final ok = await auth.signInWithGoogle();
                          if (!context.mounted) return;
                          setState(() {});
                          if (!ok && auth.errorMessage != null) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text(auth.errorMessage!)),
                            );
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 8,
                          ),
                          textStyle: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        child: const Text('Sign In'),
                      ),
                    ),
            ),
            const SizedBox(height: 24),
          ],

          // Audio & Feedback Card
          const Text(
            'FEEDBACK & AUDIO',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: AppColors.textMuted,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(
              color: AppColors.surfaceSubtle,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              children: [
                SwitchListTile(
                  title: const Text(
                    'Sound Effects',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  subtitle: const Text(
                    'Taps, escapes, and victory chimes',
                    style: TextStyle(fontSize: 12, color: AppColors.textMuted),
                  ),
                  secondary: const Icon(
                    Icons.volume_up_rounded,
                    color: AppColors.textPrimary,
                  ),
                  value: _soundEnabled,
                  activeThumbColor: AppColors.primary,
                  onChanged: _toggleSound,
                ),
                const Divider(
                  height: 1,
                  indent: 64,
                  endIndent: 20,
                  color: AppColors.border,
                ),
                SwitchListTile(
                  title: const Text(
                    'Haptic Feedback',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  subtitle: const Text(
                    'Tactile vibrations on moves and collisions',
                    style: TextStyle(fontSize: 12, color: AppColors.textMuted),
                  ),
                  secondary: const Icon(
                    Icons.vibration_rounded,
                    color: AppColors.textPrimary,
                  ),
                  value: _hapticEnabled,
                  activeThumbColor: AppColors.primary,
                  onChanged: _toggleHaptic,
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Legal & Policies Card
          const Text(
            'LEGAL & POLICIES',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: AppColors.textMuted,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(
              color: AppColors.surfaceSubtle,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(
                    Icons.privacy_tip_outlined,
                    color: AppColors.textPrimary,
                  ),
                  title: const Text(
                    'Privacy Policy',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  trailing: const Icon(
                    Icons.arrow_forward_ios_rounded,
                    size: 14,
                    color: AppColors.textMuted,
                  ),
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => const PrivacyPolicyScreen(),
                      ),
                    );
                  },
                ),
                const Divider(
                  height: 1,
                  indent: 64,
                  endIndent: 20,
                  color: AppColors.border,
                ),
                ListTile(
                  leading: const Icon(
                    Icons.description_outlined,
                    color: AppColors.textPrimary,
                  ),
                  title: const Text(
                    'Terms of Service',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  trailing: const Icon(
                    Icons.arrow_forward_ios_rounded,
                    size: 14,
                    color: AppColors.textMuted,
                  ),
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => const TermsScreen(),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Danger Zone / Data Management
          const Text(
            'DATA MANAGEMENT',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: AppColors.textMuted,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(
              color: AppColors.surfaceSubtle,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(
                    Icons.replay_rounded,
                    color: AppColors.textSecondary,
                  ),
                  title: const Text(
                    'Reset Progress',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  subtitle: const Text(
                    'Clear completed levels and streaks',
                    style: TextStyle(fontSize: 12, color: AppColors.textMuted),
                  ),
                  trailing: const Icon(
                    Icons.arrow_forward_ios_rounded,
                    size: 14,
                    color: AppColors.textMuted,
                  ),
                  onTap: _confirmResetProgress,
                ),
                const Divider(
                  height: 1,
                  indent: 64,
                  endIndent: 20,
                  color: AppColors.border,
                ),
                ListTile(
                  leading: const Icon(
                    Icons.school_rounded,
                    color: AppColors.textSecondary,
                  ),
                  title: const Text(
                    'Replay Tutorials',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  subtitle: const Text(
                    'Show the walkthroughs and level guides again',
                    style: TextStyle(fontSize: 12, color: AppColors.textMuted),
                  ),
                  onTap: () async {
                    await widget.storage.resetTutorials();
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Tutorials will play again.'),
                      ),
                    );
                  },
                ),
                if (auth != null && auth.isAuthenticated) ...[
                  const Divider(
                    height: 1,
                    indent: 64,
                    endIndent: 20,
                    color: AppColors.border,
                  ),
                  ListTile(
                    leading: const Icon(
                      Icons.delete_forever_rounded,
                      color: AppColors.blocked,
                    ),
                    title: const Text(
                      'Delete Account & Cloud Data',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: AppColors.blocked,
                      ),
                    ),
                    subtitle: const Text(
                      'Permanently erase Google link and cloud records',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textMuted,
                      ),
                    ),
                    trailing: const Icon(
                      Icons.arrow_forward_ios_rounded,
                      size: 14,
                      color: AppColors.blocked,
                    ),
                    onTap: _confirmDeleteAccount,
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 32),

          // Version Info
          const Center(
            child: Column(
              children: [
                Text(
                  AppInfo.name,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.5,
                    color: AppColors.textPrimary,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Version ${AppInfo.version} (${AppInfo.buildNumber})',
                  style: TextStyle(fontSize: 11, color: AppColors.textMuted),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}
