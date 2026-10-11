import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../utils/button_utils.dart';
import '../../../utils/database.dart';
import '../../../utils/background_scaffold.dart';
import 'expenses_report.dart';
import 'remaining_report.dart';
import 'meals_report.dart';
import 'drinks_report.dart';
import 'consumption_report.dart';
import 'member_consumption.dart';

class CurrentReportsPage extends StatefulWidget {
  final DatabaseManager db;

  const CurrentReportsPage({
    Key? key,
    required this.db,
  }) : super(key: key);

  @override
  _CurrentReportsPageState createState() => _CurrentReportsPageState();
}

class _CurrentReportsPageState extends State<CurrentReportsPage> {
  final TextStyle textStyle = const TextStyle(
    fontSize: 15,
    fontFamily: 'Cairo',
  );

  TextStyle getTitleStyle(BuildContext context) {
    final double screenWidth = MediaQuery.of(context).size.width;
    return TextStyle(
      fontSize: screenWidth < 400 ? 24 : 28,
      fontWeight: FontWeight.bold,
      fontFamily: 'Cairo',
    );
  }

  @override
  void initState() {
    super.initState();
    _checkDatabaseConnection();
  }

  Future<void> _checkDatabaseConnection() async {
    try {
      await widget.db.fetchAll('SELECT 1');
    } catch (e) {
      showSnackBar('خطأ في الاتصال بقاعدة البيانات: $e');
    }
  }

  void showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: textStyle,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }

  void navigateToParent() {
    Navigator.pop(context);
  }

  void showExpensesReport(BuildContext context, DatabaseManager db) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ExpensesReport(db: db),
      ),
    );
  }

  void showRemainingReport(BuildContext context, DatabaseManager db) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => RemainingReport(db: db),
      ),
    );
  }

  void showMealsReport(BuildContext context, DatabaseManager db) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => MealsReport(db: db),
      ),
    );
  }

  void showDrinksReport(BuildContext context, DatabaseManager db) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => DrinksReport(db: db),
      ),
    );
  }

  void showConsumptionReport(BuildContext context, DatabaseManager db) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ConsumptionReport(db: db),
      ),
    );
  }

  void showMemberConsumption(BuildContext context, DatabaseManager db) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => MemberConsumption(db: db),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final double screenWidth = MediaQuery.of(context).size.width;
    final double screenHeight = MediaQuery.of(context).size.height;
    final double buttonWidth = screenWidth < 600 ? screenWidth * 0.4 : screenWidth * 0.35;
    final double padding = screenWidth < 400 ? 8.0 : 16.0;
    final double spacing = screenWidth < 400 ? 8.0 : 10.0;
    final double runSpacing = screenHeight < 600 ? 30.0 : 40.0;

    return BackgroundScaffold(
      backgroundImagePath: 'assets/3.jpg',
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Stack(
          children: [
            Center(
              child: Container(
                constraints: BoxConstraints(
                  maxWidth: screenWidth * 0.9,
                  maxHeight: screenHeight * 0.8,
                ),
                padding: EdgeInsets.symmetric(horizontal: padding, vertical: padding),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    ConstrainedBox(
                      constraints: BoxConstraints(maxWidth: screenWidth * 0.9),
                      child: Text(
                        'تقارير الشهر الحالي',
                        style: getTitleStyle(context).copyWith(color: Colors.black),
                        textAlign: TextAlign.center,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    SizedBox(height: runSpacing),
                    Wrap(
                      spacing: spacing,
                      runSpacing: runSpacing,
                      alignment: WrapAlignment.center,
                      runAlignment: WrapAlignment.center,
                      children: [
                        createButton(
                          text: 'تقرير المصروفات',
                          onPressed: () => showExpensesReport(context, widget.db),
                          bgColor: Colors.blue[700]!,
                          textColor: Colors.white,
                          width: buttonWidth,
                          height: 50,
                          icon: Icons.receipt,
                          iconColor: Colors.white,
                        ),
                        createButton(
                          text: 'تقرير المتبقيات',
                          onPressed: () => showRemainingReport(context, widget.db),
                          bgColor: Colors.green[700]!,
                          textColor: Colors.white,
                          width: buttonWidth,
                          height: 50,
                          icon: Icons.inventory,
                          iconColor: Colors.white,
                        ),
                      ],
                    ),
                    SizedBox(height: runSpacing),
                    Wrap(
                      spacing: spacing,
                      runSpacing: runSpacing,
                      alignment: WrapAlignment.center,
                      runAlignment: WrapAlignment.center,
                      children: [
                        createButton(
                          text: 'تقرير الوجبات',
                          onPressed: () => showMealsReport(context, widget.db),
                          bgColor: Colors.indigo[700]!,
                          textColor: Colors.white,
                          width: buttonWidth,
                          height: 50,
                          icon: Icons.restaurant,
                          iconColor: Colors.white,
                        ),
                        createButton(
                          text: 'تقرير المشروبات',
                          onPressed: () => showDrinksReport(context, widget.db),
                          bgColor: Colors.teal[700]!,
                          textColor: Colors.white,
                          width: buttonWidth,
                          height: 50,
                          icon: Icons.local_drink,
                          iconColor: Colors.white,
                        ),
                      ],
                    ),
                    SizedBox(height: runSpacing),
                    Wrap(
                      spacing: spacing,
                      runSpacing: runSpacing,
                      alignment: WrapAlignment.center,
                      runAlignment: WrapAlignment.center,
                      children: [
                        createButton(
                          text: 'تقرير استهلاك المشتركين',
                          onPressed: () => showConsumptionReport(context, widget.db),
                          bgColor: Colors.orange[700]!,
                          textColor: Colors.white,
                          width: buttonWidth,
                          height: 50,
                          icon: Icons.group,
                          iconColor: Colors.white,
                        ),
                        createButton(
                          text: 'تقرير استهلاك مشترك',
                          onPressed: () => showMemberConsumption(context, widget.db),
                          bgColor: Colors.purple[700]!,
                          textColor: Colors.white,
                          width: buttonWidth,
                          height: 50,
                          icon: Icons.person,
                          iconColor: Colors.white,
                        ),
                      ],
                    ),
                    SizedBox(height: runSpacing),
                    Wrap(
                      spacing: spacing,
                      runSpacing: runSpacing,
                      alignment: WrapAlignment.center,
                      runAlignment: WrapAlignment.center,
                      children: [
                        createButton(
                          text: 'رجوع',
                          onPressed: navigateToParent,
                          bgColor: Colors.red[700]!,
                          textColor: Colors.white,
                          width: buttonWidth,
                          height: 50,
                          icon: Icons.arrow_back,
                          iconColor: Colors.white,
                        ),
                      ],
                    ),
                  ],
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