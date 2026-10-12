import 'package:flutter/material.dart';
import 'package:excel/excel.dart';
import 'package:path_provider/path_provider.dart';
import 'package:open_file/open_file.dart';
import 'package:go_router/go_router.dart';
import 'dart:io';
import '../../../utils/database.dart';
import '../../../utils/button_utils.dart';
import '../../../utils/background_scaffold.dart';

class ArchivedRemainingReport extends StatefulWidget {
  final DatabaseManager db;
  final int archiveKeyId;

  const ArchivedRemainingReport({
    Key? key,
    required this.db,
    required this.archiveKeyId,
  }) : super(key: key);

  @override
  _ArchivedRemainingReportState createState() => _ArchivedRemainingReportState();
}

class _ArchivedRemainingReportState extends State<ArchivedRemainingReport> {
  final TextStyle textStyle = const TextStyle(
    fontSize: 15,
    
  );
  final TextStyle titleStyle = const TextStyle(
    fontSize: 28,
    fontWeight: FontWeight.bold,
    
  );

  List<Map<String, dynamic>> remainingItems = [];
  double totalRemaining = 0.0;
  String archiveName = '';
  String startDate = '';
  String endDate = '';

  @override
  void initState() {
    super.initState();
    _fetchRemainingData();
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

  Future<void> _fetchRemainingData() async {
    try {
      // جلب بيانات الأرشيف
      final archiveInfo = await widget.db.fetchAll(
        'SELECT archive_name, start_date, end_date FROM archive_keys WHERE archive_key_id = ?',
        [widget.archiveKeyId],
      );

      if (archiveInfo.isEmpty) {
        showSnackBar('لا توجد بيانات لفترة الأرشيف المحددة!');
        return;
      }

      setState(() {
        archiveName = archiveInfo[0]['archive_name'] as String;
        startDate = archiveInfo[0]['start_date'] as String;
        endDate = archiveInfo[0]['end_date'] as String;
      });

      // جلب المتبقيات
      const query = '''
        SELECT item_name, remaining, price, (price * remaining) as total_price
        FROM expenses_archive
        WHERE archive_key_id = ? AND remaining > 0
      ''';
      final remaining = await widget.db.fetchAll(query, [widget.archiveKeyId]);

      if (remaining.isEmpty) {
        showSnackBar('لا توجد أصناف متبقية لهذه الفترة!');
        return;
      }

      setState(() {
        remainingItems = remaining;
        totalRemaining = remaining.fold(
            0.0, (sum, item) => sum + (item['total_price'] as num).toDouble());
      });
    } catch (e) {
      showSnackBar('خطأ أثناء جلب تقرير المتبقيات: $e');
    }
  }

  Future<void> _exportToExcel() async {
    try {
      if (remainingItems.isEmpty) {
        showSnackBar('لا توجد بيانات لتصديرها');
        return;
      }

      // إنشاء ملف Excel
      final excel = Excel.createExcel();
      final Sheet sheet = excel['تقرير المتبقيات'];

      // معلومات التقرير
      sheet.appendRow([TextCellValue('تقرير المتبقيات')]);
      sheet.appendRow([
        TextCellValue('الفترة'),
        TextCellValue('$startDate إلى $endDate'),
      ]);
      sheet.appendRow([
        TextCellValue('اسم الأرشيف'),
        TextCellValue(archiveName),
      ]);
      sheet.appendRow([]);

      // رأس الجدول
      sheet.appendRow([
        TextCellValue('الصنف'),
        TextCellValue('المتبقي'),
        TextCellValue('سعر الوحدة'),
        TextCellValue('السعر الإجمالي'),
      ]);

      // بيانات المتبقيات
      for (final row in remainingItems) {
        sheet.appendRow([
          TextCellValue(row['item_name'] as String),
          TextCellValue(row['remaining'].toString()),
          TextCellValue(row['price'].toString()),
          TextCellValue(row['total_price'].toString()),
        ]);
      }

      // إجمالي المتبقيات
      sheet.appendRow([]);
      sheet.appendRow([
        TextCellValue('إجمالي المتبقيات'),
        TextCellValue(totalRemaining.toStringAsFixed(2)),
      ]);

      // حفظ الملف
      final directory = await getApplicationDocumentsDirectory();
      final now = DateTime.now().toString().replaceAll(RegExp(r'[:\-\. ]'), '_');
      final filePath = '${directory.path}/تقرير_المتبقيات_أرشيف_${widget.archiveKeyId}_$now.xlsx';
      final file = File(filePath);
      await file.writeAsBytes(excel.encode()!);

      // فتح الملف
      await OpenFile.open(filePath);
      showSnackBar('تم تصدير التقرير إلى: $filePath');
    } catch (e) {
      showSnackBar('خطأ أثناء تصدير التقرير: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return BackgroundScaffold(
      backgroundImagePath: 'assets/3.jpg',
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Stack(
          children: [
            SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  SizedBox(
                    height: MediaQuery.of(context).orientation == Orientation.portrait
                        ? MediaQuery.of(context).size.height * 0.1
                        : MediaQuery.of(context).size.height * 0.05,
                  ),
                  Text(
                    'تقرير المتبقيات: $archiveName ($startDate إلى $endDate)',
                    style: titleStyle.copyWith(color: Colors.black),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 20),
                  if (remainingItems.isNotEmpty)
                    Card(
                      elevation: 4,
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal, // جعل الجدول قابل للتمرير أفقيًا
                        child: DataTable(
                          headingRowColor: WidgetStateProperty.all(Colors.blue),
                          border: TableBorder.all(color: Colors.black),
                          columns: [
                            DataColumn(
                                label: Container(
                                  alignment: Alignment.center,
                                  child: const Text('الصنف',
                                      style: TextStyle(color: Colors.white)),
                                )),
                            DataColumn(
                                label: Container(
                                  alignment: Alignment.center,
                                  child: const Text('المتبقي',
                                      style: TextStyle(color: Colors.white)),
                                )),
                            DataColumn(
                                label: Container(
                                  alignment: Alignment.center,
                                  child: const Text('سعر الوحدة',
                                      style: TextStyle(color: Colors.white)),
                                )),
                            DataColumn(
                                label: Container(
                                  alignment: Alignment.center,
                                  child: const Text('السعر الإجمالي',
                                      style: TextStyle(color: Colors.white)),
                                )),
                          ],
                          rows: remainingItems.map((row) {
                            return DataRow(cells: [
                              DataCell(
                                Container(
                                  alignment: Alignment.center,
                                  constraints:
                                      const BoxConstraints(maxWidth: 150), // تحديد عرض النص
                                  child: Text(
                                    row['item_name'] as String,
                                    style: textStyle,
                                    overflow:
                                        TextOverflow.ellipsis, // التعامل مع النصوص الطويلة
                                  ),
                                ),
                              ),
                              DataCell(
                                Container(
                                  alignment: Alignment.center,
                                  child: Text(row['remaining'].toStringAsFixed(2),
                                      style: textStyle)),
                              ),
                              DataCell(
                                Container(
                                  alignment: Alignment.center,
                                  child: Text(row['price'].toStringAsFixed(2),
                                      style: textStyle)),
                              ),
                              DataCell(
                                Container(
                                  alignment: Alignment.center,
                                  child: Text(row['total_price'].toStringAsFixed(2),
                                      style: textStyle)),
                              ),
                            ]);
                          }).toList(),
                        ),
                      ),
                    ),
                  const SizedBox(height: 20),
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: const [
                        BoxShadow(
                          color: Colors.black12,
                          blurRadius: 6,
                          offset: Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Text(
                      'إجمالي المتبقيات: ${totalRemaining.toStringAsFixed(2)}',
                      style: textStyle.copyWith(color: Colors.black),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(height: 20),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal, // جعل الأزرار قابلة للتمرير أفقيًا
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        createButton(
                          text: 'تصدير إلى Excel',
                          onPressed: _exportToExcel,
                          bgColor: Colors.blue[700]!,
                          textColor: Colors.white,
                          width: MediaQuery.of(context).size.width *
                              0.4, // عرض ديناميكي بناءً على الشاشة
                          height: 50,
                          icon: Icons.download,
                          iconColor: Colors.white,
                        ),
                        const SizedBox(width: 10),
                        createButton(
                          text: 'رجوع',
                          onPressed: () => Navigator.pop(context),
                          bgColor: Colors.red[700]!,
                          textColor: Colors.white,
                          width: MediaQuery.of(context).size.width * 0.4,
                          height: 50,
                          icon: Icons.arrow_back,
                          iconColor: Colors.white,
                        ),
                      ],
                    ),
                  ),
                ],
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