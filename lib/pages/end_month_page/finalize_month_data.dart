import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';
import 'package:intl/intl.dart';
import '../../utils/database.dart';
import 'miscellaneous_distribution.dart';

class FinalizeMonthData {
  /// تنفيذ عملية تقفيل الشهر وأرشفة البيانات بالكامل كمعاملة ذرية واحدة (Atomic Transaction).
  static Future<Map<String, dynamic>> executeFullMonthFinalization(
      BuildContext context, DatabaseManager db) async {
    try {
      if (db.database == null || !db.database!.isOpen) {
        await db.initializeDatabase();
      }

      int? createdArchiveKeyId;
      int? createdClosureId;

      await db.transaction((txn) async {
        // 1. التأكد من وجود أعضاء
        final memberCountRes = await txn.rawQuery("SELECT COUNT(*) as count FROM members");
        final memberCount = (memberCountRes.isNotEmpty && memberCountRes.first['count'] != null)
            ? memberCountRes.first['count'] as int
            : 0;
        if (memberCount == 0) {
          throw Exception("لا توجد أعضاء في جدول الأعضاء لتقفيل الشهر.");
        }

        // 2. توزيع النثريات المتبقية إن وجدت
        final miscExpenses = await txn.rawQuery(
          "SELECT expense_id, total_price FROM expenses WHERE is_miscellaneous = 1",
        );
        if (miscExpenses.isNotEmpty) {
          final totalMiscValue = miscExpenses.fold<double>(
            0,
            (sum, item) => sum + (item['total_price'] as num).toDouble(),
          );
          final mealCounts = await txn.rawQuery(
            "SELECT member_id, COUNT(*) as meal_count FROM meal_records GROUP BY member_id",
          );
          final distributionDate = DateFormat('yyyy-MM-dd').format(DateTime.now());

          if (mealCounts.isEmpty) {
            final members = await txn.rawQuery("SELECT member_id FROM members");
            if (members.isNotEmpty) {
              final miscPerMember = totalMiscValue / members.length;
              for (final m in members) {
                final memberId = m['member_id'] as int;
                await txn.rawUpdate(
                  "UPDATE members SET total_due = total_due + ? WHERE member_id = ?",
                  [miscPerMember, memberId],
                );
                await txn.rawInsert(
                  "INSERT INTO miscellaneous_contributions (member_id, misc_amount, meal_count, distribution_date) VALUES (?, ?, ?, ?)",
                  [memberId, miscPerMember, 0, distributionDate],
                );
              }
            }
          } else {
            final totalMeals = mealCounts.fold<int>(
              0,
              (sum, item) => sum + (item['meal_count'] as int),
            );
            final miscCostPerMeal = totalMeals > 0 ? (totalMiscValue / totalMeals) : 0.0;
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
            }
          }
        }

        // 3. إنشاء مفتاح أرشيف شهري جديد لهذا الشهر
        final closureDate = DateFormat('yyyy-MM-dd').format(DateTime.now());
        final archiveKeyId = await db.createMonthlyArchiveKey(txn, closureDate);
        if (archiveKeyId == null) {
          throw Exception("فشل إنشاء مفتاح الأرشيف الشهري.");
        }
        createdArchiveKeyId = archiveKeyId;

        // 4. أرشفة لقطة للمشتركين في members_archive
        await txn.rawInsert(
          "INSERT OR REPLACE INTO members_archive "
          "(member_id, name, rank, contribution, total_due, date, archive_key_id) "
          "SELECT member_id, name, rank, contribution, total_due, date, ? "
          "FROM members",
          [archiveKeyId],
        );

        // 5. استخراج مجاميع المشتركين للشهر
        final memberData = await getMemberData(txn);
        final mealData = await getMealTotals(txn);
        final drinkData = await getDrinkTotals(txn);
        final miscData = await getMiscTotals(txn);
        final totalContributions = await getTotalContributions(txn, memberData);

        // 6. إنشاء سجل تقفيل الشهر
        final closureId = await txn.rawInsert(
          "INSERT INTO monthly_closures (closure_date, archive_key_id) VALUES (?, ?)",
          [closureDate, archiveKeyId],
        );
        createdClosureId = closureId;

        // 7. حفظ ملخصات الأعضاء في closure_summary و closure_summary_archive
        double dbTotalMeals = 0.0;
        double dbTotalDrinks = 0.0;
        double dbTotalMisc = 0.0;
        double dbTotalConsumption = 0.0;

        for (final memberId in memberData.keys) {
          final contribution = memberData[memberId]![2] as double;
          final meals = mealData[memberId] ?? [0.0, 0.0];
          final drinks = drinkData[memberId] ?? [0.0, 0.0];
          final misc = miscData[memberId] ?? 0.0;
          final consumption = meals[1] + drinks[1] + misc;
          final remaining = contribution - consumption;

          dbTotalMeals += meals[1];
          dbTotalDrinks += drinks[1];
          dbTotalMisc += misc;
          dbTotalConsumption += consumption;

          await txn.rawInsert(
            "INSERT OR REPLACE INTO closure_summary "
            "(closure_id, member_id, total_meals, total_drinks, total_miscellaneous, "
            "total_consumption, total_contribution, remaining_cash) "
            "VALUES (?, ?, ?, ?, ?, ?, ?, ?)",
            [closureId, memberId, meals[1], drinks[1], misc, consumption, contribution, remaining],
          );

          await txn.rawInsert(
            "INSERT OR REPLACE INTO closure_summary_archive "
            "(closure_id, member_id, total_meals, total_drinks, total_miscellaneous, "
            "total_consumption, total_contribution, remaining_cash, archive_key_id) "
            "VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)",
            [closureId, memberId, meals[1], drinks[1], misc, consumption, contribution, remaining, archiveKeyId],
          );
        }

        // 8. حفظ إجماليات الشهر في monthly_totals_archive
        final totalRemainingItems = await getRemainingItemsTotal(txn);
        final dbTotalRemainingCash = totalContributions - (dbTotalConsumption + totalRemainingItems);

        await txn.rawInsert(
          "INSERT INTO monthly_totals_archive ("
          "archive_key_id, total_meals, total_drinks, total_misc, "
          "total_consumption, total_contributions, remaining_items, remaining_cash"
          ") VALUES (?, ?, ?, ?, ?, ?, ?, ?)",
          [
            archiveKeyId,
            dbTotalMeals,
            dbTotalDrinks,
            dbTotalMisc,
            dbTotalConsumption,
            totalContributions,
            totalRemainingItems,
            dbTotalRemainingCash,
          ],
        );

        // 9. أرشفة بيانات المعاملات للشهر المنتهي
        await txn.rawInsert(
          "INSERT OR REPLACE INTO meal_records_archive "
          "(meal_record_id, meal_type, date, member_id, final_cost, archive_key_id, meal_id, is_legacy) "
          "SELECT meal_record_id, meal_type, date, member_id, final_cost, ?, meal_id, is_legacy "
          "FROM meal_records",
          [archiveKeyId],
        );

        await txn.rawInsert(
          "INSERT OR REPLACE INTO drink_records_archive "
          "(drink_record_id, date, drink_name, member_id, quantity, total_cost, archive_key_id) "
          "SELECT drink_record_id, date, drink_name, member_id, quantity, total_cost, ? "
          "FROM drink_records",
          [archiveKeyId],
        );

        await txn.rawInsert(
          "INSERT OR REPLACE INTO miscellaneous_contributions_archive "
          "(misc_contribution_id, member_id, misc_amount, meal_count, distribution_date, archive_key_id) "
          "SELECT misc_contribution_id, member_id, misc_amount, meal_count, distribution_date, ? "
          "FROM miscellaneous_contributions",
          [archiveKeyId],
        );

        // أرشفة لقطة كاملة للمشتريات والمخزون في expenses_archive
        await txn.rawInsert(
          "INSERT OR REPLACE INTO expenses_archive "
          "(expense_id, item_name, unit, quantity, price, total_price, consumption, remaining, is_miscellaneous, is_drink, date, archive_key_id) "
          "SELECT expense_id, item_name, unit, quantity, price, total_price, consumption, remaining, is_miscellaneous, is_drink, date, ? "
          "FROM expenses",
          [archiveKeyId],
        );

        // 10. تصفير وتجهيز الشهر الجديد:
        // أ. مسح سجلات الوجبات والمشروبات والنثريات النشطة
        await txn.rawDelete("DELETE FROM meal_records");
        await txn.rawDelete("DELETE FROM meal_items");
        await txn.rawDelete("DELETE FROM meals");
        await txn.rawDelete("DELETE FROM drink_records");
        await txn.rawDelete("DELETE FROM miscellaneous_contributions");
        await txn.rawDelete("DELETE FROM miscellaneous_expenses");

        // ب. المخزون: الأصناف ذات الرصيد تصبح رصيد بداية للشهر الجديد، والأصناف المنتهية أو النثريات تحذف
        await txn.rawUpdate(
          "UPDATE expenses "
          "SET quantity = remaining, "
          "consumption = 0, "
          "total_price = remaining * price, "
          "date = ? "
          "WHERE remaining > 0 AND is_miscellaneous = 0",
          [closureDate],
        );
        await txn.rawDelete(
          "DELETE FROM expenses WHERE remaining <= 0 OR is_miscellaneous = 1",
        );

        // ج. تصفير المستحق على المشتركين، مع الحفاظ على المساهمة الشهرية
        await txn.rawUpdate("UPDATE members SET total_due = 0");
      });

      return {
        'success': true,
        'archive_key_id': createdArchiveKeyId,
        'closure_id': createdClosureId,
      };
    } catch (e) {
      debugPrint("Error executing full month finalization: $e");
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }

  // --- دالات متوافقة مع الاستدعاءات القديمة إن وجدت ---

  static Future<Map<String, dynamic>> distributeAndArchiveMiscellaneous(
      BuildContext context, DatabaseManager db) async {
    try {
      Map<String, dynamic> result = {'success': false, 'archive_key_id': null};
      await db.transaction((txn) async {
        final distribution = MiscellaneousDistribution(context, db);
        final distResult = await distribution.distributeMiscellaneous(txn);

        final distributionDate = DateFormat('yyyy-MM-dd').format(DateTime.now());
        final archiveKeyId = await db.createMonthlyArchiveKey(txn, distributionDate);
        if (archiveKeyId == null) {
          throw Exception("Failed to create archive key.");
        }

        if (!distResult['success']) {
          result = {'success': true, 'archive_key_id': archiveKeyId};
          return;
        }

        final expenseIds = distResult['expense_ids'] as List<int>;
        if (expenseIds.isNotEmpty) {
          final placeholders = List.filled(expenseIds.length, '?').join(',');

          await txn.rawInsert(
            "INSERT OR REPLACE INTO expenses_archive "
            "(expense_id, item_name, unit, quantity, price, total_price, consumption, remaining, is_miscellaneous, is_drink, date, archive_key_id) "
            "SELECT expense_id, item_name, unit, quantity, price, total_price, consumption, remaining, is_miscellaneous, is_drink, date, ? "
            "FROM expenses WHERE expense_id IN ($placeholders)",
            [archiveKeyId, ...expenseIds],
          );

          await txn.rawDelete(
            "DELETE FROM expenses WHERE expense_id IN ($placeholders)",
            expenseIds,
          );
        }

        result = {'success': true, 'archive_key_id': archiveKeyId};
      });
      return result;
    } catch (e) {
      debugPrint("Error distributing and archiving: $e");
      return {'success': false, 'archive_key_id': null};
    }
  }

  static Future<void> runFinalizeProcess(BuildContext context, DatabaseManager db, int archiveKeyId) async {
    // تم دمج المنطق بالكامل في executeFullMonthFinalization
  }

  static Future<bool> archiveAllData(DatabaseManager db, int archiveKeyId) async {
    // تم دمج المنطق بالكامل في executeFullMonthFinalization
    return true;
  }

  static Future<bool> archiveMembersData(DatabaseExecutor db, int archiveKeyId) async {
    try {
      final result = await db.rawInsert(
        "INSERT OR REPLACE INTO members_archive "
        "SELECT member_id, name, rank, contribution, total_due, date, ? "
        "FROM members",
        [archiveKeyId],
      );
      debugPrint("Archived $result members");
      return result > 0;
    } catch (e) {
      debugPrint("Error archiving members data: $e");
      return false;
    }
  }

  static Future<Map<int, List<dynamic>>> getMemberData(DatabaseExecutor db) async {
    try {
      final result = await db.rawQuery(
        "SELECT member_id, name, rank, contribution, total_due FROM members",
      );
      final data = {
        for (var row in result)
          row['member_id'] as int: [
            row['name'] as String,
            row['rank'] as String,
            (row['contribution'] as num).toDouble(),
            (row['total_due'] as num).toDouble(),
          ]
      };
      debugPrint("Fetched ${data.length} members");
      return data;
    } catch (e) {
      debugPrint("Error fetching member data: $e");
      return {};
    }
  }

  static Future<Map<int, List<double>>> getMealTotals(DatabaseExecutor db) async {
    try {
      final result = await db.rawQuery(
        "SELECT member_id, COUNT(*) as count, SUM(final_cost) as total "
        "FROM meal_records GROUP BY member_id",
      );
      final data = {
        for (var row in result)
          row['member_id'] as int: [
            (row['count'] as int).toDouble(),
            (row['total'] as num).toDouble(),
          ]
      };
      debugPrint("Fetched ${data.length} meal totals");
      return data;
    } catch (e) {
      debugPrint("Error fetching meal totals: $e");
      return {};
    }
  }

  static Future<Map<int, List<double>>> getDrinkTotals(DatabaseExecutor db) async {
    try {
      final result = await db.rawQuery(
        "SELECT member_id, SUM(quantity) as count, SUM(total_cost) as total "
        "FROM drink_records GROUP BY member_id",
      );
      final data = {
        for (var row in result)
          row['member_id'] as int: [
            (row['count'] as int).toDouble(),
            (row['total'] as num).toDouble(),
          ]
      };
      debugPrint("Fetched ${data.length} drink totals");
      return data;
    } catch (e) {
      debugPrint("Error fetching drink totals: $e");
      return {};
    }
  }

  static Future<Map<int, double>> getMiscTotals(DatabaseExecutor db) async {
    try {
      final result = await db.rawQuery(
        "SELECT member_id, SUM(misc_amount) as total "
        "FROM miscellaneous_contributions GROUP BY member_id",
      );
      final data = {
        for (var row in result) row['member_id'] as int: (row['total'] as num).toDouble()
      };
      debugPrint("Fetched ${data.length} misc totals");
      return data;
    } catch (e) {
      debugPrint("Error fetching misc totals: $e");
      return {};
    }
  }

  static Future<double> getTotalContributions(
      DatabaseExecutor db, Map<int, List<dynamic>> memberData) async {
    try {
      final result = await db.rawQuery("SELECT SUM(contribution) as total FROM members");
      final total = (result.first['total'] as num?)?.toDouble() ?? 0.0;
      debugPrint("Total contributions: $total");
      return total;
    } catch (e) {
      debugPrint("Error fetching total contributions: $e");
      return 0.0;
    }
  }

  static Future<int> saveMonthlyClosure(DatabaseExecutor db, int archiveKeyId) async {
    try {
      final closureDate = DateFormat('yyyy-MM-dd').format(DateTime.now());
      final closureId = await db.rawInsert(
        "INSERT INTO monthly_closures (closure_date, archive_key_id) VALUES (?, ?)",
        [closureDate, archiveKeyId],
      );
      debugPrint("Saved monthly closure with ID: $closureId");
      return closureId;
    } catch (e) {
      debugPrint("Error saving monthly closure: $e");
      return 0;
    }
  }

  static Future<void> saveClosureSummaries(
    DatabaseExecutor db,
    int closureId,
    Map<int, List<dynamic>> memberData,
    Map<int, List<double>> mealData,
    Map<int, List<double>> drinkData,
    Map<int, double> miscData,
    double totalContributions,
    int archiveKeyId,
  ) async {
    try {
      int savedCount = 0;
      for (final memberId in memberData.keys) {
        final contribution = memberData[memberId]![2] as double;

        final meals = mealData[memberId] ?? [0.0, 0.0];
        final drinks = drinkData[memberId] ?? [0.0, 0.0];
        final misc = miscData[memberId] ?? 0.0;

        final totalConsumption = meals[1] + drinks[1] + misc;
        final remaining = contribution - totalConsumption;

        await db.rawInsert(
          "INSERT OR REPLACE INTO closure_summary "
          "(closure_id, member_id, total_meals, total_drinks, total_miscellaneous, "
          "total_consumption, total_contribution, remaining_cash) "
          "VALUES (?, ?, ?, ?, ?, ?, ?, ?)",
          [
            closureId,
            memberId,
            meals[1],
            drinks[1],
            misc,
            totalConsumption,
            contribution,
            remaining,
          ],
        );
        savedCount++;
      }
      debugPrint("Saved $savedCount closure summaries");
    } catch (e) {
      debugPrint("Error saving closure summaries: $e");
    }
  }

  static Future<double> getRemainingItemsTotal(DatabaseExecutor db) async {
    try {
      final result = await db.rawQuery(
        "SELECT SUM(remaining * price) as total_remaining FROM expenses WHERE remaining > 0 AND is_miscellaneous = 0",
      );
      final total = (result.isNotEmpty && result.first['total_remaining'] != null)
          ? (result.first['total_remaining'] as num).toDouble()
          : 0.0;
      debugPrint("Total remaining items value: $total");
      return total;
    } catch (e) {
      debugPrint("Error fetching total remaining items: $e");
      return 0.0;
    }
  }

  static Future<int?> getClosureIdForArchiveKey(DatabaseManager db, int archiveKeyId) async {
    try {
      final result = await db.fetchOne(
        "SELECT closure_id FROM monthly_closures WHERE archive_key_id = ? ORDER BY closure_id DESC",
        [archiveKeyId],
      );
      final closureId = result?['closure_id'] as int?;
      debugPrint("Fetched closure_id: $closureId for archiveKeyId: $archiveKeyId");
      return closureId;
    } catch (e) {
      debugPrint("Error fetching closure_id: $e");
      return null;
    }
  }

  static Future<Map<String, dynamic>?> fetchReportData(DatabaseManager db, int closureId) async {
    try {
      debugPrint("Fetching report data for closure_id: $closureId");

      final periodData = await db.fetchOne(
        "SELECT mc.closure_date, ak.archive_key_id, ak.start_date, ak.end_date "
        "FROM monthly_closures mc "
        "JOIN archive_keys ak ON mc.archive_key_id = ak.archive_key_id "
        "WHERE mc.closure_id = ?",
        [closureId],
      );

      if (periodData == null) {
        debugPrint("No period data found for closure_id: $closureId");
        return null;
      }
      debugPrint("Period data: $periodData");

      final archiveKeyId = periodData['archive_key_id'] as int;

      final summaryData = await db.fetchAll(
        "SELECT COALESCE(m.name, ma.name, 'عضو غير معروف') as name, "
        "s.total_meals, s.total_drinks, s.total_miscellaneous, "
        "s.total_consumption, s.total_contribution, s.remaining_cash "
        "FROM closure_summary s "
        "LEFT JOIN members m ON s.member_id = m.member_id "
        "LEFT JOIN members_archive ma ON (s.member_id = ma.member_id AND ma.archive_key_id = ?) "
        "WHERE s.closure_id = ?",
        [archiveKeyId, closureId],
      );
      debugPrint("Fetched ${summaryData.length} summary records");

      final totalMeals = summaryData.fold<double>(
          0, (sum, row) => sum + (row['total_meals'] as num).toDouble());
      final totalDrinks = summaryData.fold<double>(
          0, (sum, row) => sum + (row['total_drinks'] as num).toDouble());
      final totalMisc = summaryData.fold<double>(
          0, (sum, row) => sum + (row['total_miscellaneous'] as num).toDouble());
      final totalConsumption = summaryData.fold<double>(
          0, (sum, row) => sum + (row['total_consumption'] as num).toDouble());
      final totalContributions = summaryData.fold<double>(
          0, (sum, row) => sum + (row['total_contribution'] as num).toDouble());

      final remRes = await db.fetchOne(
        "SELECT COALESCE(SUM(remaining * price), 0) as total_remaining FROM expenses_archive WHERE archive_key_id = ? AND remaining > 0",
        [archiveKeyId],
      );
      final totalRemainingItems = remRes != null ? (remRes['total_remaining'] as num).toDouble() : 0.0;
      final totalRemainingCash = totalContributions - (totalConsumption + totalRemainingItems);

      return {
        'periodData': periodData,
        'summaryData': summaryData,
        'totalMeals': totalMeals,
        'totalDrinks': totalDrinks,
        'totalMisc': totalMisc,
        'totalConsumption': totalConsumption,
        'totalContributions': totalContributions,
        'totalRemainingItems': totalRemainingItems,
        'totalRemainingCash': totalRemainingCash,
      };
    } catch (e) {
      debugPrint("Error fetching report data: $e");
      return null;
    }
  }
}