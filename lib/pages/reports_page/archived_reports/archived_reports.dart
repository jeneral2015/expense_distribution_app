import 'package:flutter/material.dart';
import '../../../utils/button_utils.dart';
import '../../../utils/database.dart';
import '../../../utils/background_scaffold.dart';
import '../../../core/utils/snackbar_utils.dart';
import 'archived_data.dart';
import '../unified_consumption_report.dart';

class ArchivedReportsPage extends StatefulWidget {
  final DatabaseManager db;

  const ArchivedReportsPage({
    super.key,
    required this.db,
  });

  @override
  State<ArchivedReportsPage> createState() => _ArchivedReportsPageState();
}

class _ArchivedReportsPageState extends State<ArchivedReportsPage> {
  String? _selectedArchive;
  List<Map<String, dynamic>> _archiveOptions = [];

  @override
  void initState() {
    super.initState();
    _loadArchivePeriods();
  }

  Future<void> _loadArchivePeriods() async {
    try {
      final rows = await widget.db.fetchAll('''
        SELECT archive_key_id, archive_name, start_date, end_date, archived_at
        FROM archive_keys
        ORDER BY archived_at DESC
      ''');
      setState(() {
        _archiveOptions = [
          {'archive_key_id': '', 'text': '--- اختر فترة الأرشيف ---'},
          ...rows.map((row) => {
                'archive_key_id': row['archive_key_id'].toString(),
                'text': 'ID: ${row['archive_key_id']} | من ${row['start_date']} إلى ${row['end_date']}',
              }),
        ];
        if (rows.isEmpty) {
          _archiveOptions = [
            {'archive_key_id': '', 'text': 'لا توجد فترات مؤرشفة'}
          ];
        }
        _selectedArchive = null;
      });
    } catch (e) {
      if (mounted) {
        showAppSnackBar(context, 'حدث خطأ في جلب فترات الأرشيف: $e', isError: true);
      }
    }
  }

  void _showReport() {
    if (_selectedArchive == null || _selectedArchive!.isEmpty) {
      showAppSnackBar(context, 'يرجى اختيار فترة أرشيف أولاً!');
      return;
    }

    final archiveKeyId = int.parse(_selectedArchive!);
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ConsumptionReportPage(
          db: widget.db,
          archiveKeyId: archiveKeyId,
        ),
      ),
    );
  }

  void _navigateToArchivedData() {
    if (_selectedArchive == null || _selectedArchive!.isEmpty) {
      showAppSnackBar(context, 'يرجى اختيار فترة أرشيف أولاً!');
      return;
    }

    final archiveKeyId = int.parse(_selectedArchive!);
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ArchivedDataPage(
          db: widget.db,
          archiveKeyId: archiveKeyId,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final double screenWidth = MediaQuery.of(context).size.width;
    final double buttonWidth = screenWidth < 600 ? screenWidth * 0.8 : 320;
    const double spacing = 16.0;

    return BackgroundScaffold(
      title: 'تقارير الأشهر السابقة',
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const Text(
                'اختر الفترة المؤرشفة المطلوبة',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'Cairo',
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),

              Container(
                width: buttonWidth,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade400),
                  boxShadow: const [
                    BoxShadow(color: Colors.black12, blurRadius: 6, offset: Offset(0, 2)),
                  ],
                ),
                child: DropdownButton<String>(
                  value: _selectedArchive,
                  hint: const Text('اختر من القائمة', style: TextStyle(fontFamily: 'Cairo')),
                  isExpanded: true,
                  underline: const SizedBox.shrink(),
                  items: _archiveOptions.map((option) {
                    return DropdownMenuItem<String>(
                      value: option['archive_key_id'],
                      enabled: option['archive_key_id'].isNotEmpty,
                      child: Text(
                        option['text'],
                        style: TextStyle(
                          fontFamily: 'Cairo',
                          fontSize: 13,
                          color: option['archive_key_id'].isEmpty ? Colors.grey : Colors.black,
                        ),
                      ),
                    );
                  }).toList(),
                  onChanged: (String? newValue) {
                    if (newValue != null && newValue.isNotEmpty) {
                      setState(() {
                        _selectedArchive = newValue;
                      });
                    }
                  },
                ),
              ),
              const SizedBox(height: 28),

              createButton(
                text: 'عرض تقرير الاستهلاك العام',
                onPressed: _showReport,
                bgColor: Colors.blue[700]!,
                textColor: Colors.white,
                width: buttonWidth,
                icon: Icons.bar_chart,
                iconColor: Colors.white,
              ),
              const SizedBox(height: spacing),

              createButton(
                text: 'عرض كافة سجلات الفترة',
                onPressed: _navigateToArchivedData,
                bgColor: Colors.green[700]!,
                textColor: Colors.white,
                width: buttonWidth,
                icon: Icons.folder_open,
                iconColor: Colors.white,
              ),
              const SizedBox(height: spacing * 2),

              createButton(
                text: 'رجوع',
                onPressed: () => Navigator.pop(context),
                bgColor: Colors.red[700]!,
                textColor: Colors.white,
                width: buttonWidth,
                icon: Icons.arrow_back,
                iconColor: Colors.white,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
