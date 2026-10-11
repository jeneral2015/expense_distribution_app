import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../utils/button_utils.dart';
import '../../utils/background_scaffold.dart';
import 'current_reports/current_reports.dart';
import 'archived_reports/archived_reports.dart';

class ReportsPage extends StatelessWidget {
  final String backgroundImagePath;
  final dynamic db;
  final VoidCallback navigateToMain;

  const ReportsPage({
    Key? key,
    required this.backgroundImagePath,
    required this.db,
    required this.navigateToMain,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (bool didPop, dynamic result) {
        if (didPop) return;
        context.go('/main');
      },
      child: BackgroundScaffold(
        backgroundImagePath: backgroundImagePath,
        child: Stack(
          children: [
            Center(
              child: SingleChildScrollView(
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minHeight: MediaQuery.of(context).size.height,
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text(
                        'التقارير',
                        style: TextStyle(
                          fontSize: 40,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'DancingScript',
                          color: Color.fromARGB(255, 0, 0, 0),
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 60),
                      LayoutBuilder(
                        builder: (context, constraints) {
                          double buttonWidth = constraints.maxWidth < 600
                              ? constraints.maxWidth * 0.8
                              : constraints.maxWidth * 0.3;
                          double buttonHeight = 50;
                          double spacing = 30;

                          return Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              SizedBox(
                                width: buttonWidth,
                                height: buttonHeight,
                                child: createButton(
                                  text: ' 📅  الشهر الحالي',
                                  onPressed: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) => CurrentReportsPage(db: db),
                                      ),
                                    );
                                  },
                                  bgColor: Colors.green,
                                ),
                              ),
                              SizedBox(height: spacing),
                              SizedBox(
                                width: buttonWidth,
                                height: buttonHeight,
                                child: createButton(
                                  text: ' 🗓️  الأشهر السابقة',
                                  onPressed: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) => ArchivedReportsPage(db: db),
                                      ),
                                    );
                                  },
                                  bgColor: Colors.blue,
                                ),
                              ),
                              SizedBox(height: spacing * 2), // مسافة أكبر قبل زر الرجوع
                              SizedBox(
                                width: buttonWidth,
                                height: buttonHeight,
                                child: createButton(
                                  text: 'رجوع',
                                  onPressed: () => context.go('/main'),
                                  bgColor: Colors.red,
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Positioned(
              top: 20,
              left: 20,
              child: createHomeButton(
                onPressed: () => context.go('/main'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}