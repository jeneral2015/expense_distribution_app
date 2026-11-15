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
  final TextStyle textStyle =
      const TextStyle(fontSize: 13, fontFamily: 'Cairo');

  List<Map<String, dynamic>> summaryList = [];
  double totalMeals = 0.0;
  double totalDrinks = 0.0;
  double totalMisc = 0.0;
  double totalConsumption = 0.0;
  double totalContributions = 0.0;
  double totalRemainingInventory = 0.0;
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
        summaryList = await widget.db
            .fetchAll(query, [widget.archiveKeyId, widget.archiveKeyId]);

        const remQuery = '''
          SELECT COALESCE(SUM(remaining * price), 0) AS total_remaining
          FROM expenses_archive
          WHERE archive_key_id = ? AND remaining > 0
        ''';
        final remResults =
            await widget.db.fetchAll(remQuery, [widget.archiveKeyId]);
        totalRemainingInventory = remResults.isNotEmpty
            ? Formatters.toDouble(remResults[0]['total_remaining'])
            : 0.0;
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

        const remQuery = '''
          SELECT COALESCE(SUM(remaining * price), 0) AS total_remaining
          FROM expenses
          WHERE remaining > 0
        ''';
        final remResults = await widget.db.fetchAll(remQuery);
        totalRemainingInventory = remResults.isNotEmpty
            ? Formatters.toDouble(remResults[0]['total_remaining'])
            : 0.0;
      }

      double totalPurchasesExcludingMisc = 0.0;
      double undistributedMisc = 0.0;
      if (isArchived) {
        const purQuery = '''
          SELECT COALESCE(SUM(total_price), 0) AS total_purchases
          FROM expenses_archive
          WHERE archive_key_id = ? AND COALESCE(is_miscellaneous, 0) = 0
        ''';
        final purResults =
            await widget.db.fetchAll(purQuery, [widget.archiveKeyId]);
        if (purResults.isNotEmpty) {
          totalPurchasesExcludingMisc =
              Formatters.toDouble(purResults[0]['total_purchases']);
        }

        const miscPurQuery = '''
          SELECT COALESCE(SUM(total_price), 0) AS total_misc
          FROM expenses_archive
          WHERE archive_key_id = ? AND COALESCE(is_miscellaneous, 0) = 1
        ''';
        final miscPurResults =
            await widget.db.fetchAll(miscPurQuery, [widget.archiveKeyId]);
        if (miscPurResults.isNotEmpty) {
          undistributedMisc =
              Formatters.toDouble(miscPurResults[0]['total_misc']);
        }
      } else {
        const purQuery = '''
          SELECT COALESCE(SUM(total_price), 0) AS total_purchases
          FROM expenses
          WHERE COALESCE(is_miscellaneous, 0) = 0
        ''';
        final purResults = await widget.db.fetchAll(purQuery);
        if (purResults.isNotEmpty) {
          totalPurchasesExcludingMisc =
              Formatters.toDouble(purResults[0]['total_purchases']);
        }

        const miscPurQuery = '''
          SELECT COALESCE(SUM(total_price), 0) AS total_misc
          FROM expenses
          WHERE COALESCE(is_miscellaneous, 0) = 1
        ''';
        final miscPurResults = await widget.db.fetchAll(miscPurQuery);
        if (miscPurResults.isNotEmpty) {
          undistributedMisc =
              Formatters.toDouble(miscPurResults[0]['total_misc']);
        }
      }

      totalMeals = summaryList.fold(
          0.0, (s, i) => s + Formatters.toDouble(i['total_meals']));
      totalDrinks = summaryList.fold(
          0.0, (s, i) => s + Formatters.toDouble(i['total_drinks']));
      final recordedMisc = summaryList.fold(
          0.0, (s, i) => s + Formatters.toDouble(i['total_miscellaneous']));

      // النثريات الفعلية (الموزعة على المشتركين + غير الموزعة المسجلة في المصروفات)
      // في الأرشيف: إذا وُزعت النثريات تكون مسجلة في closure_summary_archive ومؤرشفة في expenses_archive، لذا نمنع الازدواج
      final double baseMisc = isArchived
          ? (recordedMisc > 0 ? recordedMisc : undistributedMisc)
          : (recordedMisc + undistributedMisc);

      // حساب فارق تسوية الاستهلاك لضمان مطابقة (المشتريات = الاستهلاك + المتبقي)
      // الفارق هو ما خرج من المخزن ولم يُسجل كوجبات أو مشروبات
      if (totalPurchasesExcludingMisc > 0) {
        final inventoryConsumed =
            (totalPurchasesExcludingMisc - totalRemainingInventory)
                .clamp(0.0, double.infinity);
        final recordedMealsAndDrinks = totalMeals + totalDrinks;
        final inventoryDiscrepancy = inventoryConsumed - recordedMealsAndDrinks;

        // إذا كان هناك فارق ولم يكن قد استوعب بالفعل في النثريات الموزعة
        final alreadyAbsorbedInMisc = (baseMisc - undistributedMisc);
        final remainingDiscrepancy =
            (inventoryDiscrepancy - alreadyAbsorbedInMisc)
                .clamp(0.0, double.infinity);

        totalMisc = baseMisc + remainingDiscrepancy;
      } else {
        totalMisc = baseMisc;
      }

      totalConsumption = totalMeals + totalDrinks + totalMisc;
      totalContributions = summaryList.fold(
          0.0, (s, i) => s + Formatters.toDouble(i['total_contribution']));
      totalRemainingCash =
          totalContributions - (totalConsumption + totalRemainingInventory);
    } catch (e) {
      if (mounted) {
        showAppSnackBar(context, 'خطأ أثناء جلب ملخص الاستهلاك: $e',
            isError: true);
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
        'نوع التقرير': isArchived
            ? 'تقرير استهلاك الأعضاء (مؤرشف)'
            : 'تقرير استهلاك الأعضاء (الشهر الحالي)',
        'تاريخ التصدير': DateTime.now().toString().substring(0, 19),
        'إجمالي المساهمات': '${totalContributions.toAppString()} ج.م',
        'إجمالي الاستهلاك': '${totalConsumption.toAppString()} ج.م',
        'إجمالي النثريات': '${totalMisc.toAppString()} ج.م',
        'إجمالي المتبقيات': '${totalRemainingInventory.toAppString()} ج.م',
        'صافي النقدية المتبقية': '${totalRemainingCash.toAppString()} ج.م',
      };

      if (isArchived && archiveName.isNotEmpty) {
        extraInfo['الأرشيف'] = archiveName;
        extraInfo['الفترة'] = '$startDate إلى $endDate';
      }

      final memberRemainingTotal = summaryList.fold(
          0.0, (s, i) => s + Formatters.toDouble(i['remaining_cash']));

      final totals = [
        [
          'إجمالي استهلاك ومساهمات الأعضاء',
          '',
          '',
          totalMeals,
          totalDrinks,
          totalMisc,
          totalConsumption,
          totalContributions,
          memberRemainingTotal,
        ],
        [
          'إجمالي المتبقيات (المخزون المتبقي)',
          '',
          '',
          '',
          '',
          '',
          '',
          '',
          totalRemainingInventory,
        ],
        [
          'صافي النقدية المتبقية (النهائي)',
          '',
          '',
          '',
          '',
          '',
          '',
          '',
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
                        style: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 14),
                    ],

                    if (summaryList.isEmpty)
                      const Padding(
                        padding: EdgeInsets.all(32.0),
                        child: Text(
                          'لا توجد بيانات استهلاك لهذا الشهر!',
                          style: TextStyle(
                              fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                      )
                    else
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: DataTable(
                          columnSpacing: 18,
                          border: TableBorder.all(
                              color: Colors.grey.shade400, width: 1),
                          headingRowColor:
                              WidgetStateProperty.all(const Color(0xFF1E4C54)),
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
                            final rem =
                                Formatters.toDouble(row['remaining_cash']);

                            return DataRow(
                              cells: [
                                DataCell(Center(
                                    child: Text('$idx', style: textStyle))),
                                DataCell(Text(row['rank']?.toString() ?? '',
                                    style: textStyle)),
                                DataCell(Text(row['name']?.toString() ?? '',
                                    style: textStyle)),
                                DataCell(Text(
                                    Formatters.toDouble(row['total_meals'])
                                        .toAppString(),
                                    style: textStyle)),
                                DataCell(Text(
                                    Formatters.toDouble(row['total_drinks'])
                                        .toAppString(),
                                    style: textStyle)),
                                DataCell(Text(
                                    Formatters.toDouble(
                                            row['total_miscellaneous'])
                                        .toAppString(),
                                    style: textStyle)),
                                DataCell(Text(
                                  Formatters.toDouble(row['total_consumption'])
                                      .toAppString(),
                                  style: textStyle.copyWith(
                                      fontWeight: FontWeight.bold),
                                )),
                                DataCell(Text(
                                    Formatters.toDouble(
                                            row['total_contribution'])
                                        .toAppString(),
                                    style: textStyle)),
                                DataCell(Text(
                                  rem.toAppString(),
                                  style: textStyle.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: rem < 0
                                        ? Colors.red[800]
                                        : Colors.green[800],
                                  ),
                                )),
                              ],
                            );
                          }).toList(),
                        ),
                      ),
                    Container(
                      margin: const EdgeInsets.only(top: 12),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.blue.shade200),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.info_outline,
                              size: 18, color: Colors.blue.shade800),
                          const SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              'ملاحظة: عمود الاستهلاك بالجدول يمثل وجبات ومشروبات كل مشترك، وإجمالي الاستهلاك بالبطاقات أدناه يشمل النثريات وفارق تسوية المخزون لضمان تمام مطابقة الصندوق بنسبة 100%.',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.blue.shade900,
                                fontWeight: FontWeight.w600,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Totals Grid
                    Wrap(
                      spacing: 12,
                      runSpacing: 10,
                      alignment: WrapAlignment.center,
                      children: [
                        _buildMetricBox(
                            'إجمالي الوجبات', totalMeals, Colors.teal),
                        _buildMetricBox(
                            'إجمالي المشروبات', totalDrinks, Colors.brown),
                        _buildMetricBox(
                            'إجمالي النثريات', totalMisc, Colors.orange),
                        _buildMetricBox('إجمالي الاستهلاك', totalConsumption,
                            Colors.indigo),
                        _buildMetricBox('إجمالي المساهمات', totalContributions,
                            Colors.blue),
                        _buildMetricBox('إجمالي المتبقيات',
                            totalRemainingInventory, Colors.purple),
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
