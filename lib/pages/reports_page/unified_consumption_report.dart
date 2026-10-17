import 'package:flutter/material.dart';
import '../../utils/database.dart';
import '../../utils/button_utils.dart';
import '../../utils/background_scaffold.dart';
import '../../utils/excel_export.dart';
import '../../core/constants/app_ranks.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/snackbar_utils.dart';

class ConsumptionReportPage extends StatefulWidget {
  final DatabaseManager db;
  final int? archiveKeyId;

  const ConsumptionReportPage({
    super.key,
    required this.db,
    this.archiveKeyId,
  });

  @override
  State<ConsumptionReportPage> createState() => _ConsumptionReportPageState();
}

class _ConsumptionReportPageState extends State<ConsumptionReportPage> {
  final TextStyle textStyle = const TextStyle(fontSize: 13, fontFamily: 'Cairo');

  List<Map<String, dynamic>> summaryList = [];
  double totalMeals = 0.0;
  double totalDrinks = 0.0;
  double totalMisc = 0.0;
  double totalConsumption = 0.0;
  double totalContributions = 0.0;
  double totalRemainingCash = 0.0;

  bool _loading = true;
  String archiveName = '';
  String startDate = '';
  String endDate = '';

  bool get isArchived => widget.archiveKeyId != null;

  @override
  void initState() {
    super.initState();
    _fetchConsumptionData();
  }

  Future<void> _fetchConsumptionData() async {
    setState(() => _loading = true);
    try {
      if (isArchived) {
        final archiveInfo = await widget.db.fetchAll(
          'SELECT archive_name, start_date, end_date FROM archive_keys WHERE archive_key_id = ?',
          [widget.archiveKeyId],
        );

        if (archiveInfo.isNotEmpty) {
          archiveName = archiveInfo[0]['archive_name'] as String? ?? '';
          startDate = archiveInfo[0]['start_date'] as String? ?? '';
          endDate = archiveInfo[0]['end_date'] as String? ?? '';
        }

        final query = '''
          SELECT 
            m.name,
            m.rank,
            COALESCE(csa.total_meals, 0) AS total_meals,
            COALESCE(csa.total_drinks, 0) AS total_drinks,
            COALESCE(csa.total_miscellaneous, 0) AS total_miscellaneous,
            COALESCE(csa.total_consumption, 0) AS total_consumption,
            COALESCE(csa.total_contribution, 0) AS total_contribution,
            COALESCE(csa.remaining_cash, 0) AS remaining_cash
          FROM closure_summary_archive csa
          JOIN members_archive m ON csa.member_id = m.member_id
          WHERE csa.archive_key_id = ? AND m.archive_key_id = ?
          ORDER BY ${AppRanks.sqlRankOrder('m.rank')}, m.name ASC
        ''';
        summaryList = await widget.db.fetchAll(query, [widget.archiveKeyId, widget.archiveKeyId]);
      } else {
        final query = '''
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
                 COALESCE(mt.meal_cost, 0) as total_meals,
                 COALESCE(dt.drink_cost, 0) as total_drinks,
                 COALESCE(mct.misc_cost, 0) as total_miscellaneous,
                 (COALESCE(mt.meal_cost, 0) + COALESCE(dt.drink_cost, 0) + COALESCE(mct.misc_cost, 0)) as total_consumption,
                 COALESCE(m.contribution, 0) as total_contribution,
                 (COALESCE(m.contribution, 0) - (COALESCE(mt.meal_cost, 0) + COALESCE(dt.drink_cost, 0) + COALESCE(mct.misc_cost, 0))) as remaining_cash
          FROM members m
          LEFT JOIN MealTotals mt ON m.member_id = mt.member_id
          LEFT JOIN DrinkTotals dt ON m.member_id = dt.member_id
          LEFT JOIN MiscTotals mct ON m.member_id = mct.member_id
          ORDER BY ${AppRanks.sqlRankOrder('m.rank')}, m.name ASC
        ''';
        summaryList = await widget.db.fetchAll(query);
      }

      totalMeals = summaryList.fold(0.0, (s, i) => s + Formatters.toDouble(i['total_meals']));
      totalDrinks = summaryList.fold(0.0, (s, i) => s + Formatters.toDouble(i['total_drinks']));
      totalMisc = summaryList.fold(0.0, (s, i) => s + Formatters.toDouble(i['total_miscellaneous']));
      totalConsumption = summaryList.fold(0.0, (s, i) => s + Formatters.toDouble(i['total_consumption']));
      totalContributions = summaryList.fold(0.0, (s, i) => s + Formatters.toDouble(i['total_contribution']));
      totalRemainingCash = summaryList.fold(0.0, (s, i) => s + Formatters.toDouble(i['remaining_cash']));
    } catch (e) {
      if (mounted) {
        showAppSnackBar(context, 'خطأ أثناء جلب ملخص الاستهلاك: $e', isError: true);
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _exportToExcel() async {
    try {
      if (summaryList.isEmpty) {
        showAppSnackBar(context, 'لا توجد بيانات لتصديرها');
        return;
      }

      final columns = [
        'المسلسل',
        'الرتبة',
        'الاسم',
        'الوجبات',
        'المشروبات',
        'النثريات',
        'الاستهلاك',
        'المساهمات',
        'المتبقي',
      ];

      final rows = summaryList.asMap().entries.map((entry) {
        final index = entry.key + 1;
        final row = entry.value;
        return [
          index,
          row['rank']?.toString() ?? '',
          row['name']?.toString() ?? '',
          Formatters.toDouble(row['total_meals']),
          Formatters.toDouble(row['total_drinks']),
          Formatters.toDouble(row['total_miscellaneous']),
          Formatters.toDouble(row['total_consumption']),
          Formatters.toDouble(row['total_contribution']),
          Formatters.toDouble(row['remaining_cash']),
        ];
      }).toList();

      final extraInfo = <String, String>{
        'نوع التقرير': isArchived ? 'تقرير استهلاك الأعضاء (مؤرشف)' : 'تقرير استهلاك الأعضاء (الشهر الحالي)',
        'تاريخ التصدير': DateTime.now().toString().substring(0, 19),
      };

      if (isArchived && archiveName.isNotEmpty) {
        extraInfo['الأرشيف'] = archiveName;
        extraInfo['الفترة'] = '$startDate إلى $endDate';
      }

      final totals = [
        [
          'الإجمالي العام',
          '',
          '',
          totalMeals,
          totalDrinks,
          totalMisc,
          totalConsumption,
          totalContributions,
          totalRemainingCash,
        ]
      ];

      final title = isArchived
          ? 'تقرير_الاستهلاك_العام_أرشيف_${widget.archiveKeyId}'
          : 'تقرير_الاستهلاك_العام_الشهر_الحالي';

      await exportReportToExcel(
        context: context,
        reportTitle: title,
        columns: columns,
        rows: rows,
        extraInfo: extraInfo,
        totals: totals,
      );
    } catch (e) {
      if (mounted) {
        showAppSnackBar(context, 'خطأ أثناء تصدير التقرير: $e', isError: true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return BackgroundScaffold(
      title: isArchived ? 'تقرير الاستهلاك (مؤرشف)' : 'تقرير الاستهلاك العام',
      child: _loading
          ? const Center(child: CircularProgressIndicator())
          : Directionality(
              textDirection: TextDirection.rtl,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    if (isArchived) ...[
                      Text(
                        'الأرشيف: $archiveName\nالفترة: $startDate إلى $endDate',
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 14),
                    ],

                    if (summaryList.isEmpty)
                      const Padding(
                        padding: EdgeInsets.all(32.0),
                        child: Text(
                          'لا توجد بيانات استهلاك لهذا الشهر!',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                      )
                    else
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: DataTable(
                          columnSpacing: 18,
                          border: TableBorder.all(color: Colors.grey.shade400, width: 1),
                          headingRowColor: WidgetStateProperty.all(const Color(0xFF1E4C54)),
                          headingTextStyle: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontFamily: 'Cairo',
                            fontSize: 13,
                          ),
                          columns: const [
                            DataColumn(label: Text('المسلسل')),
                            DataColumn(label: Text('الرتبة')),
                            DataColumn(label: Text('الاسم')),
                            DataColumn(label: Text('الوجبات')),
                            DataColumn(label: Text('المشروبات')),
                            DataColumn(label: Text('النثريات')),
                            DataColumn(label: Text('الاستهلاك')),
                            DataColumn(label: Text('المساهمات')),
                            DataColumn(label: Text('المتبقي')),
                          ],
                          rows: summaryList.asMap().entries.map((entry) {
                            final idx = entry.key + 1;
                            final row = entry.value;
                            final rem = Formatters.toDouble(row['remaining_cash']);

                            return DataRow(
                              cells: [
                                DataCell(Center(child: Text('$idx', style: textStyle))),
                                DataCell(Text(row['rank']?.toString() ?? '', style: textStyle)),
                                DataCell(Text(row['name']?.toString() ?? '', style: textStyle)),
                                DataCell(Text(Formatters.toDouble(row['total_meals']).toAppString(), style: textStyle)),
                                DataCell(Text(Formatters.toDouble(row['total_drinks']).toAppString(), style: textStyle)),
                                DataCell(Text(Formatters.toDouble(row['total_miscellaneous']).toAppString(), style: textStyle)),
                                DataCell(Text(
                                  Formatters.toDouble(row['total_consumption']).toAppString(),
                                  style: textStyle.copyWith(fontWeight: FontWeight.bold),
                                )),
                                DataCell(Text(Formatters.toDouble(row['total_contribution']).toAppString(), style: textStyle)),
                                DataCell(Text(
                                  rem.toAppString(),
                                  style: textStyle.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: rem < 0 ? Colors.red[800] : Colors.green[800],
                                  ),
                                )),
                              ],
                            );
                          }).toList(),
                        ),
                      ),
                    const SizedBox(height: 20),

                    // Totals Grid
                    Wrap(
                      spacing: 12,
                      runSpacing: 10,
                      alignment: WrapAlignment.center,
                      children: [
                        _buildMetricBox('إجمالي الوجبات', totalMeals, Colors.teal),
                        _buildMetricBox('إجمالي المشروبات', totalDrinks, Colors.brown),
                        _buildMetricBox('إجمالي النثريات', totalMisc, Colors.orange),
                        _buildMetricBox('إجمالي الاستهلاك', totalConsumption, Colors.indigo),
                        _buildMetricBox('إجمالي المساهمات', totalContributions, Colors.blue),
                        _buildMetricBox(
                          'صافي النقدية المتبقية',
                          totalRemainingCash,
                          totalRemainingCash < 0 ? Colors.red : Colors.green,
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    Wrap(
                      spacing: 16,
                      runSpacing: 12,
                      alignment: WrapAlignment.center,
                      children: [
                        createButton(
                          text: 'تصدير إلى Excel',
                          onPressed: _exportToExcel,
                          bgColor: Colors.blue[700]!,
                          icon: Icons.download,
                          iconColor: Colors.white,
                          width: 200,
                        ),
                        createButton(
                          text: 'رجوع',
                          onPressed: () => Navigator.of(context).pop(),
                          bgColor: Colors.red[700]!,
                          icon: Icons.arrow_back,
                          iconColor: Colors.white,
                          width: 200,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildMetricBox(String title, double value, MaterialColor color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: const [
          BoxShadow(color: Colors.black12, blurRadius: 6, offset: Offset(0, 2)),
        ],
        border: Border.all(color: color.shade300),
      ),
      child: Column(
        children: [
          Text(title, style: TextStyle(fontSize: 12, color: color.shade800)),
          const SizedBox(height: 2),
          Text(
            '${value.toAppString()} ج.م',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: color.shade900,
            ),
          ),
        ],
      ),
    );
  }
}
