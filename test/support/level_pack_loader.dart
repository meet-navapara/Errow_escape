import 'dart:io';

import 'package:arrow_escape/game/level_pack.dart';
import 'package:arrow_escape/game/levels_data.dart';

/// Installs the shipped level pack, as main() does on device.
void loadLevelPack() {
  LevelsRepository.usePack(File(LevelPack.assetPath).readAsStringSync());
}
