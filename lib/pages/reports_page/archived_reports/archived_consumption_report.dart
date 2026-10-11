import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../utils/database.dart';
import '../../../utils/button_utils.dart';
import '../../../utils/background_scaffold.dart';
import '../../../utils/consumption_report_ui.dart';
import '../../../utils/excel_export.dart';

class ArchivedConsumptionReport extends StatefulWidget {
  final DatabaseManager db;
  final int archiveKeyId;

  const ArchivedConsumptionReport({
    Key? key,
    required this.db,
    required this.archiveKeyId,
  }) : super(key: key);

  @override
  _ArchivedConsumptionReportState createState() => _ArchivedConsumptionReportState();
}

class _ArchivedConsumptionReportState extends State<ArchivedConsumptionReport> {
  // نستخدم خط عربي واضح
  final TextStyle textStyle = const TextStyle(
    fontSize: 16,
    fontFamily: 'Cairo',
    color: Colors.black,
  );

  final TextStyle titleStyle = const TextStyle(
    fontSize: 24,
    fontWeight: FontWeight.bold,
    fontFamily: 'Cairo',
    color: Colors.black,
  );

  List<Map<String, dynamic>> consumption = [];
  double totalMeals = 0.0;
  double totalDrinks = 0.0;
  double totalMisc = 0.0;
  double totalConsumption = 0.0;
  double totalContributions = 0.0;
  double totalRemainingItems = 0.0;
  double totalRemainingCash = 0.0;
  String archiveName = '';
  String startDate = '';
  String endDate = '';

  // متغيرات لتتبع حالة التحميل والأخطاء
  bool _isLoading = true;
  String _errorMessage = '';

  // متغير لتتبع ما إذا كانت الإجماليات من قاعدة البيانات
  bool useDbTotals = false;

  @override
  void initState() {
    super.initState();
    if (kDebugMode) {
      print('🔄 [DEBUG] initState called for archiveKeyId: ${widget.archiveKeyId}');
    }
    _fetchConsumptionData();
  }

  @override
  void didUpdateWidget(ArchivedConsumptionReport oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (kDebugMode) {
      print('🔄 [DEBUG] didUpdateWidget called');
    }
    if (oldWidget.archiveKeyId != widget.archiveKeyId) {
      if (kDebugMode) {
        print('🔄 [DEBUG] archiveKeyId changed from ${oldWidget.archiveKeyId} to ${widget.archiveKeyId}, refreshing data...');
      }
      _fetchConsumptionData();
    }
  }

  void showSnackBar(String message) {
    if (kDebugMode) {
      print('📣 [DEBUG] Showing snackbar: $message');
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: textStyle),
        backgroundColor: Colors.red[800],
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // دالة آمنة لتحويل أي قيمة إلى double
  double safeDouble(dynamic value) {
    if (value == null) {
      if (kDebugMode) {
        print('⚠️ [DEBUG] safeDouble received null value, returning 0.0');
      }
      return 0.0;
    }
    if (value is num) {
      if (kDebugMode) {
        print('✅ [DEBUG] safeDouble converting num $value to double');
      }
      return value.toDouble();
    }
    if (value is String) {
      if (kDebugMode) {
        print('✅ [DEBUG] safeDouble parsing string "$value" to double');
      }
      final result = double.tryParse(value) ?? 0.0;
      if (result == 0.0) {
        if (kDebugMode) {
          print('⚠️ [DEBUG] safeDouble failed to parse string "$value", returning 0.0');
        }
      }
      return result;
    }
    if (kDebugMode) {
      print('⚠️ [DEBUG] safeDouble received unknown type: ${value.runtimeType}, returning 0.0');
    }
    return 0.0;
  }

  Future<void> _fetchConsumptionData() async {
    if (kDebugMode) {
      print('🔄 [DEBUG] Starting _fetchConsumptionData for archiveKeyId: ${widget.archiveKeyId}');
    }
    
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });
    
    try {
      // جلب بيانات الأرشيف
      if (kDebugMode) {
        print('📋 [DEBUG] Fetching archive info from database...');
      }
      final archiveInfo = await widget.db.fetchAll(
        'SELECT archive_name, start_date, end_date FROM archive_keys WHERE archive_key_id = ?',
        [widget.archiveKeyId],
      );

      if (kDebugMode) {
        print('📊 [DEBUG] Archive info query returned ${archiveInfo.length} rows');
      }
      
      if (archiveInfo.isEmpty) {
        if (kDebugMode) {
          print('❌ [DEBUG] No archive info found for archiveKeyId: ${widget.archiveKeyId}');
        }
        setState(() {
          _isLoading = false;
          _errorMessage = 'لا توجد بيانات لفترة الأرشيف المحددة!';
        });
        showSnackBar('لا توجد بيانات لفترة الأرشيف المحددة!');
        return;
      }

      if (kDebugMode) {
        print('✅ [DEBUG] Archive info found: ${archiveInfo[0]}');
      }
      
      setState(() {
        archiveName = archiveInfo[0]['archive_name'] as String? ?? 'أرشيف غير معروف';
        startDate = archiveInfo[0]['start_date'] as String? ?? '';
        endDate = archiveInfo[0]['end_date'] as String? ?? '';
      });

      // جلب بيانات الاستهلاك مع التأكد من أسماء الحقول كما يتوقعها ConsumptionReportUI
      const query = '''
        SELECT 
          m.name,
          m.rank,
          COALESCE(csa.total_meals, 0) AS total_meals,
          COALESCE(csa.total_drinks, 0) AS total_drinks,
          COALESCE(csa.total_miscellaneous, 0) AS total_miscellaneous,
          COALESCE(csa.total_consumption, 0) AS total_consumption,
          COALESCE(csa.total_contribution, 0) AS total_contribution,
          COALESCE(csa.remaining_cash, 0) AS remaining_cash
        FROM closure_summary_archive csa
        JOIN members_archive m ON csa.member_id = m.member_id
        WHERE csa.archive_key_id = ? AND m.archive_key_id = ?
      ''';

      if (kDebugMode) {
        print('📋 [DEBUG] Fetching consumption data with query...');
      }
      final consumptionData = await widget.db.fetchAll(query, [widget.archiveKeyId, widget.archiveKeyId]);

      if (kDebugMode) {
        print('📊 [DEBUG] Consumption data query returned ${consumptionData.length} rows');
      }
      
      if (consumptionData.isEmpty) {
        if (kDebugMode) {
          print('❌ [DEBUG] No consumption data found for archiveKeyId: ${widget.archiveKeyId}');
        }
        setState(() {
          _isLoading = false;
          _errorMessage = 'لا توجد بيانات استهلاك لهذه الفترة!';
        });
        showSnackBar('لا توجد بيانات استهلاك لهذه الفترة!');
        return;
      }

      // ترتيب الرتب من "ملازم" لأعلى (ملازم أول، ثم ملازم، ثم أعلى رتبة)
      final Map<String, int> rankOrder = {
        'لواء': 1,
        'عميد': 2,
        'عقيد': 3,
        'مقدم': 4,
        'رائد': 5,
        'نقيب': 6,
        'ملازم أول': 7,
        'ملازم': 8,
      };

      if (kDebugMode) {
        print('🔢 [DEBUG] Sorting consumption data by rank...');
      }
      // Create a copy of the list to avoid read-only error
      final sortedConsumptionData = List<Map<String, dynamic>>.from(consumptionData);
      sortedConsumptionData.sort((a, b) {
        final rankA = (a['rank'] as String?)?.trim() ?? '';
        final rankB = (b['rank'] as String?)?.trim() ?? '';
        final orderA = rankOrder[rankA] ?? 999;
        final orderB = rankOrder[rankB] ?? 999;
        return orderA.compareTo(orderB); // تصاعدي: من الأعلى إلى الأدنى (لواء قبل ملازم)
      });

      // تحويل البيانات لتنسيق متوافق مع UI
      if (kDebugMode) {
        print('🔄 [DEBUG] Mapping consumption data for UI...');
      }
      final List<Map<String, dynamic>> mappedData = sortedConsumptionData.map((row) {
        final mappedRow = {
          'name': row['name']?.toString() ?? '',
          'rank': row['rank']?.toString() ?? '',
          'total_meals': safeDouble(row['total_meals']),
          'total_drinks': safeDouble(row['total_drinks']),
          'total_miscellaneous': safeDouble(row['total_miscellaneous']),
          'total_consumption': safeDouble(row['total_consumption']),
          'total_contribution': safeDouble(row['total_contribution']),
          'remaining_cash': safeDouble(row['remaining_cash']),
        };
        if (kDebugMode) {
          print('📝 [DEBUG] Mapped row: $mappedRow');
        }
        return mappedRow;
      }).toList();

      // محاولة جلب الإجماليات من monthly_totals_archive
      if (kDebugMode) {
        print('📋 [DEBUG] Attempting to fetch archive totals from monthly_totals_archive...');
      }
      const archiveTotalsQuery = '''
        SELECT total_meals, total_drinks, total_misc, total_consumption,
               total_contributions, remaining_items, remaining_cash
        FROM monthly_totals_archive
        WHERE archive_key_id = ?
      ''';
      final archiveTotals = await widget.db.fetchAll(archiveTotalsQuery, [widget.archiveKeyId]);

      double dbTotalMeals = 0.0;
      double dbTotalDrinks = 0.0;
      double dbTotalMisc = 0.0;
      double dbTotalConsumption = 0.0;
      double dbTotalContributions = 0.0;
      double dbTotalRemainingItems = 0.0;
      double dbTotalRemainingCash = 0.0;

      if (archiveTotals.isNotEmpty) {
        final row = archiveTotals.first;
        dbTotalMeals = safeDouble(row['total_meals']);
        dbTotalDrinks = safeDouble(row['total_drinks']);
        dbTotalMisc = safeDouble(row['total_misc']);
        dbTotalConsumption = safeDouble(row['total_consumption']);
        dbTotalContributions = safeDouble(row['total_contributions']);
        dbTotalRemainingItems = safeDouble(row['remaining_items']);
        dbTotalRemainingCash = safeDouble(row['remaining_cash']);
        useDbTotals = true;

        if (kDebugMode) {
          print('✅ [DEBUG] Using DB totals from monthly_totals_archive:');
          print('   - Meals: $dbTotalMeals, Drinks: $dbTotalDrinks, Misc: $dbTotalMisc');
          print('   - Consumption: $dbTotalConsumption, Contributions: $dbTotalContributions');
          print('   - Remaining Items: $dbTotalRemainingItems, Cash: $dbTotalRemainingCash');
        }
      } else {
        if (kDebugMode) {
          print('⚠️ [DEBUG] No archive totals found in monthly_totals_archive, using calculated totals');
        }
      }

      // حساب الإجماليات (كاحتياطي إذا لم توجد بيانات في monthly_totals_archive)
      if (kDebugMode) {
        print('🧮 [DEBUG] Calculating fallback totals...');
      }
      final calculatedTotalMeals = mappedData.fold<double>(0.0, (sum, item) => sum + ((item['total_meals'] as double?) ?? 0.0));
      final calculatedTotalDrinks = mappedData.fold<double>(0.0, (sum, item) => sum + ((item['total_drinks'] as double?) ?? 0.0));
      final calculatedTotalMisc = mappedData.fold<double>(0.0, (sum, item) => sum + ((item['total_miscellaneous'] as double?) ?? 0.0));
      final calculatedTotalConsumption = mappedData.fold<double>(0.0, (sum, item) => sum + ((item['total_consumption'] as double?) ?? 0.0));
      final calculatedTotalContributions = mappedData.fold<double>(0.0, (sum, item) => sum + ((item['total_contribution'] as double?) ?? 0.0));
      final calculatedTotalRemainingCash = mappedData.fold<double>(0.0, (sum, item) => sum + ((item['remaining_cash'] as double?) ?? 0.0));

      if (kDebugMode) {
        print('📊 [DEBUG] Totals calculated:');
      }
      if (kDebugMode) {
        print('   - Meals: $calculatedTotalMeals');
      }
      if (kDebugMode) {
        print('   - Drinks: $calculatedTotalDrinks');
      }
      if (kDebugMode) {
        print('   - Misc: $calculatedTotalMisc');
      }
      if (kDebugMode) {
        print('   - Consumption: $calculatedTotalConsumption');
      }
      if (kDebugMode) {
        print('   - Contributions: $calculatedTotalContributions');
      }
      if (kDebugMode) {
        print('   - Remaining Cash: $calculatedTotalRemainingCash');
      }

      setState(() {
        consumption = mappedData;
        if (useDbTotals) {
          totalMeals = dbTotalMeals;
          totalDrinks = dbTotalDrinks;
          totalMisc = dbTotalMisc;
          totalConsumption = dbTotalConsumption;
          totalRemainingItems = dbTotalRemainingItems;
          // Fix for totalContributions if DB has 0 but calculated has value
          if (dbTotalContributions == 0.0 && calculatedTotalContributions != 0.0) {
            totalContributions = calculatedTotalContributions;
            // Recalculate remaining cash based on correct contributions
            totalRemainingCash = totalContributions - totalConsumption - totalRemainingItems;
            if (kDebugMode) {
              print('🔧 [DEBUG] Corrected totalContributions from DB 0.0 to calculated $calculatedTotalContributions');
              print('🔧 [DEBUG] Recalculated totalRemainingCash to $totalRemainingCash');
            }
          } else {
            totalContributions = dbTotalContributions;
            totalRemainingCash = dbTotalRemainingCash;
          }
        } else {
          totalMeals = calculatedTotalMeals;
          totalDrinks = calculatedTotalDrinks;
          totalMisc = calculatedTotalMisc;
          totalConsumption = calculatedTotalConsumption;
          totalContributions = calculatedTotalContributions;
          totalRemainingCash = calculatedTotalRemainingCash;
          totalRemainingItems = 0.0; // لا يوجد "متبقيات عينية" في الأرشيف — يمكن تعديله لاحقًا إن وُجدت
        }
        _isLoading = false;
        _errorMessage = '';
      });

      // ✅ للتأكد أن البيانات صحيحة - اطبع أول صف
      if (consumption.isNotEmpty) {
        if (kDebugMode) {
          print('✅ [DEBUG] أول صف في التقرير: ${consumption.first}');
        }
      } else {
        if (kDebugMode) {
          print('⚠️ [DEBUG] Consumption list is empty after mapping');
        }
      }
    } catch (e, stackTrace) {
      if (kDebugMode) {
        print('❌ [DEBUG] Error in _fetchConsumptionData: $e');
      }
      if (kDebugMode) {
        print('📋 [DEBUG] Stack trace: $stackTrace');
      }
      setState(() {
        _isLoading = false;
        _errorMessage = 'خطأ أثناء جلب تقرير الاستهلاك: $e';
      });
      showSnackBar('خطأ أثناء جلب تقرير الاستهلاك: $e');
    }
  }

  // تصدير إلى Excel
  Future<void> _exportToExcel() async {
    if (kDebugMode) {
      print('📤 [DEBUG] Starting _exportToExcel');
    }

    try {
      if (consumption.isEmpty) {
        if (kDebugMode) {
          print('❌ [DEBUG] Cannot export - consumption data is empty');
        }
        showSnackBar('لا توجد بيانات لتصديرها');
        return;
      }

      final columns = [
        'المسلسل',
        'الرتبة',
        'الاسم',
        'إجمالي الوجبات',
        'إجمالي المشروبات',
        'إجمالي النثريات',
        'إجمالي الاستهلاك',
        'إجمالي المساهمات',
        'المبلغ المتبقي',
      ];

      final rows = consumption.asMap().entries.map((entry) {
        final i = entry.key;
        final row = entry.value;
        return [
          (i + 1).toString(),
          row['rank'] as String,
          row['name'] as String,
          row['total_meals'] as num,
          row['total_drinks'] as num,
          row['total_miscellaneous'] as num,
          row['total_consumption'] as num,
          row['total_contribution'] as num,
          row['remaining_cash'] as num,
        ];
      }).toList();

      final extraInfo = <String, String>{
        'الفترة': '$startDate إلى $endDate',
        'اسم الأرشيف': archiveName,
      };

      final totals = [
        [
          'الإجمالي',
          '',
          '',
          totalMeals,
          totalDrinks,
          totalMisc,
          totalConsumption,
          totalContributions,
          totalRemainingCash,
        ],
      ];

      await exportReportToExcel(
        context: context,
        reportTitle: 'تقرير استهلاك المشتركين أرشيف',
        columns: columns,
        rows: rows,
        extraInfo: extraInfo,
        totals: totals,
      );

      if (kDebugMode) {
        print('✅ [DEBUG] Excel export completed successfully');
      }
      showSnackBar('تم التصدير بنجاح');
    } catch (e, stackTrace) {
      if (kDebugMode) {
        print('❌ [DEBUG] Error in _exportToExcel: $e');
      }
      if (kDebugMode) {
        print('📋 [DEBUG] Stack trace: $stackTrace');
      }
      showSnackBar('خطأ في التصدير: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (kDebugMode) {
      print('🔄 [DEBUG] Building ArchivedConsumptionReport UI');
    }
    
    return BackgroundScaffold(
      backgroundImagePath: 'assets/3.jpg',
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Stack(
          children: [
            if (_isLoading)
              Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const CircularProgressIndicator(),
                    const SizedBox(height: 16),
                    Text('جاري تحميل البيانات...', style: textStyle),
                  ],
                ),
              )
            else if (_errorMessage.isNotEmpty)
              Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error, size: 48, color: Colors.red),
                    const SizedBox(height: 16),
                    Text(_errorMessage, style: textStyle.copyWith(color: Colors.red)),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: _fetchConsumptionData,
                      child: Text('إعادة المحاولة', style: textStyle),
                    ),
                  ],
                ),
              )
            else
              Column(
                children: [
                  Expanded(
                    child: consumption.isNotEmpty
                        ? KeyedSubtree(
                            key: ValueKey(widget.archiveKeyId), // تحديث فوري عند تغيير الأرشيف
                            child: ConsumptionReportUI.buildConsumptionReportView(
                              reportData: {
                                'summaryData': consumption,
                                'totalMeals': totalMeals,
                                'totalDrinks': totalDrinks,
                                'totalMisc': totalMisc,
                                'totalConsumption': totalConsumption,
                                'totalContributions': totalContributions,
                                'totalRemainingItems': totalRemainingItems,
                                'totalRemainingCash': totalRemainingCash,
                              },
                              titleStyle: titleStyle,
                              archiveName: archiveName,
                              startDate: startDate,
                              endDate: endDate,
                            ),
                          )
                        : Center(
                            child: Text(
                              'لا توجد بيانات لعرضها',
                              style: textStyle.copyWith(fontSize: 18),
                            ),
                          ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 10),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        createButton(
                          text: 'تصدير إلى Excel',
                          onPressed: _exportToExcel,
                          bgColor: Colors.blue[700]!,
                          textColor: Colors.white,
                          width: MediaQuery.of(context).size.width * 0.4,
                          height: 50,
                          icon: Icons.download,
                          iconColor: Colors.white,
                        ),
                        const SizedBox(width: 10),
                        createButton(
                          text: 'رجوع',
                          onPressed: () {
                            if (kDebugMode) {
                              print('🔙 [DEBUG] Back button pressed');
                            }
                            Navigator.pop(context);
                          },
                          bgColor: Colors.red[700]!,
                          textColor: Colors.white,
                          width: MediaQuery.of(context).size.width * 0.4,
                          height: 50,
                          icon: Icons.arrow_back,
                          iconColor: Colors.white,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            Positioned(
              top: 20,
              left: 20,
              child: createHomeButton(
                onPressed: () {
                  if (kDebugMode) {
                    print('🏠 [DEBUG] Home button pressed');
                  }
                  context.go('/main');
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}


