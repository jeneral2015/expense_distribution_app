import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../utils/database.dart';
import '../../../utils/button_utils.dart';
import '../../../utils/background_scaffold.dart';
import '../../../utils/excel_export.dart';
import '../../../utils/undo_manager.dart';
import '../../../utils/helpers.dart' as helpers;
import '../../../services/auth_service.dart';

class MealsReport extends StatefulWidget {
  final DatabaseManager db;

  const MealsReport({
    Key? key,
    required this.db,
  }) : super(key: key);

  @override
  _MealsReportState createState() => _MealsReportState();
}

class _MealsReportState extends State<MealsReport> {
  final TextStyle textStyle = const TextStyle(
    fontSize: 15,
    fontFamily: 'Cairo',
  );
  final TextStyle titleStyle = const TextStyle(
    fontSize: 28,
    fontWeight: FontWeight.bold,
    fontFamily: 'Cairo',
  );

  static const Map<String, int> mealOrder = {
    'فطار': 1,
    'غداء': 2,
    'عشاء': 3,
  };

  List<Map<String, dynamic>> meals = [];
  List<Map<String, dynamic>> filteredMeals = [];
  Set<int> selectedMealIds = {};
  double totalCost = 0.0;
  int breakfastCount = 0;
  int lunchCount = 0;
  int dinnerCount = 0;

  // Filter controllers
  // Replace free-text member search with dropdown member filter
  String? _selectedMemberFilter;
  String _selectedMealType = 'الكل';
  DateTime? _startDate;
  DateTime? _endDate;

  @override
  void initState() {
    super.initState();
    _fetchMealsData();
    _applyFilters();
  }

  @override
  void dispose() {
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

  Future<void> _fetchMealsData() async {
    try {
      // Check if month is closed
      final now = DateTime.now();
      final closures = await widget.db.fetchAll(
        "SELECT * FROM monthly_closures WHERE strftime('%Y', closure_date) = ? AND strftime('%m', closure_date) = ?",
        [now.year.toString(), now.month.toString().padLeft(2, '0')],
      );
      if (closures.isNotEmpty) {
        showSnackBar('الشهر مغلق، لا توجد بيانات متاحة لهذا الشهر!');
        return;
      }

      // Fetch all meal records (legacy and new)
      // First check if the columns exist in the table
      final tableInfo = await widget.db.fetchAll("PRAGMA table_info('meal_records')");
      final hasMealId = tableInfo.any((col) => col['name'] == 'meal_id');
      final hasIsLegacy = tableInfo.any((col) => col['name'] == 'is_legacy');
      
      String query;
      if (hasMealId && hasIsLegacy) {
        query = '''
          SELECT mr.meal_record_id, m.name, mr.meal_type, mr.date, mr.final_cost,
                 mr.meal_id, mr.is_legacy
          FROM meal_records mr
          JOIN members m ON mr.member_id = m.member_id
        ''';
      } else if (hasMealId) {
        query = '''
          SELECT mr.meal_record_id, m.name, mr.meal_type, mr.date, mr.final_cost,
                 mr.meal_id, 1 as is_legacy
          FROM meal_records mr
          JOIN members m ON mr.member_id = m.member_id
        ''';
      } else if (hasIsLegacy) {
        query = '''
          SELECT mr.meal_record_id, m.name, mr.meal_type, mr.date, mr.final_cost,
                 NULL as meal_id, mr.is_legacy
          FROM meal_records mr
          JOIN members m ON mr.member_id = m.member_id
        ''';
      } else {
        query = '''
          SELECT mr.meal_record_id, m.name, mr.meal_type, mr.date, mr.final_cost,
                 NULL as meal_id, 1 as is_legacy
          FROM meal_records mr
          JOIN members m ON mr.member_id = m.member_id
        ''';
      }
      final mealsData = await widget.db.fetchAll(query);

      if (mealsData.isEmpty) {
        showSnackBar('لا توجد بيانات وجبات في قاعدة البيانات!');
        return;
      }

      // Make a mutable copy of the data
      List<Map<String, dynamic>> mutableMealsData = List.from(mealsData);

      int breakfast = 0;
      int lunch = 0;
      int dinner = 0;
      for (var row in mutableMealsData) {
        final mealType = row['meal_type'] as String;
        if (mealType == 'فطار') {
          breakfast++;
        } else if (mealType == 'غداء') lunch++;
        else if (mealType == 'عشاء') dinner++;
      }

      // Sort meals by date ascending, then by meal type
      mutableMealsData.sort((a, b) {
        final dateA = DateTime.parse(a['date']);
        final dateB = DateTime.parse(b['date']);
        final cmp = dateA.compareTo(dateB);
        if (cmp != 0) return cmp;
        final typeA = a['meal_type'];
        final typeB = b['meal_type'];
        final orderA = mealOrder[typeA] ?? 4;
        final orderB = mealOrder[typeB] ?? 4;
        return orderA.compareTo(orderB);
      });

      setState(() {
        meals = mutableMealsData;
        filteredMeals = mutableMealsData;
        totalCost = meals.fold(
            0.0, (sum, item) => sum + ((item['final_cost'] as num?)?.toDouble() ?? 0.0));
        breakfastCount = breakfast;
        lunchCount = lunch;
        dinnerCount = dinner;
      });
    } catch (e) {
      showSnackBar('خطأ أثناء جلب تقرير الوجبات: $e');
    }
  }

  void _applyFilters() {
    final memberFilter = _selectedMemberFilter;
    final mealTypeFilter = _selectedMealType == 'الكل' ? null : _selectedMealType;

    setState(() {
      filteredMeals = meals.where((meal) {
        if (memberFilter != null && meal['name'] != memberFilter) {
          return false;
        }
        if (mealTypeFilter != null && meal['meal_type'] != mealTypeFilter) {
          return false;
        }
        if (_startDate != null || _endDate != null) {
          final mealDate = DateTime.parse(meal['date'] as String);
          if (_startDate != null && mealDate.isBefore(_startDate!)) {
            return false;
          }
          if (_endDate != null && mealDate.isAfter(_endDate!)) {
            return false;
          }
        }
        return true;
      }).toList();

      // Sort filtered meals by date ascending, then by meal type
      filteredMeals.sort((a, b) {
        final dateA = DateTime.parse(a['date']);
        final dateB = DateTime.parse(b['date']);
        final cmp = dateA.compareTo(dateB);
        if (cmp != 0) return cmp;
        final typeA = a['meal_type'];
        final typeB = b['meal_type'];
        final orderA = mealOrder[typeA] ?? 4;
        final orderB = mealOrder[typeB] ?? 4;
        return orderA.compareTo(orderB);
      });

      if (filteredMeals.isEmpty && meals.isNotEmpty) {
        showSnackBar('لا توجد بيانات مطابقة للفلاتر، جرب تغيير الفلاتر');
      }
    });
  }

  void _selectAll(bool? selected) {
    setState(() {
      if (selected == true) {
        selectedMealIds = Set.from(filteredMeals.map((m) => m['meal_record_id'] as int));
      } else {
        selectedMealIds.clear();
      }
    });
  }

  Future<void> _deleteSelectedMeals() async {
    if (selectedMealIds.isEmpty) {
      showSnackBar('لم يتم اختيار أي وجبات للحذف!');
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('تأكيد الحذف'),
        content: Text(
          'هل أنت متأكد من حذف ${selectedMealIds.length} وجبة؟',
          style: textStyle,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('إلغاء'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('حذف'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        // Store data for undo before deletion
        final List<Map<String, dynamic>> mealsToDelete = [];
        for (var mealRecordId in selectedMealIds) {
          final meal = meals.firstWhere((m) => m['meal_record_id'] == mealRecordId);
          mealsToDelete.add(Map.from(meal));
        }

        await widget.db.transaction((txn) async {
          final Map<int?, List<int>> groupedByMealId = {};
          for (var mealRecordId in selectedMealIds) {
            final meal = meals.firstWhere((m) => m['meal_record_id'] == mealRecordId);
            final mealId = meal['meal_id'] as int?;
            final isLegacy = meal['is_legacy'] as int? ?? 1;

            if (isLegacy == 1) {
              final finalCost = meal['final_cost'] as double? ?? 0.0;
              final memberIdResult = await txn.rawQuery(
                'SELECT member_id FROM meal_records WHERE meal_record_id = ?',
                [mealRecordId],
              );
              if (memberIdResult.isNotEmpty) {
                final memberId = memberIdResult.first['member_id'] as int;
                await txn.rawUpdate(
                  'UPDATE members SET total_due = total_due - ? WHERE member_id = ?',
                  [finalCost, memberId],
                );
              }
              await txn.rawDelete(
                'DELETE FROM miscellaneous_expenses WHERE meal_record_id = ?',
                [mealRecordId],
              );
              await txn.rawDelete(
                'DELETE FROM meal_records WHERE meal_record_id = ?',
                [mealRecordId],
              );
            } else {
              groupedByMealId.putIfAbsent(mealId, () => []).add(mealRecordId);
            }
          }

          for (var entry in groupedByMealId.entries) {
            final mealId = entry.key;
            final recordIds = entry.value;

            if (mealId == null) continue;

            final allRecordsResult = await txn.rawQuery(
              'SELECT COUNT(*) as count FROM meal_records WHERE meal_id = ?',
              [mealId],
            );
            final allRecordsCount = allRecordsResult.first['count'] as int? ?? 0;

            if (recordIds.length == allRecordsCount) {
          await helpers.Helpers.reverseMealEffects(txn, mealId);
          await txn.rawDelete(
            'DELETE FROM meal_records WHERE meal_id = ?',
            [mealId],
          );
          await txn.rawDelete(
            'DELETE FROM miscellaneous_expenses WHERE meal_record_id IN (SELECT meal_record_id FROM meal_records WHERE meal_id = ?)',
            [mealId],
          );
          await txn.rawDelete(
            'DELETE FROM meal_items WHERE meal_id = ?',
            [mealId],
          );
          await txn.rawDelete(
            'DELETE FROM meals WHERE meal_id = ?',
            [mealId],
          );
            } else {
              final remainingMemberIds = await txn.rawQuery(
                'SELECT member_id FROM meal_records WHERE meal_id = ? AND meal_record_id NOT IN (${recordIds.join(',')})',
                [mealId],
              ).then((res) => res.map((r) => r['member_id'] as int).toList());

              if (remainingMemberIds.isNotEmpty) {
              await helpers.Helpers.reDistributeMealCost(txn, mealId, remainingMemberIds);
            }
            for (var id in recordIds) {
              await txn.rawDelete(
                'DELETE FROM meal_records WHERE meal_record_id = ?',
                [id],
              );
              await txn.rawDelete(
                'DELETE FROM miscellaneous_expenses WHERE meal_record_id = ?',
                [id],
              );
            }
            }
          }
        });

        final undoManager = UndoManager();
        undoManager.addAction(UndoAction(
          type: 'meal_delete',
          id: -1,
          data: {
            'deleted_meals': mealsToDelete,
          },
          timestamp: DateTime.now(),
        ));

        showSnackBar('تم حذف ${selectedMealIds.length} وجبة بنجاح!');
        
        undoManager.showUndoSnackbar(
          context, 
          'تم حذف ${selectedMealIds.length} وجبة', 
          () {
            showSnackBar('ميزة التراجع قيد التطوير - سيتم إضافتها قريباً');
          }
        );

        setState(() {
          selectedMealIds.clear();
        });
        await _fetchMealsData();
      } catch (e) {
        showSnackBar('خطأ أثناء حذف الوجبات: $e');
      }
    }
  }

  Future<void> _editSelectedMeal() async {
    if (selectedMealIds.isEmpty) {
      showSnackBar('لم يتم اختيار أي وجبة للتعديل!');
      return;
    }

    if (selectedMealIds.length > 1) {
      showSnackBar('يمكن تعديل وجبة واحدة فقط في المرة الواحدة!');
      return;
    }

    showSnackBar('ميزة التعديل قيد التطوير - سيتم إضافتها قريباً');
  }

  Future<void> _exportToExcel() async {
    try {
      if (filteredMeals.isEmpty) {
        showSnackBar('لا توجد بيانات لتصديرها');
        return;
      }

      final columns = [
        'اسم المشترك',
        'نوع الوجبة',
        'التاريخ',
        'التكلفة',
      ];

      final rows = filteredMeals.map((row) => [
            row['name'] as String,
            row['meal_type'] as String,
            row['date'] as String,
            (row['final_cost'] as num?)?.toDouble() ?? 0.0,
          ]).toList();

      final extraInfo = <String, String>{
        'اسم التقرير': 'تقرير الوجبات',
        'تاريخ التصدير': DateTime.now().toString(),
        'عدد النتائج': '${filteredMeals.length} من ${meals.length}',
      };

      if (_selectedMealType != 'الكل') {
        extraInfo['نوع الوجبة'] = _selectedMealType;
      }
      if (_startDate != null) {
        extraInfo['من تاريخ'] = _startDate!.toString().substring(0, 10);
      }
      if (_endDate != null) {
        extraInfo['إلى تاريخ'] = _endDate!.toString().substring(0, 10);
      }

      final totals = [
        [
          'إجمالي التكلفة',
          '',
          '',
          filteredMeals.fold<double>(0.0, (sum, item) => sum + ((item['final_cost'] as num?)?.toDouble() ?? 0.0)),
        ],
      ];

      await exportReportToExcel(
        context: context,
        reportTitle: 'تقرير الوجبات',
        columns: columns,
        rows: rows,
        extraInfo: extraInfo,
        totals: totals,
      );
    } catch (e) {
      showSnackBar('خطأ أثناء تصدير التقرير: $e');
    }
  }

  Widget _buildFilters() {
    return SizedBox(
      width: 300,
      child: Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 10),
            DropdownButtonFormField<String?>(
              value: _selectedMemberFilter,
              decoration: InputDecoration(
                labelText: 'اختيار المشترك',
                labelStyle: textStyle,
                suffixIcon: _selectedMemberFilter != null
                  ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        setState(() {
                          _selectedMemberFilter = null;
                          _applyFilters();
                        });
                      },
                    )
                  : null,
              ),
              items: [
                const DropdownMenuItem<String?>(
                  value: null,
                  child: Text('الكل'),
                ),
                ...meals
                  .map((m) => m['name'] as String)
                  .toSet()
                  .map((name) => DropdownMenuItem<String?>(value: name, child: Text(name, style: textStyle)))
                  .toList(),
              ],
              onChanged: (String? newValue) {
                setState(() {
                  _selectedMemberFilter = newValue;
                  _applyFilters();
                });
              },
            ),
            const SizedBox(height: 10),
            DropdownButtonFormField<String>(
              value: _selectedMealType,
              decoration: InputDecoration(
                labelText: 'نوع الوجبة',
                labelStyle: textStyle,
              ),
              items: ['الكل', 'فطار', 'غداء', 'عشاء'].map((String value) {
                return DropdownMenuItem<String>(
                  value: value,
                  child: Text(value, style: textStyle),
                );
              }).toList(),
              onChanged: (String? newValue) {
                setState(() {
                  _selectedMealType = newValue!;
                  _applyFilters();
                });
              },
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: () async {
                      final date = await showDatePicker(
                        context: context,
                        initialDate: _startDate ?? DateTime.now(),
                        firstDate: DateTime(2000),
                        lastDate: DateTime(2100),
                      );
                      if (date != null) {
                        setState(() {
                          _startDate = date;
                          _applyFilters();
                        });
                      }
                    },
                    child: Text(
                      _startDate == null 
                        ? 'من تاريخ' 
                        : 'من: ${_startDate!.toString().substring(0, 10)}',
                      style: textStyle,
                    ),
                  ),
                ),
                Expanded(
                  child: TextButton(
                    onPressed: () async {
                      final date = await showDatePicker(
                        context: context,
                        initialDate: _endDate ?? DateTime.now(),
                        firstDate: DateTime(2000),
                        lastDate: DateTime(2100),
                      );
                      if (date != null) {
                        setState(() {
                          _endDate = date;
                          _applyFilters();
                        });
                      }
                    },
                    child: Text(
                      _endDate == null 
                        ? 'إلى تاريخ' 
                        : 'إلى: ${_endDate!.toString().substring(0, 10)}',
                      style: textStyle,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            if (_selectedMemberFilter != null ||
                _selectedMealType != 'الكل' ||
                _startDate != null ||
                _endDate != null)
              TextButton(
                onPressed: () {
                  setState(() {
                    _selectedMemberFilter = null;
                    _selectedMealType = 'الكل';
                    _startDate = null;
                    _endDate = null;
                    _applyFilters();
                  });
                },
                child: Text('مسح الفلاتر', style: textStyle),
              ),
          ],
        ),
      ),
    ),
  );
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
                      'تقرير الوجبات',
                      style: titleStyle.copyWith(color: Colors.black),
                      textAlign: TextAlign.center,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 20),
                    _buildFilters(),
                    const SizedBox(height: 20),
                    if (filteredMeals.isNotEmpty)

                    const SizedBox(height: 20),
                    if (filteredMeals.isEmpty && meals.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Text(
                          'لا توجد بيانات مطابقة للفلاتر، جرب تغيير الفلاتر',
                          style: textStyle.copyWith(color: Colors.red),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    if (filteredMeals.isNotEmpty)
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
                                label: Checkbox(
                                  value: selectedMealIds.length == filteredMeals.length && filteredMeals.isNotEmpty,
                                  onChanged: _selectAll,
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
                                  child: Text('نوع الوجبة',
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
                              DataColumn(
                                label: Container(
                                  alignment: Alignment.center,
                                  child: Text('التكلفة',
                                      style: textStyle.copyWith(color: Colors.white)),
                                ),
                              ),
                            ],
                            rows: filteredMeals.map((row) {
                              final mealId = row['meal_record_id'] as int;
                              final isSelected = selectedMealIds.contains(mealId);
                              
                              return DataRow(
                                selected: isSelected,
                                cells: [
                                  DataCell(
                                    Checkbox(
                                      value: isSelected,
                                      onChanged: (selected) {
                                        setState(() {
                                          if (selected == true) {
                                            selectedMealIds.add(mealId);
                                          } else {
                                            selectedMealIds.remove(mealId);
                                          }
                                        });
                                      },
                                    ),
                                  ),
                                  DataCell(
                                    Container(
                                      alignment: Alignment.center,
                                      constraints: const BoxConstraints(maxWidth: 150),
                                      child: Text(
                                        row['name'] as String? ?? 'غير معروف',
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
                                        row['meal_type'] as String? ?? 'غير معروف',
                                        style: textStyle,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ),
                                  DataCell(
                                    Container(
                                      alignment: Alignment.center,
                                      child: Text(
                                        row['date'] as String? ?? 'غير معروف',
                                        style: textStyle,
                                      ),
                                    ),
                                  ),
                                  DataCell(
                                    Container(
                                      alignment: Alignment.center,
                                      child: Text(
                                        (row['final_cost'] as num?)?.toStringAsFixed(2) ?? '0.00',
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
                            'إجمالي التكلفة: ${totalCost.toStringAsFixed(2)}',
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
                            'اجمالى فطار: $breakfastCount',
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
                            'إجمالي الغداء: $lunchCount',
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
                            'إجمالي العشاء: $dinnerCount',
                            style: textStyle.copyWith(color: Colors.black),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // Action Buttons for Selected Records
                    if (selectedMealIds.isNotEmpty)
                      Card(
                        elevation: 4,
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            children: [
                              Text(
                                'السجلات المحددة: ${selectedMealIds.length}',
                                style: textStyle.copyWith(
                                  color: Colors.blue[800],
                                  fontWeight: FontWeight.bold,
                                ),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 16),
                              Wrap(
                                spacing: 10,
                                runSpacing: 10,
                                alignment: WrapAlignment.center,
                                children: [
                                  if (AuthService.instance.canEdit) ...[
                                    createButton(
                                      text: 'تعديل السجل',
                                      onPressed: _editSelectedMeal,
                                      bgColor: Colors.orange[700]!,
                                      textColor: Colors.white,
                                      width: MediaQuery.of(context).size.width * 0.35,
                                      height: 45,
                                      icon: Icons.edit,
                                      iconColor: Colors.white,
                                    ),
                                  ],
                                  if (AuthService.instance.canDelete) ...[
                                    createButton(
                                      text: 'حذف السجلات',
                                      onPressed: _deleteSelectedMeals,
                                      bgColor: Colors.red[700]!,
                                      textColor: Colors.white,
                                      width: MediaQuery.of(context).size.width * 0.35,
                                      height: 45,
                                      icon: Icons.delete,
                                      iconColor: Colors.white,
                                    ),
                                  ],
                                ],
                              ),
                            ],
                          ),
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
