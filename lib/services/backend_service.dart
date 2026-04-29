import 'package:flutter/services.dart';
import 'dart:typed_data';

class BackendService {
  static const platform = MethodChannel('focus_minimalism/enforcement');

  Future<bool> checkPermissions() async {
    try {
      return await platform.invokeMethod('checkPermissions');
    } catch (e) {
      return false;
    }
  }

  Future<void> openSettings() async {
    try {
      await platform.invokeMethod('openSettings');
    } catch (e) {
      print(e);
    }
  }

  Future<Map<String, dynamic>> fetchDashboardStats() async {
    try {
      final Map<dynamic, dynamic>? result = await platform.invokeMethod('getDashboardStats');
      return result != null ? Map<String, dynamic>.from(result) : {};
    } catch (e) {
      return {};
    }
  }

  Future<Map<String, dynamic>> fetchAppUsage() async {
    try {
      final Map<dynamic, dynamic>? result = await platform.invokeMethod('getAppUsage');
      return result != null ? Map<String, dynamic>.from(result) : {"total_daily_seconds": 0, "apps": []};
    } catch (e) {
      return {"total_daily_seconds": 0, "apps": []};
    }
  }

  Future<Map<String, dynamic>> getInsightsTrends() async {
    try {
      final Map<dynamic, dynamic>? result = await platform.invokeMethod('getInsightsTrends');
      return result != null ? Map<String, dynamic>.from(result) : {"daily": [], "weekly": [], "monthly": []};
    } catch (e) {
      return {"daily": [], "weekly": [], "monthly": []};
    }
  }

  Future<Map<String, dynamic>> getUserProfile() async {
    try {
      final Map<dynamic, dynamic>? result = await platform.invokeMethod('getUserProfile');
      return result != null ? Map<String, dynamic>.from(result) : {"name": "Alex", "goal_seconds": 7200};
    } catch (e) {
      return {"name": "Alex", "goal_seconds": 7200};
    }
  }

  Future<bool> saveUserSettings(String name, int goalSeconds) async {
    try {
      return await platform.invokeMethod('saveUserSettings', {'name': name, 'goal_seconds': goalSeconds});
    } catch (e) {
      return false;
    }
  }

  Future<bool> updateAppSelection(String pkg, bool isWhite, bool isBlack) async {
    try {
      return await platform.invokeMethod('updateAppSelection', {'package_name': pkg, 'is_whitelisted': isWhite, 'is_blacklisted': isBlack});
    } catch (e) {
      return false;
    }
  }

  Future<Map<String, dynamic>> getAppSelections() async {
    try {
      final Map<dynamic, dynamic>? result = await platform.invokeMethod('getAppSelections');
      return result != null ? Map<String, dynamic>.from(result) : {"whitelist": [], "blacklist": []};
    } catch (e) {
      return {"whitelist": [], "blacklist": []};
    }
  }

  Future<bool> startFocusMode(int durationMinutes) async {
    try {
      return await platform.invokeMethod('startFocusMode', {'duration_minutes': durationMinutes});
    } catch (e) {
      return false;
    }
  }

  Future<bool> stopFocusMode() async {
    try {
      return await platform.invokeMethod('stopFocusMode');
    } catch (e) {
      return false;
    }
  }

  Future<Map<String, dynamic>> getRewardsData() async {
    try {
      final Map<dynamic, dynamic>? result = await platform.invokeMethod('getRewardsData');
      return result != null ? Map<String, dynamic>.from(result) : {"points": 0, "streak": 0, "badges": []};
    } catch (e) {
      return {"points": 0, "streak": 0, "badges": []};
    }
  }

  Future<List<String>> fetchInsights() async {
    try {
      final List<dynamic>? result = await platform.invokeListMethod('getInsights');
      return result?.map((e) => e.toString()).toList() ?? [];
    } catch (e) {
      return [];
    }
  }
}
