import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme/app_colors.dart';
import '../../core/storage/storage_service.dart';
import '../../core/audio/sound_service.dart';
import '../../core/audio/haptic_service.dart';
import '../../game/difficulty.dart';
import '../../game/levels_data.dart';
import '../../game/game_controller.dart';
import 'gameplay_screen.dart';

extension DifficultyColor on Difficulty {
  Color get color => switch (this) {
    Difficulty.beginner => const Color(0xFF22C55E),
    Difficulty.easy => const Color(0xFF14B8A6),
    Difficulty.normal => const Color(0xFF3B82F6),
    Difficulty.intermediate => const Color(0xFF6366F1),
    Difficulty.hard => const Color(0xFFF59E0B),
    Difficulty.veryHard => const Color(0xFFF97316),
    Difficulty.expert => const Color(0xFFEF4444),
    Difficulty.master => const Color(0xFF9333EA),
  };
}

/// All campaign levels in chapters of [LevelsRepository.chapterSize].
/// Only the visible chapter's tiles are built; each tile's difficulty comes
/// from the level pack header, so no board is decoded or solved here.
class LevelSelectScreen extends StatefulWidget {
  final StorageService storage;
  final SoundService sound;
  final HapticService haptic;

  const LevelSelectScreen({
    super.key,
    required this.storage,
    required this.sound,
    required this.haptic,
  });

  @override
  State<LevelSelectScreen> createState() => _LevelSelectScreenState();
}

class _LevelSelectScreenState extends State<LevelSelectScreen> {
  late int _chapter = LevelsRepository.chapterOf(
    widget.storage.getCurrentLevel(),
  );
  final _chapterScroll = ScrollController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _revealChapter());
  }

  @override
  void dispose() {
    _chapterScroll.dispose();
    super.dispose();
  }

  void _revealChapter() {
    if (!_chapterScroll.hasClients) return;
    _chapterScroll.jumpTo(
      (_chapter * 96.0 - 120).clamp(0, _chapterScroll.position.maxScrollExtent),
    );
  }

  Future<void> _open(int levelId) async {
    widget.sound.playTap();
    widget.haptic.selectionClick();
    final controller = GameController(
      initialLevel: LevelsRepository.getLevel(levelId),
      storage: widget.storage,
      sound: widget.sound,
      haptic: widget.haptic,
    );
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => GameplayScreen(controller: controller),
      ),
    );
    if (mounted) setState(() {});
  }

  Future<void> _jumpToLevel() async {
    final highest = widget.storage.getHighestUnlockedLevel().clamp(
      1,
      LevelsRepository.totalLevels,
    );
    final input = TextEditingController();
    final level = await showDialog<int>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Go to level'),
        content: TextField(
          controller: input,
          autofocus: true,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          decoration: InputDecoration(
            hintText: '1 - $highest',
            helperText: 'Levels up to $highest are unlocked',
          ),
          onSubmitted: (v) => Navigator.of(ctx).pop(int.tryParse(v)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(int.tryParse(input.text)),
            child: const Text('Play'),
          ),
        ],
      ),
    );
    if (level == null || !mounted) return;
    if (level < 1 || level > highest) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            level > LevelsRepository.totalLevels || level < 1
                ? 'Choose a level from 1 to ${LevelsRepository.totalLevels}.'
                : 'Level $level is locked. Complete level $highest first.',
          ),
        ),
      );
      return;
    }
    setState(() => _chapter = LevelsRepository.chapterOf(level));
    await _open(level);
  }

  @override
  Widget build(BuildContext context) {
    final storage = widget.storage;
    final completed = storage.getCompletedLevels();
    final highest = storage.getHighestUnlockedLevel();
    final current = storage.getCurrentLevel();
    final total = LevelsRepository.totalLevels;
    final size = LevelsRepository.chapterSize;
    final first = _chapter * size + 1;
    final last = (first + size - 1).clamp(1, total);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Levels'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          IconButton(
            tooltip: 'Go to level',
            icon: const Icon(Icons.search_rounded),
            onPressed: _jumpToLevel,
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.surfaceSubtle,
                borderRadius: BorderRadius.circular(AppRadii.card),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Level $current of $total',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  LinearProgressIndicator(
                    value: completed.length / total,
                    minHeight: 8,
                    borderRadius: BorderRadius.circular(4),
                    backgroundColor: AppColors.border,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '${completed.length} completed · '
                    '${(completed.length * 100 / total).toStringAsFixed(1)}%',
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ),
          SizedBox(
            height: 64,
            child: ListView.builder(
              key: const ValueKey('chapter-strip'),
              controller: _chapterScroll,
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              itemCount: LevelsRepository.chapterCount,
              itemBuilder: (context, i) {
                final start = i * size + 1;
                final end = (start + size - 1).clamp(1, total);
                final done = [
                  for (var l = start; l <= end; l++)
                    if (completed.contains(l)) l,
                ].length;
                final selected = i == _chapter;
                final locked = start > highest;
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: ChoiceChip(
                    key: ValueKey('chapter-$i'),
                    selected: selected,
                    onSelected: (_) => setState(() => _chapter = i),
                    avatar: locked
                        ? const Icon(Icons.lock_rounded, size: 16)
                        : done == end - start + 1
                        ? const Icon(Icons.check_circle_rounded, size: 16)
                        : null,
                    label: Text(
                      '$start–$end',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: selected ? Colors.white : AppColors.textPrimary,
                      ),
                    ),
                    selectedColor: AppColors.primary,
                    showCheckmark: false,
                    tooltip: '$done of ${end - start + 1} completed',
                  ),
                );
              },
            ),
          ),
          Expanded(
            child: GridView.builder(
              key: ValueKey('chapter-grid-$_chapter'),
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 76,
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
              ),
              itemCount: last - first + 1,
              itemBuilder: (context, i) {
                final id = first + i;
                final state = completed.contains(id)
                    ? _TileState.completed
                    : id <= highest
                    ? (id == current ? _TileState.current : _TileState.open)
                    : _TileState.locked;
                return _LevelTile(
                  levelId: id,
                  state: state,
                  difficulty: state == _TileState.locked
                      ? null
                      : LevelsRepository.info(id).difficulty,
                  onTap: state == _TileState.locked ? null : () => _open(id),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

enum _TileState { completed, current, open, locked }

class _LevelTile extends StatelessWidget {
  final int levelId;
  final _TileState state;
  final Difficulty? difficulty;
  final VoidCallback? onTap;

  const _LevelTile({
    required this.levelId,
    required this.state,
    required this.difficulty,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final locked = state == _TileState.locked;
    final done = state == _TileState.completed;
    final current = state == _TileState.current;
    final label = switch (state) {
      _TileState.completed => 'completed',
      _TileState.current => 'next to play',
      _TileState.open => 'unlocked',
      _TileState.locked => 'locked',
    };
    return Semantics(
      button: !locked,
      label:
          'Level $levelId, $label${difficulty == null ? '' : ', ${difficulty!.label}'}',
      excludeSemantics: true,
      child: Material(
        color: done
            ? AppColors.primary
            : locked
            ? AppColors.surfaceSubtle
            : Colors.white,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: current
                    ? AppColors.primary
                    : locked
                    ? AppColors.border
                    : done
                    ? AppColors.primary
                    : AppColors.border,
                width: current ? 2.5 : 1.2,
              ),
            ),
            child: Stack(
              children: [
                Center(
                  child: locked
                      ? const Icon(
                          Icons.lock_rounded,
                          color: AppColors.textMuted,
                          size: 20,
                        )
                      : Text(
                          '$levelId',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: done ? Colors.white : AppColors.textPrimary,
                          ),
                        ),
                ),
                if (done)
                  const Positioned(
                    top: 4,
                    right: 4,
                    child: Icon(
                      Icons.check_rounded,
                      size: 14,
                      color: Colors.white,
                    ),
                  ),
                if (difficulty != null)
                  Positioned(
                    left: 10,
                    right: 10,
                    bottom: 6,
                    child: Container(
                      height: 4,
                      decoration: BoxDecoration(
                        color: done ? Colors.white70 : difficulty!.color,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
