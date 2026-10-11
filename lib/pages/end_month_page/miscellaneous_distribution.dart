import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';
import 'package:intl/intl.dart';
import '../../utils/database.dart';

class MiscellaneousDistribution {
  final BuildContext context;
  final DatabaseManager db;

  MiscellaneousDistribution(this.context, this.db);

  void showSnackbar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Future<Map<String, dynamic>> distributeMiscellaneous(DatabaseExecutor txn) async {
    try {
      debugPrint("Starting distribution of miscellaneous expenses");

      // 1. جلب النثريات من جدول expenses
      final miscExpenses = await txn.rawQuery(
        "SELECT expense_id, total_price FROM expenses WHERE is_miscellaneous = 1",
      );
      debugPrint("Fetched ${miscExpenses.length} miscellaneous expenses");

      if (miscExpenses.isEmpty) {
        showSnackbar("لا توجد أصناف نثريات للتوزيع!");
        return {'success': false, 'expense_ids': []};
      }

      // 2. حساب إجمالي قيمة النثريات
      final totalMiscValue = miscExpenses.fold<double>(
          0, (sum, item) => sum + (item['total_price'] as num).toDouble());
      debugPrint("Total miscellaneous value: $totalMiscValue");

      // 3. جلب عدد الوجبات لكل عضو
      final mealCounts = await txn.rawQuery(
        "SELECT member_id, COUNT(*) as meal_count FROM meal_records GROUP BY member_id",
      );
      debugPrint("Fetched ${mealCounts.length} meal counts");

      final distributionDate = DateFormat('yyyy-MM-dd').format(DateTime.now());
      final expenseIds = miscExpenses.map((item) => item['expense_id'] as int).toList();

      if (mealCounts.isEmpty) {
        // 4. لو مفيش وجبات، نوزع النثريات بالتساوي على الأعضاء
        debugPrint("No meal records found, distributing equally among members");
        final members = await txn.rawQuery(
          "SELECT member_id FROM members",
        );
        debugPrint("Fetched ${members.length} members for equal distribution");

        if (members.isEmpty) {
          showSnackbar("لا توجد أعضاء لتوزيع النثريات!");
          return {'success': false, 'expense_ids': []};
        }

        final miscCostPerMember = totalMiscValue / members.length;
        debugPrint("Misc cost per member: $miscCostPerMember");

        // 5. تحديث ديون الأعضاء وتسجيل التوزيع
        for (final member in members) {
          final memberId = member['member_id'] as int;

          await txn.rawUpdate(
            "UPDATE members SET total_due = total_due + ? WHERE member_id = ?",
            [miscCostPerMember, memberId],
          );

          await txn.rawInsert(
            "INSERT INTO miscellaneous_contributions (member_id, misc_amount, meal_count, distribution_date) VALUES (?, ?, ?, ?)",
            [memberId, miscCostPerMember, 0, distributionDate],
          );
          debugPrint("Updated member $memberId with amount: $miscCostPerMember (equal distribution)");
        }

        showSnackbar("تم توزيع النثريات بالتساوي على ${members.length} عضو!");
        debugPrint("Distribution completed equally for ${expenseIds.length} expenses");
        return {'success': true, 'expense_ids': expenseIds};
      }

      // 6. توزيع النثريات بناءً على الوجبات (الحالة العادية)
      final totalMeals = mealCounts.fold<int>(
          0, (sum, item) => sum + (item['meal_count'] as int));
      final miscCostPerMeal = totalMiscValue / totalMeals;
      debugPrint("Misc cost per meal: $miscCostPerMeal");

      // 7. تحديث ديون الأعضاء وتسجيل التوزيع
      for (final record in mealCounts) {
        final memberId = record['member_id'] as int;
        final mealCount = record['meal_count'] as int;
        final amount = mealCount * miscCostPerMeal;

        await txn.rawUpdate(
          "UPDATE members SET total_due = total_due + ? WHERE member_id = ?",
          [amount, memberId],
        );

        await txn.rawInsert(
          "INSERT INTO miscellaneous_contributions (member_id, misc_amount, meal_count, distribution_date) VALUES (?, ?, ?, ?)",
          [memberId, amount, mealCount, distributionDate],
        );
        debugPrint("Updated member $memberId with amount: $amount");
      }

      debugPrint("Distribution completed for ${expenseIds.length} expenses");
      return {'success': true, 'expense_ids': expenseIds};
    } catch (e) {
      debugPrint("Error distributing miscellaneous: $e");
      showSnackbar("خطأ أثناء توزيع النثريات: $e");
      return {'success': false, 'expense_ids': []};
    }
  }
}