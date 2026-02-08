import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Full-screen error screen with a CustomPainter illustration
/// and subtle floating animation.
class IllustratedErrorScreen extends StatefulWidget {
  const IllustratedErrorScreen({
    required this.onRetry,
    super.key,
  });

  final VoidCallback onRetry;

  @override
  State<IllustratedErrorScreen> createState() =>
      _IllustratedErrorScreenState();
}

class _IllustratedErrorScreenState extends State<IllustratedErrorScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
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
        isDark ? const Color(0xFF0D1117) : const Color(0xFFFAFBFC);
    final textColor =
        isDark ? const Color(0xFFC9D1D9) : const Color(0xFF24292F);

    return Directionality(
      textDirection: TextDirection.ltr,
      child: Material(
        color: bg,
        child: Stack(
          children: [
            // Background illustration.
            Positioned.fill(
              child: AnimatedBuilder(
                animation: _controller,
                builder: (_, _) => CustomPaint(
                  painter: _IllustrationPainter(
                    progress: _controller.value,
                    isDark: isDark,
                  ),
                ),
              ),
            ),
            // Foreground content.
            Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(height: 80),
                    Text(
                      'We hit a snag',
                      style: TextStyle(
                        color: textColor,
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'The app encountered an unexpected '
                      'error.\nTap below to restart.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: textColor.withValues(alpha: 0.6),
                        fontSize: 15,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 28),
                    GestureDetector(
                      onTap: widget.onRetry,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 28,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: isDark
                              ? const Color(0xFF238636)
                              : const Color(0xFF2EA043),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text(
                          'Try Again',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _IllustrationPainter extends CustomPainter {
  _IllustrationPainter({
    required this.progress,
    required this.isDark,
  });

  final double progress;
  final bool isDark;

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;

    // Floating circles with gentle bob.
    final bobOffset = math.sin(progress * 2 * math.pi) * 8;

    // Large background circle.
    final bgCircle = Paint()
      ..color = isDark
          ? const Color(0x0DFFFFFF)
          : const Color(0x0D000000);
    canvas.drawCircle(
      Offset(cx, size.height * 0.3 + bobOffset),
      80,
      bgCircle,
    );

    // Broken link illustration — two arcs.
    final arcPaint = Paint()
      ..color = isDark
          ? const Color(0xFF58A6FF)
          : const Color(0xFF0969DA)
      ..strokeWidth = 4
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final separation =
        6 + math.sin(progress * 2 * math.pi) * 3;

    canvas
      // Left arc.
      ..drawArc(
        Rect.fromCenter(
          center: Offset(
            cx - separation,
            size.height * 0.3 + bobOffset,
          ),
          width: 40,
          height: 40,
        ),
        math.pi * 0.7,
        math.pi * 1.2,
        false,
        arcPaint,
      )
      // Right arc.
      ..drawArc(
        Rect.fromCenter(
          center: Offset(
            cx + separation,
            size.height * 0.3 + bobOffset,
          ),
          width: 40,
          height: 40,
        ),
        -math.pi * 0.3,
        math.pi * 1.2,
        false,
        arcPaint,
      );

    // Small decorative dots.
    final dotPaint = Paint()
      ..color = isDark
          ? const Color(0x33FFFFFF)
          : const Color(0x22000000);
    for (var i = 0; i < 5; i++) {
      final angle =
          (i / 5) * 2 * math.pi + progress * 2 * math.pi;
      final r = 60.0 + i * 8;
      final dx = cx + math.cos(angle) * r;
      final dy =
          size.height * 0.3 + math.sin(angle) * r * 0.5;
      canvas.drawCircle(
        Offset(dx, dy + bobOffset),
        2 + i * 0.5,
        dotPaint,
      );
    }
  }

  @override
  bool shouldRepaint(_IllustrationPainter oldDelegate) =>
      progress != oldDelegate.progress;
}
