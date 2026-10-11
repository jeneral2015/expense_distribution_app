import 'package:flutter/material.dart';
import 'package:excel/excel.dart' as old_excel;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:syncfusion_flutter_xlsio/xlsio.dart' as xlsio;
import 'dart:io';

/// دالة عامة لتصدير بيانات التقرير إلى ملف Excel (تتعامل مع Android و Windows)
Future<void> exportReportToExcel({
  required BuildContext context,
  required String reportTitle,
  required List<String> columns,
  required List<List<dynamic>> rows,
  Map<String, String>? extraInfo, // بيانات إضافية مثل الفترة أو التاريخ
  List<List<dynamic>>? totals, // بيانات الإجماليات
}) async {
  try {
    if (Platform.isWindows) {
      /// ============================
      /// نسخة ويندوز - Syncfusion
      /// ============================
      final workbook = xlsio.Workbook();
      final sheet = workbook.worksheets[0];

      int currentRowIndex = 1;

      // عنوان التقرير
      sheet.getRangeByIndex(currentRowIndex, 1).setText(reportTitle);
      currentRowIndex += 2;

      // بيانات إضافية
      if (extraInfo != null && extraInfo.isNotEmpty) {
        extraInfo.forEach((key, value) {
          sheet.getRangeByIndex(currentRowIndex, 1).setText(key);
          sheet.getRangeByIndex(currentRowIndex, 2).setText(value);
          currentRowIndex++;
        });
        currentRowIndex++;
      }

      // الهيدر
      for (int i = 0; i < columns.length; i++) {
        sheet.getRangeByIndex(currentRowIndex, i + 1).setText(columns[i]);
      }
      currentRowIndex++;

      // الصفوف
      for (final row in rows) {
        for (int c = 0; c < row.length; c++) {
          final cell = sheet.getRangeByIndex(currentRowIndex, c + 1);
          if (row[c] is num) {
            cell.setNumber((row[c] as num).toDouble());
          } else {
            cell.setText(row[c].toString());
          }
        }
        currentRowIndex++;
      }

      // الإجماليات
      if (totals != null && totals.isNotEmpty) {
        currentRowIndex++;
        sheet.getRangeByIndex(currentRowIndex, 1).setText("إجماليات الشهر");
        currentRowIndex++;
        for (final total in totals) {
          for (int c = 0; c < total.length; c++) {
            final cell = sheet.getRangeByIndex(currentRowIndex, c + 1);
            if (total[c] is num) {
              cell.setNumber((total[c] as num).toDouble());
            } else {
              cell.setText(total[c].toString());
            }
          }
          currentRowIndex++;
        }
      }

      // حفظ الملف
      final List<int> bytes = workbook.saveAsStream();
      workbook.dispose();

      final directory = await getApplicationDocumentsDirectory();
      final now =
          DateTime.now().toString().replaceAll(RegExp(r'[:\-\. ]'), '_');
      final filePath = '${directory.path}/${reportTitle}_$now.xlsx';
      final file = File(filePath);
      await file.writeAsBytes(bytes, flush: true);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text("تم إنشاء التقرير بنجاح على ويندوز ✅\n$filePath")),
      );
    } else {
      /// ============================
      /// نسخة Android/iOS - excel
      /// ============================
      final excel = old_excel.Excel.createExcel();

      // إنشاء الشيت
      final sheet = excel['تقرير'];

      // حذف الافتراضي
      if (excel.sheets.containsKey('Sheet1')) {
        excel.delete('Sheet1');
      }

      // الهيدر
      sheet.appendRow(
          columns.map((col) => old_excel.TextCellValue(col)).toList());

      // الصفوف
      for (final row in rows) {
        final formattedRow = row.map((cell) {
          if (cell is num)
            return old_excel.TextCellValue(cell.toStringAsFixed(2));
          return old_excel.TextCellValue(cell?.toString() ?? '');
        }).toList();

        formattedRow.addAll(List.filled(
            columns.length - formattedRow.length, old_excel.TextCellValue('')));

        sheet.appendRow(formattedRow);
      }

      // الإجماليات
      if (totals != null && totals.isNotEmpty) {
        sheet.appendRow(
            List.filled(columns.length, old_excel.TextCellValue('')));
        sheet.appendRow([old_excel.TextCellValue('إجماليات الشهر')]);
        for (final total in totals) {
          final formattedTotal = total.map((cell) {
            if (cell is num)
              return old_excel.TextCellValue(cell.toStringAsFixed(2));
            return old_excel.TextCellValue(cell?.toString() ?? '');
          }).toList();

          formattedTotal.addAll(List.filled(
              columns.length - formattedTotal.length,
              old_excel.TextCellValue('')));
          sheet.appendRow(formattedTotal);
        }
      }

      // حفظ الملف مؤقتًا
      final directory = await getTemporaryDirectory();
      final now =
          DateTime.now().toString().replaceAll(RegExp(r'[:\-\. ]'), '_');
      final filePath = '${directory.path}/${reportTitle}_$now.xlsx';
      final file = File(filePath);
      await file.writeAsBytes(excel.encode()!);

      // مشاركة الملف
      await Share.shareXFiles([XFile(filePath)], text: 'تقرير $reportTitle');

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("تم تصدير التقرير ومشاركته بنجاح ✅")),
      );
    }
  } catch (e) {
    debugPrint("خطأ أثناء تصدير التقرير: $e");
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("خطأ أثناء تصدير التقرير: $e")),
      );
    }
  }
}
