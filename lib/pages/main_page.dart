import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:io';
import 'package:go_router/go_router.dart';
import '../utils/button_utils.dart';
import '../utils/database.dart';
import '../utils/background_scaffold.dart';

class MainPage extends StatelessWidget {
  final DatabaseManager db;

  const MainPage({super.key, required this.db});

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false, // Disable default back button behavior
      onPopInvoked: (didPop) {
        if (didPop) return;
        _showExitDialog(context); // Show exit dialog on back press
      },
      child: LayoutBuilder(
        builder: (context, constraints) {
          final mediaQuery = MediaQuery.of(context);
          final bool isPortrait = mediaQuery.orientation == Orientation.portrait;
          final double maxWidth = mediaQuery.size.width;
          final double maxHeight = mediaQuery.size.height;
          final double buttonWidth = isPortrait ? maxWidth * 0.4 : maxWidth * 0.25;
          final double buttonHeight = isPortrait ? 55.0 : 70.0;
          final double spacing = isPortrait ? 40.0 : 50.0;
          final double runSpacing = isPortrait ? 30.0 : 15.0;
          final double titleSize = isPortrait ? 30.0 : 30.0;
          final double padding = isPortrait ? 10.0 : 20.0;

          return BackgroundScaffold(
            backgroundImagePath: 'assets/3.jpg',
            child: Center(
              child: SingleChildScrollView(
                child: Container(
                  padding: EdgeInsets.all(padding),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Text(
                        'برنامج توزيع المصاريف',
                        style: TextStyle(
                          fontSize: titleSize,
                          fontWeight: FontWeight.bold,
                          color: Colors.black,
                          fontFamily: 'DancingScript',
                        ),
                        textAlign: TextAlign.center,
                        textDirection: TextDirection.rtl,
                      ),
                      SizedBox(height: maxHeight * 0.05),
                      Wrap(
                        spacing: spacing,
                        runSpacing: runSpacing,
                        alignment: WrapAlignment.center,
                        runAlignment: WrapAlignment.center,
                        children: [
                          createButton(
                            text: '📥 إدخال البيانات',
                            onPressed: () => context.go('/input'),
                            bgColor: Colors.blue[700]!,
                            width: buttonWidth,
                            height: buttonHeight,
                          ),
                          createButton(
                            text: '📊 عرض البحث',
                            onPressed: () => context.go('/view'),
                            bgColor: Colors.green[700]!,
                            width: buttonWidth,
                            height: buttonHeight,
                          ),
                          createButton(
                            text: '🍽️ توزيع المصروفات',
                            onPressed: () => context.go('/distribute_expenses'),
                            bgColor: Colors.orange[700]!,
                            width: buttonWidth,
                            height: buttonHeight,
                          ),
                          createButton(
                            text: '📑 التقارير',
                            onPressed: () => context.go('/reports'),
                            bgColor: Colors.purple[700]!,
                            width: buttonWidth,
                            height: buttonHeight,
                          ),
                          createButton(
                            text: '📅 تقفيل الشهر',
                            onPressed: () => context.go('/end_month'),
                            bgColor: Colors.red[700]!,
                            width: buttonWidth,
                            height: buttonHeight,
                          ),
                          createButton(
                            text: '🗄️ قاعدة البيانات',
                            onPressed: () => context.go('/database'),
                            bgColor: Colors.teal[700]!,
                            width: buttonWidth,
                            height: buttonHeight,
                          ),
                          createButton(
                            text: '📋 إدارة السجلات',
                            onPressed: () => context.push('/manage_records'),
                            bgColor: Colors.indigo[700]!,
                            width: buttonWidth,
                            height: buttonHeight,
                          ),
                        ],
                      ),
                      SizedBox(height: maxHeight * 0.05),
                      createButton(
                        text: '❌ إغلاق',
                        onPressed: () => _showExitDialog(context),
                        bgColor: Colors.grey[700]!,
                        width: buttonWidth,
                        height: buttonHeight,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  void _showExitDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text(
          'تأكيد الإغلاق',
          style: TextStyle(fontFamily: 'Lalezar'),
          textDirection: TextDirection.rtl,
        ),
        content: const Text(
          'هل أنت متأكد أنك تريد إغلاق البرنامج؟',
          style: TextStyle(fontFamily: 'Lalezar'),
          textDirection: TextDirection.rtl,
        ),
        actions: [
          TextButton(
            onPressed: () {
              db.close();
              Navigator.pop(context);
              if (Platform.isAndroid) {
                SystemNavigator.pop();
              } else if (Platform.isIOS) {
                // التطبيقات على iOS لا يفترض أن تغلق نفسها برمجياً
                // لكن إذا كان ضرورياً، يمكن استخدام exit(0)
                exit(0);
              } else if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
                // الطريقة الصحيحة لإغلاق التطبيق على أنظمة سطح المكتب
                exit(0);
              }
            },
            child: const Text(
              'نعم',
              style: TextStyle(fontFamily: 'Lalezar'),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'لا',
              style: TextStyle(fontFamily: 'Lalezar'),
            ),
          ),
        ],
      ),
    );
  }
}