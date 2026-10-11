import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import '../utils/database.dart';
import '../utils/button_utils.dart';
import '../utils/background_scaffold.dart';
import 'dart:io' as io;

class DatabasePage extends StatefulWidget {
  final DatabaseManager db;
  final VoidCallback navigateToMain;

  const DatabasePage({
    super.key,
    required this.db,
    required this.navigateToMain,
  });

  @override
  State<DatabasePage> createState() => _DatabasePageState();
}

class _DatabasePageState extends State<DatabasePage> {
  String? dbPath;

  @override
  void initState() {
    super.initState();
    if (!kIsWeb) {
      _initDbPath();
    }
  }

  Future<void> _initDbPath() async {
    if (kIsWeb) return;
    final databasesPath = await getDatabasesPath();
    setState(() {
      dbPath = join(databasesPath, 'expenses.db');
    });
  }

  Future<void> _exportDatabase() async {
    if (kIsWeb) {
      ScaffoldMessenger.of(this.context).showSnackBar(
        const SnackBar(content: Text('هذه الخاصية غير مدعومة على الويب')),
      );
      return;
    }
    
    if (dbPath == null) return;
    final dbFile = io.File(dbPath!);
    
    if (!await dbFile.exists()) {
      ScaffoldMessenger.of(this.context).showSnackBar(
        const SnackBar(content: Text('ملف قاعدة البيانات غير موجود!')),
      );
      return;
    }

    // إذا كان النظام ويندوز، استخدم Save As
    if (io.Platform.isWindows) {
      try {
        // اختيار مكان لحفظ الملف
        String? outputPath = await FilePicker.platform.saveFile(
          dialogTitle: 'حفظ قاعدة البيانات',
          fileName: 'expenses_backup.db',
          allowedExtensions: ['db'],
          type: FileType.custom,
        );
        
        if (outputPath != null) {
          // التأكد من إضافة الامتداد إذا لم يضفه المستخدم
          if (!outputPath.toLowerCase().endsWith('.db')) {
            outputPath += '.db';
          }
          
          // نسخ الملف إلى الموقع المختار
          await dbFile.copy(outputPath);
          
          ScaffoldMessenger.of(this.context).showSnackBar(
            SnackBar(content: Text('تم حفظ قاعدة البيانات في: $outputPath')),
          );
        }
      } catch (e) {
        ScaffoldMessenger.of(this.context).showSnackBar(
          SnackBar(content: Text('حدث خطأ أثناء الحفظ: $e')),
        );
      }
    } else {
      // للنظم الأخرى استخدم المشاركة العادية
      await Share.shareXFiles([XFile(dbFile.path)], text: 'قاعدة بيانات البرنامج');
    }
  }

  Future<void> _importDatabase() async {
    if (kIsWeb) {
      ScaffoldMessenger.of(this.context).showSnackBar(
        const SnackBar(content: Text('هذه الخاصية غير مدعومة على الويب')),
      );
      return;
    }

    try {
      // إظهار مؤشر تحميل
      showDialog(
        context: this.context,
        barrierDismissible: false,
        builder: (context) => const Center(child: CircularProgressIndicator()),
      );

      // التعديل الرئيسي: استخدام FileType.any مع التحقق من الامتداد لاحقاً
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.any,
        dialogTitle: 'اختر ملف قاعدة البيانات (يجب أن يكون بامتداد .db)',
        allowMultiple: false,
      ).catchError((error) {
        if (!mounted) return null;
        Navigator.pop(this.context);
        ScaffoldMessenger.of(this.context).showSnackBar(
          SnackBar(content: Text('حدث خطأ: $error')),
        );
        return null;
      });

      // إذا لم يتم اختيار ملف
      if (result == null || result.files.isEmpty) {
        Navigator.pop(this.context);
        return;
      }

      final pickedFile = result.files.first;
      if (pickedFile.path == null) {
        Navigator.pop(this.context);
        ScaffoldMessenger.of(this.context).showSnackBar(
          const SnackBar(content: Text('لم يتم تحديد مسار الملف!')),
        );
        return;
      }

      // التحقق من امتداد الملف
      if (!pickedFile.path!.toLowerCase().endsWith('.db')) {
        Navigator.pop(this.context);
        ScaffoldMessenger.of(this.context).showSnackBar(
          const SnackBar(content: Text('يجب اختيار ملف بامتداد .db فقط')),
        );
        return;
      }

      // تأكيد الاستيراد
      final confirm = await showDialog<bool>(
        context: this.context,
        builder: (context) => AlertDialog(
          title: const Text('تأكيد الاستيراد'),
          content: const Text('سيتم استبدال قاعدة البيانات الحالية. هل أنت متأكد؟'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('إلغاء'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('تأكيد'),
            ),
          ],
        ),
      );

      if (confirm != true) {
        Navigator.pop(this.context);
        return;
      }

      // إغلاق الاتصال الحالي
      await widget.db.closeConnection();

      // نسخ الملف الجديد
      final dbFile = io.File(dbPath!);
      final sourceFile = io.File(pickedFile.path!);
      await sourceFile.copy(dbFile.path);

      // إعادة فتح الاتصال
      await widget.db.reopenConnection();

      Navigator.pop(this.context);
      setState(() {});

      ScaffoldMessenger.of(this.context).showSnackBar(
        const SnackBar(content: Text('تم استيراد قاعدة البيانات بنجاح!')),
      );
    } catch (e) {
      Navigator.pop(this.context);
      ScaffoldMessenger.of(this.context).showSnackBar(
        SnackBar(content: Text('حدث خطأ أثناء الاستيراد: $e')),
      );
      
      // محاولة إعادة فتح الاتصال في حالة الخطأ
      try {
        await widget.db.reopenConnection();
      } catch (e) {
        ScaffoldMessenger.of(this.context).showSnackBar(
          SnackBar(content: Text('فشل في إعادة الاتصال بقاعدة البيانات: $e')),
        );
      }
    }
  }

  Future<void> _deleteDatabase() async {
    if (kIsWeb) {
      ScaffoldMessenger.of(this.context).showSnackBar(
        const SnackBar(content: Text('هذه الخاصية غير مدعومة على الويب')),
      );
      return;
    }

    final confirm = await showDialog<bool>(
      context: this.context,
      builder: (context) => AlertDialog(
        title: const Text('تأكيد الحذف'),
        content: const Text('هل أنت متأكد أنك تريد حذف قاعدة البيانات؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('لا'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('نعم'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      showDialog(
        context: this.context,
        barrierDismissible: false,
        builder: (context) => const Center(child: CircularProgressIndicator()),
      );

      await widget.db.initializeNewDatabase();

      Navigator.pop(this.context);
      setState(() {});

      ScaffoldMessenger.of(this.context).showSnackBar(
        const SnackBar(content: Text('تم حذف قاعدة البيانات وإنشاء قاعدة جديدة فارغة!')),
      );
    } catch (e) {
      Navigator.pop(this.context);
      ScaffoldMessenger.of(this.context).showSnackBar(
        SnackBar(content: Text('حدث خطأ أثناء الحذف: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final bool isPortrait = mediaQuery.orientation == Orientation.portrait;
    final double maxWidth = mediaQuery.size.width;
    final double buttonWidth = isPortrait ? maxWidth * 0.7 : maxWidth * 0.35;
    final double buttonHeight = isPortrait ? 55.0 : 65.0;
    final double spacing = isPortrait ? 24.0 : 32.0;

    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) {
        if (didPop) return;
        GoRouter.of(context).go('/main');
      },
      child: BackgroundScaffold(
        backgroundImagePath: 'assets/3.jpg',
        child: Stack(
          children: [
            Center(
              child: SingleChildScrollView(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const SizedBox(height: 40),
                    const Text(
                      'إدارة قاعدة البيانات',
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                        fontFamily: 'DancingScript',
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 60),
                    if (!kIsWeb)
                      Wrap(
                        alignment: WrapAlignment.center,
                        spacing: spacing,
                        runSpacing: spacing,
                        children: [
                          SizedBox(
                            width: buttonWidth,
                            height: buttonHeight,
                            child: createButton(
                              text: 'تصدير قاعدة البيانات',
                              icon: Icons.share,
                              onPressed: _exportDatabase,
                              bgColor: const Color.fromARGB(255, 2, 102, 233),
                            ),
                          ),
                          SizedBox(
                            width: buttonWidth,
                            height: buttonHeight,
                            child: createButton(
                              text: 'إضافة قاعدة بيانات',
                              icon: Icons.file_upload,
                              onPressed: _importDatabase,
                              bgColor: const Color.fromARGB(255, 241, 139, 6),
                            ),
                          ),
                          SizedBox(
                            width: buttonWidth,
                            height: buttonHeight,
                            child: createButton(
                              text: 'مسح قاعدة البيانات',
                              icon: Icons.delete,
                              onPressed: _deleteDatabase,
                              bgColor: const Color.fromARGB(255, 6, 136, 34),
                            ),
                          ),
                        ],
                      ),
                    if (kIsWeb)
                      Padding(
                        padding: const EdgeInsets.all(32.0),
                        child: Text(
                          'إدارة قاعدة البيانات غير متاحة على الويب.\nيرجى استخدام التطبيق على الموبايل أو الديسكتوب.',
                          style: TextStyle(
                            fontSize: 20,
                            color: Colors.red[700],
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    const SizedBox(height: 40),
                    createButton(
                      text: 'رجوع',
                      icon: Icons.arrow_back,
                      onPressed: () => GoRouter.of(context).go('/main'),
                      bgColor: const Color.fromARGB(255, 255, 4, 4),
                    ),
                  ],
                ),
              ),
            ),
            Positioned(
              top: 20,
              left: 20,
              child: createHomeButton(
                onPressed: widget.navigateToMain,
              ),
            ),
          ],
        ),
      ),
    );
  }
}