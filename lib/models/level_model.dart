import 'board_model.dart';

enum LevelTier {
  tutorial('Tutorial', 1, 3),
  beginner('Beginner', 4, 10),
  easy('Easy', 11, 25),
  medium('Medium', 26, 50),
  hard('Hard', 51, 75),
  expert('Expert', 76, 100),
  daily('Daily Challenge', 0, 0);

  final String label;
  final int minLevel;
  final int maxLevel;

  const LevelTier(this.label, this.minLevel, this.maxLevel);

  /// Difficulty badge shown in the gameplay header.
  String get displayName {
    switch (this) {
      case LevelTier.tutorial:
      case LevelTier.beginner:
        return 'Easy';
      case LevelTier.easy:
        return 'Easy';
      case LevelTier.medium:
        return 'Normal';
      case LevelTier.hard:
        return 'Hard';
      case LevelTier.expert:
        return 'Expert';
      case LevelTier.daily:
        return 'Daily';
    }
  }

  static LevelTier fromLevelNumber(int level) {
    if (level <= 3) return LevelTier.tutorial;
    if (level <= 10) return LevelTier.beginner;
    if (level <= 25) return LevelTier.easy;
    if (level <= 50) return LevelTier.medium;
    if (level <= 75) return LevelTier.hard;
    return LevelTier.expert;
  }
}

class Level {
  final int id;
  final String title;
  final Board board;
  final LevelTier tier;
  final int targetMoves;
  final String? tutorialMessage;

  const Level({
    required this.id,
    required this.title,
    required this.board,
    required this.tier,
    required this.targetMoves,
    this.tutorialMessage,
  });

  bool get isTutorial => tier == LevelTier.tutorial;

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'board': board.toJson(),
    'tier': tier.name,
    'targetMoves': targetMoves,
    'tutorialMessage': tutorialMessage,
  };

  factory Level.fromJson(Map<String, dynamic> json) {
    final tierName = json['tier'] as String;
    final tier = LevelTier.values.firstWhere(
      (t) => t.name == tierName,
      orElse: () => LevelTier.beginner,
    );
    return Level(
      id: json['id'] as int,
      title: json['title'] as String,
      board: Board.fromJson(json['board'] as Map<String, dynamic>),
      tier: tier,
      targetMoves: json['targetMoves'] as int,
      tutorialMessage: json['tutorialMessage'] as String?,
    );
  }
}
