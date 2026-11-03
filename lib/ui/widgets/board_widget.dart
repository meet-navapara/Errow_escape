import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../models/arrow_model.dart';
import '../../core/theme/app_colors.dart';
import '../../game/game_controller.dart';
import 'board_geometry.dart';
import 'board_painter.dart';

/// Zoomable, pannable puzzle board.
///
/// The viewer fills all the space it is given; at scale 1 the whole board is
/// fitted inside it. Taps are hit-tested in board coordinates (inside the
/// transformed child), so selection stays accurate at every zoom level.
class BoardWidget extends StatefulWidget {
  final GameController controller;

  /// Arrows a tutorial step points at (drawn in blue with a pulse).
  final Set<String> guideIds;

  /// Duration of the snake-like escape animation.
  final Duration escapeDuration;

  const BoardWidget({
    super.key,
    required this.controller,
    this.guideIds = const {},
    this.escapeDuration = const Duration(milliseconds: 420),
  });

  /// Smallest on-screen spacing (logical px) we want between lattice lines
  /// when fully zoomed in; drives the maximum zoom for dense boards.
  static const double comfortableCellSize = 56;

  @override
  State<BoardWidget> createState() => _BoardWidgetState();
}

class _BoardWidgetState extends State<BoardWidget>
    with TickerProviderStateMixin {
  late final TransformationController _transformationController;
  late final AnimationController _resetAnimation;
  late final AnimationController _bumpAnimation;
  late final AnimationController _pulse;
  Animation<Matrix4>? _resetTween;
  bool _isZoomed = false;

  /// One independent animation per escaping arrow, keyed by arrow id.
  final Map<String, (Arrow, AnimationController)> _escapes = {};

  /// Arrows the controller reported as escaping at its last notification.
  /// Only arrows that newly appear here start an animation, so unrelated
  /// notifications (another tap, a timer) never restart a running escape.
  Set<String> _reportedEscapes = const {};
  int _lastBlockedTap = 0;

  @override
  void initState() {
    super.initState();
    _transformationController = TransformationController()
      ..addListener(_onTransformChanged);
    _resetAnimation =
        AnimationController(
          vsync: this,
          duration: const Duration(milliseconds: 260),
        )..addListener(() {
          final tween = _resetTween;
          if (tween != null) _transformationController.value = tween.value;
        });
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _syncPulse();
    _bumpAnimation = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 260),
    );
    _lastBlockedTap = widget.controller.blockedTapCount;
    widget.controller.addListener(_onControllerChanged);
  }

  @override
  void didUpdateWidget(covariant BoardWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncPulse();
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_onControllerChanged);
      widget.controller.addListener(_onControllerChanged);
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onControllerChanged);
    _transformationController.removeListener(_onTransformChanged);
    _transformationController.dispose();
    _resetAnimation.dispose();
    _bumpAnimation.dispose();
    _pulse.dispose();
    for (final (_, animation) in _escapes.values) {
      animation.dispose();
    }
    super.dispose();
  }

  void _syncPulse() {
    if (widget.guideIds.isNotEmpty) {
      if (!_pulse.isAnimating) _pulse.repeat(reverse: true);
    } else if (_pulse.isAnimating) {
      _pulse.stop();
      _pulse.value = 0;
    }
  }

  void _onControllerChanged() {
    final reported = <String>{};
    for (final arrow in widget.controller.escapingArrows) {
      reported.add(arrow.id);
      if (!_reportedEscapes.contains(arrow.id)) _startEscape(arrow);
    }
    _reportedEscapes = reported;

    // Every blocked tap shakes, including a repeat tap on the same arrow.
    final blockedTap = widget.controller.blockedTapCount;
    if (blockedTap != _lastBlockedTap) _bumpAnimation.forward(from: 0);
    _lastBlockedTap = blockedTap;
  }

  void _startEscape(Arrow arrow) {
    // Undo can bring an arrow back and let it escape again before its
    // previous ghost finished; that old animation is simply replaced.
    _escapes.remove(arrow.id)?.$2.dispose();
    final animation = AnimationController(
      vsync: this,
      duration: widget.escapeDuration,
    );
    animation
      ..addListener(() => setState(() {}))
      ..addStatusListener((status) {
        if (status != AnimationStatus.completed) return;
        if (_escapes[arrow.id]?.$2 == animation) _escapes.remove(arrow.id);
        animation.dispose();
      })
      ..forward();
    _escapes[arrow.id] = (arrow, animation);
  }

  void _onTransformChanged() {
    final zoomed = !_transformationController.value.isIdentity();
    if (zoomed != _isZoomed) setState(() => _isZoomed = zoomed);
  }

  void _resetView() {
    _resetTween = Matrix4Tween(
      begin: _transformationController.value,
      end: Matrix4.identity(),
    ).animate(CurvedAnimation(parent: _resetAnimation, curve: Curves.easeOut));
    _resetAnimation.forward(from: 0);
  }

  List<EscapingArrow> _currentEscapes() => [
    for (final (arrow, animation) in _escapes.values)
      EscapingArrow(arrow, animation.value),
  ];

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final controller = widget.controller;
        final board = controller.board;
        final viewport = constraints.biggest;
        final geometry = BoardGeometry.fit(board: board, available: viewport);
        final maxScale = math.max(
          3.0,
          BoardWidget.comfortableCellSize / geometry.cellSize,
        );

        return Stack(
          children: [
            Positioned.fill(
              child: InteractiveViewer(
                transformationController: _transformationController,
                minScale: 1.0,
                maxScale: maxScale,
                // Zero margin keeps the board from being dragged out of view.
                boundaryMargin: EdgeInsets.zero,
                clipBehavior: Clip.hardEdge,
                child: GestureDetector(
                  key: const ValueKey('board-tap-target'),
                  behavior: HitTestBehavior.opaque,
                  onTapUp: (details) {
                    final hit = geometry.hitTest(board, details.localPosition);
                    if (hit != null) controller.onArrowTapped(hit);
                  },
                  child: AnimatedBuilder(
                    animation: Listenable.merge([_bumpAnimation, _pulse]),
                    builder: (context, _) => CustomPaint(
                      size: viewport,
                      painter: BoardPainter(
                        board: board,
                        geometry: geometry,
                        blockedId: controller.blockedArrow?.id,
                        blockerId: controller.blockerArrow?.id,
                        hintedId: controller.hintedArrow?.id,
                        guideIds: widget.guideIds,
                        pulse: _pulse.value,
                        scanId: controller.scanResult?.arrow.id,
                        scanBlockerIds: {
                          for (final a
                              in controller.scanResult?.blockers ??
                                  const <Arrow>[])
                            a.id,
                        },
                        bump: controller.blockedArrow == null
                            ? 0
                            : math.sin(_bumpAnimation.value * math.pi) * 0.3,
                        escaping: _currentEscapes(),
                      ),
                    ),
                  ),
                ),
              ),
            ),

            // Reset View Floating Pill (Visible when zoomed or panned)
            if (_isZoomed)
              Positioned(
                top: 8,
                right: 8,
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: _resetView,
                    borderRadius: BorderRadius.circular(20),
                    child: Container(
                      constraints: const BoxConstraints(minHeight: 40),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: AppColors.border),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x18000000),
                            blurRadius: 8,
                            offset: Offset(0, 2),
                          ),
                        ],
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.fit_screen_rounded,
                            size: 16,
                            color: AppColors.primary,
                          ),
                          SizedBox(width: 4),
                          Text(
                            'Reset View',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}
