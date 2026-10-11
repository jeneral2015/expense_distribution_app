import 'dart:async';
import 'package:flutter/material.dart';

class UndoAction {
  final String type; // 'meal', 'drink', 'misc'
  final int id;
  final Map<String, dynamic> data;
  final DateTime timestamp;

  UndoAction({
    required this.type,
    required this.id,
    required this.data,
    required this.timestamp,
  });

  Map<String, dynamic> toMap() {
    return {
      'type': type,
      'id': id,
      'data': data,
      'timestamp': timestamp.toIso8601String(),
    };
  }

  factory UndoAction.fromMap(Map<String, dynamic> map) {
    return UndoAction(
      type: map['type'],
      id: map['id'],
      data: Map<String, dynamic>.from(map['data']),
      timestamp: DateTime.parse(map['timestamp']),
    );
  }
}

class UndoManager {
  static final UndoManager _instance = UndoManager._internal();
  factory UndoManager() => _instance;
  UndoManager._internal();

  final List<UndoAction> _actions = [];
  Timer? _cleanupTimer;

  List<UndoAction> get actions => List.unmodifiable(_actions);

  void addAction(UndoAction action) {
    _actions.add(action);
    _startCleanupTimer();
  }

  // تعديل جذري: إرجاع الإجراء المُلغى مع إزالة من المكدس
  UndoAction? undoLast() {
    if (_actions.isEmpty) return null;
    return _actions.removeLast();
  }

  void clearExpiredActions() {
    final now = DateTime.now();
    _actions.removeWhere((action) => 
        now.difference(action.timestamp).inMinutes > 5);
  }

  void _startCleanupTimer() {
    _cleanupTimer?.cancel();
    _cleanupTimer = Timer.periodic(const Duration(minutes: 1), (timer) {
      clearExpiredActions();
      if (_actions.isEmpty) {
        timer.cancel();
        _cleanupTimer = null;
      }
    });
  }

  // تعديل مهم: دعم دالة onUndo مع سياق الحذف
  void showUndoSnackbar(
    BuildContext context, 
    String message, 
    VoidCallback onUndo,
    {Duration duration = const Duration(seconds: 5)}
  ) {
    final snackBar = SnackBar(
      content: Text(
        message,
        style: const TextStyle(fontSize: 16),
      ),
      duration: duration,
      action: SnackBarAction(
        label: 'تراجع',
        textColor: Colors.white,
        onPressed: () {
          ScaffoldMessenger.of(context).hideCurrentSnackBar();
          onUndo();
        },
      ),
      backgroundColor: Colors.blue[700],
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
      ),
    );

    ScaffoldMessenger.of(context).showSnackBar(snackBar);
  }

  void dispose() {
    _cleanupTimer?.cancel();
    _actions.clear();
  }
}
