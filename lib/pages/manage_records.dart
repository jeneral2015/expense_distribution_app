import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../utils/button_utils.dart';
import '../utils/background_scaffold.dart';
import '../utils/database.dart';
import 'reports_page/unified_meals_report.dart';
import 'reports_page/unified_drinks_report.dart';
import 'reports_page/unified_member_consumption_report.dart';

class ManageRecordsPage extends StatefulWidget {
  final DatabaseManager db;
  final VoidCallback navigateToMain;

  const ManageRecordsPage({
    super.key,
    required this.db,
    required this.navigateToMain,
  });

  @override
  State<ManageRecordsPage> createState() => _ManageRecordsPageState();
}

class _ManageRecordsPageState extends State<ManageRecordsPage> {
  final TextStyle textStyle = const TextStyle(
    fontSize: 15,
    fontFamily: 'Cairo',
  );

  void _pushPage(Widget page) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => page),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (bool didPop, dynamic result) {
        if (didPop) return;
        context.go('/main');
      },
      child: BackgroundScaffold(
        title: 'إدارة السجلات',
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 20.0),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 500),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildRecordCard(
                    title: 'سجلات الوجبات',
                    buttonText: 'إدارة سجلات الوجبات',
                    icon: Icons.restaurant,
                    color: Colors.orange[700]!,
                    onPressed: () => _pushPage(MealsReportPage(db: widget.db)),
                  ),
                  const SizedBox(height: 16),
                  _buildRecordCard(
                    title: 'سجلات المشروبات',
                    buttonText: 'إدارة سجلات المشروبات',
                    icon: Icons.local_cafe,
                    color: Colors.brown[700]!,
                    onPressed: () => _pushPage(DrinksReportPage(db: widget.db)),
                  ),
                  const SizedBox(height: 16),
                  _buildRecordCard(
                    title: 'سجلات استهلاك المشتركين',
                    buttonText: 'إدارة استهلاك المشتركين',
                    icon: Icons.person,
                    color: Colors.teal[700]!,
                    onPressed: () =>
                        _pushPage(MemberConsumptionReportPage(db: widget.db)),
                  ),
                  const SizedBox(height: 32),
                  Center(
                    child: createButton(
                      text: 'رجوع',
                      onPressed: () => context.go('/main'),
                      bgColor: Colors.red[700]!,
                      textColor: Colors.white,
                      width: 250,
                      height: 50,
                      icon: Icons.arrow_back,
                      iconColor: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRecordCard({
    required String title,
    required String buttonText,
    required IconData icon,
    required Color color,
    required VoidCallback onPressed,
  }) {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(18.0),
        child: Column(
          children: [
            Text(
              title,
              style: textStyle.copyWith(
                fontSize: 17,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 14),
            createButton(
              text: buttonText,
              onPressed: onPressed,
              bgColor: color,
              textColor: Colors.white,
              width: 260,
              height: 48,
              icon: icon,
              iconColor: Colors.white,
            ),
          ],
        ),
      ),
    );
  }
}
