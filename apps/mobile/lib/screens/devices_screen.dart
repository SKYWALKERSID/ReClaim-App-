import 'package:flutter/material.dart';
import '../services/backend_service.dart';

class DevicesScreen extends StatefulWidget {
  const DevicesScreen({super.key});

  @override
  State<DevicesScreen> createState() => _DevicesScreenState();
}

class _DevicesScreenState extends State<DevicesScreen> {
  final BackendService _backend = BackendService();
  List<Map<String, dynamic>> _devices = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadDevices();
  }

  Future<void> _loadDevices() async {
    setState(() => _loading = true);
    try {
      final info = await _backend.getDeviceInfo();
      final currentDeviceId = info["device_id"] ?? "";
      final backendDevices = await _backend.getDevices();
      
      setState(() {
        _devices = backendDevices.map((d) {
          final isCurrent = d["deviceId"] == currentDeviceId;
          return {
            "device_id": d["deviceId"],
            "model": d["model"] ?? "Unknown Device",
            "os_version": d["osVersion"] ?? "Unknown OS",
            "is_current": isCurrent,
            "last_sync": "Recently"
          };
        }).toList();
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
    }
  }

  Future<void> _removeDevice(String deviceId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Remove Device"),
        content: const Text("Are you sure you want to unregister this device? It will stop receiving focus enforcement updates."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("CANCEL")),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text("REMOVE", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final success = await _backend.unregisterDevice(deviceId);
      if (success) {
        setState(() {
          _devices.removeWhere((d) => d["device_id"] == deviceId);
        });
      }
      if (!mounted) return; // widget may have been disposed during the dialog
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Device unregistered successfully")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text("Manage Devices", style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: Colors.cyanAccent))
          : TweenAnimationBuilder<double>(
              duration: const Duration(milliseconds: 500),
              tween: Tween(begin: 0.0, end: 1.0),
              builder: (context, value, child) {
                return Opacity(
                  opacity: value,
                  child: Transform.translate(
                    offset: Offset(0, 15 * (1 - value)),
                    child: child,
                  ),
                );
              },
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: _devices.length,
                itemBuilder: (context, index) {
                  final device = _devices[index];
                  final isCurrent = device["is_current"] == true;

                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isCurrent ? Colors.cyanAccent.withValues(alpha: 0.3) : Colors.white10,
                      ),
                      boxShadow: isCurrent ? [
                        BoxShadow(
                          color: Colors.cyanAccent.withValues(alpha: 0.05),
                          blurRadius: 10,
                          spreadRadius: 1,
                        )
                      ] : null,
                    ),
                    child: Row(
                      children: [
                        Icon(
                          isCurrent ? Icons.smartphone : Icons.tablet_android,
                          color: isCurrent ? Colors.cyanAccent : Colors.white60,
                          size: 32,
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                device["model"],
                                style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                              ),
                              Text(
                                "${device["os_version"]} • Last synced: ${device["last_sync"]}",
                                style: const TextStyle(color: Colors.white60, fontSize: 12),
                              ),
                            ],
                          ),
                        ),
                        if (!isCurrent)
                          IconButton(
                            icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                            onPressed: () => _removeDevice(device["device_id"]),
                          )
                        else
                          const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 8),
                            child: Text("CURRENT", style: TextStyle(color: Colors.cyanAccent, fontSize: 10, fontWeight: FontWeight.bold)),
                          ),
                      ],
                    ),
                  );
                },
              ),
            ),
    );
  }
}

