import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../utils/button_utils.dart';
import '../utils/database.dart';
import '../utils/background_scaffold.dart';

class ViewPage extends StatelessWidget {
  final DatabaseManager db;
  final VoidCallback navigateToMain;
  final String backgroundImagePath;

  const ViewPage({
    Key? key,
    required this.db,
    required this.navigateToMain,
    required this.backgroundImagePath,
  }) : super(key: key);

  void _handleBack(BuildContext context) {
    navigateToMain();
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
        _handleBack(context);
      },
      child: BackgroundScaffold(
        title: 'عرض وبحث',
        backgroundImagePath: backgroundImagePath,
        child: Stack(
          children: [
            Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text(
                      'عرض البيانات',
                      style: TextStyle(
                        fontSize: 25,
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                        
                      ),
                      textDirection: TextDirection.rtl,
                    ),
                    const SizedBox(height: 30),
                    createButton(
                      text: 'عرض المتبقيات',
                      onPressed: () => context.push('/show_expenses', extra: {'isMiscellaneous': false}), // تمرير المعامل
                      bgColor: Colors.green[700]!,
                      width: buttonWidth,
                      height: buttonHeight,
                    ),
                    const SizedBox(height: 20),
                    createButton(
                      text: 'عرض النثريات',
                      onPressed: () => context.push('/show_expenses', extra: {'isMiscellaneous': true}), // تمرير المعامل
                      bgColor: Colors.green[700]!,
                      width: buttonWidth,
                      height: buttonHeight,
                    ),
                    const SizedBox(height: 20),
                    createButton(
                      text: 'عرض بيانات المشتركين',
                      onPressed: () => context.push('/show_subscribers'),
                      bgColor: Colors.green[700]!,
                      width: buttonWidth,
                      height: buttonHeight,
                    ),
                    const SizedBox(height: 20),
                    createButton(
                      text: 'رجوع',
                      onPressed: () => _handleBack(context),
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