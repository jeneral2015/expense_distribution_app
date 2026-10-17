import 'package:flutter/material.dart';
import '../../utils/database.dart';
import '../utils/formatters.dart';

class MealDetailsDialog extends StatefulWidget {
  final DatabaseManager db;
  final int? mealId;
  final int? mealRecordId;
  final String memberName;
  final String mealType;
  final String date;
  final double memberFinalCost;

  const MealDetailsDialog({
    super.key,
    required this.db,
    this.mealId,
    this.mealRecordId,
    required this.memberName,
    required this.mealType,
    required this.date,
    required this.memberFinalCost,
  });

  static Future<void> show({
    required BuildContext context,
    required DatabaseManager db,
    int? mealId,
    int? mealRecordId,
    required String memberName,
    required String mealType,
    required String date,
    required double memberFinalCost,
  }) {
    return showDialog(
      context: context,
      builder: (ctx) => MealDetailsDialog(
        db: db,
        mealId: mealId,
        mealRecordId: mealRecordId,
        memberName: memberName,
        mealType: mealType,
        date: date,
        memberFinalCost: memberFinalCost,
      ),
    );
  }

  @override
  State<MealDetailsDialog> createState() => _MealDetailsDialogState();
}

class _MealDetailsDialogState extends State<MealDetailsDialog> {
  bool _loading = true;
  String? _errorMessage;
  double _totalMealCost = 0.0;
  double _miscTotal = 0.0;
  double _memberRatio = 1.0;
  List<Map<String, dynamic>> _items = [];

  @override
  void initState() {
    super.initState();
    _loadMealDetails();
  }

  Future<void> _loadMealDetails() async {
    try {
      int? resolvedMealId = widget.mealId;

      // If mealId was not passed directly, try to get it from mealRecordId
      if (resolvedMealId == null && widget.mealRecordId != null) {
        final rec = await widget.db.fetchOne(
          'SELECT meal_id FROM meal_records WHERE meal_record_id = ?',
          [widget.mealRecordId],
        );
        if (rec != null && rec['meal_id'] != null) {
          resolvedMealId = rec['meal_id'] as int?;
        } else {
          // Check archive table
          final archRec = await widget.db.fetchOne(
            'SELECT meal_id FROM meal_records_archive WHERE meal_record_id = ?',
            [widget.mealRecordId],
          );
          if (archRec != null && archRec['meal_id'] != null) {
            resolvedMealId = archRec['meal_id'] as int?;
          }
        }
      }

      if (resolvedMealId == null) {
        setState(() {
          _loading = false;
          _errorMessage = 'لا يوجد رقم وجبة مسجل لهذه المعاملة (سجل قديم).';
        });
        return;
      }

      // Fetch meal overall info
      final mealRow = await widget.db.fetchOne(
        'SELECT total_cost, misc_total FROM meals WHERE meal_id = ?',
        [resolvedMealId],
      );

      if (mealRow != null) {
        _totalMealCost = Formatters.toDouble(mealRow['total_cost']);
        _miscTotal = Formatters.toDouble(mealRow['misc_total']);
      }

      // Calculate member ratio
      if (_totalMealCost > 0 && widget.memberFinalCost > 0) {
        _memberRatio = widget.memberFinalCost / _totalMealCost;
      } else {
        _memberRatio = 1.0;
      }

      // Fetch meal items
      final itemsRows = await widget.db.fetchAll(
        '''
        SELECT item_name, quantity_used, price_at_time, 
               (quantity_used * price_at_time) as item_total_cost
        FROM meal_items
        WHERE meal_id = ?
        ''',
        [resolvedMealId],
      );

      setState(() {
        _items = itemsRows;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _loading = false;
        _errorMessage = 'خطأ أثناء جلب مكونات الوجبة: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        insetPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 24),
        titlePadding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
        contentPadding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        title: Column(
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.orange.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.restaurant_menu_rounded,
                      color: Colors.orange, size: 24),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'تفاصيل ومكونات الوجبة',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1E4C54),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'المشترك: ${widget.memberName}',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Colors.black87,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'الوجبة: ${widget.mealType}',
                    style: const TextStyle(
                        fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                  Text(
                    'التاريخ: ${widget.date}',
                    style: const TextStyle(fontSize: 12, color: Colors.black54),
                  ),
                ],
              ),
            ),
          ],
        ),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: _buildContent(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('إغلاق', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    if (_loading) {
      return const SizedBox(
        height: 180,
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (_errorMessage != null) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.info_outline, color: Colors.blue[600], size: 40),
            const SizedBox(height: 12),
            Text(
              _errorMessage!,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 14, color: Colors.black87),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.green.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'التكلفة الإجمالية المسجلة على المشترك: ${widget.memberFinalCost.toAppString()} ج.م',
                style: const TextStyle(
                    fontWeight: FontWeight.bold, color: Colors.green),
              ),
            ),
          ],
        ),
      );
    }

    if (_items.isEmpty && _miscTotal <= 0) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'لا توجد مكونات تفصيلية مسجلة لهذه الوجبة.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 12),
            Text(
              'التكلفة المسجلة: ${widget.memberFinalCost.toAppString()} ج.م',
              style: const TextStyle(
                  fontWeight: FontWeight.bold, color: Colors.green),
            ),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Table(
            border: TableBorder.all(
              color: Colors.grey.shade300,
              width: 1,
              borderRadius: BorderRadius.circular(8),
            ),
            columnWidths: const {
              0: FlexColumnWidth(2.0), // المكون
              1: FlexColumnWidth(1.0), // الكمية
              2: FlexColumnWidth(1.3), // سعر الوحدة
              3: FlexColumnWidth(1.6), // نصيب المشترك
            },
            defaultVerticalAlignment: TableCellVerticalAlignment.middle,
            children: [
              const TableRow(
                decoration: BoxDecoration(
                  color: Color(0xFF1E4C54),
                ),
                children: [
                  Padding(
                    padding: EdgeInsets.symmetric(vertical: 9.0, horizontal: 4.0),
                    child: Text(
                      'المكون',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  Padding(
                    padding: EdgeInsets.symmetric(vertical: 9.0, horizontal: 2.0),
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        'الكمية',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                  Padding(
                    padding: EdgeInsets.symmetric(vertical: 9.0, horizontal: 2.0),
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        'سعر الوحدة',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                  Padding(
                    padding: EdgeInsets.symmetric(vertical: 9.0, horizontal: 2.0),
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        'نصيب المشترك',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              ..._items.map((item) {
                final itemName = item['item_name']?.toString() ?? '';
                final qtyUsed = Formatters.toDouble(item['quantity_used']);
                final price = Formatters.toDouble(item['price_at_time']);
                final itemTotalCost = Formatters.toDouble(item['item_total_cost']);
                final memberItemCost = itemTotalCost * _memberRatio;

                return TableRow(
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          vertical: 7.0, horizontal: 6.0),
                      child: Text(
                        itemName,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 12.5,
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 7.0, horizontal: 2.0),
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          qtyUsed.toAppString(),
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 12.5),
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 7.0, horizontal: 2.0),
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          '${price.toAppString()} ج',
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 12.5),
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 7.0, horizontal: 2.0),
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          '${memberItemCost.toAppString()} ج',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 12.5,
                            color: Color(0xFF1E4C54),
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              }),
              if (_miscTotal > 0)
                TableRow(
                  decoration: BoxDecoration(
                    color: Colors.amber.withValues(alpha: 0.1),
                  ),
                  children: [
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 7.0, horizontal: 6.0),
                      child: Text(
                        'نثريات الوجبة',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: Colors.amber,
                          fontSize: 12.5,
                        ),
                      ),
                    ),
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 7.0),
                      child: Text('-', textAlign: TextAlign.center),
                    ),
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 7.0),
                      child: Text('-', textAlign: TextAlign.center),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 7.0, horizontal: 2.0),
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          '${(_miscTotal * _memberRatio).toAppString()} ج',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 12.5,
                            color: Colors.deepOrange,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFFE8EFE9),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFF4C8D8B), width: 1.2),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Flexible(
                  child: Text(
                    'إجمالي التكلفة على المشترك:',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1E4C54),
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    '${widget.memberFinalCost.toAppString()} ج.م',
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF1E4C54),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
