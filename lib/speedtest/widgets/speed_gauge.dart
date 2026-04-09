import 'dart:math';

import 'package:flutter/material.dart';

class SpeedGauge extends StatelessWidget {
  const SpeedGauge({
    super.key,
    required this.valueMbps,
    required this.phaseLabel,
    required this.maxMbps,
    required this.isRunning,
    required this.onTap,
  });

  final double valueMbps;
  final String phaseLabel;
  final double maxMbps;
  final bool isRunning;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final clamped = valueMbps.clamp(0.0, maxMbps).toDouble();
    const goDiameter = 140.0;

    return AspectRatio(
      aspectRatio: 1,
      child: TweenAnimationBuilder<double>(
        duration: const Duration(milliseconds: 160),
        curve: Curves.easeOutCubic,
        tween: Tween<double>(end: clamped),
        child: _GoButton(
          isRunning: isRunning,
          diameter: goDiameter,
          onTap: onTap,
        ),
        builder: (context, animatedValue, child) {
          final progress = maxMbps <= 0
              ? 0.0
              : (animatedValue / maxMbps).clamp(0.0, 1.0);
          return Stack(
            alignment: Alignment.center,
            children: [
              CustomPaint(
                painter: _GaugePainter(
                  progress: progress,
                  valueMbps: animatedValue,
                  maxMbps: maxMbps,
                  isRunning: isRunning,
                  phaseLabel: phaseLabel,
                  goDiameter: goDiameter,
                  colorScheme: Theme.of(context).colorScheme,
                ),
                size: Size.infinite,
              ),
              if (child != null) ...[child],
            ],
          );
        },
      ),
    );
  }
}

class _GoButton extends StatelessWidget {
  const _GoButton({
    required this.isRunning,
    required this.diameter,
    required this.onTap,
  });

  final bool isRunning;
  final double diameter;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: isRunning ? null : onTap,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 180),
        opacity: isRunning ? 0.55 : 1.0,
        child: Container(
          height: diameter,
          width: diameter,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              colors: [
                Colors.white.withValues(alpha: 0.12),
                Colors.white.withValues(alpha: 0.02),
              ],
            ),
            border: Border.all(color: Colors.white.withValues(alpha: 0.20)),
            boxShadow: [
              BoxShadow(
                color: scheme.primary.withValues(alpha: 0.30),
                blurRadius: 22,
                spreadRadius: 1,
              ),
            ],
          ),
          child: Center(
            child: Text(
              'GO',
              style: TextStyle(
                fontSize: diameter * 0.34,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.8,
                color: Colors.white,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _GaugePainter extends CustomPainter {
  _GaugePainter({
    required this.progress,
    required this.valueMbps,
    required this.maxMbps,
    required this.isRunning,
    required this.phaseLabel,
    required this.goDiameter,
    required this.colorScheme,
  });

  final double progress;
  final double valueMbps;
  final double maxMbps;
  final bool isRunning;
  final String phaseLabel;
  final double goDiameter;
  final ColorScheme colorScheme;

  static const _startAngle = 5 * pi / 4;
  static const _sweepAngle = 3 * pi / 2;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = min(size.width, size.height) * 0.42;
    final rect = Rect.fromCircle(center: center, radius: radius);

    final glowPaint = Paint()
      ..color = colorScheme.primary.withValues(alpha: 0.18)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 26);
    canvas.drawCircle(center, radius * 0.88, glowPaint);

    final basePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = radius * 0.14
      ..strokeCap = StrokeCap.round
      ..color = Colors.white.withValues(alpha: 0.08);
    canvas.drawArc(rect, _startAngle, _sweepAngle, false, basePaint);

    final arcPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = radius * 0.14
      ..strokeCap = StrokeCap.round
      ..shader = SweepGradient(
        startAngle: _startAngle,
        endAngle: _startAngle + _sweepAngle,
        colors: [
          const Color(0xFF22C55E),
          const Color(0xFF3B82F6),
          const Color(0xFFA855F7),
        ],
      ).createShader(rect);
    canvas.drawArc(rect, _startAngle, _sweepAngle * progress, false, arcPaint);

    _paintTicks(canvas, center, radius);

    final needleAngle = _startAngle + (_sweepAngle * progress);
    _paintNeedle(canvas, center, radius, needleAngle);

    _paintCenterTexts(canvas, size, center);
  }

  void _paintTicks(Canvas canvas, Offset center, double radius) {
    final tickPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.18)
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;

    const tickCount = 14;
    for (var i = 0; i <= tickCount; i++) {
      final t = i / tickCount;
      final angle = _startAngle + _sweepAngle * t;
      final p1 = Offset(
        center.dx + cos(angle) * (radius * 1.00),
        center.dy + sin(angle) * (radius * 1.00),
      );
      final p2 = Offset(
        center.dx + cos(angle) * (radius * 1.12),
        center.dy + sin(angle) * (radius * 1.12),
      );
      canvas.drawLine(p1, p2, tickPaint);
    }
  }

  void _paintNeedle(Canvas canvas, Offset center, double radius, double angle) {
    final needlePaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.92)
      ..strokeWidth = radius * 0.03
      ..strokeCap = StrokeCap.round;

    final glowPaint = Paint()
      ..color = colorScheme.primary.withValues(alpha: 0.35)
      ..strokeWidth = radius * 0.05
      ..strokeCap = StrokeCap.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10);

    final end = Offset(
      center.dx + cos(angle) * (radius * 1.05),
      center.dy + sin(angle) * (radius * 1.05),
    );

    canvas.drawLine(center, end, glowPaint);
    canvas.drawLine(center, end, needlePaint);

    final hubPaint = Paint()
      ..color = const Color(0xFF0B1224)
      ..style = PaintingStyle.fill;
    final hubBorder = Paint()
      ..color = Colors.white.withValues(alpha: 0.22)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    canvas.drawCircle(center, radius * 0.10, hubPaint);
    canvas.drawCircle(center, radius * 0.10, hubBorder);

    final dotPaint = Paint()..color = colorScheme.primary;
    canvas.drawCircle(center, radius * 0.03, dotPaint);
  }

  void _paintCenterTexts(Canvas canvas, Size size, Offset center) {
    final value = valueMbps.isFinite ? valueMbps : 0.0;
    final valueText = value >= 100
        ? value.toStringAsFixed(0)
        : value >= 10
        ? value.toStringAsFixed(1)
        : value.toStringAsFixed(2);

    final phase = phaseLabel.toUpperCase();

    final valuePainter = TextPainter(
      text: TextSpan(
        text: valueText,
        style: TextStyle(
          color: Colors.white,
          fontSize: size.width * 0.14,
          fontWeight: FontWeight.w800,
          height: 1.0,
        ),
      ),
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
    )..layout();

    final unitPainter = TextPainter(
      text: TextSpan(
        text: 'Mbps',
        style: TextStyle(
          color: Colors.white.withValues(alpha: 0.70),
          fontSize: size.width * 0.040,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.8,
        ),
      ),
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
    )..layout();

    final phasePainter = TextPainter(
      text: TextSpan(
        text: isRunning ? phase : '',
        style: TextStyle(
          color: Colors.white.withValues(alpha: 0.62),
          fontSize: size.width * 0.034,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.3,
        ),
      ),
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
    )..layout();

    final maxPainter = TextPainter(
      text: TextSpan(
        text: 'max ${maxMbps.toStringAsFixed(0)}',
        style: TextStyle(
          color: Colors.white.withValues(alpha: 0.38),
          fontSize: size.width * 0.030,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.6,
        ),
      ),
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
    )..layout();

    final lift = goDiameter * 0.55;
    final yTop = center.dy - lift - (valuePainter.height / 2);
    valuePainter.paint(
      canvas,
      Offset(center.dx - valuePainter.width / 2, yTop),
    );
    unitPainter.paint(
      canvas,
      Offset(
        center.dx - unitPainter.width / 2,
        yTop + valuePainter.height + size.width * 0.010,
      ),
    );

    final bottomY = center.dy + (goDiameter / 2) + size.width * 0.06;
    phasePainter.paint(
      canvas,
      Offset(center.dx - phasePainter.width / 2, bottomY),
    );
    maxPainter.paint(
      canvas,
      Offset(
        center.dx - maxPainter.width / 2,
        bottomY + phasePainter.height + size.width * 0.018,
      ),
    );
  }

  @override
  bool shouldRepaint(covariant _GaugePainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.valueMbps != valueMbps ||
        oldDelegate.isRunning != isRunning ||
        oldDelegate.phaseLabel != phaseLabel ||
        oldDelegate.maxMbps != maxMbps ||
        oldDelegate.goDiameter != goDiameter ||
        oldDelegate.colorScheme != colorScheme;
  }
}
