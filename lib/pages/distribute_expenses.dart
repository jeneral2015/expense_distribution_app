import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../utils/button_utils.dart';
import '../utils/database.dart';
import '../utils/background_scaffold.dart';

class DistributeExpensesPage extends StatefulWidget {
  final DatabaseManager db;
  final VoidCallback navigateToMain;
  final String backgroundImagePath;

  const DistributeExpensesPage({
    Key? key,
    required this.db,
    required this.navigateToMain,
    required this.backgroundImagePath,
  }) : super(key: key);

  @override
  _DistributeExpensesPageState createState() => _DistributeExpensesPageState();
}

class _DistributeExpensesPageState extends State<DistributeExpensesPage> {
  @override
  void initState() {
    super.initState();
    // widget.db.initializeDatabase(); // تم تعليقها لأنها بتحصل في main.dart
  }

  void _navigateTo(String page) {
    if (page == 'main') {
      widget.navigateToMain();
    } else {
      context.go('/$page');
    }
  }

  @override
  Widget build(BuildContext context) {
    const title = Text(
      'توزيع المصروفات',
      style: TextStyle(
        fontSize: 40,
        fontWeight: FontWeight.bold,
        color: Colors.black,
        fontFamily: 'DancingScript',
      ),
      textAlign: TextAlign.center,
    );

    final btnDrinks = createButton(
      text: '☕ المشروبات',
      onPressed: () => _navigateTo('drink'),
      bgColor: Colors.green[700]!,
    );
    final btnMeals = createButton(
      text: '🍽️ الوجبات',
      onPressed: () => _navigateTo('meal'),
      bgColor: Colors.green[700]!,
    );
    final btnBack = createButton(
      text: 'رجوع',
      onPressed: () => _navigateTo('main'),
      bgColor: Colors.red[700]!,
    );

    return PopScope(
      canPop: false,
      onPopInvoked: (bool didPop) {
        if (didPop) return;
        widget.navigateToMain();
      },
      child: Stack(
        children: [
          BackgroundScaffold(
            backgroundImagePath: widget.backgroundImagePath,
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.start,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const SizedBox(height: 50),
                    title,
                    const SizedBox(height: 50),
                    btnDrinks,
                    const SizedBox(height: 20),
                    btnMeals,
                    const SizedBox(height: 20),
                    btnBack,
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
  }
}