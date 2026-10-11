import 'package:flutter/material.dart';
import '../../utils/database.dart';


class ClearData {
  final BuildContext context;
  final DatabaseManager db;
  final Map<String, bool> checkboxValues = {
    'members': false,
    'expenses': false,
    'meals': false,
    'drinks': false,
    'misc': false,
    'select_all': false,
  };

  ClearData(this.context, this.db);

  void showConfirmation() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text("مسح البيانات"),
              content: SingleChildScrollView(
                child: Column(
                  children: [
                    _buildCheckboxRow(
                      'select_all',
                      'الكل',
                      setState,
                    ),
                    _buildCheckboxRow(
                      'members',
                      'سجل المشتركين',
                      setState,
                    ),
                    _buildCheckboxRow(
                      'expenses',
                      'سجل المشتروات',
                      setState,
                    ),
                    _buildCheckboxRow(
                      'meals',
                      'سجل الوجبات',
                      setState,
                    ),
                    _buildCheckboxRow(
                      'drinks',
                      'سجل المشروبات',
                      setState,
                    ),
                    _buildCheckboxRow(
                      'misc',
                      'سجل المصروفات الأخرى',
                      setState,
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  child: const Text("لا"),
                  onPressed: () => Navigator.of(context).pop(),
                ),
                TextButton(
                  child: const Text("نعم"),
                  onPressed: () async {
                    Navigator.of(context).pop();
                    await _confirmClear();
                  },
                ),
              ],
              actionsAlignment: MainAxisAlignment.end,
            );
          },
        );
      },
    );
  }

  Widget _buildCheckboxRow(String key, String label, StateSetter setState) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Checkbox(
          value: checkboxValues[key],
          onChanged: (bool? value) {
            setState(() {
              if (key == 'select_all') {
                // عند تغيير خيار "الكل"
                for (var k in checkboxValues.keys) {
                  if (k != 'select_all') {
                    checkboxValues[k] = value!;
                  }
                }
              } else {
                // عند تغيير أي خيار آخر
                checkboxValues[key] = value!;
                
                // تحديث حالة خيار "الكل"
                checkboxValues['select_all'] = (checkboxValues['members'] ?? false) &&
                    (checkboxValues['expenses'] ?? false) &&
                    (checkboxValues['meals'] ?? false) &&
                    (checkboxValues['drinks'] ?? false) &&
                    (checkboxValues['misc'] ?? false);
              }
            });
          },
        ),
        Text(label),
      ],
    );
  }

  Future<void> _confirmClear() async {
    try {
      final tables = <String>[];
      if (checkboxValues['members'] == true) tables.add('members');
      if (checkboxValues['expenses'] == true) tables.add('expenses');
      if (checkboxValues['meals'] == true) tables.add('meal_records');
      if (checkboxValues['drinks'] == true) tables.add('drink_records');
      if (checkboxValues['misc'] == true) tables.add('miscellaneous_expenses');

      if (tables.isEmpty) {
        showSnackbar("لم يتم اختيار أي جداول!");
        return;
      }

      await db.transaction((txn) async {
        for (final table in tables) {
          await txn.rawDelete("DELETE FROM $table");
        }
      });

      showSnackbar("تم المسح بنجاح!");
    } catch (e) {
      debugPrint("Error clearing data: $e");
      showSnackbar("خطأ: $e");
    }
  }

  void showSnackbar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }
}