import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';
import 'package:intl/intl.dart';
import '../../utils/database.dart';
import 'miscellaneous_distribution.dart';

class FinalizeMonthData {
  static Future<Map<String, dynamic>> distributeAndArchiveMiscellaneous(
      BuildContext context, DatabaseManager db) async {
    try {
      Map<String, dynamic> result = {'success': false, 'archive_key_id': null};
      await db.transaction((txn) async {
        final distribution = MiscellaneousDistribution(context, db);
        final distResult = await distribution.distributeMiscellaneous(txn);

        final distributionDate = DateFormat('yyyy-MM-dd').format(DateTime.now());
        final firstDate = await db.getFirstTransactionDate(txn) ?? distributionDate;
        final archiveKeyId = await db.getOrCreateArchiveKey(txn, firstDate);
        if (archiveKeyId == null) {
          debugPrint("Failed to create archive key");
          throw Exception("Failed to create archive key.");
        }
        debugPrint("Created archive key: $archiveKeyId");

        if (!distResult['success']) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("لا توجد نثريات للتوزيع، يتم الاستمرار في تقفيل الشهر")),
          );
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
          debugPrint("Archived and deleted ${expenseIds.length} miscellaneous expenses");
        }

        result = {'success': true, 'archive_key_id': archiveKeyId};
      });
      return result;
    } catch (e) {
      debugPrint("Error distributing and archiving: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("خطأ أثناء توزيع النثريات: $e")),
      );
      return {'success': false, 'archive_key_id': null};
    }
  }

  static Future<void> runFinalizeProcess(BuildContext context, DatabaseManager db, int archiveKeyId) async {
    try {
      await db.transaction((txn) async {
        final memberCount = await txn.rawQuery("SELECT COUNT(*) as count FROM members");
        if (memberCount.isEmpty || (memberCount.first['count'] as int) == 0) {
          debugPrint("No members found in members table");
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("خطأ: لا توجد أعضاء لأرشفتها")),
          );
          throw Exception("لا توجد أعضاء في جدول الأعضاء");
        }

        if (!await archiveMembersData(txn, archiveKeyId)) {
          debugPrint("Failed to archive members data");
          throw Exception("فشل أرشفة بيانات الأعضاء");
        }

        final memberData = await getMemberData(txn);
        final mealData = await getMealTotals(txn);
        final drinkData = await getDrinkTotals(txn);
        final miscData = await getMiscTotals(txn);
        final totalContributions = await getTotalContributions(txn, memberData);

        debugPrint("Fetched data: ${memberData.length} members, ${mealData.length} meals, ${drinkData.length} drinks, ${miscData.length} misc");

        if (miscData.isEmpty) {
          debugPrint("No miscellaneous contributions found for this closure");
        }

        final closureId = await saveMonthlyClosure(txn, archiveKeyId);
        if (closureId == 0) {
          debugPrint("Failed to save monthly closure");
          throw Exception("فشل حفظ تقفيل الشهر");
        }
        debugPrint("Saved monthly closure with ID: $closureId");

        await saveClosureSummaries(
            txn, closureId, memberData, mealData, drinkData, miscData, totalContributions, archiveKeyId);

        final summaries = await txn.rawQuery(
            "SELECT * FROM closure_summary WHERE closure_id = ?", [closureId]);
        debugPrint("Saved ${summaries.length} closure summaries");

        await txn.rawUpdate("UPDATE members SET total_due = 0", []);
        debugPrint("Reset total_due for all members");
      });
    } catch (e) {
      debugPrint("Error in finalize process: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("حدث خطأ أثناء تقفيل الشهر: $e")),
      );
    }
  }

  static Future<bool> archiveAllData(DatabaseManager db, int archiveKeyId) async {
    try {
      await db.transaction((txn) async {
        final closureDate = DateFormat('yyyy-MM-dd').format(DateTime.now());

        final archivePeriod = await txn.rawQuery(
          "SELECT start_date, end_date FROM archive_keys WHERE archive_key_id = ?",
          [archiveKeyId],
        );

        if (archivePeriod.isEmpty) {
          throw Exception("Invalid archive_key_id: $archiveKeyId");
        }

        final startDate = archivePeriod.first['start_date'] as String;
        final endDate = archivePeriod.first['end_date'] as String;

        // Archive meal records
        final mealRecordsCount = await txn.rawInsert(
          "INSERT INTO meal_records_archive "
          "(meal_record_id, meal_type, date, member_id, final_cost, archive_key_id, meal_id, is_legacy) "
          "SELECT meal_record_id, meal_type, date, member_id, final_cost, ?, meal_id, is_legacy "
          "FROM meal_records "
          "WHERE date BETWEEN ? AND ?",
          [archiveKeyId, startDate, endDate],
        );
        debugPrint("Archived $mealRecordsCount meal records");

        // Archive drink records
        final drinkRecordsCount = await txn.rawInsert(
          "INSERT INTO drink_records_archive "
          "SELECT *, ? FROM drink_records "
          "WHERE date BETWEEN ? AND ?",
          [archiveKeyId, startDate, endDate],
        );
        debugPrint("Archived $drinkRecordsCount drink records");

        // Archive miscellaneous contributions
        final miscContributionsCount = await txn.rawInsert(
          "INSERT INTO miscellaneous_contributions_archive "
          "SELECT *, ? FROM miscellaneous_contributions "
          "WHERE distribution_date BETWEEN ? AND ?",
          [archiveKeyId, startDate, endDate],
        );
        debugPrint("Archived $miscContributionsCount miscellaneous contributions");

        // Archive expenses with all columns including unit
        final expensesCount = await txn.rawInsert(
          "INSERT INTO expenses_archive "
          "SELECT expense_id, item_name, unit, quantity, price, "
          "total_price, consumption, remaining, is_miscellaneous, is_drink, date, ? "
          "FROM expenses "
          "WHERE date BETWEEN ? AND ?",
          [archiveKeyId, startDate, endDate],
        );
        debugPrint("Archived $expensesCount expenses");

        // Update remaining expenses
        await txn.rawUpdate(
          "UPDATE expenses "
          "SET quantity = remaining, "
          "consumption = 0, "
          "total_price = remaining * price, "
          "date = ? "
          "WHERE date BETWEEN ? AND ?",
          [closureDate, startDate, endDate],
        );

        // Archive closure summaries with all columns
        final closureSummariesCount = await txn.rawInsert(
          "INSERT INTO closure_summary_archive "
          "SELECT s.summary_id, s.closure_id, s.member_id, s.total_meals, "
          "s.total_drinks, s.total_miscellaneous, s.total_consumption, "
          "s.total_contribution, s.remaining_cash, ? "
          "FROM closure_summary s "
          "WHERE s.closure_id IN ("
          "SELECT closure_id FROM monthly_closures "
          "WHERE archive_key_id = ?"
          ")",
          [archiveKeyId, archiveKeyId],
        );
        debugPrint("Archived $closureSummariesCount closure summaries");

        // Calculate actual totals before archiving
        final memberData = await getMemberData(txn);
        final mealData = await getMealTotals(txn);
        final drinkData = await getDrinkTotals(txn);
        final miscData = await getMiscTotals(txn);
        final totalContributions = await getTotalContributions(txn, memberData);

        // Calculate totals from the data
        double dbTotalMeals = 0.0;
        double dbTotalDrinks = 0.0;
        double dbTotalMisc = 0.0;
        double dbTotalConsumption = 0.0;

        for (final memberId in memberData.keys) {
          final meals = mealData[memberId] ?? [0.0, 0.0];
          final drinks = drinkData[memberId] ?? [0.0, 0.0];
          final misc = miscData[memberId] ?? 0.0;

          dbTotalMeals += meals[1];
          dbTotalDrinks += drinks[1];
          dbTotalMisc += misc;
          dbTotalConsumption += meals[1] + drinks[1] + misc;
        }

        final totalRemainingItems = await getRemainingItemsTotal(txn);
        final dbTotalRemainingCash = totalContributions - (dbTotalConsumption + totalRemainingItems);

        // Save monthly totals with actual calculated values
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
            dbTotalRemainingCash
          ],
        );

        // Delete archived data
        final deletedMisc = await txn.rawDelete(
          "DELETE FROM miscellaneous_contributions WHERE distribution_date BETWEEN ? AND ?",
          [startDate, endDate],
        );
        final deletedMeals = await txn.rawDelete(
          "DELETE FROM meal_records WHERE date BETWEEN ? AND ?",
          [startDate, endDate],
        );
        final deletedDrinks = await txn.rawDelete(
          "DELETE FROM drink_records WHERE date BETWEEN ? AND ?",
          [startDate, endDate],
        );
        debugPrint("Deleted $deletedMisc misc, $deletedMeals meals, $deletedDrinks drinks");

        // Delete from closure_summary
        final deletedSummaries = await txn.rawDelete(
          "DELETE FROM closure_summary "
          "WHERE closure_id IN ("
          "SELECT closure_id FROM monthly_closures "
          "WHERE archive_key_id = ?"
          ")",
          [archiveKeyId],
        );
        debugPrint("Deleted $deletedSummaries records from closure_summary");
      });

      return true;
    } catch (e) {
      debugPrint("Error archiving data: $e");
      return false;
    }
  }

  static Future<bool> archiveMembersData(DatabaseExecutor db, int archiveKeyId) async {
    try {
      final result = await db.rawInsert(
        "INSERT INTO members_archive "
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
      final result = await db.rawQuery("SELECT SUM(total_due) as total FROM members");
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

        final check = await db.rawQuery(
          "SELECT 1 FROM members_archive "
          "WHERE member_id = ? AND archive_key_id = ?",
          [memberId, archiveKeyId],
        );

        if (check.isEmpty) {
          debugPrint("Skipping member $memberId: not found in members_archive");
          continue;
        }

        await db.rawInsert(
          "INSERT INTO closure_summary "
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
        debugPrint("Saved summary for member $memberId");
      }
      debugPrint("Saved $savedCount closure summaries");
    } catch (e) {
      debugPrint("Error saving closure summaries: $e");
    }
  }

  static Future<double> getRemainingItemsTotal(DatabaseExecutor db) async {
    try {
      final result = await db.rawQuery(
        "SELECT SUM(remaining * price) as total_remaining FROM expenses WHERE remaining > 0",
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
        "SELECT closure_id FROM monthly_closures WHERE archive_key_id = ?",
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
        "SELECT mc.closure_date, ak.start_date, ak.end_date "
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

      final summaryData = await db.fetchAll(
        "SELECT m.name, s.total_meals, s.total_drinks, s.total_miscellaneous, "
        "s.total_consumption, s.total_contribution, s.remaining_cash "
        "FROM closure_summary s "
        "JOIN members m ON s.member_id = m.member_id "
        "WHERE s.closure_id = ?",
        [closureId],
      );
      debugPrint("Fetched ${summaryData.length} summary records");

      if (summaryData.isEmpty) {
        debugPrint("No summary data found for closure_id: $closureId");
      }

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

      final totalRemainingItems = await getRemainingItemsTotal(db.database!);
      final totalRemainingCash = totalContributions - (totalConsumption + totalRemainingItems);

      debugPrint("Saving totals to monthly_totals_archive");
      await db.transaction((txn) async {
        await txn.rawUpdate(
          "UPDATE monthly_totals_archive SET "
          "total_meals = ?, total_drinks = ?, total_misc = ?, "
          "total_consumption = ?, total_contributions = ?, "
          "remaining_items = ?, remaining_cash = ? "
          "WHERE archive_key_id = ?",
          [
            totalMeals,
            totalDrinks,
            totalMisc,
            totalConsumption,
            totalContributions,
            totalRemainingItems,
            totalRemainingCash,
            periodData['archive_key_id'],
          ],
        );
      });

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