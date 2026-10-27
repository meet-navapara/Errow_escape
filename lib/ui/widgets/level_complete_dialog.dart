import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../models/board_model.dart';
import 'board_geometry.dart';
import 'board_painter.dart';

/// Full-screen level-completion celebration: sunburst background, falling
/// confetti, a preview of the solved puzzle and clear next actions.
class LevelCompleteDialog extends StatefulWidget {
  final int levelId;
  final bool isDaily;
  final int movesTaken;
  final int targetMoves;
  final int remainingHearts;

  /// Starting layout of the solved puzzle, shown as a preview card.
  final Board? previewBoard;
  final bool hasNextLevel;

  /// Overrides for non-campaign modes (weekly, daily).
  final String? title;
  final String? subtitle;
  final String? nextLabel;

  /// Titles of achievements unlocked by this completion.
  final List<String> achievements;
  final VoidCallback onNextLevel;
  final VoidCallback onReplay;
  final VoidCallback onHome;

  const LevelCompleteDialog({
    super.key,
    required this.levelId,
    required this.isDaily,
    required this.movesTaken,
    required this.targetMoves,
    this.remainingHearts = 3,
    this.previewBoard,
    this.hasNextLevel = true,
    this.title,
    this.subtitle,
    this.nextLabel,
    this.achievements = const [],
    required this.onNextLevel,
    required this.onReplay,
    required this.onHome,
  });

  @override
  State<LevelCompleteDialog> createState() => _LevelCompleteDialogState();
}

class _LevelCompleteDialogState extends State<LevelCompleteDialog>
    with TickerProviderStateMixin {
  late final AnimationController _entrance;
  late final AnimationController _loop;

  @override
  void initState() {
    super.initState();
    _entrance = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..forward();
    _loop = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 6),
    )..repeat();
  }

  @override
  void dispose() {
    _entrance.dispose();
    _loop.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Stars earned based on remaining hearts
    final stars = widget.remainingHearts.clamp(1, 3);
    final showNext = !widget.isDaily && widget.hasNextLevel;

    return Material(
      color: const Color(0xFF1677E8),
      child: Stack(
        children: [
          Positioned.fill(
            child: AnimatedBuilder(
              animation: _loop,
              builder: (context, _) =>
                  CustomPaint(painter: _SunburstPainter(rotation: _loop.value)),
            ),
          ),
          Positioned.fill(
            child: IgnorePointer(
              child: AnimatedBuilder(
                animation: _loop,
                builder: (context, _) =>
                    CustomPaint(painter: _ConfettiPainter(time: _loop.value)),
              ),
            ),
          ),
          SafeArea(
            child: MediaQuery.withClampedTextScaling(
              maxScaleFactor: 1.3,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final previewSize = math.min(
                    constraints.maxWidth * 0.72,
                    constraints.maxHeight * 0.36,
                  );
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Column(
                      children: [
                        const Spacer(flex: 2),
                        _fadeSlide(
                          0.0,
                          Text(
                            widget.title ??
                                (widget.isDaily
                                    ? 'Daily Cleared!'
                                    : 'Level Completed!'),
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 32,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                              shadows: [
                                Shadow(
                                  color: Color(0x40000000),
                                  blurRadius: 12,
                                  offset: Offset(0, 3),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 6),
                        _fadeSlide(
                          0.1,
                          Text(
                            widget.subtitle ??
                                (widget.isDaily
                                    ? 'You solved the daily challenge!'
                                    : 'Level ${widget.levelId} cleared with flying colors!'),
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 15,
                              color: Color(0xE6FFFFFF),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        _fadeSlide(
                          0.2,
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: List.generate(3, (index) {
                              final isEarned = index < stars;
                              return Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 3,
                                ),
                                child: Icon(
                                  isEarned
                                      ? Icons.star_rounded
                                      : Icons.star_outline_rounded,
                                  color: isEarned
                                      ? const Color(0xFFFFD54F)
                                      : const Color(0x80FFFFFF),
                                  size: 36,
                                ),
                              );
                            }),
                          ),
                        ),
                        const Spacer(),
                        ScaleTransition(
                          scale: CurvedAnimation(
                            parent: _entrance,
                            curve: const Interval(
                              0.15,
                              1.0,
                              curve: Curves.elasticOut,
                            ),
                          ),
                          child: _PreviewCard(
                            board: widget.previewBoard,
                            size: previewSize,
                          ),
                        ),
                        const SizedBox(height: 16),
                        _fadeSlide(
                          0.4,
                          _OneLine(
                            children: [
                              _StatChip(
                                icon: Icons.touch_app_rounded,
                                label: 'Moves',
                                value: '${widget.movesTaken}',
                              ),
                              const SizedBox(width: 10),
                              _StatChip(
                                icon: Icons.favorite_rounded,
                                label: 'Hearts',
                                value: '${widget.remainingHearts}/3',
                              ),
                            ],
                          ),
                        ),
                        for (final a in widget.achievements)
                          Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: _fadeSlide(
                              0.45,
                              _StatChip(
                                icon: Icons.emoji_events_rounded,
                                label: 'Achievement:',
                                value: a,
                              ),
                            ),
                          ),
                        const Spacer(flex: 2),
                        if (showNext)
                          _fadeSlide(
                            0.5,
                            SizedBox(
                              width: double.infinity,
                              height: 62,
                              child: ElevatedButton(
                                onPressed: widget.onNextLevel,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.white,
                                  foregroundColor: AppColors.primary,
                                  elevation: 4,
                                  shadowColor: const Color(0x33000000),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(31),
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 24,
                                    vertical: 4,
                                  ),
                                ),
                                child: FittedBox(
                                  fit: BoxFit.scaleDown,
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Text(
                                        'Next Level',
                                        style: TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                      Text(
                                        widget.nextLabel ??
                                            'Level ${widget.levelId + 1}',
                                        style: const TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w500,
                                          color: AppColors.textMuted,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        const SizedBox(height: 8),
                        _fadeSlide(
                          0.6,
                          _OneLine(
                            children: [
                              _FooterButton(
                                icon: Icons.replay_rounded,
                                label: 'Replay Level',
                                onTap: widget.onReplay,
                              ),
                              const SizedBox(width: 12),
                              _FooterButton(
                                icon: Icons.home_rounded,
                                label: 'Main',
                                onTap: widget.onHome,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Staggered fade + slide-up entrance starting at [delay] (0..1).
  Widget _fadeSlide(double delay, Widget child) {
    final curve = CurvedAnimation(
      parent: _entrance,
      curve: Interval(delay, math.min(1.0, delay + 0.4), curve: Curves.easeOut),
    );
    return FadeTransition(
      opacity: curve,
      child: SlideTransition(
        position: Tween(
          begin: const Offset(0, 0.25),
          end: Offset.zero,
        ).animate(curve),
        child: child,
      ),
    );
  }
}

/// A centred row that scales down instead of overflowing on narrow screens.
class _OneLine extends StatelessWidget {
  final List<Widget> children;

  const _OneLine({required this.children});

  @override
  Widget build(BuildContext context) {
    return FittedBox(
      fit: BoxFit.scaleDown,
      child: Row(mainAxisSize: MainAxisSize.min, children: children),
    );
  }
}

class _PreviewCard extends StatelessWidget {
  final Board? board;
  final double size;

  const _PreviewCard({required this.board, required this.size});

  @override
  Widget build(BuildContext context) {
    final b = board;
    final double width;
    final double height;
    if (b == null) {
      width = height = size * 0.6;
    } else if (b.cols >= b.rows) {
      width = size;
      height = size * b.rows / b.cols;
    } else {
      height = size;
      width = size * b.cols / b.rows;
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: const [
          BoxShadow(
            color: Color(0x33000000),
            blurRadius: 24,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: SizedBox(
        width: width,
        height: height,
        child: b == null
            ? const Icon(
                Icons.emoji_events_rounded,
                size: 72,
                color: AppColors.accent,
              )
            : LayoutBuilder(
                builder: (context, constraints) => CustomPaint(
                  size: constraints.biggest,
                  painter: BoardPainter(
                    board: b,
                    geometry: BoardGeometry.fit(
                      board: b,
                      available: constraints.biggest,
                      padding: 0,
                    ),
                  ),
                ),
              ),
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _StatChip({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0x26FFFFFF),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0x40FFFFFF)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: Colors.white),
          const SizedBox(width: 6),
          Text(
            '$label $value',
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}

class _FooterButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _FooterButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return TextButton.icon(
      onPressed: onTap,
      style: TextButton.styleFrom(
        foregroundColor: Colors.white,
        minimumSize: const Size(48, 48),
        padding: const EdgeInsets.symmetric(horizontal: 16),
      ),
      icon: Icon(icon, size: 20),
      label: Text(
        label,
        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
      ),
    );
  }
}

/// Slowly rotating light rays over a blue radial gradient.
class _SunburstPainter extends CustomPainter {
  final double rotation;

  _SunburstPainter({required this.rotation});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height * 0.45);
    final rect = Offset.zero & size;
    canvas.drawRect(
      rect,
      Paint()
        ..shader = const RadialGradient(
          center: Alignment(0, -0.1),
          radius: 0.9,
          colors: [Color(0xFF3BB4FF), Color(0xFF1677E8), Color(0xFF0D5FD0)],
          stops: [0.0, 0.6, 1.0],
        ).createShader(rect),
    );

    const rays = 16;
    final radius = size.longestSide;
    final paint = Paint()..color = const Color(0x14FFFFFF);
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(rotation * 2 * math.pi / rays);
    for (var i = 0; i < rays; i++) {
      final a = i * 2 * math.pi / rays;
      const half = math.pi / rays / 2;
      final path = Path()
        ..moveTo(0, 0)
        ..lineTo(math.cos(a - half) * radius, math.sin(a - half) * radius)
        ..lineTo(math.cos(a + half) * radius, math.sin(a + half) * radius)
        ..close();
      canvas.drawPath(path, paint);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _SunburstPainter old) =>
      old.rotation != rotation;
}

/// Lightweight looping confetti: each piece falls with its own speed, sway
/// and spin, derived from a fixed seed so no per-frame allocation is needed.
class _ConfettiPainter extends CustomPainter {
  final double time;

  _ConfettiPainter({required this.time});

  static const _colors = [
    Color(0xFFFFE066),
    Color(0xFFFF8FC8),
    Color(0xFF7CF0A9),
    Color(0xFF9BE7FF),
    Color(0xFFFFFFFF),
    Color(0xFFFFB86B),
  ];

  static final List<_Piece> _pieces = () {
    final r = math.Random(7);
    return List.generate(
      70,
      (i) => _Piece(
        x: r.nextDouble(),
        phase: r.nextDouble(),
        // Whole falls per loop, so pieces don't jump when the loop wraps.
        speed: 1.0 + r.nextInt(2),
        sway: 10 + r.nextDouble() * 24,
        spin: (r.nextDouble() - 0.5) * 10,
        size: 6 + r.nextDouble() * 7,
        color: _colors[i % _colors.length],
      ),
    );
  }();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint();
    for (final p in _pieces) {
      final t = (time * p.speed + p.phase) % 1.0;
      final y = -20 + t * (size.height + 40);
      final x =
          p.x * size.width + math.sin((t * 4 + p.phase) * math.pi) * p.sway;
      paint.color = p.color;
      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(t * p.spin);
      // Squash horizontally to fake a 3D flip without real 3D.
      canvas.scale(math.cos(t * p.spin * 1.7).abs() * 0.8 + 0.2, 1);
      canvas.drawRect(
        Rect.fromCenter(
          center: Offset.zero,
          width: p.size,
          height: p.size * 0.6,
        ),
        paint,
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _ConfettiPainter old) => old.time != time;
}

class _Piece {
  final double x;
  final double phase;
  final double speed;
  final double sway;
  final double spin;
  final double size;
  final Color color;

  const _Piece({
    required this.x,
    required this.phase,
    required this.speed,
    required this.sway,
    required this.spin,
    required this.size,
    required this.color,
  });
}
