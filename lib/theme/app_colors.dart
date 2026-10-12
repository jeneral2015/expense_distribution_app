import 'package:flutter/material.dart';

class AppColors {
  static const Color headerDarkTeal = Color(0xFF1E4C54);
  static const Color headerLightWave = Color(0xFFE8EFE9);
  static const Color background = Color(0xFFF9FAF7);
  static const Color bottomOrange = Color(0xFFDEB082);
  static const Color bottomTeal = Color(0xFF4C8D8B);
  static const Color closeButtonRed = Color(0xFFE43B4E);
  static const Color textPrimary = Color(0xFF1A1A1A);
  static const Color textSecondary = Color(0xFF666666);
}

class BackgroundPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    // Light beige wave at the top
    final Paint lightTeal = Paint()..color = AppColors.headerLightWave..style = PaintingStyle.fill;
    Path path1 = Path();
    path1.lineTo(0, size.height * 0.25);
    path1.quadraticBezierTo(size.width * 0.25, size.height * 0.35, size.width * 0.5, size.height * 0.25);
    path1.quadraticBezierTo(size.width * 0.75, size.height * 0.15, size.width, size.height * 0.28);
    path1.lineTo(size.width, 0);
    path1.close();
    canvas.drawPath(path1, lightTeal);

    // Bottom orange wave
    final Paint bottomOrange = Paint()..color = AppColors.bottomOrange..style = PaintingStyle.fill;
    Path path2 = Path();
    path2.moveTo(0, size.height);
    path2.lineTo(0, size.height * 0.85);
    path2.quadraticBezierTo(size.width * 0.25, size.height * 0.75, size.width * 0.5, size.height * 0.85);
    path2.quadraticBezierTo(size.width * 0.8, size.height * 0.95, size.width, size.height * 0.75);
    path2.lineTo(size.width, size.height);
    path2.close();
    canvas.drawPath(path2, bottomOrange);

    // Bottom teal wave
    final Paint bottomTeal = Paint()..color = AppColors.bottomTeal..style = PaintingStyle.fill;
    Path path3 = Path();
    path3.moveTo(0, size.height);
    path3.lineTo(0, size.height * 0.90);
    path3.quadraticBezierTo(size.width * 0.2, size.height * 0.85, size.width * 0.45, size.height * 0.95);
    path3.quadraticBezierTo(size.width * 0.8, size.height * 1.05, size.width, size.height * 0.85);
    path3.lineTo(size.width, size.height);
    path3.close();
    canvas.drawPath(path3, bottomTeal);
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}

class HeaderWaveClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    Path path = Path();
    path.lineTo(0, size.height - 30);
    path.quadraticBezierTo(size.width * 0.25, size.height, size.width * 0.5, size.height - 25);
    path.quadraticBezierTo(size.width * 0.75, size.height - 50, size.width, size.height - 20);
    path.lineTo(size.width, 0);
    path.close();
    return path;
  }

  @override
  bool shouldReclip(CustomClipper<Path> oldClipper) => false;
}
