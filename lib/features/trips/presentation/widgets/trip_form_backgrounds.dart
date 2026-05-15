import 'package:flutter/material.dart';

/// Reusable soft gradient background with skyline accent
class SoftGradientBackground extends StatelessWidget {
  const SoftGradientBackground({super.key});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned(
          top: -120,
          left: -60,
          right: -60,
          child: Container(
            height: 330,
            decoration: BoxDecoration(
              gradient: RadialGradient(
                colors: [
                  const Color(0xFF7C3AED).withValues(alpha: 0.08),
                  Colors.transparent,
                ],
              ),
            ),
          ),
        ),
        Positioned(
          bottom: -80,
          left: -30,
          right: -30,
          child: Opacity(
            opacity: 0.08,
            child: SizedBox(
              height: 140,
              child: CustomPaint(
                painter: SkylinePainter(),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Custom painter for decorative cityscape silhouette
class SkylinePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF7C3AED)
      ..style = PaintingStyle.fill;

    final path = Path()
      ..moveTo(0, size.height)
      ..lineTo(size.width * 0.08, size.height * 0.55)
      ..lineTo(size.width * 0.16, size.height)
      ..lineTo(size.width * 0.28, size.height * 0.72)
      ..lineTo(size.width * 0.33, size.height)
      ..lineTo(size.width * 0.48, size.height * 0.42)
      ..lineTo(size.width * 0.53, size.height)
      ..lineTo(size.width * 0.68, size.height * 0.68)
      ..lineTo(size.width * 0.78, size.height)
      ..lineTo(size.width * 0.92, size.height * 0.50)
      ..lineTo(size.width, size.height)
      ..close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
