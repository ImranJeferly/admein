import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import '../models/ad_model.dart';
import '../models/quiz_model.dart';
import '../models/performance_model.dart';
import '../models/driver_profile_model.dart';
import 'local_storage_service.dart';

class ApiService {
  static String baseUrl = 'http://connect.admein.az/api/panel';
  
  String? _driverId;
  String? _actualDriverId; // The actual ID (2) for ride status
  String? _authToken;
  String? _csrfToken;
  String? _logoUrl;
  

  // Getters for external access
  String? get logoUrl => _logoUrl;
  String? get actualDriverId => _actualDriverId;
  String? get driverId => _driverId;

  // Restore authentication state from saved data
  Future<void> restoreAuthenticationState({
    required String authToken,
    required String driverId,
    required String actualDriverId,
    String? logoUrl,
  }) async {
    _authToken = authToken;
    _driverId = driverId;
    _actualDriverId = actualDriverId;
    _logoUrl = logoUrl;
    
    print('🔐 [API] Restored authentication state');
    print('🔐 [API] Driver ID (driverid): $_driverId');
    print('🔐 [API] Actual Driver ID (id): $_actualDriverId');
    print('🔐 [API] Logo URL: $_logoUrl');
  }


  Future<Map<String, dynamic>> authenticate(String password) async {
    try {
      final url = '$baseUrl?password=$password';
      print('🔐 [AUTH] Attempting authentication with: $url');
      
      final response = await http.get(
        Uri.parse(url),
      );

      print('🔐 [AUTH] Response status: ${response.statusCode}');
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        print('🔐 [AUTH] Response data: $data');
        
        if (data['status'] == 'success' && data['user'] != null) {
          // Extract driver ID from user object
          _driverId = data['user']['driverid']?.toString();
          _actualDriverId = data['user']['id']?.toString(); // The actual ID for ride status
          _authToken = password; // Use password as token for subsequent requests
          
          print('🔐 [AUTH] Driver ID (driverid): $_driverId');
          print('🔐 [AUTH] Actual Driver ID (id): $_actualDriverId');
          print('🔐 [AUTH] Car Number: ${data['user']['car_number']}');
          
          // Extract logo URL if available
          if (data['logo'] != null && data['logo'].toString().isNotEmpty) {
            final logoFilename = data['logo'].toString();
            _logoUrl = 'http://connect.admein.az/storage/logos/$logoFilename';
            print('🔐 [AUTH] Logo filename: $logoFilename');
            print('🔐 [AUTH] Full logo URL: $_logoUrl');
          } else {
            print('🔐 [AUTH] No logo found in response');
          }
          
          // Parse ads from 'videoList' array
          List<AdModel> ads = [];
          if (data['videoList'] != null) {
            print('🔐 [AUTH] Raw videoList: ${data['videoList']}');
            ads = (data['videoList'] as List)
                .map((videoJson) => AdModel.fromJson(videoJson))
                .toList();
          } else {
            print('🔐 [AUTH] ⚠️ WARNING: videoList is null in API response!');
            print('🔐 [AUTH] Full API response: $data');
          }
          
          print('🔐 [AUTH] Found ${ads.length} videos/ads');
          for (int i = 0; i < ads.length; i++) {
            print('🔐 [AUTH] Ad ${i + 1}: ${ads[i].id} - "${ads[i].url}" - QR: ${ads[i].qrLink != null ? "YES" : "NO"}');
          }
              
          // Download media files after successful authentication
          print('⬇️ [DOWNLOAD] Starting media download for ${ads.length} ads...');
          final adsWithLocalPaths = await _downloadMediaFiles(ads);
          
          return {
            'success': true,
            'driver_id': _driverId,
            'ads': adsWithLocalPaths,
            'car_number': data['user']['car_number'],
            'user_id': data['user']['id'],
            'logo_url': _logoUrl,
          };
        } else {
          return {'success': false, 'error': 'Invalid response format'};
        }
      } else {
        return {
          'success': false, 
          'error': 'HTTP ${response.statusCode}: ${response.body}'
        };
      }
    } catch (e) {
      return {'success': false, 'error': 'Network error: $e'};
    }
  }

  Future<void> _fetchCsrfToken() async {
    if (_csrfToken != null) return; // Already have token
    
    try {
      print('💓 [CSRF] Fetching CSRF token...');
      // Use HTTP for CSRF token fetching (HTTPS returns 404)
      final csrfResponse = await http.get(Uri.parse('http://connect.admein.az'));
      
      if (csrfResponse.statusCode == 200) {
        // Extract CSRF token from response
        final tokenMatch = RegExp(r'name="_token".*?value="([^"]+)"').firstMatch(csrfResponse.body);
        _csrfToken = tokenMatch?.group(1);
        if (_csrfToken != null) {
          print('💓 [CSRF] Token extracted: ${_csrfToken!.substring(0, 10)}...');
        } else {
          print('💓 [CSRF] Token not found in response');
        }
      } else {
        print('💓 [CSRF] Failed to fetch token - Status: ${csrfResponse.statusCode}');
      }
    } catch (e) {
      print('💓 [CSRF] Error fetching token: $e');
    }
  }

  Future<bool> sendAliveSignal() async {
    if (_actualDriverId == null) {
      print('💓 [ALIVE] Skipped - No actual driver ID available (actualDriverId: $_actualDriverId)');
      return false;
    }
    
    try {
      final url = 'https://connect.admein.az/api/record-connection/$_actualDriverId';
      print('💓 [ALIVE] Sending alive signal to: $url with tablet_id: $_driverId');
      
      final response = await http.get(Uri.parse(url));
      
      print('💓 [ALIVE] Response status: ${response.statusCode}');
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final success = data['success'] == true || data['status'] == 'success';
        print('💓 [ALIVE] Response body: ${response.body}');
        print('💓 [ALIVE] Success: $success');
        return success;
      } else {
        print('💓 [ALIVE] Response body: ${response.body}');
        return false;
      }
    } catch (e) {
      print('💓 [ALIVE] Error: $e');
      return false;
    }
  }

  Future<Map<String, dynamic>> checkRideStatusAndOrderCompletion() async {
    if (_actualDriverId == null) {
      print('🚗 [RIDE] Skipped - No actual driver ID available (actualDriverId: $_actualDriverId)');
      return {'isOnRide': false, 'orderCompleted': false};
    }
    
    try {
      // 1. Check ride status
      final statusUrl = 'http://connect.admein.az/fetch-status/$_actualDriverId';
      print('🚗 [RIDE] Checking ride status: $statusUrl');
      
      final statusResponse = await http.get(Uri.parse(statusUrl));
      
      print('🚗 [RIDE] Status response: ${statusResponse.statusCode}');
      print('🚗 [RIDE] Status body: ${statusResponse.body}');
      
      bool isOnRide = false;
      if (statusResponse.statusCode == 200) {
        final data = jsonDecode(statusResponse.body);
        final currentStatus = data['currentStatus']?.toString() ?? 'offline';
        
        // Driver is ON ride (show ads) only if status is 'in_order_free' or 'in_order_busy'
        final onRideStatuses = ['in_order_free', 'in_order_busy'];
        isOnRide = onRideStatuses.contains(currentStatus.toLowerCase());
        
        print('🚗 [RIDE] Status from server: $currentStatus');
        print('🚗 [RIDE] Is on ride: $isOnRide (checking against: $onRideStatuses)');
      } else {
        print('🚗 [RIDE] Non-200 status response (${statusResponse.statusCode}) - assuming offline');
      }
      
      // 2. Check for order completion
      final ordersUrl = 'https://connect.admein.az/api/store-orders';
      final ordersPayload = {
        'driverid': _driverId,        // Long driver ID (driverid from API)  
        'userid': int.tryParse(_actualDriverId!) ?? 0,  // Numeric user ID
      };
      
      print('🏁 [ORDER] Checking order completion: $ordersUrl');
      print('🏁 [ORDER] Request payload: ${jsonEncode(ordersPayload)}');
      print('🏁 [ORDER] driverid type: ${_driverId.runtimeType}, value: $_driverId');
      print('🏁 [ORDER] userid type: ${(int.tryParse(_actualDriverId!) ?? 0).runtimeType}, value: ${int.tryParse(_actualDriverId!) ?? 0}');
      
      final ordersResponse = await http.post(
        Uri.parse(ordersUrl),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode(ordersPayload),
      );
      
      print('🏁 [ORDER] Orders response: ${ordersResponse.statusCode}');
      print('🏁 [ORDER] Orders body: ${ordersResponse.body}');
      
      bool orderCompleted = false;
      if (ordersResponse.statusCode == 200) {
        try {
          final orderData = jsonDecode(ordersResponse.body);
          final message = orderData['message']?.toString().toLowerCase() ?? '';
          orderCompleted = message == 'added'; // Exact match, not substring
          print('🏁 [ORDER] Message: "$message", Order completed: $orderCompleted');
        } catch (e) {
          print('🏁 [ORDER] Error parsing order response: $e');
        }
      }
      
      return {
        'isOnRide': isOnRide,
        'orderCompleted': orderCompleted,
      };
    } catch (e) {
      print('🚗 [RIDE] Error: $e - assuming offline');
      return {'isOnRide': false, 'orderCompleted': false};
    }
  }
  
  Future<bool> checkRideStatus() async {
    final result = await checkRideStatusAndOrderCompletion();
    return result['isOnRide'] ?? false;
  }

  Future<bool> sendPerformanceData(List<AdPerformance> performances, List<RideRating> ratings) async {
    if (_actualDriverId == null) {
      print('📊 [PERF_API] ❌ No actual driver ID available - cannot send performance data');
      return false;
    }
    
    final tabletId = int.tryParse(_actualDriverId!) ?? 0;
    print('📊 [PERF_API] ✅ Sending performance data for actual_driver_id: $_actualDriverId (tablet_id: $tabletId)');
    
    try {
      bool allSuccess = true;
      
      // 1. Send views to /record-view
      if (performances.isNotEmpty) {
        final viewsData = {
          'views': performances.where((p) => p.viewCount > 0).map((p) => {
            'ad_id': int.tryParse(p.adId) ?? 1,
            'tablet_id': tabletId,
            'count': p.viewCount,
          }).toList(),
        };
        
        if (viewsData['views']!.isNotEmpty) {
          final viewsUrl = 'https://connect.admein.az/api/record-view';
          print('📊 [VIEWS] 📤 Sending to: $viewsUrl');
          print('📊 [VIEWS] 📦 Payload: ${jsonEncode(viewsData)}');
          
          final viewsResponse = await http.post(
            Uri.parse(viewsUrl),
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
            body: jsonEncode(viewsData),
          );
          
          print('📊 [VIEWS] 📨 Response status: ${viewsResponse.statusCode}');
          print('📊 [VIEWS] 📨 Response body: ${viewsResponse.body}');
          
          if (viewsResponse.statusCode != 200) {
            allSuccess = false;
          }
        }
        
        // 2. Send clicks to /record-click
        final clicksData = {
          'clicks': performances.where((p) => p.clickCount > 0).map((p) => {
            'ad_id': int.tryParse(p.adId) ?? 1,
            'tablet_id': tabletId,
            'count': p.clickCount,
          }).toList(),
        };
        
        if (clicksData['clicks']!.isNotEmpty) {
          final clicksUrl = 'https://connect.admein.az/api/record-click';
          print('📊 [CLICKS] 📤 Sending to: $clicksUrl');
          print('📊 [CLICKS] 📦 Payload: ${jsonEncode(clicksData)}');
          
          final clicksResponse = await http.post(
            Uri.parse(clicksUrl),
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
            body: jsonEncode(clicksData),
          );
          
          print('📊 [CLICKS] 📨 Response status: ${clicksResponse.statusCode}');
          print('📊 [CLICKS] 📨 Response body: ${clicksResponse.body}');
          
          if (clicksResponse.statusCode != 200) {
            allSuccess = false;
          }
        }
        
        // 3. Send video tracking to /track-video (for played seconds)
        final videosData = {
          'videos': performances.where((p) => p.playedSeconds > 0).map((p) => {
            'videoid': p.adId,
            'duration': p.playedSeconds.round(),
            'userid': tabletId,
          }).toList(),
        };
        
        if (videosData['videos']!.isNotEmpty) {
          final videosUrl = 'https://connect.admein.az/api/track-video';
          print('📊 [VIDEOS] 📤 Sending to: $videosUrl');
          print('📊 [VIDEOS] 📦 Payload: ${jsonEncode(videosData)}');
          
          final videosResponse = await http.post(
            Uri.parse(videosUrl),
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
            body: jsonEncode(videosData),
          );
          
          print('📊 [VIDEOS] 📨 Response status: ${videosResponse.statusCode}');
          print('📊 [VIDEOS] 📨 Response body: ${videosResponse.body}');
          
          if (videosResponse.statusCode != 200 && videosResponse.statusCode != 201) {
            allSuccess = false;
          }
        }
      }
      
      // 4. Send orders to /store-orders (for ride ratings)
      if (ratings.isNotEmpty) {
        final ordersData = {
          'tablet_id': tabletId,
          'ratings': ratings.map((r) => r.toJson()).toList(),
        };
        
        final ordersUrl = 'https://connect.admein.az/api/store-orders';
        print('📊 [ORDERS] 📤 Sending to: $ordersUrl');
        print('📊 [ORDERS] 📦 Payload: ${jsonEncode(ordersData)}');
        
        final ordersResponse = await http.post(
          Uri.parse(ordersUrl),
          headers: {
            'Content-Type': 'application/json',
            'Accept': 'application/json',
          },
          body: jsonEncode(ordersData),
        );
        
        print('📊 [ORDERS] 📨 Response status: ${ordersResponse.statusCode}');
        print('📊 [ORDERS] 📨 Response body: ${ordersResponse.body}');
        
        if (ordersResponse.statusCode != 200) {
          allSuccess = false;
        }
      }
      
      if (allSuccess) {
        print('📊 [PERF_API] ✅ All performance data sent successfully');
        return true;
      } else {
        print('📊 [PERF_API] ❌ Some requests failed');
        return false;
      }
    } catch (e) {
      print('📊 [PERF_API] ❌ Exception occurred: $e');
      return false;
    }
  }

  Future<bool> sendDetailedRatings(Map<String, String> ratingsWithTimestamp) async {
    if (_actualDriverId == null) {
      print('📊 [RATINGS_API] ❌ No actual driver ID available - cannot send detailed ratings');
      return false;
    }
    
    final tabletId = int.tryParse(_actualDriverId!) ?? 0;
    print('📊 [RATINGS_API] ✅ Sending detailed ratings for actual_driver_id: $_actualDriverId (tablet_id: $tabletId)');
    
    try {
      // Map internal rating types to proper question text
      final questionMap = {
        'interest': 'Ad relevance',
        'attention': 'Video quality',
        'frequency': 'Ad frequency',
        'quality': 'Overall satisfaction',
      };
      
      // Use correct endpoint for saving feedback (HTTP for mobile API)
      final ratingsData = {
        'tablet_id': tabletId,
        'ratings': ratingsWithTimestamp.entries.map((entry) {
          final parts = entry.value.split('|');
          final rating = parts[0]; // Keep as string instead of parsing to int
          final questionText = questionMap[entry.key] ?? entry.key;
          return {
            'question': questionText,
            'rating': rating,
          };
        }).toList(),
      };
      
      final url = 'https://connect.admein.az/api/savefeedback';
      print('📊 [RATINGS_API] 📤 Sending to: $url');
      print('📊 [RATINGS_API] 📦 Payload: ${jsonEncode(ratingsData)}');
      
      final response = await http.post(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode(ratingsData),
      );
      
      print('📊 [RATINGS_API] 📨 Response status: ${response.statusCode}');
      print('📊 [RATINGS_API] 📨 Response body: ${response.body}');
      
      if (response.statusCode == 200) {
        print('📊 [RATINGS_API] ✅ Detailed ratings sent successfully');
        return true;
      } else {
        print('📊 [RATINGS_API] ❌ Failed with status ${response.statusCode}: ${response.body}');
        return false;
      }
    } catch (e) {
      print('📊 [RATINGS_API] ❌ Exception occurred: $e');
      return false;
    }
  }

  Future<List<AdModel>> getUpdatedAds() async {
    if (_driverId == null || _authToken == null) return [];
    
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/ads?password=$_authToken&driver_id=$_driverId'),
      );
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['ads'] != null) {
          return (data['ads'] as List)
              .map((adJson) => AdModel.fromJson(adJson))
              .toList();
        }
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  Future<Map<String, dynamic>> checkForUpdates(List<AdModel> currentAds) async {
    if (_driverId == null || _authToken == null) {
      return {'success': false, 'error': 'Not authenticated'};
    }
    
    try {
      print('🔄 [UPDATE] Checking for ad updates...');
      final url = '$baseUrl?password=$_authToken';
      
      final response = await http.get(Uri.parse(url));
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        
        if (data['status'] == 'success' && data['videoList'] != null) {
          // Extract logo URL if available
          String? newLogoUrl;
          if (data['logo'] != null && data['logo'].toString().isNotEmpty) {
            final logoFilename = data['logo'].toString();
            newLogoUrl = 'http://connect.admein.az/storage/logos/$logoFilename';
            print('🔄 [UPDATE] Found logo filename: $logoFilename');
            print('🔄 [UPDATE] Full logo URL: $newLogoUrl');
          }
          
          // Check if logo has changed
          bool logoChanged = newLogoUrl != _logoUrl;
          if (logoChanged) {
            print('🔄 [UPDATE] Logo URL changed from $_logoUrl to $newLogoUrl');
            _logoUrl = newLogoUrl;
          }
          
          // Parse new ads from API
          final List<AdModel> newAds = (data['videoList'] as List)
              .map((videoJson) => AdModel.fromJson(videoJson))
              .toList();
          
          print('🔄 [UPDATE] Found ${newAds.length} ads in API, currently have ${currentAds.length}');
          
          // Compare current ads with new ads
          final updateResult = _compareAndUpdateAds(currentAds, newAds);
          
          if (updateResult['hasChanges'] || logoChanged) {
            print('🔄 [UPDATE] Changes detected! New: ${updateResult['toAdd'].length}, Remove: ${updateResult['toRemove'].length}');
            
            // Download new media files
            final List<AdModel> adsToAdd = updateResult['toAdd'];
            if (adsToAdd.isNotEmpty) {
              final adsWithLocalPaths = await _downloadMediaFiles(adsToAdd);
              updateResult['toAdd'] = adsWithLocalPaths;
            }
            
            return {
              'success': true,
              'hasChanges': true,
              'toAdd': updateResult['toAdd'],
              'toRemove': updateResult['toRemove'],
              'allUpdatedAds': updateResult['allUpdatedAds'],
              'logoUrl': _logoUrl,
              'logoChanged': logoChanged,
            };
          } else {
            print('🔄 [UPDATE] No changes detected');
            return {'success': true, 'hasChanges': false};
          }
        }
      }
      
      return {'success': false, 'error': 'Invalid API response'};
    } catch (e) {
      print('🔄 [UPDATE] Error checking for updates: $e');
      return {'success': false, 'error': e.toString()};
    }
  }

  Map<String, dynamic> _compareAndUpdateAds(List<AdModel> currentAds, List<AdModel> newAds) {
    final currentAdIds = currentAds.map((ad) => ad.id).toSet();
    final newAdIds = newAds.map((ad) => ad.id).toSet();
    
    // Find ads to add (new ads not in current list)
    final toAdd = newAds.where((ad) => !currentAdIds.contains(ad.id)).toList();
    
    // Find ads to remove (current ads not in new list)
    final toRemove = currentAds.where((ad) => !newAdIds.contains(ad.id)).toList();
    
    // Find ads that might have been updated (same ID but different properties)
    final toUpdate = <AdModel>[];
    for (final newAd in newAds) {
      final currentAdList = currentAds.where((ad) => ad.id == newAd.id);
      if (currentAdList.isNotEmpty) {
        final currentAd = currentAdList.first;
        if (_adHasChanged(currentAd, newAd)) {
          toUpdate.add(newAd);
        }
      }
    }
    
    // Combine updates with additions for downloading
    final toAddAndUpdate = [...toAdd, ...toUpdate];
    
    // Create the final updated ads list
    final Map<String, AdModel> updatedAdsMap = {};
    
    // Add existing ads that haven't changed and aren't being removed
    for (final currentAd in currentAds) {
      if (newAdIds.contains(currentAd.id) && 
          !toUpdate.any((ad) => ad.id == currentAd.id)) {
        updatedAdsMap[currentAd.id] = currentAd;
      }
    }
    
    // Add new ads (will be filled with local paths after download)
    for (final newAd in newAds) {
      if (toAdd.any((ad) => ad.id == newAd.id)) {
        // This is a completely new ad, will get local path after download
        updatedAdsMap[newAd.id] = newAd;
      } else if (!toUpdate.any((ad) => ad.id == newAd.id)) {
        // This ad exists and hasn't changed, keep the current version with local path
        final existingAd = currentAds.firstWhere((ad) => ad.id == newAd.id);
        updatedAdsMap[newAd.id] = existingAd;
      }
    }
    
    final hasChanges = toAdd.isNotEmpty || toRemove.isNotEmpty || toUpdate.isNotEmpty;
    
    return {
      'hasChanges': hasChanges,
      'toAdd': toAddAndUpdate, // Include both new and updated ads for downloading
      'toRemove': toRemove,
      'toUpdate': toUpdate,
      'allUpdatedAds': updatedAdsMap.values.toList(),
    };
  }

  bool _adHasChanged(AdModel currentAd, AdModel newAd) {
    return currentAd.url != newAd.url ||
           currentAd.type != newAd.type ||
           currentAd.duration != newAd.duration ||
           currentAd.qrLink != newAd.qrLink;
  }

  Future<List<AdModel>> _downloadMediaFiles(List<AdModel> ads) async {
    final List<AdModel> updatedAds = [];
    
    // Get app documents directory
    final Directory appDir = await getApplicationDocumentsDirectory();
    final Directory mediaDir = Directory('${appDir.path}/media');
    
    // Create media directory if it doesn't exist
    if (!await mediaDir.exists()) {
      await mediaDir.create(recursive: true);
      print('⬇️ [DOWNLOAD] Created media directory: ${mediaDir.path}');
    }
    
    for (final ad in ads) {
      try {
        // Skip quiz ads - they don't have media files to download
        if (ad.type == 'quiz') {
          print('🧠 [DOWNLOAD] Skipping quiz ad: ${ad.id} - no media to download');
          updatedAds.add(ad);
          continue;
        }

        // Extract filename from URL
        final uri = Uri.parse(ad.url);
        final filename = path.basename(uri.path);
        final localFilePath = '${mediaDir.path}/$filename';
        final localFile = File(localFilePath);
        
        // Check if file already exists and is valid
        if (await localFile.exists()) {
          final fileSize = await localFile.length();
          if (fileSize > 0) {
            print('⬇️ [DOWNLOAD] File already exists: $filename (${fileSize} bytes)');
            updatedAds.add(ad.copyWith(localPath: localFilePath));
            continue;
          }
        }
        
        print('⬇️ [DOWNLOAD] Downloading: ${ad.url}');
        
        // Download the file
        final response = await http.get(Uri.parse(ad.url));
        
        if (response.statusCode == 200) {
          await localFile.writeAsBytes(response.bodyBytes);
          final fileSize = response.bodyBytes.length;
          print('⬇️ [DOWNLOAD] Success: $filename (${fileSize} bytes)');
          
          // Add ad with local path
          updatedAds.add(ad.copyWith(localPath: localFilePath));
        } else {
          print('⬇️ [DOWNLOAD] Failed: ${ad.url} (Status: ${response.statusCode})');
          // Add ad without local path (will use remote URL as fallback)
          updatedAds.add(ad);
        }
      } catch (e) {
        print('⬇️ [DOWNLOAD] Error downloading ${ad.url}: $e');
        // Add ad without local path (will use remote URL as fallback)
        updatedAds.add(ad);
      }
    }
    
    print('⬇️ [DOWNLOAD] Download complete: ${updatedAds.where((ad) => ad.localPath != null).length}/${ads.length} files downloaded');
    return updatedAds;
  }

  Future<QuizModel?> fetchQuizForAd(String adId) async {
    try {
      final url = 'https://connect.admein.az/api/quiz/$adId';
      print('🧠 [QUIZ] Fetching quiz data from: $url');
      
      final response = await http.get(Uri.parse(url));
      
      print('🧠 [QUIZ] Response status: ${response.statusCode}');
      print('🧠 [QUIZ] Response body: ${response.body}');
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        print('🧠 [QUIZ] Parsed response data: $data');
        
        if (data['status'] == 'success') {
          print('🧠 [QUIZ] ✅ Status is success - extracting quiz data');
          print('🧠 [QUIZ] Raw quiz data: ${data['data']}');
          
          // Create a quiz model with the ad ID and extract questions
          final quizData = {
            'id': adId,
            'brand': 'Quiz', // Default brand name
            'data': data['data'],
          };
          
          print('🧠 [QUIZ] Creating QuizModel with data: $quizData');
          
          final quiz = QuizModel.fromJson(quizData);
          print('🧠 [QUIZ] ✅ Successfully created quiz with ${quiz.questions.length} questions');
          
          if (quiz.questions.isEmpty) {
            print('🧠 [QUIZ] ⚠️ WARNING: Quiz was created but has 0 questions!');
          }
          
          return quiz;
        } else {
          print('🧠 [QUIZ] ❌ Status is not success: ${data['status']}');
        }
      } else {
        print('🧠 [QUIZ] ❌ HTTP error: ${response.statusCode} - ${response.body}');
      }
      
      print('🧠 [QUIZ] ❌ Failed to fetch quiz data for ad: $adId');
      return null;
    } catch (e) {
      print('🧠 [QUIZ] Error fetching quiz: $e');
      return null;
    }
  }

  Future<DriverProfileModel?> fetchDriverProfile(String driverId) async {
    try {
      final url = 'https://connect.admein.az/api/driver-profile/$driverId';
      print('👤 [DRIVER] Fetching driver profile: $url');
      print('👤 [DRIVER] Driver ID parameter: $driverId');
      print('👤 [DRIVER] Current _actualDriverId: $_actualDriverId');
      print('👤 [DRIVER] Current _driverId: $_driverId');
      
      final response = await http.get(Uri.parse(url)).timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          throw Exception('Driver profile API request timeout');
        },
      );
      
      print('👤 [DRIVER] Response status: ${response.statusCode}');
      print('👤 [DRIVER] Response body: ${response.body}');
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        print('👤 [DRIVER] ✅ Driver profile fetched successfully');
        print('👤 [DRIVER] Data keys: ${data.keys.toList()}');
        
        return DriverProfileModel.fromJson(data);
      } else {
        print('👤 [DRIVER] ❌ HTTP error: ${response.statusCode}');
        print('👤 [DRIVER] Error response body: ${response.body}');
        return null;
      }
    } catch (e) {
      print('👤 [DRIVER] ❌ Error fetching driver profile: $e');
      return null;
    }
  }

  Future<String?> getAdLogo(String adId) async {
    if (_actualDriverId == null) {
      print('🏷️ [LOGO] Skipped - No actual driver ID available');
      return null;
    }
    
    try {
      final url = 'https://connect.admein.az/api/generate-qr/$adId/$_actualDriverId';
      print('🏷️ [LOGO] Fetching logo from QR API: $url');
      
      final response = await http.get(Uri.parse(url));
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final logoUrl = data['logo'];
        
        print('🏷️ [LOGO] Logo URL received: $logoUrl');
        return logoUrl;
      } else {
        print('🏷️ [LOGO] HTTP error: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      print('🏷️ [LOGO] Error fetching logo: $e');
      return null;
    }
  }

  Future<Map<String, String?>> generateQrCode(String adId) async {
    if (_actualDriverId == null) {
      print('📱 [QR] Skipped - No actual driver ID available');
      return {'qr_code': null, 'logo': null};
    }
    
    try {
      final url = 'https://connect.admein.az/api/generate-qr/$adId/$_actualDriverId';
      print('📱 [QR] Generating QR code: $url');
      
      final response = await http.get(Uri.parse(url));
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final qrCodeUrl = data['qr_code'];
        final logoUrl = data['logo'];
        
        print('📱 [QR] QR code received (${qrCodeUrl?.length} chars)');
        print('📱 [QR] Logo URL: $logoUrl');
        
        return {
          'qr_code': qrCodeUrl,
          'logo': logoUrl,
        };
      } else {
        print('📱 [QR] Failed to generate QR code - Status: ${response.statusCode}');
        print('📱 [QR] Response: ${response.body}');
        return {'qr_code': null, 'logo': null};
      }
    } catch (e) {
      print('📱 [QR] Error generating QR code: $e');
      return {'qr_code': null, 'logo': null};
    }
  }


  Future<void> cleanupRemovedAds(List<AdModel> adsToRemove) async {
    if (adsToRemove.isEmpty) return;
    
    print('🗑️ [CLEANUP] Cleaning up ${adsToRemove.length} removed ads...');
    
    for (final ad in adsToRemove) {
      if (ad.localPath != null) {
        try {
          final file = File(ad.localPath!);
          if (await file.exists()) {
            await file.delete();
            print('🗑️ [CLEANUP] Deleted local file: ${ad.localPath}');
          }
        } catch (e) {
          print('🗑️ [CLEANUP] Error deleting ${ad.localPath}: $e');
        }
      }
    }
    
    print('🗑️ [CLEANUP] Cleanup complete');
  }

  // Submit quiz answers for a specific ad
  Future<bool> sendQuizResults(String adId, Map<String, String> questionAnswers) async {
    if (_actualDriverId == null) {
      print('🧠 [QUIZ_API] ❌ No actual driver ID available - cannot send quiz results');
      return false;
    }
    
    final tabletId = int.tryParse(_actualDriverId!) ?? 0;
    final adIdInt = int.tryParse(adId) ?? 0;
    
    if (adIdInt == 0) {
      print('🧠 [QUIZ_API] ❌ Invalid ad ID: $adId');
      return false;
    }
    
    print('🧠 [QUIZ_API] ✅ Sending quiz results for ad: $adId (tablet_id: $tabletId)');
    
    try {
      // Convert question-answer pairs to the required format
      final List<Map<String, String>> quizResults = questionAnswers.entries.map((entry) {
        return {
          'question': entry.key,
          'selected_option': entry.value,
        };
      }).toList();
      
      final requestData = {
        'ad_id': adIdInt,
        'tablet_id': tabletId,
        'quiz': quizResults,
      };
      
      final url = 'https://connect.admein.az/api/sendQuizResult';
      print('🧠 [QUIZ_API] 📤 Sending to: $url');
      print('🧠 [QUIZ_API] 📦 Payload: ${jsonEncode(requestData)}');
      
      final response = await http.post(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode(requestData),
      );
      
      print('🧠 [QUIZ_API] 📨 Response status: ${response.statusCode}');
      print('🧠 [QUIZ_API] 📨 Response body: ${response.body}');
      
      if (response.statusCode == 200) {
        print('🧠 [QUIZ_API] ✅ Quiz results sent successfully for ad: $adId');
        return true;
      } else {
        print('🧠 [QUIZ_API] ❌ Failed with status ${response.statusCode}: ${response.body}');
        return false;
      }
    } catch (e) {
      print('🧠 [QUIZ_API] ❌ Exception occurred: $e');
      return false;
    }
  }

  // Submit all quiz answers for all ads
  Future<bool> sendAllQuizResults(Map<String, Map<String, String>> allQuizAnswers) async {
    if (allQuizAnswers.isEmpty) {
      print('🧠 [QUIZ_API] ℹ️ No quiz answers to send');
      return true;
    }
    
    bool allSuccess = true;
    
    for (final entry in allQuizAnswers.entries) {
      final String adId = entry.key;
      final Map<String, String> answers = entry.value;
      
      if (answers.isNotEmpty) {
        final success = await sendQuizResults(adId, answers);
        if (!success) {
          allSuccess = false;
          print('🧠 [QUIZ_API] ❌ Failed to send quiz results for ad: $adId');
        }
      }
    }
    
    if (allSuccess) {
      print('🧠 [QUIZ_API] ✅ All quiz results sent successfully');
    } else {
      print('🧠 [QUIZ_API] ⚠️ Some quiz results failed to send');
    }
    
    return allSuccess;
  }
}