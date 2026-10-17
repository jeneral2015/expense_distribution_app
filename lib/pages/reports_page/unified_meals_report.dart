import 'package:flutter/material.dart';
import '../../utils/database.dart';
import '../../utils/button_utils.dart';
import '../../utils/background_scaffold.dart';
import '../../utils/excel_export.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/snackbar_utils.dart';
import '../../core/widgets/meal_details_dialog.dart';
import '../../services/auth_service.dart';
import '../../utils/helpers.dart' as helpers;

class MealsReportPage extends StatefulWidget {
  final DatabaseManager db;
  final int? archiveKeyId;

  const MealsReportPage({
    super.key,
    required this.db,
    this.archiveKeyId,
  });

  @override
  State<MealsReportPage> createState() => _MealsReportPageState();
}

class _MealsReportPageState extends State<MealsReportPage> {
  final TextStyle textStyle = const TextStyle(fontSize: 14, fontFamily: 'Cairo');

  List<Map<String, dynamic>> meals = [];
  List<Map<String, dynamic>> filteredMeals = [];
  Set<int> selectedMealIds = {};

  double totalCost = 0.0;
  int breakfastCount = 0;
  int lunchCount = 0;
  int dinnerCount = 0;
  bool _loading = true;

  String archiveName = '';
  String startDate = '';
  String endDate = '';

  // Filters
  String _selectedMealType = 'الكل';
  String? _selectedMember;
  DateTime? _filterStartDate;
  DateTime? _filterEndDate;
  List<String> _memberOptions = ['الكل'];

  bool get isArchived => widget.archiveKeyId != null;

  @override
  void initState() {
    super.initState();
    _fetchMealsData();
  }

  Future<void> _fetchMealsData() async {
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

        const query = '''
          SELECT mr.meal_record_id, m.name, mr.meal_type, mr.date, mr.final_cost, mr.meal_id
          FROM meal_records_archive mr
          JOIN members_archive m ON mr.member_id = m.member_id
          WHERE mr.archive_key_id = ?
          ORDER BY mr.date DESC, mr.meal_record_id DESC
        ''';
        meals = await widget.db.fetchAll(query, [widget.archiveKeyId]);
      } else {
        const query = '''
          SELECT mr.meal_record_id, m.name, mr.meal_type, mr.date, mr.final_cost, mr.meal_id
          FROM meal_records mr
          JOIN members m ON mr.member_id = m.member_id
          ORDER BY mr.date DESC, mr.meal_record_id DESC
        ''';
        meals = await widget.db.fetchAll(query);
      }

      final distinctMembers = meals
          .map((m) => m['name']?.toString() ?? '')
          .where((name) => name.isNotEmpty)
          .toSet()
          .toList()
        ..sort();
      _memberOptions = ['الكل', ...distinctMembers];

      _applyFilters();
    } catch (e) {
      if (mounted) {
        showAppSnackBar(context, 'خطأ أثناء جلب تقرير الوجبات: $e', isError: true);
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _applyFilters() {
    List<Map<String, dynamic>> result = meals;

    if (_selectedMealType != 'الكل') {
      result = result.where((m) => m['meal_type'] == _selectedMealType).toList();
    }

    if (_selectedMember != null && _selectedMember != 'الكل') {
      result = result.where((m) => m['name'] == _selectedMember).toList();
    }

    if (_filterStartDate != null) {
      result = result.where((m) {
        final d = DateTime.tryParse(m['date']?.toString() ?? '');
        return d != null && !d.isBefore(_filterStartDate!);
      }).toList();
    }

    if (_filterEndDate != null) {
      result = result.where((m) {
        final d = DateTime.tryParse(m['date']?.toString() ?? '');
        return d != null && !d.isAfter(_filterEndDate!);
      }).toList();
    }

    filteredMeals = result;

    breakfastCount = 0;
    lunchCount = 0;
    dinnerCount = 0;
    for (final m in filteredMeals) {
      final t = m['meal_type']?.toString() ?? '';
      if (t == 'فطار') breakfastCount++;
      if (t == 'غداء') lunchCount++;
      if (t == 'عشاء') dinnerCount++;
    }

    totalCost = filteredMeals.fold(
      0.0,
      (sum, item) => sum + Formatters.toDouble(item['final_cost']),
    );
  }

  void _showMealDetails(Map<String, dynamic> row) {
    MealDetailsDialog.show(
      context: context,
      db: widget.db,
      mealId: row['meal_id'] as int?,
      mealRecordId: row['meal_record_id'] as int?,
      memberName: row['name']?.toString() ?? 'غير معروف',
      mealType: row['meal_type']?.toString() ?? 'وجبة',
      date: row['date']?.toString() ?? '',
      memberFinalCost: Formatters.toDouble(row['final_cost']),
    );
  }

  Future<void> _deleteSelectedMeals() async {
    if (selectedMealIds.isEmpty) {
      showAppSnackBar(context, 'لم يتم اختيار أي وجبة للحذف!');
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: const Text('تأكيد الحذف'),
          content: Text('هل أنت متأكد من حذف ${selectedMealIds.length} وجبة محددة؟'),
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
        for (final recId in selectedMealIds) {
          final row = meals.firstWhere((m) => m['meal_record_id'] == recId);
          final mealId = row['meal_id'] as int?;
          if (mealId != null) {
            await helpers.Helpers.reverseMealEffects(txn, mealId);
          } else {
            await txn.rawDelete(
              'DELETE FROM meal_records WHERE meal_record_id = ?',
              [recId],
            );
          }
        }
      });

      if (mounted) {
        showAppSnackBar(context, 'تم حذف الوجبات المحددة بنجاح');
      }
      selectedMealIds.clear();
      await _fetchMealsData();
    } catch (e) {
      if (mounted) {
        showAppSnackBar(context, 'خطأ أثناء حذف الوجبات: $e', isError: true);
      }
    }
  }

  Future<void> _exportToExcel() async {
    try {
      if (filteredMeals.isEmpty) {
        showAppSnackBar(context, 'لا توجد بيانات لتصديرها');
        return;
      }

      final columns = ['اسم المشترك', 'نوع الوجبة', 'التاريخ', 'التكلفة'];
      final rows = filteredMeals
          .map((row) => [
                row['name']?.toString() ?? '',
                row['meal_type']?.toString() ?? '',
                row['date']?.toString() ?? '',
                Formatters.toDouble(row['final_cost']),
              ])
          .toList();

      final extraInfo = <String, String>{
        'نوع التقرير': isArchived ? 'تقرير الوجبات (مؤرشف)' : 'تقرير الوجبات (الشهر الحالي)',
        'تاريخ التصدير': DateTime.now().toString().substring(0, 19),
        'عدد السجلات': '${filteredMeals.length}',
      };

      if (isArchived && archiveName.isNotEmpty) {
        extraInfo['الأرشيف'] = archiveName;
        extraInfo['الفترة'] = '$startDate إلى $endDate';
      }

      final totals = [
        ['إجمالي التكلفة', '', '', totalCost],
      ];

      final title = isArchived
          ? 'تقرير_الوجبات_أرشيف_${widget.archiveKeyId}'
          : 'تقرير_الوجبات_الشهر_الحالي';

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
      title: isArchived ? 'تقرير الوجبات (مؤرشف)' : 'تقرير الوجبات',
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

                    // Info banner
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: Colors.blue.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.blue.shade200),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.info_outline, color: Colors.blue, size: 20),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              '💡 اضغط على أي وجبة في الجدول لعرض مكوناتها والتكلفة المحسوبة لهذا المشترك بالتفصيل.',
                              style: TextStyle(fontSize: 13, color: Colors.blue),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Filter Card
                    Card(
                      elevation: 2,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      child: Padding(
                        padding: const EdgeInsets.all(12.0),
                        child: Wrap(
                          spacing: 14,
                          runSpacing: 10,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            // Meal Type
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Text('النوع: ', style: TextStyle(fontWeight: FontWeight.bold)),
                                DropdownButton<String>(
                                  value: _selectedMealType,
                                  items: ['الكل', 'فطار', 'غداء', 'عشاء'].map((t) {
                                    return DropdownMenuItem(value: t, child: Text(t));
                                  }).toList(),
                                  onChanged: (val) {
                                    setState(() {
                                      _selectedMealType = val ?? 'الكل';
                                      _applyFilters();
                                    });
                                  },
                                ),
                              ],
                            ),

                            // Member Name
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Text('المشترك: ', style: TextStyle(fontWeight: FontWeight.bold)),
                                DropdownButton<String>(
                                  value: _selectedMember ?? 'الكل',
                                  items: _memberOptions.map((m) {
                                    return DropdownMenuItem(value: m, child: Text(m));
                                  }).toList(),
                                  onChanged: (val) {
                                    setState(() {
                                      _selectedMember = val;
                                      _applyFilters();
                                    });
                                  },
                                ),
                              ],
                            ),

                            // Date Range Pickers
                            TextButton.icon(
                              icon: const Icon(Icons.date_range, size: 18),
                              label: Text(_filterStartDate == null
                                  ? 'من تاريخ'
                                  : _filterStartDate.toString().substring(0, 10)),
                              onPressed: () async {
                                final d = await showDatePicker(
                                  context: context,
                                  initialDate: _filterStartDate ?? DateTime.now(),
                                  firstDate: DateTime(2020),
                                  lastDate: DateTime(2035),
                                );
                                if (d != null) {
                                  setState(() {
                                    _filterStartDate = d;
                                    _applyFilters();
                                  });
                                }
                              },
                            ),
                            TextButton.icon(
                              icon: const Icon(Icons.date_range, size: 18),
                              label: Text(_filterEndDate == null
                                  ? 'إلى تاريخ'
                                  : _filterEndDate.toString().substring(0, 10)),
                              onPressed: () async {
                                final d = await showDatePicker(
                                  context: context,
                                  initialDate: _filterEndDate ?? DateTime.now(),
                                  firstDate: DateTime(2020),
                                  lastDate: DateTime(2035),
                                );
                                if (d != null) {
                                  setState(() {
                                    _filterEndDate = d;
                                    _applyFilters();
                                  });
                                }
                              },
                            ),
                            if (_filterStartDate != null || _filterEndDate != null)
                              IconButton(
                                icon: const Icon(Icons.clear, color: Colors.red),
                                tooltip: 'إلغاء فلترة التاريخ',
                                onPressed: () {
                                  setState(() {
                                    _filterStartDate = null;
                                    _filterEndDate = null;
                                    _applyFilters();
                                  });
                                },
                              ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Table
                    if (filteredMeals.isEmpty)
                      const Padding(
                        padding: EdgeInsets.all(32.0),
                        child: Text(
                          'لا توجد وجبات تطابق الفلاتر المحددة!',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                      )
                    else
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: DataTable(
                          columnSpacing: 22,
                          showCheckboxColumn: !isArchived,
                          onSelectAll: isArchived
                              ? null
                              : (bool? isAllSelected) {
                                  setState(() {
                                    if (isAllSelected == true) {
                                      selectedMealIds = filteredMeals
                                          .map((m) => m['meal_record_id'] as int)
                                          .toSet();
                                    } else {
                                      selectedMealIds.clear();
                                    }
                                  });
                                },
                          headingRowColor: WidgetStateProperty.all(const Color(0xFF1E4C54)),
                          headingTextStyle: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontFamily: 'Cairo',
                          ),
                          columns: const [
                            DataColumn(label: Text('اسم المشترك')),
                            DataColumn(label: Text('نوع الوجبة')),
                            DataColumn(label: Text('التاريخ')),
                            DataColumn(label: Text('التكلفة')),
                            DataColumn(label: Text('المكونات')),
                          ],
                          rows: filteredMeals.map((row) {
                            final recId = row['meal_record_id'] as int;
                            final isSelected = selectedMealIds.contains(recId);
                            final cost = Formatters.toDouble(row['final_cost']);

                            return DataRow(
                              selected: isSelected,
                              onSelectChanged: isArchived
                                  ? null
                                  : (sel) {
                                      setState(() {
                                        if (sel == true) {
                                          selectedMealIds.add(recId);
                                        } else {
                                          selectedMealIds.remove(recId);
                                        }
                                      });
                                    },
                              cells: [
                                DataCell(
                                  Text(row['name']?.toString() ?? '', style: textStyle),
                                  onTap: () => _showMealDetails(row),
                                ),
                                DataCell(
                                  Text(row['meal_type']?.toString() ?? '', style: textStyle),
                                  onTap: () => _showMealDetails(row),
                                ),
                                DataCell(
                                  Text(row['date']?.toString() ?? '', style: textStyle),
                                  onTap: () => _showMealDetails(row),
                                ),
                                DataCell(
                                  Text('${cost.toAppString()} ج', style: textStyle),
                                  onTap: () => _showMealDetails(row),
                                ),
                                DataCell(
                                  ElevatedButton.icon(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.orange.shade50,
                                      foregroundColor: Colors.orange.shade900,
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 10, vertical: 4),
                                      elevation: 0,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(8),
                                        side: BorderSide(color: Colors.orange.shade300),
                                      ),
                                    ),
                                    icon: const Icon(Icons.receipt_long, size: 16),
                                    label: const Text('المكونات', style: TextStyle(fontSize: 12)),
                                    onPressed: () => _showMealDetails(row),
                                  ),
                                ),
                              ],
                            );
                          }).toList(),
                        ),
                      ),
                    const SizedBox(height: 20),

                    // Meal Counts & Total
                    Wrap(
                      spacing: 14,
                      runSpacing: 10,
                      alignment: WrapAlignment.center,
                      children: [
                        _buildCounterCard('فطار', breakfastCount, Colors.teal),
                        _buildCounterCard('غداء', lunchCount, Colors.orange),
                        _buildCounterCard('عشاء', dinnerCount, Colors.indigo),
                        _buildCounterCard(
                          'إجمالي التكلفة',
                          totalCost,
                          Colors.green,
                          isCurrency: true,
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // Actions
                    if (!isArchived && selectedMealIds.isNotEmpty && AuthService.instance.canDelete)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 16.0),
                        child: createButton(
                          text: 'حذف الوجبات المحددة (${selectedMealIds.length})',
                          onPressed: _deleteSelectedMeals,
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
                ),
              ),
            ),
    );
  }

  Widget _buildCounterCard(String title, num value, MaterialColor color,
      {bool isCurrency = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
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
          Text(title, style: TextStyle(fontSize: 13, color: color.shade800)),
          const SizedBox(height: 2),
          Text(
            isCurrency ? '${value.toAppString()} ج.م' : '$value',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: color.shade900,
            ),
          ),
        ],
      ),
    );
  }
}
