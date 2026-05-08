import 'package:flutter/material.dart';

class AppLogo extends StatelessWidget {
  const AppLogo({super.key, this.size = 96, this.showShadow = true});

  final double size;
  final bool showShadow;

  static const Color _black = Color(0xFF0A0A0A);
  static const Color _charcoal = Color(0xFF1F1F1F);
  static const Color _gold = Color(0xFFD4A017);

  @override
  Widget build(BuildContext context) {
    final radius = size * 0.26;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        gradient: const LinearGradient(
          colors: [_charcoal, _black],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(
          color: _gold.withValues(alpha: 0.35),
          width: size * 0.012,
        ),
        boxShadow: showShadow
            ? [
                BoxShadow(
                  color: _gold.withValues(alpha: 0.20),
                  blurRadius: size * 0.28,
                  spreadRadius: -size * 0.08,
                ),
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.45),
                  blurRadius: size * 0.20,
                  offset: Offset(0, size * 0.06),
                ),
              ]
            : null,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: CustomPaint(
          painter: _LogoPainter(),
          size: Size.square(size),
        ),
      ),
    );
  }
}

class _LogoPainter extends CustomPainter {
  static const Color _gold = Color(0xFFD4A017);
  static const Color _goldMid = Color(0xFFE9C46A);
  static const Color _goldHi = Color(0xFFFFE9A8);

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // Yumuşak ışık halesi (sol üstten)
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..shader = RadialGradient(
          colors: [
            _gold.withValues(alpha: 0.12),
            Colors.transparent,
          ],
          center: const Alignment(-0.5, -0.6),
          radius: 0.95,
        ).createShader(Offset.zero & size),
    );

    // Bar chart alanı
    final barRect = Rect.fromLTWH(w * 0.22, h * 0.36, w * 0.56, h * 0.42);
    const barCount = 4;
    final gap = barRect.width * 0.08;
    final barW = (barRect.width - gap * (barCount - 1)) / barCount;
    const heights = [0.42, 0.60, 0.78, 1.0];

    final goldShader = const LinearGradient(
      colors: [_goldHi, _goldMid, _gold],
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
    ).createShader(barRect);
    final paintBar = Paint()..shader = goldShader;

    for (var i = 0; i < barCount; i++) {
      final left = barRect.left + i * (barW + gap);
      final fullH = barRect.height;
      final topOff = fullH * (1 - heights[i]);
      final r = RRect.fromRectAndRadius(
        Rect.fromLTWH(left, barRect.top + topOff, barW, fullH - topOff),
        Radius.circular(barW * 0.30),
      );
      canvas.drawRRect(r, paintBar);
    }

    // Yükselen trend çizgisi (bar tepelerinden geçen)
    final nodes = <Offset>[
      for (var i = 0; i < barCount; i++)
        Offset(
          barRect.left + i * (barW + gap) + barW / 2,
          barRect.top + barRect.height * (1 - heights[i]) - h * 0.005,
        ),
    ];

    final trend = Path()..moveTo(nodes.first.dx, nodes.first.dy);
    for (final n in nodes.skip(1)) {
      trend.lineTo(n.dx, n.dy);
    }

    canvas.drawPath(
      trend,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = w * 0.018
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..color = _goldHi,
    );

    for (final p in nodes) {
      canvas.drawCircle(p, w * 0.022, Paint()..color = _goldHi);
      canvas.drawCircle(
        p,
        w * 0.011,
        Paint()..color = const Color(0xFF0A0A0A),
      );
    }

    // ₺ rozet (sol üst)
    final tp = TextPainter(
      text: TextSpan(
        text: '₺',
        style: TextStyle(
          color: _goldHi,
          fontSize: w * 0.20,
          fontWeight: FontWeight.w900,
          height: 1,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset(w * 0.13, h * 0.13));

    // Alt baseline
    final baselineY = barRect.bottom + h * 0.025;
    canvas.drawLine(
      Offset(w * 0.18, baselineY),
      Offset(w * 0.82, baselineY),
      Paint()
        ..color = _gold.withValues(alpha: 0.55)
        ..strokeWidth = w * 0.010
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
