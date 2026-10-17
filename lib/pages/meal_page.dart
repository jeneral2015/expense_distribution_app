import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../utils/button_utils.dart';
import '../utils/database.dart';
import '../utils/background_scaffold.dart';
import '../utils/undo_manager.dart';
import 'package:intl/intl.dart' hide TextDirection;
import '../core/constants/app_ranks.dart';

class MealPage extends StatefulWidget {
  final DatabaseManager db;
  final VoidCallback navigateToDistribute_expenses;
  final String backgroundImagePath;

  const MealPage({
    Key? key,
    required this.db,
    required this.navigateToDistribute_expenses,
    required this.backgroundImagePath,
  }) : super(key: key);

  @override
  _MealPageState createState() => _MealPageState();
}

class _MealPageState extends State<MealPage> {
  late TextEditingController _dateController;
  late String? _mealType;
  late Map<String, bool> _selectedMeals;
  late Map<String, TextEditingController> _mealQuantities;
  late bool _miscVar;
  late Map<String, int> _memberMeals; // Changed from Map<String, bool> to Map<String, int>
  int _currentStep = 0;

  @override
  void initState() {
    super.initState();
    _dateController = TextEditingController(
      text: DateFormat('yyyy-MM-dd').format(DateTime.now()),
    );
    _mealType = null;
    _selectedMeals = {};
    _mealQuantities = {};
    _miscVar = false;
    _memberMeals = {};
  }

  @override
  void dispose() {
    _dateController.dispose();
    _mealQuantities.forEach((_, controller) => controller.dispose());
    super.dispose();
  }

  void _navigateTo(String page) {
    if (page == 'distribute_expenses') {
      widget.navigateToDistribute_expenses();
    } else {
      context.go('/$page');
    }
  }

  Future<void> _saveMealData() async {
    try {
      final selectedMembersWithMeals = _memberMeals.entries
          .where((e) => e.value > 0)
          .toList();

      if (selectedMembersWithMeals.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('لم يتم اختيار أي أعضاء!')),
        );
        return;
      }

      double totalCost = 0;
      final hasSelectedItems = _selectedMeals.values.any((v) => v);

      // Calculate total cost and prepare meal items
      final Map<String, Map<String, dynamic>> mealItemsData = {};

      if (hasSelectedItems) {
        for (var entry in _selectedMeals.entries.where((e) => e.value)) {
          final quantity = double.parse(_mealQuantities[entry.key]!.text);
          final priceData = await widget.db.fetchOne(
            'SELECT price FROM expenses WHERE item_name = ?',
            [entry.key],
          );

          if (priceData == null) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('الصنف ${entry.key} غير موجود!')),
            );
            return;
          }

          final price = priceData['price'] as double;
          final itemCost = quantity * price;
          totalCost += itemCost;

          mealItemsData[entry.key] = {
            'quantity': quantity,
            'price': price,
            'cost': itemCost,
          };
        }
      }

      // Add miscellaneous expenses if selected
      double miscTotal = 0;
      if (_miscVar) {
        miscTotal = double.parse(_mealQuantities['misc']!.text);
        totalCost += miscTotal;
      }

      // Calculate total meals across all members
      final int totalMeals = _memberMeals.values.fold(0, (sum, meals) => sum + meals);
      final double costPerMeal = totalCost / totalMeals;
      final double miscPerMeal = miscTotal / totalMeals;

      await widget.db.transaction((txn) async {
        // Insert into meals table first
        final mealId = await txn.rawInsert(
          'INSERT INTO meals (meal_type, date, total_cost, misc_total) VALUES (?, ?, ?, ?)',
          [_mealType, _dateController.text, totalCost, miscTotal],
        );

        // Insert meal items
        for (var entry in mealItemsData.entries) {
          await txn.rawInsert(
            'INSERT INTO meal_items (meal_id, item_name, quantity_used, price_at_time) VALUES (?, ?, ?, ?)',
            [mealId, entry.key, entry.value['quantity'], entry.value['price']],
          );

          // Update consumption in expenses
          await txn.rawUpdate(
            'UPDATE expenses SET consumption = consumption + ?, remaining = remaining - ? WHERE item_name = ?',
            [entry.value['quantity'], entry.value['quantity'], entry.key],
          );
        }

        for (var entry in selectedMembersWithMeals) {
          final member = entry.key;
          final meals = entry.value;
          final memberIdData = await txn.rawQuery(
            'SELECT member_id FROM members WHERE rank || \' \' || name = ?',
            [member],
          );

          if (memberIdData.isEmpty) {
            throw Exception('العضو $member غير موجود.');
          }

          final memberId = memberIdData.first['member_id'] as int;
          final memberCost = meals * costPerMeal;
          final memberMisc = meals * miscPerMeal;

          // Insert meal record
          final mealRecordId = await txn.rawInsert(
            'INSERT INTO meal_records (meal_type, date, member_id, final_cost, meal_id, is_legacy) VALUES (?, ?, ?, ?, ?, ?)',
            [_mealType, _dateController.text, memberId, memberCost, mealId, 0],
          );

          // Update member dues
          await txn.rawUpdate(
            'UPDATE members SET total_due = total_due + ? WHERE member_id = ?',
            [memberCost, memberId],
          );

          // Insert miscellaneous expense if applicable
          if (_miscVar && memberMisc > 0) {
            await txn.rawInsert(
              'INSERT INTO miscellaneous_expenses (date, amount, meal_type, meal_record_id, member_id) VALUES (?, ?, ?, ?, ?)',
              [
                _dateController.text,
                memberMisc,
                _mealType,
                mealRecordId,
                memberId,
              ],
            );
          }
        }
      });

      // Add undo action
      final undoManager = UndoManager();
      undoManager.addAction(UndoAction(
        type: 'meal',
        id: -1, // Will be updated with actual meal_id after transaction
        data: {
          'meal_type': _mealType,
          'date': _dateController.text,
          'total_cost': totalCost,
          'misc_total': miscTotal,
          'selected_members': selectedMembersWithMeals.map((e) => e.key).toList(),
          'member_meals': Map<String, int>.from(_memberMeals),
          'meal_items': mealItemsData,
        },
        timestamp: DateTime.now(),
      ));

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم حفظ البيانات بنجاح!')),
      );

      // Reset form
      setState(() {
        _currentStep = 0;
        _mealType = null;
        _selectedMeals.clear();
        _mealQuantities.forEach((_, controller) => controller.dispose());
        _mealQuantities.clear();
        _miscVar = false;
        _memberMeals.clear();
      });
    } catch (e) {
      debugPrint('خطأ أثناء حفظ المأكولات: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('حدث خطأ: $e')),
      );
    }
  }

  Widget _buildResponsiveButton({
    required String text,
    required VoidCallback onPressed,
    required Color bgColor,
    required BuildContext context,
    double minWidth = 100,
    double maxWidth = 200,
    double heightRatio = 0.06,
  }) {
    final mediaQuery = MediaQuery.of(context);
    final bool isPortrait = mediaQuery.orientation == Orientation.portrait;
    final double screenWidth = mediaQuery.size.width;
    final double buttonWidth = isPortrait
        ? screenWidth * 0.4
        : screenWidth * 0.25;
    final double buttonHeight = mediaQuery.size.height * heightRatio;

    return Container(
      constraints: BoxConstraints(
        minWidth: minWidth,
        maxWidth: maxWidth,
      ),
      width: buttonWidth.clamp(minWidth, maxWidth),
      height: buttonHeight,
      child: createButton(
        text: text,
        onPressed: onPressed,
        bgColor: bgColor,
        width: buttonWidth.clamp(minWidth, maxWidth),
        height: buttonHeight,
      ),
    );
  }

  Widget _buildNavigationButtons({
    required BuildContext context,
    required VoidCallback onBack,
    required VoidCallback onNext,
    required String nextText,
    bool isLastStep = false,
  }) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildResponsiveButton(
            context: context,
            text: 'رجوع',
            onPressed: onBack,
            bgColor: Colors.red[700]!,
          ),
          const SizedBox(width: 20),
          _buildResponsiveButton(
            context: context,
            text: isLastStep ? 'حفظ' : nextText,
            onPressed: onNext,
            bgColor: Colors.green[700]!,
          ),
        ],
      ),
    );
  }

  Widget _buildItemsList(List<Map<String, dynamic>> items) {
    return StatefulBuilder(
      builder: (context, setState) {
        return Container(
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.7),
            borderRadius: BorderRadius.circular(10),
          ),
          padding: const EdgeInsets.all(10),
          child: Column(
            children: [
              ...items.map((row) {
                return CheckboxListTile(
                  title: Text(
                    row['item_name'],
                    style: const TextStyle(
                      color: Colors.white,
                      
                    ),
                  ),
                  value: _selectedMeals[row['item_name']] ?? false,
                  onChanged: (bool? value) {
                    setState(() {
                      _selectedMeals[row['item_name']] = value ?? false;
                    });
                  },
                  activeColor: Colors.green,
                  checkColor: Colors.white,
                  tileColor: Colors.transparent,
                );
              }).toList(),
              // مصاريف أخرى
              CheckboxListTile(
                title: const Text(
                  'مصاريف أخرى',
                  style: TextStyle(
                    color: Colors.white,
                    
                  ),
                ),
                value: _miscVar,
                onChanged: (bool? value) {
                  setState(() {
                    _miscVar = value ?? false;
                  });
                },
                activeColor: Colors.green,
                checkColor: Colors.white,
                tileColor: Colors.transparent,
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildMembersList(List<Map<String, dynamic>> members) {
    return StatefulBuilder(
      builder: (context, setState) {
        return Container(
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.7),
            borderRadius: BorderRadius.circular(10),
          ),
          padding: const EdgeInsets.all(10),
          child: Column(
            children: [
              for (int i = 0; i < members.length; i++)
                Directionality(
                  textDirection: TextDirection.rtl,
                  child: Container(
                    margin: const EdgeInsets.symmetric(vertical: 4.0),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.white.withOpacity(0.3)),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Checkbox(
                          value: (_memberMeals[members[i]['display_name']] ?? 0) > 0, // Fixed: Convert int to bool
                          onChanged: (bool? value) {
                            setState(() {
                              final name = members[i]['display_name'];
                              if (value == true) {
                                _memberMeals[name] = 1; // Default to 1 meal when selected
                              } else {
                                _memberMeals.remove(name); // Remove if unchecked
                              }
                            });
                          },
                          activeColor: Colors.green,
                          checkColor: Colors.white,
                        ),
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: Text(
                              '${(i + 1)} - ${members[i]['display_name']}',
                              style: const TextStyle(
                                color: Colors.white,
                                
                              ),
                              textAlign: TextAlign.right,
                            ),
                          ),
                        ),
                        if ((_memberMeals[members[i]['display_name']] ?? 0) > 0)
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.remove, color: Colors.white, size: 20),
                                onPressed: () {
                                  setState(() {
                                    final name = members[i]['display_name'];
                                    int current = _memberMeals[name] ?? 0;
                                    if (current > 1) {
                                      _memberMeals[name] = current - 1;
                                    } else {
                                      _memberMeals.remove(name); // Uncheck if meals reach 0
                                    }
                                  });
                                },
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  '${_memberMeals[members[i]['display_name']] ?? 0}',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.add, color: Colors.white, size: 20),
                                onPressed: () {
                                  setState(() {
                                    final name = members[i]['display_name'];
                                    _memberMeals[name] = (_memberMeals[name] ?? 0) + 1;
                                  });
                                },
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
                              ),
                            ],
                          ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  List<Widget> _buildStepContent(BuildContext context) {
    if (_currentStep == 0) {
      return [

        TextField(
          controller: _dateController,
          decoration: InputDecoration(
            labelText: 'التاريخ',
            labelStyle: const TextStyle(
              color: Colors.white,
              
            ),
            filled: true,
            fillColor: Colors.black.withOpacity(0.7),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          style: const TextStyle(
            color: Colors.white,
            
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
              _dateController.text = DateFormat('yyyy-MM-dd').format(picked);
            }
          },
        ),
        const SizedBox(height: 20),
        DropdownButtonFormField<String>(
          value: _mealType,
          decoration: InputDecoration(
            labelText: 'اختر نوع الوجبة',
            labelStyle: const TextStyle(
              color: Colors.white,
              
            ),
            filled: true,
            fillColor: Colors.black.withOpacity(0.7),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          hint: const Text(
            'نوع الوجبة',
            style: TextStyle(
              color: Colors.white,
              
            ),
          ),
          items: ['فطار', 'غداء', 'عشاء'].map((String value) {
            return DropdownMenuItem<String>(
              value: value,
              child: Text(
                value,
                style: const TextStyle(
                  color: Colors.white,
                  
                ),
              ),
            );
          }).toList(),
          onChanged: (String? newValue) {
            setState(() {
              _mealType = newValue;
            });
          },
          style: const TextStyle(
            color: Colors.white,
            
          ),
          dropdownColor: Colors.black.withOpacity(0.7),
        ),
        const SizedBox(height: 20),
        _buildNavigationButtons(
          context: context,
          onBack: () => _navigateTo('distribute_expenses'),
          onNext: () {
            if (_mealType == null) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('يرجى اختيار نوع الوجبة!')),
              );
            } else {
              setState(() {
                _currentStep = 1;
              });
            }
          },
          nextText: 'التالي',
        ),
      ];
    } else if (_currentStep == 1) {
      return [

        FutureBuilder<List<Map<String, dynamic>>>(
          future: widget.db.fetchAll('SELECT item_name FROM expenses WHERE is_drink = 0 AND is_miscellaneous = 0 AND remaining > 0'),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            } else if (snapshot.hasError) {
              return const Text(
                'حدث خطأ أثناء تحميل الأصناف',
                style: TextStyle(
                  color: Colors.black,
                  
                ),
              );
            } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
              return Column(
                children: [
                  const Text(
                    'لا توجد أصناف متاحة',
                    style: TextStyle(
                      color: Colors.black,
                      
                    ),
                  ),
                  const SizedBox(height: 10),
                  _buildItemsList([]),
                ],
              );
            }
            return _buildItemsList(snapshot.data!);
          },
        ),
        const SizedBox(height: 20),
        _buildNavigationButtons(
          context: context,
          onBack: () {
            setState(() {
              _currentStep = 0;
            });
          },
          onNext: () {
            if (!(_selectedMeals.values.any((v) => v) || _miscVar)) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('يرجى اختيار صنف واحد على الأقل أو مصاريف أخرى!')),
              );
            } else {
              setState(() {
                _currentStep = 2;
              });
            }
          },
          nextText: 'التالي',
        ),
      ];
    } else if (_currentStep == 2) {
      return [

        ..._selectedMeals.entries.where((e) => e.value).map((e) {
          final controller = _mealQuantities[e.key] ??= TextEditingController();
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 6.0),
            child: TextField(
              controller: controller,
              decoration: InputDecoration(
                labelText: 'كمية ${e.key}',
                labelStyle: const TextStyle(
                  color: Colors.white,
                  
                ),
                filled: true,
                fillColor: Colors.black.withOpacity(0.7),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              style: const TextStyle(
                color: Colors.white,
                
              ),
              keyboardType: TextInputType.number,
            ),
          );
        }).toList(),
        if (_miscVar)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6.0),
            child: TextField(
              controller: _mealQuantities['misc'] ??= TextEditingController(),
              decoration: InputDecoration(
                labelText: 'مبلغ المصاريف الأخرى',
                labelStyle: const TextStyle(
                  color: Colors.white,
                  
                ),
                filled: true,
                fillColor: Colors.black.withOpacity(0.7),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              style: const TextStyle(
                color: Colors.white,
                
              ),
              keyboardType: TextInputType.number,
            ),
          ),
        const SizedBox(height: 20),
        _buildNavigationButtons(
          context: context,
          onBack: () {
            setState(() {
              _currentStep = 1;
            });
          },
          onNext: () async {
            bool hasError = false;

            // التحقق من صحة المدخلات للأصناف المختارة
            for (var entry in _selectedMeals.entries.where((e) => e.value)) {
              final controller = _mealQuantities[entry.key] ?? TextEditingController();
              final value = controller.text;

              if (value.isEmpty) {
                hasError = true;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('حقل كمية ${entry.key} مطلوب!')),
                );
                break;
              }

              try {
                final quantity = double.parse(value);
                if (quantity <= 0) {
                  hasError = true;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('كمية ${entry.key} يجب أن تكون أكبر من صفر!')),
                  );
                  break;
                }

                final remaining = (await widget.db.fetchOne(
                  'SELECT remaining FROM expenses WHERE item_name = ?',
                  [entry.key],
                ))?['remaining'] ?? 0.0;

                if (quantity > remaining) {
                  hasError = true;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('الكمية المطلوبة لـ ${entry.key} غير متوفرة! المتاح: $remaining')),
                  );
                  break;
                }
              } catch (e) {
                hasError = true;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('حقل كمية ${entry.key} يجب أن يكون رقمًا صحيحًا أو عشريًا!')),
                );
                break;
              }
            }

            // التحقق من صحة المدخلات للمصاريف الأخرى (إذا تم اختيارها)
            if (_miscVar && !hasError) {
              final miscController = _mealQuantities['misc'] ?? TextEditingController();
              final miscValue = miscController.text;

              if (miscValue.isEmpty) {
                hasError = true;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('حقل مبلغ المصاريف الأخرى مطلوب!')),
                );
              } else {
                try {
                  final miscAmount = double.parse(miscValue);
                  if (miscAmount <= 0) {
                    hasError = true;
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('مبلغ المصاريف الأخرى يجب أن يكون أكبر من صفر!')),
                    );
                  }
                } catch (e) {
                  hasError = true;
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('حقل مبلغ المصاريف الأخرى يجب أن يكون رقمًا!')),
                  );
                }
              }
            }

            // التحقق من أنه تم اختيار صنف واحد على الأقل أو مصاريف أخرى
            final hasSelectedItems = _selectedMeals.values.any((v) => v);
            if (!hasSelectedItems && !_miscVar && !hasError) {
              hasError = true;
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('يرجى اختيار صنف واحد على الأقل أو مصاريف أخرى!')),
              );
            }

            if (!hasError) {
              setState(() {
                _currentStep = 3;
              });
            }
          },
          nextText: 'التالي',
        ),
      ];
    } else if (_currentStep == 3) {
      return [

        FutureBuilder<List<Map<String, dynamic>>>(
          future: widget.db.fetchAll(
            'SELECT member_id, rank, rank || \' \' || name AS display_name FROM members ORDER BY ${AppRanks.sqlRankOrder('rank')}',
          ),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            } else if (snapshot.hasError) {
              return const Text(
                'حدث خطأ أثناء تحميل الأعضاء',
                style: TextStyle(
                  color: Colors.black,
                  
                ),
              );
            } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
              return const Text(
                'لا يوجد أعضاء متاحين',
                style: TextStyle(
                  color: Colors.black,
                  
                ),
              );
            }
            return _buildMembersList(snapshot.data!);
          },
        ),
        const SizedBox(height: 20),
        _buildNavigationButtons(
          context: context,
          onBack: () {
            setState(() {
              _currentStep = 2;
            });
          },
          onNext: () async {
            if (_memberMeals.values.any((meals) => meals > 0)) {
              await _saveMealData();
            } else {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('لم يتم اختيار أي أعضاء!')),
              );
            }
          },
          nextText: 'حفظ',
          isLastStep: true,
        ),
      ];
    }
    return [];
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvoked: (bool didPop) {
        if (didPop) return;
        widget.navigateToDistribute_expenses();
      },
      child: BackgroundScaffold(
        title: 'توزيع الوجبات',
        backgroundImagePath: widget.backgroundImagePath,
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: constraints.maxHeight,
                ),
                child: IntrinsicHeight(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      ..._buildStepContent(context),
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}