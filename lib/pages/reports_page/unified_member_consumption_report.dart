import 'package:flutter/material.dart';
import '../../utils/database.dart';
import '../../utils/button_utils.dart';
import '../../utils/background_scaffold.dart';
import '../../utils/excel_export.dart';
import '../../core/constants/app_ranks.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/snackbar_utils.dart';
import '../../core/widgets/meal_details_dialog.dart';
import '../../services/auth_service.dart';
import '../../utils/helpers.dart' as helpers;

class MemberConsumptionReportPage extends StatefulWidget {
  final DatabaseManager db;
  final int? archiveKeyId;

  const MemberConsumptionReportPage({
    super.key,
    required this.db,
    this.archiveKeyId,
  });

  @override
  State<MemberConsumptionReportPage> createState() =>
      _MemberConsumptionReportPageState();
}

class _MemberConsumptionReportPageState
    extends State<MemberConsumptionReportPage> {
  final TextStyle textStyle = const TextStyle(fontSize: 14, fontFamily: 'Cairo');

  List<Map<String, dynamic>> subscribers = [];
  String? selectedSubscriberId;
  String selectedSubscriberName = '';

  List<Map<String, dynamic>> consumption = [];
  List<Map<String, dynamic>> filteredConsumption = [];
  Set<int> selectedRecordIndices = {};

  final TextEditingController searchController = TextEditingController();

  double totalCost = 0.0;
  double mealsCost = 0.0;
  double drinksCost = 0.0;
  double miscCost = 0.0;
  bool _loading = true;

  String archiveName = '';
  String startDate = '';
  String endDate = '';

  bool get isArchived => widget.archiveKeyId != null;

  @override
  void initState() {
    super.initState();
    _fetchSubscribers();
    searchController.addListener(_applySearchFilter);
  }

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  void _applySearchFilter() {
    final query = searchController.text.trim().toLowerCase();
    setState(() {
      if (query.isEmpty) {
        filteredConsumption = consumption;
      } else {
        filteredConsumption = consumption.where((item) {
          final itemName = (item['item']?.toString() ?? '').toLowerCase();
          final date = (item['date']?.toString() ?? '').toLowerCase();
          return itemName.contains(query) || date.contains(query);
        }).toList();
      }
      _calculateTotals();
    });
  }

  void _calculateTotals() {
    totalCost = filteredConsumption.fold(
      0.0,
      (sum, item) => sum + Formatters.toDouble(item['cost']),
    );
    mealsCost = filteredConsumption
        .where((item) => item['record_type'] == 'meal')
        .fold(0.0, (sum, item) => sum + Formatters.toDouble(item['cost']));
    drinksCost = filteredConsumption
        .where((item) => item['record_type'] == 'drink')
        .fold(0.0, (sum, item) => sum + Formatters.toDouble(item['cost']));
    miscCost = filteredConsumption
        .where((item) => item['record_type'] == 'misc')
        .fold(0.0, (sum, item) => sum + Formatters.toDouble(item['cost']));
  }

  Future<void> _fetchSubscribers() async {
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
          SELECT member_id, rank, name
          FROM members_archive
          WHERE archive_key_id = ?
          ORDER BY ${AppRanks.sqlRankOrder()}, name ASC
        ''';
        subscribers = await widget.db.fetchAll(query, [widget.archiveKeyId]);
      } else {
        final query = '''
          SELECT member_id, rank, name
          FROM members
          ORDER BY ${AppRanks.sqlRankOrder()}, name ASC
        ''';
        subscribers = await widget.db.fetchAll(query);
      }
    } catch (e) {
      if (mounted) {
        showAppSnackBar(context, 'خطأ أثناء جلب المشتركين: $e', isError: true);
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _fetchConsumption(String memberId) async {
    setState(() => _loading = true);
    try {
      String query;
      List<dynamic> params;

      if (isArchived) {
        query = '''
          SELECT mr.meal_record_id as record_id, 'meal' as record_type,
                 m.name, COALESCE(mr.meal_type, 'غير محدد') as item,
                 COALESCE(mr.final_cost, 0) as cost, mr.date, mr.meal_id
          FROM meal_records_archive mr
          JOIN members_archive m ON mr.member_id = m.member_id
          WHERE mr.member_id = ? AND mr.archive_key_id = ?
          UNION ALL
          SELECT dr.drink_record_id as record_id, 'drink' as record_type,
                 m.name, dr.drink_name as item,
                 dr.total_cost as cost, dr.date, NULL as meal_id
          FROM drink_records_archive dr
          JOIN members_archive m ON dr.member_id = m.member_id
          WHERE dr.member_id = ? AND dr.archive_key_id = ?
          UNION ALL
          SELECT mc.misc_contribution_id as record_id, 'misc' as record_type,
                 m.name, 'نثريات' as item,
                 mc.misc_amount as cost, mc.distribution_date as date, NULL as meal_id
          FROM miscellaneous_contributions_archive mc
          JOIN members_archive m ON mc.member_id = m.member_id
          WHERE mc.member_id = ? AND mc.archive_key_id = ?
          ORDER BY date DESC
        ''';
        params = [
          memberId,
          widget.archiveKeyId,
          memberId,
          widget.archiveKeyId,
          memberId,
          widget.archiveKeyId
        ];
      } else {
        query = '''
          SELECT mr.meal_record_id as record_id, 'meal' as record_type,
                 m.name, COALESCE(mr.meal_type, 'غير محدد') as item,
                 COALESCE(mr.final_cost, 0) as cost, mr.date, mr.meal_id
          FROM meal_records mr
          JOIN members m ON mr.member_id = m.member_id
          WHERE mr.member_id = ?
          UNION ALL
          SELECT dr.drink_record_id as record_id, 'drink' as record_type,
                 m.name, dr.drink_name as item,
                 dr.total_cost as cost, dr.date, NULL as meal_id
          FROM drink_records dr
          JOIN members m ON dr.member_id = m.member_id
          WHERE dr.member_id = ?
          UNION ALL
          SELECT mc.misc_contribution_id as record_id, 'misc' as record_type,
                 m.name, 'نثريات' as item,
                 mc.misc_amount as cost, mc.distribution_date as date, NULL as meal_id
          FROM miscellaneous_contributions mc
          JOIN members m ON mc.member_id = m.member_id
          WHERE mc.member_id = ?
          ORDER BY date DESC
        ''';
        params = [memberId, memberId, memberId];
      }

      final data = await widget.db.fetchAll(query, params);
      consumption = data;
      filteredConsumption = data;
      selectedRecordIndices.clear();
      _calculateTotals();
    } catch (e) {
      if (mounted) {
        showAppSnackBar(context, 'خطأ أثناء جلب استهلاك المشترك: $e', isError: true);
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showMealDetails(Map<String, dynamic> row) {
    if (row['record_type'] != 'meal') return;

    MealDetailsDialog.show(
      context: context,
      db: widget.db,
      mealId: row['meal_id'] as int?,
      mealRecordId: row['record_id'] as int?,
      memberName: row['name']?.toString() ?? selectedSubscriberName,
      mealType: row['item']?.toString() ?? 'وجبة',
      date: row['date']?.toString() ?? '',
      memberFinalCost: Formatters.toDouble(row['cost']),
    );
  }

  Future<void> _deleteSelectedRecords() async {
    if (selectedRecordIndices.isEmpty) {
      showAppSnackBar(context, 'لم يتم اختيار أي سجلات للحذف!');
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: const Text('تأكيد الحذف'),
          content: Text('هل أنت متأكد من حذف ${selectedRecordIndices.length} سجل محدد؟'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('إلغاء'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('حذف'),
            ),
          ],
        ),
      ),
    );

    if (confirm != true) return;

    try {
      await widget.db.transaction((txn) async {
        for (final idx in selectedRecordIndices) {
          final row = filteredConsumption[idx];
          final type = row['record_type'] as String;
          final recId = row['record_id'] as int;

          if (type == 'meal') {
            final mealId = row['meal_id'] as int?;
            if (mealId != null) {
              await helpers.Helpers.reverseMealEffects(txn, mealId);
            } else {
              await txn.rawDelete(
                'DELETE FROM meal_records WHERE meal_record_id = ?',
                [recId],
              );
            }
          } else if (type == 'drink') {
            await helpers.Helpers.reverseDrinkEffects(recId);
          } else if (type == 'misc') {
            await helpers.Helpers.reverseMiscEffects(recId);
          }
        }
      });

      if (mounted) {
        showAppSnackBar(context, 'تم حذف السجلات المحددة بنجاح');
      }
      if (selectedSubscriberId != null) {
        await _fetchConsumption(selectedSubscriberId!);
      }
    } catch (e) {
      if (mounted) {
        showAppSnackBar(context, 'خطأ أثناء حذف السجلات: $e', isError: true);
      }
    }
  }

  Future<void> _exportToExcel() async {
    try {
      if (filteredConsumption.isEmpty) {
        showAppSnackBar(context, 'لا توجد بيانات لتصديرها');
        return;
      }

      final columns = ['اسم المشترك', 'الصنف / البند', 'التكلفة', 'التاريخ'];
      final rows = filteredConsumption
          .map((row) => [
                row['name']?.toString() ?? selectedSubscriberName,
                row['item']?.toString() ?? '',
                Formatters.toDouble(row['cost']),
                row['date']?.toString() ?? '',
              ])
          .toList();

      final extraInfo = <String, String>{
        'اسم المشترك': selectedSubscriberName,
        'نوع التقرير': isArchived ? 'تقرير استهلاك مشترك (مؤرشف)' : 'تقرير استهلاك مشترك (الشهر الحالي)',
        'تاريخ التصدير': DateTime.now().toString().substring(0, 19),
      };

      if (isArchived && archiveName.isNotEmpty) {
        extraInfo['الأرشيف'] = archiveName;
        extraInfo['الفترة'] = '$startDate إلى $endDate';
      }

      final totals = [
        ['إجمالي الوجبات', '', mealsCost, ''],
        ['إجمالي المشروبات', '', drinksCost, ''],
        ['إجمالي النثريات', '', miscCost, ''],
        ['إجمالي الاستهلاك الكلي', '', totalCost, ''],
      ];

      final title = isArchived
          ? 'تقرير_استهلاك_${selectedSubscriberName}_أرشيف_${widget.archiveKeyId}'
          : 'تقرير_استهلاك_${selectedSubscriberName}_الشهر_الحالي';

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
      title: isArchived ? 'استهلاك مشترك (مؤرشف)' : 'تقرير استهلاك مشترك',
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
                      const SizedBox(height: 12),
                    ],

                    // Subscriber Selection Card
                    Card(
                      elevation: 2,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
                        child: Row(
                          children: [
                            const Text(
                              'اختر المشترك: ',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: DropdownButton<String>(
                                value: selectedSubscriberId,
                                hint: const Text('--- اضغط لاختيار مشترك ---'),
                                isExpanded: true,
                                items: subscribers.map((sub) {
                                  final id = sub['member_id'].toString();
                                  final label = '${sub['rank']} / ${sub['name']}';
                                  return DropdownMenuItem(
                                    value: id,
                                    child: Text(label),
                                  );
                                }).toList(),
                                onChanged: (val) {
                                  if (val != null) {
                                    final sub = subscribers.firstWhere(
                                      (s) => s['member_id'].toString() == val,
                                    );
                                    setState(() {
                                      selectedSubscriberId = val;
                                      selectedSubscriberName =
                                          '${sub['rank']} / ${sub['name']}';
                                    });
                                    _fetchConsumption(val);
                                  }
                                },
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),

                    if (selectedSubscriberId != null) ...[
                      // Search box
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 4.0),
                        child: TextField(
                          controller: searchController,
                          decoration: InputDecoration(
                            hintText: 'بحث في السجلات أو التواريخ...',
                            prefixIcon: const Icon(Icons.search),
                            suffixIcon: searchController.text.isNotEmpty
                                ? IconButton(
                                    icon: const Icon(Icons.clear),
                                    onPressed: () => searchController.clear(),
                                  )
                                : null,
                            filled: true,
                            fillColor: Colors.white,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Information banner about meal clicking
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.orange.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.orange.shade200),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.touch_app, color: Colors.orange, size: 20),
                            SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                '💡 اضغط على أي وجبة في الجدول لعرض مكوناتها والتكلفة المسجلة على هذا المشترك.',
                                style: TextStyle(fontSize: 13, color: Colors.deepOrange),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Table
                      if (filteredConsumption.isEmpty)
                        const Padding(
                          padding: EdgeInsets.all(32.0),
                          child: Text(
                            'لا توجد سجلات استهلاك لهذا المشترك!',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                        )
                      else
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: DataTable(
                            columnSpacing: 24,
                            showCheckboxColumn: false,
                            headingRowColor: WidgetStateProperty.all(const Color(0xFF1E4C54)),
                            headingTextStyle: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontFamily: 'Cairo',
                            ),
                            columns: [
                              if (!isArchived)
                                const DataColumn(label: Text('تحديد')),
                              const DataColumn(label: Text('البند / الوجبة')),
                              const DataColumn(label: Text('التكلفة')),
                              const DataColumn(label: Text('التاريخ')),
                              const DataColumn(label: Text('التفاصيل')),
                            ],
                            rows: filteredConsumption.asMap().entries.map((entry) {
                              final idx = entry.key;
                              final row = entry.value;
                              final isSelected = selectedRecordIndices.contains(idx);
                              final isMeal = row['record_type'] == 'meal';
                              final cost = Formatters.toDouble(row['cost']);

                              return DataRow(
                                selected: isSelected,
                                cells: [
                                  if (!isArchived)
                                    DataCell(
                                      Checkbox(
                                        value: isSelected,
                                        onChanged: (sel) {
                                          setState(() {
                                            if (sel == true) {
                                              selectedRecordIndices.add(idx);
                                            } else {
                                              selectedRecordIndices.remove(idx);
                                            }
                                          });
                                        },
                                      ),
                                    ),
                                  DataCell(
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        if (isMeal)
                                          const Icon(Icons.restaurant,
                                              size: 16, color: Colors.orange),
                                        if (row['record_type'] == 'drink')
                                          const Icon(Icons.coffee,
                                              size: 16, color: Colors.brown),
                                        if (row['record_type'] == 'misc')
                                          const Icon(Icons.category,
                                              size: 16, color: Colors.teal),
                                        const SizedBox(width: 6),
                                        Text(row['item']?.toString() ?? '',
                                            style: textStyle),
                                      ],
                                    ),
                                    onTap: isMeal ? () => _showMealDetails(row) : null,
                                  ),
                                  DataCell(
                                    Text('${cost.toAppString()} ج', style: textStyle),
                                    onTap: isMeal ? () => _showMealDetails(row) : null,
                                  ),
                                  DataCell(
                                    Text(row['date']?.toString() ?? '', style: textStyle),
                                    onTap: isMeal ? () => _showMealDetails(row) : null,
                                  ),
                                  DataCell(
                                    isMeal
                                        ? ElevatedButton.icon(
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: Colors.orange.shade50,
                                              foregroundColor: Colors.orange.shade900,
                                              padding: const EdgeInsets.symmetric(
                                                  horizontal: 8, vertical: 2),
                                              elevation: 0,
                                              shape: RoundedRectangleBorder(
                                                borderRadius: BorderRadius.circular(8),
                                                side: BorderSide(
                                                    color: Colors.orange.shade300),
                                              ),
                                            ),
                                            icon: const Icon(Icons.receipt_long, size: 14),
                                            label: const Text('المكونات',
                                                style: TextStyle(fontSize: 11)),
                                            onPressed: () => _showMealDetails(row),
                                          )
                                        : const SizedBox.shrink(),
                                  ),
                                ],
                              );
                            }).toList(),
                          ),
                        ),
                      const SizedBox(height: 20),

                      // Counters
                      Wrap(
                        spacing: 12,
                        runSpacing: 10,
                        alignment: WrapAlignment.center,
                        children: [
                          _buildSummaryBox('الوجبات', mealsCost, Colors.orange),
                          _buildSummaryBox('المشروبات', drinksCost, Colors.brown),
                          _buildSummaryBox('النثريات', miscCost, Colors.teal),
                          _buildSummaryBox('إجمالي الاستهلاك', totalCost, Colors.green),
                        ],
                      ),
                      const SizedBox(height: 20),

                      // Actions
                      if (!isArchived &&
                          selectedRecordIndices.isNotEmpty &&
                          AuthService.instance.canDelete)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 16.0),
                          child: createButton(
                            text: 'حذف السجلات المحددة (${selectedRecordIndices.length})',
                            onPressed: _deleteSelectedRecords,
                            bgColor: Colors.red[800]!,
                            icon: Icons.delete,
                            iconColor: Colors.white,
                            width: 260,
                          ),
                        ),

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
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildSummaryBox(String title, double value, MaterialColor color) {
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
