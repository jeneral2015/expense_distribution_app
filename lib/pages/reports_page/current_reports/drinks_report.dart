// filename="drinks_report.dart">
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../utils/database.dart';
import '../../../utils/button_utils.dart';
import '../../../utils/background_scaffold.dart';
import '../../../utils/excel_export.dart';
import '../../../utils/undo_manager.dart';
import '../../../utils/helpers.dart';
import '../../../utils/logger.dart' show AppLogger;
import '../../../services/auth_service.dart';

class DrinksReport extends StatefulWidget {
  final DatabaseManager db;

  const DrinksReport({
    Key? key,
    required this.db,
  }) : super(key: key);

  @override
  _DrinksReportState createState() => _DrinksReportState();
}

class _DrinksReportState extends State<DrinksReport> {
  final TextStyle textStyle = const TextStyle(
    fontSize: 15,
    fontFamily: 'Cairo',
  );
  final TextStyle titleStyle = const TextStyle(
    fontSize: 28,
    fontWeight: FontWeight.bold,
    fontFamily: 'Cairo',
  );

  List<Map<String, dynamic>> drinks = [];
  List<Map<String, dynamic>> filteredDrinks = [];
  List<Map<String, dynamic>> drinkQuantities = [];
  double totalCost = 0.0;
  
  // Selection and filtering
  Set<int> selectedDrinkIds = {};
  bool selectAll = false;

  // Use a dropdown to filter by member name
  String? selectedMemberFilter;
  String? selectedDrinkFilter;
  DateTime? startDate;
  DateTime? endDate;

  @override
  void initState() {
    super.initState();
    _fetchDrinksData();
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
          style: const TextStyle(fontSize: 16),
        ),
      ),
    );
  }

  // تعديل جذري: تحسين دالة تعديل السجلات
  Future<void> _editSelectedDrink() async {
    if (selectedDrinkIds.isEmpty) {
      showSnackBar('لم يتم اختيار أي سجل للتعديل!');
      return;
    }

    if (selectedDrinkIds.length > 1) {
      showSnackBar('يمكن تعديل سجل واحد فقط في المرة الواحدة!');
      return;
    }

    final recordId = selectedDrinkIds.first;
    final record = drinks.firstWhere((d) => d['drink_record_id'] == recordId);

    // عرض نافذة التعديل
    final editedData = await _showEditDialog(record);
    if (editedData == null) return; // تم إلغاء التعديل

    try {
      final db = widget.db;
      
      // جلب سعر المشروب الجديد لحساب newTotalCost مسبقاً للـ undo
      final priceResult = await db.fetchAll(
        'SELECT price FROM expenses WHERE item_name = ? AND is_drink = 1',
        [editedData['drink_name']],
      );
      
      if (priceResult.isEmpty) {
        showSnackBar('المشروب غير موجود في المخزون');
        return;
      }
      
      final newPrice = _toDouble(priceResult.first['price']) ?? 0.0;
      final newQuantity = editedData['quantity'] as int;
      final newTotalCost = newQuantity * newPrice;
      editedData['total_cost'] = newTotalCost;

      final undoManager = UndoManager();
      final oldRecord = Map<String, dynamic>.from(record);
      
      // 1. تطبيق التعديل مع حساب الفروق
      final result = await _applyDrinkEdit(recordId, editedData);
      
      if (result['success'] == false) {
        // عرض رسالة الخطأ المحددة
        final errorMessage = result['error'] as String? ?? 'فشل تعديل السجل - تأكد من صحة البيانات';
        showSnackBar(errorMessage);
        return;
      }

      // 2. إنشاء إجراء التراجع (مع تخزين القيم القديمة والجديدة)
      final undoAction = UndoAction(
        type: 'edit_drink',
        id: recordId,
        data: { // ✅ التصحيح الرئيسي: استخدام  بدلًا من تمرير كمعلمة موضعية
          'old': oldRecord,
          'new': editedData,
        },
        timestamp: DateTime.now(),
      );
      undoManager.addAction(undoAction);

      // 3. عرض SnackBar مع زر تراجع
      undoManager.showUndoSnackbar(
        context,
        'تم تعديل السجل بنجاح',
        () => _undoEdit(undoAction),
        duration: const Duration(seconds: 10),
      );

      setState(() {
        selectedDrinkIds.clear();
      });
      await _fetchDrinksData();
    } catch (e, stackTrace) {
      AppLogger.logError('Error editing drink record: $e\n$stackTrace');
      showSnackBar('خطأ غير متوقع أثناء التعديل: $e');
    }
  }

  // دالة جديدة: عرض نافذة تعديل السجل
  Future<Map<String, dynamic>?> _showEditDialog(Map<String, dynamic> record) async {
    final db = widget.db;
    final drinkNameController = TextEditingController(text: record['drink_name'] as String);
    final quantityController = TextEditingController(text: record['quantity'].toString());

    // جلب أسماء المشروبات المتاحة
    final drinksResult = await db.fetchAll('SELECT item_name FROM expenses WHERE is_drink = 1');
    final drinkNames = drinksResult.map((e) => e['item_name'] as String).toList();

    return await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('تعديل سجل المشروب', style: textStyle),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                value: record['drink_name'] as String,
                items: drinkNames.map((name) {
                  return DropdownMenuItem(value: name, child: Text(name, style: textStyle));
                }).toList(),
                onChanged: (value) {
                  drinkNameController.text = value!;
                },
                decoration: const InputDecoration(labelText: 'اسم المشروب', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: quantityController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'الكمية',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, null),
              child: Text('إلغاء', style: textStyle),
            ),
            TextButton(
              onPressed: () {
                final quantity = int.tryParse(quantityController.text);
                if (quantity == null || quantity <= 0) {
                  showSnackBar('الكمية يجب أن تكون رقمًا صحيحًا أكبر من الصفر');
                  return;
                }
                Navigator.pop(context, {
                  'drink_name': drinkNameController.text,
                  'quantity': quantity,
                });
              },
              child: Text('حفظ', style: textStyle.copyWith(color: Colors.blue)),
            ),
          ],
        );
      },
    );
  }

  // دالة مُصلحة: تطبيق التعديل على قاعدة البيانات
  Future<Map<String, dynamic>> _applyDrinkEdit(int recordId, Map<String, dynamic> editedData) async {
    final db = widget.db;
    final oldRecord = drinks.firstWhere((d) => d['drink_record_id'] == recordId);

    try {
      // ✅ التصحيح: التعامل مع القيم المحتملة null
      final oldDrinkName = oldRecord['drink_name'] as String;
      final oldQuantity = _toDouble(oldRecord['quantity'])?.toInt() ?? 0;
      final oldTotalCost = _toDouble(oldRecord['total_cost']) ?? 0.0;
      final memberId = _toInt(oldRecord['member_id']) ?? 0;
      // ✅ التصحيح: إزالة المتغير غير المستخدم 'date'
      
      final newDrinkName = editedData['drink_name'] as String;
      final newQuantity = editedData['quantity'] as int;

      await db.transaction((txn) async {
        // 1. جلب سعر المشروب الجديد مع التحقق من null
        final priceResult = await txn.rawQuery(
          'SELECT price, quantity FROM expenses WHERE item_name = ? AND is_drink = 1',
          [newDrinkName],
        );
        
        if (priceResult.isEmpty) {
          throw Exception('المشروب غير موجود في المخزون');
        }
        
        final priceRow = priceResult.first;
        final newPrice = _toDouble(priceRow['price']) ?? 0.0;
        final newTotalCost = newQuantity * newPrice;
        
        // ✅ التصحيح: التعامل مع quantity المحتمل أن يكون double
        final totalQuantity = _toDouble(priceRow['quantity'])?.toInt() ?? 0;

        // 2. التحقق من صحة الكمية الجديدة
        if (newDrinkName == oldDrinkName) {
          // حالة: نفس النوع، تحقق من إجمالي الكمية
          final totalConsumedResult = await txn.rawQuery(
            'SELECT COALESCE(SUM(quantity), 0) as total FROM drink_records WHERE drink_name = ?',
            [newDrinkName],
          );
          
          final totalConsumed = _toDouble(totalConsumedResult.first['total'])?.toInt() ?? 0;
          final adjustedTotal = totalConsumed - oldQuantity + newQuantity;

          if (adjustedTotal > totalQuantity) {
            throw Exception('الكمية المطلوبة تتجاوز الكمية المتاحة (الكمية المتاحة: $totalQuantity)');
          }
        } else {
          // حالة: نوع مختلف، تحقق من المشروب الجديد
          final totalConsumedResult = await txn.rawQuery(
            'SELECT COALESCE(SUM(quantity), 0) as total FROM drink_records WHERE drink_name = ?',
            [newDrinkName],
          );
          
          final totalConsumed = _toDouble(totalConsumedResult.first['total'])?.toInt() ?? 0;
          final adjustedTotal = totalConsumed + newQuantity;

          if (adjustedTotal > totalQuantity) {
            throw Exception('الكمية المطلوبة تتجاوز الكمية المتاحة (الكمية المتاحة: $totalQuantity)');
          }
        }

        // 3. حساب الفروق
        final costDelta = newTotalCost - oldTotalCost;
        final quantityDelta = newQuantity - oldQuantity;

        // 4. تحديث المديونية
        await txn.rawUpdate(
          'UPDATE members SET total_due = total_due + ? WHERE member_id = ?',
          [costDelta, memberId],
        );

        // 5. تحديث المخزون
        if (newDrinkName == oldDrinkName) {
          // نفس النوع: تعديل الكمية مباشرة
          await txn.rawUpdate(
            'UPDATE expenses SET consumption = consumption + ?, remaining = remaining - ? WHERE item_name = ?',
            [quantityDelta, quantityDelta, newDrinkName],
          );
        } else {
          // نوع مختلف: إلغاء التأثير القديم وتطبيق الجديد
          await txn.rawUpdate(
            'UPDATE expenses SET consumption = consumption - ?, remaining = remaining + ? WHERE item_name = ?',
            [oldQuantity, oldQuantity, oldDrinkName],
          );
          await txn.rawUpdate(
            'UPDATE expenses SET consumption = consumption + ?, remaining = remaining - ? WHERE item_name = ?',
            [newQuantity, newQuantity, newDrinkName],
          );
        }

        // 6. تحديث السجل
        await txn.rawUpdate(
          'UPDATE drink_records SET drink_name = ?, quantity = ?, total_cost = ? WHERE drink_record_id = ?',
          [newDrinkName, newQuantity, newTotalCost, recordId],
        );
      });
      
      return {'success': true};
    } catch (e) {
      AppLogger.logError('Error applying drink edit: $e');
      return {
        'success': false,
        'error': e.toString()
      };
    }
  }

  // دالة مساعدة: تحويل القيم إلى double مع التعامل مع null
  double? _toDouble(dynamic value) {
    if (value == null) return null;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) {
      final parsed = double.tryParse(value);
      return parsed;
    }
    return null;
  }

  // دالة مساعدة: تحويل القيم إلى int مع التعامل مع null
  int? _toInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is double) return value.toInt();
    if (value is String) {
      final parsed = int.tryParse(value);
      return parsed;
    }
    return null;
  }

  // دالة جديدة: التراجع عن التعديل
  Future<void> _undoEdit(UndoAction undoAction) async {
    try {
      final data = undoAction.data;
      final oldRecord = data['old'] as Map<String, dynamic>;
      final newRecord = data['new'] as Map<String, dynamic>;
      final recordId = undoAction.id;

      final db = widget.db;
      await db.transaction((txn) async {
        // ✅ التصحيح: التعامل مع أنواع البيانات بشكل صحيح
        final oldDrinkName = oldRecord['drink_name'] as String;
        final oldQuantity = _toDouble(oldRecord['quantity'])?.toInt() ?? 0;
        final oldTotalCost = _toDouble(oldRecord['total_cost']) ?? 0.0;
        final memberId = _toInt(oldRecord['member_id']) ?? 0;

        final newDrinkName = newRecord['drink_name'] as String;
        final newQuantity = _toDouble(newRecord['quantity'])?.toInt() ?? 0;
        final newTotalCost = _toDouble(newRecord['total_cost']) ?? 0.0;

        // 2. حساب الفروق العكسية
        final costDelta = oldTotalCost - newTotalCost;
        final quantityDelta = oldQuantity - newQuantity;

        // 3. تحديث المديونية
        await txn.rawUpdate(
          'UPDATE members SET total_due = total_due + ? WHERE member_id = ?',
          [costDelta, memberId],
        );

        // 4. تحديث المخزون
        if (newDrinkName == oldDrinkName) {
          await txn.rawUpdate(
            'UPDATE expenses SET consumption = consumption + ?, remaining = remaining - ? WHERE item_name = ?',
            [quantityDelta, quantityDelta, newDrinkName],
          );
        } else {
          // إلغاء التأثير الجديد
          await txn.rawUpdate(
            'UPDATE expenses SET consumption = consumption - ?, remaining = remaining + ? WHERE item_name = ?',
            [newQuantity, newQuantity, newDrinkName],
          );
          // تطبيق التأثير القديم
          await txn.rawUpdate(
            'UPDATE expenses SET consumption = consumption + ?, remaining = remaining - ? WHERE item_name = ?',
            [oldQuantity, oldQuantity, oldDrinkName],
          );
        }

        // 5. استعادة السجل الأصلي
        await txn.rawUpdate(
          'UPDATE drink_records SET drink_name = ?, quantity = ?, total_cost = ? WHERE drink_record_id = ?',
          [oldDrinkName, oldQuantity, oldTotalCost, recordId],
        );
      });

      // 6. إزالة إجراء التراجع
      UndoManager().undoLast();
      showSnackBar('تم التراجع عن التعديل');
      await _fetchDrinksData();
    } catch (e, stackTrace) {
      AppLogger.logError('Error undoing drink edit: $e\n$stackTrace');
      showSnackBar('خطأ أثناء التراجع عن التعديل: $e');
    }
  }

  void _applyFilters() {
    List<Map<String, dynamic>> filtered = drinks;

    // Apply member dropdown filter (exact match). If null => no member filter.
    if (selectedMemberFilter != null) {
      filtered = filtered.where((drink) {
        final memberName = (drink['name'] as String);
        return memberName == selectedMemberFilter;
      }).toList();
    }

    // Apply drink filter
    if (selectedDrinkFilter != null) {
      filtered = filtered.where((drink) {
        return drink['drink_name'] == selectedDrinkFilter;
      }).toList();
    }

    // Apply date filter
    if (startDate != null && endDate != null) {
      filtered = filtered.where((drink) {
        final drinkDate = DateTime.parse(drink['date'] as String);
        return drinkDate.isAfter(startDate!.subtract(const Duration(days: 1))) &&
               drinkDate.isBefore(endDate!.add(const Duration(days: 1)));
      }).toList();
    }

    // Sort filtered drinks by date ascending
    filtered.sort((a, b) {
      final dateA = DateTime.parse(a['date']);
      final dateB = DateTime.parse(b['date']);
      return dateA.compareTo(dateB);
    });

    setState(() {
      filteredDrinks = filtered;
      selectedDrinkIds.clear();
      selectAll = false;
    });
  }

  Future<void> _fetchDrinksData() async {
    try {
      const query = '''
        SELECT dr.drink_record_id, dr.member_id, m.name, dr.drink_name, dr.quantity, dr.date, dr.total_cost
        FROM drink_records dr
        JOIN members m ON dr.member_id = m.member_id
      ''';
      final drinksData = await widget.db.fetchAll(query);

      if (drinksData.isEmpty) {
        showSnackBar('لا توجد بيانات مشروبات لهذا الشهر!');
        return;
      }

      final Map<String, num> quantities = {};
      for (var row in drinksData) {
        final drinkName = row['drink_name'] as String;
        final quantity = _toDouble(row['quantity']) ?? 0.0;
        quantities[drinkName] = (quantities[drinkName] ?? 0) + quantity;
      }

      // Make a mutable copy and sort by date ascending
      List<Map<String, dynamic>> mutableDrinksData = List.from(drinksData);
      mutableDrinksData.sort((a, b) {
        final dateA = DateTime.parse(a['date']);
        final dateB = DateTime.parse(b['date']);
        return dateA.compareTo(dateB);
      });

      setState(() {
        drinks = mutableDrinksData;
        filteredDrinks = mutableDrinksData; // Initialize filteredDrinks with all drinks data
        totalCost = drinks.fold(
            0.0, (sum, item) => sum + (_toDouble(item['total_cost']) ?? 0.0));
        drinkQuantities = quantities.entries
            .map((e) => {'drink_name': e.key, 'quantity': e.value})
            .toList();
      });
    } catch (e, stackTrace) {
      AppLogger.logError('Error fetching drinks report: $e\n$stackTrace');
      showSnackBar('خطأ أثناء جلب تقرير المشروبات: $e');
    }
  }

  Future<void> _deleteSelectedDrinks() async {
    if (selectedDrinkIds.isEmpty) {
      showSnackBar('لم يتم تحديد أي سجلات للحذف');
      return;
    }

    // Show confirmation dialog
    final bool confirmDelete = await showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('تأكيد الحذف', style: textStyle),
          content: Text(
            'هل أنت متأكد من حذف ${selectedDrinkIds.length} سجل؟',
            style: textStyle,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text('إلغاء', style: textStyle),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: Text('حذف', style: textStyle.copyWith(color: Colors.red)),
            ),
          ],
        );
      },
    );

    if (!confirmDelete) {
      return;
    }

    try {
      final undoManager = UndoManager();
      final deletedRecords = <Map<String, dynamic>>[];

      // 1. استخدام Helpers.reverseDrinkEffects (يعدّل المديونية والمخزون)
      for (final id in selectedDrinkIds.toList()) {
        final record = drinks.firstWhere((d) => d['drink_record_id'] == id);
        
        final success = await Helpers.reverseDrinkEffects(id);
        if (success) {
          deletedRecords.add(record);
        } else {
          AppLogger.logError('Failed to reverse drink effects for ID: $id');
        }
      }

      if (deletedRecords.isEmpty) {
        showSnackBar('فشل الحذف - لم يتم العثور على السجلات');
        return;
      }

      // 2. إضافة إجراءات التراجع
      for (final record in deletedRecords) {
        final undoAction = UndoAction(
          type: 'drink',
          id: record['drink_record_id'] as int,
          data: record, // ✅ التصحيح: إضافة المعامل المطلوب 'data'
          timestamp: DateTime.now(),
        );
        undoManager.addAction(undoAction);
      }

      // 3. عرض SnackBar مع زر تراجع
      undoManager.showUndoSnackbar(
        context,
        'تم حذف ${deletedRecords.length} سجل',
        () => _undoDelete(deletedRecords),
        duration: const Duration(seconds: 10), // وقت أطول للـ Undo
      );

      setState(() {
        selectedDrinkIds.clear();
        selectAll = false;
      });

      await _fetchDrinksData();
    } catch (e, stackTrace) {
      AppLogger.logError('Error in _deleteSelectedDrinks: $e\n$stackTrace');
      showSnackBar('خطأ أثناء حذف السجلات: $e');
    }
  }

  // دالة جديدة: تنفيذ التراجع عن الحذف
  Future<void> _undoDelete(List<Map<String, dynamic>> records) async {
    try {
      final undoManager = UndoManager();
      
      for (final record in records) {
        // استخدام Helpers.reapplyDrinkEffect (يعدّل المديونية والمخزون)
        final success = await Helpers.reapplyDrinkEffect(record);
        if (!success) {
          AppLogger.logError('Failed to reapply drink effect for ID: ${record['drink_record_id']}');
          showSnackBar('فشل التراجع عن سجل: ${record['drink_name']}');
        }
      }

      // إزالة الإجراء من مكدس التراجع
      undoManager.undoLast();
      
      showSnackBar('تم التراجع عن الحذف');
      await _fetchDrinksData();
    } catch (e, stackTrace) {
      AppLogger.logError('Error during undo: $e\n$stackTrace');
      showSnackBar('خطأ أثناء التراجع: $e');
    }
  }

  Future<void> _exportToExcel() async {
    try {
      if (drinks.isEmpty) {
        showSnackBar('لا توجد بيانات لتصديرها');
        return;
      }

      // بيانات الجدول الرئيسي
      final mainColumns = [
        'اسم المشترك',
        'اسم المشروب',
        'الكمية',
        'التاريخ',
        'التكلفة',
      ];

      final mainRows = drinks.map((row) => [
            row['name'] as String,
            row['drink_name'] as String,
            _toDouble(row['quantity']) ?? 0.0,
            row['date'] as String,
            _toDouble(row['total_cost']) ?? 0.0,
          ]).toList();

      final mainExtraInfo = <String, String>{
        'اسم التقرير': 'تقرير المشروبات',
        'تاريخ التصدير': DateTime.now().toString(),
      };

      final mainTotals = [
        [
          'الإجمالي',
          '',
          '',
          '',
          totalCost,
        ],
      ];

      // بيانات جدول إجمالي الكميات
      final quantitiesColumns = [
        'اسم المشروب',
        'إجمالي الكمية',
      ];

      final quantitiesRows = drinkQuantities.map((row) => [
            row['drink_name'] as String,
            _toDouble(row['quantity']) ?? 0.0,
          ]).toList();

      final quantitiesExtraInfo = <String, String>{
        'اسم التقرير': 'إجمالي الكمية لكل مشروب',
        'تاريخ التصدير': DateTime.now().toString(),
      };

      // تصدير الجدول الرئيسي
      await exportReportToExcel(
        context: context,
        reportTitle: 'تقرير المشروبات',
        columns: mainColumns,
        rows: mainRows,
        extraInfo: mainExtraInfo,
        totals: mainTotals,
      );

      // تصدير جدول إجمالي الكميات
      await exportReportToExcel(
        context: context,
        reportTitle: 'إجمالي الكمية لكل مشروب',
        columns: quantitiesColumns,
        rows: quantitiesRows,
        extraInfo: quantitiesExtraInfo,
        totals: [],
      );
    } catch (e, stackTrace) {
      AppLogger.logError('Error exporting report: $e\n$stackTrace');
      showSnackBar('خطأ أثناء تصدير التقرير: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return BackgroundScaffold(
      backgroundImagePath: 'assets/3.jpg', // Assuming a default path; adjust if needed
      child: Stack(
        children: [
          Center(
            child: SingleChildScrollView(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('تقرير المشروبات', style: titleStyle),
                  const SizedBox(height: 16),
                  // Filters
                  Card(
                    elevation: 4,
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: FutureBuilder<List<String>>(
                                  future: widget.db.fetchAll('SELECT DISTINCT name FROM members').then(
                                    (members) => members.map((m) => m['name'] as String).toList(),
                                  ),
                                  builder: (context, snapshot) {
                                    if (!snapshot.hasData) return const CircularProgressIndicator();
                                    final memberNames = snapshot.data!;
                                    return DropdownButtonFormField<String>(
                                      value: selectedMemberFilter,
                                      hint: Text('تصفية حسب اسم المشترك', style: textStyle),
                                      items: memberNames
                                          .map((name) => DropdownMenuItem(
                                                value: name,
                                                child: Text(name, style: textStyle),
                                              ))
                                          .toList(),
                                      onChanged: (value) {
                                        setState(() {
                                          selectedMemberFilter = value;
                                        });
                                        _applyFilters();
                                      },
                                    );
                                  },
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(
                                child: FutureBuilder<List<String>>(
                                  future: widget.db.fetchAll('SELECT DISTINCT drink_name FROM drink_records').then(
                                    (drinks) => drinks.map((d) => d['drink_name'] as String).toList(),
                                  ),
                                  builder: (context, snapshot) {
                                    if (!snapshot.hasData) return const CircularProgressIndicator();
                                    final drinkNames = snapshot.data!;
                                    return DropdownButtonFormField<String>(
                                      value: selectedDrinkFilter,
                                      hint: Text('تصفية حسب اسم المشروب', style: textStyle),
                                      items: drinkNames
                                          .map((drinkName) => DropdownMenuItem(
                                                value: drinkName,
                                                child: Text(drinkName, style: textStyle),
                                              ))
                                          .toList(),
                                      onChanged: (value) {
                                        setState(() {
                                          selectedDrinkFilter = value;
                                        });
                                        _applyFilters();
                                      },
                                    );
                                  },
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('نطاق التاريخ:', style: textStyle),
                                    const SizedBox(height: 8),
                                    Row(
                                      children: [
                                        Expanded(
                                          child: TextButton(
                                            onPressed: () async {
                                              final pickedDate = await showDatePicker(
                                                context: context,
                                                initialDate: startDate ?? DateTime.now(),
                                                firstDate: DateTime(2000),
                                                lastDate: DateTime(2100),
                                              );
                                              if (pickedDate != null) {
                                                setState(() {
                                                  startDate = pickedDate;
                                                });
                                                _applyFilters();
                                              }
                                            },
                                            child: Text(
                                              startDate != null
                                                  ? DateFormat('yyyy-MM-dd').format(startDate!)
                                                  : 'بداية التاريخ',
                                              style: textStyle,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: TextButton(
                                            onPressed: () async {
                                              final pickedDate = await showDatePicker(
                                                context: context,
                                                initialDate: endDate ?? DateTime.now(),
                                                firstDate: DateTime(2000),
                                                lastDate: DateTime(2100),
                                              );
                                              if (pickedDate != null) {
                                                setState(() {
                                                  endDate = pickedDate;
                                                });
                                                _applyFilters();
                                              }
                                            },
                                            child: Text(
                                              endDate != null
                                                  ? DateFormat('yyyy-MM-dd').format(endDate!)
                                                  : 'نهاية التاريخ',
                                              style: textStyle,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    if (startDate != null || endDate != null)
                                      TextButton(
                                        onPressed: () {
                                          setState(() {
                                            startDate = null;
                                            endDate = null;
                                          });
                                          _applyFilters();
                                        },
                                        child: Text('مسح نطاق التاريخ', style: textStyle.copyWith(color: Colors.red)),
                                      ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  'السجلات المحددة: ${selectedDrinkIds.length}',
                                  style: textStyle,
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 20),
                  if (filteredDrinks.isNotEmpty)
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
                                value: selectAll,
                                onChanged: (value) {
                                  setState(() {
                                    selectAll = value ?? false;
                                    if (selectAll) {
                                      selectedDrinkIds.addAll(filteredDrinks.map((d) => d['drink_record_id'] as int));
                                    } else {
                                      selectedDrinkIds.clear();
                                    }
                                  });
                                },
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
                                child: Text('اسم المشروب',
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
                          rows: filteredDrinks.map((row) {
                            return DataRow(
                              selected: selectedDrinkIds.contains(row['drink_record_id'] as int),
                              cells: [
                                DataCell(
                                  Checkbox(
                                    value: selectedDrinkIds.contains(row['drink_record_id'] as int),
                                    onChanged: (value) {
                                      setState(() {
                                        if (value ?? false) {
                                          selectedDrinkIds.add(row['drink_record_id'] as int);
                                        } else {
                                          selectedDrinkIds.remove(row['drink_record_id'] as int);
                                        }
                                        selectAll = selectedDrinkIds.length == filteredDrinks.length;
                                      });
                                    },
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
                                      row['drink_name'] as String,
                                      style: textStyle,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ),
                                DataCell(
                                  Container(
                                    alignment: Alignment.center,
                                    child: Text(
                                      _toDouble(row['quantity'])?.toInt().toString() ?? '0',
                                      style: textStyle,
                                    ),
                                  ),
                                ),
                                DataCell(
                                  Container(
                                    alignment: Alignment.center,
                                    child: Text(
                                      row['date'] as String,
                                      style: textStyle,
                                    ),
                                  ),
                                ),
                                DataCell(
                                  Container(
                                    alignment: Alignment.center,
                                    child: Text(
                                      _toDouble(row['total_cost'])?.toStringAsFixed(2) ?? '0.00',
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
                      'إجمالي التكلفة: ${totalCost.toStringAsFixed(2)}',
                      style: textStyle.copyWith(color: Colors.black),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Action Buttons for Selected Records
                  if (selectedDrinkIds.isNotEmpty)
                    Card(
                      elevation: 4,
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          children: [
                            Text(
                              'السجلات المحددة: ${selectedDrinkIds.length}',
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
                                    onPressed: _editSelectedDrink,
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
                                    onPressed: _deleteSelectedDrinks,
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
                  if (drinkQuantities.isNotEmpty)
                    Column(
                      children: [
                        Text(
                          'إحصائية إجمالي الكمية لكل مشروب',
                          style: textStyle.copyWith(color: Colors.black),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 10),
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
                                    child: Text('اسم المشروب',
                                        style: textStyle.copyWith(color: Colors.white)),
                                  ),
                                ),
                                DataColumn(
                                  label: Container(
                                    alignment: Alignment.center,
                                    child: Text('إجمالي الكمية',
                                        style: textStyle.copyWith(color: Colors.white)),
                                  ),
                                ),
                              ],
                              rows: drinkQuantities.map((row) {
                                return DataRow(cells: [
                                  DataCell(
                                    Container(
                                      alignment: Alignment.center,
                                      constraints: const BoxConstraints(maxWidth: 150),
                                      child: Text(
                                        row['drink_name'] as String,
                                        style: textStyle,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ),
                                  DataCell(
                                    Container(
                                      alignment: Alignment.center,
                                      child: Text(
                                        _toDouble(row['quantity'])?.toInt().toString() ?? '0',
                                        style: textStyle,
                                      ),
                                    ),
                                  ),
                                ]);
                              }).toList(),
                            ),
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
              onPressed: () => Navigator.pop(context),
            ),
          ),
        ],
      ),
    );
  }
}