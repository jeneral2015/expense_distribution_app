import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

class ConsumptionReportUI {
  static Widget buildConsumptionReportView({
    required Map<String, dynamic> reportData,
    required TextStyle titleStyle,
    required String archiveName,
    required String startDate,
    required String endDate,
  }) {
    if (kDebugMode) {
      print('🔄 [DEBUG] Building ConsumptionReportUI');
    }
    if (kDebugMode) {
      print('📊 [DEBUG] Report data keys: ${reportData.keys.join(', ')}');
    }
    
    final summary = reportData['summaryData'] as List<dynamic>? ?? [];
    final totalMeals = reportData['totalMeals'] ?? 0.0;
    final totalDrinks = reportData['totalDrinks'] ?? 0.0;
    final totalMisc = reportData['totalMisc'] ?? 0.0;
    final totalConsumption = reportData['totalConsumption'] ?? 0.0;
    final totalContributions = reportData['totalContributions'] ?? 0.0;
    final totalRemainingItems = reportData['totalRemainingItems'] ?? 0.0;
    final totalRemainingCash = reportData['totalRemainingCash'] ?? 0.0;

    if (kDebugMode) {
      print('📈 [DEBUG] Summary data count: ${summary.length}');
    }
    if (kDebugMode) {
      print('🧮 [DEBUG] Totals - Meals: $totalMeals, Drinks: $totalDrinks, Misc: $totalMisc');
    }
    if (kDebugMode) {
      print('🧮 [DEBUG] Totals - Consumption: $totalConsumption, Contributions: $totalContributions');
    }
    if (kDebugMode) {
      print('🧮 [DEBUG] Totals - Remaining Items: $totalRemainingItems, Cash: $totalRemainingCash');
    }

    if (summary.isNotEmpty) {
      if (kDebugMode) {
        print('✅ [DEBUG] First summary item: ${summary.first}');
      }
    } else {
      if (kDebugMode) {
        print('⚠️ [DEBUG] Summary data is empty');
      }
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // --- عنوان الفترة والأرشيف ---
          Text(
            "الأرشيف: $archiveName\nالفترة: $startDate إلى $endDate",
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

          // --- الجدول الأفقي مع اتجاه RTL ---
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Directionality(
              textDirection: TextDirection.rtl,
              child: DataTable(
                columnSpacing: 30,
                border: TableBorder.all(width: 1.0, color: Colors.black),
                columns: [
                  DataColumn(label: _buildHeader('المسلسل')),
                  DataColumn(label: _buildHeader('الرتبة')),
                  DataColumn(label: _buildHeader('الاسم')),
                  DataColumn(label: _buildHeader('الوجبات')),
                  DataColumn(label: _buildHeader('المشروبات')),
                  DataColumn(label: _buildHeader('النثريات')),
                  DataColumn(label: _buildHeader('الاستهلاك')),
                  DataColumn(label: _buildHeader('المساهمات')),
                  DataColumn(label: _buildHeader('المتبقي')),
                ],
                rows: summary.asMap().entries.map((entry) {
                  final index = entry.key + 1;
                  final row = entry.value;
                  final double remaining = (row['remaining_cash'] as num?)?.toDouble() ?? 0.0;
                  
                  if (kDebugMode) {
                    print('📝 [DEBUG] Building row $index: $row');
                  }
                  
                  return DataRow(
                    cells: [
                      DataCell(_buildCellText(index.toString())),
                      DataCell(_buildCellText(row['rank']?.toString() ?? '')),
                      DataCell(_buildCellText(row['name']?.toString() ?? '')),
                      DataCell(_buildCellText(
                          (row['total_meals'] as num?)?.toStringAsFixed(2) ?? '0.00')),
                      DataCell(_buildCellText(
                          (row['total_drinks'] as num?)?.toStringAsFixed(2) ?? '0.00')),
                      DataCell(_buildCellText(
                          (row['total_miscellaneous'] as num?)?.toStringAsFixed(2) ?? '0.00')),
                      DataCell(_buildCellText(
                          (row['total_consumption'] as num?)?.toStringAsFixed(2) ?? '0.00')),
                      DataCell(_buildCellText(
                          (row['total_contribution'] as num?)?.toStringAsFixed(2) ?? '0.00')),
                      DataCell(_buildColoredText(
                          (row['remaining_cash'] as num?)?.toStringAsFixed(2) ?? '0.00', remaining)),
                    ],
                  );
                }).toList(),
              ),
            ),
          ),

          const SizedBox(height: 32),

          // --- عنوان الإجماليات ---
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
              width: 400,
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

  // --- دالة رأس العمود ---
  static Widget _buildHeader(String text) {
    if (kDebugMode) {
      print('📋 [DEBUG] Building header: $text');
    }
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

  // --- دالة خلية نصية ---
  static Widget _buildCellText(String text) {
    if (kDebugMode) {
      print('📝 [DEBUG] Building cell text: $text');
    }
    return Container(
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
      child: Text(
        text,
        style: const TextStyle(fontSize: 14),
        textAlign: TextAlign.center,
      ),
    );
  }

  // --- دالة نص بلون حسب القيمة ---
  static Widget _buildColoredText(String text, double value) {
    if (kDebugMode) {
      print('🎨 [DEBUG] Building colored text: $text (value: $value)');
    }
    final color = value >= 0 ? Colors.green : Colors.red;
    if (kDebugMode) {
      print('🎨 [DEBUG] Text color: $color');
    }
    
    return Container(
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.bold,
          fontSize: 14,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }

  // --- دالة صف الإجماليات ---
  static Widget _buildTotalRow(String label, double value) {
    if (kDebugMode) {
      print('🧮 [DEBUG] Building total row: $label = $value');
    }
    final color = value >= 0 ? Colors.green : Colors.red;
    if (kDebugMode) {
      print('🎨 [DEBUG] Total row color: $color');
    }
    
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
                color: color,
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