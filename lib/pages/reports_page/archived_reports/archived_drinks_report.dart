import 'package:flutter/material.dart';
import 'package:excel/excel.dart';
import 'package:path_provider/path_provider.dart';
import 'package:open_file/open_file.dart';
import 'package:go_router/go_router.dart';
import 'dart:io';
import '../../../utils/database.dart';
import '../../../utils/button_utils.dart';
import '../../../utils/background_scaffold.dart';

class ArchivedDrinksReport extends StatefulWidget {
  final DatabaseManager db;
  final int archiveKeyId;

  const ArchivedDrinksReport({
    Key? key,
    required this.db,
    required this.archiveKeyId,
  }) : super(key: key);

  @override
  _ArchivedDrinksReportState createState() => _ArchivedDrinksReportState();
}

class _ArchivedDrinksReportState extends State<ArchivedDrinksReport> {
  final TextStyle textStyle = const TextStyle(
    fontSize: 15,
    
  );
  final TextStyle titleStyle = const TextStyle(
    fontSize: 28,
    fontWeight: FontWeight.bold,
    
  );

  List<Map<String, dynamic>> drinks = [];
  List<Map<String, dynamic>> drinkQuantities = [];
  double totalCost = 0.0;
  String archiveName = '';
  String startDate = '';
  String endDate = '';

  @override
  void initState() {
    super.initState();
    _fetchDrinksData();
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

  Future<void> _fetchDrinksData() async {
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

      // جلب بيانات المشروبات
      const query = '''
        SELECT m.name, dr.drink_name, dr.quantity, dr.date, dr.total_cost
        FROM drink_records_archive dr
        JOIN members_archive m ON dr.member_id = m.member_id
        WHERE dr.archive_key_id = ?
      ''';
      final drinksData = await widget.db.fetchAll(query, [widget.archiveKeyId]);

      if (drinksData.isEmpty) {
        showSnackBar('لا توجد بيانات مشروبات لهذه الفترة!');
        return;
      }

      // حساب إجمالي الكمية لكل مشروب
      final Map<String, num> quantities = {};
      for (var row in drinksData) {
        final drinkName = row['drink_name'] as String;
        final quantity = row['quantity'] as num;
        quantities[drinkName] = (quantities[drinkName] ?? 0) + quantity;
      }

      setState(() {
        drinks = drinksData;
        totalCost = drinks.fold(
            0.0, (sum, item) => sum + (item['total_cost'] as num).toDouble());
        drinkQuantities = quantities.entries
            .map((e) => {'drink_name': e.key, 'quantity': e.value})
            .toList();
      });
    } catch (e) {
      showSnackBar('خطأ أثناء جلب تقرير المشروبات: $e');
    }
  }

  Future<void> _exportToExcel() async {
    try {
      if (drinks.isEmpty) {
        showSnackBar('لا توجد بيانات لتصديرها');
        return;
      }

      // إنشاء ملف Excel
      final excel = Excel.createExcel();
      final Sheet mainSheet = excel['تقرير المشروبات'];
      final Sheet quantitiesSheet = excel['إجمالي الكمية لكل مشروب'];

      // معلومات التقرير (الجدول الرئيسي)
      mainSheet.appendRow([TextCellValue('تقرير المشروبات')]);
      mainSheet.appendRow([
        TextCellValue('الفترة'),
        TextCellValue('$startDate إلى $endDate'),
      ]);
      mainSheet.appendRow([
        TextCellValue('اسم الأرشيف'),
        TextCellValue(archiveName),
      ]);
      mainSheet.appendRow([]);

      // رأس الجدول الرئيسي
      mainSheet.appendRow([
        TextCellValue('اسم المشترك'),
        TextCellValue('اسم المشروب'),
        TextCellValue('الكمية'),
        TextCellValue('التاريخ'),
        TextCellValue('التكلفة'),
      ]);

      // بيانات المشروبات
      for (final row in drinks) {
        mainSheet.appendRow([
          TextCellValue(row['name'] as String),
          TextCellValue(row['drink_name'] as String),
          TextCellValue(
            (row['quantity'] as num).truncate() == row['quantity']
                ? row['quantity'].toStringAsFixed(0)
                : row['quantity'].toStringAsFixed(2),
          ),
          TextCellValue(row['date'] as String),
          TextCellValue(
            (row['total_cost'] as num).truncate() == row['total_cost']
                ? row['total_cost'].toStringAsFixed(0)
                : row['total_cost'].toStringAsFixed(2),
          ),
        ]);
      }

      // إجمالي التكلفة
      mainSheet.appendRow([]);
      mainSheet.appendRow([
        TextCellValue('إجمالي التكلفة'),
        TextCellValue(
          totalCost.truncate() == totalCost
              ? totalCost.toStringAsFixed(0)
              : totalCost.toStringAsFixed(2),
        ),
      ]);

      // جدول إجمالي الكمية لكل مشروب
      quantitiesSheet.appendRow([TextCellValue('إجمالي الكمية لكل مشروب')]);
      quantitiesSheet.appendRow([]);
      quantitiesSheet.appendRow([
        TextCellValue('اسم المشروب'),
        TextCellValue('إجمالي الكمية'),
      ]);

      for (final row in drinkQuantities) {
        quantitiesSheet.appendRow([
          TextCellValue(row['drink_name'] as String),
          TextCellValue(
            (row['quantity'] as num).truncate() == row['quantity']
                ? row['quantity'].toStringAsFixed(0)
                : row['quantity'].toStringAsFixed(2),
          ),
        ]);
      }

      // حفظ الملف
      final directory = await getApplicationDocumentsDirectory();
      final now = DateTime.now().toString().replaceAll(RegExp(r'[:\-\. ]'), '_');
      final filePath = '${directory.path}/تقرير_المشروبات_أرشيف_${widget.archiveKeyId}_$now.xlsx';
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
                    'تقرير المشروبات: $archiveName ($startDate إلى $endDate)',
                    style: titleStyle.copyWith(color: Colors.black),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 20),
                  if (drinks.isNotEmpty)
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
                                  child: const Text('اسم المشترك',
                                      style: TextStyle(color: Colors.white)),
                                )),
                            DataColumn(
                                label: Container(
                                  alignment: Alignment.center,
                                  child: const Text('اسم المشروب',
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
                                  child: const Text('التاريخ',
                                      style: TextStyle(color: Colors.white)),
                                )),
                            DataColumn(
                                label: Container(
                                  alignment: Alignment.center,
                                  child: const Text('التكلفة',
                                      style: TextStyle(color: Colors.white)),
                                )),
                          ],
                          rows: drinks.map((row) {
                            return DataRow(cells: [
                              DataCell(
                                Container(
                                  alignment: Alignment.center,
                                  constraints: const BoxConstraints(maxWidth: 150),
                                  child: Text(
                                    row['name'] as String,
                                    style: textStyle,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ),
                              DataCell(
                                Container(
                                  alignment: Alignment.center,
                                  constraints: const BoxConstraints(maxWidth: 150),
                                  child: Text(
                                    row['drink_name'] as String,
                                    style: textStyle,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ),
                              DataCell(
                                Container(
                                  alignment: Alignment.center,
                                  child: Text(row['quantity'].toStringAsFixed(2),
                                      style: textStyle),
                                ),
                              ),
                              DataCell(
                                Container(
                                  alignment: Alignment.center,
                                  child: Text(row['date'] as String, style: textStyle),
                                ),
                              ),
                              DataCell(
                                Container(
                                  alignment: Alignment.center,
                                  child: Text(row['total_cost'].toStringAsFixed(2),
                                      style: textStyle),
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
                      'إجمالي التكلفة: ${totalCost.toStringAsFixed(2)}',
                      style: textStyle.copyWith(color: Colors.black),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(height: 20),
                  if (drinkQuantities.isNotEmpty)
                    Column(
                      children: [
                        Text(
                          'إحصائية إجمالي الكمية لكل مشروب',
                          style: textStyle.copyWith(color: Colors.black),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 10),
                        Card(
                          elevation: 4,
                          child: SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: DataTable(
                              headingRowColor: WidgetStateProperty.all(Colors.blue),
                              border: TableBorder.all(color: Colors.black),
                              columns: const [
                                DataColumn(
                                    label: Text('اسم المشروب',
                                        style: TextStyle(color: Colors.white))),
                                DataColumn(
                                    label: Text('إجمالي الكمية',
                                        style: TextStyle(color: Colors.white))),
                              ],
                              rows: drinkQuantities.map((row) {
                                return DataRow(cells: [
                                  DataCell(
                                    Container(
                                      constraints:
                                          const BoxConstraints(maxWidth: 150),
                                      child: Text(
                                        row['drink_name'] as String,
                                        style: textStyle,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ),
                                  DataCell(
                                      Text(row['quantity'].toString(),
                                          style: textStyle)),
                                ]);
                              }).toList(),
                            ),
                          ),
                        ),
                      ],
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
