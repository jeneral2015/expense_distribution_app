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

class CurrentReportsPage extends StatefulWidget {
  final DatabaseManager db;

  const CurrentReportsPage({
    super.key,
    required this.db,
  });

  @override
  State<CurrentReportsPage> createState() => _CurrentReportsPageState();
}

class _CurrentReportsPageState extends State<CurrentReportsPage> {
  final TextStyle textStyle = const TextStyle(fontSize: 15, fontFamily: 'Cairo');

  TextStyle getTitleStyle(BuildContext context) {
    final double screenWidth = MediaQuery.of(context).size.width;
    return TextStyle(
      fontSize: screenWidth < 400 ? 24 : 28,
      fontWeight: FontWeight.bold,
      fontFamily: 'Cairo',
    );
  }

  void _pushPage(Widget page) {
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
      title: 'تقارير الشهر الحالي',
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'تقارير الشهر الحالي',
                style: getTitleStyle(context),
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
                    onPressed: () => _pushPage(ExpensesReportPage(db: widget.db)),
                    bgColor: Colors.green[700]!,
                    width: buttonWidth,
                  ),
                  createButton(
                    text: 'تقرير المتبقيات',
                    onPressed: () => _pushPage(RemainingReportPage(db: widget.db)),
                    bgColor: Colors.green[700]!,
                    width: buttonWidth,
                  ),
                  createButton(
                    text: 'تقرير الوجبات',
                    onPressed: () => _pushPage(MealsReportPage(db: widget.db)),
                    bgColor: Colors.green[700]!,
                    width: buttonWidth,
                  ),
                  createButton(
                    text: 'تقرير المشروبات',
                    onPressed: () => _pushPage(DrinksReportPage(db: widget.db)),
                    bgColor: Colors.green[700]!,
                    width: buttonWidth,
                  ),
                  createButton(
                    text: 'استهلاك مشترك',
                    onPressed: () =>
                        _pushPage(MemberConsumptionReportPage(db: widget.db)),
                    bgColor: Colors.green[700]!,
                    width: buttonWidth,
                  ),
                  createButton(
                    text: 'تقرير الاستهلاك العام',
                    onPressed: () =>
                        _pushPage(ConsumptionReportPage(db: widget.db)),
                    bgColor: Colors.green[700]!,
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