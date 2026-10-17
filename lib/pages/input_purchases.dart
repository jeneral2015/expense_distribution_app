import 'package:flutter/material.dart';
import '../utils/button_utils.dart';
import '../utils/database.dart';
import '../utils/background_scaffold.dart';
import '../utils/logger.dart';
import '../services/auth_service.dart';
import '../core/utils/formatters.dart';
import '../core/utils/snackbar_utils.dart';

class InputPurchasesPage extends StatefulWidget {
  final DatabaseManager db;
  final VoidCallback navigateToInput;
  final String backgroundImagePath;

  const InputPurchasesPage({
    Key? key,
    required this.db,
    required this.navigateToInput,
    required this.backgroundImagePath,
  }) : super(key: key);

  @override
  _InputPurchasesPageState createState() => _InputPurchasesPageState();
}

class _InputPurchasesPageState extends State<InputPurchasesPage> {
  String? _selectedItemName;
  String? _selectedUnit;
  final TextEditingController _quantityController = TextEditingController();
  final TextEditingController _totalPriceController = TextEditingController();
  final TextEditingController _newItemNameController = TextEditingController();
  List<String> _similarItems = [];
  final List<String> _tempItems = []; // Temporary list for new items

  final List<String> _unitOptions = ['عدد', 'كيلوجرام', 'لتر'];

  bool _isMiscellaneous = false; // نثريات (لا تزيد المخزون، تضاف مباشرة للاستهلاك)
  bool _isDrink = false;

  double _asDouble(dynamic v, [double fallback = 0.0]) =>
      Formatters.toDouble(v, fallback);

  @override
  void initState() {
    super.initState();
    widget.db.initializeDatabase();
  }

  @override
  void dispose() {
    _quantityController.dispose();
    _totalPriceController.dispose();
    _newItemNameController.dispose();
    super.dispose();
  }

  Future<List<DropdownMenuItem<String>>> _getExpenseOptions() async {
    final results = await widget.db.fetchAll('SELECT DISTINCT item_name FROM expenses');
    AppLogger.logInfo('Fetched expense options: $results');
    final dbItems = results.map((row) => row['item_name'] as String).toList();
    final defaultItems = ['سكر', 'قهوة', 'شاي']; // الأصناف الافتراضية
    final allItems = <String>{...dbItems, ..._tempItems, ...defaultItems}.toList();
    return allItems
        .map((item) => DropdownMenuItem<String>(
              value: item,
              child: Text(
                item,
                textDirection: TextDirection.rtl,
                style: const TextStyle(color: Colors.white, ),
              ),
            ))
        .toList();
  }

  Future<void> _searchSimilarItems(String query, StateSetter dialogSetState) async {
    if (query.trim().isEmpty) {
      dialogSetState(() {
        _similarItems = [];
      });
      return;
    }
    final results = await widget.db.fetchAll(
      'SELECT item_name FROM expenses WHERE item_name LIKE ?',
      ['%${query.trim()}%'],
    );
    AppLogger.logInfo('Similar items found for query "$query": $results');
    dialogSetState(() {
      _similarItems = results.map((row) => row['item_name'] as String).toList();
    });
  }

  void _selectSimilarItem(String item) {
    setState(() {
      _selectedItemName = item;
      _similarItems = [];
    });
    _newItemNameController.clear();
    Navigator.of(context).pop();
    _showSnackBar('تم اختيار الصنف: $item');
  }

  void _openAddItemDialog() {
    AppLogger.logInfo('Opening Add Item Dialog');
    _newItemNameController.clear();
    _similarItems = [];
    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (BuildContext context, StateSetter dialogSetState) {
          return AlertDialog(
            title: const Text(
              'إضافة صنف جديد',
              textDirection: TextDirection.rtl,
              style: TextStyle(),
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: _newItemNameController,
                    decoration: InputDecoration(
                      labelText: 'اسم الصنف الجديد',
                      labelStyle: const TextStyle(color: Colors.black, ),
                      filled: true,
                      fillColor: Colors.black.withOpacity(0.1),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    style: const TextStyle(color: Colors.black, ),
                    textDirection: TextDirection.rtl,
                    onChanged: (query) {
                      AppLogger.logInfo('Searching for: $query');
                      _searchSimilarItems(query, dialogSetState);
                    },
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'الأصناف المشابهة:',
                    style: TextStyle(
                      color: Colors.red,
                      fontWeight: FontWeight.bold,
                      
                    ),
                    textDirection: TextDirection.rtl,
                  ),
                  SizedBox(
                    height: 100,
                    width: double.maxFinite,
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: _similarItems.length,
                      itemBuilder: (context, index) {
                        final item = _similarItems[index];
                        return ListTile(
                          title: Text(
                            item,
                            style: const TextStyle(color: Colors.black, ),
                            textDirection: TextDirection.rtl,
                          ),
                          onTap: () {
                            AppLogger.logInfo('Selected item: $item');
                            _selectSimilarItem(item);
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              createButton(
                text: 'إضافة',
                onPressed: () {
                  AppLogger.logInfo('Add button pressed');
                  _addNewItem();
                },
                bgColor: Colors.green[700]!,
                width: 100,
                height: 40,
              ),
              createButton(
                text: 'إلغاء',
                onPressed: () {
                  AppLogger.logInfo('Cancel button pressed');
                  Navigator.of(dialogContext).pop();
                },
                bgColor: Colors.red[700]!,
                width: 100,
                height: 40,
              ),
            ],
            actionsAlignment: MainAxisAlignment.center,
          );
        },
      ),
    ).then((_) {
      AppLogger.logInfo('Dialog closed');
      setState(() {});
    });
  }

  void _addNewItem() {
    final newItem = _newItemNameController.text.trim();
    AppLogger.logInfo('Attempting to add new item: $newItem');
    if (newItem.isEmpty) {
      AppLogger.logInfo('Item name is empty');
      _showSnackBar('يرجى إدخال اسم الصنف!');
      return;
    }

    if (_tempItems.contains(newItem) || _similarItems.contains(newItem)) {
      AppLogger.logInfo('Item already exists in temp or database');
      _showSnackBar('هذا الصنف موجود بالفعل!');
      return;
    }

    setState(() {
      _tempItems.add(newItem);
      _selectedItemName = newItem;
    });
    AppLogger.logInfo('Item "$newItem" added to temp list: $_tempItems');
    _newItemNameController.clear();
    _similarItems = [];
    Navigator.of(context).pop();
    _showSnackBar('تم إضافة الصنف بنجاح!');
  }

  Future<void> _saveExpense() async {
    final itemName = _selectedItemName;
    final quantityText = _quantityController.text.trim();
    final totalPriceText = _totalPriceController.text.trim();
    final unit = _selectedUnit;

    AppLogger.logInfo(
        'Saving expense: item=$itemName, quantity=$quantityText, totalPrice=$totalPriceText, unit=$unit, misc=$_isMiscellaneous, drink=$_isDrink');

    if (itemName == null || quantityText.isEmpty || totalPriceText.isEmpty) {
      AppLogger.logInfo('Missing required fields');
      _showSnackBar('يرجى ملء جميع الحقول بشكل صحيح!');
      return;
    }

    // Validate decimal quantity format (up to 2 decimals)
    final quantityRegex = RegExp(r'^\d+(\.\d{1,2})?$');
    if (!quantityRegex.hasMatch(quantityText)) {
      _showSnackBar('يرجى إدخال كمية صحيحة (رقم مع اختياريًا منزلتين عشريتين)');
      return;
    }

    try {
      final double addQty = double.parse(quantityText);
      final double addTotalPrice = double.parse(totalPriceText); // إجمالي سعر الدفعة الجديدة
      if (addQty <= 0 || addTotalPrice <= 0) {
        AppLogger.logInfo('Invalid quantity or price');
        _showSnackBar('الكمية والسعر يجب أن يكونا أكبر من صفر!');
        return;
      }

      final String currentDate = DateTime.now().toIso8601String().split('T')[0];

      // Fetch existing expense data
      final results = await widget.db.fetchAll(
        'SELECT quantity, price, remaining, consumption, total_price, is_miscellaneous, is_drink, unit FROM expenses WHERE item_name = ?',
        [itemName],
      );
      AppLogger.logInfo('Fetched existing expense: $results');

      // Fetch actual consumption from related tables
      double newConsumption = 0.0;
      if (_isDrink) {
        final drinkConsumption = await widget.db.fetchAll(
          'SELECT COALESCE(SUM(quantity), 0) as total FROM drink_records WHERE drink_name = ?',
          [itemName],
        );
        newConsumption += _asDouble(drinkConsumption.isNotEmpty ? drinkConsumption.first['total'] : 0.0);
      }
      if (!_isMiscellaneous) {
        final mealConsumption = await widget.db.fetchAll(
          'SELECT COALESCE(SUM(quantity_used), 0) as total FROM meal_items WHERE item_name = ?',
          [itemName],
        );
        newConsumption += _asDouble(mealConsumption.isNotEmpty ? mealConsumption.first['total'] : 0.0);
      }
      if (_isMiscellaneous) {
        // For miscellaneous items, add the new quantity to consumption
        newConsumption += addQty;
      }

      if (results.isNotEmpty) {
        final row = results[0];
        final double oldQty = _asDouble(row['quantity']); // إجمالي ما دخل من أول الشهر
        final double oldPrice = _asDouble(row['price']);   // سعر الوحدة الحالي (المرجعي)
        final double storedRemaining = _asDouble(row['remaining']);
        final double oldConsumption = _asDouble(row['consumption']);
        final double oldTotalSpent = _asDouble(row['total_price']); // إجمالي المصروفات حتى الآن
        final String? oldUnit = row['unit'] as String?;

        // Compute canonical remaining from quantity - consumption to repair possible DB drift
        final double computedRemaining = (oldQty - oldConsumption) >= 0 ? (oldQty - oldConsumption) : 0.0;
        if ((storedRemaining - computedRemaining).abs() > 0.0001) {
          AppLogger.logInfo(
              'Inconsistent remaining value for "$itemName". stored=$storedRemaining computed=$computedRemaining. Using computedRemaining to keep consistency.');
        }
        final double oldRemaining = computedRemaining; // use computed as source-of-truth

        final double newQtyCumulative = oldQty + addQty; // إجمالي ما دخل من أول الشهر

        // Check if new consumption exceeds total quantity
        if (newConsumption > newQtyCumulative) {
          AppLogger.logInfo('Consumption exceeds available quantity: $newConsumption > $newQtyCumulative');
          _showSnackBar('الاستهلاك يتجاوز الكمية المتاحة!');
          return;
        }

        // Calculate new remaining
        final double newRemaining = newQtyCumulative - newConsumption;

        if (_isMiscellaneous) {
          final double newUnitPrice = oldPrice; // لا نعيد حساب السعر لأنه لم يتغير المخزون
          final double newTotalSpent = oldTotalSpent + addTotalPrice; // إجمالي مصروفات الشهر

          await widget.db.database!.update(
            'expenses',
            {
              'quantity': newQtyCumulative,
              'consumption': newConsumption,
              'remaining': newRemaining,
              'price': newUnitPrice,
              'total_price': newTotalSpent, // تراكمي للصرف من أول الشهر
              'is_miscellaneous': 1,
              'is_drink': _isDrink ? 1 : 0,
              'unit': unit ?? oldUnit,
              'date': currentDate,
            },
            where: 'item_name = ?',
            whereArgs: [itemName],
          );
          AppLogger.logInfo('Updated (misc) expense for item "$itemName"');
        } else {
          // إضافة مخزنية عادية: نحسب متوسط سعر الوحدة بناءً على (المتبقي القديم + الدفعة الجديدة)
          final double inventoryOldValue = oldRemaining * oldPrice; // قيمة المتبقي القديم
          final double inventoryNewQty = oldRemaining + addQty;     // كمية المخزون بعد الإضافة
          final double inventoryNewValue = inventoryOldValue + addTotalPrice; // قيمة المخزون بعد الإضافة
          final double newUnitPrice = inventoryNewQty > 0 ? (inventoryNewValue / inventoryNewQty) : oldPrice;

          await widget.db.database!.update(
            'expenses',
            {
              'quantity': newQtyCumulative,
              'remaining': newRemaining,
              'consumption': newConsumption,
              'price': newUnitPrice,      // متوسط السعر العادل الحالي للمخزون
              'total_price': oldTotalSpent + addTotalPrice, // إجمالي المصروفات التراكمي
              'is_miscellaneous': 0,
              'is_drink': _isDrink ? 1 : 0,
              'unit': unit ?? oldUnit,
              'date': currentDate,
            },
            where: 'item_name = ?',
            whereArgs: [itemName],
          );
          AppLogger.logInfo('Updated (stock add) expense for item "$itemName"');
        }
      } else {
        // صنف جديد بالكامل
        final double unitPrice = addTotalPrice / addQty;

        // For new items, consumption is 0 unless miscellaneous
        if (newConsumption > addQty) {
          AppLogger.logInfo('Consumption exceeds available quantity for new item: $newConsumption > $addQty');
          _showSnackBar('الاستهلاك يتجاوز الكمية المتاحة!');
          return;
        }

        if (_isMiscellaneous) {
          // نثريات لصنف جديد: لا يوجد مخزون، كله استهلاك
          await widget.db.database!.insert(
            'expenses',
            {
              'item_name': itemName,
              'unit': unit,
              'quantity': addQty,          // إجمالي ما دخل من أول الشهر
              'price': unitPrice,          // نحفظ آخر سعر للوحدة كمرجع
              'total_price': addTotalPrice, // إجمالي المصروفات التراكمي
              'remaining': 0.0,            // لا مخزون
              'consumption': newConsumption, // كله مستهلك
              'is_miscellaneous': 1,
              'is_drink': _isDrink ? 1 : 0,
              'date': currentDate,
            },
          );
          AppLogger.logInfo('Inserted new (misc) expense for item "$itemName"');
        } else {
          // إضافة مخزنية لصنف جديد
          await widget.db.database!.insert(
            'expenses',
            {
              'item_name': itemName,
              'unit': unit,
              'quantity': addQty,           // إجمالي ما دخل من أول الشهر
              'price': unitPrice,           // سعر الوحدة الحالي
              'total_price': addTotalPrice, // إجمالي المصروفات التراكمي
              'remaining': addQty - newConsumption, // المخزون الحالي
              'consumption': newConsumption,
              'is_miscellaneous': 0,
              'is_drink': _isDrink ? 1 : 0,
              'date': currentDate,
            },
          );
          AppLogger.logInfo('Inserted new (stock) expense for item "$itemName"');
        }

        // Remove item from temp list after saving
        setState(() {
          _tempItems.remove(itemName);
        });
      }

      _resetForm();
      _showSnackBar('تم الحفظ بنجاح!');
    } catch (e) {
      AppLogger.logError('Error saving expense: $e');
      if (e is FormatException) {
        _showSnackBar('خطأ في القيم المدخلة! يرجى التأكد من الأرقام');
      } else {
        _showSnackBar('خطأ غير متوقع: $e');
      }
    }
  }

  void _resetForm() {
    setState(() {
      _selectedItemName = null;
      _selectedUnit = null;
      _quantityController.clear();
      _totalPriceController.clear();
      _isMiscellaneous = false;
      _isDrink = false;
    });
  }

  void _handleBack() {
    _resetForm();
    widget.navigateToInput();
  }

  void _showSnackBar(String message) {
    showAppSnackBar(context, message);
  }

  @override
  Widget build(BuildContext context) {
    final isPortrait = MediaQuery.of(context).orientation == Orientation.portrait;
    final double buttonWidth = isPortrait
        ? MediaQuery.of(context).size.width * 0.5
        : MediaQuery.of(context).size.width * 0.25;
    const double buttonHeight = 60.0;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (bool didPop, dynamic result) {
        if (didPop) return;
        _handleBack();
      },
      child: BackgroundScaffold(
        title: 'إدخال المشتروات',
        backgroundImagePath: widget.backgroundImagePath,
        child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [

                    FutureBuilder<List<DropdownMenuItem<String>>>(
                      future: _getExpenseOptions(),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState == ConnectionState.waiting) {
                          return const CircularProgressIndicator();
                        }
                        return Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Expanded(
                              child: DropdownButtonFormField<String>(
                                value: _selectedItemName,
                                decoration: InputDecoration(
                                  labelText: 'اسم الصنف',
                                  labelStyle: const TextStyle(color: Colors.white, ),
                                  filled: true,
                                  fillColor: Colors.black.withOpacity(0.7),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                ),
                                hint: const Text(
                                  'اسم الصنف',
                                  textDirection: TextDirection.rtl,
                                  style: TextStyle(color: Colors.white, ),
                                ),
                                items: snapshot.data ?? [],
                                onChanged: (value) {
                                  setState(() {
                                    _selectedItemName = value;
                                    // Fetch unit, is_miscellaneous, and is_drink for the selected item
                                    widget.db
                                        .fetchAll(
                                          'SELECT unit, is_miscellaneous, is_drink FROM expenses WHERE item_name = ?',
                                          [value],
                                        )
                                        .then((results) {
                                          setState(() {
                                            if (results.isNotEmpty) {
                                              _selectedUnit = results[0]['unit'] as String?;
                                              _isMiscellaneous = (results[0]['is_miscellaneous'] as int? ?? 0) == 1;
                                              _isDrink = (results[0]['is_drink'] as int? ?? 0) == 1;
                                            } else {
                                              // For non-existing items (e.g., default items or temp items), reset to defaults
                                              _selectedUnit = null;
                                              _isMiscellaneous = false;
                                              _isDrink = false;
                                            }
                                          });
                                        });
                                  });
                                },
                                style: const TextStyle(color: Colors.white, ),
                                dropdownColor: Colors.black.withOpacity(0.7),
                                selectedItemBuilder: (BuildContext context) {
                                  return (snapshot.data ?? [])
                                      .map((DropdownMenuItem<String> item) => Text(
                                            item.value!,
                                            style: const TextStyle(
                                              color: Colors.white,
                                              
                                            ),
                                            textDirection: TextDirection.rtl,
                                          ))
                                      .toList();
                                },
                              ),
                            ),
                            const SizedBox(width: 10),
                            if (AuthService.instance.canAdd)
                              createButton(
                                text: '➕ إضافة صنف',
                                onPressed: _openAddItemDialog,
                                bgColor: Colors.blue[700]!,
                                width: 150,
                                height: 50,
                              ),
                          ],
                        );
                      },
                    ),
                    const SizedBox(height: 20),
                    DropdownButtonFormField<String>(
                      value: _selectedUnit,
                      decoration: InputDecoration(
                        labelText: 'الوحدة',
                        labelStyle: const TextStyle(color: Colors.white, ),
                        filled: true,
                        fillColor: Colors.black.withOpacity(0.7),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      hint: const Text(
                        'الوحدة',
                        textDirection: TextDirection.rtl,
                        style: TextStyle(color: Colors.white, ),
                      ),
                      items: _unitOptions
                          .map((unit) => DropdownMenuItem<String>(
                                value: unit,
                                child: Text(
                                  unit,
                                  textDirection: TextDirection.rtl,
                                  style: const TextStyle(color: Colors.white, ),
                                ),
                              ))
                          .toList(),
                      onChanged: (value) {
                        setState(() {
                          _selectedUnit = value;
                        });
                      },
                      style: const TextStyle(color: Colors.white, ),
                      dropdownColor: Colors.black.withOpacity(0.7),
                      selectedItemBuilder: (BuildContext context) {
                        return _unitOptions.map((String unit) {
                          return Text(
                            unit,
                            style: const TextStyle(color: Colors.white, ),
                            textDirection: TextDirection.rtl,
                          );
                        }).toList();
                      },
                    ),
                    const SizedBox(height: 20),
                    TextField(
                      controller: _quantityController,
                      decoration: InputDecoration(
                        labelText: 'الكمية',
                        labelStyle: const TextStyle(color: Colors.white, ),
                        filled: true,
                        fillColor: Colors.black.withOpacity(0.7),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      style: const TextStyle(color: Colors.white, ),
                      keyboardType: TextInputType.number,
                      textDirection: TextDirection.rtl,
                    ),
                    const SizedBox(height: 20),
                    TextField(
                      controller: _totalPriceController,
                      decoration: InputDecoration(
                        labelText: 'السعر الإجمالي',
                        labelStyle: const TextStyle(color: Colors.white, ),
                        filled: true,
                        fillColor: Colors.black.withOpacity(0.7),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      style: const TextStyle(color: Colors.white, ),
                      keyboardType: TextInputType.number,
                      textDirection: TextDirection.rtl,
                    ),
                    const SizedBox(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        StatefulBuilder(
                          builder: (BuildContext context, StateSetter setCheckboxState) {
                            return Checkbox(
                              value: _isMiscellaneous,
                              onChanged: (value) {
                                setCheckboxState(() {
                                  _isMiscellaneous = value ?? false;
                                });
                              },
                            );
                          },
                        ),
                        const Text(
                          'هل هي نثريات؟',
                          style: TextStyle(
                            color: Colors.black,
                            fontWeight: FontWeight.bold,
                            
                          ),
                          textDirection: TextDirection.rtl,
                        ),
                        const SizedBox(width: 20),
                        StatefulBuilder(
                          builder: (BuildContext context, StateSetter setCheckboxState) {
                            return Checkbox(
                              value: _isDrink,
                              onChanged: (value) {
                                setCheckboxState(() {
                                  _isDrink = value ?? false;
                                });
                              },
                            );
                          },
                        ),
                        const Text(
                          'هل هي مشروبات؟',
                          style: TextStyle(
                            color: Colors.black,
                            fontWeight: FontWeight.bold,
                            
                          ),
                          textDirection: TextDirection.rtl,
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    if (AuthService.instance.canAdd) ...[
                      createButton(
                        text: 'حفظ',
                        onPressed: _saveExpense,
                        bgColor: Colors.green[700]!,
                        width: buttonWidth,
                        height: buttonHeight,
                      ),
                      const SizedBox(height: 20),
                    ],
                    createButton(
                      text: 'رجوع',
                      onPressed: _handleBack,
                      bgColor: Colors.red[700]!,
                      width: buttonWidth,
                      height: buttonHeight,
                    ),
                  ],
                ),
              ),
            ),
      ),
    );
  }
}