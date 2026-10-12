import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../utils/button_utils.dart';
import '../utils/database.dart';
import '../utils/background_scaffold.dart';
import '../utils/logger.dart';

class InputPage extends StatelessWidget {
  final DatabaseManager db;
  final VoidCallback? navigateToMain;
  final String backgroundImagePath;

  const InputPage({
    super.key,
    required this.db,
    this.navigateToMain,
    required this.backgroundImagePath,
  });

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false, // Disable default back button behavior
      onPopInvoked: (didPop) {
        if (didPop) return;
        try {
          if (navigateToMain != null) {
            navigateToMain!();
          } else {
            context.go('/main');
          }
        } catch (e) {
          AppLogger.logError('خطأ في التنقل: $e');
        }
      },
      child: LayoutBuilder(
        builder: (context, constraints) {
          final mediaQuery = MediaQuery.of(context);
          final bool isPortrait = mediaQuery.orientation == Orientation.portrait;
          final double maxWidth = mediaQuery.size.width;
          final double maxHeight = mediaQuery.size.height;
          final double buttonWidth = isPortrait ? maxWidth * 0.5 : maxWidth * 0.25;
          final double buttonHeight = isPortrait ? 60.0 : 70.0;
          final double spacing = isPortrait ? 20.0 : 25.0;
          final double runSpacing = isPortrait ? 25.0 : 20.0;
          final double padding = isPortrait ? 16.0 : 24.0;

          return BackgroundScaffold(
            title: 'إدخال البيانات',
            backgroundImagePath: backgroundImagePath,
            child: Stack(
              children: [
                Center(
                  child: SingleChildScrollView(
                    child: Container(
                      padding: EdgeInsets.all(padding),
                      constraints: BoxConstraints(maxWidth: maxWidth * 0.9),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [

                          isPortrait
                              ? Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    createButton(
                                      text: '📥 إدخال بيانات المشتركين',
                                      onPressed: () => context.go('/input_subscribers'),
                                      bgColor: Colors.green[700]!,
                                      width: buttonWidth,
                                      height: buttonHeight,
                                    ),
                                    SizedBox(height: runSpacing),
                                    createButton(
                                      text: '📊 إدخال المشتروات',
                                      onPressed: () => context.go('/input_purchases'),
                                      bgColor: Colors.green[700]!,
                                      width: buttonWidth,
                                      height: buttonHeight,
                                    ),
                                    SizedBox(height: runSpacing),
                                    createButton(
                                      text: '❌ رجوع',
                                      onPressed: () {
                                        try {
                                          if (navigateToMain != null) {
                                            navigateToMain!();
                                          } else {
                                            context.go('/main');
                                          }
                                        } catch (e) {
                                          AppLogger.logError('خطأ في التنقل: $e');
                                        }
                                      },
                                      bgColor: Colors.red[700]!,
                                      width: buttonWidth,
                                      height: buttonHeight,
                                    ),
                                  ],
                                )
                              : Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    createButton(
                                      text: '📥 إدخال بيانات المشتركين',
                                      onPressed: () => context.go('/input_subscribers'),
                                      bgColor: Colors.green[700]!,
                                      width: buttonWidth,
                                      height: buttonHeight,
                                    ),
                                    SizedBox(width: spacing),
                                    createButton(
                                      text: '📊 إدخال المشتروات',
                                      onPressed: () => context.go('/input_purchases'),
                                      bgColor: Colors.green[700]!,
                                      width: buttonWidth,
                                      height: buttonHeight,
                                    ),
                                    SizedBox(width: spacing),
                                    createButton(
                                      text: '❌ رجوع',
                                      onPressed: () {
                                        try {
                                          if (navigateToMain != null) {
                                            navigateToMain!();
                                          } else {
                                            context.go('/main');
                                          }
                                        } catch (e) {
                                          AppLogger.logError('خطأ في التنقل: $e');
                                        }
                                      },
                                      bgColor: Colors.red[700]!,
                                      width: buttonWidth,
                                      height: buttonHeight,
                                    ),
                                  ],
                                ),
                          SizedBox(height: maxHeight * (isPortrait ? 0.08 : 0.12)),
                        ],
                      ),
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
          );
        },
      ),
    );
  }
}