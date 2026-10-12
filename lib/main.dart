import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:logging/logging.dart';

import 'firebase_options.dart';
import 'pages/auth/login_page.dart';
import 'pages/auth/register_page.dart';
import 'pages/database_page.dart';
import 'pages/distribute_expenses.dart';
import 'pages/drink_page.dart';
import 'pages/end_month_page/end_month_page.dart';
import 'pages/input_page.dart';
import 'pages/input_purchases.dart';
import 'pages/input_subscribers.dart';
import 'pages/main_page.dart';
import 'pages/manage_records.dart';
import 'pages/meal_page.dart';
import 'pages/reports_page/reports_page.dart';
import 'pages/settings_page.dart';
import 'pages/show_expenses.dart';
import 'pages/show_subscribers.dart';
import 'pages/view_page.dart';
import 'services/auth_service.dart';
import 'services/sync_service.dart';
import 'theme/app_theme.dart';
import 'utils/background_scaffold.dart';
import 'utils/database.dart';
import 'utils/platform_database.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initPlatformDatabase();

  if (DefaultFirebaseOptions.isConfigured) {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  }

  Logger.root.level = Level.INFO;
  Logger.root.onRecord.listen((record) {
    debugPrint('${record.level.name}: ${record.time}: ${record.message}');
  });

  final auth = AuthService();
  await auth.ensureInitialized();
  final db = DatabaseManager();
  final sync = SyncService();

  await _bootstrapUserDatabase(auth, db, sync);

  runApp(ExpensesApp(db: db, auth: auth, sync: sync));
}

Future<void> _bootstrapUserDatabase(
  AuthService auth,
  DatabaseManager db,
  SyncService sync,
) async {
  final uid = auth.userId;
  await db.setUserId(uid);
  await db.initializeDatabase();
}

class ExpensesApp extends StatefulWidget {
  const ExpensesApp({
    super.key,
    required this.db,
    required this.auth,
    required this.sync,
  });

  final DatabaseManager db;
  final AuthService auth;
  final SyncService sync;

  @override
  State<ExpensesApp> createState() => _ExpensesAppState();
}

class _ExpensesAppState extends State<ExpensesApp> {
  late final GoRouter _router;

  @override
  void initState() {
    super.initState();
    widget.auth.addListener(_onAuthChanged);
    _router = _buildRouter();
  }

  @override
  void dispose() {
    widget.auth.removeListener(_onAuthChanged);
    super.dispose();
  }

  Future<void> _onAuthChanged() async {
    final uid = widget.auth.userId;
    
    // If we're just toggling loading state, only refresh the router.
    if (widget.auth.isLoadingPermissions) {
      _router.refresh();
      return;
    }

    await widget.db.setUserId(uid);
    await widget.db.initializeDatabase();
    
    // Refresh the UI IMMEDIATELY so the loading circle disappears.
    _router.refresh();
  }

  GoRouter _buildRouter() {
    final db = widget.db;
    final auth = widget.auth;

    final firebaseEnabled = DefaultFirebaseOptions.isConfigured;

    return GoRouter(
      initialLocation: !firebaseEnabled || auth.isLoggedIn ? '/main' : '/login',
      refreshListenable: auth,
      redirect: (context, state) {
        if (!firebaseEnabled) {
          return null;
        }
        final loggedIn = auth.isLoggedIn;
        final loc = state.matchedLocation;
        final onAuth = loc == '/login' || loc == '/register';
        if (!loggedIn && !onAuth) return '/login';
        if (loggedIn && onAuth) return '/main';
        return null;
      },
      routes: [
        GoRoute(
          path: '/login',
          builder: (context, state) => LoginPage(auth: auth),
        ),
        GoRoute(
          path: '/register',
          builder: (context, state) => RegisterPage(auth: auth),
        ),
        GoRoute(
          path: '/main',
          builder: (context, state) => MainScreen(db: db, auth: auth),
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
        GoRoute(
          path: '/show_expenses',
          builder: (context, state) {
            final extra = state.extra as Map<String, dynamic>? ?? {};
            final bool isMiscellaneous =
                extra['isMiscellaneous'] as bool? ?? false;
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
            navigateToDistribute_expenses: () =>
                context.go('/distribute_expenses'),
            backgroundImagePath: 'assets/3.jpg',
          ),
        ),
        GoRoute(
          path: '/meal',
          builder: (context, state) => MealPage(
            db: db,
            navigateToDistribute_expenses: () =>
                context.go('/distribute_expenses'),
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
            auth: auth,
            sync: widget.sync,
            navigateToMain: () => context.go('/main'),
          ),
        ),
        GoRoute(
          path: '/settings',
          builder: (context, state) => SettingsPage(auth: auth),
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
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'برنامج توزيع المصاريف',
      theme: AppTheme.light(),
      routerConfig: _router,
    );
  }
}

class MainScreen extends StatelessWidget {
  final DatabaseManager db;
  final AuthService auth;

  const MainScreen({super.key, required this.db, required this.auth});

  @override
  Widget build(BuildContext context) {
    return BackgroundScaffold(
      backgroundImagePath: 'assets/3.jpg',
      showAppBar: false,
      child: MainPage(db: db, auth: auth),
    );
  }
}
