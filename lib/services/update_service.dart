import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:ota_update/ota_update.dart';
import 'package:package_info_plus/package_info_plus.dart';

class UpdateService {
  // Laravel backend API URL for APK version checking
  static const String _updateApiUrl = 'https://connect.admein.az/api/app-version';
  
  // GitHub API URL for APK releases
  static const String _githubApiUrl = 'https://api.github.com/repos/ImranJeferly/admein/releases/latest';
  
  /// Check for app updates on startup
  static Future<void> checkForUpdates(BuildContext context) async {
    try {
      print('🔄 [UPDATE] Checking for app updates...');
      
      // Get current app version
      final packageInfo = await PackageInfo.fromPlatform();
      final currentVersion = packageInfo.version;
      print('🔄 [UPDATE] Current app version: $currentVersion');
      
      // Call GitHub API
      final response = await http.get(
        Uri.parse(_githubApiUrl),
        headers: {
          'Accept': 'application/vnd.github.v3+json',
          'User-Agent': 'AdmainApp-UpdateChecker',
        },
      ).timeout(const Duration(seconds: 10));
      
      if (response.statusCode == 200) {
        final releaseData = jsonDecode(response.body);
        final latestVersion = releaseData['tag_name'] as String;
        
        print('🔄 [UPDATE] Latest version: $latestVersion');
        
        if (_isNewerVersion(currentVersion, latestVersion)) {
          print('🔄 [UPDATE] Update available: $currentVersion -> $latestVersion');
          
          // Get APK download URL
          final assets = releaseData['assets'] as List;
          String? apkDownloadUrl;
          
          for (final asset in assets) {
            final fileName = asset['name'] as String;
            if (fileName.endsWith('.apk')) {
              apkDownloadUrl = asset['browser_download_url'] as String;
              break;
            }
          }
          
          if (apkDownloadUrl != null && context.mounted) {
            _showUpdateDialog(context, currentVersion, latestVersion, apkDownloadUrl);
          } else {
            print('⚠️ [UPDATE] No APK found in release assets');
          }
        } else {
          print('✅ [UPDATE] App is up to date');
        }
      } else {
        print('⚠️ [UPDATE] GitHub API returned status: ${response.statusCode}');
      }
      
    } catch (e) {
      print('❌ [UPDATE] Error checking for updates: $e');
      // Continue app normally on error - don't block startup
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
  
  /// Download and install the update
  static Future<void> _downloadAndInstallUpdate(BuildContext context, String downloadUrl, String version) async {
    // Show progress dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return const UpdateProgressDialog();
      },
    );
    
    try {
      print('📥 [UPDATE] Starting download from: $downloadUrl');
      
      // Get app directory for storing the APK
      final directory = await getExternalStorageDirectory();
      final apkPath = '${directory!.path}/admain_update_$version.apk';
      
      // Download APK with progress tracking
      final request = http.Request('GET', Uri.parse(downloadUrl));
      final streamedResponse = await request.send();
      
      if (streamedResponse.statusCode == 200) {
        final file = File(apkPath);
        final sink = file.openWrite();
        
        final totalBytes = streamedResponse.contentLength ?? 0;
        int downloadedBytes = 0;
        
        await for (final chunk in streamedResponse.stream) {
          sink.add(chunk);
          downloadedBytes += chunk.length;
          
          if (totalBytes > 0) {
            final progress = downloadedBytes / totalBytes;
            // Update progress in dialog
            UpdateProgressDialog.updateProgress(progress);
          }
        }
        
        await sink.close();
        print('✅ [UPDATE] APK downloaded to: $apkPath');
        
        // Close progress dialog and install the APK
        if (context.mounted) {
          Navigator.of(context).pop();
          await _installApk(context, apkPath);
        }
        
      } else {
        throw Exception('Download failed with status: ${streamedResponse.statusCode}');
      }
      
    } catch (e) {
      print('❌ [UPDATE] Download failed: $e');
      
      // Close progress dialog
      if (context.mounted) {
        Navigator.of(context).pop();
        
        // Show error dialog
        _showErrorDialog(context, 'Yeniləmə yüklənmədi: $e');
      }
    }
  }
  
  /// Install the downloaded APK
  static Future<void> _installApk(BuildContext context, String apkPath) async {
    try {
      print('📱 [UPDATE] Installing APK: $apkPath');
      
      // Use OTA Update plugin to install the APK
      try {
        OtaUpdate().execute(
          apkPath,
          destinationFilename: 'admain_update.apk',
        ).listen((OtaEvent event) {
          print('📱 [UPDATE] OTA Event: ${event.status}');
        });
        
        print('✅ [UPDATE] Installation initiated');
      } on Exception catch (e) {
        print('❌ [UPDATE] OTA execution failed: $e');
        
        if (context.mounted) {
          _showErrorDialog(context, 'Yeniləmə quraşdırılmadı: $e');
        }
      }
      
    } catch (e) {
      print('❌ [UPDATE] Installation failed: $e');
      
      if (context.mounted) {
        _showErrorDialog(context, 'Yeniləmə quraşdırılmadı: $e');
      }
    }
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