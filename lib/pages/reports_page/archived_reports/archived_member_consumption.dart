import 'package:flutter/material.dart';
import 'package:excel/excel.dart';
import 'package:path_provider/path_provider.dart';
import 'package:open_file/open_file.dart';
import 'package:go_router/go_router.dart';
import 'dart:io';
import '../../../utils/database.dart';
import '../../../utils/button_utils.dart';
import '../../../utils/background_scaffold.dart';

class ArchivedMemberConsumption extends StatefulWidget {
  final DatabaseManager db;
  final int archiveKeyId;

  const ArchivedMemberConsumption({
    Key? key,
    required this.db,
    required this.archiveKeyId,
  }) : super(key: key);

  @override
  _ArchivedMemberConsumptionState createState() => _ArchivedMemberConsumptionState();
}

class _ArchivedMemberConsumptionState extends State<ArchivedMemberConsumption> {
  final TextStyle textStyle = const TextStyle(
    fontSize: 15,
    
  );
  final TextStyle titleStyle = const TextStyle(
    fontSize: 28,
    fontWeight: FontWeight.bold,
    
  );

  List<Map<String, dynamic>> subscribers = [];
  String? selectedSubscriberId;
  List<Map<String, dynamic>> consumption = [];
  double totalCost = 0.0;
  String archiveName = '';
  String startDate = '';
  String endDate = '';

  @override
  void initState() {
    super.initState();
    _fetchSubscribers();
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

  Future<void> _fetchSubscribers() async {
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

      // جلب المشتركين
      final subscribersData = await widget.db.fetchAll(
        'SELECT member_id, name FROM members_archive WHERE archive_key_id = ?',
        [widget.archiveKeyId],
      );

      setState(() {
        archiveName = archiveInfo[0]['archive_name'] as String;
        startDate = archiveInfo[0]['start_date'] as String;
        endDate = archiveInfo[0]['end_date'] as String;
        subscribers = subscribersData;
      });
    } catch (e) {
      showSnackBar('خطأ أثناء جلب بيانات المشتركين: $e');
    }
  }

  Future<void> _fetchConsumptionData(String subscriberId) async {
    try {
      const query = '''
        SELECT m.name, 
               COALESCE(mr.meal_type, 'غير محدد') as item, 
               COALESCE(mr.final_cost, 0) as cost, 
               mr.date
        FROM meal_records_archive mr
        JOIN members_archive m ON mr.member_id = m.member_id
        WHERE mr.member_id = ? AND mr.archive_key_id = ?
        UNION ALL
        SELECT m.name, 
               dr.drink_name as item, 
               dr.total_cost as cost, 
               dr.date
        FROM drink_records_archive dr
        JOIN members_archive m ON dr.member_id = m.member_id
        WHERE dr.member_id = ? AND dr.archive_key_id = ?
        UNION ALL
        SELECT m.name, 
               'نثريات' as item, 
               mc.misc_amount as cost, 
               mc.distribution_date as date
        FROM miscellaneous_contributions_archive mc
        JOIN members_archive m ON mc.member_id = m.member_id
        WHERE mc.member_id = ? AND mc.archive_key_id = ?
      ''';
      final consumptionData = await widget.db.fetchAll(
        query,
        [
          subscriberId,
          widget.archiveKeyId,
          subscriberId,
          widget.archiveKeyId,
          subscriberId,
          widget.archiveKeyId,
        ],
      );

      if (consumptionData.isEmpty) {
        showSnackBar('لا توجد بيانات لهذا المشترك في هذه الفترة!');
        return;
      }

      setState(() {
        consumption = consumptionData;
        totalCost = consumption.fold(
            0.0, (sum, item) => sum + (item['cost'] as num).toDouble());
      });
    } catch (e) {
      showSnackBar('خطأ أثناء جلب تقرير المشترك: $e');
    }
  }

  Future<void> _exportToExcel() async {
    try {
      if (consumption.isEmpty) {
        showSnackBar('لا توجد بيانات لتصديرها');
        return;
      }

      // إنشاء ملف Excel
      final excel = Excel.createExcel();
      final Sheet sheet = excel['تقرير استهلاك مشترك'];

      // معلومات التقرير
      sheet.appendRow([TextCellValue('تقرير استهلاك مشترك')]);
      sheet.appendRow([
        TextCellValue('الفترة'),
        TextCellValue('$startDate إلى $endDate'),
      ]);
      sheet.appendRow([
        TextCellValue('اسم الأرشيف'),
        TextCellValue(archiveName),
      ]);
      sheet.appendRow([
        TextCellValue('اسم المشترك'),
        TextCellValue(consumption.isNotEmpty ? consumption[0]['name'] as String : ''),
      ]);
      sheet.appendRow([]);

      // رأس الجدول
      sheet.appendRow([
        TextCellValue('اسم المشترك'),
        TextCellValue('البند'),
        TextCellValue('التكلفة'),
        TextCellValue('التاريخ'),
      ]);

      // بيانات الاستهلاك
      for (final row in consumption) {
        sheet.appendRow([
          TextCellValue(row['name'] as String),
          TextCellValue(row['item'] as String),
          TextCellValue(row['cost'].toString()),
          TextCellValue(row['date'] as String? ?? ''),
        ]);
      }

      // إجمالي التكلفة
      sheet.appendRow([]);
      sheet.appendRow([
        TextCellValue('إجمالي التكلفة'),
        TextCellValue(totalCost.toStringAsFixed(2)),
      ]);

      // حفظ الملف
      final directory = await getApplicationDocumentsDirectory();
      final now = DateTime.now().toString().replaceAll(RegExp(r'[:\-\. ]'), '_');
      final filePath =
          '${directory.path}/تقرير_استهلاك_مشترك_${selectedSubscriberId ?? ''}_أرشيف_${widget.archiveKeyId}_$now.xlsx';
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
                    'تقرير استهلاك مشترك: $archiveName ($startDate إلى $endDate)',
                    style: titleStyle.copyWith(color: Colors.black),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 20),
                  DropdownButton<String>(
                    hint: const Text('اختر المشترك'),
                    value: selectedSubscriberId,
                    items: subscribers.map((subscriber) {
                      return DropdownMenuItem<String>(
                        value: subscriber['member_id'].toString(),
                        child: Text(
                          subscriber['name'] as String,
                          style: textStyle,
                          overflow: TextOverflow.ellipsis,
                        ),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setState(() {
                        selectedSubscriberId = value;
                        consumption = [];
                        totalCost = 0.0;
                      });
                      if (value != null) {
                        _fetchConsumptionData(value);
                      }
                    },
                    style: textStyle.copyWith(color: Colors.black),
                    dropdownColor: Colors.white,
                    isExpanded: true,
                    underline: Container(
                      height: 2,
                      color: Colors.blue[700],
                    ),
                  ),
                  const SizedBox(height: 20),
                  if (consumption.isNotEmpty)
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
                                  child: const Text('البند',
                                      style: TextStyle(color: Colors.white)),
                                )),
                            DataColumn(
                                label: Container(
                                  alignment: Alignment.center,
                                  child: const Text('التكلفة',
                                      style: TextStyle(color: Colors.white)),
                                )),
                            DataColumn(
                                label: Container(
                                  alignment: Alignment.center,
                                  child: const Text('التاريخ',
                                      style: TextStyle(color: Colors.white)),
                                )),
                          ],
                          rows: consumption.asMap().entries.map((entry) {
                            final i = entry.key;
                            final row = entry.value;
                            return DataRow(
                              color: WidgetStateProperty.all(
                                  i % 2 == 0 ? Colors.grey[100] : Colors.white),
                              cells: [
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
                                      row['item'] as String,
                                      style: textStyle,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ),
                                DataCell(
                                  Container(
                                    alignment: Alignment.center,
                                    child: Text(row['cost'].toStringAsFixed(2), style: textStyle),
                                  ),
                                ),
                                DataCell(
                                  Container(
                                    alignment: Alignment.center,
                                    child: Text(row['date'] as String? ?? '', style: textStyle),
                                  ),
                                ),
                              ],
                            );
                          }).toList(),
                        ),
                      ),
                    ),
                  if (consumption.isNotEmpty) const SizedBox(height: 20),
                  if (consumption.isNotEmpty)
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
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        createButton(
                          text: consumption.isEmpty ? 'عرض التقرير' : 'تصدير إلى Excel',
                          onPressed: consumption.isEmpty
                              ? () {
                                  if (selectedSubscriberId == null) {
                                    showSnackBar('يرجى اختيار مشترك');
                                  } else {
                                    _fetchConsumptionData(selectedSubscriberId!);
                                  }
                                }
                              : _exportToExcel,
                          bgColor: consumption.isEmpty ? Colors.green[700]! : Colors.blue[700]!,
                          textColor: Colors.white,
                          width: MediaQuery.of(context).size.width * 0.4,
                          height: 50,
                          icon: consumption.isEmpty ? Icons.visibility : Icons.download,
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
