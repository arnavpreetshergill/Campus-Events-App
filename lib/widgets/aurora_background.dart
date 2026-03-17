import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class AuroraBackground extends StatefulWidget {
  const AuroraBackground({super.key});

  @override
  State<AuroraBackground> createState() => _AuroraBackgroundState();
}

class _AuroraBackgroundState extends State<AuroraBackground>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 12),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final t = _controller.value;
        return DecoratedBox(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: <Color>[
                Color(0xFF050A15),
                AppTheme.ink,
                Color(0xFF081B29),
              ],
            ),
          ),
          child: Stack(
            fit: StackFit.expand,
            children: <Widget>[
              Positioned(
                left: -60 + (t * 80),
                top: -40 + (t * 18),
                child: _GlowOrb(
                  diameter: 280,
                  color: AppTheme.coral.withValues(alpha: 0.16),
                ),
              ),
              Positioned(
                right: -90 + (t * 45),
                top: 120 - (t * 30),
                child: _GlowOrb(
                  diameter: 340,
                  color: AppTheme.cyan.withValues(alpha: 0.14),
                ),
              ),
              Positioned(
                left: 40 - (t * 25),
                bottom: -110 + (t * 65),
                child: _GlowOrb(
                  diameter: 300,
                  color: AppTheme.gold.withValues(alpha: 0.10),
                ),
              ),
              Positioned.fill(
                child: CustomPaint(painter: _GridPainter(progress: t)),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _GlowOrb extends StatelessWidget {
  const _GlowOrb({required this.diameter, required this.color});

  final double diameter;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: diameter,
        height: diameter,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: <Color>[color, color.withValues(alpha: 0)],
          ),
        ),
      ),
    );
  }
}

class _GridPainter extends CustomPainter {
  const _GridPainter({required this.progress});

  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final gridPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.06)
      ..strokeWidth = 1;

    const spacing = 34.0;
    final shift = progress * spacing;

    for (double x = -spacing; x < size.width + spacing; x += spacing) {
      canvas.drawLine(
        Offset(x + shift, 0),
        Offset(x + shift - 20, size.height),
        gridPaint,
      );
    }

    for (double y = 0; y < size.height + spacing; y += spacing) {
      final alpha = 0.04 + (0.02 * math.sin((y / size.height) + progress));
      gridPaint.color = Colors.white.withValues(alpha: alpha);
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _GridPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}
