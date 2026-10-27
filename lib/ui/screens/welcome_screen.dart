import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/auth/auth_service.dart';
import '../../core/audio/sound_service.dart';
import '../../core/audio/haptic_service.dart';
import '../widgets/game_logo_widget.dart';
import 'home_screen.dart';
import 'privacy_policy_screen.dart';
import 'terms_screen.dart';

class WelcomeScreen extends StatefulWidget {
  final AuthService auth;
  final SoundService sound;
  final HapticService haptic;

  const WelcomeScreen({
    super.key,
    required this.auth,
    required this.sound,
    required this.haptic,
  });

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> {
  void _navigateToHome() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (context) => HomeScreen(
          storage: widget.auth.storage,
          sound: widget.sound,
          haptic: widget.haptic,
          auth: widget.auth,
        ),
      ),
    );
  }

  Future<void> _handleGuestPlay() async {
    widget.sound.playTap();
    widget.haptic.selectionClick();
    await widget.auth.playAsGuest();
    _navigateToHome();
  }

  Future<void> _handleGoogleSignIn() async {
    widget.sound.playTap();
    widget.haptic.selectionClick();
    final success = await widget.auth.signInWithGoogle();
    if (success) {
      _navigateToHome();
    } else if (widget.auth.errorMessage != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(widget.auth.errorMessage!),
          backgroundColor: AppColors.textPrimary,
          duration: const Duration(seconds: 4),
          action: SnackBarAction(
            label: 'Continue as Guest',
            textColor: AppColors.primary,
            onPressed: _handleGuestPlay,
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
          child: Column(
            children: [
              const Spacer(flex: 1),

              // Official Brand Logo & Tagline
              const GameLogoWidget(size: 110),

              const Spacer(flex: 2),

              // Sign In with Google Button
              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton(
                  onPressed: widget.auth.isLoading ? null : _handleGoogleSignIn,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.textPrimary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                  ),
                  child: widget.auth.isLoading
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            valueColor: AlwaysStoppedAnimation(Colors.white),
                          ),
                        )
                      : const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.g_mobiledata_rounded, size: 28),
                            SizedBox(width: 8),
                            Flexible(
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Text(
                                  'Continue with Google',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                ),
              ),
              const SizedBox(height: 14),

              // Play as Guest Button
              SizedBox(
                width: double.infinity,
                height: 52,
                child: OutlinedButton(
                  onPressed: widget.auth.isLoading ? null : _handleGuestPlay,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.textPrimary,
                    side: const BorderSide(color: AppColors.border, width: 1.5),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                  ),
                  child: const Text(
                    'Continue as Guest',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                  ),
                ),
              ),

              const SizedBox(height: 28),

              // Legal Links & Notice
              Wrap(
                alignment: WrapAlignment.center,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  const Text(
                    'By continuing, you agree to our ',
                    style: TextStyle(fontSize: 11, color: AppColors.textMuted),
                  ),
                  InkWell(
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (context) => const TermsScreen(),
                        ),
                      );
                    },
                    child: const Text(
                      'Terms',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  ),
                  const Text(
                    ' and ',
                    style: TextStyle(fontSize: 11, color: AppColors.textMuted),
                  ),
                  InkWell(
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (context) => const PrivacyPolicyScreen(),
                        ),
                      );
                    },
                    child: const Text(
                      'Privacy Policy',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }
}
