import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../utils/button_utils.dart';
import '../../utils/background_scaffold.dart';
import 'current_reports/current_reports.dart';
import 'archived_reports/archived_reports.dart';

class ReportsPage extends StatelessWidget {
  final String? backgroundImagePath;
  final dynamic db;
  final VoidCallback navigateToMain;

  const ReportsPage({
    super.key,
    this.backgroundImagePath,
    required this.db,
    required this.navigateToMain,
  });

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (bool didPop, dynamic result) {
        if (didPop) return;
        context.go('/main');
      },
      child: BackgroundScaffold(
        title: 'التقارير',
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20.0),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final double buttonWidth = constraints.maxWidth < 600
                    ? constraints.maxWidth * 0.8
                    : 280;
                const double buttonHeight = 52;
                const double spacing = 24;

                return Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    SizedBox(
                      width: buttonWidth,
                      height: buttonHeight,
                      child: createButton(
                        text: '📅  الشهر الحالي',
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => CurrentReportsPage(db: db),
                            ),
                          );
                        },
                        bgColor: Colors.green[700]!,
                      ),
                    ),
                    const SizedBox(height: spacing),
                    SizedBox(
                      width: buttonWidth,
                      height: buttonHeight,
                      child: createButton(
                        text: '🗓️  الأشهر السابقة',
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => ArchivedReportsPage(db: db),
                            ),
                          );
                        },
                        bgColor: Colors.blue[700]!,
                      ),
                    ),
                    const SizedBox(height: spacing * 2),
                    SizedBox(
                      width: buttonWidth,
                      height: buttonHeight,
                      child: createButton(
                        text: 'رجوع',
                        onPressed: () => context.go('/main'),
                        bgColor: Colors.red[700]!,
                      ),
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