import 'package:flutter/material.dart';
import '../../utils/database.dart';
import 'finalize_month_data.dart';
import 'finalize_month_report.dart';

class FinalizeMonth {
  final BuildContext context;
  final DatabaseManager db;
  final Function(String)? navigate;
  int? archiveKeyId;
  final TextStyle textStyle = const TextStyle(fontSize: 15);
  final TextStyle titleStyle = const TextStyle(fontSize: 28, fontWeight: FontWeight.bold);

  FinalizeMonth(this.context, this.db, {this.navigate});

  void showSnackbar(String message, {bool isError = false}) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red[800] : Colors.green[800],
      ),
    );
  }

  Future<void> startProcess() async {
    debugPrint("Starting finalize month process");
    await showConfirmation();
  }

  Future<void> showConfirmation() async {
    return showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text("تقفيل الشهر"),
          content: const Text(
            "هل أنت متأكد من بدء تقفيل الشهر؟\n\n"
            "سيتم توزيع أي نثريات متبقية، وأرشفة جميع الوجبات والمشروبات والمشتريات، "
            "وتجهيز وتصفير الشهر الجديد تلقائياً.",
          ),
          actions: [
            TextButton(
              child: const Text("إلغاء"),
              onPressed: () => Navigator.of(dialogContext).pop(),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green[700],
                foregroundColor: Colors.white,
              ),
              child: const Text("تأكيد التقفيل"),
              onPressed: () async {
                Navigator.of(dialogContext).pop();
                await _executeFinalize();
              },
            ),
          ],
          actionsAlignment: MainAxisAlignment.end,
        );
      },
    );
  }

  Future<void> _executeFinalize() async {
    // إظهار مؤشر التحميل
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext loadingContext) {
        return PopScope(
          canPop: false,
          child: Center(
            child: Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text(
                      "جاري تقفيل الشهر وأرشفة البيانات...",
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );

    try {
      final result = await FinalizeMonthData.executeFullMonthFinalization(context, db);

      // إغلاق مؤشر التحميل
      if (context.mounted) {
        Navigator.of(context, rootNavigator: true).pop();
      }

      if (result['success'] == true && result['archive_key_id'] != null) {
        archiveKeyId = result['archive_key_id'] as int;
        showSnackbar("تم تقفيل الشهر وأرشفة البيانات بنجاح!");
        debugPrint("Month finalized successfully, archiveKeyId: $archiveKeyId");

        if (context.mounted) {
          await FinalizeMonthReport.showReport(
            context: context,
            db: db,
            archiveKeyId: archiveKeyId!,
            navigate: navigate,
          );
        }
      } else {
        final errorMsg = result['error'] ?? "تعذر إتمام عملية تقفيل الشهر";
        showSnackbar("فشل تقفيل الشهر: $errorMsg", isError: true);
        debugPrint("Month finalization failed: $errorMsg");
      }
    } catch (e) {
      if (context.mounted) {
        Navigator.of(context, rootNavigator: true).pop();
      }
      debugPrint("Error in finalize process: $e");
      showSnackbar("حدث خطأ أثناء تقفيل الشهر: $e", isError: true);
    }
  }
}