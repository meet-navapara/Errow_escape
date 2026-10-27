import 'package:flutter/services.dart';

import '../storage/storage_service.dart';

class HapticService {
  final StorageService _storage;

  const HapticService(this._storage);

  void lightImpact() {
    if (_storage.isHapticEnabled()) {
      HapticFeedback.lightImpact();
    }
  }

  void mediumImpact() {
    if (_storage.isHapticEnabled()) {
      HapticFeedback.mediumImpact();
    }
  }

  void heavyImpact() {
    if (_storage.isHapticEnabled()) {
      HapticFeedback.heavyImpact();
    }
  }

  void selectionClick() {
    if (_storage.isHapticEnabled()) {
      HapticFeedback.selectionClick();
    }
  }

  void successVibrate() {
    if (_storage.isHapticEnabled()) {
      HapticFeedback.vibrate();
    }
  }
}
