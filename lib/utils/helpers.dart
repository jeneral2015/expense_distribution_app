import 'database.dart';
import 'logger.dart';

class Helpers {
  static Future<bool> reDistributeMealCost(dynamic txn, int mealId, List<int> remainingMemberIds) async {
    try {
      // Get the total cost of the meal
      final mealResult = await txn.rawQuery(
        'SELECT total_cost FROM meals WHERE meal_id = ?',
        [mealId],
      );

      if (mealResult.isEmpty) {
        AppLogger.logError('No meal found for meal_id: $mealId');
        return false;
      }

      final totalCost = mealResult.first['total_cost'] as double? ?? 0.0;

      if (remainingMemberIds.isEmpty) {
        AppLogger.logError('No remaining members to redistribute cost for meal_id: $mealId');
        return false;
      }

      // Calculate new cost per member
      final costPerMember = totalCost / remainingMemberIds.length;

      // Update each remaining member's meal record and total_due
      for (final memberId in remainingMemberIds) {
        // Get the old cost to adjust total_due correctly
        final oldCostResult = await txn.rawQuery(
          'SELECT final_cost FROM meal_records WHERE meal_id = ? AND member_id = ?',
          [mealId, memberId],
        );
        final oldCost = oldCostResult.isNotEmpty ? oldCostResult.first['final_cost'] as double? ?? 0.0 : 0.0;

        // Update meal_records
        await txn.rawUpdate(
          'UPDATE meal_records SET final_cost = ? WHERE meal_id = ? AND member_id = ?',
          [costPerMember, mealId, memberId],
        );

        // Update total_due in members (subtract old cost, add new cost)
        await txn.rawUpdate(
          'UPDATE members SET total_due = total_due - ? + ? WHERE member_id = ?',
          [oldCost, costPerMember, memberId],
        );
      }

      AppLogger.logInfo('Successfully redistributed meal cost for meal_id: $mealId');
      return true;
    } catch (e) {
      AppLogger.logError('Error redistributing meal cost for meal_id: $mealId: $e');
      return false;
    }
  }

  static Future<bool> reverseDrinkEffects(int drinkRecordId) async {
    final dbManager = DatabaseManager();
    
    try {
      await dbManager.transaction((txn) async {
        // الحصول على تفاصيل السجل مع الكميات (مهم للتعديلات)
        final drinkResult = await txn.rawQuery(
          'SELECT member_id, total_cost, drink_name, quantity FROM drink_records WHERE drink_record_id = ?',
          [drinkRecordId],
        );
        
        if (drinkResult.isEmpty) {
          AppLogger.logWarning('Drink record not found for ID: $drinkRecordId');
          return;
        }
        
        final row = drinkResult.first;
        final memberId = row['member_id'] as int;
        final totalCost = row['total_cost'] as double;
        final drinkName = row['drink_name'] as String;
        final quantity = row['quantity'] as int;
        
        // 1. إلغاء تأثير المديونية
        await txn.rawUpdate(
          'UPDATE members SET total_due = total_due - ? WHERE member_id = ?',
          [totalCost, memberId],
        );
        
        // 2. إلغاء تأثير المخزون (إعادة الكميات)
        await txn.rawUpdate(
          'UPDATE expenses SET consumption = consumption - ?, remaining = remaining + ? WHERE item_name = ?',
          [quantity, quantity, drinkName],
        );
        
        // 3. حذف السجل
        await txn.rawDelete(
          'DELETE FROM drink_records WHERE drink_record_id = ?',
          [drinkRecordId],
        );
      });
      
      AppLogger.logInfo('Successfully reversed drink effects for drink_record_id: $drinkRecordId');
      return true;
    } catch (e) {
      AppLogger.logError('Error reversing drink effects for drink_record_id: $drinkRecordId: $e');
      return false;
    }
  }

  // ✅ التصحيح هنا: تعريف drinkRecordId خارج transaction
  static Future<bool> reapplyDrinkEffect(Map<String, dynamic> record) async {
    final dbManager = DatabaseManager();
    
    // ✅ الحل: تعريف drinkRecordId هنا (خارج transaction)
    final drinkRecordId = record['drink_record_id'] as int;
    
    try {
      await dbManager.transaction((txn) async {
        final memberId = record['member_id'] as int;
        final drinkName = record['drink_name'] as String;
        final quantity = record['quantity'] as int;
        final totalCost = record['total_cost'] as double;
        final date = record['date'] as String;
        
        // 1. إعادة إدراج السجل
        await txn.rawInsert(
          'INSERT INTO drink_records (drink_record_id, date, drink_name, member_id, quantity, total_cost) '
          'VALUES (?, ?, ?, ?, ?, ?)',
          [drinkRecordId, date, drinkName, memberId, quantity, totalCost],
        );
        
        // 2. إعادة تطبيق المديونية
        await txn.rawUpdate(
          'UPDATE members SET total_due = total_due + ? WHERE member_id = ?',
          [totalCost, memberId],
        );
        
        // 3. إعادة تطبيق المخزون
        await txn.rawUpdate(
          'UPDATE expenses SET consumption = consumption + ?, remaining = remaining - ? WHERE item_name = ?',
          [quantity, quantity, drinkName],
        );
      });
      
      // ✅ الآن drinkRecordId معرّف هنا (خارج transaction)
      AppLogger.logInfo('Successfully reapplied drink effect for drink_record_id: $drinkRecordId');
      return true;
    } catch (e) {
      AppLogger.logError('Error reapplying drink effect: $e');
      return false;
    }
  }

  static Future<bool> reverseMiscEffects(int miscContributionId) async {
    final dbManager = DatabaseManager();
    
    try {
      await dbManager.transaction((txn) async {
        // Get misc contribution details
        final miscResult = await txn.rawQuery(
          'SELECT member_id, misc_amount FROM miscellaneous_contributions WHERE misc_contribution_id = ?',
          [miscContributionId],
        );
        
        if (miscResult.isEmpty) return;
        
        final memberId = miscResult.first['member_id'] as int;
        final miscAmount = miscResult.first['misc_amount'] as double;
        
        // Reverse member dues
        await txn.rawUpdate(
          'UPDATE members SET total_due = total_due - ? WHERE member_id = ?',
          [miscAmount, memberId],
        );
        
        // Delete the misc contribution
        await txn.rawDelete(
          'DELETE FROM miscellaneous_contributions WHERE misc_contribution_id = ?',
          [miscContributionId],
        );
      });
      
      return true;
    } catch (e) {
      AppLogger.logError('Error reversing misc effects: $e');
      return false;
    }
  }

  static Future<bool> reverseMiscExpenseEffects(int miscExpenseId) async {
    final dbManager = DatabaseManager();
    
    try {
      await dbManager.transaction((txn) async {
        // Get misc expense details
        final expenseResult = await txn.rawQuery(
          'SELECT member_id, amount FROM miscellaneous_expenses WHERE misc_expense_id = ?',
          [miscExpenseId],
        );
        
        if (expenseResult.isEmpty) return;
        
        final memberId = expenseResult.first['member_id'] as int;
        final amount = expenseResult.first['amount'] as double;
        
        // Reverse member dues
        await txn.rawUpdate(
          'UPDATE members SET total_due = total_due - ? WHERE member_id = ?',
          [amount, memberId],
        );
        
        // Delete the misc expense
        await txn.rawDelete(
          'DELETE FROM miscellaneous_expenses WHERE misc_expense_id = ?',
          [miscExpenseId],
        );
      });
      
      return true;
    } catch (e) {
      AppLogger.logError('Error reversing misc expense effects: $e');
      return false;
    }
  }

  static Future<bool> reverseMealEffects(dynamic txn, int mealId) async {
    try {
      // Fetch meal items to reverse consumption
      final items = await txn.rawQuery(
        'SELECT item_name, quantity_used, price_at_time FROM meal_items WHERE meal_id = ?',
        [mealId],
      );

      // Reverse consumption and remaining in expenses
      for (var item in items) {
        final itemName = item['item_name'] as String?;
        final quantityUsed = item['quantity_used'] as double? ?? 0.0;
        if (itemName != null) {
          await txn.rawUpdate(
            'UPDATE expenses SET consumption = consumption - ?, remaining = remaining + ? WHERE item_name = ?',
            [quantityUsed, quantityUsed, itemName],
          );
        }
      }

      // Get all meal records for this meal
      final mealRecords = await txn.rawQuery(
        'SELECT meal_record_id, member_id, final_cost FROM meal_records WHERE meal_id = ?',
        [mealId],
      );

      // Reverse member dues for each participant
      for (final record in mealRecords) {
        final memberId = record['member_id'] as int?;
        final finalCost = record['final_cost'] as double? ?? 0.0;
        if (memberId != null) {
          await txn.rawUpdate(
            'UPDATE members SET total_due = total_due - ? WHERE member_id = ?',
            [finalCost, memberId],
          );
        }
      }

      // Delete all meal records for this meal
      await txn.rawDelete(
        'DELETE FROM meal_records WHERE meal_id = ?',
        [mealId],
      );

      // Delete meal items
      await txn.rawDelete(
        'DELETE FROM meal_items WHERE meal_id = ?',
        [mealId],
      );

      // Delete the meal itself
      await txn.rawDelete(
        'DELETE FROM meals WHERE meal_id = ?',
        [mealId],
      );

      AppLogger.logInfo('Successfully reversed meal effects for meal_id: $mealId');
      return true;
    } catch (e) {
      AppLogger.logError('Error reversing meal effects for meal_id: $mealId: $e');
      return false;
    }
  }
}
