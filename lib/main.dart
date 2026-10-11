import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:logging/logging.dart';
import 'pages/main_page.dart';
import 'utils/database.dart';
import 'pages/input_page.dart';
import 'pages/input_subscribers.dart';
import 'pages/input_purchases.dart';
import 'utils/background_scaffold.dart';
import 'pages/view_page.dart';
import 'pages/show_subscribers.dart';
import 'pages/show_expenses.dart'; // استيراد الصفحة الجديدة (بدل show_purchases و show_over)
import 'pages/distribute_expenses.dart';
import 'pages/drink_page.dart';
import 'pages/meal_page.dart';
import 'pages/reports_page/reports_page.dart';
import 'pages/end_month_page/end_month_page.dart';
import 'pages/database_page.dart';
import 'pages/manage_records.dart';
import 'dart:io';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';


void main() async {
  WidgetsFlutterBinding.ensureInitialized(); // لضمان تهيئة Flutter قبل العمليات الاسنكرونية
  try {
    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    }
  } catch (e) {
    // Handle web platform where Platform.isWindows etc. are not available
    // No need to initialize sqflite FFI for web
  }
  Logger.root.level = Level.INFO;
  Logger.root.onRecord.listen((record) {
    // Use proper logging instead of print in production code
    debugPrint('${record.level.name}: ${record.time}: ${record.message}');
  });

  final db = DatabaseManager();
  await db.initializeDatabase(); // تهيئة القاعدة مرة واحدة

  runApp(MyApp(db: db));
}

class MyApp extends StatelessWidget {
  final DatabaseManager db;

  const MyApp({super.key, required this.db});

  @override
  Widget build(BuildContext context) {
    final GoRouter router = GoRouter(
      initialLocation: '/main',
      routes: [
        GoRoute(
          path: '/main',
          builder: (context, state) => MainScreen(db: db),
        ),
        GoRoute(
          path: '/input',
          builder: (context, state) => InputPage(
            db: db,
            navigateToMain: () => context.go('/main'),
            backgroundImagePath: 'assets/3.jpg',
          ),
        ),
        GoRoute(
          path: '/input_subscribers',
          builder: (context, state) => InputSubscribersPage(
            db: db,
            navigateToInput: () => context.replace('/input'),
            backgroundImagePath: 'assets/3.jpg',
          ),
        ),
        GoRoute(
          path: '/input_purchases',
          builder: (context, state) => InputPurchasesPage(
            db: db,
            navigateToInput: () => context.replace('/input'),
            backgroundImagePath: 'assets/3.jpg',
          ),
        ),
        GoRoute(
          path: '/view',
          builder: (context, state) => ViewPage(
            db: db,
            navigateToMain: () => context.go('/main'),
            backgroundImagePath: 'assets/3.jpg',
          ),
        ),
        GoRoute(
          path: '/show_subscribers',
          builder: (context, state) => ShowSubscribersPage(
            db: db,
            navigateToView: () => context.go('/view'),
            backgroundImagePath: 'assets/3.jpg',
          ),
        ),
        GoRoute( // الـ route الجديد للصفحة العامة
          path: '/show_expenses',
          builder: (context, state) {
            final extra = state.extra as Map<String, dynamic>? ?? {}; // استخراج الـ extra
            final bool isMiscellaneous = extra['isMiscellaneous'] as bool? ?? false; // افتراضي false
            return ShowExpensesPage(
              db: db,
              navigateToView: () => context.go('/view'),
              backgroundImagePath: 'assets/3.jpg',
              isMiscellaneous: isMiscellaneous,
            );
          },
        ),
        GoRoute(
          path: '/distribute_expenses',
          builder: (context, state) => DistributeExpensesPage(
            db: db,
            navigateToMain: () => context.go('/main'),
            backgroundImagePath: 'assets/3.jpg',
          ),
        ),
        GoRoute(
          path: '/drink',
          builder: (context, state) => DrinkPage(
            db: db,
            navigateToDistribute_expenses: () => context.go('/distribute_expenses'),
            backgroundImagePath: 'assets/3.jpg',
          ),
        ),
        GoRoute(
          path: '/meal',
          builder: (context, state) => MealPage(
            db: db,
            navigateToDistribute_expenses: () => context.go('/distribute_expenses'),
            backgroundImagePath: 'assets/3.jpg',
          ),
        ),
        GoRoute(
          path: '/reports',
          builder: (context, state) => ReportsPage(
            db: db,
            navigateToMain: () => context.go('/main'),
            backgroundImagePath: 'assets/3.jpg',
          ),
        ),
        GoRoute(
          path: '/end_month',
          builder: (context, state) => EndMonthPage(
            db: db,
            navigateToMain: () => context.go('/main'),
            backgroundImagePath: 'assets/3.jpg',
          ),
        ),
        GoRoute(
          path: '/database',
          builder: (context, state) => DatabasePage(
            db: db,
            navigateToMain: () => context.go('/main'),
          ),
        ),
        GoRoute(
          path: '/manage_records',
          builder: (context, state) => ManageRecordsPage(
            db: db,
            navigateToMain: () => context.go('/main'),
          ),
        ),
      ],
    );

    return MaterialApp.router(
      title: 'برنامج توزيع المصاريف',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        fontFamily: '1',
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      routerConfig: router,
    );
  }
}

class MainScreen extends StatelessWidget {
  final DatabaseManager db;

  const MainScreen({super.key, required this.db});

  @override
  Widget build(BuildContext context) {
    return BackgroundScaffold(
      backgroundImagePath: 'assets/3.jpg',
      child: MainPage(db: db),
    );
  }
}