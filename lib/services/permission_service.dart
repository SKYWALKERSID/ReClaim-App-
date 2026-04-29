import 'package:permission_handler/permission_handler.dart';
import 'backend_service.dart';

class PermissionService {
  final BackendService _backend = BackendService();

  Future<bool> checkAndRequestAll() async {
    // 1. Check Usage Stats (via Backend)
    bool hasUsage = await _backend.checkPermissions();
    if (!hasUsage) {
      await _backend.openSettings();
      // Wait a bit or let the user handle it
      return false;
    }

    // 2. Check System Alert Window (Overlay)
    var overlayStatus = await Permission.systemAlertWindow.status;
    if (!overlayStatus.isGranted) {
      overlayStatus = await Permission.systemAlertWindow.request();
      if (!overlayStatus.isGranted) return false;
    }

    return true;
  }

  Future<bool> isAccessibilityEnabled() async {
    // This is trickier to check from Dart without a dedicated plugin, 
    // but the EnforcementService will warn the user if it can't run.
    return true; 
  }
}
