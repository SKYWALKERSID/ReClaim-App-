import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'api_service.dart';

class BackendService {
  static const platform = MethodChannel('reclaim/enforcement');
  static final _api = ApiService();

  static String get baseUrl => _api.dio.options.baseUrl;

  static Future<void> initialize() async {
    // No-op for now, ApiService handles tokens internally
  }

  Future<void> hideBlockingOverlay() async {
    try {
      await platform.invokeMethod('hideBlockingOverlay');
    } catch (e) {
      debugPrint("Failed to hide overlay: $e");
    }
  }

  // ─── Native Platform Methods (MethodChannel) ───

  Future<dynamic> invokeMethod(String method, [dynamic arguments]) async {
    try {
      return await platform.invokeMethod(method, arguments);
    } catch (e) {
      debugPrint("MethodChannel Error ($method)"); // Minimal logging for security
      return null;
    }
  }

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
      // Silently swallow — this is a best-effort UI navigation call.
    }
  }

  Future<Map<String, dynamic>> getPermissionStatus() async {
    try {
      final dynamic result = await platform.invokeMethod('getPermissionStatus');
      if (result == null || result is! Map) return {};
      return Map<String, dynamic>.from(result);
    } catch (e) {
      return {};
    }
  }

  Future<void> openPermissionSettings(String permission) async {
    try {
      await platform.invokeMethod('openPermissionSettings', {'permission': permission});
    } catch (e) {
      // Silently swallow — best-effort UI navigation.
    }
  }

  Future<Map<String, dynamic>> fetchDashboardStats() async {
    try {
      final dynamic result = await platform.invokeMethod('getDashboardStats');
      if (result == null || result is! Map) return {};
      return _deepCastMap(result);
    } catch (e) {
      return {};
    }
  }

  Future<Map<String, dynamic>> fetchBehavioralMetrics() async {
    try {
      final dynamic result = await platform.invokeMethod('getBehavioralMetrics');
      if (result == null || result is! Map) {
        return {
          "drift_score": 0.0,
          "fragmentation_index": 0.0,
          "reopen_count": 0,
          "failed_exits": 0,
          "feed_exposure_seconds": 0,
          "addiction_score": 0.0
        };
      }
      return _deepCastMap(result);
    } catch (e) {
      return {
        "drift_score": 0.0,
        "fragmentation_index": 0.0,
        "reopen_count": 0,
        "failed_exits": 0,
        "feed_exposure_seconds": 0,
        "addiction_score": 0.0
      };
    }
  }

  // fetchDriftStats() removed — was a dead alias for fetchBehavioralMetrics(); use that directly.

  Future<Uint8List?> getAppIcon(String packageName) async {
    try {
      final dynamic result = await platform.invokeMethod('getAppIcon', {'package_name': packageName});
      if (result == null || result is! Uint8List) return null;
      return result;
    } catch (e) {
      return null;
    }
  }

  Future<Map<String, dynamic>> fetchAppUsage() async {
    try {
      final dynamic result = await platform.invokeMethod('getAppUsage');
      if (result == null || result is! Map) return {"total_daily_seconds": 0, "apps": []};
      return {
        "total_daily_seconds": (result["total_daily_seconds"] as num?)?.toInt() ?? 0,
        "apps": List<dynamic>.from(result["apps"] ?? []).map((e) => Map<String, dynamic>.from(e as Map)).toList(),
      };
    } catch (e) {
      return {"total_daily_seconds": 0, "apps": []};
    }
  }

  Future<Map<String, dynamic>> getInstalledApps() async {
    try {
      final dynamic result = await platform.invokeMethod('getInstalledApps');
      if (result == null || result is! Map) return {"apps": []};
      return {
        "apps": List<dynamic>.from(result["apps"] ?? []).map((e) => Map<String, dynamic>.from(e as Map)).toList(),
      };
    } catch (e) {
      return {"apps": []};
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

  Future<Map<String, dynamic>> getInsightsData(String period, {String? category}) async {
    try {
      final dynamic result = await platform.invokeMethod('getInsightsData', {
        'period': period,       // Native handler reads 'period', not 'tab'
        'category': category,
      });
      if (result == null || result is! Map) return {"top_apps": [], "trend": [], "total_usage_seconds": 0, "category_breakdown": {}};
      
      return {
        "trend": List<dynamic>.from(result["trend"] ?? []).map((e) => (e as num).toInt()).toList(),
        "top_apps": (result["top_apps"] as List? ?? []).map((e) => Map<String, dynamic>.from(e as Map)).toList(),
        "total_usage_seconds": (result["total_usage_seconds"] as num?)?.toInt() ?? 0,
        "category_breakdown": Map<String, dynamic>.from(result["category_breakdown"] as Map? ?? {}),
      };
    } catch (e) {
      debugPrint('getInsightsData error: $e');
      return {"top_apps": [], "trend": [], "total_usage_seconds": 0, "category_breakdown": {}};
    }
  }

  Future<Map<String, dynamic>> getUserProfile() async {
    try {
      final dynamic result = await platform.invokeMethod('getUserProfile');
      if (result == null || result is! Map) return {"name": "", "goal_seconds": 7200, "age": 0, "gender": ""};
      return {
        "name": result["name"]?.toString() ?? "",
        "goal_seconds": (result["goal_seconds"] as num?)?.toInt() ?? 7200,
        "safe_code": result["safe_code"]?.toString() ?? "",
        "age": (result["age"] as num?)?.toInt() ?? 0,
        "gender": result["gender"]?.toString() ?? ""
      };
    } catch (e) {
      return {"name": "", "goal_seconds": 7200, "safe_code": "", "age": 0, "gender": ""};
    }
  }

  Future<bool> saveUserSettings(String name, int goalSeconds, {String? safeCode, int? age, String? gender}) async {
    try {
      return await platform.invokeMethod('saveUserSettings', {
        'name': name, 
        'goal_seconds': goalSeconds,
        if (safeCode != null) 'safe_code': safeCode,
        if (age != null) 'age': age,
        if (gender != null) 'gender': gender,
      });
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

  Future<bool> updateAppCategory(String pkg, String category) async {
    try {
      return await platform.invokeMethod('updateAppCategory', {'package_name': pkg, 'category': category});
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

  Future<bool> startFocusMode(int durationMinutes, {String category = "Deep Focus"}) async {
    try {
      return await platform.invokeMethod('startFocusMode', {
        'duration_minutes': durationMinutes,
        'category': category,
      });
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

  Future<Map<String, int>> getUsageForDateRange(DateTime start, DateTime end) async {
    try {
      final dynamic result = await platform.invokeMethod('getUsageForDateRange', {
        'start': start.millisecondsSinceEpoch,
        'end': end.millisecondsSinceEpoch,
      });
      if (result == null || result is! Map) return {};
      return Map<String, int>.from(result);
    } catch (e) {
      return {};
    }
  }

  Future<List<Map<String, dynamic>>> getTopAppsForRange(DateTime start, DateTime end) async {
    try {
      final dynamic result = await platform.invokeMethod('getTopAppsForRange', {
        'start': start.millisecondsSinceEpoch,
        'end': end.millisecondsSinceEpoch,
      });
      if (result == null || result is! List) return [];
      return result.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    } catch (e) {
      return [];
    }
  }

  Future<List<String>> fetchInsights() async {
    try {
      final data = await getInsightsData("Day");
      if (data.containsKey("recommendations")) {
        return (data["recommendations"] as List).map((e) => e.toString()).toList();
      }
    } catch (_) {
      // Silently fall back to default insight.
    }
    return ["Your usage looks healthy today. Keep it up!"];
  }

  Future<bool> registerDevice({String? userId, String? fcmToken}) async {
    try {
      String? token = fcmToken;
      if (token == null) {
        try {
          await Future.delayed(const Duration(seconds: 1));
          token = await FirebaseMessaging.instance.getToken();
        } catch (_) {
          // FCM token not available; device registration will proceed without push capability.
        }
      }

      final jwt = await _api.getAccessToken();
      final uid = userId ?? "anonymous";

      await platform.invokeMethod('saveAuth', {
        'jwt_token': jwt,
        'user_id': uid,
      });

      return await platform.invokeMethod('registerDevice', {
        'jwt_token': jwt,
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
      final response = await _api.dio.get("/social/buddies");
      return response.data;
    } catch (e) {
      return [];
    }
  }

  Future<List<dynamic>> getChallenges() async {
    try {
      final response = await _api.dio.get("/social/challenges");
      return response.data;
    } catch (e) {
      return [];
    }
  }

  Future<bool> joinChallenge(String challengeId) async {
    try {
      final response = await _api.dio.post("/social/challenges/join", data: {
        "challengeId": challengeId
      });
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  Future<Map<String, dynamic>> getAdminStats() async {
    try {
      final response = await _api.dio.get("/admin/stats");
      return response.data;
    } catch (e) {
      return {};
    }
  }

  Future<List<dynamic>> getDevices() async {
    try {
      final response = await _api.dio.get("/devices");
      return response.data;
    } catch (e) {
      return [];
    }
  }

  Future<bool> unregisterDevice(String deviceId) async {
    try {
      final response = await _api.dio.delete("/devices/$deviceId");
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  Future<bool> sendNudge(String title, String body) async {
    try {
      // Backend route is POST /v1/nudge (not /analytics/nudge)
      final response = await _api.dio.post("/nudge", data: {"title": title, "body": body});
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  // --- Brain & Memory Features ---

  Future<Map<String, dynamic>?> getPendingReflection() async {
    try {
      final dynamic result = await platform.invokeMethod('getPendingReflection');
      if (result == null || result is! Map) return null;
      return Map<String, dynamic>.from(result);
    } catch (e) {
      return null;
    }
  }

  Future<bool> submitReflection(String sessionId, String promptType, String response, int driftScore) async {
    try {
      return await platform.invokeMethod('submitReflection', {
        'sessionId': sessionId,
        'promptType': promptType,
        'response': response,
        'driftScore': driftScore,
      });
    } catch (e) {
      return false;
    }
  }

  Future<List<Map<String, dynamic>>> getReflectionHistory() async {
    try {
      final dynamic result = await platform.invokeMethod('getReflectionHistory');
      if (result == null || result is! List) return [];
      return result.map((e) => (e as Map).cast<String, dynamic>()).toList();
    } catch (e) {
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> getFrictionInterventions() async {
    try {
      final dynamic result = await platform.invokeMethod('getFrictionInterventions');
      if (result == null || result is! List) return [];
      return result.map((e) => (e as Map).cast<String, dynamic>()).toList();
    } catch (e) {
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> getIntentHistory() async {
    try {
      final dynamic result = await platform.invokeMethod('getIntentHistory');
      if (result == null || result is! List) return [];
      return result.map((e) => (e as Map).cast<String, dynamic>()).toList();
    } catch (e) {
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> getDriftHistory() async {
    try {
      final dynamic result = await platform.invokeMethod('getDriftHistory');
      if (result == null || result is! List) return [];
      return result.map((e) => (e as Map).cast<String, dynamic>()).toList();
    } catch (e) {
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> getRecommendations() async {
    try {
      final dynamic result = await platform.invokeMethod('getRecommendations');
      if (result == null || result is! List) return [];
      return result.map((e) => (e as Map).cast<String, dynamic>()).toList();
    } catch (e) {
      return [];
    }
  }

  Future<Map<String, dynamic>> getCravingStatus() async {
    try {
      final dynamic result = await platform.invokeMethod('getCravingStatus');
      if (result == null || result is! Map) return {'isActive': false, 'windowName': 'None'};
      return Map<String, dynamic>.from(result);
    } catch (e) {
      return {'isActive': false, 'windowName': 'None'};
    }
  }

  Future<int> getLifetimeDriftCount() async {
    try {
      final int result = await platform.invokeMethod('getLifetimeDriftCount');
      return result;
    } catch (e) {
      return 0;
    }
  }

  Future<List<Map<String, dynamic>>> getFocusHistory() async {
    try {
      final dynamic result = await platform.invokeMethod('getFocusHistory');
      if (result == null || result is! List) return [];
      return result.map((e) => (e as Map).cast<String, dynamic>()).toList();
    } catch (e) {
      return [];
    }
  }

  Future<int> getUnsyncedCount() async {
    try {
      final int result = await platform.invokeMethod('getUnsyncedCount');
      return result;
    } catch (e) {
      return 0;
    }
  }

  Future<bool> syncAllData() async {
    try {
      return await platform.invokeMethod('syncAllData');
    } catch (e) {
      return false;
    }
  }

  Future<bool> toggleNotifications(bool enabled) async {
    try {
      return await platform.invokeMethod('toggleNotifications', {'enabled': enabled});
    } catch (e) {
      return false;
    }
  }

  Future<bool> toggleScheduledReports(bool enabled) async {
    try {
      return await platform.invokeMethod('toggleScheduledReports', {'enabled': enabled});
    } catch (e) {
      return false;
    }
  }

  Future<bool> checkNightTimeOveruse() async {
    try {
      return await platform.invokeMethod('checkNightTimeOveruse');
    } catch (e) {
      return false;
    }
  }

  Map<String, dynamic> _deepCastMap(dynamic map) {
    if (map is! Map) return {};
    return map.map((key, value) {
      final String stringKey = key.toString();
      if (value is Map) {
        return MapEntry(stringKey, _deepCastMap(value));
      } else if (value is List) {
        return MapEntry(stringKey, value.map((e) {
          if (e is Map) return _deepCastMap(e);
          return e;
        }).toList());
      }
      return MapEntry(stringKey, value);
    }).cast<String, dynamic>();
  }
}
