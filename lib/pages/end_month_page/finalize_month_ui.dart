import 'package:flutter/material.dart';

class FinalizeMonthUI {
  static Widget buildReportView(Map<String, dynamic> reportData, TextStyle titleStyle) {
    final period = reportData['periodData'];
    final summary = reportData['summaryData'] as List<dynamic>? ?? [];
    final totalMeals = reportData['totalMeals'] ?? 0.0;
    final totalDrinks = reportData['totalDrinks'] ?? 0.0;
    final totalMisc = reportData['totalMisc'] ?? 0.0;
    final totalConsumption = reportData['totalConsumption'] ?? 0.0;
    final totalContributions = reportData['totalContributions'] ?? 0.0;
    final totalRemainingItems = reportData['totalRemainingItems'] ?? 0.0;
    final totalRemainingCash = reportData['totalRemainingCash'] ?? 0.0;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center, // ⬅️ المحاذاة العامة للوسطين
        children: [
          // --- الفترة ---
          if (period != null)
            Text(
              "الفترة: ${period['start_date']} إلى ${period['end_date']}\nتاريخ التقفيل: ${period['closure_date']}",
              style: titleStyle.copyWith(color: Colors.black),
              textAlign: TextAlign.center,
            ),
          const SizedBox(height: 24),

          // --- عنوان ملخص الأعضاء ---
          const Text(
            "ملخص الأعضاء:",
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),

          // --- الجدول ---
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              columnSpacing: 30, // مسافة مناسبة بين الأعمدة
              border: TableBorder.all(
                width: 1.0,
                color: Colors.black,
              ), // ✅ كل الحدود ظاهرة (أفقية + رأسية)
              columns: [
                DataColumn(
                  label: _buildHeader('الاسم'),
                ),
                DataColumn(
                  label: _buildHeader('الوجبات'),
                ),
                DataColumn(
                  label: _buildHeader('المشروبات'),
                ),
                DataColumn(
                  label: _buildHeader('النثريات'),
                ),
                DataColumn(
                  label: _buildHeader('الاستهلاك'),
                ),
                DataColumn(
                  label: _buildHeader('المساهمات'),
                ),
                DataColumn(
                  label: _buildHeader('المتبقي'),
                ),
              ],
              rows: summary.map((row) {
                final remaining = (row['remaining_cash'] as num).toDouble();
                return DataRow(
                  cells: [
                    DataCell(
                      _buildCellText(row['name'] ?? ''),
                    ),
                    DataCell(
                      _buildCellText(row['total_meals'].toStringAsFixed(2)),
                    ),
                    DataCell(
                      _buildCellText(row['total_drinks'].toStringAsFixed(2)),
                    ),
                    DataCell(
                      _buildCellText(row['total_miscellaneous'].toStringAsFixed(2)),
                    ),
                    DataCell(
                      _buildCellText(row['total_consumption'].toStringAsFixed(2)),
                    ),
                    DataCell(
                      _buildCellText(row['total_contribution'].toStringAsFixed(2)),
                    ),
                    DataCell(
                      _buildColoredText(
                        row['remaining_cash'].toStringAsFixed(2),
                        remaining,
                      ),
                    ),
                  ],
                );
              }).toList(),
            ),
          ),

          const SizedBox(height: 32),

          // --- إجماليات الشهر ---
          const Text(
            "إجماليات الشهر:",
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),

          // --- كارت الإجماليات ---
          Card(
            elevation: 4,
            child: SizedBox(
              width: 400, // عرض ثابت للكارت
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    _buildTotalRow("إجمالي الوجبات", totalMeals),
                    _buildTotalRow("إجمالي المشروبات", totalDrinks),
                    _buildTotalRow("إجمالي النثريات", totalMisc),
                    _buildTotalRow("إجمالي الاستهلاك", totalConsumption),
                    _buildTotalRow("إجمالي المساهمات", totalContributions),
                    _buildTotalRow("إجمالي المتبقيات", totalRemainingItems),
                    _buildTotalRow("النقدي المتبقي", totalRemainingCash),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --- دالة لإنشاء نص الرأس بالمحاذاة ---
  static Widget _buildHeader(String text) {
    return Container(
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      child: Text(
        text,
        style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black),
        textAlign: TextAlign.center,
      ),
    );
  }

  // --- دالة لإنشاء خلية نصية بالمحاذاة ---
  static Widget _buildCellText(String text) {
    return Container(
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
      child: Text(
        text,
        style: const TextStyle(fontSize: 14, color: Colors.black),
        textAlign: TextAlign.center,
      ),
    );
  }

  // --- دالة لإنشاء نص بلون حسب القيمة ---
  static Widget _buildColoredText(String text, double value) {
    return Container(
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
      child: Text(
        text,
        style: TextStyle(
          color: value >= 0 ? Colors.green : Colors.red,
          fontWeight: FontWeight.bold,
          fontSize: 14,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }

  // --- دالة لصف الإجماليات ---
  static Widget _buildTotalRow(String label, double value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black),
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 20),
          Container(
            width: 100,
            alignment: Alignment.center,
            child: Text(
              value.toStringAsFixed(2),
              style: TextStyle(
                color: value >= 0 ? Colors.green : Colors.red,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }
}