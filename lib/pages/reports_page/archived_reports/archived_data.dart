import 'package:flutter/material.dart';
import '../../../utils/button_utils.dart';
import '../../../utils/database.dart';
import '../../../utils/background_scaffold.dart';
import '../unified_expenses_report.dart';
import '../unified_remaining_report.dart';
import '../unified_meals_report.dart';
import '../unified_drinks_report.dart';
import '../unified_consumption_report.dart';
import '../unified_member_consumption_report.dart';

class ArchivedDataPage extends StatelessWidget {
  final DatabaseManager db;
  final int? archiveKeyId;

  const ArchivedDataPage({
    super.key,
    required this.db,
    this.archiveKeyId,
  });

  void _pushPage(BuildContext context, Widget page) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => page),
    );
  }

  @override
  Widget build(BuildContext context) {
    final double screenWidth = MediaQuery.of(context).size.width;
    final double buttonWidth =
        screenWidth < 600 ? screenWidth * 0.42 : screenWidth * 0.35;
    const double spacing = 12.0;
    const double runSpacing = 16.0;

    return BackgroundScaffold(
      title: 'بيانات الأرشيف',
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'تقارير الفترة المؤرشفة (ID: $archiveKeyId)',
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'Cairo',
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              Wrap(
                alignment: WrapAlignment.center,
                spacing: spacing,
                runSpacing: runSpacing,
                children: [
                  createButton(
                    text: 'تقرير المصروفات',
                    onPressed: () => _pushPage(
                      context,
                      ExpensesReportPage(db: db, archiveKeyId: archiveKeyId),
                    ),
                    bgColor: Colors.blue[700]!,
                    width: buttonWidth,
                  ),
                  createButton(
                    text: 'تقرير المتبقيات',
                    onPressed: () => _pushPage(
                      context,
                      RemainingReportPage(db: db, archiveKeyId: archiveKeyId),
                    ),
                    bgColor: Colors.blue[700]!,
                    width: buttonWidth,
                  ),
                  createButton(
                    text: 'تقرير الوجبات',
                    onPressed: () => _pushPage(
                      context,
                      MealsReportPage(db: db, archiveKeyId: archiveKeyId),
                    ),
                    bgColor: Colors.blue[700]!,
                    width: buttonWidth,
                  ),
                  createButton(
                    text: 'تقرير المشروبات',
                    onPressed: () => _pushPage(
                      context,
                      DrinksReportPage(db: db, archiveKeyId: archiveKeyId),
                    ),
                    bgColor: Colors.blue[700]!,
                    width: buttonWidth,
                  ),
                  createButton(
                    text: 'استهلاك مشترك',
                    onPressed: () => _pushPage(
                      context,
                      MemberConsumptionReportPage(
                          db: db, archiveKeyId: archiveKeyId),
                    ),
                    bgColor: Colors.blue[700]!,
                    width: buttonWidth,
                  ),
                  createButton(
                    text: 'تقرير الاستهلاك العام',
                    onPressed: () => _pushPage(
                      context,
                      ConsumptionReportPage(
                          db: db, archiveKeyId: archiveKeyId),
                    ),
                    bgColor: Colors.blue[700]!,
                    width: buttonWidth,
                  ),
                ],
              ),
              const SizedBox(height: 36),
              createButton(
                text: 'رجوع',
                onPressed: () => Navigator.pop(context),
                bgColor: Colors.red[700]!,
                width: buttonWidth,
              ),
            ],
          ),
        ),
      ),
    );
  }
}