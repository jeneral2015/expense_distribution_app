import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../utils/button_utils.dart';
import '../utils/database.dart';
import '../utils/background_scaffold.dart';

class ViewPage extends StatelessWidget {
  final DatabaseManager db;
  final VoidCallback navigateToMain;
  final String? backgroundImagePath;

  const ViewPage({
    super.key,
    required this.db,
    required this.navigateToMain,
    this.backgroundImagePath,
  });

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (bool didPop, dynamic result) {
        if (didPop) return;
        navigateToMain();
      },
      child: BackgroundScaffold(
        title: 'عرض وبحث',
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20.0),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final double buttonWidth = constraints.maxWidth < 600
                    ? constraints.maxWidth * 0.8
                    : 280;
                const double buttonHeight = 52.0;
                const double spacing = 18.0;

                return Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const Text(
                      'عرض البيانات',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                        fontFamily: 'Cairo',
                      ),
                      textDirection: TextDirection.rtl,
                    ),
                    const SizedBox(height: 28),
                    createButton(
                      text: 'عرض المتبقيات',
                      onPressed: () => context.push(
                        '/show_expenses',
                        extra: {'isMiscellaneous': false},
                      ),
                      bgColor: Colors.green[700]!,
                      width: buttonWidth,
                      height: buttonHeight,
                    ),
                    const SizedBox(height: spacing),
                    createButton(
                      text: 'عرض النثريات',
                      onPressed: () => context.push(
                        '/show_expenses',
                        extra: {'isMiscellaneous': true},
                      ),
                      bgColor: Colors.green[700]!,
                      width: buttonWidth,
                      height: buttonHeight,
                    ),
                    const SizedBox(height: spacing),
                    createButton(
                      text: 'عرض بيانات المشتركين',
                      onPressed: () => context.push('/show_subscribers'),
                      bgColor: Colors.green[700]!,
                      width: buttonWidth,
                      height: buttonHeight,
                    ),
                    const SizedBox(height: spacing * 2),
                    createButton(
                      text: 'رجوع',
                      onPressed: () => navigateToMain(),
                      bgColor: Colors.red[700]!,
                      width: buttonWidth,
                      height: buttonHeight,
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