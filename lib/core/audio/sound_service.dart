import 'package:flutter/services.dart';

import '../storage/storage_service.dart';

class SoundService {
  final StorageService _storage;

  const SoundService(this._storage);

  void playTap() {
    if (_storage.isSoundEnabled()) {
      SystemSound.play(SystemSoundType.click);
    }
  }

  void playEscape() {
    if (_storage.isSoundEnabled()) {
      SystemSound.play(SystemSoundType.click);
    }
  }

  void playBlocked() {
    if (_storage.isSoundEnabled()) {
      SystemSound.play(SystemSoundType.alert);
    }
  }

  void playWin() {
    if (_storage.isSoundEnabled()) {
      SystemSound.play(SystemSoundType.click);
    }
  }

  void playUndo() {
    if (_storage.isSoundEnabled()) {
      SystemSound.play(SystemSoundType.click);
    }
  }
}
