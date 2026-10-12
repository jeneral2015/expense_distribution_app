import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:go_router/go_router.dart';
import 'package:file_picker/file_picker.dart';
import '../firebase_options.dart';
import '../services/auth_service.dart';
import '../services/sync_service.dart';
import '../utils/database.dart';
import '../utils/button_utils.dart';
import '../utils/background_scaffold.dart';
import '../utils/file_downloader.dart';
import 'dart:io' as io;

class DatabasePage extends StatefulWidget {
  final DatabaseManager db;
  final AuthService auth;
  final SyncService sync;
  final VoidCallback navigateToMain;

  const DatabasePage({
    super.key,
    required this.db,
    required this.auth,
    required this.sync,
    required this.navigateToMain,
  });

  @override
  State<DatabasePage> createState() => _DatabasePageState();
}

class _DatabasePageState extends State<DatabasePage> {
  String? dbPath;
  bool _syncBusy = false;

  @override
  void initState() {
    super.initState();
    if (!kIsWeb) {
      _initDbPath();
    }
  }

  Future<void> _initDbPath() async {
    if (kIsWeb) return;
    final path = await widget.db.databasePath();
    setState(() {
      dbPath = path;
    });
  }

  Future<void> _runCloudSync(Future<void> Function(String uid) action) async {
    if (!DefaultFirebaseOptions.isConfigured) {
      _snack('يرجى إعداد Firebase أولاً (flutterfire configure)');
      return;
    }
    final uid = widget.auth.userId;
    if (uid == null) {
      _snack('سجّل الدخول لتفعيل المزامنة');
      return;
    }
    setState(() => _syncBusy = true);
    try {
      await action(uid);
      _snack('تمت المزامنة بنجاح');
    } catch (e) {
      _snack('فشلت المزامنة: $e');
    } finally {
      if (mounted) setState(() => _syncBusy = false);
    }
  }

  Future<void> _confirmAndUploadCloud() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('تأكيد الرفع إلى السحابة', style: TextStyle(fontWeight: FontWeight.bold)),
          content: const Text(
            'هل أنت متأكد أنك تريد رفع قاعدة البيانات إلى السحابة؟\nسيؤدي هذا إلى استبدال البيانات السحابية الحالية بالبيانات المحلية.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('إلغاء'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF2563EB),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: () => Navigator.pop(context, true),
              child: const Text('تأكيد الرفع'),
            ),
          ],
        ),
      ),
    );

    if (confirm == true && mounted) {
      await _runCloudSync((uid) => widget.sync.uploadLocal(uid, widget.db));
    }
  }

  Future<void> _confirmAndDownloadCloud() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('تأكيد التنزيل من السحابة', style: TextStyle(fontWeight: FontWeight.bold)),
          content: const Text(
            'هل أنت متأكد أنك تريد تنزيل البيانات من السحابة؟\nسيؤدي هذا إلى استبدال قاعدة البيانات المحلية الحالية بالنسخة السحابية.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('إلغاء'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF7C3AED),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: () => Navigator.pop(context, true),
              child: const Text('تأكيد التنزيل'),
            ),
          ],
        ),
      ),
    );

    if (confirm == true && mounted) {
      await _runCloudSync((uid) => widget.sync.downloadToLocal(uid, widget.db));
    }
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _exportDatabase() async {
    try {
      final bytes = await widget.db.exportDatabaseBytes();
      await downloadOrSaveFile('expenses_backup.db', bytes);
      _snack('تم تصدير قاعدة البيانات بنجاح');
    } catch (e) {
      _snack('حدث خطأ أثناء تصدير قاعدة البيانات: $e');
    }
  }

  Future<void> _importDatabase() async {
    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(child: CircularProgressIndicator()),
      );

      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.any,
        dialogTitle: 'اختر ملف قاعدة البيانات (يجب أن يكون بامتداد .db)',
        allowMultiple: false,
        withData: true,
      ).catchError((error) {
        if (!mounted) return null;
        Navigator.pop(context);
        _snack('حدث خطأ: $error');
        return null;
      });

      if (result == null || result.files.isEmpty) {
        Navigator.pop(context);
        return;
      }

      final pickedFile = result.files.first;
      
      if (!pickedFile.name.toLowerCase().endsWith('.db')) {
        Navigator.pop(context);
        _snack('يجب اختيار ملف بامتداد .db فقط');
        return;
      }

      final bytes = pickedFile.bytes ?? (pickedFile.path != null ? await io.File(pickedFile.path!).readAsBytes() : null);
      if (bytes == null) {
        Navigator.pop(context);
        _snack('لم نتمكن من قراءة محتوى الملف');
        return;
      }

      final confirm = await showDialog<bool>(
        context: context,
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
        Navigator.pop(context);
        return;
      }

      await widget.db.importDatabaseBytes(bytes);

      Navigator.pop(context);
      setState(() {});
      _snack('تم استيراد قاعدة البيانات بنجاح!');
    } catch (e) {
      Navigator.pop(context);
      _snack('حدث خطأ أثناء الاستيراد: $e');
      try {
        await widget.db.reopenConnection();
      } catch (e2) {
        _snack('فشل في إعادة الاتصال بقاعدة البيانات: $e2');
      }
    }
  }

  Future<void> _deleteDatabase() async {
    if (kIsWeb) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('هذه الخاصية غير مدعومة على الويب')),
      );
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
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
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(child: CircularProgressIndicator()),
      );

      await widget.db.initializeNewDatabase();

      Navigator.pop(context);
      setState(() {});

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم حذف قاعدة البيانات وإنشاء قاعدة جديدة فارغة!')),
      );
    } catch (e) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
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
        title: 'إدارة قاعدة البيانات',
        backgroundImagePath: 'assets/3.jpg',
        child: Stack(
          children: [
            Center(
              child: SingleChildScrollView(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const SizedBox(height: 40),

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
                    if (DefaultFirebaseOptions.isConfigured) ...[
                      const SizedBox(height: 24),

                      if (_syncBusy)
                        const Padding(
                          padding: EdgeInsets.all(16),
                          child: CircularProgressIndicator(),
                        )
                      else
                        Wrap(
                          alignment: WrapAlignment.center,
                          spacing: spacing,
                          runSpacing: spacing,
                          children: [
                            SizedBox(
                              width: buttonWidth,
                              height: buttonHeight,
                              child: createButton(
                                text: 'رفع للسحابة',
                                icon: Icons.cloud_upload,
                                onPressed: _confirmAndUploadCloud,
                                bgColor: const Color(0xFF2563EB),
                              ),
                            ),
                            SizedBox(
                              width: buttonWidth,
                              height: buttonHeight,
                              child: createButton(
                                text: 'تنزيل من السحابة',
                                icon: Icons.cloud_download,
                                onPressed: _confirmAndDownloadCloud,
                                bgColor: const Color(0xFF7C3AED),
                              ),
                            ),
                          ],
                        ),
                    ],
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