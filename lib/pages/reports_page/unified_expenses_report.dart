import 'package:flutter/material.dart';
import '../../utils/database.dart';
import '../../utils/button_utils.dart';
import '../../utils/background_scaffold.dart';
import '../../utils/excel_export.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/snackbar_utils.dart';

class ExpensesReportPage extends StatefulWidget {
  final DatabaseManager db;
  final int? archiveKeyId;

  const ExpensesReportPage({
    super.key,
    required this.db,
    this.archiveKeyId,
  });

  @override
  State<ExpensesReportPage> createState() => _ExpensesReportPageState();
}

class _ExpensesReportPageState extends State<ExpensesReportPage> {
  final TextStyle textStyle = const TextStyle(fontSize: 15, fontFamily: 'Cairo');
  final TextStyle titleStyle = const TextStyle(
    fontSize: 26,
    fontWeight: FontWeight.bold,
    fontFamily: 'Cairo',
  );

  List<Map<String, dynamic>> expenses = [];
  List<Map<String, dynamic>> filteredExpenses = [];
  final TextEditingController searchController = TextEditingController();

  double totalExpenses = 0.0;
  double totalConsumption = 0.0;
  bool _loading = true;

  String archiveName = '';
  String startDate = '';
  String endDate = '';

  bool get isArchived => widget.archiveKeyId != null;

  @override
  void initState() {
    super.initState();
    _fetchExpensesData();
    searchController.addListener(_applyFilter);
  }

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  void _applyFilter() {
    final query = searchController.text.trim().toLowerCase();
    setState(() {
      if (query.isEmpty) {
        filteredExpenses = expenses;
      } else {
        filteredExpenses = expenses
            .where((item) =>
                (item['item_name']?.toString() ?? '').toLowerCase().contains(query))
            .toList();
      }
      _calculateTotals();
    });
  }

  void _calculateTotals() {
    totalExpenses = filteredExpenses.fold(
      0.0,
      (sum, item) => sum + Formatters.toDouble(item['total_price']),
    );
    totalConsumption = filteredExpenses.fold(
      0.0,
      (sum, item) =>
          sum +
          (Formatters.toDouble(item['consumption']) *
              Formatters.toDouble(item['price'])),
    );
  }

  Future<void> _fetchExpensesData() async {
    setState(() => _loading = true);
    try {
      if (isArchived) {
        final archiveInfo = await widget.db.fetchAll(
          'SELECT archive_name, start_date, end_date FROM archive_keys WHERE archive_key_id = ?',
          [widget.archiveKeyId],
        );

        if (archiveInfo.isNotEmpty) {
          archiveName = archiveInfo[0]['archive_name'] as String? ?? '';
          startDate = archiveInfo[0]['start_date'] as String? ?? '';
          endDate = archiveInfo[0]['end_date'] as String? ?? '';
        }

        const query = '''
          SELECT item_name, quantity, price, (price * quantity) as total_price, COALESCE(consumption, 0) as consumption
          FROM expenses_archive
          WHERE archive_key_id = ?
        ''';
        expenses = await widget.db.fetchAll(query, [widget.archiveKeyId]);
      } else {
        const query = '''
          SELECT item_name, quantity, price, (price * quantity) as total_price, COALESCE(consumption, 0) as consumption
          FROM expenses
        ''';
        expenses = await widget.db.fetchAll(query);
      }

      filteredExpenses = expenses;
      _calculateTotals();
    } catch (e) {
      if (mounted) {
        showAppSnackBar(context, 'خطأ أثناء جلب تقرير المصروفات: $e', isError: true);
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _exportToExcel() async {
    try {
      if (filteredExpenses.isEmpty) {
        showAppSnackBar(context, 'لا توجد بيانات لتصديرها');
        return;
      }

      final columns = [
        'اسم الصنف',
        'الكمية',
        'سعر الوحدة',
        'السعر الكامل',
        'الاستهلاك',
      ];

      final rows = filteredExpenses.map((row) => [
            row['item_name']?.toString() ?? '',
            Formatters.toDouble(row['quantity']),
            Formatters.toDouble(row['price']),
            Formatters.toDouble(row['total_price']),
            Formatters.toDouble(row['consumption']),
          ]).toList();

      final extraInfo = <String, String>{
        'نوع التقرير': isArchived ? 'تقرير المصروفات (مؤرشف)' : 'تقرير المصروفات (الشهر الحالي)',
        'تاريخ التصدير': DateTime.now().toString().substring(0, 19),
      };

      if (isArchived && archiveName.isNotEmpty) {
        extraInfo['الأرشيف'] = archiveName;
        extraInfo['الفترة'] = '$startDate إلى $endDate';
      }

      final totals = [
        ['إجمالي المصروفات', '', '', totalExpenses, ''],
        ['إجمالي الاستهلاك', '', '', '', totalConsumption],
      ];

      final title = isArchived
          ? 'تقرير_المصروفات_أرشيف_${widget.archiveKeyId}'
          : 'تقرير_المصروفات_الشهر_الحالي';

      await exportReportToExcel(
        context: context,
        reportTitle: title,
        columns: columns,
        rows: rows,
        extraInfo: extraInfo,
        totals: totals,
      );
    } catch (e) {
      if (mounted) {
        showAppSnackBar(context, 'خطأ أثناء تصدير التقرير: $e', isError: true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return BackgroundScaffold(
      title: isArchived ? 'تقرير المصروفات (مؤرشف)' : 'تقرير المصروفات',
      child: _loading
          ? const Center(child: CircularProgressIndicator())
          : Directionality(
              textDirection: TextDirection.rtl,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    if (isArchived) ...[
                      Text(
                        'الأرشيف: $archiveName\nالفترة: $startDate إلى $endDate',
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 12),
                    ],

                    // Search box
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                      child: TextField(
                        controller: searchController,
                        decoration: InputDecoration(
                          hintText: 'بحث باسم الصنف...',
                          prefixIcon: const Icon(Icons.search),
                          suffixIcon: searchController.text.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear),
                                  onPressed: () => searchController.clear(),
                                )
                              : null,
                          filled: true,
                          fillColor: Colors.white,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Table
                    if (filteredExpenses.isEmpty)
                      const Padding(
                        padding: EdgeInsets.all(32.0),
                        child: Text(
                          'لا توجد بيانات مصروفات!',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                      )
                    else
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: DataTable(
                          columnSpacing: 24,
                          headingRowColor: WidgetStateProperty.all(const Color(0xFF1E4C54)),
                          headingTextStyle: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontFamily: 'Cairo',
                          ),
                          columns: const [
                            DataColumn(label: Text('اسم الصنف')),
                            DataColumn(label: Text('الكمية')),
                            DataColumn(label: Text('سعر الوحدة')),
                            DataColumn(label: Text('السعر الكامل')),
                            DataColumn(label: Text('الاستهلاك')),
                          ],
                          rows: filteredExpenses.map((row) {
                            final qty = Formatters.toDouble(row['quantity']);
                            final price = Formatters.toDouble(row['price']);
                            final totalPrice = Formatters.toDouble(row['total_price']);
                            final consumption = Formatters.toDouble(row['consumption']);

                            return DataRow(
                              cells: [
                                DataCell(Text(row['item_name']?.toString() ?? '', style: textStyle)),
                                DataCell(Text(qty.toAppString(), style: textStyle)),
                                DataCell(Text(price.toAppString(), style: textStyle)),
                                DataCell(Text(totalPrice.toAppString(), style: textStyle)),
                                DataCell(Text(consumption.toAppString(), style: textStyle)),
                              ],
                            );
                          }).toList(),
                        ),
                      ),
                    const SizedBox(height: 24),

                    // Summary Cards
                    Wrap(
                      spacing: 16,
                      runSpacing: 12,
                      alignment: WrapAlignment.center,
                      children: [
                        _buildSummaryCard(
                          title: 'إجمالي المصروفات',
                          value: '${totalExpenses.toAppString()} ج.م',
                          color: Colors.green[800]!,
                        ),
                        _buildSummaryCard(
                          title: 'إجمالي الاستهلاك',
                          value: '${totalConsumption.toAppString()} ج.م',
                          color: Colors.blue[800]!,
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // Action Buttons
                    Wrap(
                      spacing: 16,
                      runSpacing: 12,
                      alignment: WrapAlignment.center,
                      children: [
                        createButton(
                          text: 'تصدير إلى Excel',
                          onPressed: _exportToExcel,
                          bgColor: Colors.blue[700]!,
                          icon: Icons.download,
                          iconColor: Colors.white,
                          width: 200,
                        ),
                        createButton(
                          text: 'رجوع',
                          onPressed: () => Navigator.of(context).pop(),
                          bgColor: Colors.red[700]!,
                          icon: Icons.arrow_back,
                          iconColor: Colors.white,
                          width: 200,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildSummaryCard({
    required String title,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: const [
          BoxShadow(color: Colors.black12, blurRadius: 8, offset: Offset(0, 3)),
        ],
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          Text(title, style: const TextStyle(fontSize: 14, color: Colors.black54)),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color),
          ),
        ],
      ),
    );
  }
}
