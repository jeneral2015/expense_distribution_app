import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';
import 'package:go_router/go_router.dart';
import '../utils/button_utils.dart';
import '../utils/database.dart';
import '../utils/background_scaffold.dart';
import '../utils/logger.dart';

class InputSubscribersPage extends StatefulWidget {
  final DatabaseManager db;
  final VoidCallback navigateToInput;
  final String backgroundImagePath;

  const InputSubscribersPage({
    Key? key,
    required this.db,
    required this.navigateToInput,
    required this.backgroundImagePath,
  }) : super(key: key);

  @override
  _InputSubscribersPageState createState() => _InputSubscribersPageState();
}

class _InputSubscribersPageState extends State<InputSubscribersPage> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _contributionController = TextEditingController();
  String? _selectedRank;
  List<String> _similarNames = [];

  final List<String> _ranks = [
    'عميد',
    'عقيد',
    'مقدم',
    'رائد',
    'نقيب',
    'ملازم أول',
    'ملازم',
  ];

  @override
  void initState() {
    super.initState();
    widget.db.initializeDatabase();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _contributionController.dispose();
    super.dispose();
  }

  void _searchSimilarNames(String query) async {
    if (query.trim().isEmpty) {
      setState(() {
        _similarNames = [];
      });
      return;
    }
    final results = await widget.db.fetchAll(
      'SELECT name FROM members WHERE LOWER(name) LIKE ?',
      ['%${query.trim().toLowerCase()}%'],
    );
    AppLogger.logInfo('Similar names found for query "$query": $results'); // للتصحيح
    setState(() {
      _similarNames = results.map((row) => row['name'] as String).toList();
    });
  }

  void _selectSimilarName(String name) {
    setState(() {
      _nameController.text = name;
      _similarNames = [];
    });
    _showSnackBar('تم اختيار الاسم: $name');
  }

  void _saveMember() async {
    final rank = _selectedRank;
    final name = _nameController.text.trim();
    final contribution = _contributionController.text.trim();

    AppLogger.logInfo('Saving member: rank=$rank, name=$name, contribution=$contribution'); // للتصحيح
    if (rank == null || name.isEmpty || contribution.isEmpty) {
      AppLogger.logInfo('Missing required fields'); // للتصحيح
      _showSnackBar('يرجى ملء جميع الحقول بشكل صحيح.');
      return;
    }

    try {
      final contributionValue = double.parse(contribution);
      if (contributionValue < 0) {
        AppLogger.logInfo('Invalid contribution value'); // للتصحيح
        _showSnackBar('مبلغ المساهمة يجب أن يكون رقمًا موجبًا.');
        return;
      }

      final result = await widget.db.database!.rawQuery(
        'SELECT COUNT(*) FROM members WHERE name = ?',
        [name],
      );
      if (result[0]['COUNT(*)'] as int > 0) {
        AppLogger.logInfo('Name already exists: $name'); // للتصحيح
        _showSnackBar('هذا الاسم موجود بالفعل!');
        return;
      }

      final currentDate = DateTime.now().toIso8601String().split('T')[0];
      await widget.db.database!.insert(
        'members',
        {
          'rank': rank,
          'name': name,
          'contribution': contributionValue,
          'date': currentDate,
          'total_due': 0.0,
        },
        conflictAlgorithm: ConflictAlgorithm.rollback,
      );
      AppLogger.logInfo('Inserted new member: $name'); // للتصحيح
      _resetForm();
      _showSnackBar('تم حفظ البيانات بنجاح!');
    } catch (e) {
      AppLogger.logError('Error saving member: $e'); // للتصحيح
      if (e is FormatException) {
        _showSnackBar('مبلغ المساهمة يجب أن يكون رقمًا.');
      } else {
        _showSnackBar('حدث خطأ أثناء حفظ البيانات: $e');
      }
    }
  }

  void _resetForm() {
    setState(() {
      _selectedRank = null;
      _nameController.clear();
      _similarNames = [];
      _contributionController.clear();
    });
  }

  void _handleBack() {
    _resetForm();
    widget.navigateToInput();
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
      onPopInvoked: (didPop) {
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
                      'إدخال بيانات المشتركين',
                      style: TextStyle(
                        fontSize: 25,
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                        fontFamily: 'DancingScript',
                      ),
                      textDirection: TextDirection.rtl,
                    ),
                    const SizedBox(height: 20),
                    DropdownButtonFormField<String>(
                      decoration: InputDecoration(
                        labelText: 'الرتبة',
                        labelStyle: const TextStyle(color: Colors.white, fontFamily: 'Lalezar'),
                        filled: true,
                        fillColor: Colors.black.withOpacity(0.7),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      value: _selectedRank,
                      hint: const Text(
                        'الرتبة',
                        textDirection: TextDirection.rtl,
                        style: TextStyle(color: Colors.white, fontFamily: 'Lalezar'),
                      ),
                      items: _ranks.map((rank) {
                        return DropdownMenuItem(
                          value: rank,
                          child: Text(
                            rank,
                            textDirection: TextDirection.rtl,
                            style: const TextStyle(color: Colors.white, fontFamily: 'Lalezar'),
                          ),
                        );
                      }).toList(),
                      onChanged: (value) {
                        setState(() {
                          _selectedRank = value;
                        });
                      },
                      style: const TextStyle(color: Colors.white, fontFamily: 'Lalezar'),
                      dropdownColor: Colors.black.withOpacity(0.7),
                      selectedItemBuilder: (BuildContext context) {
                        return _ranks.map((String rank) {
                          return Text(
                            rank,
                            style: const TextStyle(color: Colors.white, fontFamily: 'Lalezar'),
                            textDirection: TextDirection.rtl,
                          );
                        }).toList();
                      },
                    ),
                    const SizedBox(height: 20),
                    TextField(
                      controller: _nameController,
                      decoration: InputDecoration(
                        labelText: 'اسم المشترك',
                        labelStyle: const TextStyle(color: Colors.white, fontFamily: 'Lalezar'),
                        filled: true,
                        fillColor: Colors.black.withOpacity(0.7),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      style: const TextStyle(color: Colors.white, fontFamily: 'Lalezar'),
                      textDirection: TextDirection.rtl,
                      onChanged: _searchSimilarNames,
                    ),
                    if (_similarNames.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Container(
                        height: 100,
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.7),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: ListView.builder(
                          itemCount: _similarNames.length,
                          itemBuilder: (context, index) {
                            final name = _similarNames[index];
                            return ListTile(
                              title: Text(
                                name,
                                style: const TextStyle(color: Colors.white, fontFamily: 'Lalezar'),
                                textDirection: TextDirection.rtl,
                              ),
                              onTap: () => _selectSimilarName(name),
                            );
                          },
                        ),
                      ),
                    ],
                    const SizedBox(height: 20),
                    TextField(
                      controller: _contributionController,
                      decoration: InputDecoration(
                        labelText: 'مبلغ المساهمة',
                        labelStyle: const TextStyle(color: Colors.white, fontFamily: 'Lalezar'),
                        filled: true,
                        fillColor: Colors.black.withOpacity(0.7),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      style: const TextStyle(color: Colors.white, fontFamily: 'Lalezar'),
                      keyboardType: TextInputType.number,
                      textDirection: TextDirection.rtl,
                    ),
                    const SizedBox(height: 20),
                    createButton(
                      text: 'حفظ',
                      onPressed: _saveMember,
                      bgColor: Colors.green[700]!,
                      width: buttonWidth,
                      height: buttonHeight,
                    ),
                    const SizedBox(height: 20),
                    createButton(
                      text: 'رجوع',
                      onPressed: _handleBack,
                      bgColor: Colors.red[700]!,
                      width: buttonWidth,
                      height: buttonHeight,
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