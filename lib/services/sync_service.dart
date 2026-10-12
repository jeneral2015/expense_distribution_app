import 'package:cloud_firestore/cloud_firestore.dart';

import '../utils/database.dart';
import '../utils/logger.dart';

/// مزامنة كاملة للجداول مع Firestore دون تغيير منطق الصفحات.
class SyncService {
  SyncService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  static const syncTables = [
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

  DocumentReference<Map<String, dynamic>> _metaRef(String userId) =>
      _firestore.collection('users').doc(userId).collection('meta').doc('sync');

  DocumentReference<Map<String, dynamic>> _tableRef(
          String userId, String table) =>
      _firestore.collection('users').doc(userId).collection('tables').doc(table);

  Future<DateTime?> getRemoteUpdatedAt(String userId) async {
    final snap = await _metaRef(userId).get();
    if (!snap.exists) return null;
    final ts = snap.data()?['updatedAt'];
    if (ts is Timestamp) return ts.toDate();
    return null;
  }

  Future<bool> hasRemoteData(String userId) async {
    final meta = await _metaRef(userId).get();
    if (meta.exists && meta.data()?['hasData'] == true) return true;
    for (final table in syncTables) {
      final doc = await _tableRef(userId, table).get();
      final rows = doc.data()?['rows'];
      if (rows is List && rows.isNotEmpty) return true;
    }
    return false;
  }

  Future<void> uploadLocal(String userId, DatabaseManager db) async {
    if (db.database == null) await db.initializeDatabase();
    final database = db.database!;
    final batch = _firestore.batch();
    final payload = <String, List<Map<String, dynamic>>>{};

    for (final table in syncTables) {
      final rows = await database.rawQuery('SELECT * FROM $table');
      payload[table] = rows.map((r) => _serializeRow(r)).toList();
      batch.set(_tableRef(userId, table), {
        'rows': payload[table],
        'rowCount': payload[table]!.length,
      });
    }

    batch.set(_metaRef(userId), {
      'updatedAt': FieldValue.serverTimestamp(),
      'hasData': true,
      'tableCount': syncTables.length,
    });

    await batch.commit();
    AppLogger.logInfo('Uploaded local database to Firestore for $userId');
  }

  Future<void> downloadToLocal(String userId, DatabaseManager db) async {
    if (db.database == null) await db.initializeDatabase();
    final database = db.database!;

    await database.transaction((txn) async {
      await txn.execute('PRAGMA foreign_keys = OFF');
      for (final table in syncTables.reversed) {
        await txn.delete(table);
      }
      for (final table in syncTables) {
        final snap = await _tableRef(userId, table).get();
        final rows = snap.data()?['rows'];
        if (rows is! List) continue;
        for (final raw in rows) {
          if (raw is! Map) continue;
          final row = Map<String, dynamic>.from(raw);
          await txn.insert(table, row);
        }
      }
      await txn.execute('PRAGMA foreign_keys = ON');
    });

    AppLogger.logInfo('Downloaded Firestore data into local DB for $userId');
  }

  Map<String, dynamic> _serializeRow(Map<String, dynamic> row) {
    final out = <String, dynamic>{};
    row.forEach((key, value) {
      if (value is num || value is String || value == null) {
        out[key] = value;
      } else {
        out[key] = value.toString();
      }
    });
    return out;
  }
}
