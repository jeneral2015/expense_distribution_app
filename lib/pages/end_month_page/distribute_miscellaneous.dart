import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../utils/database.dart';
import 'miscellaneous_distribution.dart';

class DistributeMiscellaneous {
  final BuildContext context;
  final DatabaseManager db;

  DistributeMiscellaneous(this.context, this.db);

  Future<void> showConfirmation() async {
    return showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text("توزيع النثريات"),
          content: const Text("سيتم توزيع النثريات، هل تريد الاستمرار؟"),
          actions: [
            TextButton(
              child: const Text("لا"),
              onPressed: () => Navigator.of(context).pop(),
            ),
            TextButton(
              child: const Text("نعم"),
              onPressed: () async {
                Navigator.of(context).pop();
                await _confirmDistribution();
              },
            ),
          ],
          actionsAlignment: MainAxisAlignment.end,
        );
      },
    );
  }

  Future<void> _confirmDistribution() async {
    try {
      final result = await _distributeAndArchiveMiscellaneous();
      if (result['success']) {
        showSnackbar("تم توزيع النثريات والأرشفة بنجاح!");
      } else {
        showSnackbar("فشل توزيع النثريات.");
      }
    } catch (e) {
      debugPrint("Error in distribution: $e");
      showSnackbar("خطأ أثناء التوزيع: $e");
    }
  }

  Future<Map<String, dynamic>> _distributeAndArchiveMiscellaneous() async {
    try {
      Map<String, dynamic> result = {'success': false, 'archive_key_id': null};
      await db.transaction((txn) async {
        // استخدام الكلاس المشترك لتوزيع النثريات
        final distribution = MiscellaneousDistribution(context, db);
        final distResult = await distribution.distributeMiscellaneous(txn);
        
        if (!distResult['success']) {
          return;
        }

        final expenseIds = distResult['expense_ids'] as List<int>;
        if (expenseIds.isEmpty) {
          result = {'success': false, 'archive_key_id': null};
          return;
        }

        // جلب تاريخ أول معاملة أو استخدام تاريخ اليوم
        final distributionDate = DateFormat('yyyy-MM-dd').format(DateTime.now());
        final firstDate = await db.getFirstTransactionDate(txn) ?? distributionDate;

        // إنشاء مفتاح الأرشفة
        final archiveKeyId = await db.getOrCreateArchiveKey(txn, firstDate);
        if (archiveKeyId == null) {
          throw Exception("Failed to create archive key.");
        }

        // أرشفة توزيعات النثريات
        final newContributions = await txn.rawQuery(
          "SELECT misc_contribution_id FROM miscellaneous_contributions WHERE distribution_date = ?",
          [distributionDate],
        );

        if (newContributions.isNotEmpty) {
          final newIds = newContributions.map((row) => row['misc_contribution_id'] as int).toList();
          final placeholders = List.filled(newIds.length, '?').join(',');

          await txn.rawDelete(
            "DELETE FROM miscellaneous_contributions_archive WHERE misc_contribution_id IN ($placeholders) AND archive_key_id = ?",
            [...newIds, archiveKeyId],
          );

          await txn.rawInsert(
            "INSERT OR REPLACE INTO miscellaneous_contributions_archive "
            "(misc_contribution_id, member_id, misc_amount, meal_count, distribution_date, archive_key_id) "
            "SELECT misc_contribution_id, member_id, misc_amount, meal_count, distribution_date, ? "
            "FROM miscellaneous_contributions WHERE misc_contribution_id IN ($placeholders)",
            [archiveKeyId, ...newIds],
          );
        }

        // أرشفة وحذف النثريات من expenses
        final placeholders2 = List.filled(expenseIds.length, '?').join(',');
        await txn.rawDelete(
          "DELETE FROM expenses_archive WHERE expense_id IN ($placeholders2) AND archive_key_id = ?",
          [...expenseIds, archiveKeyId],
        );

        await txn.rawInsert(
          "INSERT OR REPLACE INTO expenses_archive "
          "(expense_id, item_name, quantity, price, total_price, consumption, remaining, is_miscellaneous, is_drink, date, archive_key_id) "
          "SELECT expense_id, item_name, quantity, price, total_price, consumption, remaining, is_miscellaneous, is_drink, date, ? "
          "FROM expenses WHERE expense_id IN ($placeholders2)",
          [archiveKeyId, ...expenseIds],
        );

        await txn.rawDelete(
          "DELETE FROM expenses WHERE expense_id IN ($placeholders2)",
          expenseIds,
        );

        debugPrint("Archived and deleted ${expenseIds.length} miscellaneous expenses");
        result = {'success': true, 'archive_key_id': archiveKeyId};
      });
      return result;
    } catch (e) {
      debugPrint("Error distributing and archiving: $e");
      showSnackbar("خطأ أثناء التوزيع والأرشفة: $e");
      return {'success': false, 'archive_key_id': null};
    }
  }

  void showSnackbar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }
}