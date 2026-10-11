import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../utils/button_utils.dart';
import '../utils/database.dart';
import '../utils/background_scaffold.dart';
import '../utils/logger.dart';

class ShowSubscribersPage extends StatefulWidget {
  final DatabaseManager db;
  final VoidCallback navigateToView;
  final String backgroundImagePath;

  const ShowSubscribersPage({
    Key? key,
    required this.db,
    required this.navigateToView,
    required this.backgroundImagePath,
  }) : super(key: key);

  @override
  _ShowSubscribersPageState createState() => _ShowSubscribersPageState();
}

class _ShowSubscribersPageState extends State<ShowSubscribersPage> with WidgetsBindingObserver {
  List<Map<String, dynamic>> _rows = [];
  Map<String, dynamic>? _selectedRow;
  int? _selectedMemberId;
  Set<int> _selectedMembersForDeletion = {};
  final TextEditingController _rankController = TextEditingController();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _contributionController = TextEditingController();
  final TextEditingController _totalDueController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _initializeAndFetchData();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    _rankController.dispose();
    _nameController.dispose();
    _contributionController.dispose();
    _totalDueController.dispose();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.resumed) {
      _fetchMembersData();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _fetchMembersData();
  }

  Future<void> _initializeAndFetchData() async {
    try {
      await widget.db.initializeDatabase();
      AppLogger.logInfo('Database initialized successfully');
      await _fetchMembersData();
    } catch (e) {
      AppLogger.logError('Error initializing database: $e');
      _showSnackBar('خطأ في تهيئة قاعدة البيانات: $e');
    }
  }

  Future<void> _fetchMembersData() async {
    try {
      if (widget.db.database == null) {
        AppLogger.logError('Database is not initialized');
        _showSnackBar('قاعدة البيانات غير مهيأة');
        return;
      }

      // استعلام SQL مع ترتيب حسب الرتبة
      final results = await widget.db.fetchAll('''
        SELECT member_id, rank, name, contribution, total_due 
        FROM members 
        ORDER BY CASE rank
          WHEN 'لواء' THEN 0
          WHEN 'عميد' THEN 1
          WHEN 'عقيد' THEN 2
          WHEN 'مقدم' THEN 3
          WHEN 'رائد' THEN 4
          WHEN 'نقيب' THEN 5
          WHEN 'ملازم أول' THEN 6
          WHEN 'ملازم' THEN 7
          ELSE 999
        END
      ''');

      setState(() {
        _rows = results;
      });
      AppLogger.logInfo('Fetched ${_rows.length} members');
    } catch (e) {
      AppLogger.logError('Error fetching members: $e');
      _showSnackBar('حدث خطأ أثناء جلب البيانات: $e');
    }
  }

  void _selectRowForEdit(Map<String, dynamic>? row) {
    setState(() {
      final rowId = row?['member_id'];
      if (_selectedMemberId == rowId) {
        _selectedRow = null;
        _selectedMemberId = null;
      } else {
        _selectedRow = row;
        _selectedMemberId = rowId;
        if (rowId != null) {
          _selectedMembersForDeletion.add(rowId);
        }
      }
      AppLogger.logInfo('Selected Member ID for Edit: $_selectedMemberId');
    });
  }

  void _toggleMemberForDeletion(int memberId) {
    setState(() {
      if (_selectedMembersForDeletion.contains(memberId)) {
        _selectedMembersForDeletion.remove(memberId);
        if (_selectedMemberId == memberId) {
          _selectedRow = null;
          _selectedMemberId = null;
        }
      } else {
        _selectedMembersForDeletion.add(memberId);
        _selectedRow = null;
        _selectedMemberId = null;
      }
      AppLogger.logInfo('Selected Members for Deletion: $_selectedMembersForDeletion');
    });
  }

  void _editMember() {
    if (_selectedMembersForDeletion.length > 1) {
      _showSnackBar('الرجاء اختيار مشترك واحد فقط للتعديل.');
      return;
    }

    if (_selectedMembersForDeletion.length == 1) {
      final memberId = _selectedMembersForDeletion.first;
      final member = _rows.firstWhere((row) => row['member_id'] == memberId, orElse: () => {});
      if (member.isNotEmpty) {
        _selectRowForEdit(member);
        _openEditDialog();
        return;
      }
    }

    if (_selectedRow == null) {
      _showSnackBar('يرجى اختيار مشترك للتعديل.');
      return;
    }

    _openEditDialog();
  }

  void _openEditDialog() {
    _rankController.text = _selectedRow!['rank']?.toString() ?? '';
    _nameController.text = _selectedRow!['name']?.toString() ?? '';
    _contributionController.text = _selectedRow!['contribution']?.toString() ?? '0';
    _totalDueController.text = _selectedRow!['total_due']?.toString() ?? '0';

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text(
          'تعديل بيانات المشترك',
          textDirection: TextDirection.rtl,
          style: TextStyle(fontFamily: 'Lalezar'),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _rankController,
                decoration: const InputDecoration(
                  labelText: 'الرتبة',
                  labelStyle: TextStyle(fontFamily: 'Lalezar'),
                  border: OutlineInputBorder(),
                ),
                textDirection: TextDirection.rtl,
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'الاسم',
                  labelStyle: TextStyle(fontFamily: 'Lalezar'),
                  border: OutlineInputBorder(),
                ),
                textDirection: TextDirection.rtl,
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _contributionController,
                decoration: const InputDecoration(
                  labelText: 'مبلغ المساهمة',
                  labelStyle: TextStyle(fontFamily: 'Lalezar'),
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
                textDirection: TextDirection.rtl,
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _totalDueController,
                decoration: InputDecoration(
                  labelText: 'المبلغ المستحق',
                  labelStyle: const TextStyle(fontFamily: 'Lalezar'),
                  border: const OutlineInputBorder(),
                  filled: true,
                  fillColor: Colors.grey[200],
                ),
                keyboardType: TextInputType.number,
                textDirection: TextDirection.rtl,
                readOnly: true,
                enabled: false,
              ),
            ],
          ),
        ),
        actions: [
          createButton(
            text: 'حفظ',
            onPressed: () => _saveEdit(_selectedMemberId!),
            bgColor: Colors.green[700]!,
            width: 100,
            height: 40,
          ),
          createButton(
            text: 'إلغاء',
            onPressed: () => Navigator.of(context).pop(),
            bgColor: Colors.red[700]!,
            width: 100,
            height: 40,
          ),
        ],
        actionsAlignment: MainAxisAlignment.center,
      ),
    ).then((_) {
      setState(() {});
    });
  }

  void _saveEdit(int memberId) async {
    try {
      final rank = _rankController.text.trim();
      final name = _nameController.text.trim();
      final contribution = double.tryParse(_contributionController.text) ?? 0;

      if (rank.isEmpty || name.isEmpty || contribution < 0) {
        _showSnackBar('يرجى ملء جميع الحقول بشكل صحيح.');
        return;
      }

      if (widget.db.database == null) {
        AppLogger.logError('Database is not initialized for update');
        _showSnackBar('قاعدة البيانات غير مهيأة');
        return;
      }

      await widget.db.database!.update(
        'members',
        {
          'rank': rank,
          'name': name,
          'contribution': contribution,
        },
        where: 'member_id = ?',
        whereArgs: [memberId],
      );

      _showSnackBar('تم تعديل البيانات بنجاح!');
      Navigator.of(context).pop();
      _selectedRow = null;
      _selectedMemberId = null;
      await _fetchMembersData();
    } catch (e) {
      AppLogger.logError('Error updating member: $e');
      _showSnackBar('حدث خطأ أثناء تعديل البيانات: $e');
    }
  }

  void _deleteMember() {
    if (_selectedMembersForDeletion.isEmpty && _selectedRow == null) {
      _showSnackBar('يرجى اختيار مشترك للحذف.');
      return;
    }

    final membersToDelete = _selectedMembersForDeletion.isNotEmpty
        ? _selectedMembersForDeletion
        : {_selectedMemberId!};

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text(
          'تأكيد الحذف',
          textDirection: TextDirection.rtl,
          style: TextStyle(fontFamily: 'Lalezar'),
        ),
        content: Text(
          membersToDelete.length > 1
              ? 'هل أنت متأكد أنك تريد حذف ${membersToDelete.length} مشتركين؟'
              : 'هل أنت متأكد أنك تريد حذف هذا المشترك؟',
          textDirection: TextDirection.rtl,
          style: const TextStyle(fontFamily: 'Lalezar'),
        ),
        actions: [
          createButton(
            text: 'نعم',
            onPressed: () => _confirmDeleteMultiple(membersToDelete),
            bgColor: Colors.green[700]!,
            width: 100,
            height: 40,
          ),
          createButton(
            text: 'لا',
            onPressed: () => Navigator.of(context).pop(),
            bgColor: Colors.red[700]!,
            width: 100,
            height: 40,
          ),
        ],
        actionsAlignment: MainAxisAlignment.center,
      ),
    );
  }

  void _confirmDeleteMultiple(Set<int> memberIds) async {
    try {
      if (widget.db.database == null) {
        AppLogger.logError('Database is not initialized for deletion');
        _showSnackBar('قاعدة البيانات غير مهيأة');
        return;
      }

      for (final memberId in memberIds) {
        await widget.db.database!.delete(
          'members',
          where: 'member_id = ?',
          whereArgs: [memberId],
        );
      }

      _showSnackBar('تم حذف ${memberIds.length} مشترك بنجاح!');
      Navigator.of(context).pop();
      _selectedRow = null;
      _selectedMemberId = null;
      _selectedMembersForDeletion.clear();
      await _fetchMembersData();
    } catch (e) {
      AppLogger.logError('Error deleting members: $e');
      _showSnackBar('حدث خطأ أثناء الحذف: $e');
    }
  }

  void _handleBack() {
    _selectedRow = null;
    _selectedMemberId = null;
    widget.navigateToView();
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message, textDirection: TextDirection.rtl)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isPortrait = MediaQuery.of(context).orientation == Orientation.portrait;
    final double buttonWidth = isPortrait
        ? MediaQuery.of(context).size.width * 0.5
        : MediaQuery.of(context).size.width * 0.25;
    const double buttonHeight = 60.0;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (bool didPop, dynamic result) {
        if (didPop) return;
        _handleBack();
      },
      child: BackgroundScaffold(
        backgroundImagePath: widget.backgroundImagePath,
        child: Stack(
          children: [
            Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text(
                      'عرض بيانات المشتركين',
                      style: TextStyle(
                        fontSize: 25,
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                        fontFamily: 'DancingScript',
                      ),
                      textDirection: TextDirection.rtl,
                    ),
                    const SizedBox(height: 10),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: DataTable(
                        border: TableBorder.all(color: Colors.black, width: 1),
                        dividerThickness: 1,
                        decoration: const BoxDecoration(color: Colors.white),
                        columns: [
                          DataColumn(
                            label: Checkbox(
                              value: _selectedMembersForDeletion.length == _rows.length && _rows.isNotEmpty,
                              onChanged: (value) {
                                if (value == true) {
                                  setState(() {
                                    _selectedMembersForDeletion = Set.from(_rows.map((row) => row['member_id'] as int));
                                    _selectedRow = null;
                                    _selectedMemberId = null;
                                  });
                                } else {
                                  setState(() {
                                    _selectedMembersForDeletion.clear();
                                  });
                                }
                              },
                            ),
                          ),
                          const DataColumn(label: Text('مسلسل', style: TextStyle(fontFamily: 'Lalezar'))),
                          const DataColumn(label: Text('الرتبة', style: TextStyle(fontFamily: 'Lalezar'))),
                          const DataColumn(label: Text('الاسم', style: TextStyle(fontFamily: 'Lalezar'))),
                          const DataColumn(label: Text('مبلغ المساهمة', style: TextStyle(fontFamily: 'Lalezar'))),
                          const DataColumn(label: Text('المبلغ المستحق', style: TextStyle(fontFamily: 'Lalezar'))),
                        ],
                        rows: _rows.asMap().entries.map((entry) {
                          final index = entry.key;
                          final row = entry.value;
                          final memberId = row['member_id'] as int;
                          final isSelectedForEdit = _selectedMemberId == memberId;
                          final isSelectedForDeletion = _selectedMembersForDeletion.contains(memberId);

                          return DataRow(
                            color: MaterialStateProperty.resolveWith<Color?>(
                              (Set<MaterialState> states) {
                                if (isSelectedForEdit) {
                                  return Colors.yellow;
                                } else if (isSelectedForDeletion) {
                                  return Colors.red.withOpacity(0.3);
                                }
                                return null;
                              },
                            ),
                            cells: [
                              DataCell(
                                Checkbox(
                                  value: isSelectedForDeletion,
                                  onChanged: (value) {
                                    _toggleMemberForDeletion(memberId);
                                  },
                                ),
                              ),
                              DataCell(Text((index + 1).toString())),
                              DataCell(Text(row['rank']?.toString() ?? '')),
                              DataCell(Text(row['name']?.toString() ?? '')),
                              DataCell(Text(row['contribution']?.toStringAsFixed(0) ?? '0')),
                              DataCell(Text(row['total_due']?.toStringAsFixed(2) ?? '0.00')),
                            ],
                          );
                        }).toList(),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        createButton(
                          text: 'تعديل',
                          onPressed: _editMember,
                          bgColor: Colors.amber[700]!,
                          width: buttonWidth / 3,
                          height: buttonHeight,
                        ),
                        const SizedBox(width: 20),
                        createButton(
                          text: 'حذف',
                          onPressed: _deleteMember,
                          bgColor: Colors.red[700]!,
                          width: buttonWidth / 3,
                          height: buttonHeight,
                        ),
                        const SizedBox(width: 20),
                        createButton(
                          text: 'رجوع',
                          onPressed: _handleBack,
                          bgColor: Colors.red[700]!,
                          width: buttonWidth / 3,
                          height: buttonHeight,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            Positioned(
              top: 20,
              left: 20,
              child: createHomeButton(
                onPressed: () => context.go('/main'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}