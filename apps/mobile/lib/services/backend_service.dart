import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class BackendService {
  static const platform = MethodChannel('reclaim/enforcement');
  
  static String? _jwtToken;
  static String? _userId;

  static String get baseUrl {
    return const String.fromEnvironment('FOCUS_API_URL', defaultValue: 'http://10.0.2.2:4000/v1');
  }

  static Future<void> initialize() async {
    final prefs = await SharedPreferences.getInstance();
    _jwtToken = prefs.getString('jwt_token');
    _userId = prefs.getString('user_id');
    
    if (_jwtToken == null) {
      await _authenticateAnonymous();
    }
  }

  static Future<void> _authenticateAnonymous() async {
    try {
      final response = await http.post(
        Uri.parse('${BackendService.baseUrl}/auth/anonymous'),
        headers: {'Content-Type': 'application/json'},
      ).timeout(const Duration(seconds: 10));
      
      if (response.statusCode == 201) {
        final data = json.decode(response.body);
        _jwtToken = data['token'];
        _userId = data['userId'];
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('jwt_token', _jwtToken!);
        await prefs.setString('user_id', _userId!);
      }
    } catch (e) {
      debugPrint('Auth error: $e');
    }
  }

  Map<String, String> get _headers => {
    'Content-Type': 'application/json',
    if (_jwtToken != null) 'Authorization': 'Bearer $_jwtToken',
  };

  // ─── Native Platform Methods (MethodChannel) ───

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
      debugPrint("openSettings error: $e");
    }
  }

  Future<Map<String, dynamic>> getPermissionStatus() async {
    try {
      final dynamic result = await platform.invokeMethod('getPermissionStatus');
      if (result == null || result is! Map) return {};
      return Map<String, dynamic>.from(result);
    } catch (e) {
      debugPrint("getPermissionStatus error: $e");
      return {};
    }
  }

  Future<void> openPermissionSettings(String permission) async {
    try {
      await platform.invokeMethod('openPermissionSettings', {'permission': permission});
    } catch (e) {
      debugPrint("openPermissionSettings($permission) error: $e");
    }
  }

  Future<Map<String, dynamic>> fetchDashboardStats() async {
    try {
      final dynamic result = await platform.invokeMethod('getDashboardStats');
      if (result == null || result is! Map) return {};
      return Map<String, dynamic>.from(result);
    } catch (e) {
      return {};
    }
  }

  Future<Map<String, dynamic>> fetchAppUsage() async {
    try {
      final dynamic result = await platform.invokeMethod('getAppUsage');
      if (result == null || result is! Map) return {"total_daily_seconds": 0, "apps": []};
      return {
        "total_daily_seconds": (result["total_daily_seconds"] as num?)?.toInt() ?? 0,
        "apps": List<Map<dynamic, dynamic>>.from(result["apps"] ?? []),
      };
    } catch (e) {
      return {"total_daily_seconds": 0, "apps": []};
    }
  }

  Future<Map<String, dynamic>> getInsightsTrends() async {
    try {
      final dynamic result = await platform.invokeMethod('getInsightsTrends');
      if (result == null || result is! Map) return {"daily": [], "weekly": [], "monthly": []};
      return {
        "daily": List<int>.from(result["daily"] ?? []),
        "weekly": List<int>.from(result["weekly"] ?? []),
        "monthly": List<int>.from(result["monthly"] ?? []),
      };
    } catch (e) {
      return {"daily": [], "weekly": [], "monthly": []};
    }
  }

  Future<Map<String, dynamic>> getUserProfile() async {
    try {
      final dynamic result = await platform.invokeMethod('getUserProfile');
      if (result == null || result is! Map) return {"name": "[ENTER_NAME]", "goal_seconds": 7200};
      return {
        "name": result["name"]?.toString() ?? "[ENTER_NAME]",
        "goal_seconds": (result["goal_seconds"] as num?)?.toInt() ?? 7200
      };
    } catch (e) {
      return {"name": "[ENTER_NAME]", "goal_seconds": 7200};
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
      final dynamic result = await platform.invokeMethod('getAppSelections');
      if (result == null || result is! Map) return {"whitelist": [], "blacklist": []};
      return {
        "whitelist": List<String>.from(result["whitelist"] ?? []),
        "blacklist": List<String>.from(result["blacklist"] ?? []),
      };
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
      final dynamic result = await platform.invokeMethod('getRewardsData');
      if (result == null || result is! Map) return {"points": 0, "streak": 0, "badges": []};
      return {
        "points": (result["points"] as num?)?.toInt() ?? 0,
        "streak": (result["streak"] as num?)?.toInt() ?? 0,
        "badges": List<String>.from(result["badges"] ?? []),
      };
    } catch (e) {
      return {"points": 0, "streak": 0, "badges": []};
    }
  }

  Future<Map<String, dynamic>> getInsightsData(String period) async {
    try {
      final dynamic result = await platform.invokeMethod('getInsightsData', {'period': period});
      if (result == null || result is! Map) return {};
      return Map<String, dynamic>.from(result);
    } catch (e) {
      debugPrint("getInsightsData error: $e");
      return {};
    }
  }

  Future<Uint8List?> getAppIcon(String pkg) async {
    try {
      return await platform.invokeMethod<Uint8List>('getAppIcon', {'package_name': pkg});
    } catch (e) {
      return null;
    }
  }

  Future<List<String>> fetchInsights() async {
    try {
      final data = await getInsightsData("Day");
      if (data.containsKey("recommendations")) {
        return (data["recommendations"] as List).map((e) => e.toString()).toList();
      }
    } catch (e) {
      debugPrint("fetchInsights error: $e");
    }
    return ["Your usage looks healthy today. Keep it up!"];
  }

  Future<bool> registerDevice({String? userId, String? fcmToken}) async {
    try {
      String? token = fcmToken;
      if (token == null) {
        try {
          token = await FirebaseMessaging.instance.getToken();
        } catch (e) {
          debugPrint("FCM Token fetch failed: $e");
        }
      }

      return await platform.invokeMethod('registerDevice', {
        'jwt_token': _jwtToken,
        'base_url': baseUrl,
        'fcm_token': token,
      });
    } catch (e) {
      return false;
    }
  }

  Future<Map<String, dynamic>> getDeviceInfo() async {
    try {
      final dynamic result = await platform.invokeMethod('getDeviceInfo');
      if (result == null || result is! Map) return {};
      return Map<String, dynamic>.from(result);
    } catch (e) {
      return {};
    }
  }

  // ─── HTTP API Methods (Node.js Backend) ───

  Future<List<dynamic>> getBuddies() async {
    try {
      final response = await http.get(
        Uri.parse("$baseUrl/social/buddies"),
        headers: _headers,
      ).timeout(const Duration(seconds: 5));
      if (response.statusCode == 200) {
        return json.decode(response.body);
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  Future<List<dynamic>> getChallenges() async {
    try {
      final response = await http.get(
        Uri.parse("$baseUrl/social/challenges"),
        headers: _headers,
      ).timeout(const Duration(seconds: 5));
      if (response.statusCode == 200) {
        return json.decode(response.body);
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  Future<bool> joinChallenge(String challengeId) async {
    try {
      final response = await http.post(
        Uri.parse("$baseUrl/social/challenges/join"),
        headers: _headers,
        body: json.encode({
          "challengeId": challengeId
        }),
      ).timeout(const Duration(seconds: 5));
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  Future<Map<String, dynamic>> getAdminStats() async {
    try {
      final response = await http.get(
        Uri.parse("$baseUrl/admin/stats"),
        headers: _headers,
      ).timeout(const Duration(seconds: 5));
      if (response.statusCode == 200) {
        return json.decode(response.body);
      }
      return {};
    } catch (e) {
      return {};
    }
  }

  Future<List<dynamic>> getDevices() async {
    try {
      final response = await http.get(
        Uri.parse("$baseUrl/devices"),
        headers: _headers,
      ).timeout(const Duration(seconds: 5));
      if (response.statusCode == 200) {
        return json.decode(response.body);
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  Future<bool> unregisterDevice(String deviceId) async {
    try {
      final response = await http.delete(
        Uri.parse("$baseUrl/devices/$deviceId"),
        headers: _headers,
      ).timeout(const Duration(seconds: 5));
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }
}
