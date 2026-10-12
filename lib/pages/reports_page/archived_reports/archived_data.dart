import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../utils/button_utils.dart';
import '../../../utils/database.dart';
import 'archived_expenses_report.dart';
import 'archived_remaining_report.dart';
import 'archived_meals_report.dart';
import 'archived_drinks_report.dart';
import 'archived_consumption_report.dart';
import 'archived_member_consumption.dart';
import '../../../utils/background_scaffold.dart';

class ArchivedDataPage extends StatefulWidget {
  final DatabaseManager db;
  final int? archiveKeyId;

  const ArchivedDataPage({
    Key? key,
    required this.db,
    this.archiveKeyId,
  }) : super(key: key);

  @override
  _ArchivedDataPageState createState() => _ArchivedDataPageState();
}

class _ArchivedDataPageState extends State<ArchivedDataPage> {
  final TextStyle textStyle = const TextStyle(
    fontSize: 15,
    
  );
  final TextStyle titleStyle = const TextStyle(
    fontSize: 28,
    fontWeight: FontWeight.bold,
    
  );

  void showExpensesReport(BuildContext context, DatabaseManager db, int archiveKeyId) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ArchivedExpensesReport(
          db: db,
          archiveKeyId: archiveKeyId,
        ),
      ),
    );
  }

  void showRemainingReport(BuildContext context, DatabaseManager db, int archiveKeyId) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ArchivedRemainingReport(
          db: db,
          archiveKeyId: archiveKeyId,
        ),
      ),
    );
  }

  void showMealsReport(BuildContext context, DatabaseManager db, int archiveKeyId) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ArchivedMealsReport(
          db: db,
          archiveKeyId: archiveKeyId,
        ),
      ),
    );
  }

  void showDrinksReport(BuildContext context, DatabaseManager db, int archiveKeyId) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ArchivedDrinksReport(
          db: db,
          archiveKeyId: archiveKeyId,
        ),
      ),
    );
  }

  void showConsumptionReport(BuildContext context, DatabaseManager db, int archiveKeyId) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ArchivedConsumptionReport(
          db: db,
          archiveKeyId: archiveKeyId,
        ),
      ),
    );
  }

  void showMemberConsumption(BuildContext context, DatabaseManager db, int archiveKeyId) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ArchivedMemberConsumption(
          db: db,
          archiveKeyId: archiveKeyId,
        ),
      ),
    );
  }

  void showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: textStyle,
        ),
      ),
    );
  }

  void navigateToParent() {
    Navigator.pop(context);
  }

  Future<Widget> getContent() async {
    if (widget.archiveKeyId == null) {
      showSnackBar('يرجى اختيار فترة أرشيف أولاً!');
      return const SizedBox.shrink();
    }

    // Fetch archive info for the title
    final archiveInfo = await widget.db.fetchAll(
      'SELECT archive_name, start_date, end_date FROM archive_keys WHERE archive_key_id = ?',
      [widget.archiveKeyId],
    );

    if (archiveInfo.isEmpty) {
      showSnackBar('لا توجد بيانات لفترة الأرشيف المحددة!');
      return const SizedBox.shrink();
    }

    final archiveName = archiveInfo[0]['archive_name'] as String;
    final startDate = archiveInfo[0]['start_date'] as String;
    final endDate = archiveInfo[0]['end_date'] as String;
    final titleText = 'تقارير الأرشيف: $archiveName ($startDate إلى $endDate)';

    return Column(
      children: [
        SizedBox(
          height: MediaQuery.of(context).orientation == Orientation.portrait
              ? MediaQuery.of(context).size.height * 0.1 // 10% من ارتفاع الشاشة في portrait
              : MediaQuery.of(context).size.height * 0.05,
        ),
        Text(
          titleText,
          style: titleStyle.copyWith(color: const Color.fromARGB(255, 0, 0, 0)),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 30),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            createButton(
              text: 'تقرير المصروفات',
              onPressed: () => showExpensesReport(context, widget.db, widget.archiveKeyId!),
              bgColor: Colors.blue[700]!,
              textColor: Colors.white,
              width: 200,
              height: 50,
              icon: Icons.receipt,
              iconColor: Colors.white,
            ),
            const SizedBox(width: 10),
            createButton(
              text: 'تقرير المتبقيات',
              onPressed: () => showRemainingReport(context, widget.db, widget.archiveKeyId!),
              bgColor: Colors.green[700]!,
              textColor: Colors.white,
              width: 200,
              height: 50,
              icon: Icons.inventory,
              iconColor: Colors.white,
            ),
          ],
        ),
        const SizedBox(height: 20),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            createButton(
              text: 'تقرير الوجبات',
              onPressed: () => showMealsReport(context, widget.db, widget.archiveKeyId!),
              bgColor: Colors.indigo[700]!,
              textColor: Colors.white,
              width: 200,
              height: 50,
              icon: Icons.restaurant,
              iconColor: Colors.white,
            ),
            const SizedBox(width: 10),
            createButton(
              text: 'تقرير المشروبات',
              onPressed: () => showDrinksReport(context, widget.db, widget.archiveKeyId!),
              bgColor: Colors.teal[700]!,
              textColor: Colors.white,
              width: 200,
              height: 50,
              icon: Icons.local_drink,
              iconColor: Colors.white,
            ),
          ],
        ),
        const SizedBox(height: 20),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            createButton(
              text: 'تقرير استهلاك المشتركين',
              onPressed: () => showConsumptionReport(context, widget.db, widget.archiveKeyId!),
              bgColor: Colors.orange[700]!,
              textColor: Colors.white,
              width: 200,
              height: 50,
              icon: Icons.group,
              iconColor: Colors.white,
            ),
            const SizedBox(width: 10),
            createButton(
              text: 'تقرير استهلاك مشترك',
              onPressed: () => showMemberConsumption(context, widget.db, widget.archiveKeyId!),
              bgColor: Colors.purple[700]!,
              textColor: Colors.white,
              width: 200,
              height: 50,
              icon: Icons.person,
              iconColor: Colors.white,
            ),
          ],
        ),
        const SizedBox(height: 20),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            createButton(
              text: 'رجوع',
              onPressed: navigateToParent,
              bgColor: Colors.red[700]!,
              textColor: Colors.white,
              width: 200,
              height: 50,
              icon: Icons.arrow_back,
              iconColor: Colors.white,
            ),
          ],
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return BackgroundScaffold(
      backgroundImagePath: 'assets/3.jpg',
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Stack(
          children: [
            FutureBuilder<Widget>(
              future: getContent(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                return SingleChildScrollView(
                  child: snapshot.data ?? const SizedBox.shrink(),
                );
              },
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