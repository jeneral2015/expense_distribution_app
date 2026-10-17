import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../utils/button_utils.dart';
import '../utils/database.dart';
import '../utils/background_scaffold.dart';

class DistributeExpensesPage extends StatelessWidget {
  final DatabaseManager db;
  final VoidCallback navigateToMain;
  final String? backgroundImagePath;

  const DistributeExpensesPage({
    super.key,
    required this.db,
    required this.navigateToMain,
    this.backgroundImagePath,
  });

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (bool didPop, dynamic result) {
        if (didPop) return;
        navigateToMain();
      },
      child: BackgroundScaffold(
        title: 'توزيع المصروفات',
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20.0),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final double buttonWidth = constraints.maxWidth < 600
                    ? constraints.maxWidth * 0.8
                    : 280;
                const double buttonHeight = 52.0;
                const double spacing = 20.0;

                return Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    createButton(
                      text: '☕ المشروبات',
                      onPressed: () => context.go('/drink'),
                      bgColor: Colors.green[700]!,
                      width: buttonWidth,
                      height: buttonHeight,
                    ),
                    const SizedBox(height: spacing),
                    createButton(
                      text: '🍽️ الوجبات',
                      onPressed: () => context.go('/meal'),
                      bgColor: Colors.green[700]!,
                      width: buttonWidth,
                      height: buttonHeight,
                    ),
                    const SizedBox(height: spacing * 2),
                    createButton(
                      text: 'رجوع',
                      onPressed: () => navigateToMain(),
                      bgColor: Colors.red[700]!,
                      width: buttonWidth,
                      height: buttonHeight,
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}