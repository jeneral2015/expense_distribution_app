import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../utils/database.dart';
import '../../../utils/button_utils.dart';
import '../../../utils/background_scaffold.dart';
import '../../../utils/excel_export.dart';
import '../../../utils/undo_manager.dart';
import '../../../utils/helpers.dart' as helpers;
import '../../../services/auth_service.dart';

class MemberConsumption extends StatefulWidget {
  final DatabaseManager db;

  const MemberConsumption({
    Key? key,
    required this.db,
  }) : super(key: key);

  @override
  _MemberConsumptionState createState() => _MemberConsumptionState();
}

class _MemberConsumptionState extends State<MemberConsumption> {
  final TextStyle textStyle = const TextStyle(
    fontSize: 15,
    fontFamily: 'Cairo',
  );
  final TextStyle titleStyle = const TextStyle(
    fontSize: 28,
    fontWeight: FontWeight.bold,
    fontFamily: 'Cairo',
  );

  List<Map<String, dynamic>> subscribers = [];
  String? selectedSubscriberId;
  List<Map<String, dynamic>> consumption = [];
  List<Map<String, dynamic>> filteredConsumption = [];
  double totalCost = 0.0;

  // Selection and filtering
  Set<int> selectedRecords = {};
  bool selectAll = false;
  TextEditingController searchController = TextEditingController();
  DateTime? startDate;
  DateTime? endDate;

  @override
  void initState() {
    super.initState();
    _fetchSubscribers();
    searchController.addListener(_applyFilters);
  }

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
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

  Future<void> _fetchSubscribers() async {
    try {
      // جلب البيانات مع الترتيب حسب الرتبة
      final subscribersData = await widget.db.fetchAll('''
        SELECT member_id, name, rank 
        FROM members 
        ORDER BY 
          CASE rank
            WHEN 'لواء' THEN 0
            WHEN 'عميد' THEN 1
            WHEN 'عقيد' THEN 2
            WHEN 'مقدم' THEN 3
            WHEN 'رائد' THEN 4
            WHEN 'نقيب' THEN 5
            WHEN 'ملازم أول' THEN 6
            WHEN 'ملازم' THEN 7
            ELSE 8
          END,
          name ASC
      ''');

      setState(() {
        subscribers = subscribersData;
      });
    } catch (e) {
      showSnackBar('خطأ أثناء جلب بيانات المشتركين: $e');
    }
  }

  Future<void> _fetchConsumptionData(String subscriberId) async {
    try {
      const query = '''
        SELECT mr.meal_record_id as record_id, 'meal' as record_type,
               m.name, 
               COALESCE(mr.meal_type, 'غير محدد') as item, 
               COALESCE(mr.final_cost, 0) as cost, 
               mr.date
        FROM meal_records mr
        JOIN members m ON mr.member_id = m.member_id
        WHERE mr.member_id = ?
        UNION ALL
        SELECT dr.drink_record_id as record_id, 'drink' as record_type,
               m.name, 
               dr.drink_name as item, 
               dr.total_cost as cost, 
               dr.date
        FROM drink_records dr
        JOIN members m ON dr.member_id = m.member_id
        WHERE dr.member_id = ?
        UNION ALL
        SELECT mc.misc_contribution_id as record_id, 'misc' as record_type,
               m.name, 
               'نثريات' as item, 
               mc.misc_amount as cost, 
               mc.distribution_date as date
        FROM miscellaneous_contributions mc
        JOIN members m ON mc.member_id = m.member_id
        WHERE mc.member_id = ?
      ''';
      final consumptionData = await widget.db.fetchAll(
        query,
        [subscriberId, subscriberId, subscriberId],
      );

      if (consumptionData.isEmpty) {
        showSnackBar('لا توجد بيانات لهذا المشترك في هذا الشهر!');
        return;
      }

      setState(() {
        consumption = consumptionData;
        filteredConsumption = consumptionData;
        totalCost = consumption.fold(
            0.0, (sum, item) => sum + (item['cost'] as num).toDouble());
        _applyFilters();
      });
    } catch (e) {
      showSnackBar('خطأ أثناء جلب تقرير المشترك: $e');
    }
  }

  void _applyFilters() {
    List<Map<String, dynamic>> filtered = consumption;

    // Apply search filter
    final searchText = searchController.text.toLowerCase();
    if (searchText.isNotEmpty) {
      filtered = filtered.where((record) {
        final itemName = (record['item'] as String).toLowerCase();
        return itemName.contains(searchText);
      }).toList();
    }

    // Apply date filter
    if (startDate != null && endDate != null) {
      filtered = filtered.where((record) {
        final recordDate = DateTime.parse(record['date'] as String);
        return recordDate.isAfter(startDate!.subtract(const Duration(days: 1))) &&
               recordDate.isBefore(endDate!.add(const Duration(days: 1)));
      }).toList();
    }

    setState(() {
      filteredConsumption = filtered;
      selectedRecords.clear();
      selectAll = false;
    });
  }

  Future<void> _exportToExcel() async {
    try {
      if (consumption.isEmpty) {
        showSnackBar('لا توجد بيانات لتصديرها');
        return;
      }

      final columns = [
        'اسم المشترك',
        'البند',
        'التكلفة',
        'التاريخ',
      ];

      final rows = consumption.map((row) => [
            row['name'] as String,
            row['item'] as String,
            row['cost'] as num,
            row['date'] as String? ?? '',
          ]).toList();

      final extraInfo = <String, String>{
        'اسم التقرير': 'تقرير استهلاك مشترك',
        'اسم المشترك': consumption.isNotEmpty ? consumption[0]['name'] as String : '',
        'تاريخ التصدير': DateFormat('yyyy-MM-dd HH:mm').format(DateTime.now()),
        'رقم المشترك': selectedSubscriberId ?? '',
      };

      final totals = [
        [
          'إجمالي التكلفة',
          '',
          totalCost,
          '',
        ],
      ];

      await exportReportToExcel(
        context: context,
        reportTitle: 'تقرير_استهلاك_مشترك_${selectedSubscriberId ?? ''}',
        columns: columns,
        rows: rows,
        extraInfo: extraInfo,
        totals: totals,
      );
    } catch (e) {
      showSnackBar('خطأ أثناء تصدير التقرير: $e');
    }
  }

  void _showDeleteConfirmationDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('تأكيد الحذف', style: textStyle),
        content: Text(
          'هل أنت متأكد من حذف ${selectedRecords.length} سجل؟',
          style: textStyle,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('إلغاء', style: textStyle),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _deleteSelectedRecords();
            },
            child: Text('حذف', style: textStyle.copyWith(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _showEditDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('تعديل السجلات المختارة', style: textStyle),
        content: Text(
          'هذه الميزة قيد التطوير. سيتم إضافتها في تحديثات قادمة.',
          style: textStyle,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('موافق', style: textStyle),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteSelectedRecords() async {
    try {
      if (selectedRecords.isEmpty) {
        showSnackBar('لم يتم اختيار أي سجلات للحذف');
        return;
      }

      final dbManager = widget.db;
      final mealRecordIds = <int>[];
      final drinkRecordIds = <int>[];
      final miscContributionIds = <int>[];

      for (final index in selectedRecords) {
        final record = filteredConsumption[index];
        final recordType = record['record_type'] as String;
        final recordId = record['record_id'] as int;

        if (recordType == 'meal') {
          mealRecordIds.add(recordId);
        } else if (recordType == 'drink') {
          drinkRecordIds.add(recordId);
        } else if (recordType == 'misc') {
          miscContributionIds.add(recordId);
        }
      }

      // Reverse meal effects by meal_id
      final mealIdsToReverse = <int>{};
      for (final mealRecordId in mealRecordIds) {
        final mealId = await dbManager.getMealIdForRecord(mealRecordId);
        if (mealId != null) {
          mealIdsToReverse.add(mealId);
        }
      }

      for (final mealId in mealIdsToReverse) {
        final success = await helpers.Helpers.reverseMealEffects(dbManager, mealId);
        if (!success) {
          showSnackBar('فشل في عكس تأثيرات الوجبة $mealId');
          return;
        }
      }

      // Reverse drink effects
      for (final drinkRecordId in drinkRecordIds) {
        final success = await helpers.Helpers.reverseDrinkEffects(drinkRecordId);
        if (!success) {
          showSnackBar('فشل في عكس تأثيرات المشروب $drinkRecordId');
          return;
        }
      }

      // Reverse misc contributions
      for (final miscId in miscContributionIds) {
        final success = await helpers.Helpers.reverseMiscEffects(miscId);
        if (!success) {
          showSnackBar('فشل في عكس تأثيرات النثريات $miscId');
          return;
        }
      }

      setState(() {
        selectedRecords.clear();
        selectAll = false;
      });

      if (selectedSubscriberId != null) {
        await _fetchConsumptionData(selectedSubscriberId!);
      }

      final undoManager = UndoManager();
      undoManager.showUndoSnackbar(
        context,
        'تم حذف ${selectedRecords.length} سجل',
        () {
          showSnackBar('ميزة التراجع قيد التطوير');
        },
      );
    } catch (e) {
      showSnackBar('خطأ أثناء محاولة الحذف: $e');
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
                      'تقرير استهلاك مشترك',
                      style: titleStyle.copyWith(color: Colors.black),
                      textAlign: TextAlign.center,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 20),

                    // --- قائمة اختيار المشترك ---
                    SizedBox(
                      width: 300,
                      child: DropdownButtonFormField<String>(
                        decoration: InputDecoration(
                          labelText: 'اختر المشترك',
                          labelStyle: textStyle.copyWith(color: Colors.white),
                          filled: true,
                          fillColor: Colors.black.withOpacity(0.7),
                          border: OutlineInputBorder(
                            borderSide: BorderSide(color: Colors.blue[700]!),
                          ),
                          alignLabelWithHint: true,
                        ),
                        value: selectedSubscriberId,
                        isExpanded: true,
                        items: subscribers.asMap().entries.map((entry) {
                          final index = entry.key + 1;
                          final subscriber = entry.value;
                          final memberId = subscriber['member_id'].toString();
                          final name = subscriber['name'] as String;
                          final rank = subscriber['rank'] as String? ?? '';

                          final displayText = '\u200f$index. $rank $name';


                          return DropdownMenuItem<String>(
                            value: memberId,
                            child: Container(
                              alignment: Alignment.centerRight,
                              padding: const EdgeInsets.symmetric(horizontal: 8.0),
                              child: Text(
                                displayText,
                                style: textStyle.copyWith(color: Colors.black),
                                textAlign: TextAlign.right,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          );
                        }).toList(),
                        onChanged: (value) {
                          setState(() {
                            selectedSubscriberId = value;
                            consumption = [];
                            totalCost = 0.0;
                            filteredConsumption = [];
                            searchController.clear();
                            startDate = null;
                            endDate = null;
                            selectedRecords.clear();
                            selectAll = false;
                          });
                          if (value != null) {
                            _fetchConsumptionData(value);
                          }
                        },
                      ),
                    ),

                    const SizedBox(height: 20),

                    // --- كارت الفلاتر ---
                    if (consumption.isNotEmpty)
                    SizedBox(
                      width: 300,
                      child:  Card(
                        elevation: 2,
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            children: [
                              TextField(
                                controller: searchController,
                                decoration: InputDecoration(
                                  labelText: 'بحث في البند',
                                  labelStyle: textStyle,
                                  prefixIcon: const Icon(Icons.search),
                                  border: const OutlineInputBorder(),
                                ),
                                style: textStyle,
                              ),
                              const SizedBox(height: 16),
                              Row(
                                children: [
                                  Expanded(
                                    child: TextButton(
                                      onPressed: () async {
                                        final pickedDate = await showDatePicker(
                                          context: context,
                                          initialDate: startDate ?? DateTime.now(),
                                          firstDate: DateTime(2020),
                                          lastDate: DateTime.now(),
                                        );
                                        if (pickedDate != null) {
                                          setState(() {
                                            startDate = pickedDate;
                                            _applyFilters();
                                          });
                                        }
                                      },
                                      child: Text(
                                        startDate == null
                                            ? 'اختر تاريخ البداية'
                                            : DateFormat('yyyy-MM-dd').format(startDate!),
                                        style: textStyle,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: TextButton(
                                      onPressed: () async {
                                        final pickedDate = await showDatePicker(
                                          context: context,
                                          initialDate: endDate ?? DateTime.now(),
                                          firstDate: DateTime(2020),
                                          lastDate: DateTime.now(),
                                        );
                                        if (pickedDate != null) {
                                          setState(() {
                                            endDate = pickedDate;
                                            _applyFilters();
                                          });
                                        }
                                      },
                                      child: Text(
                                        endDate == null
                                            ? 'اختر تاريخ النهاية'
                                            : DateFormat('yyyy-MM-dd').format(endDate!),
                                        style: textStyle,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              if (startDate != null || endDate != null || searchController.text.isNotEmpty)
                                createButton(
                                  text: 'مسح الفلاتر',
                                  onPressed: () {
                                    setState(() {
                                      searchController.clear();
                                      startDate = null;
                                      endDate = null;
                                      _applyFilters();
                                    });
                                  },
                                  bgColor: Colors.grey[700]!,
                                  textColor: Colors.white,
                                  width: double.infinity,
                                  height: 40,
                                  icon: Icons.clear,
                                  iconColor: Colors.white,
                                ),
                            ],
                          ),
                        ),
                      ),
                  ),
                    const SizedBox(height: 20),

                    // --- عدد السجلات المختارة ---
                    if (consumption.isNotEmpty && selectedRecords.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                        decoration: BoxDecoration(
                          color: Colors.blue[100],
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '${selectedRecords.length} سجل مختار',
                          style: textStyle.copyWith(color: Colors.blue[800]),
                        ),
                      ),

                    const SizedBox(height: 20),

                    // --- أزرار تعديل/حذف ---
                    if (consumption.isNotEmpty && selectedRecords.isNotEmpty)
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        alignment: WrapAlignment.center,
                        children: [
                          if (AuthService.instance.canDelete) ...[
                            createButton(
                              text: 'حذف المختار',
                              onPressed: () => _showDeleteConfirmationDialog(),
                              bgColor: Colors.red[700]!,
                              textColor: Colors.white,
                              width: 150,
                              height: 40,
                              icon: Icons.delete,
                              iconColor: Colors.white,
                            ),
                          ],
                          if (AuthService.instance.canEdit) ...[
                            createButton(
                              text: 'تعديل المختار',
                              onPressed: () => _showEditDialog(),
                              bgColor: Colors.orange[700]!,
                              textColor: Colors.white,
                              width: 150,
                              height: 40,
                              icon: Icons.edit,
                              iconColor: Colors.white,
                            ),
                          ],
                        ],
                      ),

                    const SizedBox(height: 20),

                    // --- الجدول ---
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
                                  child: Checkbox(
                                    value: selectAll,
                                    onChanged: (value) {
                                      setState(() {
                                        selectAll = value ?? false;
                                        selectedRecords = selectAll
                                            ? Set<int>.from(
                                                Iterable.generate(filteredConsumption.length))
                                            : <int>{};
                                      });
                                    },
                                  ),
                                ),
                              ),
                              DataColumn(
                                label: Container(
                                  alignment: Alignment.center,
                                  child: Text('اسم المشترك',
                                      style: textStyle.copyWith(color: Colors.white)),
                                ),
                              ),
                              DataColumn(
                                label: Container(
                                  alignment: Alignment.center,
                                  child: Text('البند',
                                      style: textStyle.copyWith(color: Colors.white)),
                                ),
                              ),
                              DataColumn(
                                label: Container(
                                  alignment: Alignment.center,
                                  child: Text('التكلفة',
                                      style: textStyle.copyWith(color: Colors.white)),
                                ),
                              ),
                              DataColumn(
                                label: Container(
                                  alignment: Alignment.center,
                                  child: Text('التاريخ',
                                      style: textStyle.copyWith(color: Colors.white)),
                                ),
                              ),
                            ],
                            rows: filteredConsumption.asMap().entries.map((entry) {
                              final index = entry.key;
                              final row = entry.value;
                              final isSelected = selectedRecords.contains(index);

                              return DataRow(
                                selected: isSelected,

                                cells: [
                                  DataCell(
                                    Container(
                                      alignment: Alignment.center,
                                      child: Checkbox(
                                        value: isSelected,
                                        onChanged: (selected) {
                                          setState(() {
                                            if (selected ?? false) {
                                              selectedRecords.add(index);
                                            } else {
                                              selectedRecords.remove(index);
                                            }
                                            selectAll = selectedRecords.length == filteredConsumption.length;
                                          });
                                        },
                                      ),
                                    ),
                                  ),
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
                                      child: Text(
                                        row['cost'].toStringAsFixed(2),
                                        style: textStyle,
                                      ),
                                    ),
                                  ),
                                  DataCell(
                                    Container(
                                      alignment: Alignment.center,
                                      child: Text(
                                        row['date'] as String? ?? '',
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

                    if (consumption.isNotEmpty) const SizedBox(height: 20),

                    // --- إجمالي التكلفة ---
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

                    // --- أزرار العمل ---
                    Wrap(
                      spacing: 10,
                      runSpacing: 20,
                      alignment: WrapAlignment.center,
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
                        createButton(
                          text: 'رجوع',
                          onPressed: () {
                            if (selectedSubscriberId != null) {
                              // إعادة تعيين الاختيار
                              setState(() {
                                selectedSubscriberId = null;
                                consumption = [];
                                totalCost = 0.0;
                                filteredConsumption = [];
                                searchController.clear();
                                startDate = null;
                                endDate = null;
                                selectedRecords.clear();
                                selectAll = false;
                              });
                            } else {
                              // العودة للخلف
                              Navigator.pop(context);
                            }
                          },
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

            // زر الصفحة الرئيسية
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