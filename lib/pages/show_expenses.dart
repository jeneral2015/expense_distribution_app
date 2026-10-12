import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../utils/button_utils.dart';
import '../utils/database.dart';
import '../utils/background_scaffold.dart';
import '../utils/logger.dart';
import '../services/auth_service.dart';

class ShowExpensesPage extends StatefulWidget {
  final DatabaseManager db;
  final VoidCallback navigateToView;
  final String backgroundImagePath;
  final bool isMiscellaneous;

  const ShowExpensesPage({
    Key? key,
    required this.db,
    required this.navigateToView,
    required this.backgroundImagePath,
    required this.isMiscellaneous,
  }) : super(key: key);

  @override
  _ShowExpensesPageState createState() => _ShowExpensesPageState();
}

class _ShowExpensesPageState extends State<ShowExpensesPage> {
  List<Map<String, dynamic>> _rows = [];
  Map<String, dynamic>? _selectedRow;
  int? _selectedItemId;
  // Not final because we modify its contents dynamically (add/remove items)
  Set<int> _selectedItemsForDeletion = {};
  final List<String> _units = ['عدد', 'كيلوجرام', 'لتر'];

  @override
  void initState() {
    super.initState();
    widget.db.initializeDatabase();
    _fetchExpensesData();
  }

  String formatNumber(num? number) {
    if (number == null) return '';
    if (number is int) return number.toString();
    final d = number.toDouble();
    if (d == d.toInt()) return d.toInt().toString();
    return d.toStringAsFixed(2);
  }

  double? _parseNum(String text) {
    final t = text.trim().replaceAll(',', '.');
    if (t.isEmpty) return null;
    return double.tryParse(t);
  }

  Future<void> _fetchExpensesData() async {
    try {
      final int miscValue = widget.isMiscellaneous ? 1 : 0;
      final results = await widget.db.fetchAll(
        'SELECT expense_id, item_name, unit, quantity, price, total_price, consumption, remaining, is_miscellaneous, is_drink FROM expenses WHERE is_miscellaneous = $miscValue',
      );
      setState(() {
        _rows = results
            .map((row) => {
                  'expense_id': row['expense_id'],
                  'item_name': row['item_name'],
                  'unit': row['unit'],
                  'quantity': (row['quantity'] is int)
                      ? (row['quantity'] as int).toDouble()
                      : row['quantity'],
                  'price': (row['price'] is int)
                      ? (row['price'] as int).toDouble()
                      : row['price'],
                  'total_price': (row['total_price'] is int)
                      ? (row['total_price'] as int).toDouble()
                      : row['total_price'],
                  'consumption': (row['consumption'] is int)
                      ? (row['consumption'] as int).toDouble()
                      : row['consumption'],
                  'remaining': (row['remaining'] is int)
                      ? (row['remaining'] as int).toDouble()
                      : row['remaining'],
                  'is_miscellaneous': row['is_miscellaneous'],
                  'is_drink': row['is_drink'],
                })
            .toList();
      });
    } catch (e) {
      AppLogger.logError('Failed to fetch expenses: $e');
      _showSnackBar('حدث خطأ أثناء جلب البيانات');
    }
  }

  void _selectRowForEdit(Map<String, dynamic>? row) {
    setState(() {
      final rowId = row?['expense_id'];
      if (_selectedItemId == rowId) {
        _selectedRow = null;
        _selectedItemId = null;
      } else {
        _selectedRow = row;
        _selectedItemId = rowId;
        if (rowId != null) {
          _selectedItemsForDeletion.add(rowId);
        }
      }
      AppLogger.logInfo('Selected Item ID for Edit: $_selectedItemId');
    });
  }

  void _toggleItemForDeletion(int itemId) {
    setState(() {
      if (_selectedItemsForDeletion.contains(itemId)) {
        _selectedItemsForDeletion.remove(itemId);
        if (_selectedItemId == itemId) {
          _selectedRow = null;
          _selectedItemId = null;
        }
      } else {
        _selectedItemsForDeletion.add(itemId);
        _selectedRow = null;
        _selectedItemId = null;
      }
      AppLogger.logInfo('Selected Items for Deletion: $_selectedItemsForDeletion');
    });
  }

  void _editItem() {
    if (_selectedItemsForDeletion.length > 1) {
      _showSnackBar('الرجاء اختيار صنف واحد فقط للتعديل.');
      return;
    }

    if (_selectedItemsForDeletion.length == 1) {
      final itemId = _selectedItemsForDeletion.first;
      final item = _rows.firstWhere((row) => row['expense_id'] == itemId, orElse: () => {});
      if (item.isNotEmpty) {
        _selectRowForEdit(item);
        _openEditDialog();
        return;
      }
    }

    if (_selectedRow == null) {
      _showSnackBar('يرجى اختيار صنف للتعديل.');
      return;
    }

    _openEditDialog();
  }

  Future<void> _openEditDialog() async {
    final tempRow = Map<String, dynamic>.from(_selectedRow!);

    final itemNameController = TextEditingController(text: tempRow['item_name'] ?? '');
    final unitController = TextEditingController(text: tempRow['unit'] ?? '');
    final quantityController = TextEditingController(text: formatNumber(tempRow['quantity']));
    final priceController = TextEditingController(text: formatNumber(tempRow['price']));
    final totalPriceController = TextEditingController(text: formatNumber(tempRow['total_price']));
    final consumptionController = TextEditingController(text: formatNumber(tempRow['consumption']));
    final remainingController = TextEditingController(text: formatNumber(tempRow['remaining']));

    bool isMiscellaneous = (tempRow['is_miscellaneous'] == 1);
    bool isDrink = (tempRow['is_drink'] == 1);

    bool updating = false;

    void setTextSafely(TextEditingController c, String v,
        void Function(void Function()) setDialogState) {
      updating = true;
      setDialogState(() {
        c.text = v;
        c.selection = TextSelection.fromPosition(
            TextPosition(offset: c.text.length));
      });
      updating = false;
    }

    await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            void recalcFromQuantity() {
              if (updating) return;
              final q = _parseNum(quantityController.text);
              final cons = _parseNum(consumptionController.text) ?? 0;
              final total = _parseNum(totalPriceController.text);

              if (q == null) {
                setTextSafely(remainingController, '', setDialogState);
                setTextSafely(priceController, '', setDialogState); // Reset price if quantity is invalid
                return;
              }

              // Update remaining
              final rem = q - cons;
              setTextSafely(remainingController, formatNumber(rem), setDialogState);

              // Update unit price
              if (total != null && q > 0) {
                final unitPrice = total / q;
                setTextSafely(priceController, formatNumber(unitPrice), setDialogState);
              } else {
                setTextSafely(priceController, '', setDialogState);
              }
            }

            void recalcFromConsumption() {
              if (updating) return;
              final q = _parseNum(quantityController.text);
              final cons = _parseNum(consumptionController.text);
              if (q == null || cons == null) {
                return;
              }
              final rem = q - cons;
              setTextSafely(remainingController, formatNumber(rem), setDialogState);
            }

            void recalcFromTotalPrice() {
              if (updating) return;
              final q = _parseNum(quantityController.text);
              final total = _parseNum(totalPriceController.text);

              if (q != null && total != null && q > 0) {
                final unitPrice = total / q;
                setTextSafely(priceController, formatNumber(unitPrice), setDialogState);
              } else {
                setTextSafely(priceController, '', setDialogState);
              }
            }

            void onQuantityChanged(String _) => recalcFromQuantity();
            void onConsumptionChanged(String _) => recalcFromConsumption();
            void onTotalPriceChanged(String _) => recalcFromTotalPrice();

            Future<void> onSave() async {
              try {
                final itemName = itemNameController.text.trim();
                final unit = unitController.text.trim();
                final quantity = _parseNum(quantityController.text) ?? 0;
                final price = _parseNum(priceController.text) ?? 0;
                final totalPrice = _parseNum(totalPriceController.text) ?? 0;
                final consumption = _parseNum(consumptionController.text) ?? 0;
                final remaining = quantity - consumption;

                if (itemName.isEmpty || unit.isEmpty) {
                  _showSnackBar('يرجى ملء حقلي اسم الصنف والوحدة.');
                  return;
                }
                if (remaining < 0) {
                  _showSnackBar('الاستهلاك لا يمكن أن يكون أكبر من الكمية.');
                  return;
                }

                await widget.db.database!.update(
                  'expenses',
                  {
                    'item_name': itemName,
                    'unit': unit,
                    'quantity': quantity,
                    'price': price,
                    'total_price': totalPrice,
                    'consumption': consumption,
                    'remaining': remaining,
                    'is_miscellaneous': isMiscellaneous ? 1 : 0,
                    'is_drink': isDrink ? 1 : 0,
                  },
                  where: 'expense_id = ?',
                  whereArgs: [tempRow['expense_id']],
                );

                Navigator.of(dialogContext).pop(true);
              } catch (e) {
                _showSnackBar('حدث خطأ أثناء تعديل البيانات: $e');
                AppLogger.logError('Error details: $e');
              }
            }

            return AlertDialog(
              title: const Text(
                'تعديل بيانات الصنف',
                textDirection: TextDirection.rtl,
                style: TextStyle(),
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: itemNameController,
                      decoration: const InputDecoration(
                        labelText: 'اسم الصنف',
                        labelStyle: TextStyle(),
                        border: OutlineInputBorder(),
                      ),
                      textDirection: TextDirection.rtl,
                    ),
                    const SizedBox(height: 10),
                    DropdownButtonFormField<String>(
                      value: _units.contains(unitController.text)
                          ? unitController.text
                          : null,
                      decoration: const InputDecoration(
                        labelText: 'الوحدة',
                        labelStyle: TextStyle(),
                        border: OutlineInputBorder(),
                      ),
                      hint: const Text(
                        'اختر الوحدة',
                        textDirection: TextDirection.rtl,
                        style: TextStyle( color: Colors.black),
                      ),
                      items: _units
                          .map((unit) => DropdownMenuItem(
                                value: unit,
                                child: Text(
                                  unit,
                                  textDirection: TextDirection.rtl,
                                  style: const TextStyle(
                                       color: Colors.black),
                                ),
                              ))
                          .toList(),
                      onChanged: (value) {
                        setDialogState(() {
                          unitController.text = value ?? '';
                        });
                      },
                      style: const TextStyle(
                           color: Colors.black),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: quantityController,
                      decoration: const InputDecoration(
                        labelText: 'الكمية',
                        labelStyle: TextStyle(),
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.number,
                      textDirection: TextDirection.rtl,
                      onChanged: onQuantityChanged,
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: priceController,
                      decoration: const InputDecoration(
                        labelText: 'سعر الوحدة',
                        labelStyle: TextStyle(),
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.number,
                      textDirection: TextDirection.rtl,
                      enabled: false, // Make it read-only
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: totalPriceController,
                      decoration: const InputDecoration(
                        labelText: 'السعر الإجمالي',
                        labelStyle: TextStyle(),
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.number,
                      textDirection: TextDirection.rtl,
                      onChanged: onTotalPriceChanged, // Add callback for total price
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: consumptionController,
                      decoration: const InputDecoration(
                        labelText: 'الاستهلاك',
                        labelStyle: TextStyle(),
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.number,
                      textDirection: TextDirection.rtl,
                      enabled: false,
                      onChanged: onConsumptionChanged,
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: remainingController,
                      decoration: const InputDecoration(
                        labelText: 'المتبقي',
                        labelStyle: TextStyle(),
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.number,
                      textDirection: TextDirection.rtl,
                    ),
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Row(
                          children: [
                            Checkbox(
                              value: isMiscellaneous,
                              onChanged: (value) {
                                setDialogState(() {
                                  isMiscellaneous = value ?? false;
                                });
                              },
                              checkColor: Colors.white,
                              activeColor: Colors.green[700],
                            ),
                            const Text(
                              'نثريات',
                              style: TextStyle(),
                              textDirection: TextDirection.rtl,
                            ),
                          ],
                        ),
                        const SizedBox(width: 20),
                        Row(
                          children: [
                            Checkbox(
                              value: isDrink,
                              onChanged: (value) {
                                setDialogState(() {
                                  isDrink = value ?? false;
                                });
                              },
                              checkColor: Colors.white,
                              activeColor: Colors.green[700],
                            ),
                            const Text(
                              'مشروبات',
                              style: TextStyle(),
                              textDirection: TextDirection.rtl,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              actions: [
                createButton(
                  text: 'حفظ',
                  onPressed: onSave,
                  bgColor: Colors.green[700]!,
                  width: 100,
                  height: 40,
                ),
                createButton(
                  text: 'إلغاء',
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  bgColor: Colors.red[700]!,
                  width: 100,
                  height: 40,
                ),
              ],
              actionsAlignment: MainAxisAlignment.center,
            );
          },
        );
      },
    ).then((saved) async {
      await _fetchExpensesData();
      setState(() {
        _selectedRow = null;
        _selectedItemId = null;
        _selectedItemsForDeletion.clear();
      });
    });
  }

  void _deleteItem() {
    if (_selectedItemsForDeletion.isEmpty && _selectedRow == null) {
      _showSnackBar('يرجى اختيار صنف للحذف.');
      return;
    }

    final itemsToDelete = _selectedItemsForDeletion.isNotEmpty
        ? _selectedItemsForDeletion
        : {_selectedItemId!};

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text(
          'تأكيد الحذف',
          textDirection: TextDirection.rtl,
          style: TextStyle(),
        ),
        content: Text(
          itemsToDelete.length > 1
              ? 'هل أنت متأكد أنك تريد حذف ${itemsToDelete.length} أصناف؟'
              : 'هل أنت متأكد أنك تريد حذف هذا الصنف؟',
          textDirection: TextDirection.rtl,
          style: const TextStyle(),
        ),
        actions: [
          createButton(
            text: 'نعم',
            onPressed: () => _confirmDeleteMultiple(itemsToDelete),
            bgColor: Colors.green[700]!,
            width: 100,
            height: 40,
          ),
          createButton(
            text: 'إلغاء',
            onPressed: () => Navigator.of(context).pop(),
            bgColor: Colors.red[700]!,
            width: 100,
            height: 40,
          ),
        ],
        actionsAlignment: MainAxisAlignment.center,
      ),
    );
  }

  void _confirmDeleteMultiple(Set<int> itemIds) async {
    try {
      for (final itemId in itemIds) {
        await widget.db.database!.delete(
          'expenses',
          where: 'expense_id = ?',
          whereArgs: [itemId],
        );
      }

      _showSnackBar('تم حذف ${itemIds.length} صنف بنجاح!');
      Navigator.of(context).pop();
      _selectedRow = null;
      _selectedItemId = null;
      _selectedItemsForDeletion.clear();
      await _fetchExpensesData();
    } catch (e) {
      _showSnackBar('حدث خطأ أثناء الحذف: $e');
    }
  }

  void _handleBack() {
    _selectedRow = null;
    _selectedItemId = null;
    _selectedItemsForDeletion.clear();
    widget.navigateToView();
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message, textDirection: TextDirection.rtl)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isPortrait = MediaQuery.of(context).orientation == Orientation.portrait;
    final double buttonWidth = isPortrait
        ? MediaQuery.of(context).size.width * 0.5
        : MediaQuery.of(context).size.width * 0.25;
    const double buttonHeight = 60.0;

    final String pageTitle = widget.isMiscellaneous ? 'عرض النثريات' : 'عرض الأصناف المتبقية';

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (bool didPop, dynamic result) {
        if (didPop) return;
        _handleBack();
      },
      child: BackgroundScaffold(
        title: pageTitle,
        backgroundImagePath: widget.backgroundImagePath,
        child: Stack(
          children: [
            Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: DataTable(
                        border: TableBorder.all(color: Colors.black, width: 1),
                        dividerThickness: 1,
                        decoration: const BoxDecoration(color: Colors.white),
                        columns: [
                          DataColumn(
                            label: Checkbox(
                              value: _selectedItemsForDeletion.length == _rows.length && _rows.isNotEmpty,
                              onChanged: (value) {
                                if (value == true) {
                                  setState(() {
                                    _selectedItemsForDeletion = Set.from(_rows.map((row) => row['expense_id'] as int));
                                    _selectedRow = null;
                                    _selectedItemId = null;
                                  });
                                } else {
                                  setState(() {
                                    _selectedItemsForDeletion.clear();
                                  });
                                }
                              },
                            ),
                          ),
                          const DataColumn(
                              label: Text('مسلسل', style: TextStyle())),
                          const DataColumn(
                              label: Text('اسم الصنف', style: TextStyle())),
                          const DataColumn(
                              label: Text('الوحدة', style: TextStyle())),
                          const DataColumn(
                              label: Text('الكمية', style: TextStyle())),
                          const DataColumn(
                              label: Text('سعر الوحدة', style: TextStyle())),
                          const DataColumn(
                              label: Text('السعر الإجمالي', style: TextStyle())),
                          const DataColumn(
                              label: Text('الاستهلاك', style: TextStyle())),
                          const DataColumn(
                              label: Text('المتبقي', style: TextStyle())),
                        ],
                        rows: _rows.asMap().entries.map((entry) {
                          final index = entry.key;
                          final row = entry.value;
                          final itemId = row['expense_id'] as int;
                          final isSelectedForEdit = _selectedItemId == itemId;
                          final isSelectedForDeletion = _selectedItemsForDeletion.contains(itemId);

                          return DataRow(
                            color: MaterialStateProperty.resolveWith<Color?>(
                              (Set<MaterialState> states) {
                                if (isSelectedForEdit) {
                                  return Colors.yellow;
                                } else if (isSelectedForDeletion) {
                                  return Colors.red.withOpacity(0.3);
                                }
                                return null;
                              },
                            ),
                            cells: [
                              DataCell(
                                Checkbox(
                                  value: isSelectedForDeletion,
                                  onChanged: (value) {
                                    _toggleItemForDeletion(itemId);
                                  },
                                ),
                              ),
                              DataCell(Text((index + 1).toString())),
                              DataCell(Text(row['item_name'] ?? '')),
                              DataCell(Text(row['unit'] ?? '',
                                  style: const TextStyle(
                                      color: Colors.black, ))),
                              DataCell(Text(formatNumber(row['quantity']))),
                              DataCell(Text(formatNumber(row['price']))),
                              DataCell(Text(formatNumber(row['total_price']))),
                              DataCell(Text(formatNumber(row['consumption']))),
                              DataCell(Text(formatNumber(row['remaining']))),
                            ],
                          );
                        }).toList(),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (AuthService.instance.canEdit) ...[
                          createButton(
                            text: 'تعديل',
                            onPressed: _editItem,
                            bgColor: Colors.amber[700]!,
                            width: buttonWidth / 3,
                            height: buttonHeight,
                          ),
                          const SizedBox(width: 20),
                        ],
                        if (AuthService.instance.canDelete) ...[
                          createButton(
                            text: 'حذف',
                            onPressed: _deleteItem,
                            bgColor: Colors.red[700]!,
                            width: buttonWidth / 3,
                            height: buttonHeight,
                          ),
                          const SizedBox(width: 20),
                        ],
                        createButton(
                          text: 'رجوع',
                          onPressed: _handleBack,
                          bgColor: Colors.red[700]!,
                          width: buttonWidth / 3,
                          height: buttonHeight,
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