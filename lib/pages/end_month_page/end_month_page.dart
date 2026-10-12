import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../utils/button_utils.dart';
import '../../utils/database.dart';
import '../../utils/background_scaffold.dart';
import 'distribute_miscellaneous.dart';
import 'clear_data.dart';
import 'finalize_month.dart';

class EndMonthPage extends StatefulWidget {
  final DatabaseManager db;
  final String backgroundImagePath;
  final VoidCallback navigateToMain;

  const EndMonthPage({
    super.key,
    required this.db,
    required this.backgroundImagePath,
    required this.navigateToMain,
  });

  @override
  State<EndMonthPage> createState() => _EndMonthPageState();
}

class _EndMonthPageState extends State<EndMonthPage> {
  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (bool didPop, dynamic result) {
        if (didPop) return;
        context.go('/main');
      },
      child: BackgroundScaffold(
        title: 'تقفيل الشهر',
        backgroundImagePath: widget.backgroundImagePath,
        child: Stack(
          children: [
            Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16.0),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    // تحديد حجم الزر حسب حجم الشاشة
                    double buttonWidth = constraints.maxWidth < 600
                        ? constraints.maxWidth * 0.8
                        : constraints.maxWidth * 0.25;
                    double buttonHeight = constraints.maxWidth < 600 ? 48 : 56;
                    double spacing = constraints.maxWidth < 600 ? 12 : 24;

                    return Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        const SizedBox(height: 20),

                        // استخدم Wrap بدلاً من Row
                        Wrap(
                          alignment: WrapAlignment.center,
                          spacing: spacing,
                          runSpacing: spacing,
                          children: [
                            SizedBox(
                              width: buttonWidth,
                              height: buttonHeight,
                              child: createButton(
                                text: 'توزيع النثريات',
                                onPressed: () {
                                  DistributeMiscellaneous(
                                    context,
                                    widget.db,
                                  ).showConfirmation();
                                },
                                bgColor: Colors.blue,
                              ),
                            ),
                            SizedBox(
                              width: buttonWidth,
                              height: buttonHeight,
                              child: createButton(
                                text: 'مسح البيانات',
                                onPressed: () {
                                  ClearData(
                                    context,
                                    widget.db,
                                  ).showConfirmation();
                                },
                                bgColor: Colors.orange,
                              ),
                            ),
                            SizedBox(
                              width: buttonWidth,
                              height: buttonHeight,
                              child: createButton(
                                text: 'تقفيل الشهر',
                                onPressed: () {
                                  FinalizeMonth(
                                    context,
                                    widget.db,
                                  ).startProcess();
                                },
                                bgColor: Colors.green,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 40),
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