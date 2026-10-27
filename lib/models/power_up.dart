/// Limited-use tools available on the gameplay screen.
///
/// Each has one distinct, well-defined effect:
/// - [hint]: highlights an arrow the solver confirms can escape. Never moves.
/// - [eraser]: removes one arrow the player selects, even if it is blocked.
/// - [wand]: launches every arrow that is currently free (up to [wandLimit]).
/// - [scanner]: shows the selected arrow's escape route and every blocker on it.
///
/// Removing arrows can never make a solvable board unsolvable (it only frees
/// cells), so eraser and wand always leave a solvable puzzle.
enum PowerUpType {
  hint('Hint', 'Highlights one arrow that can escape right now.'),
  eraser(
    'Eraser',
    'Select any arrow to remove it, even if it is blocked. Great for breaking a jam.',
  ),
  wand(
    'Magic Wand',
    'Instantly launches up to 5 arrows that are free to escape.',
  ),
  scanner(
    'Path Scanner',
    'Select an arrow to see its escape route and which arrows block it. No heart cost.',
  );

  final String label;
  final String description;

  const PowerUpType(this.label, this.description);

  /// Uses every new player receives once (per account or installation).
  static const int starterAllowance = 2;

  static const int wandLimit = 5;

  /// Tools that need the player to pick an arrow after activating them.
  bool get needsTarget => this == eraser || this == scanner;
}
