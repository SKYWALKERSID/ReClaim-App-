import 'dart:convert';
import 'package:home_widget/home_widget.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'backend_service.dart';

class WidgetSyncService {
  static String _groupId = 'group.com.reclaim.app';
  static String _widgetName = 'ReclaimWidget';
  static String _storageKey = 'widget_data';
  static String _pendingKey = 'widget_pending_completions';
  
  final BackendService _backend = BackendService();
  final FlutterSecureStorage _secureStorage = FlutterSecureStorage();

  /// Syncs current habit data and AI nudge to the Android widget.
  Future<void> syncWidgetData() async {
    try {
      // 1. Fetch fresh data from backend
      final habits = await _backend.getHabits();
      final nudgeResult = await _backend.getWidgetNudge();
      
      // 2. Prepare JSON for the widget
      final data = {
        'habits': habits.map((h) => {
          'id': h['id'],
          'name': h['name'],
          'isCompleted': h['isCompleted'] ?? false,
          'streak': h['streak'] ?? 0,
        }).toList(),
        'nudge': nudgeResult['nudge'] ?? "Ready for today's win?",
        'lastSync': DateTime.now().toIso8601String(),
      };

      // 3. Write to shared storage for Glance to read
      await HomeWidget.saveWidgetData(_storageKey, jsonEncode(data));
      
      // 4. Trigger widget update
      await HomeWidget.updateWidget(
        name: _widgetName,
        androidName: _widgetName,
      );
      
      print('Widget synced successfully');
    } catch (e) {
      print('Widget sync failed: $e');
    }
  }

  /// Securely saves the session token for background tasks.
  /// Fixes BUG 17: Never pass token in WorkManager inputData.
  Future<void> saveSessionToken(String token) async {
    await _secureStorage.write(key: 'bg_session_token', value: token);
  }

  /// Clears widget data on logout.
  /// Fixes BUG 18: Prevent data leakage after session end.
  Future<void> clearOnLogout() async {
    await HomeWidget.saveWidgetData(_storageKey, null);
    await HomeWidget.saveWidgetData(_pendingKey, null);
    await _secureStorage.delete(key: 'bg_session_token');
    await HomeWidget.updateWidget(name: _widgetName);
  }
}
