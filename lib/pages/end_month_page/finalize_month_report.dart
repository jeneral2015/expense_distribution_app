import 'package:flutter/material.dart';
import '../../utils/database.dart';
import '../../utils/background_scaffold.dart';
import '../../utils/button_utils.dart';
import '../../utils/excel_export.dart';
import 'finalize_month_data.dart';
import 'finalize_month_ui.dart';
import 'package:go_router/go_router.dart';

class FinalizeMonthReport {
  static Future<void> showReport({
    required BuildContext context,
    required DatabaseManager db,
    required int archiveKeyId,
    Function(String)? navigate,
  }) async {
    try {
      debugPrint("Showing report for archiveKeyId: $archiveKeyId");

      final closureId = await FinalizeMonthData.getClosureIdForArchiveKey(db, archiveKeyId);
      if (closureId == null) {
        debugPrint("No closure_id found for archiveKeyId: $archiveKeyId");
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("خطأ: لا يوجد تقفيل مرتبط بمفتاح الأرشيف")),
        );
        return;
      }
      debugPrint("Found closure_id: $closureId");

      final reportData = await FinalizeMonthData.fetchReportData(db, closureId);
      if (reportData == null) {
        debugPrint("Failed to fetch report data for closure_id: $closureId");
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("خطأ: فشل في جلب بيانات التقرير")),
        );
        return;
      }
      debugPrint("Fetched report data: $reportData");

      if (!context.mounted) {
        debugPrint("Context is not mounted, cannot navigate to report");
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("خطأ: لا يمكن عرض التقرير بسبب مشكلة في الواجهة")),
        );
        return;
      }

      // تحضير البيانات للتصدير
      final columns = [
        'الاسم',
        'الوجبات',
        'المشروبات',
        'النثريات',
        'الاستهلاك',
        'المساهمة',
        'المتبقي',
      ];
      final rows = (reportData['summaryData'] as List<dynamic>).map((row) => [
            row['name'],
            row['total_meals'],
            row['total_drinks'],
            row['total_miscellaneous'],
            row['total_consumption'],
            row['total_contribution'],
            row['remaining_cash'],
          ]).toList();
      final extraInfo = {
        'الفترة': "${reportData['periodData']['start_date']} إلى ${reportData['periodData']['end_date']}",
        'تاريخ التقفيل': "${reportData['periodData']['closure_date']}",
      };
      final totals = [
        ['إجمالي الوجبات', reportData['totalMeals']],
        ['إجمالي المشروبات', reportData['totalDrinks']],
        ['إجمالي النثريات', reportData['totalMisc']],
        ['إجمالي الاستهلاك', reportData['totalConsumption']],
        ['إجمالي المتبقيات', reportData['totalRemainingItems']],
        ['إجمالي المساهمات', reportData['totalContributions']],
        ['النقدي المتبقي', reportData['totalRemainingCash']],
      ];

      Navigator.of(context, rootNavigator: true).push(
        MaterialPageRoute(
          builder: (context) => BackgroundScaffold(
            backgroundImagePath: 'assets/3.jpg',
            child: Scaffold(
              backgroundColor: Colors.transparent,
              appBar: AppBar(
                title: const Text("تقرير تقفيل الشهر"),
                backgroundColor: Colors.green[700],
                foregroundColor: Colors.white,
                leading: createHomeButton(
                  onPressed: () => context.go('/main'),
                ),
              ),
              body: Column(
                children: [
                  Expanded(
                    child: FinalizeMonthUI.buildReportView(
                      reportData,
                      const TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.all(10),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        createButton(
                          text: '📥 تصدير إلى Excel',
                          onPressed: () => exportReportToExcel(
                            context: context,
                            reportTitle: 'تقرير تقفيل الشهر',
                            columns: columns,
                            rows: rows,
                            extraInfo: extraInfo,
                            totals: totals,
                          ),
                          bgColor: Colors.blue[700]!,
                          textColor: Colors.white,
                          width: 150.0,
                          height: 50.0,
                          icon: Icons.download,
                          iconColor: Colors.white,
                        ),
                        createButton(
                          text: '❌ إغلاق',
                          onPressed: () => Navigator.of(context).pop(),
                          bgColor: Colors.red[700]!,
                          textColor: Colors.white,
                          width: 150.0,
                          height: 50.0,
                          icon: Icons.close,
                          iconColor: Colors.white,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      debugPrint("Navigated to report view");

      if (navigate != null) {
        navigate("end_month_page");
      }
    } catch (e) {
      debugPrint("Error showing report: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("خطأ أثناء عرض التقرير: $e")),
      );
    }
  }
}