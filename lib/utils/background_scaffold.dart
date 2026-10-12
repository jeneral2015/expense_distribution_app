import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../theme/app_colors.dart';

class BackgroundScaffold extends StatelessWidget {
  final Widget child;
  final String? backgroundImagePath; // Kept for compatibility, but ignored for uniform design
  final String? title;
  final bool showAppBar;
  final List<Widget>? actions;

  const BackgroundScaffold({
    super.key,
    required this.child,
    this.backgroundImagePath,
    this.title,
    this.showAppBar = true,
    this.actions,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: showAppBar
          ? AppBar(
              backgroundColor: AppColors.headerDarkTeal,
              foregroundColor: Colors.white,
              title: title != null
                  ? Text(title!, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20))
                  : null,
              centerTitle: true,
              actions: [
                if (actions != null) ...actions!,
                IconButton(
                  icon: const Icon(Icons.home),
                  onPressed: () => context.go('/main'),
                  tooltip: 'الصفحة الرئيسية',
                ),
                const SizedBox(width: 8),
              ],
              shape: const RoundedRectangleBorder(
                borderRadius: BorderRadius.vertical(bottom: Radius.circular(20)),
              ),
            )
          : null,
      body: Stack(
        children: [
          Positioned.fill(
            child: CustomPaint(painter: BackgroundPainter()),
          ),
          Positioned.fill(
            child: SafeArea(child: child),
          ),
        ],
      ),
    );
  }
}
