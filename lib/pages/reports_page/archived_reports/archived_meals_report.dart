import 'package:flutter/material.dart';
import 'package:excel/excel.dart';
import 'package:path_provider/path_provider.dart';
import 'package:open_file/open_file.dart';
import 'package:go_router/go_router.dart';
import 'dart:io';
import '../../../utils/database.dart';
import '../../../utils/button_utils.dart';
import '../../../utils/background_scaffold.dart';

class ArchivedMealsReport extends StatefulWidget {
  final DatabaseManager db;
  final int archiveKeyId;

  const ArchivedMealsReport({
    Key? key,
    required this.db,
    required this.archiveKeyId,
  }) : super(key: key);

  @override
  _ArchivedMealsReportState createState() => _ArchivedMealsReportState();
}

class _ArchivedMealsReportState extends State<ArchivedMealsReport> {
  final TextStyle textStyle = const TextStyle(
    fontSize: 15,
    fontFamily: 'DancingScript',
  );
  final TextStyle titleStyle = const TextStyle(
    fontSize: 28,
    fontWeight: FontWeight.bold,
    fontFamily: 'DancingScript',
  );

  List<Map<String, dynamic>> meals = [];
  double totalCost = 0.0;
  int breakfastCount = 0;
  int lunchCount = 0;
  int dinnerCount = 0;
  String archiveName = '';
  String startDate = '';
  String endDate = '';

  @override
  void initState() {
    super.initState();
    _fetchMealsData();
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

  Future<void> _fetchMealsData() async {
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

      // جلب بيانات الوجبات
      const query = '''
        SELECT m.name, mr.meal_type, mr.date, mr.final_cost
        FROM meal_records_archive mr
        JOIN members_archive m ON mr.member_id = m.member_id
        WHERE mr.archive_key_id = ?
      ''';
      final mealsData = await widget.db.fetchAll(query, [widget.archiveKeyId]);

      if (mealsData.isEmpty) {
        showSnackBar('لا توجد بيانات وجبات لهذه الفترة!');
        return;
      }

      // حساب إجمالي عدد الوجبات لكل نوع
      int breakfast = 0;
      int lunch = 0;
      int dinner = 0;
      for (var row in mealsData) {
        final mealType = row['meal_type'] as String;
        if (mealType == 'فطار') {
          breakfast++;
        } else if (mealType == 'غداء') lunch++;
        else if (mealType == 'عشاء') dinner++;
      }

      setState(() {
        meals = mealsData;
        totalCost = meals.fold(
            0.0, (sum, item) => sum + (item['final_cost'] as num).toDouble());
        breakfastCount = breakfast;
        lunchCount = lunch;
        dinnerCount = dinner;
      });
    } catch (e) {
      showSnackBar('خطأ أثناء جلب تقرير الوجبات: $e');
    }
  }

  Future<void> _exportToExcel() async {
    try {
      if (meals.isEmpty) {
        showSnackBar('لا توجد بيانات لتصديرها');
        return;
      }

      // إنشاء ملف Excel
      final excel = Excel.createExcel();
      final Sheet sheet = excel['تقرير الوجبات'];

      // معلومات التقرير
      sheet.appendRow([TextCellValue('تقرير الوجبات')]);
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
        TextCellValue('اسم المشترك'),
        TextCellValue('نوع الوجبة'),
        TextCellValue('التاريخ'),
        TextCellValue('التكلفة'),
      ]);

      // بيانات الوجبات
      for (final row in meals) {
        sheet.appendRow([
          TextCellValue(row['name'] as String),
          TextCellValue(row['meal_type'] as String),
          TextCellValue(row['date'] as String),
          TextCellValue(row['final_cost'].toString()),
        ]);
      }

      // إجمالي التكلفة وإحصائيات الوجبات
      sheet.appendRow([]);
      sheet.appendRow([
        TextCellValue('إجمالي التكلفة'),
        TextCellValue(totalCost.toStringAsFixed(2)),
      ]);
      sheet.appendRow([]);
      sheet.appendRow([
        TextCellValue('إجمالي الفطار'),
        TextCellValue(breakfastCount.toString()),
      ]);
      sheet.appendRow([
        TextCellValue('إجمالي الغداء'),
        TextCellValue(lunchCount.toString()),
      ]);
      sheet.appendRow([
        TextCellValue('إجمالي العشاء'),
        TextCellValue(dinnerCount.toString()),
      ]);

      // حفظ الملف
      final directory = await getApplicationDocumentsDirectory();
      final now = DateTime.now().toString().replaceAll(RegExp(r'[:\-\. ]'), '_');
      final filePath = '${directory.path}/تقرير_الوجبات_أرشيف_${widget.archiveKeyId}_$now.xlsx';
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
                    'تقرير الوجبات: $archiveName ($startDate إلى $endDate)',
                    style: titleStyle.copyWith(color: Colors.black),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 20),
                  if (meals.isNotEmpty)
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
                                  child: const Text('نوع الوجبة',
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
                          rows: meals.map((row) {
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
                                    row['meal_type'] as String,
                                    style: textStyle,
                                    overflow: TextOverflow.ellipsis,
                                  ),
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
                                  child: Text(
                                    (row['final_cost'] as num).truncate() == row['final_cost']
                                        ? row['final_cost'].toStringAsFixed(0)
                                        : row['final_cost'].toStringAsFixed(2),
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
                    child: Column(
                      children: [
                        Text(
                          'إجمالي التكلفة: ${totalCost.toStringAsFixed(2)}',
                          style: textStyle.copyWith(color: Colors.black),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 10),
                        Text(
                          'إجمالي الفطار: $breakfastCount',
                          style: textStyle.copyWith(color: Colors.black),
                          textAlign: TextAlign.center,
                        ),
                        Text(
                          'إجمالي الغداء: $lunchCount',
                          style: textStyle.copyWith(color: Colors.black),
                          textAlign: TextAlign.center,
                        ),
                        Text(
                          'إجمالي العشاء: $dinnerCount',
                          style: textStyle.copyWith(color: Colors.black),
                          textAlign: TextAlign.center,
                        ),
                      ],
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