import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../utils/button_utils.dart';
import '../utils/database.dart';
import '../utils/background_scaffold.dart';
import 'package:intl/intl.dart';
import 'dart:ui' as ui;

class DrinkPage extends StatefulWidget {
  final DatabaseManager db;
  final VoidCallback navigateToDistribute_expenses;
  final String backgroundImagePath;

  const DrinkPage({
    Key? key,
    required this.db,
    required this.navigateToDistribute_expenses,
    required this.backgroundImagePath,
  }) : super(key: key);

  @override
  _DrinkPageState createState() => _DrinkPageState();
}

class _DrinkPageState extends State<DrinkPage> {
  late TextEditingController _dateController;
  late String? _drinkName;
  late TextEditingController _quantityController;
  late String? _memberId;

  @override
  void initState() {
    super.initState();
    _dateController = TextEditingController(
      text: DateFormat('yyyy-MM-dd').format(DateTime.now()),
    );
    _drinkName = null;
    _quantityController = TextEditingController();
    _memberId = null;
  }

  @override
  void dispose() {
    _dateController.dispose();
    _quantityController.dispose();
    super.dispose();
  }

  void _navigateTo(String page) {
    if (page == 'distribute_expenses') {
      widget.navigateToDistribute_expenses();
    } else {
      context.go('/$page');
    }
  }

  void _resetFields() {
    _drinkName = null;
    _quantityController.clear();
    _memberId = null;
    setState(() {});
  }

  void _saveDrinkDistribution() async {
    final drinkName = _drinkName;
    final quantityText = _quantityController.text.trim();
    final memberInfo = _memberId;
    final date = _dateController.text;

    if (drinkName != null &&
        quantityText.isNotEmpty &&
        memberInfo != null &&
        date.isNotEmpty) {
      try {
        final quantity = int.tryParse(quantityText);
        if (quantity == null || quantity <= 0) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text('العدد يجب أن يكون عددًا صحيحًا أكبر من صفر!')),
          );
          return;
        }

        debugPrint(
            'Starting save transaction for drink: $drinkName, quantity: $quantity, member: $memberInfo');

        String? warningMessage;

        await widget.db.transaction((txn) async {
          // جلب بيانات المشروب
          final priceDataList = await txn.rawQuery(
            'SELECT price, quantity FROM expenses WHERE item_name = ? AND is_drink = 1',
            [drinkName],
          );
          if (priceDataList.isEmpty) {
            throw Exception('المشروب غير موجود.');
          }
          final priceData = priceDataList.first;
          final unitPrice = widget.db.asDouble(priceData['price']);
          final originalQuantity = widget.db.asInt(priceData['quantity']);

          // جلب بيانات السكر
          final sugarDataList = await txn.rawQuery(
            'SELECT price, quantity FROM expenses WHERE item_name = ?',
            ['سكر'],
          );

          double sugarCostPerCup = 0.0;
          double finalUnitPrice = unitPrice;
          bool sugarAvailable = false;

          if (sugarDataList.isNotEmpty) {
            final sugarData = sugarDataList.first;
            final sugarPricePerKg = widget.db.asDouble(sugarData['price']);
            final sugarOriginalQuantity =
                widget.db.asDouble(sugarData['quantity']);

            if (sugarPricePerKg > 0 && sugarOriginalQuantity > 0) {
              // حساب تكلفة السكر لكل كوب (20 جرام = 0.02 كجم)
              sugarCostPerCup = (sugarPricePerKg * 0.02);
              finalUnitPrice = unitPrice + sugarCostPerCup;
              sugarAvailable = true;

              // التحقق من الكمية المتاحة للسكر
              final sugarConsumedDataList = await txn.rawQuery(
                'SELECT COALESCE(SUM(quantity * 0.02), 0) as total_kg FROM drink_records',
              );
              final sugarConsumedKg = sugarConsumedDataList.isNotEmpty
                  ? widget.db.asDouble(sugarConsumedDataList.first['total_kg'])
                  : 0.0;

              final newSugarConsumptionKg = quantity * 0.02;
              final totalSugarConsumedAfter =
                  sugarConsumedKg + newSugarConsumptionKg;

              if (totalSugarConsumedAfter > sugarOriginalQuantity) {
                warningMessage =
                    'كمية السكر غير كافية، تم الحفظ بدون إضافة سكر';
                sugarCostPerCup = 0.0;
                finalUnitPrice = unitPrice;
                sugarAvailable = false;
              }
            } else {
              warningMessage =
                  'سعر أو كمية السكر غير صحيحة، تم الحفظ بدون إضافة سكر';
              sugarCostPerCup = 0.0;
              finalUnitPrice = unitPrice;
              sugarAvailable = false;
            }
          } else {
            warningMessage =
                'تم الحفظ بدون إضافة سكر لعدم توفر صنف السكر في المخزون';
            sugarCostPerCup = 0.0;
            finalUnitPrice = unitPrice;
            sugarAvailable = false;
          }

          // التحقق من الكمية المتاحة للمشروب
          final totalConsumedDataList = await txn.rawQuery(
            'SELECT COALESCE(SUM(quantity), 0) as total FROM drink_records WHERE drink_name = ?',
            [drinkName],
          );
          final totalConsumed = totalConsumedDataList.isNotEmpty
              ? widget.db.asInt(totalConsumedDataList.first['total'])
              : 0;

          final newConsumption = quantity;
          final totalConsumedAfter = totalConsumed + newConsumption;

          if (totalConsumedAfter <= originalQuantity) {
            final totalCost = newConsumption * finalUnitPrice;

            // تحديث مستحقات العضو
            await txn.rawUpdate(
              'UPDATE members SET total_due = total_due + ? WHERE member_id = ?',
              [totalCost, int.parse(memberInfo)],
            );

            // تحديث استهلاك المشروب
            await txn.rawUpdate(
              'UPDATE expenses SET consumption = ?, remaining = ? WHERE item_name = ?',
              [
                totalConsumedAfter,
                originalQuantity - totalConsumedAfter,
                drinkName
              ],
            );

            // تحديث استهلاك السكر فقط إذا كان متوفراً وبكمية كافية
            if (sugarAvailable && sugarCostPerCup > 0) {
              final newSugarConsumptionKg = quantity * 0.02;
              await txn.rawUpdate(
                'UPDATE expenses SET consumption = consumption + ?, remaining = remaining - ? WHERE item_name = ?',
                [newSugarConsumptionKg, newSugarConsumptionKg, 'سكر'],
              );
            }

            // تسجيل عملية توزيع المشروب
            await txn.rawInsert(
              'INSERT INTO drink_records (date, drink_name, member_id, quantity, total_cost) VALUES (?, ?, ?, ?, ?)',
              [
                date,
                drinkName,
                int.parse(memberInfo),
                newConsumption,
                totalCost
              ],
            );
          } else {
            throw Exception('الكمية المطلوبة تتجاوز الكمية المتاحة للمشروب.');
          }
        });

        debugPrint('Save successful for drink: $drinkName');

        // عرض رسالة النجاح مع التحذير إذا كان موجود
        if (warningMessage != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('تم توزيع المشروبات بنجاح!',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text(warningMessage!, style: const TextStyle(fontSize: 12)),
                ],
              ),
              duration: const Duration(seconds: 4),
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('تم توزيع المشروبات بنجاح!')),
          );
        }

        _resetFields();
      } catch (e) {
        debugPrint('خطأ أثناء الحفظ: $e');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('حدث خطأ أثناء توزيع المشروبات: $e')),
        );
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('يرجى ملء جميع الحقول بشكل صحيح.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (bool didPop, dynamic result) {
        if (didPop) return;
        widget.navigateToDistribute_expenses();
      },
      child: BackgroundScaffold(
        backgroundImagePath: widget.backgroundImagePath,
        child: Stack(
          children: [
            Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const Text(
                      'توزيع المشروبات',
                      style: TextStyle(
                        fontSize: 40,
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                        fontFamily: 'DancingScript',
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 20),
                    TextField(
                      controller: _dateController,
                      decoration: InputDecoration(
                        labelText: 'التاريخ',
                        labelStyle: const TextStyle(
                          color: Colors.white,
                          fontFamily: 'Lalezar',
                        ),
                        filled: true,
                        fillColor: Colors.black.withOpacity(0.7),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      style: const TextStyle(
                        color: Colors.white,
                        fontFamily: 'Lalezar',
                      ),
                      readOnly: true,
                      onTap: () async {
                        DateTime? picked = await showDatePicker(
                          context: context,
                          initialDate: DateTime.now(),
                          firstDate: DateTime(2000),
                          lastDate: DateTime(2100),
                        );
                        if (picked != null) {
                          _dateController.text =
                              DateFormat('yyyy-MM-dd').format(picked);
                        }
                      },
                    ),
                    const SizedBox(height: 20),
                    FutureBuilder<List<Map<String, dynamic>>>(
                      future: widget.db.fetchAll(
                          'SELECT item_name FROM expenses WHERE is_drink = 1'),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState ==
                            ConnectionState.waiting) {
                          return const CircularProgressIndicator();
                        } else if (snapshot.hasError) {
                          return const Text(
                            'حدث خطأ أثناء تحميل الأصناف',
                            style: TextStyle(
                              color: Colors.black,
                              fontFamily: 'Lalezar',
                            ),
                          );
                        } else if (!snapshot.hasData ||
                            snapshot.data!.isEmpty) {
                          return const Text(
                            'لا توجد مشروبات متاحة',
                            style: TextStyle(
                              color: Colors.black,
                              fontFamily: 'Lalezar',
                            ),
                          );
                        }
                        return DropdownButtonFormField<String>(
                          value: _drinkName,
                          decoration: InputDecoration(
                            labelText: 'اختر المشروب',
                            labelStyle: const TextStyle(
                              color: Colors.white,
                              fontFamily: 'Lalezar',
                            ),
                            filled: true,
                            fillColor: Colors.black.withOpacity(0.7),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          hint: const Text(
                            'اختر المشروب',
                            style: TextStyle(
                              color: Colors.white,
                              fontFamily: 'Lalezar',
                            ),
                          ),
                          items: snapshot.data!
                              .map((row) => DropdownMenuItem<String>(
                                    value: row['item_name'],
                                    alignment: AlignmentDirectional.centerEnd,
                                    child: Text(
                                      row['item_name'],
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontFamily: 'Lalezar',
                                      ),
                                      textDirection: ui.TextDirection.rtl,
                                    ),
                                  ))
                              .toList(),
                          onChanged: (String? newValue) {
                            setState(() {
                              _drinkName = newValue;
                            });
                          },
                          style: const TextStyle(
                            color: Colors.white,
                            fontFamily: 'Lalezar',
                          ),
                          dropdownColor: Colors.black.withOpacity(0.7),
                          isExpanded: true,
                          alignment: AlignmentDirectional.centerEnd,
                          itemHeight: 50,
                        );
                      },
                    ),
                    const SizedBox(height: 20),
                    TextField(
                      controller: _quantityController,
                      decoration: InputDecoration(
                        labelText: 'العدد',
                        alignLabelWithHint: true,
                        labelStyle: const TextStyle(
                          color: Colors.white,
                          fontFamily: 'Lalezar',
                        ),
                        filled: true,
                        fillColor: Colors.black.withOpacity(0.7),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      style: const TextStyle(
                        color: Colors.white,
                        fontFamily: 'Lalezar',
                      ),
                      keyboardType: TextInputType.number,
                      textDirection: ui.TextDirection.rtl,
                      textAlign: TextAlign.right,
                      textAlignVertical: TextAlignVertical.center,
                    ),
                    const SizedBox(height: 20),
                    FutureBuilder<List<Map<String, dynamic>>>(
                      future: widget.db.fetchAll(
                          'SELECT member_id, rank, name FROM members ORDER BY CASE rank WHEN \'لواء\' THEN 1 WHEN \'عميد\' THEN 2 WHEN \'عقيد\' THEN 3 WHEN \'مقدم\' THEN 4 WHEN \'رائد\' THEN 5 WHEN \'نقيب\' THEN 6 WHEN \'ملازم أول\' THEN 7 WHEN \'ملازم\' THEN 8 ELSE 9 END'),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState ==
                            ConnectionState.waiting) {
                          return const CircularProgressIndicator();
                        } else if (snapshot.hasError) {
                          return const Text(
                            'حدث خطأ أثناء تحميل الأعضاء',
                            style: TextStyle(
                              color: Colors.black,
                              fontFamily: 'Lalezar',
                            ),
                          );
                        } else if (!snapshot.hasData ||
                            snapshot.data!.isEmpty) {
                          return const Text(
                            'لا يوجد أعضاء متاحين',
                            style: TextStyle(
                              color: Colors.black,
                              fontFamily: 'Lalezar',
                            ),
                          );
                        }
                        return DropdownButtonFormField<String>(
                          value: _memberId,
                          decoration: InputDecoration(
                            labelText: 'اختر الشخص',
                            labelStyle: const TextStyle(
                              color: Colors.white,
                              fontFamily: 'Lalezar',
                            ),
                            filled: true,
                            fillColor: Colors.black.withOpacity(0.7),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          hint: const Text(
                            'اختر الشخص',
                            style: TextStyle(
                              color: Colors.white,
                              fontFamily: 'Lalezar',
                            ),
                            textDirection: ui.TextDirection.rtl,
                          ),
                          items: snapshot.data!.asMap().entries.map((entry) {
                            final index = entry.key;
                            final row = entry.value;
                            return DropdownMenuItem<String>(
                              value: row['member_id'].toString(),
                              alignment: AlignmentDirectional.centerEnd,
                              child: Text(
                                '${index + 1} - ${row['rank'] ?? ''} ${row['name'] ?? ''}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontFamily: 'Lalezar',
                                ),
                                textDirection: ui.TextDirection.rtl,
                              ),
                            );
                          }).toList(),
                          onChanged: (String? newValue) {
                            setState(() {
                              _memberId = newValue;
                            });
                          },
                          style: const TextStyle(
                            color: Colors.white,
                            fontFamily: 'Lalezar',
                          ),
                          dropdownColor: Colors.black.withOpacity(0.7),
                          isExpanded: true,
                          alignment: AlignmentDirectional.centerEnd,
                          itemHeight: 50,
                        );
                      },
                    ),
                    const SizedBox(height: 20),
                    createButton(
                      text: 'حفظ',
                      onPressed: _saveDrinkDistribution,
                      bgColor: Colors.green[700]!,
                    ),
                    const SizedBox(height: 20),
                    createButton(
                      text: 'رجوع',
                      onPressed: () => _navigateTo('distribute_expenses'),
                      bgColor: Colors.red[700]!,
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
