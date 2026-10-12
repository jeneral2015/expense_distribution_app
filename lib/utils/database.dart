import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:intl/intl.dart';
import 'logger.dart';

class DatabaseManager {
  static final DatabaseManager _instance = DatabaseManager._internal();
  factory DatabaseManager() => _instance;
  DatabaseManager._internal();

  Database? _database;
  String? _userId;

  Database? get database => _database;

  String? get userId => _userId;

  String get _dbFileName =>
      _userId != null ? 'expenses_$_userId.db' : 'expenses.db';

  /// ربط قاعدة البيانات المحلية بحساب المستخدم الحالي.
  Future<void> setUserId(String? userId) async {
    if (_userId == userId) return;
    await closeConnection();
    _userId = userId;
  }

  Future<String> databasePath() async {
    if (kIsWeb) {
      return _dbFileName;
    }
    return join(await getDatabasesPath(), _dbFileName);
  }

  double asDouble(dynamic v, [double fallback = 0.0]) {
    if (v == null) return fallback;
    if (v is num) return v.toDouble();
    if (v is String) {
      final p = double.tryParse(v);
      if (p != null) return p;
    }
    return fallback;
  }

  int asInt(dynamic v, [int fallback = 0]) {
    if (v == null) return fallback;
    if (v is int) return v;
    if (v is num) return v.toInt();
    if (v is String) {
      final p = int.tryParse(v);
      if (p != null) return p;
    }
    return fallback;
  }

  Future<void> initializeDatabase() async {
    try {
      final path = await databasePath();
      _database = await openDatabase(
        path,
        version: 3,
        onCreate: (db, version) async {
          await _createTables(db);
          await _ensureSyncMetadata(db);
          await _installSyncRevisionTriggers(db);
        },
        onUpgrade: (db, oldVersion, newVersion) async {
          if (oldVersion < 2) {
            await _createTables(db);
            await _runMigrations(db);
          }
          if (oldVersion < 3) {
            await _ensureSyncMetadata(db);
            await _installSyncRevisionTriggers(db);
          }
        },
      );
      await _database!.execute('PRAGMA foreign_keys = ON;');
    } catch (e) {
      AppLogger.logError('Failed to initialize database: $e');
    }
  }

  Future<void> closeConnection() async {
    if (_database != null && _database!.isOpen) {
      await _database!.close();
    }
    _database = null;
  }

  Future<Uint8List> exportDatabaseBytes() async {
    final path = await databasePath();
    return await databaseFactory.readDatabaseBytes(path);
  }

  Future<void> importDatabaseBytes(Uint8List bytes) async {
    final path = await databasePath();
    await closeConnection();
    await databaseFactory.writeDatabaseBytes(path, bytes);
    await initializeDatabase();
  }


  Future<void> reopenConnection() async {
    if (_database != null && _database!.isOpen) {
      await _database!.close();
    }
    _database = await openDatabase(
      await databasePath(),
      version: 3,
      onCreate: (db, version) async {
        await _createTables(db);
        await _ensureSyncMetadata(db);
        await _installSyncRevisionTriggers(db);
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await _createTables(db);
          await _runMigrations(db);
        }
        if (oldVersion < 3) {
          await _ensureSyncMetadata(db);
          await _installSyncRevisionTriggers(db);
        }
      },
    );
    await _database!.execute('PRAGMA foreign_keys = ON;');
  }

  Future<void> initializeNewDatabase() async {
    await closeConnection();
    final path = await databasePath();
    await deleteDatabase(path);
    _database = await openDatabase(
      path,
      version: 3,
      onCreate: (db, version) async {
        await _createTables(db);
        await _ensureSyncMetadata(db);
        await _installSyncRevisionTriggers(db);
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await _createTables(db);
          await _runMigrations(db);
        }
        if (oldVersion < 3) {
          await _ensureSyncMetadata(db);
          await _installSyncRevisionTriggers(db);
        }
      },
    );
    await _database!.execute('PRAGMA foreign_keys = ON;');
  }

  Future<void> _createTables(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS expenses (
        expense_id INTEGER PRIMARY KEY AUTOINCREMENT,
        item_name TEXT,
        unit TEXT,
        quantity REAL,
        price REAL,
        total_price REAL,
        consumption REAL DEFAULT 0,
        remaining REAL DEFAULT 0,
        is_miscellaneous INTEGER DEFAULT 0,
        is_drink INTEGER DEFAULT 0,
        date TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS members (
        member_id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT,
        rank TEXT,
        contribution REAL,
        total_due REAL DEFAULT 0,
        date TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS meals (
        meal_id INTEGER PRIMARY KEY AUTOINCREMENT,
        meal_type TEXT,
        date TEXT,
        total_cost REAL,
        misc_total REAL DEFAULT 0
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS meal_items (
        meal_item_id INTEGER PRIMARY KEY AUTOINCREMENT,
        meal_id INTEGER,
        item_name TEXT,
        quantity_used REAL,
        price_at_time REAL,
        FOREIGN KEY (meal_id) REFERENCES meals(meal_id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS meal_records (
        meal_record_id INTEGER PRIMARY KEY AUTOINCREMENT,
        meal_type TEXT,
        date TEXT,
        member_id INTEGER,
        final_cost REAL,
        meal_id INTEGER,
        is_legacy INTEGER DEFAULT 1,
        FOREIGN KEY (member_id) REFERENCES members(member_id),
        FOREIGN KEY (meal_id) REFERENCES meals(meal_id)
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS drink_records (
        drink_record_id INTEGER PRIMARY KEY AUTOINCREMENT,
        date TEXT,
        drink_name TEXT,
        member_id INTEGER,
        quantity INTEGER,
        total_cost REAL,
        FOREIGN KEY (member_id) REFERENCES members(member_id)
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS miscellaneous_expenses (
        misc_expense_id INTEGER PRIMARY KEY AUTOINCREMENT,
        date TEXT,
        amount REAL,
        meal_type TEXT,
        meal_record_id INTEGER,
        member_id INTEGER,
        FOREIGN KEY (meal_record_id) REFERENCES meal_records(meal_record_id) ON DELETE CASCADE,
        FOREIGN KEY (member_id) REFERENCES members(member_id)
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS miscellaneous_contributions (
        misc_contribution_id INTEGER PRIMARY KEY AUTOINCREMENT,
        member_id INTEGER,
        misc_amount REAL,
        meal_count INTEGER DEFAULT 0,
        distribution_date TEXT,
        FOREIGN KEY (member_id) REFERENCES members(member_id)
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS archive_keys (
        archive_key_id INTEGER PRIMARY KEY AUTOINCREMENT,
        archive_name TEXT,
        start_date TEXT,
        end_date TEXT,
        archived_at TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS monthly_closures (
        closure_id INTEGER PRIMARY KEY AUTOINCREMENT,
        closure_date TEXT,
        year INTEGER,
        month INTEGER,
        archive_key_id INTEGER,
        FOREIGN KEY (archive_key_id) REFERENCES archive_keys(archive_key_id)
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS closure_summary (
        summary_id INTEGER PRIMARY KEY AUTOINCREMENT,
        closure_id INTEGER,
        member_id INTEGER,
        total_meals REAL,
        total_drinks REAL,
        total_miscellaneous REAL,
        total_consumption REAL,
        total_contribution REAL,
        remaining_cash REAL,
        FOREIGN KEY (closure_id) REFERENCES monthly_closures(closure_id),
        FOREIGN KEY (member_id) REFERENCES members(member_id)
      )
    ''');

    await _createArchiveTables(db);
  }

  Future<void> _ensureSyncMetadata(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS sync_metadata (
        id INTEGER PRIMARY KEY CHECK (id = 1),
        updated_at TEXT NOT NULL
      )
    ''');
    await db.rawInsert(
      "INSERT OR IGNORE INTO sync_metadata (id, updated_at) VALUES (1, datetime('now'))",
    );
  }

  Future<void> _installSyncRevisionTriggers(Database db) async {
    const tables = [
      'expenses',
      'members',
      'meals',
      'meal_items',
      'meal_records',
      'drink_records',
      'miscellaneous_expenses',
      'miscellaneous_contributions',
      'archive_keys',
      'monthly_closures',
      'closure_summary',
      'closure_summary_archive',
      'expenses_archive',
      'members_archive',
      'meal_records_archive',
      'drink_records_archive',
      'miscellaneous_expenses_archive',
      'miscellaneous_contributions_archive',
      'monthly_totals_archive',
    ];
    for (final table in tables) {
      final triggerName = 'sync_bump_$table';
      await db.execute('DROP TRIGGER IF EXISTS $triggerName');
      await db.execute('''
        CREATE TRIGGER $triggerName
        AFTER INSERT ON $table
        BEGIN
          UPDATE sync_metadata SET updated_at = datetime('now') WHERE id = 1;
        END
      ''');
      await db.execute('DROP TRIGGER IF EXISTS ${triggerName}_upd');
      await db.execute('''
        CREATE TRIGGER ${triggerName}_upd
        AFTER UPDATE ON $table
        BEGIN
          UPDATE sync_metadata SET updated_at = datetime('now') WHERE id = 1;
        END
      ''');
      await db.execute('DROP TRIGGER IF EXISTS ${triggerName}_del');
      await db.execute('''
        CREATE TRIGGER ${triggerName}_del
        AFTER DELETE ON $table
        BEGIN
          UPDATE sync_metadata SET updated_at = datetime('now') WHERE id = 1;
        END
      ''');
    }
  }

  Future<DateTime?> getLocalRevisionTime() async {
    if (_database == null || !_database!.isOpen) await initializeDatabase();
    final row = await _database!.rawQuery(
      'SELECT updated_at FROM sync_metadata WHERE id = 1 LIMIT 1',
    );
    if (row.isEmpty) return null;
    final raw = row.first['updated_at'] as String?;
    if (raw == null) return null;
    return DateTime.tryParse(raw);
  }

  Future<void> touchLocalRevision() async {
    if (_database == null || !_database!.isOpen) await initializeDatabase();
    await _database!.rawUpdate(
      "UPDATE sync_metadata SET updated_at = datetime('now') WHERE id = 1",
    );
  }

  Future<void> _createArchiveTables(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS closure_summary_archive (
        summary_id INTEGER,
        closure_id INTEGER,
        member_id INTEGER,
        total_meals REAL,
        total_drinks REAL,
        total_miscellaneous REAL,
        total_consumption REAL,
        total_contribution REAL,
        remaining_cash REAL,
        archive_key_id INTEGER,
        PRIMARY KEY (summary_id, archive_key_id),
        FOREIGN KEY (archive_key_id) REFERENCES archive_keys(archive_key_id)
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS expenses_archive (
        expense_id INTEGER,
        item_name TEXT,
        unit TEXT,
        quantity REAL,
        price REAL,
        total_price REAL,
        consumption REAL DEFAULT 0,
        remaining REAL DEFAULT 0,
        is_miscellaneous INTEGER DEFAULT 0,
        is_drink INTEGER DEFAULT 0,
        date TEXT,
        archive_key_id INTEGER,
        PRIMARY KEY (expense_id, archive_key_id),
        FOREIGN KEY (archive_key_id) REFERENCES archive_keys(archive_key_id)
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS members_archive (
        member_id INTEGER,
        name TEXT,
        rank TEXT,
        contribution REAL,
        total_due REAL,
        date TEXT,
        archive_key_id INTEGER,
        PRIMARY KEY (member_id, archive_key_id),
        FOREIGN KEY (archive_key_id) REFERENCES archive_keys(archive_key_id)
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS meal_records_archive (
        meal_record_id INTEGER,
        meal_type TEXT,
        date TEXT,
        member_id INTEGER,
        final_cost REAL,
        archive_key_id INTEGER,
        meal_id INTEGER,
        is_legacy INTEGER DEFAULT 1,
        PRIMARY KEY (meal_record_id, archive_key_id),
        FOREIGN KEY (archive_key_id) REFERENCES archive_keys(archive_key_id)
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS drink_records_archive (
        drink_record_id INTEGER,
        date TEXT,
        drink_name TEXT,
        member_id INTEGER,
        quantity INTEGER,
        total_cost REAL,
        archive_key_id INTEGER,
        PRIMARY KEY (drink_record_id, archive_key_id),
        FOREIGN KEY (archive_key_id) REFERENCES archive_keys(archive_key_id)
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS miscellaneous_expenses_archive (
        misc_expense_id INTEGER,
        date TEXT,
        amount REAL,
        meal_type TEXT,
        meal_record_id INTEGER,
        archive_key_id INTEGER,
        PRIMARY KEY (misc_expense_id, archive_key_id),
        FOREIGN KEY (archive_key_id) REFERENCES archive_keys(archive_key_id)
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS miscellaneous_contributions_archive (
        misc_contribution_id INTEGER,
        member_id INTEGER,
        misc_amount REAL,
        meal_count INTEGER,
        distribution_date TEXT,
        archive_key_id INTEGER,
        PRIMARY KEY (misc_contribution_id, archive_key_id),
        FOREIGN KEY (archive_key_id) REFERENCES archive_keys(archive_key_id)
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS monthly_totals_archive (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        archive_key_id INTEGER,
        total_meals INTEGER,
        total_drinks INTEGER,
        total_misc REAL,
        total_consumption REAL,
        total_contributions REAL,
        remaining_items REAL,
        remaining_cash REAL,
        recorded_at TEXT DEFAULT CURRENT_TIMESTAMP,
        FOREIGN KEY (archive_key_id) REFERENCES archive_keys(archive_key_id)
      )
    ''');
  }

  Future<void> _runMigrations(Database db) async {
    try {
      // Check and add columns for miscellaneous_expenses
      var columns = await db.rawQuery('PRAGMA table_info(miscellaneous_expenses)');
      var columnNames = columns.map((col) => col['name'] as String).toList();
      if (!columnNames.contains('meal_record_id')) {
        await db.execute('ALTER TABLE miscellaneous_expenses ADD COLUMN meal_record_id INTEGER');
      }
      if (!columnNames.contains('member_id')) {
        await db.execute('ALTER TABLE miscellaneous_expenses ADD COLUMN member_id INTEGER REFERENCES members(member_id)');
      }

      // Check and add columns for miscellaneous_contributions
      columns = await db.rawQuery('PRAGMA table_info(miscellaneous_contributions)');
      columnNames = columns.map((col) => col['name'] as String).toList();
      if (!columnNames.contains('meal_count')) {
        await db.execute('ALTER TABLE miscellaneous_contributions ADD COLUMN meal_count INTEGER DEFAULT 0');
      }
      if (!columnNames.contains('distribution_date')) {
        await db.execute('ALTER TABLE miscellaneous_contributions ADD COLUMN distribution_date TEXT');
      }

      // Check and add unit column for expenses
      columns = await db.rawQuery('PRAGMA table_info(expenses)');
      columnNames = columns.map((col) => col['name'] as String).toList();
      if (!columnNames.contains('unit')) {
        await db.execute('ALTER TABLE expenses ADD COLUMN unit TEXT');
        AppLogger.logInfo('Added unit column to expenses table');
      }

      // Check and add unit column for expenses_archive
      columns = await db.rawQuery('PRAGMA table_info(expenses_archive)');
      columnNames = columns.map((col) => col['name'] as String).toList();
      if (!columnNames.contains('unit')) {
        await db.execute('ALTER TABLE expenses_archive ADD COLUMN unit TEXT');
        AppLogger.logInfo('Added unit column to expenses_archive table');
      }

      // Migration for decimal quantities - check if quantity column is still INTEGER
      columns = await db.rawQuery('PRAGMA table_info(expenses)');
      var expenseColumns = columns.map((col) => {
        'name': col['name'] as String,
        'type': col['type'] as String
      }).toList();
      
      var quantityColumn = expenseColumns.firstWhere((col) => col['name'] == 'quantity', orElse: () => {});
      if (quantityColumn.isNotEmpty && quantityColumn['type'] == 'INTEGER') {
        AppLogger.logInfo('Migrating quantity columns from INTEGER to REAL');
        
        // Create temporary table with new schema
        await db.execute('''
          CREATE TABLE expenses_temp (
            expense_id INTEGER PRIMARY KEY AUTOINCREMENT,
            item_name TEXT,
            unit TEXT,
            quantity REAL,
            price REAL,
            total_price REAL,
            consumption REAL DEFAULT 0,
            remaining REAL DEFAULT 0,
            is_miscellaneous INTEGER DEFAULT 0,
            is_drink INTEGER DEFAULT 0,
            date TEXT
          )
        ''');
        
        // Copy data from old table to new table
        await db.execute('''
          INSERT INTO expenses_temp 
          SELECT expense_id, item_name, unit, CAST(quantity AS REAL), price, total_price, 
                 CAST(consumption AS REAL), CAST(remaining AS REAL), 
                 is_miscellaneous, is_drink, date 
          FROM expenses
        ''');
        
        // Drop old table
        await db.execute('DROP TABLE expenses');
        
        // Rename temporary table
        await db.execute('ALTER TABLE expenses_temp RENAME TO expenses');
        
        AppLogger.logInfo('Successfully migrated expenses table to use REAL quantities');
      }

      // Check and add meal_id and is_legacy columns to meal_records
      columns = await db.rawQuery('PRAGMA table_info(meal_records)');
      columnNames = columns.map((col) => col['name'] as String).toList();
      if (!columnNames.contains('meal_id')) {
        await db.execute('ALTER TABLE meal_records ADD COLUMN meal_id INTEGER REFERENCES meals(meal_id)');
        AppLogger.logInfo('Added meal_id column to meal_records table');
      }
      if (!columnNames.contains('is_legacy')) {
        await db.execute('ALTER TABLE meal_records ADD COLUMN is_legacy INTEGER DEFAULT 1');
        AppLogger.logInfo('Added is_legacy column to meal_records table');
      }

      // Check and add meal_id column to meal_records_archive
      columns = await db.rawQuery('PRAGMA table_info(meal_records_archive)');
      columnNames = columns.map((col) => col['name'] as String).toList();
      if (!columnNames.contains('meal_id')) {
        await db.execute('ALTER TABLE meal_records_archive ADD COLUMN meal_id INTEGER');
        AppLogger.logInfo('Added meal_id column to meal_records_archive table');
      }
      if (!columnNames.contains('is_legacy')) {
        await db.execute('ALTER TABLE meal_records_archive ADD COLUMN is_legacy INTEGER DEFAULT 1');
        AppLogger.logInfo('Added is_legacy column to meal_records_archive table');
      }

      // Create retroactive meal_ids for existing meal_records
      final existingMealRecords = await db.rawQuery('''
        SELECT meal_record_id, meal_type, date FROM meal_records WHERE meal_id IS NULL
      ''');
      
      if (existingMealRecords.isNotEmpty) {
        AppLogger.logInfo('Creating retroactive meal_ids for ${existingMealRecords.length} meal records');
        
        // Group meal_records by date and meal_type
        final Map<String, List<int>> mealGroups = {};
        for (final record in existingMealRecords) {
          final key = '${record['date']}_${record['meal_type']}';
          final mealRecordId = record['meal_record_id'] as int;
          if (!mealGroups.containsKey(key)) {
            mealGroups[key] = [];
          }
          mealGroups[key]!.add(mealRecordId);
        }
        
        // Create meals and update meal_records
        for (final entry in mealGroups.entries) {
          final parts = entry.key.split('_');
          final date = parts[0];
          final mealType = parts[1];
          final mealRecordIds = entry.value;
          
          // Calculate total cost for this meal group
          final totalCostResult = await db.rawQuery('''
            SELECT SUM(final_cost) as total_cost FROM meal_records 
            WHERE meal_record_id IN (${mealRecordIds.join(',')})
          ''');
          
          final totalCost = asDouble(totalCostResult.first['total_cost'], 0.0);
          
          // Insert into meals table
          final mealId = await db.rawInsert('''
            INSERT INTO meals (meal_type, date, total_cost) VALUES (?, ?, ?)
          ''', [mealType, date, totalCost]);
          
          // Update meal_records with meal_id and set is_legacy=0
          await db.rawUpdate('''
            UPDATE meal_records SET meal_id = ?, is_legacy = 0 
            WHERE meal_record_id IN (${mealRecordIds.join(',')})
          ''', [mealId]);
        }
        
        // For any remaining meal_records without meal_id, set is_legacy=1
        await db.rawUpdate('''
          UPDATE meal_records SET is_legacy = 1 WHERE meal_id IS NULL
        ''');
        
        AppLogger.logInfo('Successfully created retroactive meal_ids');
      }

      // Check and add year and month columns to monthly_closures
      columns = await db.rawQuery('PRAGMA table_info(monthly_closures)');
      columnNames = columns.map((col) => col['name'] as String).toList();
      if (!columnNames.contains('year')) {
        await db.execute('ALTER TABLE monthly_closures ADD COLUMN year INTEGER');
        AppLogger.logInfo('Added year column to monthly_closures table');
      }
      if (!columnNames.contains('month')) {
        await db.execute('ALTER TABLE monthly_closures ADD COLUMN month INTEGER');
        AppLogger.logInfo('Added month column to monthly_closures table');
      }

      // Populate year and month columns from closure_date for existing records
      final existingClosures = await db.rawQuery('''
        SELECT closure_id, closure_date FROM monthly_closures WHERE year IS NULL OR month IS NULL
      ''');
      
      if (existingClosures.isNotEmpty) {
        AppLogger.logInfo('Populating year and month columns for ${existingClosures.length} monthly closures');
        
        for (final closure in existingClosures) {
          final closureId = closure['closure_id'] as int;
          final closureDate = closure['closure_date'] as String?;
          
          if (closureDate != null && closureDate.isNotEmpty) {
            try {
              final date = DateTime.parse(closureDate);
              await db.rawUpdate(
                'UPDATE monthly_closures SET year = ?, month = ? WHERE closure_id = ?',
                [date.year, date.month, closureId],
              );
            } catch (e) {
              AppLogger.logError('Error parsing closure date $closureDate: $e');
            }
          }
        }
        
        AppLogger.logInfo('Successfully populated year and month columns for monthly closures');
      }

    } catch (e) {
      AppLogger.logError('Error during migrations: $e');
    }
  }

  Future<void> executeQuery(String query, [List<dynamic>? params]) async {
    try {
      if (_database == null || !_database!.isOpen) await initializeDatabase();
      await _database!.execute(query, params);
    } catch (e) {
      AppLogger.logError('Error executing query: $e');
    }
  }

  Future<List<Map<String, dynamic>>> fetchAll(String query, [List<dynamic>? params]) async {
    try {
      if (_database == null || !_database!.isOpen) await initializeDatabase();
      return await _database!.rawQuery(query, params);
    } catch (e) {
      AppLogger.logError('Error fetching data: $e');
      return [];
    }
  }

  Future<Map<String, dynamic>?> fetchOne(String query, [List<dynamic>? params]) async {
    try {
      if (_database == null || !_database!.isOpen) await initializeDatabase();
      final result = await _database!.rawQuery(query, params);
      return result.isNotEmpty ? result.first : null;
    } catch (e) {
      AppLogger.logError('Error fetching single record: $e');
      return null;
    }
  }

  Future<void> transaction(Function(DatabaseExecutor) transactionBlock) async {
    try {
      if (_database == null || !_database!.isOpen) await initializeDatabase();
      await _database!.transaction((txn) async {
        await transactionBlock(txn);
      });
    } catch (e) {
      AppLogger.logError('Error during transaction: $e');
      rethrow;
    }
  }

  Future<void> close() async {
    await _database?.close();
  }

  Future<String?> getFirstTransactionDate(DatabaseExecutor db) async {
    try {
      final queries = [
        "SELECT MIN(date) FROM meal_records",
        "SELECT MIN(date) FROM drink_records",
        "SELECT MIN(date) FROM expenses",
      ];

      final dates = <String>[];
      for (final q in queries) {
        final result = await db.rawQuery(q);
        final date = result.first.values.first as String?;
        if (date != null) {
          dates.add(date);
        }
      }

      final minDate = dates.isNotEmpty
          ? dates.reduce((a, b) => a.compareTo(b) < 0 ? a : b)
          : null;
      AppLogger.logInfo("First transaction date: $minDate");
      return minDate;
    } catch (e) {
      AppLogger.logError("Error getting first transaction date: $e");
      return null;
    }
  }

  Future<int?> getOrCreateArchiveKey(DatabaseExecutor db, String firstDate) async {
    try {
      final existing = await db.rawQuery(
        "SELECT archive_key_id FROM archive_keys WHERE start_date <= ? AND (end_date IS NULL OR end_date >= ?)",
        [firstDate, firstDate],
      );

      final nowDate = DateFormat('yyyy-MM-dd').format(DateTime.now());
      final nowDt = DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now());

      if (existing.isNotEmpty) {
        final keyId = existing.first['archive_key_id'] as int;
        await db.rawUpdate(
          "UPDATE archive_keys SET end_date = ?, archived_at = ? WHERE archive_key_id = ? AND end_date IS NULL",
          [nowDate, nowDt, keyId],
        );
        AppLogger.logInfo("Updated existing archive key: $keyId");
        return keyId;
      } else {
        final archiveName = "Dist_${firstDate}_to_$nowDate";
        final keyId = await db.rawInsert(
          "INSERT INTO archive_keys (archive_name, start_date, end_date, archived_at) VALUES (?, ?, ?, ?)",
          [archiveName, firstDate, nowDate, nowDt],
        );
        AppLogger.logInfo("Created new archive key: $keyId");
        return keyId;
      }
    } catch (e) {
      AppLogger.logError("Error creating archive key: $e");
      return null;
    }
  }

  Future<int?> getMealIdForRecord(int mealRecordId) async {
    try {
      if (_database == null || !_database!.isOpen) await initializeDatabase();
      final result = await _database!.rawQuery(
        'SELECT meal_id FROM meal_records WHERE meal_record_id = ?',
        [mealRecordId],
      );
      return result.isNotEmpty ? result.first['meal_id'] as int? : null;
    } catch (e) {
      AppLogger.logError('Error getting meal_id for record $mealRecordId: $e');
      return null;
    }
  }

  Future<bool> reverseMealEffects(int mealId) async {
    try {
      if (_database == null || !_database!.isOpen) await initializeDatabase();
      
      await _database!.transaction((txn) async {
        // Get all meal items for this meal
        final mealItems = await txn.rawQuery(
          'SELECT item_name, quantity_used FROM meal_items WHERE meal_id = ?',
          [mealId],
        );
        
        // Reverse consumption in expenses
        for (final item in mealItems) {
          final itemName = item['item_name'] as String;
          final quantityUsed = asDouble(item['quantity_used']);

          await txn.rawUpdate(
            'UPDATE expenses SET consumption = consumption - ?, remaining = remaining + ? WHERE item_name = ?',
            [quantityUsed, quantityUsed, itemName],
          );
        }

        // Get all meal records for this meal
        final mealRecords = await txn.rawQuery(
          'SELECT member_id, final_cost FROM meal_records WHERE meal_id = ?',
          [mealId],
        );

        // Reverse member dues
        for (final record in mealRecords) {
          final memberId = asInt(record['member_id']);
          final finalCost = asDouble(record['final_cost']);

          await txn.rawUpdate(
            'UPDATE members SET total_due = total_due - ? WHERE member_id = ?',
            [finalCost, memberId],
          );
        }
        
        // Delete miscellaneous expenses linked to this meal's records
        await txn.rawDelete(
          'DELETE FROM miscellaneous_expenses WHERE meal_record_id IN (SELECT meal_record_id FROM meal_records WHERE meal_id = ?)',
          [mealId],
        );
        
        // Delete meal records
        await txn.rawDelete(
          'DELETE FROM meal_records WHERE meal_id = ?',
          [mealId],
        );
        
        // Delete meal items
        await txn.rawDelete(
          'DELETE FROM meal_items WHERE meal_id = ?',
          [mealId],
        );
        
        // Delete the meal itself
        await txn.rawDelete(
          'DELETE FROM meals WHERE meal_id = ?',
          [mealId],
        );
      });
      
      AppLogger.logInfo('Successfully reversed meal effects for meal_id: $mealId');
      return true;
    } catch (e) {
      AppLogger.logError('Error reversing meal effects for meal_id $mealId: $e');
      return false;
    }
  }
}