import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../utils/database.dart';
import '../../../utils/button_utils.dart';
import '../../../utils/background_scaffold.dart';
import '../../../utils/excel_export.dart';

class RemainingReport extends StatefulWidget {
  final DatabaseManager db;

  const RemainingReport({
    Key? key,
    required this.db,
  }) : super(key: key);

  @override
  _RemainingReportState createState() => _RemainingReportState();
}

class _RemainingReportState extends State<RemainingReport> {
  final TextStyle textStyle = const TextStyle(
    fontSize: 15,
    fontFamily: 'Cairo',
  );
  final TextStyle titleStyle = const TextStyle(
    fontSize: 28,
    fontWeight: FontWeight.bold,
    fontFamily: 'Cairo',
  );

  List<Map<String, dynamic>> remaining = [];
  double totalRemaining = 0.0;

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
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }

  Future<void> _fetchRemainingData() async {
    try {
      const query = '''
        SELECT item_name, remaining, price, (price * remaining) as total_price
        FROM expenses
      ''';
      final remainingData = await widget.db.fetchAll(query);

      if (remainingData.isEmpty) {
        showSnackBar('لا توجد بيانات متبقيات لهذا الشهر!');
        return;
      }

      setState(() {
        remaining = remainingData;
        totalRemaining = remaining.fold(
            0.0, (sum, item) => sum + (item['total_price'] as num).toDouble());
      });
    } catch (e) {
      showSnackBar('خطأ أثناء جلب تقرير المتبقيات: $e');
    }
  }

  Future<void> _exportToExcel() async {
    try {
      if (remaining.isEmpty) {
        showSnackBar('لا توجد بيانات لتصديرها');
        return;
      }

      final columns = [
        'الصنف',
        'المتبقي',
        'سعر الوحدة',
        'السعر الإجمالي',
      ];

      final rows = remaining.map((row) => [
            row['item_name'] as String,
            row['remaining'] as num,
            row['price'] as num,
            row['total_price'] as num,
          ]).toList();

      final extraInfo = <String, String>{
        'اسم التقرير': 'تقرير المتبقيات',
        'تاريخ التصدير': DateTime.now().toString(),
      };

      final totals = [
        [
          'الإجمالي',
          '',
          '',
          totalRemaining,
        ],
      ];

      await exportReportToExcel(
        context: context,
        reportTitle: 'تقرير المتبقيات',
        columns: columns,
        rows: rows,
        extraInfo: extraInfo,
        totals: totals,
      );
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
              padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 16.0),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    SizedBox(
                      height: MediaQuery.of(context).orientation == Orientation.portrait
                          ? MediaQuery.of(context).size.height * 0.1
                          : MediaQuery.of(context).size.height * 0.05,
                    ),
                    Text(
                      'تقرير المتبقيات',
                      style: titleStyle.copyWith(color: Colors.black),
                      textAlign: TextAlign.center,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 20),
                    if (remaining.isNotEmpty)
                      Card(
                        elevation: 4,
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: DataTable(
                            headingRowColor: WidgetStateProperty.all(Colors.blue[700]),
                            border: TableBorder.all(color: Colors.black),
                            columnSpacing: 0,
                            columns: [
                              DataColumn(
                                label: Container(
                                  alignment: Alignment.center,
                                  child: Text('الصنف',
                                      style: textStyle.copyWith(color: Colors.white)),
                                ),
                              ),
                              DataColumn(
                                label: Container(
                                  alignment: Alignment.center,
                                  child: Text('المتبقي',
                                      style: textStyle.copyWith(color: Colors.white)),
                                ),
                              ),
                              DataColumn(
                                label: Container(
                                  alignment: Alignment.center,
                                  child: Text('سعر الوحدة',
                                      style: textStyle.copyWith(color: Colors.white)),
                                ),
                              ),
                              DataColumn(
                                label: Container(
                                  alignment: Alignment.center,
                                  child: Text('السعر الإجمالي',
                                      style: textStyle.copyWith(color: Colors.white)),
                                ),
                              ),
                            ],
                            rows: remaining.map((row) {
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
                                      (row['remaining'] as num).truncate() == row['remaining']
                                          ? row['remaining'].toStringAsFixed(0)
                                          : row['remaining'].toStringAsFixed(2),
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
                        'إجمالي المتبقيات: ${totalRemaining.toStringAsFixed(2)}',
                        style: textStyle.copyWith(color: Colors.black),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Wrap(
                      spacing: 10,
                      runSpacing: 20,
                      alignment: WrapAlignment.center,
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
                  ],
                ),
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