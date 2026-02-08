import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Fun animated "Oops!" screen with a wobbling character.
class FriendlyErrorScreen extends StatefulWidget {
  const FriendlyErrorScreen({
    required this.onRetry,
    super.key,
  });

  final VoidCallback onRetry;

  @override
  State<FriendlyErrorScreen> createState() =>
      _FriendlyErrorScreenState();
}

class _FriendlyErrorScreenState extends State<FriendlyErrorScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    );
    unawaited(_controller.repeat());
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark =
        MediaQuery.platformBrightnessOf(context) == Brightness.dark;
    final bg =
        isDark ? const Color(0xFF1A1A2E) : const Color(0xFFF8F0FF);
    final textColor =
        isDark ? const Color(0xFFE0D6FF) : const Color(0xFF3A2D5C);

    return Directionality(
      textDirection: TextDirection.ltr,
      child: Material(
        color: bg,
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AnimatedBuilder(
                  animation: _controller,
                  builder: (_, _) {
                    return CustomPaint(
                      size: const Size(120, 120),
                      painter: _FriendlyCharPainter(
                        progress: _controller.value,
                        isDark: isDark,
                      ),
                    );
                  },
                ),
                const SizedBox(height: 32),
                Text(
                  'Oops!',
                  style: TextStyle(
                    color: textColor,
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Something unexpected happened.\n'
                  "Don't worry, let's try again!",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: textColor.withValues(alpha: 0.7),
                    fontSize: 16,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 32),
                _RetryButton(
                  onTap: widget.onRetry,
                  isDark: isDark,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _FriendlyCharPainter extends CustomPainter {
  _FriendlyCharPainter({
    required this.progress,
    required this.isDark,
  });

  final double progress;
  final bool isDark;

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;

    // Wobble effect.
    final wobble = math.sin(progress * 2 * math.pi) * 4;
    final tilt = math.sin(progress * 2 * math.pi) * 0.05;

    canvas
      ..save()
      ..translate(cx, cy)
      ..rotate(tilt)
      ..translate(-cx, -cy);

    // Body circle.
    final bodyPaint = Paint()
      ..color = isDark
          ? const Color(0xFF6C5CE7)
          : const Color(0xFFA29BFE);
    canvas.drawCircle(Offset(cx, cy + wobble), 40, bodyPaint);

    // Eyes.
    final eyePaint = Paint()..color = Colors.white;
    final pupilPaint = Paint()
      ..color = isDark
          ? const Color(0xFF2D2B55)
          : const Color(0xFF3A2D5C);

    canvas
      ..drawCircle(
        Offset(cx - 14, cy - 8 + wobble),
        10,
        eyePaint,
      )
      ..drawCircle(
        Offset(cx - 14, cy - 6 + wobble),
        5,
        pupilPaint,
      )
      ..drawCircle(
        Offset(cx + 14, cy - 8 + wobble),
        10,
        eyePaint,
      )
      ..drawCircle(
        Offset(cx + 14, cy - 6 + wobble),
        5,
        pupilPaint,
      );

    // Mouth (squiggly line).
    final mouthPaint = Paint()
      ..color = pupilPaint.color
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final mouthPath = Path()
      ..moveTo(cx - 12, cy + 14 + wobble);
    for (var i = 0; i <= 24; i++) {
      final x = cx - 12 + i;
      final y = cy +
          14 +
          wobble +
          math.sin(i * 0.6 + progress * 2 * math.pi) * 3;
      mouthPath.lineTo(x, y);
    }
    canvas
      ..drawPath(mouthPath, mouthPaint)
      ..restore();
  }

  @override
  bool shouldRepaint(_FriendlyCharPainter oldDelegate) =>
      progress != oldDelegate.progress;
}

class _RetryButton extends StatelessWidget {
  const _RetryButton({required this.onTap, required this.isDark});

  final VoidCallback onTap;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: 32,
          vertical: 14,
        ),
        decoration: BoxDecoration(
          color: isDark
              ? const Color(0xFF6C5CE7)
              : const Color(0xFFA29BFE),
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: (isDark
                      ? const Color(0xFF6C5CE7)
                      : const Color(0xFFA29BFE))
                  .withValues(alpha: 0.3),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: const Text(
          'Try Again',
          style: TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}
