import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../utils/button_utils.dart';
import '../../utils/database.dart';
import '../../utils/background_scaffold.dart';
import 'distribute_miscellaneous.dart';
import 'clear_data.dart';
import 'finalize_month.dart';

class EndMonthPage extends StatelessWidget {
  final DatabaseManager db;
  final String? backgroundImagePath;
  final VoidCallback navigateToMain;

  const EndMonthPage({
    super.key,
    required this.db,
    this.backgroundImagePath,
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
        title: 'تقفيل الشهر',
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20.0),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final double buttonWidth = constraints.maxWidth < 600
                    ? constraints.maxWidth * 0.8
                    : 260;
                final double buttonHeight = constraints.maxWidth < 600 ? 50 : 54;
                final double spacing = constraints.maxWidth < 600 ? 14 : 20;

                return Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
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
                              DistributeMiscellaneous(context, db)
                                  .showConfirmation();
                            },
                            bgColor: Colors.blue[700]!,
                          ),
                        ),
                        SizedBox(
                          width: buttonWidth,
                          height: buttonHeight,
                          child: createButton(
                            text: 'مسح البيانات',
                            onPressed: () {
                              ClearData(context, db).showConfirmation();
                            },
                            bgColor: Colors.orange[800]!,
                          ),
                        ),
                        SizedBox(
                          width: buttonWidth,
                          height: buttonHeight,
                          child: createButton(
                            text: 'تقفيل الشهر',
                            onPressed: () {
                              FinalizeMonth(context, db).startProcess();
                            },
                            bgColor: Colors.green[700]!,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 36),
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