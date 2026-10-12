import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../utils/button_utils.dart';
import '../../../utils/database.dart';
import '../../../utils/background_scaffold.dart';
import '../../../utils/logger.dart';
import 'archived_data.dart';
import 'archived_consumption_report.dart';

class ArchivedReportsPage extends StatefulWidget {
  final DatabaseManager db;

  const ArchivedReportsPage({
    Key? key,
    required this.db,
  }) : super(key: key);

  @override
  _ArchivedReportsPageState createState() => _ArchivedReportsPageState();
}

class _ArchivedReportsPageState extends State<ArchivedReportsPage> {
  String? _selectedArchive;
  List<Map<String, dynamic>> _archiveOptions = [];
  bool _isLoading = false;

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
          {'archive_key_id': '', 'text': '--- اختر فترة ---'},
          ...rows.map((row) => {
                'archive_key_id': row['archive_key_id'].toString(),
                'text': 'ID: ${row['archive_key_id']} | ${row['end_date']}',
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
      _showSnackBar('حدث خطأ في جلب فترات الأرشيف: $e');
    }
  }

  Future<void> _showReport() async {
    if (_selectedArchive == null || _selectedArchive!.isEmpty) {
      _showSnackBar('اختار فترة أرشيف أولاً!');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final archiveKeyId = int.parse(_selectedArchive!);
      await ArchivedReportView.showReport(
        context: context,
        db: widget.db,
        archiveKeyId: archiveKeyId,
      );
    } catch (e) {
      _showSnackBar('حدث خطأ في جلب التقرير: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

void _navigateToArchivedData() {
  if (_selectedArchive == null || _selectedArchive!.isEmpty) {
    _showSnackBar('اختار فترة أرشيف أولاً!');
    return;
  }
  try {
    final archiveKeyId = int.parse(_selectedArchive!);
    AppLogger.logInfo('Navigating to ArchivedDataPage with archiveKeyId: $archiveKeyId'); // للتصحيح
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ArchivedDataPage(
          db: widget.db,
          archiveKeyId: archiveKeyId,
        ),
      ),
    );
  } catch (e) {
    AppLogger.logInfo('Navigation error: $e'); // للتصحيح
    _showSnackBar('خطأ في التنقل إلى بيانات الأرشيف: $e');
  }
}

  void _navigateToReports() {
    Navigator.pop(context);
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message, style: const TextStyle())),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BackgroundScaffold(
      backgroundImagePath: 'assets/3.jpg',
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: const Text('تقارير الأشهر السابقة'),
          backgroundColor: Colors.green[700],
          foregroundColor: Colors.white,
          leading: createButton(
            text: '🏠',
            onPressed: () => context.go('/main'),
            bgColor: Colors.green[700]!,
            textColor: Colors.white,
            width: 50,
            height: 50,
            icon: Icons.home,
            iconColor: Colors.white,
          ),
        ),
        body: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: LayoutBuilder(
              builder: (context, constraints) {
                double buttonWidth = constraints.maxWidth < 600
                    ? constraints.maxWidth * 0.8
                    : constraints.maxWidth * 0.25;
                double buttonHeight = constraints.maxWidth < 600 ? 48 : 56;
                double spacing = constraints.maxWidth < 600 ? 12 : 24;

                return Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const SizedBox(height: 20),
                    const Text(
                      'تقارير الأشهر السابقة',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        
                        color: Colors.black,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: 300,
                      child: DropdownButton<String>(
                        value: _selectedArchive,
                        hint: const Text('اختر من القائمة', style: TextStyle()),
                        isExpanded: true,
                        items: _archiveOptions.map((option) {
                          return DropdownMenuItem<String>(
                            value: option['archive_key_id'],
                            enabled: option['archive_key_id'].isNotEmpty,
                            child: Text(
                              option['text'],
                              style: TextStyle(
                                
                                color: option['archive_key_id'].isEmpty ? Colors.grey : Colors.black,
                              ),
                            ),
                          );
                        }).toList(),
                        onChanged: (value) {
                          setState(() {
                            _selectedArchive = value;
                          });
                        },
                      ),
                    ),
                    const SizedBox(height: 20),
                    if (_isLoading) const CircularProgressIndicator(),
                    const SizedBox(height: 20),
                    Wrap(
                      alignment: WrapAlignment.center,
                      spacing: spacing,
                      runSpacing: spacing,
                      children: [
                        SizedBox(
                          width: buttonWidth,
                          height: buttonHeight,
                          child: createButton(
                            text: 'عرض التقرير',
                            onPressed: _showReport,
                            bgColor: Colors.green[700]!,
                            textColor: Colors.white,
                            icon: Icons.visibility,
                            iconColor: Colors.white,
                          ),
                        ),
                        SizedBox(
                          width: buttonWidth,
                          height: buttonHeight,
                          child: createButton(
                            text: 'بيانات الأرشيف',
                            onPressed: _navigateToArchivedData,
                            bgColor: Colors.blue[700]!,
                            textColor: Colors.white,
                            icon: Icons.archive,
                            iconColor: Colors.white,
                          ),
                        ),
                        SizedBox(
                          width: buttonWidth,
                          height: buttonHeight,
                          child: createButton(
                            text: 'رجوع',
                            onPressed: _navigateToReports,
                            bgColor: Colors.red[700]!,
                            textColor: Colors.white,
                            icon: Icons.arrow_back,
                            iconColor: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class ArchivedReportView {
  static Future<void> showReport({
    required BuildContext context,
    required DatabaseManager db,
    required int archiveKeyId,
  }) async {
    try {
      // عرض التقرير باستخدام ArchivedConsumptionReport
      if (!context.mounted) return;

      Navigator.of(context, rootNavigator: true).push(
        MaterialPageRoute(
          builder: (context) => ArchivedConsumptionReport(
            db: db,
            archiveKeyId: archiveKeyId,
          ),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('حدث خطأ في عرض التقرير: $e')),
      );
    }
  }
}


