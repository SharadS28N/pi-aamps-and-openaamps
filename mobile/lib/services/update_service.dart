import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

class UpdateInfo {
  final String version;
  final int buildNumber;
  final String releaseNotes;
  final String downloadUrl;
  final bool isMandatory;

  const UpdateInfo({
    required this.version,
    required this.buildNumber,
    required this.releaseNotes,
    required this.downloadUrl,
    this.isMandatory = false,
  });
}

class UpdateService extends ChangeNotifier {
  static final UpdateService instance = UpdateService._internal();
  UpdateService._internal();

  static const String currentVersion = '1.2.7';
  static const int currentBuildNumber = 23;
  static const String canonicalPackage = 'com.aamps.openaamps';

  static const String _prefDismissedVersion = 'openaamps_dismissed_update_version';
  static const String _prefAutoCheck = 'openaamps_auto_check_updates';

  bool _autoCheckUpdates = true;
  String? _dismissedVersion;
  UpdateInfo? _latestAvailableUpdate;
  bool _isChecking = false;

  bool get autoCheckUpdates => _autoCheckUpdates;
  String? get dismissedVersion => _dismissedVersion;
  UpdateInfo? get latestAvailableUpdate => _latestAvailableUpdate;
  bool get isChecking => _isChecking;

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _autoCheckUpdates = prefs.getBool(_prefAutoCheck) ?? true;
    _dismissedVersion = prefs.getString(_prefDismissedVersion);
    notifyListeners();
  }

  Future<void> setAutoCheckUpdates(bool enabled) async {
    _autoCheckUpdates = enabled;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefAutoCheck, enabled);
    notifyListeners();
  }

  Future<void> dismissVersion(String version) async {
    _dismissedVersion = version;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefDismissedVersion, version);
    notifyListeners();
  }

  Future<void> clearDismissedVersion() async {
    _dismissedVersion = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_prefDismissedVersion);
    notifyListeners();
  }

  bool isVersionDismissed(String version) {
    return _dismissedVersion == version;
  }

  /// Checks for available update.
  /// If [userInitiated] is false and the version was previously dismissed,
  /// this method returns null so the user is never repeatedly irritated.
  Future<UpdateInfo?> checkForUpdate({bool userInitiated = false}) async {
    _isChecking = true;
    notifyListeners();

    try {
      // In production, this queries the latest GitHub release or Pi backend API.
      // Default fallback metadata endpoint:
      final url = Uri.parse(
        'https://api.github.com/repos/SharadS28N/pi-aamps-and-openaamps/releases/latest',
      );

      final resp = await http.get(url).timeout(const Duration(seconds: 5));
      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body);
        final tagName = (data['tag_name'] as String? ?? '').replaceAll('v', '').trim();
        final body = data['body'] as String? ?? 'Performance optimizations, dynamic player styles, and bug fixes.';
        
        // Find APK asset download URL
        String apkDownload = 'https://github.com/SharadS28N/pi-aamps-and-openaamps/releases/latest';
        final assets = data['assets'] as List<dynamic>?;
        if (assets != null) {
          for (final asset in assets) {
            final name = asset['name'] as String? ?? '';
            if (name.endsWith('.apk')) {
              apkDownload = asset['browser_download_url'] as String? ?? apkDownload;
              break;
            }
          }
        }

        if (tagName.isNotEmpty && _isNewerVersion(tagName, currentVersion)) {
          final info = UpdateInfo(
            version: tagName,
            buildNumber: currentBuildNumber + 1,
            releaseNotes: body,
            downloadUrl: apkDownload,
          );
          _latestAvailableUpdate = info;

          // If this version was previously dismissed and this is an automatic check,
          // do not disturb the user.
          if (!userInitiated && isVersionDismissed(tagName)) {
            return null;
          }

          return info;
        }
      }
    } catch (e) {
      debugPrint('[UpdateService] Update check handled: $e');
    } finally {
      _isChecking = false;
      notifyListeners();
    }

    return null;
  }

  bool _isNewerVersion(String candidate, String current) {
    try {
      final cParts = candidate.split('.').map((p) => int.tryParse(p) ?? 0).toList();
      final currParts = current.split('.').map((p) => int.tryParse(p) ?? 0).toList();

      for (int i = 0; i < 3; i++) {
        final c = i < cParts.length ? cParts[i] : 0;
        final cur = i < currParts.length ? currParts[i] : 0;
        if (c > cur) return true;
        if (c < cur) return false;
      }
    } catch (_) {}
    return false;
  }

  /// Presents a gentle, non-intrusive update sheet that respects the user's preference.
  void showUpdatePrompt(BuildContext context, UpdateInfo info) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF161618),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.white10,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.system_update_rounded, color: Colors.white, size: 24),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Update Available (v${info.version})',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Current version: v$currentVersion',
                            style: const TextStyle(color: Color(0xFFA1A1AA), fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF202022),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white10),
                  ),
                  child: Text(
                    info.releaseNotes,
                    maxLines: 4,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Color(0xFFD4D4D8), fontSize: 13, height: 1.4),
                  ),
                ),
                const SizedBox(height: 20),
                // Update Button
                SizedBox(
                  width: double.infinity,
                  height: 46,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.black,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(23)),
                    ),
                    onPressed: () async {
                      Navigator.pop(ctx);
                      final uri = Uri.parse(info.downloadUrl);
                      if (await canLaunchUrl(uri)) {
                        await launchUrl(uri, mode: LaunchMode.externalApplication);
                      }
                    },
                    child: const Text('Download & Update', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  ),
                ),
                const SizedBox(height: 10),
                // Action options: Remind Later vs Don't show again for this version
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text(
                        'Remind Later',
                        style: TextStyle(color: Color(0xFFA1A1AA), fontSize: 13),
                      ),
                    ),
                    TextButton(
                      onPressed: () {
                        dismissVersion(info.version);
                        Navigator.pop(ctx);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Update notification muted for v${info.version}.'),
                            backgroundColor: const Color(0xFF222222),
                          ),
                        );
                      },
                      child: const Text(
                        "Don't show again for this version",
                        style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
