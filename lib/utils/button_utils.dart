import 'package:flutter/material.dart';

/// دالة محسنة لإنشاء زر مخصص بدون مشاكل تجاوز المساحة
Widget createButton({
  required String text,
  required VoidCallback onPressed,
  Color bgColor = Colors.green,
  Color textColor = Colors.black,
  double width = 200.0,
  double height = 50.0,
  double elevation = 2.0,
  Color? shadowColor,
  IconData? icon,
  Color? iconColor,
}) {
  shadowColor = shadowColor ?? bgColor;

  return Container(
    width: width,
    height: height,
    decoration: BoxDecoration(
      boxShadow: [
        BoxShadow(
          color: shadowColor,
          blurRadius: 10.0,
          spreadRadius: 2.0,
        ),
      ],
    ),
    child: ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: bgColor,
        foregroundColor: textColor,
        elevation: elevation,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10.0),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 10.0),
      ),
      child: SizedBox(
        width: width - 20, // تعويض مساحة الـ padding
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (icon != null) ...[
                Icon(icon, color: iconColor, size: 20),
                const SizedBox(width: 6.0),
              ],
              Flexible(
                child: Text(
                  text,
                  style: const TextStyle(
                    fontFamily: 'Lalezar',
                    fontSize: 16, // حجم خط افتراضي
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

/// دالة لإنشاء زر الهوم
Widget createHomeButton({
  required VoidCallback onPressed,
}) {
  return ElevatedButton(
    onPressed: onPressed,
    style: ElevatedButton.styleFrom(
      backgroundColor: Colors.blue[700],
      foregroundColor: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
      ),
      padding: const EdgeInsets.all(10),
    ),
    child: const Text('🏠', style: TextStyle(fontSize: 20)),
  );
}