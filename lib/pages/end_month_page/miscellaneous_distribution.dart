import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';
import 'package:intl/intl.dart';
import '../../utils/database.dart';

class MiscellaneousDistribution {
  final BuildContext? context;
  final DatabaseManager db;

  MiscellaneousDistribution(this.context, this.db);

  void showSnackbar(String message) {
    if (context == null || !context!.mounted) return;
    ScaffoldMessenger.of(context!).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Future<Map<String, dynamic>> distributeMiscellaneous(
    DatabaseExecutor txn, {
    bool suppressSnackbars = false,
  }) async {
    try {
      debugPrint("Starting distribution of miscellaneous expenses");

      // 1. جلب النثريات من جدول expenses
      final miscExpenses = await txn.rawQuery(
        "SELECT expense_id, total_price FROM expenses WHERE is_miscellaneous = 1",
      );
      debugPrint("Fetched ${miscExpenses.length} miscellaneous expenses");

      // 2. حساب إجمالي قيمة النثريات المسجلة
      double totalMiscValue = miscExpenses.fold<double>(
          0, (sum, item) => sum + (item['total_price'] as num).toDouble());

      // 3. جلب استهلاك الوجبات والمشروبات لكل عضو
      final mealRecords = await txn.rawQuery(
        "SELECT member_id, COUNT(*) as meal_count, SUM(final_cost) as meal_cost FROM meal_records GROUP BY member_id",
      );
      final drinkRecords = await txn.rawQuery(
        "SELECT member_id, SUM(total_cost) as drink_cost FROM drink_records GROUP BY member_id",
      );

      // 4. احتساب فارق تسوية الاستهلاك للمخزن (المشتريات بدون نثريات - المتبقي) - (الوجبات + المشروبات)
      // لضمان استرداد أي فارق محاسبي ضمن التوزيع ومنع أي عجز بالصندوق
      final purData = await txn.rawQuery(
        "SELECT COALESCE(SUM(total_price), 0) as pur, COALESCE(SUM(remaining * price), 0) as rem FROM expenses WHERE COALESCE(is_miscellaneous, 0) = 0",
      );
      double inventoryDiscrepancy = 0.0;
      if (purData.isNotEmpty) {
        final double pur = (purData.first['pur'] as num?)?.toDouble() ?? 0.0;
        final double rem = (purData.first['rem'] as num?)?.toDouble() ?? 0.0;
        final double inventoryConsumed =
            (pur - rem).clamp(0.0, double.infinity);

        final double totalMealsCost = mealRecords.fold<double>(
            0.0, (s, r) => s + ((r['meal_cost'] as num?)?.toDouble() ?? 0.0));
        final double totalDrinksCost = drinkRecords.fold<double>(
            0.0, (s, r) => s + ((r['drink_cost'] as num?)?.toDouble() ?? 0.0));

        final double recordedConsumption = totalMealsCost + totalDrinksCost;
        if (inventoryConsumed > recordedConsumption) {
          inventoryDiscrepancy = inventoryConsumed - recordedConsumption;
        }
      }

      if (inventoryDiscrepancy > 0.001) {
        totalMiscValue += inventoryDiscrepancy;
        debugPrint(
            "Added inventory discrepancy ($inventoryDiscrepancy) to miscellaneous distribution total: $totalMiscValue");
      }

      if (miscExpenses.isEmpty && inventoryDiscrepancy <= 0.001) {
        if (!suppressSnackbars) {
          showSnackbar("لا توجد أصناف نثريات للتوزيع!");
        }
        return {'success': false, 'expense_ids': []};
      }
      debugPrint("Total miscellaneous value for distribution: $totalMiscValue");

      final distributionDate = DateFormat('yyyy-MM-dd').format(DateTime.now());
      final expenseIds =
          miscExpenses.map((item) => item['expense_id'] as int).toList();

      final totalMeals = mealRecords.fold<int>(
        0,
        (sum, item) => sum + ((item['meal_count'] as num?)?.toInt() ?? 0),
      );

      if (totalMeals == 0) {
        // 4. في حال عدم وجود أي وجبات إطلاقاً، نوزع النثريات بالتساوي على الأعضاء
        debugPrint("No meal records found, distributing equally among members");
        final members = await txn.rawQuery(
          "SELECT member_id FROM members",
        );
        debugPrint("Fetched ${members.length} members for equal distribution");

        if (members.isEmpty) {
          if (!suppressSnackbars) {
            showSnackbar("لا توجد أعضاء لتوزيع النثريات!");
          }
          return {'success': false, 'expense_ids': []};
        }

        final miscCostPerMember =
            double.parse((totalMiscValue / members.length).toStringAsFixed(2));
        debugPrint("Misc cost per member: $miscCostPerMember");

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
        }

        if (!suppressSnackbars) {
          showSnackbar("تم توزيع النثريات بالتساوي على ${members.length} عضو!");
        }
        return {'success': true, 'expense_ids': expenseIds};
      }

      // 5. توزيع النثريات بالمتوسط العادل بين نسبة الوجبات ونسبة مبالغ الاستهلاك
      final Map<int, int> memberMealCounts = {};
      final Map<int, double> memberMealCosts = {};
      final Map<int, double> memberDrinkCosts = {};
      final Set<int> activeMemberIds = {};

      double totalMealsCost = 0.0;
      for (final row in mealRecords) {
        final memberId = row['member_id'] as int;
        final count = (row['meal_count'] as num?)?.toInt() ?? 0;
        final cost = (row['meal_cost'] as num?)?.toDouble() ?? 0.0;
        memberMealCounts[memberId] = count;
        memberMealCosts[memberId] = cost;
        totalMealsCost += cost;
        activeMemberIds.add(memberId);
      }

      double totalDrinksCost = 0.0;
      for (final row in drinkRecords) {
        final memberId = row['member_id'] as int;
        final cost = (row['drink_cost'] as num?)?.toDouble() ?? 0.0;
        memberDrinkCosts[memberId] = cost;
        totalDrinksCost += cost;
        activeMemberIds.add(memberId);
      }

      final double totalConsumption = totalMealsCost + totalDrinksCost;
      debugPrint(
          "Total meals count: $totalMeals, Total consumption: $totalConsumption (Meals: $totalMealsCost, Drinks: $totalDrinksCost)");

      for (final memberId in activeMemberIds) {
        final mealCount = memberMealCounts[memberId] ?? 0;
        final mealCost = memberMealCosts[memberId] ?? 0.0;
        final drinkCost = memberDrinkCosts[memberId] ?? 0.0;
        final memberConsumption = mealCost + drinkCost;

        // الحصة (أ): بالنسبة لعدد الوجبات
        final double shareA =
            totalMeals > 0 ? (totalMiscValue * (mealCount / totalMeals)) : 0.0;

        // الحصة (ب): بالنسبة لمبالغ الاستهلاك (وجبات + مشروبات)
        final double shareB = totalConsumption > 0
            ? (totalMiscValue * (memberConsumption / totalConsumption))
            : shareA;

        // المتوسط الحسابي العادل مقرباً لمنزلتين عشريتين
        final double finalAmount =
            double.parse(((shareA + shareB) / 2).toStringAsFixed(2));

        if (finalAmount <= 0) continue;

        await txn.rawUpdate(
          "UPDATE members SET total_due = total_due + ? WHERE member_id = ?",
          [finalAmount, memberId],
        );

        await txn.rawInsert(
          "INSERT INTO miscellaneous_contributions (member_id, misc_amount, meal_count, distribution_date) VALUES (?, ?, ?, ?)",
          [memberId, finalAmount, mealCount, distributionDate],
        );
        debugPrint(
            "Member $memberId: meals=$mealCount, consumption=$memberConsumption -> shareA=$shareA, shareB=$shareB, final=$finalAmount");
      }

      debugPrint("Distribution completed for ${expenseIds.length} expenses");
      return {'success': true, 'expense_ids': expenseIds};
    } catch (e) {
      debugPrint("Error distributing miscellaneous: $e");
      if (!suppressSnackbars) {
        showSnackbar("خطأ أثناء توزيع النثريات: $e");
      }
      return {'success': false, 'expense_ids': []};
    }
  }
}
