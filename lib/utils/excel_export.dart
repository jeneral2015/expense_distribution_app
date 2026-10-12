import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_xlsio/xlsio.dart' as xlsio;
import 'package:share_plus/share_plus.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io' as io;

/// دالة عامة لتصدير بيانات التقرير إلى ملف Excel (تتعامل مع جميع المنصات)
Future<void> exportReportToExcel({
  required BuildContext context,
  required String reportTitle,
  required List<String> columns,
  required List<List<dynamic>> rows,
  Map<String, String>? extraInfo, // بيانات إضافية مثل الفترة أو التاريخ
  List<List<dynamic>>? totals, // بيانات الإجماليات
}) async {
  try {
    final workbook = xlsio.Workbook();
    final sheet = workbook.worksheets[0];
    
    sheet.name = 'التقرير';
    sheet.isRightToLeft = true; // تعيين الاتجاه لليمين (RTL)

    int currentRowIndex = 1;

    // تنسيق العنوان
    final xlsio.Style titleStyle = workbook.styles.add('TitleStyle');
    titleStyle.bold = true;
    titleStyle.fontSize = 16;
    titleStyle.hAlign = xlsio.HAlignType.center;

    final xlsio.Style headerStyle = workbook.styles.add('HeaderStyle');
    headerStyle.bold = true;
    headerStyle.backColor = '#E0E0E0';
    headerStyle.hAlign = xlsio.HAlignType.center;

    // عنوان التقرير
    final titleRange = sheet.getRangeByIndex(currentRowIndex, 1, currentRowIndex, columns.length);
    titleRange.merge();
    titleRange.setText(reportTitle);
    titleRange.cellStyle = titleStyle;
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
      final cell = sheet.getRangeByIndex(currentRowIndex, i + 1);
      cell.setText(columns[i]);
      cell.cellStyle = headerStyle;
    }
    currentRowIndex++;

    // الصفوف
    for (final row in rows) {
      for (int c = 0; c < row.length; c++) {
        final cell = sheet.getRangeByIndex(currentRowIndex, c + 1);
        if (row[c] is num) {
          cell.setNumber((row[c] as num).toDouble());
        } else {
          cell.setText(row[c]?.toString() ?? '');
        }
      }
      currentRowIndex++;
    }

    // الإجماليات
    if (totals != null && totals.isNotEmpty) {
      currentRowIndex++;
      final totalTitle = sheet.getRangeByIndex(currentRowIndex, 1, currentRowIndex, columns.length);
      totalTitle.merge();
      totalTitle.setText("إجماليات الشهر");
      totalTitle.cellStyle = headerStyle;
      
      currentRowIndex++;
      for (final total in totals) {
        for (int c = 0; c < total.length; c++) {
          final cell = sheet.getRangeByIndex(currentRowIndex, c + 1);
          if (total[c] is num) {
            cell.setNumber((total[c] as num).toDouble());
          } else {
            cell.setText(total[c]?.toString() ?? '');
          }
        }
        currentRowIndex++;
      }
    }

    // تعديل حجم الأعمدة لتتناسب مع المحتوى (Auto-fit)
    for (int i = 1; i <= columns.length; i++) {
      sheet.autoFitColumn(i);
    }

    // حفظ الملف
    final List<int> bytes = workbook.saveAsStream();
    workbook.dispose();

    final now = DateTime.now().toString().replaceAll(RegExp(r'[:\-\. ]'), '_');
    final fileName = '${reportTitle}_$now.xlsx';

    // استخدام طريقة الحفظ أو المشاركة حسب المنصة
    if (kIsWeb) {
      await Share.shareXFiles(
        [XFile.fromData(Uint8List.fromList(bytes), name: fileName, mimeType: 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet')], 
        text: 'تقرير $reportTitle'
      );
    } else if (defaultTargetPlatform == TargetPlatform.windows) {
      String? outputPath = await FilePicker.platform.saveFile(
        dialogTitle: 'حفظ تقرير Excel',
        fileName: fileName,
        allowedExtensions: ['xlsx'],
        type: FileType.custom,
      );
      if (outputPath != null) {
        if (!outputPath.toLowerCase().endsWith('.xlsx')) {
          outputPath += '.xlsx';
        }
        final file = io.File(outputPath);
        await file.writeAsBytes(bytes, flush: true);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("تم حفظ التقرير بنجاح على ويندوز ✅\n$outputPath")),
          );
        }
      }
    } else {
      // Android / iOS
      final directory = await io.Directory.systemTemp.createTemp();
      final filePath = '${directory.path}/$fileName';
      final file = io.File(filePath);
      await file.writeAsBytes(bytes, flush: true);
      await Share.shareXFiles([XFile(filePath)], text: 'تقرير $reportTitle');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("تم تصدير التقرير ومشاركته بنجاح ✅")),
        );
      }
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
