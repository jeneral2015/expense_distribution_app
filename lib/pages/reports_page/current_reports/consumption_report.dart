import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../utils/database.dart';
import '../../../utils/button_utils.dart';
import '../../../utils/background_scaffold.dart';
import '../../../utils/excel_export.dart';
import '../../../utils/logger.dart';

class ConsumptionReport extends StatefulWidget {
  final DatabaseManager db;

  const ConsumptionReport({
    Key? key,
    required this.db,
  }) : super(key: key);

  @override
  _ConsumptionReportState createState() => _ConsumptionReportState();
}

class _ConsumptionReportState extends State<ConsumptionReport> {
  final TextStyle textStyle = const TextStyle(
    fontSize: 15,
    fontFamily: 'Cairo',
  );
  final TextStyle titleStyle = const TextStyle(
    fontSize: 28,
    fontWeight: FontWeight.bold,
    fontFamily: 'Cairo',
  );

  List<Map<String, dynamic>> consumption = [];
  double totalMeals = 0.0;
  double totalDrinks = 0.0;
  double totalMisc = 0.0;
  double totalConsumption = 0.0;

  @override
  void initState() {
    super.initState();
    _fetchConsumptionData();
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

  Future<void> _fetchConsumptionData() async {
    try {
      const query = '''
        WITH MealTotals AS (
          SELECT member_id, COALESCE(SUM(final_cost), 0) as meal_cost
          FROM meal_records
          GROUP BY member_id
        ),
        DrinkTotals AS (
          SELECT member_id, COALESCE(SUM(total_cost), 0) as drink_cost
          FROM drink_records
          GROUP BY member_id
        ),
        MiscTotals AS (
          SELECT member_id, COALESCE(SUM(misc_amount), 0) as misc_cost
          FROM miscellaneous_contributions
          GROUP BY member_id
        )
        SELECT m.member_id, m.name, m.rank,
               COALESCE(mt.meal_cost, 0) as meal_cost,
               COALESCE(dt.drink_cost, 0) as drink_cost,
               COALESCE(mct.misc_cost, 0) as misc_cost
        FROM members m
        LEFT JOIN MealTotals mt ON m.member_id = mt.member_id
        LEFT JOIN DrinkTotals dt ON m.member_id = dt.member_id
        LEFT JOIN MiscTotals mct ON m.member_id = mct.member_id
      ''';
      final consumptionData = await widget.db.fetchAll(query);

      if (consumptionData.isEmpty) {
        showSnackBar('لا توجد بيانات استهلاك لهذا الشهر!');
        return;
      }

      setState(() {
        consumption = consumptionData;
        totalMeals = consumption.fold(0.0, (sum, item) => sum + (item['meal_cost'] as num).toDouble());
        totalDrinks = consumption.fold(0.0, (sum, item) => sum + (item['drink_cost'] as num).toDouble());
        totalMisc = consumption.fold(0.0, (sum, item) => sum + (item['misc_cost'] as num).toDouble());
        totalConsumption = totalMeals + totalDrinks + totalMisc;
      });

      // طباعة للتصحيح
      for (var row in consumptionData) {
        AppLogger.logInfo('Member: ${row['name']}, Meals: ${row['meal_cost']}, Drinks: ${row['drink_cost']}, Misc: ${row['misc_cost']}');
  }
    } catch (e) {
      showSnackBar('خطأ أثناء جلب تقرير الاستهلاك: $e');
    }
  }

  Future<void> _exportToExcel() async {
    try {
      if (consumption.isEmpty) {
        showSnackBar('لا توجد بيانات لتصديرها');
        return;
      }

      final columns = [
        'المسلسل',
        'الرتبة',
        'اسم المشترك',
        'تكلفة الوجبات',
        'تكلفة المشروبات',
        'تكلفة النثريات',
        'إجمالي الاستهلاك',
      ];

      final rows = consumption.asMap().entries.map((entry) {
        final i = entry.key;
        final row = entry.value;
        return [
          (i + 1).toString(),
          row['rank'] as String,
          row['name'] as String,
          row['meal_cost'] as num,
          row['drink_cost'] as num,
          row['misc_cost'] as num,
          (row['meal_cost'] + row['drink_cost'] + row['misc_cost']) as num,
        ];
      }).toList();

      final extraInfo = <String, String>{
        'اسم التقرير': 'تقرير استهلاك المشتركين',
        'تاريخ التصدير': DateTime.now().toString(),
      };

      final totals = [
        [
          'الإجمالي',
          '',
          '',
          totalMeals,
          totalDrinks,
          totalMisc,
          totalConsumption,
        ],
      ];

      await exportReportToExcel(
        context: context,
        reportTitle: 'تقرير استهلاك المشتركين',
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
                      'تقرير استهلاك المشتركين',
                      style: titleStyle.copyWith(color: Colors.black),
                      textAlign: TextAlign.center,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 20),
                    if (consumption.isNotEmpty)
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
                                  child: Text('المسلسل', style: textStyle.copyWith(color: Colors.white)),
                                ),
                              ),
                              DataColumn(
                                label: Container(
                                  alignment: Alignment.center,
                                  child: Text('الرتبة', style: textStyle.copyWith(color: Colors.white)),
                                ),
                              ),
                              DataColumn(
                                label: Container(
                                  alignment: Alignment.center,
                                  child: Text('اسم المشترك', style: textStyle.copyWith(color: Colors.white)),
                                ),
                              ),
                              DataColumn(
                                label: Container(
                                  alignment: Alignment.center,
                                  child: Text('تكلفة الوجبات', style: textStyle.copyWith(color: Colors.white)),
                                ),
                              ),
                              DataColumn(
                                label: Container(
                                  alignment: Alignment.center,
                                  child: Text('تكلفة المشروبات', style: textStyle.copyWith(color: Colors.white)),
                                ),
                              ),
                              DataColumn(
                                label: Container(
                                  alignment: Alignment.center,
                                  child: Text('تكلفة النثريات', style: textStyle.copyWith(color: Colors.white)),
                                ),
                              ),
                              DataColumn(
                                label: Container(
                                  alignment: Alignment.center,
                                  child: Text('إجمالي الاستهلاك', style: textStyle.copyWith(color: Colors.white)),
                                ),
                              ),
                            ],
                            rows: consumption.asMap().entries.map((entry) {
                              final i = entry.key;
                              final row = entry.value;
                              return DataRow(
                                cells: [
                                  DataCell(
                                    Container(
                                      alignment: Alignment.center,
                                      child: Text((i + 1).toString(), style: textStyle),
                                    ),
                                  ),
                                  DataCell(
                                    Container(
                                      alignment: Alignment.center,
                                      constraints: const BoxConstraints(maxWidth: 100),
                                      child: Text(row['rank'] as String, style: textStyle, overflow: TextOverflow.ellipsis),
                                    ),
                                  ),
                                  DataCell(
                                    Container(
                                      alignment: Alignment.center,
                                      constraints: const BoxConstraints(maxWidth: 150),
                                      child: Text(row['name'] as String, style: textStyle, overflow: TextOverflow.ellipsis),
                                    ),
                                  ),
                                  DataCell(
                                    Container(
                                      alignment: Alignment.center,
                                      child: Text(
                                        (row['meal_cost'] as num).truncate() == row['meal_cost']
                                            ? row['meal_cost'].toStringAsFixed(0)
                                            : row['meal_cost'].toStringAsFixed(2),
                                        style: textStyle,
                                      ),
                                    ),
                                  ),
                                  DataCell(
                                    Container(
                                      alignment: Alignment.center,
                                      child: Text(
                                        (row['drink_cost'] as num).truncate() == row['drink_cost']
                                            ? row['drink_cost'].toStringAsFixed(0)
                                            : row['drink_cost'].toStringAsFixed(2),
                                        style: textStyle,
                                      ),
                                    ),
                                  ),
                                  DataCell(
                                    Container(
                                      alignment: Alignment.center,
                                      child: Text(
                                        (row['misc_cost'] as num).truncate() == row['misc_cost']
                                            ? row['misc_cost'].toStringAsFixed(0)
                                            : row['misc_cost'].toStringAsFixed(2),
                                        style: textStyle,
                                      ),
                                    ),
                                  ),
                                  DataCell(
                                    Container(
                                      alignment: Alignment.center,
                                      child: Text(
                                        ((row['meal_cost'] + row['drink_cost'] + row['misc_cost']) as num).truncate() ==
                                                (row['meal_cost'] + row['drink_cost'] + row['misc_cost'])
                                            ? (row['meal_cost'] + row['drink_cost'] + row['misc_cost']).toStringAsFixed(0)
                                            : (row['meal_cost'] + row['drink_cost'] + row['misc_cost']).toStringAsFixed(2),
                                        style: textStyle,
                                      ),
                                    ),
                                  ),
                                ],
                              );
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
                        'إجمالي الوجبات: ${totalMeals.toStringAsFixed(2)}, المشروبات: ${totalDrinks.toStringAsFixed(2)}, النثريات: ${totalMisc.toStringAsFixed(2)}, الاستهلاك: ${totalConsumption.toStringAsFixed(2)}',
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