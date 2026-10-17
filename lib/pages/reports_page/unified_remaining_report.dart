import 'package:flutter/material.dart';
import '../../utils/database.dart';
import '../../utils/button_utils.dart';
import '../../utils/background_scaffold.dart';
import '../../utils/excel_export.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/snackbar_utils.dart';

class RemainingReportPage extends StatefulWidget {
  final DatabaseManager db;
  final int? archiveKeyId;

  const RemainingReportPage({
    super.key,
    required this.db,
    this.archiveKeyId,
  });

  @override
  State<RemainingReportPage> createState() => _RemainingReportPageState();
}

class _RemainingReportPageState extends State<RemainingReportPage> {
  final TextStyle textStyle = const TextStyle(fontSize: 15, fontFamily: 'Cairo');
  List<Map<String, dynamic>> remainingItems = [];
  List<Map<String, dynamic>> filteredItems = [];
  final TextEditingController searchController = TextEditingController();

  double totalRemaining = 0.0;
  bool _loading = true;

  String archiveName = '';
  String startDate = '';
  String endDate = '';

  bool get isArchived => widget.archiveKeyId != null;

  @override
  void initState() {
    super.initState();
    _fetchRemainingData();
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
        filteredItems = remainingItems;
      } else {
        filteredItems = remainingItems
            .where((item) =>
                (item['item_name']?.toString() ?? '').toLowerCase().contains(query))
            .toList();
      }
      totalRemaining = filteredItems.fold(
        0.0,
        (sum, item) => sum + Formatters.toDouble(item['total_price']),
      );
    });
  }

  Future<void> _fetchRemainingData() async {
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
          SELECT item_name, remaining, price, (price * remaining) as total_price
          FROM expenses_archive
          WHERE archive_key_id = ? AND remaining > 0
        ''';
        remainingItems = await widget.db.fetchAll(query, [widget.archiveKeyId]);
      } else {
        const query = '''
          SELECT item_name, remaining, price, (price * remaining) as total_price
          FROM expenses
          WHERE remaining > 0
        ''';
        remainingItems = await widget.db.fetchAll(query);
      }

      filteredItems = remainingItems;
      totalRemaining = filteredItems.fold(
        0.0,
        (sum, item) => sum + Formatters.toDouble(item['total_price']),
      );
    } catch (e) {
      if (mounted) {
        showAppSnackBar(context, 'خطأ أثناء جلب تقرير المتبقيات: $e', isError: true);
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _exportToExcel() async {
    try {
      if (filteredItems.isEmpty) {
        showAppSnackBar(context, 'لا توجد بيانات لتصديرها');
        return;
      }

      final columns = [
        'الصنف',
        'المتبقي',
        'سعر الوحدة',
        'السعر الإجمالي',
      ];

      final rows = filteredItems.map((row) => [
            row['item_name']?.toString() ?? '',
            Formatters.toDouble(row['remaining']),
            Formatters.toDouble(row['price']),
            Formatters.toDouble(row['total_price']),
          ]).toList();

      final extraInfo = <String, String>{
        'نوع التقرير': isArchived ? 'تقرير المتبقيات (مؤرشف)' : 'تقرير المتبقيات (الشهر الحالي)',
        'تاريخ التصدير': DateTime.now().toString().substring(0, 19),
      };

      if (isArchived && archiveName.isNotEmpty) {
        extraInfo['الأرشيف'] = archiveName;
        extraInfo['الفترة'] = '$startDate إلى $endDate';
      }

      final totals = [
        ['إجمالي المتبقيات', '', '', totalRemaining],
      ];

      final title = isArchived
          ? 'تقرير_المتبقيات_أرشيف_${widget.archiveKeyId}'
          : 'تقرير_المتبقيات_الشهر_الحالي';

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
      title: isArchived ? 'تقرير المتبقيات (مؤرشف)' : 'تقرير المتبقيات',
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

                    if (filteredItems.isEmpty)
                      const Padding(
                        padding: EdgeInsets.all(32.0),
                        child: Text(
                          'لا توجد أصناف متبقية!',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                      )
                    else
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: DataTable(
                          columnSpacing: 28,
                          headingRowColor: WidgetStateProperty.all(const Color(0xFF1E4C54)),
                          headingTextStyle: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontFamily: 'Cairo',
                          ),
                          columns: const [
                            DataColumn(label: Text('الصنف')),
                            DataColumn(label: Text('المتبقي')),
                            DataColumn(label: Text('سعر الوحدة')),
                            DataColumn(label: Text('السعر الإجمالي')),
                          ],
                          rows: filteredItems.map((row) {
                            final rem = Formatters.toDouble(row['remaining']);
                            final price = Formatters.toDouble(row['price']);
                            final totalPrice = Formatters.toDouble(row['total_price']);

                            return DataRow(
                              cells: [
                                DataCell(Text(row['item_name']?.toString() ?? '', style: textStyle)),
                                DataCell(Text(rem.toAppString(), style: textStyle)),
                                DataCell(Text(price.toAppString(), style: textStyle)),
                                DataCell(Text(totalPrice.toAppString(), style: textStyle)),
                              ],
                            );
                          }).toList(),
                        ),
                      ),
                    const SizedBox(height: 24),

                    // Summary
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: const [
                          BoxShadow(color: Colors.black12, blurRadius: 8, offset: Offset(0, 3)),
                        ],
                        border: Border.all(color: Colors.green.withValues(alpha: 0.3)),
                      ),
                      child: Column(
                        children: [
                          const Text('إجمالي قيمة المتبقيات',
                              style: TextStyle(fontSize: 14, color: Colors.black54)),
                          const SizedBox(height: 4),
                          Text(
                            '${totalRemaining.toAppString()} ج.م',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Colors.green[800],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

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
}
