import 'package:flutter/material.dart';
import '../../utils/database.dart';
import '../../utils/button_utils.dart';
import '../../utils/background_scaffold.dart';
import '../../utils/excel_export.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/snackbar_utils.dart';
import '../../services/auth_service.dart';
import '../../utils/helpers.dart' as helpers;

class DrinksReportPage extends StatefulWidget {
  final DatabaseManager db;
  final int? archiveKeyId;

  const DrinksReportPage({
    super.key,
    required this.db,
    this.archiveKeyId,
  });

  @override
  State<DrinksReportPage> createState() => _DrinksReportPageState();
}

class _DrinksReportPageState extends State<DrinksReportPage> {
  final TextStyle textStyle = const TextStyle(fontSize: 14, fontFamily: 'Cairo');

  List<Map<String, dynamic>> drinks = [];
  List<Map<String, dynamic>> filteredDrinks = [];
  Map<String, int> drinkQuantities = {};
  Set<int> selectedDrinkIds = {};

  double totalCost = 0.0;
  bool _loading = true;

  String archiveName = '';
  String startDate = '';
  String endDate = '';

  // Filters
  String? _selectedMember;
  String? _selectedDrink;
  DateTime? _filterStartDate;
  DateTime? _filterEndDate;

  List<String> _memberOptions = ['الكل'];
  List<String> _drinkOptions = ['الكل'];

  bool get isArchived => widget.archiveKeyId != null;

  @override
  void initState() {
    super.initState();
    _fetchDrinksData();
  }

  Future<void> _fetchDrinksData() async {
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
          SELECT dr.drink_record_id, m.name, dr.drink_name, dr.quantity, dr.date, dr.total_cost
          FROM drink_records_archive dr
          JOIN members_archive m ON dr.member_id = m.member_id
          WHERE dr.archive_key_id = ?
          ORDER BY dr.date DESC, dr.drink_record_id DESC
        ''';
        drinks = await widget.db.fetchAll(query, [widget.archiveKeyId]);
      } else {
        const query = '''
          SELECT dr.drink_record_id, m.name, dr.drink_name, dr.quantity, dr.date, dr.total_cost
          FROM drink_records dr
          JOIN members m ON dr.member_id = m.member_id
          ORDER BY dr.date DESC, dr.drink_record_id DESC
        ''';
        drinks = await widget.db.fetchAll(query);
      }

      final distinctMembers = drinks
          .map((d) => d['name']?.toString() ?? '')
          .where((n) => n.isNotEmpty)
          .toSet()
          .toList()
        ..sort();
      _memberOptions = ['الكل', ...distinctMembers];

      final distinctDrinks = drinks
          .map((d) => d['drink_name']?.toString() ?? '')
          .where((n) => n.isNotEmpty)
          .toSet()
          .toList()
        ..sort();
      _drinkOptions = ['الكل', ...distinctDrinks];

      _applyFilters();
    } catch (e) {
      if (mounted) {
        showAppSnackBar(context, 'خطأ أثناء جلب تقرير المشروبات: $e', isError: true);
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _applyFilters() {
    List<Map<String, dynamic>> result = drinks;

    if (_selectedMember != null && _selectedMember != 'الكل') {
      result = result.where((d) => d['name'] == _selectedMember).toList();
    }

    if (_selectedDrink != null && _selectedDrink != 'الكل') {
      result = result.where((d) => d['drink_name'] == _selectedDrink).toList();
    }

    if (_filterStartDate != null) {
      result = result.where((d) {
        final dt = DateTime.tryParse(d['date']?.toString() ?? '');
        return dt != null && !dt.isBefore(_filterStartDate!);
      }).toList();
    }

    if (_filterEndDate != null) {
      result = result.where((d) {
        final dt = DateTime.tryParse(d['date']?.toString() ?? '');
        return dt != null && !dt.isAfter(_filterEndDate!);
      }).toList();
    }

    filteredDrinks = result;

    drinkQuantities.clear();
    for (final d in filteredDrinks) {
      final name = d['drink_name']?.toString() ?? 'مشروب';
      final qty = Formatters.toInt(d['quantity']);
      drinkQuantities[name] = (drinkQuantities[name] ?? 0) + qty;
    }

    totalCost = filteredDrinks.fold(
      0.0,
      (sum, item) => sum + Formatters.toDouble(item['total_cost']),
    );
  }

  Future<void> _deleteSelectedDrinks() async {
    if (selectedDrinkIds.isEmpty) {
      showAppSnackBar(context, 'لم يتم اختيار أي سجل مشروبات للحذف!');
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: const Text('تأكيد الحذف'),
          content: Text('هل أنت متأكد من حذف ${selectedDrinkIds.length} سجل مشروبات؟'),
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
      for (final recId in selectedDrinkIds) {
        await helpers.Helpers.reverseDrinkEffects(recId);
      }

      if (mounted) {
        showAppSnackBar(context, 'تم حذف سجلات المشروبات المحددة بنجاح');
      }
      selectedDrinkIds.clear();
      await _fetchDrinksData();
    } catch (e) {
      if (mounted) {
        showAppSnackBar(context, 'خطأ أثناء حذف سجلات المشروبات: $e', isError: true);
      }
    }
  }

  Future<void> _exportToExcel() async {
    try {
      if (filteredDrinks.isEmpty) {
        showAppSnackBar(context, 'لا توجد بيانات لتصديرها');
        return;
      }

      final columns = ['اسم المشترك', 'المشروب', 'العدد', 'التاريخ', 'التكلفة'];
      final rows = filteredDrinks
          .map((row) => [
                row['name']?.toString() ?? '',
                row['drink_name']?.toString() ?? '',
                Formatters.toInt(row['quantity']),
                row['date']?.toString() ?? '',
                Formatters.toDouble(row['total_cost']),
              ])
          .toList();

      final extraInfo = <String, String>{
        'نوع التقرير': isArchived ? 'تقرير المشروبات (مؤرشف)' : 'تقرير المشروبات (الشهر الحالي)',
        'تاريخ التصدير': DateTime.now().toString().substring(0, 19),
        'إجمالي السجلات': '${filteredDrinks.length}',
      };

      if (isArchived && archiveName.isNotEmpty) {
        extraInfo['الأرشيف'] = archiveName;
        extraInfo['الفترة'] = '$startDate إلى $endDate';
      }

      final totals = [
        ['إجمالي التكلفة', '', '', '', totalCost],
      ];

      final title = isArchived
          ? 'تقرير_المشروبات_أرشيف_${widget.archiveKeyId}'
          : 'تقرير_المشروبات_الشهر_الحالي';

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
      title: isArchived ? 'تقرير المشروبات (مؤرشف)' : 'تقرير المشروبات',
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
                            // Drink Name Filter
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Text('المشروب: ', style: TextStyle(fontWeight: FontWeight.bold)),
                                DropdownButton<String>(
                                  value: _selectedDrink ?? 'الكل',
                                  items: _drinkOptions.map((d) {
                                    return DropdownMenuItem(value: d, child: Text(d));
                                  }).toList(),
                                  onChanged: (val) {
                                    setState(() {
                                      _selectedDrink = val;
                                      _applyFilters();
                                    });
                                  },
                                ),
                              ],
                            ),

                            // Member Name Filter
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

                            // Date Filters
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
                    if (filteredDrinks.isEmpty)
                      const Padding(
                        padding: EdgeInsets.all(32.0),
                        child: Text(
                          'لا توجد سجلات مشروبات تطابق الفلاتر!',
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
                            const DataColumn(label: Text('اسم المشترك')),
                            const DataColumn(label: Text('المشروب')),
                            const DataColumn(label: Text('العدد')),
                            const DataColumn(label: Text('التاريخ')),
                            const DataColumn(label: Text('التكلفة')),
                          ],
                          rows: filteredDrinks.map((row) {
                            final recId = row['drink_record_id'] as int;
                            final isSelected = selectedDrinkIds.contains(recId);
                            final qty = Formatters.toInt(row['quantity']);
                            final cost = Formatters.toDouble(row['total_cost']);

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
                                            selectedDrinkIds.add(recId);
                                          } else {
                                            selectedDrinkIds.remove(recId);
                                          }
                                        });
                                      },
                                    ),
                                  ),
                                DataCell(Text(row['name']?.toString() ?? '', style: textStyle)),
                                DataCell(Text(row['drink_name']?.toString() ?? '', style: textStyle)),
                                DataCell(Text('$qty', style: textStyle)),
                                DataCell(Text(row['date']?.toString() ?? '', style: textStyle)),
                                DataCell(Text('${cost.toAppString()} ج', style: textStyle)),
                              ],
                            );
                          }).toList(),
                        ),
                      ),
                    const SizedBox(height: 20),

                    // Drinks Quantities summary cards
                    if (drinkQuantities.isNotEmpty) ...[
                      const Text(
                        'إجمالي الكميات المستهلكة:',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 12,
                        runSpacing: 8,
                        alignment: WrapAlignment.center,
                        children: drinkQuantities.entries.map((entry) {
                          return Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                            decoration: BoxDecoration(
                              color: Colors.brown.shade50,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: Colors.brown.shade200),
                            ),
                            child: Text(
                              '☕ ${entry.key}: ${entry.value} كوب',
                              style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.brown.shade900,
                                  fontSize: 13),
                            ),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 16),
                    ],

                    // Total Cost card
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: const [
                          BoxShadow(color: Colors.black12, blurRadius: 6, offset: Offset(0, 2)),
                        ],
                        border: Border.all(color: Colors.green.shade300),
                      ),
                      child: Column(
                        children: [
                          const Text('إجمالي تكلفة المشروبات',
                              style: TextStyle(fontSize: 13, color: Colors.black54)),
                          const SizedBox(height: 2),
                          Text(
                            '${totalCost.toAppString()} ج.م',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.green.shade900,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Actions
                    if (!isArchived &&
                        selectedDrinkIds.isNotEmpty &&
                        AuthService.instance.canDelete)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 16.0),
                        child: createButton(
                          text: 'حذف السجلات المحددة (${selectedDrinkIds.length})',
                          onPressed: _deleteSelectedDrinks,
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
}
