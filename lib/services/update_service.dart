import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:ota_update/ota_update.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

class UpdateService {
  // Laravel backend API URL for APK version checking (PRODUCTION)
  static const String _updateApiUrl = 'https://connect.admein.az/api/app-version';
  
  // GitHub API URL for APK releases (PRODUCTION - switch to releases when fixed)
  static const String _githubApiUrl = 'https://api.github.com/repos/ImranJeferly/admein/releases/latest';
  
  // GitHub commits API (TEMPORARY - for testing only)
  static const String _githubCommitsApiUrl = 'https://api.github.com/repos/ImranJeferly/admein/commits/main';
  
  /// Check for app updates on startup - DISABLED for manual updates
  static Future<void> checkForUpdates(BuildContext context) async {
    // AUTO-UPDATE DISABLED - Manual updates only
    print('🚕 [FLEET-UPDATE] Auto-update system DISABLED');
    print('🔄 [FLEET-UPDATE] Using manual update process');
    return;
    
    // OLD AUTO-UPDATE CODE (DISABLED)
    /*
    try {
      print('🔄 [FLEET-UPDATE] Checking for fleet updates...');
      print('🚕 [FLEET-UPDATE] Tablet ID: ${await _getDeviceId()}');
      
      // Get current app version
      final packageInfo = await PackageInfo.fromPlatform();
      final currentVersion = packageInfo.version;
      print('🔄 [FLEET-UPDATE] Current version: $currentVersion');
      
      // PRODUCTION: Check GitHub Releases for new APK
      final response = await http.get(
        Uri.parse(_githubApiUrl),
        headers: {
          'Accept': 'application/vnd.github.v3+json',
          'User-Agent': 'AdmainApp-UpdateChecker',
        },
      ).timeout(const Duration(seconds: 10));
      
      if (response.statusCode == 200) {
        final releaseData = jsonDecode(response.body);
        final latestVersion = (releaseData['tag_name'] as String).replaceFirst('v', '');
        
        print('🔄 [FLEET-UPDATE] Latest release version: $latestVersion');
        print('🔄 [FLEET-UPDATE] Current version: $currentVersion');
        
        // Check if update is needed and not already installed
        if (_isNewerVersion(currentVersion, latestVersion) && !(await _isVersionAlreadyInstalled(latestVersion))) {
          // Find APK download URL
          final assets = releaseData['assets'] as List<dynamic>;
          String? apkDownloadUrl;
          
          for (final asset in assets) {
            final assetName = asset['name'] as String;
            if (assetName.toLowerCase().endsWith('.apk')) {
              apkDownloadUrl = asset['browser_download_url'] as String;
              break;
            }
          }
          
          if (apkDownloadUrl != null) {
            print('🚕 [FLEET-UPDATE] PRODUCTION UPDATE DETECTED!');
            print('🚕 [FLEET-UPDATE] Update available: $currentVersion -> $latestVersion');
            print('📥 [FLEET-UPDATE] APK URL: $apkDownloadUrl');
            print('🔄 [FLEET-UPDATE] Starting silent background update...');
            
            if (context.mounted) {
              // PRODUCTION: Start silent background fleet update
              _downloadAndInstallUpdateSilent(context, apkDownloadUrl, latestVersion);
            }
          } else {
            print('⚠️ [FLEET-UPDATE] No APK found in release assets');
          }
        } else {
          print('✅ [FLEET-UPDATE] Fleet is up to date');
        }
      } else if (response.statusCode == 404) {
        print('⚠️ [FLEET-UPDATE] No releases found, falling back to commit detection...');
        await _checkCommitsForTesting(context, currentVersion);
      } else {
        print('⚠️ [UPDATE] GitHub API returned status: ${response.statusCode}');
      }
      
    } catch (e) {
      print('❌ [FLEET-UPDATE] Error checking for fleet updates: $e');
      // Continue app normally on error - don't block taxi operations
    }
    */
  }
  
  /// Fallback method for testing when releases aren't available
  static Future<void> _checkCommitsForTesting(BuildContext context, String currentVersion) async {
    try {
      final response = await http.get(
        Uri.parse(_githubCommitsApiUrl),
        headers: {
          'Accept': 'application/vnd.github.v3+json',
          'User-Agent': 'AdmainApp-UpdateChecker',
        },
      ).timeout(const Duration(seconds: 10));
      
      if (response.statusCode == 200) {
        final commitData = jsonDecode(response.body);
        final latestCommit = commitData['sha'] as String;
        final commitMessage = commitData['commit']['message'] as String;
        
        print('🔄 [FLEET-UPDATE] Latest commit: ${latestCommit.substring(0, 8)}');
        print('🔄 [FLEET-UPDATE] Commit message: $commitMessage');
        
        // For testing: detect commits with "FLEET TEST" in the message
        if (commitMessage.toLowerCase().contains('fleet test')) {
          print('🚕 [FLEET-UPDATE] FLEET TEST UPDATE DETECTED!');
          print('🚕 [FLEET-UPDATE] Update available: $currentVersion -> Testing Version');
          print('🔄 [FLEET-UPDATE] Test update detection successful - no download in test mode');
        } else {
          print('✅ [FLEET-UPDATE] Fleet is up to date (no test commits found)');
        }
      }
    } catch (e) {
      print('❌ [FLEET-UPDATE] Error checking commits: $e');
    }
  }
  
  /// Get device identifier for fleet tracking
  static Future<String> _getDeviceId() async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      return 'TAXI_${packageInfo.packageName}_${DateTime.now().millisecondsSinceEpoch.toString().substring(8)}';
    } catch (e) {
      return 'TAXI_UNKNOWN_${DateTime.now().millisecondsSinceEpoch.toString().substring(8)}';
    }
  }
  
  /// Save installed version to prevent re-detection
  static Future<void> _saveInstalledVersion(String version) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('fleet_installed_version', version);
      await prefs.setString('fleet_last_update', DateTime.now().toIso8601String());
      print('✅ [FLEET-UPDATE] Saved installed version: $version');
    } catch (e) {
      print('❌ [FLEET-UPDATE] Failed to save version: $e');
    }
  }
  
  /// Check if version was already installed to prevent duplicate updates
  static Future<bool> _isVersionAlreadyInstalled(String latestVersion) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final installedVersion = prefs.getString('fleet_installed_version');
      
      if (installedVersion != null && installedVersion == latestVersion) {
        final lastUpdate = prefs.getString('fleet_last_update');
        print('✅ [FLEET-UPDATE] Version $latestVersion already installed on $lastUpdate');
        return true;
      }
      
      return false;
    } catch (e) {
      print('❌ [FLEET-UPDATE] Failed to check installed version: $e');
      return false;
    }
  }
  
  /// Compare version strings (supports semantic versioning)
  static bool _isNewerVersion(String current, String latest) {
    // Remove 'v' prefix if present
    current = current.replaceFirst('v', '');
    latest = latest.replaceFirst('v', '');
    
    final currentParts = current.split('.').map(int.parse).toList();
    final latestParts = latest.split('.').map(int.parse).toList();
    
    // Ensure both version arrays have same length
    while (currentParts.length < latestParts.length) {
      currentParts.add(0);
    }
    while (latestParts.length < currentParts.length) {
      latestParts.add(0);
    }
    
    for (int i = 0; i < currentParts.length; i++) {
      if (latestParts[i] > currentParts[i]) return true;
      if (latestParts[i] < currentParts[i]) return false;
    }
    
    return false; // Versions are equal
  }
  
  /// Show fleet test dialog - demonstrates update detection
  static void _showFleetTestDialog(BuildContext context, String currentVersion, String commitHash) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF2a2e6a),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Row(
            children: [
              Icon(Icons.local_taxi, color: Color(0xFFffc107), size: 28),
              SizedBox(width: 12),
              Text(
                'Fleet Test Update!',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '🎉 Auto-Update Detection Working!',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  color: Colors.white.withOpacity(0.9),
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Current: $currentVersion',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  color: Colors.white.withOpacity(0.7),
                  fontSize: 14,
                ),
              ),
              Text(
                'Latest Commit: $commitHash',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  color: Colors.white.withOpacity(0.7),
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'The green background change has been detected! In production, this would automatically download and install the new APK across all 200 taxi tablets.',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  color: Colors.white.withOpacity(0.8),
                  fontSize: 12,
                ),
              ),
            ],
          ),
          actions: [
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFffc107),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              ),
              child: const Text(
                'Great! It Works! 🚕',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  color: Color(0xFF2a2e6a),
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  /// Show fleet update dialog - automatic update for taxi tablets
  static void _showFleetUpdateDialog(BuildContext context, String currentVersion, String latestVersion, String downloadUrl) {
    showDialog(
      context: context,
      barrierDismissible: false, // Cannot be dismissed - fleet update is mandatory
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF2a2e6a),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Row(
            children: [
              Icon(Icons.local_taxi, color: Color(0xFFffc107), size: 28),
              SizedBox(width: 12),
              Text(
                'Fleet Update Available',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '🚕 Taxi Fleet Management System',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  color: Colors.white.withOpacity(0.9),
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Current: $currentVersion → New: $latestVersion',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  color: Colors.white.withOpacity(0.7),
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'This update will be installed automatically to keep all taxi tablets synchronized with the latest features and fixes.',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  color: Colors.white.withOpacity(0.8),
                  fontSize: 12,
                ),
              ),
            ],
          ),
          actions: [
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                _downloadAndInstallUpdate(context, downloadUrl, latestVersion);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFffc107),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              ),
              child: const Text(
                'Update Fleet 🚕',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  color: Color(0xFF2a2e6a),
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  /// Show test update notification (no actual download)
  static void _showTestUpdateDialog(BuildContext context, String currentVersion, String latestCommit) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF2a2e6a),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Row(
            children: [
              Icon(Icons.system_update, color: Color(0xFFffc107), size: 28),
              SizedBox(width: 12),
              Text(
                'Test Update Detected!',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Auto-update system is working! 🎉',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  color: Colors.white.withOpacity(0.9),
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Latest commit: $latestCommit',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  color: Colors.white.withOpacity(0.7),
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Current version: $currentVersion',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  color: Colors.white.withOpacity(0.7),
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'In a real scenario, this would download and install the update automatically.',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  color: Colors.white.withOpacity(0.6),
                  fontSize: 12,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ),
          actions: [
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFffc107),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              ),
              child: const Text(
                'Awesome! 🚀',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  color: Color(0xFF2a2e6a),
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  /// Show update dialog to user
  static void _showUpdateDialog(BuildContext context, String currentVersion, String latestVersion, String downloadUrl) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF2a2e6a),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Row(
            children: [
              Icon(Icons.system_update, color: Color(0xFFffc107), size: 28),
              SizedBox(width: 12),
              Text(
                'Yeniləmə mövcuddur!',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Yeni versiya mövcuddur:',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  color: Colors.white.withValues(alpha: 0.9),
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Text(
                    '$currentVersion',
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      color: Colors.white.withOpacity(0.7),
                      fontSize: 16,
                    ),
                  ),
                  const Icon(Icons.arrow_forward, color: Color(0xFFffc107), size: 20),
                  Text(
                    ' $latestVersion',
                    style: const TextStyle(
                      fontFamily: 'Poppins',
                      color: Color(0xFFffc107),
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                'Yeniləməni indi quraşdırmaq istəyirsiniz?',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  color: Colors.white.withOpacity(0.9),
                  fontSize: 14,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: Text(
                'Sonra',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  color: Colors.white.withOpacity(0.7),
                  fontSize: 16,
                ),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                _downloadAndInstallUpdate(context, downloadUrl, latestVersion);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFffc107),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              ),
              child: const Text(
                'Yenilə',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  color: Color(0xFF2a2e6a),
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
  
  /// Download and install update silently in background
  static Future<void> _downloadAndInstallUpdateSilent(BuildContext context, String downloadUrl, String version) async {
    try {
      print('📥 [FLEET-UPDATE] Starting silent download from: $downloadUrl');
      
      // Get app directory for storing the APK
      final directory = await getExternalStorageDirectory();
      final apkPath = '${directory!.path}/admain_update_$version.apk';
      
      // Download APK with console progress logging
      final request = http.Request('GET', Uri.parse(downloadUrl));
      final streamedResponse = await request.send();
      
      if (streamedResponse.statusCode == 200) {
        final file = File(apkPath);
        final sink = file.openWrite();
        
        final totalBytes = streamedResponse.contentLength ?? 0;
        int downloadedBytes = 0;
        int lastLoggedProgress = 0;
        
        await for (final chunk in streamedResponse.stream) {
          sink.add(chunk);
          downloadedBytes += chunk.length;
          
          if (totalBytes > 0) {
            final progress = ((downloadedBytes / totalBytes) * 100).round();
            // Log progress every 10%
            if (progress >= lastLoggedProgress + 10) {
              print('📥 [FLEET-UPDATE] Download progress: $progress% ($downloadedBytes/$totalBytes bytes)');
              lastLoggedProgress = progress;
            }
          }
        }
        
        await sink.close();
        print('✅ [FLEET-UPDATE] APK downloaded successfully to: $apkPath');
        print('🔄 [FLEET-UPDATE] File size: ${(downloadedBytes / 1024 / 1024).toStringAsFixed(1)} MB');
        
        // Install the APK silently
        await _installApkSilent(context, apkPath, version);
        
      } else {
        throw Exception('Download failed with status: ${streamedResponse.statusCode}');
      }
      
    } catch (e) {
      print('❌ [FLEET-UPDATE] Silent download failed: $e');
      print('🔄 [FLEET-UPDATE] Will retry on next app restart');
    }
  }
  
  /// Legacy method for dialog-based updates (kept for compatibility)
  static Future<void> _downloadAndInstallUpdate(BuildContext context, String downloadUrl, String version) async {
    // Redirect to silent update
    await _downloadAndInstallUpdateSilent(context, downloadUrl, version);
  }
  
  /// Install APK silently without UI interruption
  static Future<void> _installApkSilent(BuildContext context, String apkPath, String version) async {
    try {
      print('📱 [FLEET-UPDATE] Installing APK silently: $apkPath');
      
      // Save the updated version to prevent re-detection
      await _saveInstalledVersion(version);
      
      // Use OTA Update plugin to install the APK
      try {
        OtaUpdate().execute(
          apkPath,
          destinationFilename: 'admain_fleet_update.apk',
        ).listen((OtaEvent event) {
          print('📱 [FLEET-UPDATE] Installation status: ${event.status}');
          
          if (event.status == OtaStatus.INSTALLING) {
            print('🔄 [FLEET-UPDATE] Installing update in background...');
          } else if (event.status == OtaStatus.ALREADY_RUNNING_ERROR) {
            print('⚠️ [FLEET-UPDATE] Installation already in progress');
          } else if (event.status == OtaStatus.PERMISSION_NOT_GRANTED_ERROR) {
            print('❌ [FLEET-UPDATE] Installation permission not granted');
          }
        });
        
        print('✅ [FLEET-UPDATE] Silent installation initiated successfully');
        print('🚕 [FLEET-UPDATE] Taxi tablet will restart automatically when installation completes');
        
      } on Exception catch (e) {
        print('❌ [FLEET-UPDATE] OTA execution failed: $e');
        print('🔄 [FLEET-UPDATE] Will retry on next app restart');
      }
      
    } catch (e) {
      print('❌ [FLEET-UPDATE] Silent installation failed: $e');
      print('🔄 [FLEET-UPDATE] Will retry on next app restart');
    }
  }
  
  /// Legacy install method (kept for compatibility)
  static Future<void> _installApk(BuildContext context, String apkPath) async {
    final packageInfo = await PackageInfo.fromPlatform();
    await _installApkSilent(context, apkPath, packageInfo.version);
  }
  
  /// Show error dialog with retry option
  static void _showErrorDialog(BuildContext context, String message) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF2a2e6a),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Row(
            children: [
              Icon(Icons.error, color: Colors.red, size: 28),
              SizedBox(width: 12),
              Text(
                'Xəta',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          content: Text(
            message,
            style: TextStyle(
              fontFamily: 'Poppins',
              color: Colors.white.withOpacity(0.9),
              fontSize: 16,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text(
                'Bağla',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  color: Colors.white,
                  fontSize: 16,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

/// Progress dialog widget for update download
class UpdateProgressDialog extends StatefulWidget {
  const UpdateProgressDialog({super.key});
  
  static void Function(double)? _updateProgressCallback;
  
  static void updateProgress(double progress) {
    _updateProgressCallback?.call(progress);
  }
  
  @override
  State<UpdateProgressDialog> createState() => _UpdateProgressDialogState();
}

class _UpdateProgressDialogState extends State<UpdateProgressDialog> {
  double _progress = 0.0;
  
  @override
  void initState() {
    super.initState();
    UpdateProgressDialog._updateProgressCallback = (progress) {
      if (mounted) {
        setState(() {
          _progress = progress;
        });
      }
    };
  }
  
  @override
  void dispose() {
    UpdateProgressDialog._updateProgressCallback = null;
    super.dispose();
  }
  
  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFF2a2e6a),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'Yeniləmə yüklənir...',
            style: TextStyle(
              fontFamily: 'Poppins',
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 24),
          LinearProgressIndicator(
            value: _progress,
            backgroundColor: Colors.white.withOpacity(0.3),
            valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFFffc107)),
          ),
          const SizedBox(height: 16),
          Text(
            '${(_progress * 100).toStringAsFixed(0)}%',
            style: TextStyle(
              fontFamily: 'Poppins',
              color: Colors.white.withOpacity(0.8),
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }
}