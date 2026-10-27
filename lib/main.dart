import 'dart:async';
import 'dart:io' show Platform;

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'core/theme/app_theme.dart';
import 'core/theme/app_colors.dart';
import 'core/storage/storage_service.dart';
import 'core/audio/sound_service.dart';
import 'core/audio/haptic_service.dart';
import 'core/auth/auth_service.dart';
import 'core/ads/ad_service.dart';
import 'game/level_pack.dart';
import 'game/levels_data.dart';
import 'ui/screens/home_screen.dart';
import 'ui/screens/welcome_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Lock to portrait orientation for crisp casual mobile puzzle experience
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // System bar styling for clean light UI
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      systemNavigationBarColor: AppColors.background,
      systemNavigationBarIconBrightness: Brightness.dark,
    ),
  );

  // Firebase reads its configuration from google-services.json (Android,
  // applied by the Google Services Gradle plugin) and
  // GoogleService-Info.plist (iOS). If it is missing the game still runs
  // fully offline in guest mode.
  try {
    await Firebase.initializeApp();
  } catch (e) {
    debugPrint('[main] Firebase unavailable, running offline: $e');
  }

  // Initialize offline local persistence
  final storage = await StorageService.init();
  await storage.ensureStarterPowerUps();
  final sound = SoundService(storage);
  final haptic = HapticService(storage);
  final auth = AuthService(storage: storage);
  await auth.init();

  // Rewarded ads (optional, consent-gated). Not awaited so startup never
  // waits on the network or the consent form.
  if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
    final ads = AdMobRewardedAds();
    AdService.rewarded = ads;
    unawaited(ads.initialize());
  }

  // Precomputed level pack (~0.5 MB text). Boards are decoded on demand; if
  // the asset is missing, levels are generated with the same deterministic
  // generator instead.
  try {
    LevelsRepository.usePack(await rootBundle.loadString(LevelPack.assetPath));
  } catch (e) {
    debugPrint('[main] Level pack unavailable, generating levels: $e');
  }

  runApp(
    ArrowEscapeApp(storage: storage, sound: sound, haptic: haptic, auth: auth),
  );
}

class ArrowEscapeApp extends StatelessWidget {
  final StorageService storage;
  final SoundService sound;
  final HapticService haptic;
  final AuthService auth;

  const ArrowEscapeApp({
    super.key,
    required this.storage,
    required this.sound,
    required this.haptic,
    required this.auth,
  });

  @override
  Widget build(BuildContext context) {
    final showWelcome = !storage.isFirstLaunchCompleted();

    return MaterialApp(
      title: 'Arrow Escape',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      home: showWelcome
          ? WelcomeScreen(auth: auth, sound: sound, haptic: haptic)
          : HomeScreen(
              storage: storage,
              sound: sound,
              haptic: haptic,
              auth: auth,
            ),
    );
  }
}
