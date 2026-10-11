import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../utils/button_utils.dart';
import '../utils/background_scaffold.dart';
import '../utils/database.dart';
import 'reports_page/current_reports/meals_report.dart';
import 'reports_page/current_reports/drinks_report.dart';
import 'reports_page/current_reports/member_consumption.dart';

class ManageRecordsPage extends StatefulWidget {
  final DatabaseManager db;
  final VoidCallback navigateToMain;

  const ManageRecordsPage({
    Key? key,
    required this.db,
    required this.navigateToMain,
  }) : super(key: key);

  @override
  _ManageRecordsPageState createState() => _ManageRecordsPageState();
}

class _ManageRecordsPageState extends State<ManageRecordsPage> {
  final TextStyle textStyle = const TextStyle(
    fontSize: 15,
    fontFamily: 'Cairo',
  );
  final TextStyle titleStyle = const TextStyle(
    fontSize: 28,
    fontWeight: FontWeight.bold,
    fontFamily: 'Cairo',
  );

  @override
  Widget build(BuildContext context) {
    return BackgroundScaffold(
      backgroundImagePath: 'assets/3.jpg',
      child: WillPopScope(
        onWillPop: () async {
          // Check if we can pop the current route
          if (Navigator.of(context).canPop()) {
            Navigator.of(context).pop();
            return false; // Prevent default back behavior
          }
          // If no route to pop, navigate to main page instead of closing app
          context.go('/main');
          return false; // Prevent default back behavior (app closing)
        },
        child: Scaffold(
          backgroundColor: Colors.transparent,
          body: Stack(
            children: [
              SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 16.0),
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      SizedBox(
                        height: MediaQuery.of(context).orientation == Orientation.portrait
                            ? MediaQuery.of(context).size.height * 0.1
                            : MediaQuery.of(context).size.height * 0.05,
                      ),
                      Text(
                        'إدارة السجلات',
                        style: titleStyle.copyWith(color: Colors.black),
                        textAlign: TextAlign.center,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 40),
                      
                      // Meal Records Management
                      Card(
                        elevation: 4,
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            children: [
                              Text(
                                'سجلات الوجبات',
                                style: textStyle.copyWith(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 16),
                              createButton(
                                text: 'إدارة سجلات الوجبات',
                                onPressed: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => MealsReport(db: widget.db),
                                    ),
                                  );
                                },
                                bgColor: Colors.orange[700]!,
                                textColor: Colors.white,
                                width: 250,
                                height: 50,
                                icon: Icons.restaurant,
                                iconColor: Colors.white,
                              ),
                            ],
                          ),
                        ),
                      ),
                      
                      const SizedBox(height: 20),
                      
                      // Drink Records Management
                      Card(
                        elevation: 4,
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            children: [
                              Text(
                                'سجلات المشروبات',
                                style: textStyle.copyWith(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 16),
                              createButton(
                                text: 'إدارة سجلات المشروبات',
                                onPressed: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => DrinksReport(db: widget.db),
                                    ),
                                  );
                                },
                                bgColor: Colors.blue[700]!,
                                textColor: Colors.white,
                                width: 250,
                                height: 50,
                                icon: Icons.local_drink,
                                iconColor: Colors.white,
                              ),
                            ],
                          ),
                        ),
                      ),
                      
                      const SizedBox(height: 20),
                      
                      // Member Consumption Management
                      Card(
                        elevation: 4,
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            children: [
                              Text(
                                'استهلاك المشتركين',
                                style: textStyle.copyWith(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 16),
                              createButton(
                                text: 'إدارة استهلاك المشتركين',
                                onPressed: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => MemberConsumption(db: widget.db),
                                    ),
                                  );
                                },
                                bgColor: Colors.green[700]!,
                                textColor: Colors.white,
                                width: 250,
                                height: 50,
                                icon: Icons.people,
                                iconColor: Colors.white,
                              ),
                            ],
                          ),
                        ),
                      ),
                      
                      const SizedBox(height: 40),
                      
                      // Back Button - Updated to handle navigation properly
                      createButton(
                        text: 'رجوع',
                        onPressed: () {
                          if (Navigator.of(context).canPop()) {
                            Navigator.of(context).pop();
                          } else {
                            context.go('/main');
                          }
                        },
                        bgColor: Colors.red[700]!,
                        textColor: Colors.white,
                        width: 200,
                        height: 50,
                        icon: Icons.arrow_back,
                        iconColor: Colors.white,
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
      ),
    );
  }
}
