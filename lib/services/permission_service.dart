import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

class PermissionService {
  static Future<bool> requestMicrophone(BuildContext context) async {
    return _request(
      Permission.microphone,
      context,
      'Microphone',
      'Microphone access is needed to record voice messages.',
    );
  }

  static Future<bool> requestCamera(BuildContext context) async {
    return _request(
      Permission.camera,
      context,
      'Camera',
      'Camera access is needed to take photos and videos.',
    );
  }

  static Future<bool> requestPhotos(BuildContext context) async {
    // Android 13+ uses READ_MEDIA_IMAGES; older uses storage
    final status13 = await Permission.photos.status;
    if (status13.isGranted || status13.isLimited) return true;

    if (!status13.isPermanentlyDenied) {
      final result = await Permission.photos.request();
      if (result.isGranted || result.isLimited) return true;
    }

    // Fallback for older Android
    final storageStatus = await Permission.storage.status;
    if (storageStatus.isGranted) return true;
    if (!storageStatus.isPermanentlyDenied) {
      final result = await Permission.storage.request();
      if (result.isGranted) return true;
    }

    if (context.mounted) {
      await _showSettingsDialog(
        context,
        'Storage / Photos',
        'To share photos and files, please allow access in app settings.',
      );
    }
    return false;
  }

  static Future<bool> requestVideos(BuildContext context) async {
    final status = await Permission.videos.status;
    if (status.isGranted || status.isLimited) return true;
    if (!status.isPermanentlyDenied) {
      final result = await Permission.videos.request();
      if (result.isGranted || result.isLimited) return true;
    }
    // Fallback for older Android
    return requestPhotos(context);
  }

  static Future<bool> requestContacts(BuildContext context) async {
    return _request(
      Permission.contacts,
      context,
      'Contacts',
      'Contacts access is needed to find and sync your contacts.',
    );
  }

  static Future<void> requestNotification() async {
    final status = await Permission.notification.status;
    if (!status.isGranted) {
      await Permission.notification.request();
    }
  }

  static Future<bool> _request(
    Permission permission,
    BuildContext context,
    String name,
    String rationale,
  ) async {
    final status = await permission.status;
    if (status.isGranted) return true;
    if (status.isDenied) {
      final result = await permission.request();
      return result.isGranted;
    }
    if (status.isPermanentlyDenied && context.mounted) {
      await _showSettingsDialog(context, name, rationale);
    }
    return false;
  }

  static Future<void> _showSettingsDialog(
    BuildContext context,
    String name,
    String message,
  ) async {
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('$name Permission'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Not Now'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await openAppSettings();
            },
            child: const Text('Open Settings'),
          ),
        ],
      ),
    );
  }
}
