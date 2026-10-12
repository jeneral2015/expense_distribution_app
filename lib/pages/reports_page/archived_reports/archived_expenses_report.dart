import 'package:flutter/material.dart';
import 'package:excel/excel.dart';
import 'package:path_provider/path_provider.dart';
import 'package:open_file/open_file.dart';
import 'package:go_router/go_router.dart';
import 'dart:io';
import '../../../utils/database.dart';
import '../../../utils/button_utils.dart';
import '../../../utils/background_scaffold.dart';

class ArchivedExpensesReport extends StatefulWidget {
  final DatabaseManager db;
  final int archiveKeyId;

  const ArchivedExpensesReport({
    Key? key,
    required this.db,
    required this.archiveKeyId,
  }) : super(key: key);

  @override
  _ArchivedExpensesReportState createState() => _ArchivedExpensesReportState();
}

class _ArchivedExpensesReportState extends State<ArchivedExpensesReport> {
  final TextStyle textStyle = const TextStyle(
    fontSize: 15,
    
  );
  final TextStyle titleStyle = const TextStyle(
    fontSize: 28,
    fontWeight: FontWeight.bold,
    
  );

  List<Map<String, dynamic>> expenses = [];
  double totalExpenses = 0.0;
  String archiveName = '';
  String startDate = '';
  String endDate = '';

  @override
  void initState() {
    super.initState();
    _fetchExpensesData();
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

  Future<void> _fetchExpensesData() async {
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

      // جلب المصروفات
      const query = '''
        SELECT item_name, quantity, price, (price * quantity) as total_price
        FROM expenses_archive
        WHERE archive_key_id = ?
      ''';
      final expensesData = await widget.db.fetchAll(query, [widget.archiveKeyId]);

      if (expensesData.isEmpty) {
        showSnackBar('لا توجد مصروفات لهذه الفترة!');
        return;
      }

      setState(() {
        expenses = expensesData;
        totalExpenses = expenses.fold(
            0.0, (sum, item) => sum + (item['total_price'] as num).toDouble());
      });
    } catch (e) {
      showSnackBar('خطأ أثناء جلب تقرير المصروفات: $e');
    }
  }

  Future<void> _exportToExcel() async {
    try {
      if (expenses.isEmpty) {
        showSnackBar('لا توجد بيانات لتصديرها');
        return;
      }

      // إنشاء ملف Excel
      final excel = Excel.createExcel();
      final Sheet sheet = excel['تقرير المصروفات'];

      // معلومات التقرير
      sheet.appendRow([TextCellValue('تقرير المصروفات')]);
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
        TextCellValue('اسم الصنف'),
        TextCellValue('الكمية'),
        TextCellValue('سعر الوحدة'),
        TextCellValue('السعر الكامل'),
      ]);

      // بيانات المصروفات
      for (final row in expenses) {
        sheet.appendRow([
          TextCellValue(row['item_name'] as String),
          TextCellValue(
            (row['quantity'] as num).truncate() == row['quantity']
                ? row['quantity'].toStringAsFixed(0)
                : row['quantity'].toStringAsFixed(2),
          ),
          TextCellValue(
            (row['price'] as num).truncate() == row['price']
                ? row['price'].toStringAsFixed(0)
                : row['price'].toStringAsFixed(2),
          ),
          TextCellValue(
            (row['total_price'] as num).truncate() == row['total_price']
                ? row['total_price'].toStringAsFixed(0)
                : row['total_price'].toStringAsFixed(2),
          ),
        ]);
      }

      // إجمالي المصروفات
      sheet.appendRow([]);
      sheet.appendRow([
        TextCellValue('إجمالي المصروفات'),
        TextCellValue(
          totalExpenses.truncate() == totalExpenses
              ? totalExpenses.toStringAsFixed(0)
              : totalExpenses.toStringAsFixed(2),
        ),
      ]);

      // حفظ الملف
      final directory = await getApplicationDocumentsDirectory();
      final now = DateTime.now().toString().replaceAll(RegExp(r'[:\-\. ]'), '_');
      final filePath = '${directory.path}/تقرير_المصروفات_أرشيف_${widget.archiveKeyId}_$now.xlsx';
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
                    'تقرير المصروفات: $archiveName ($startDate إلى $endDate)',
                    style: titleStyle.copyWith(color: Colors.black),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 20),
                  if (expenses.isNotEmpty)
                    Card(
                      elevation: 4,
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: DataTable(
                          headingRowColor: WidgetStateProperty.all(Colors.blue),
                          border: TableBorder.all(color: Colors.black),
                          columns: [
                            DataColumn(
                                label: Container(
                                  alignment: Alignment.center,
                                  child: const Text('اسم الصنف',
                                      style: TextStyle(color: Colors.white)),
                                )),
                            DataColumn(
                                label: Container(
                                  alignment: Alignment.center,
                                  child: const Text('الكمية',
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
                                  child: const Text('السعر الكامل',
                                      style: TextStyle(color: Colors.white)),
                                )),
                          ],
                          rows: expenses.map((row) {
                            return DataRow(cells: [
                              DataCell(
                                Container(
                                  alignment: Alignment.center,
                                  constraints: const BoxConstraints(maxWidth: 150),
                                  child: Text(
                                    row['item_name'] as String,
                                    style: textStyle,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ),
                              DataCell(
                                Container(
                                  alignment: Alignment.center,
                                  child: Text(
                                    (row['quantity'] as num).truncate() == row['quantity']
                                        ? row['quantity'].toStringAsFixed(0)
                                        : row['quantity'].toStringAsFixed(2),
                                    style: textStyle,
                                  ),
                                ),
                              ),
                              DataCell(
                                Container(
                                  alignment: Alignment.center,
                                  child: Text(
                                    (row['price'] as num).truncate() == row['price']
                                        ? row['price'].toStringAsFixed(0)
                                        : row['price'].toStringAsFixed(2),
                                    style: textStyle,
                                  ),
                                ),
                              ),
                              DataCell(
                                Container(
                                  alignment: Alignment.center,
                                  child: Text(
                                    (row['total_price'] as num).truncate() == row['total_price']
                                        ? row['total_price'].toStringAsFixed(0)
                                        : row['total_price'].toStringAsFixed(2),
                                    style: textStyle,
                                  ),
                                ),
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
                      'إجمالي المصروفات: ${totalExpenses.truncate() == totalExpenses ? totalExpenses.toStringAsFixed(0) : totalExpenses.toStringAsFixed(2)}',
                      style: textStyle.copyWith(color: Colors.black),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(height: 20),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        createButton(
                          text: 'تصدير إلى Excel',
                          onPressed: _exportToExcel,
                          bgColor: Colors.blue[700]!,
                          textColor: Colors.white,
                          width: MediaQuery.of(context).size.width * 0.4,
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
