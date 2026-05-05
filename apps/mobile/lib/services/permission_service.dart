import 'package:permission_handler/permission_handler.dart';
import 'backend_service.dart';

class PermissionService {
  final BackendService _backend = BackendService();

  Future<bool> checkAndRequestAll() async {
    final status = await _backend.getPermissionStatus();
    return (status['usage_access'] as bool? ?? false) &&
        (status['overlay_access'] as bool? ?? false) &&
        (status['accessibility_access'] as bool? ?? false);
  }

  Future<bool> isAccessibilityEnabled() async {
    final status = await _backend.getPermissionStatus();
    return status['accessibility_access'] as bool? ?? false;
  }

  Future<bool> hasOverlayPermission() async {
    final status = await Permission.systemAlertWindow.status;
    return status.isGranted;
  }

  Future<bool> hasUsageAccess() async {
    return await _backend.checkPermissions();
  }
}
