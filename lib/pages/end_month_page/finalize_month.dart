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

  void showSnackbar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Future<void> startProcess() async {
    debugPrint("Starting finalize month process");
    await showConfirmation();
  }

  Future<void> showConfirmation() async {
    return showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text("تقفيل الشهر"),
          content: const Text("هل أنت متأكد من بدء تقفيل الشهر؟"),
          actions: [
            TextButton(
              child: const Text("لا"),
              onPressed: () => Navigator.of(context).pop(),
            ),
            TextButton(
              child: const Text("نعم"),
              onPressed: () async {
                Navigator.of(context).pop();
                await showConfirmationDistribution();
              },
            ),
          ],
          actionsAlignment: MainAxisAlignment.end,
        );
      },
    );
  }

  Future<void> showConfirmationDistribution() async {
    return showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text("توزيع النثريات"),
          content: const Text("سيتم توزيع النثريات، هل تريد الاستمرار؟"),
          actions: [
            TextButton(
              child: const Text("لا"),
              onPressed: () => Navigator.of(context).pop(),
            ),
            TextButton(
              child: const Text("نعم"),
              onPressed: () async {
                Navigator.of(context).pop();
                await _confirmDistribution();
              },
            ),
          ],
          actionsAlignment: MainAxisAlignment.end,
        );
      },
    );
  }

  Future<void> _confirmDistribution() async {
    try {
      debugPrint("Confirming distribution of miscellaneous expenses");
      final result = await FinalizeMonthData.distributeAndArchiveMiscellaneous(context, db);
      if (result['success'] && result['archive_key_id'] != null) {
        archiveKeyId = result['archive_key_id'];
        showSnackbar("تم توزيع النثريات والأرشفة بنجاح!");
        debugPrint("Distribution successful, archiveKeyId: $archiveKeyId");
        await FinalizeMonthData.runFinalizeProcess(context, db, archiveKeyId!);
        await FinalizeMonthReport.showReport(
          context: context,
          db: db,
          archiveKeyId: archiveKeyId!,
          navigate: navigate,
        );
      } else {
        showSnackbar("فشل توزيع النثريات أو تعذر الحصول على مفتاح الأرشيف.");
        debugPrint("Distribution failed: $result");
      }
    } catch (e) {
      debugPrint("Error in distribution: $e");
      showSnackbar("خطأ أثناء التوزيع: $e");
    }
  }
}