import 'package:flutter/material.dart';

import '../core/audio/haptic_service.dart';
import '../core/audio/sound_service.dart';
import '../core/auth/auth_service.dart';
import '../core/storage/storage_service.dart';
import '../game/game_controller.dart';
import '../game/play_context.dart';
import '../models/level_model.dart';
import 'screens/gameplay_screen.dart';

/// Services shared by the home tabs and the screens they open.
class AppServices {
  final StorageService storage;
  final SoundService sound;
  final HapticService haptic;
  final AuthService? auth;

  const AppServices({
    required this.storage,
    required this.sound,
    required this.haptic,
    this.auth,
  });

  void tapFeedback() {
    sound.playTap();
    haptic.selectionClick();
  }

  /// Opens gameplay for [level] and completes when the player leaves it.
  Future<void> play(
    BuildContext context,
    Level level, {
    PlayContext playContext = const PlayContext.campaign(),
  }) async {
    tapFeedback();
    final controller = GameController(
      initialLevel: level,
      storage: storage,
      sound: sound,
      haptic: haptic,
      context: playContext,
    );
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => GameplayScreen(controller: controller),
      ),
    );
    // Push anything earned while playing without waiting for the debounce.
    auth?.cloudSync.syncProgress();
  }
}
