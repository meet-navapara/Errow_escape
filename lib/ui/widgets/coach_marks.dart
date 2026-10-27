import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';

/// One step of a walkthrough: a short instruction pointing at [target].
class CoachStep {
  /// Widget to spotlight. If null or not laid out, the card is centred.
  final GlobalKey? target;
  final String title;
  final String body;
  final IconData icon;

  const CoachStep({
    this.target,
    required this.title,
    required this.body,
    this.icon = Icons.lightbulb_outline_rounded,
  });
}

/// Modal spotlight walkthrough. While it is open the rest of the screen
/// cannot be touched, so gameplay is effectively paused.
class CoachMarks extends StatefulWidget {
  final List<CoachStep> steps;

  const CoachMarks({super.key, required this.steps});

  /// Shows [steps] one at a time. Resolves to true when finished, false when
  /// skipped.
  static Future<bool> show(BuildContext context, List<CoachStep> steps) async {
    final finished = await Navigator.of(context).push<bool>(
      PageRouteBuilder(
        opaque: false,
        barrierDismissible: false,
        pageBuilder: (_, _, _) => CoachMarks(steps: steps),
        transitionsBuilder: (_, a, _, child) =>
            FadeTransition(opacity: a, child: child),
      ),
    );
    return finished ?? false;
  }

  @override
  State<CoachMarks> createState() => _CoachMarksState();
}

class _CoachMarksState extends State<CoachMarks> {
  int _index = 0;

  Rect? _targetRect() {
    final ctx = widget.steps[_index].target?.currentContext;
    final box = ctx?.findRenderObject();
    if (box is! RenderBox || !box.hasSize || !box.attached) return null;
    final overlay = context.findRenderObject() as RenderBox?;
    final topLeft = box.localToGlobal(Offset.zero, ancestor: overlay);
    return (topLeft & box.size).inflate(6);
  }

  void _next() {
    if (_index == widget.steps.length - 1) {
      Navigator.of(context).pop(true);
    } else {
      setState(() => _index++);
    }
  }

  @override
  Widget build(BuildContext context) {
    final step = widget.steps[_index];
    final hole = _targetRect();
    final size = MediaQuery.sizeOf(context);
    final last = _index == widget.steps.length - 1;
    // Put the card on whichever side of the spotlight has more room.
    final cardBelow = hole == null || hole.center.dy < size.height / 2;

    final card = Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(AppRadii.card),
      elevation: 8,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 10),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(step.icon, color: AppColors.primary, size: 22),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    step.title,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
                Text(
                  '${_index + 1}/${widget.steps.length}',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textMuted,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              step.body,
              style: const TextStyle(
                fontSize: 14,
                height: 1.4,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                if (!last)
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(false),
                    child: const Text('Skip'),
                  ),
                const Spacer(),
                if (_index > 0)
                  TextButton(
                    onPressed: () => setState(() => _index--),
                    child: const Text('Back'),
                  ),
                const SizedBox(width: 4),
                FilledButton(
                  onPressed: _next,
                  child: Text(last ? 'Finish' : 'Next'),
                ),
              ],
            ),
          ],
        ),
      ),
    );

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () {}, // swallow taps: gameplay is paused
              child: CustomPaint(painter: _SpotlightPainter(hole)),
            ),
          ),
          Positioned(
            left: 16,
            right: 16,
            top: cardBelow
                ? (hole == null
                      ? size.height * 0.32
                      : (hole.bottom + 14).clamp(0, size.height - 260))
                : null,
            bottom: cardBelow
                ? null
                : (size.height - hole.top + 14).clamp(0, size.height - 260),
            child: SafeArea(child: card),
          ),
        ],
      ),
    );
  }
}

class _SpotlightPainter extends CustomPainter {
  final Rect? hole;
  _SpotlightPainter(this.hole);

  @override
  void paint(Canvas canvas, Size size) {
    final dim = Path()..addRect(Offset.zero & size);
    if (hole != null) {
      dim.addRRect(RRect.fromRectAndRadius(hole!, const Radius.circular(18)));
      dim.fillType = PathFillType.evenOdd;
    }
    canvas.drawPath(dim, Paint()..color = const Color(0xB30B192C));
    if (hole != null) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(hole!, const Radius.circular(18)),
        Paint()
          ..color = Colors.white
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _SpotlightPainter old) => old.hole != hole;
}
