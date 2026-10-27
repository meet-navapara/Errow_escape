import 'arrow_model.dart';
import 'board_model.dart';

/// Records a move made by the player to enable smooth undo. A single move
/// can remove several arrows (the Magic Wand), so undo restores
/// [previousBoard] as a whole.
class GameMove {
  final Arrow arrow;
  final List<Arrow> removed;
  final int moveIndex;
  final Board previousBoard;
  final DateTime timestamp;

  GameMove({
    required this.arrow,
    List<Arrow>? removed,
    required this.moveIndex,
    required this.previousBoard,
    required this.timestamp,
  }) : removed = removed ?? [arrow];
}
