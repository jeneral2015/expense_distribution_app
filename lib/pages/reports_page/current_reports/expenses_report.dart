import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../utils/database.dart';
import '../../../utils/button_utils.dart';
import '../../../utils/background_scaffold.dart';
import '../../../utils/excel_export.dart';

class ExpensesReport extends StatefulWidget {
  final DatabaseManager db;

  const ExpensesReport({
    Key? key,
    required this.db,
  }) : super(key: key);

  @override
  _ExpensesReportState createState() => _ExpensesReportState();
}

class _ExpensesReportState extends State<ExpensesReport> {
  final TextStyle textStyle = const TextStyle(
    fontSize: 15,
    fontFamily: 'Cairo',
  );
  final TextStyle titleStyle = const TextStyle(
    fontSize: 28,
    fontWeight: FontWeight.bold,
    fontFamily: 'Cairo',
  );

  List<Map<String, dynamic>> expenses = [];
  double totalExpenses = 0.0;
  double totalConsumption = 0.0;

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
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }

  Future<void> _fetchExpensesData() async {
    try {
      const query = '''
        SELECT item_name, quantity, price, (price * quantity) as total_price, consumption
        FROM expenses
      ''';
      final expensesData = await widget.db.fetchAll(query);

      if (expensesData.isEmpty) {
        showSnackBar('لا توجد بيانات مصروفات لهذا الشهر!');
        return;
      }

      setState(() {
        expenses = expensesData;
        totalExpenses = expenses.fold(
            0.0, (sum, item) => sum + (item['total_price'] as num).toDouble());
        totalConsumption = expenses.fold(
            0.0, (sum, item) => sum + (item['consumption'] as num) * (item['price'] as num).toDouble());
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

      final columns = [
        'اسم الصنف',
        'الكمية',
        'سعر الوحدة',
        'السعر الكامل',
        'الاستهلاك',
      ];

      final rows = expenses.map((row) => [
            row['item_name'] as String,
            row['quantity'] as num,
            row['price'] as num,
            row['total_price'] as num,
            row['consumption'] as num,
          ]).toList();

      final extraInfo = <String, String>{
        'اسم التقرير': 'تقرير المصروفات',
        'تاريخ التصدير': DateTime.now().toString(),
      };

      final totals = [
        [
          'الإجمالي',
          '',
          '',
          totalExpenses,
          totalConsumption,
        ],
      ];

      await exportReportToExcel(
        context: context,
        reportTitle: 'تقرير المصروفات',
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
                      'تقرير المصروفات',
                      style: titleStyle.copyWith(color: Colors.black),
                      textAlign: TextAlign.center,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 20),
                    if (expenses.isNotEmpty)
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
                                  child: Text('اسم الصنف',
                                      style: textStyle.copyWith(color: Colors.white)),
                                ),
                              ),
                              DataColumn(
                                label: Container(
                                  alignment: Alignment.center,
                                  child: Text('الكمية',
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
                                  child: Text('السعر الكامل',
                                      style: textStyle.copyWith(color: Colors.white)),
                                ),
                              ),
                              DataColumn(
                                label: Container(
                                  alignment: Alignment.center,
                                  child: Text('الاستهلاك',
                                      style: textStyle.copyWith(color: Colors.white)),
                                ),
                              ),
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
                                DataCell(
                                  Container(
                                    alignment: Alignment.center,
                                    child: Text(
                                      (row['consumption'] as num).truncate() == row['consumption']
                                          ? row['consumption'].toStringAsFixed(0)
                                          : row['consumption'].toStringAsFixed(2),
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
                    Wrap(
                      spacing: 20,
                      runSpacing: 10,
                      alignment: WrapAlignment.center,
                      children: [
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
                            'إجمالي المصروفات: ${totalExpenses.toStringAsFixed(2)}',
                            style: textStyle.copyWith(color: Colors.black),
                            textAlign: TextAlign.center,
                          ),
                        ),
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
                            'إجمالي الاستهلاك: ${totalConsumption.toStringAsFixed(2)}',
                            style: textStyle.copyWith(color: Colors.black),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ],
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