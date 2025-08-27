import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import '../models/ad_model.dart';
import '../models/performance_model.dart';
import '../models/quiz_model.dart';
import '../models/weather_model.dart';
import '../models/news_model.dart';
import '../models/driver_profile_model.dart';
import 'api_service.dart';
import 'local_storage_service.dart';
import 'weather_service.dart';
import 'news_service.dart';

enum AppState {
  authentication,
  welcome,
  adDisplay,
  nonAdContent,
  qrDisplay,
  logoScreen,
  ratingScreen,
}

enum NonAdContentType {
  weather,
  news,
  rideInfo,
  rate,
}

class AppStateService extends ChangeNotifier {
  final ApiService _apiService = ApiService();
  
  AppState _currentState = AppState.authentication;
  List<AdModel> _ads = [];
  int _currentAdIndex = 0;
  int _currentNonAdIndex = 0;
  bool _isOnRide = false;
  bool _isAuthenticated = false;
  String? _lastError;
  String? _logoUrl;
  String? _qrCodeUrl;
  String? _qrLogoUrl;
  String? _qrText; // Text to show on QR screen
  
  // 5-minute ad cycle tracking
  DateTime? _adCycleStartTime;
  int _totalAdTimeElapsed = 0; // in seconds
  static const int _targetAdCycleDuration = 300; // 5 minutes in seconds
  
  // Individual ad session tracking
  DateTime? _currentAdStartTime;
  
  // Detailed ratings storage
  Map<String, int> _detailedRatings = {
    'interest': 0,
    'attention': 0,
    'frequency': 0,
    'quality': 0,
  };
  
  Timer? _aliveTimer;
  Timer? _rideStatusTimer;
  Timer? _welcomeTimer;
  Timer? _adTimer;
  Timer? _nonAdTimer;
  Timer? _qrTimer;
  Timer? _contentUpdateTimer;
  
  // State transition management
  AppState? _pendingStateChange;
  bool _isInAdCycle = false;
  
  // Ride status stability tracking
  bool _lastRideStatus = false;
  int _consecutiveStatusChecks = 0;
  static const int _statusStabilityThreshold = 2; // Require 2 consecutive checks
  
  // Order completion tracking
  bool _pendingOrderCompletion = false;
  
  // Quiz answers storage - for compatibility with existing quiz screen
  List<QuizAnswer> _quizAnswers = [];

  // Getters
  AppState get currentState => _currentState;
  List<AdModel> get ads => _ads;
  AdModel? get currentAd => _ads.isNotEmpty ? _ads[_currentAdIndex] : null;
  NonAdContentType get currentNonAdContent => 
      NonAdContentType.values[_currentNonAdIndex % NonAdContentType.values.length];
  bool get isOnRide => _isOnRide;
  bool get isAuthenticated => _isAuthenticated;
  String? get lastError => _lastError;
  ApiService get apiService => _apiService;
  
  // Weather and News data - always return real API data
  WeatherModel? get currentWeather => WeatherService.getCachedWeather();
  NewsModel? get currentNews => NewsService.getCurrentNewsArticle();
  
  // Driver profile data
  DriverProfileModel? _driverProfile;
  DriverProfileModel? get driverProfile => _driverProfile;
  
  // Video preloading
  VideoPlayerController? _preloadedVideoController;
  bool _isPreloadingVideo = false;
  String? _preloadedVideoAdId; // Track which ad is preloaded
  VideoPlayerController? get preloadedVideoController => _preloadedVideoController;
  
  void clearPreloadedVideo() {
    print('📹 [PRELOAD] Clearing preloaded video controller reference');
    _preloadedVideoController = null; // Don't dispose here, as AdDisplayScreen now owns it
    _preloadedVideoAdId = null; // Clear the preloaded ad ID
  }
  
  // Mock data methods removed - now using real API data
  
  // Logo URL
  String? get logoUrl => _logoUrl;
  
  // QR Code URLs and Text
  String? get qrCodeUrl => _qrCodeUrl;
  String? get qrLogoUrl => _qrLogoUrl;
  String? get qrText => _qrText;
  
  // Rating methods
  int getRating(String ratingType) => _detailedRatings[ratingType] ?? 0;
  Map<String, int> get allRatings => Map.from(_detailedRatings);

  Future<void> initialize() async {
    print('🚀 [APP] Initializing app...');
    await LocalStorageService.initialize();
    
    // Clear all quiz answers on app restart
    await LocalStorageService.clearAllQuizAnswers();
    
    // Load stored detailed ratings
    _detailedRatings = LocalStorageService.getAllDetailedRatings();
    print('📊 [RATINGS] Loaded stored ratings: $_detailedRatings');
    
    // Check for saved authentication state
    await _checkSavedAuthentication();
    
    print('🚀 [APP] App initialized successfully');
  }

  Future<void> _checkSavedAuthentication() async {
    final savedAuth = LocalStorageService.getSavedAuthenticationState();
    
    if (savedAuth.isNotEmpty && 
        savedAuth['auth_token'] != null && 
        savedAuth['driver_id'] != null && 
        savedAuth['actual_driver_id'] != null) {
      
      print('🔐 [APP] Found saved authentication state');
      print('🔐 [APP] Driver ID: ${savedAuth['driver_id']}');
      print('🔐 [APP] Actual Driver ID: ${savedAuth['actual_driver_id']}');
      
      // Restore authentication state
      _isAuthenticated = true;
      _logoUrl = savedAuth['logo_url'];
      
      // Restore API service state
      await _apiService.restoreAuthenticationState(
        authToken: savedAuth['auth_token']!,
        driverId: savedAuth['driver_id']!,
        actualDriverId: savedAuth['actual_driver_id']!,
        logoUrl: savedAuth['logo_url'],
      );
      
      // Load saved ads from local storage
      _ads = await LocalStorageService.getAds();
      print('💾 [APP] Loaded ${_ads.length} saved ads from local storage');
      if (_ads.isNotEmpty) {
        for (final ad in _ads) {
          print('💾 [APP] ===============================================');
          print('💾 [APP] Ad ${ad.id}:');
          print('💾 [APP]   Type: ${ad.type}');
          print('💾 [APP]   URL: "${ad.url}"');
          print('💾 [APP]   Local Path: "${ad.localPath}"');
          print('💾 [APP]   QR Link: "${ad.qrLink}"');
          print('💾 [APP]   Text: "${ad.text}"');
          print('💾 [APP]   Duration: ${ad.duration}s');
          print('💾 [APP]   Created: ${ad.createdAt}');
          if (ad.url.isEmpty) {
            print('💾 [APP]   ⚠️ WARNING: Empty URL for ad ${ad.id}!');
          }
          if (ad.localPath != null && ad.localPath!.isEmpty) {
            print('💾 [APP]   ⚠️ WARNING: Empty local path for ad ${ad.id}!');
          }
          print('💾 [APP] ===============================================');
        }
      } else {
        print('💾 [APP] ⚠️ WARNING: No saved ads found in local storage!');
        print('💾 [APP] This might be the first run or ads were cleared');
      }
      
      // Fetch driver profile immediately if authenticated
      final driverId = _apiService.driverId; // Use the long driver ID for profile API
      final actualDriverId = _apiService.actualDriverId;
      if (driverId != null) {
        print('👤 [INIT] Fetching driver profile immediately on app start');
        print('👤 [INIT] Using driver_id: $driverId (vs actualDriverId: $actualDriverId)');
        _fetchDriverProfile(driverId);
      } else {
        print('❌ [INIT] No driver ID available for profile fetch');
      }
      
      // Start background timers
      print('⏰ [APP] Starting background timers');
      _startAliveTimer();
      _startRideStatusTimer();
      // Only start content timer if not already running (prevent duplicate weather fetches)
      if (_contentUpdateTimer == null || !_contentUpdateTimer!.isActive) {
        _startContentUpdateTimer();
      } else {
        print('🔄 [CONTENT] Content update timer already running - skipping duplicate start');
      }
      
      // Always start at logo screen (waiting screen) and let ride status check determine next step
      print('🏠 [APP] Starting at logo screen - will check ride status to determine next action');
      _goToLogoScreen();
      
      notifyListeners();
    } else {
      print('🔐 [APP] No saved authentication found');
    }
  }

  Future<bool> authenticate(String password) async {
    print('🔐 [APP] Starting authentication...');
    final result = await _apiService.authenticate(password);
    
    if (result['success']) {
      print('🔐 [APP] Authentication successful!');
      _isAuthenticated = true;
      _ads = result['ads'] ?? [];
      _logoUrl = result['logo_url'];
      _lastError = null;
      
      print('💾 [APP] Received ${_ads.length} ads from authentication');
      if (_ads.isNotEmpty) {
        for (final ad in _ads) {
          print('💾 [APP] ===============================================');
          print('💾 [APP] NEW Ad ${ad.id}:');
          print('💾 [APP]   Type: ${ad.type}');
          print('💾 [APP]   URL: "${ad.url}"');
          print('💾 [APP]   Local Path: "${ad.localPath}"');
          print('💾 [APP]   QR Link: "${ad.qrLink}"');
          print('💾 [APP]   Text: "${ad.text}"');
          print('💾 [APP]   Duration: ${ad.duration}s');
          if (ad.url.isEmpty) {
            print('💾 [APP]   ⚠️ WARNING: Empty URL received for ad ${ad.id}!');
          }
          print('💾 [APP] ===============================================');
        }
      } else {
        print('💾 [APP] ⚠️ WARNING: No ads received from authentication!');
      }
      
      print('💾 [APP] Saving ${_ads.length} ads to local storage');
      await LocalStorageService.saveAds(_ads);
      
      // Save authentication state for persistence
      if (result['driver_id'] != null && result['user_id'] != null) {
        await LocalStorageService.saveAuthenticationState(
          authToken: password,
          driverId: result['driver_id'],
          actualDriverId: result['user_id'].toString(),
          logoUrl: result['logo_url'],
        );
        print('💾 [APP] Saved authentication state for auto-login');
      }
      
      // Fetch driver profile immediately after authentication
      final actualDriverId = _apiService.actualDriverId;
      final driverId = result['driver_id']; // Use the long driver ID for profile API
      if (driverId != null) {
        print('👤 [AUTH] Fetching driver profile immediately after authentication');
        print('👤 [AUTH] Using driver_id: $driverId (vs actualDriverId: $actualDriverId)');
        _fetchDriverProfile(driverId);
      } else {
        print('❌ [AUTH] No driver ID available for profile fetch');
      }

      print('⏰ [APP] Starting background timers');
      _startAliveTimer();
      _startRideStatusTimer();
      // Only start content timer if not already running (prevent duplicate weather fetches)
      if (_contentUpdateTimer == null || !_contentUpdateTimer!.isActive) {
        _startContentUpdateTimer();
      } else {
        print('🔄 [CONTENT] Content update timer already running - skipping duplicate start');
      }
      
      // Always start at logo screen (waiting screen) after authentication
      print('🏠 [APP] Authentication complete - starting at logo screen to check ride status');
      _goToLogoScreen();
      
      notifyListeners();
      return true;
    } else {
      print('❌ [APP] Authentication failed: ${result['error']}');
      _lastError = result['error'];
      notifyListeners();
      return false;
    }
  }

  void _startAliveTimer() {
    print('💓 [TIMER] Starting alive timer (every 5 seconds)');
    _aliveTimer?.cancel();
    
    // Send first alive signal immediately
    print('💓 [TIMER] Sending first alive signal immediately...');
    _apiService.sendAliveSignal();
    
    // Then start the periodic timer
    _aliveTimer = Timer.periodic(const Duration(seconds: 5), (timer) async {
      print('💓 [TIMER] Alive timer triggered (${timer.tick}) - sending signal...');
      await _apiService.sendAliveSignal();
    });
  }

  void _startRideStatusTimer() {
    print('🚗 [TIMER] Starting ride status timer (every 10 seconds)');
    _rideStatusTimer?.cancel();
    
    // Check ride status immediately
    print('🚗 [TIMER] Checking ride status immediately...');
    _checkRideStatusNow();
    
    // Then start the periodic timer
    _rideStatusTimer = Timer.periodic(const Duration(seconds: 10), (timer) async {
      print('🚗 [TIMER] Ride status timer triggered (${timer.tick}) - checking status...');
      await _checkRideStatusNow();
    });
  }
  
  Future<void> _checkRideStatusNow() async {
    final wasOnRide = _isOnRide;
    final result = await _apiService.checkRideStatusAndOrderCompletion();
    final currentRideStatus = result['isOnRide'] ?? false;
    final orderCompleted = result['orderCompleted'] ?? false;
    
    print('🚗 [RIDE_CHECK] Previous: ${wasOnRide ? 'ON_RIDE' : 'OFF_RIDE'}, Current: ${currentRideStatus ? 'ON_RIDE' : 'OFF_RIDE'}');
    print('🏁 [ORDER_CHECK] Order completed: $orderCompleted');
    
    // Handle order completion based on current state
    if (orderCompleted) {
      print('🏁 [ORDER] ⭐ ORDER COMPLETED! ⭐ Ride has ended - handling data transmission...');
      
      if (_currentState == AppState.adDisplay) {
        print('🏁 [ORDER] Currently showing ad - will finish current ad then send data');
        _pendingOrderCompletion = true;
      } else {
        print('🏁 [ORDER] Not currently showing ad - sending data immediately');
        print('📊 [DATA] Collecting: Ad views, clicks, play time, ratings, detailed ratings');
        await _sendPerformanceData();
        print('📊 [DATA] ✅ Performance data sent and local storage cleared');
      }
    }
    
    // Implement status stability checking for ride status
    if (currentRideStatus == _lastRideStatus) {
      _consecutiveStatusChecks++;
    } else {
      _consecutiveStatusChecks = 1;
      _lastRideStatus = currentRideStatus;
    }
    
    // Only act on stable status (multiple consecutive checks)
    if (_consecutiveStatusChecks >= _statusStabilityThreshold) {
      _isOnRide = currentRideStatus;
      
      // Handle state transitions with guards and ad cycle respect
      if (!_isOnRide && _currentState != AppState.logoScreen) {
        // Check if we're in the middle of an active ad cycle
        if (_isInAdCycle) {
          print('🏠 [STATE] Not on ride, but ad cycle is active - will check again after cycle completes');
          print('🏠 [STATE] Current ad cycle progress: ${_totalAdTimeElapsed}s/${_targetAdCycleDuration}s');
          // Don't schedule pending change - let the ad cycle complete naturally
          // The cycle will check ride status again when it finishes
        } else {
          print('🏠 [STATE] Not on ride - requesting switch to logo screen');
          if (_canTransitionToLogoScreen()) {
            _goToLogoScreen();
          } else {
            print('🏠 [STATE] Cannot transition now - scheduling pending change');
            _pendingStateChange = AppState.logoScreen;
          }
        }
      } else if (_isOnRide && _currentState == AppState.logoScreen) {
        print('🚗 [STATE] Ride started - switching to welcome screen');
        if (_canTransitionToWelcomeScreen()) {
          _goToWelcomeScreen();
        } else {
          print('🚗 [STATE] Cannot transition now - scheduling pending change');
          _pendingStateChange = AppState.welcome;
        }
      }
    } else {
      print('🚗 [RIDE_CHECK] Status not stable yet - waiting for ${_statusStabilityThreshold - _consecutiveStatusChecks} more consistent checks');
    }
    
    notifyListeners();
  }

  void _goToWelcomeScreen() {
    print('👋 [STATE] Switching to welcome screen');
    _currentState = AppState.welcome;
    _startWelcomeTimer();
    notifyListeners();
  }

  void _startWelcomeTimer() {
    print('⏰ [WELCOME] Starting 60-second welcome timer');
    _welcomeTimer?.cancel();
    _welcomeTimer = Timer(const Duration(seconds: 60), () {
      print('⏰ [WELCOME] Timer expired - starting ad cycle');
      print('⏰ [WELCOME] Current ads count: ${_ads.length}');
      _startAdCycle();
    }); 
  }

  void skipWelcome() {
    print('👆 [WELCOME] User tapped - skipping welcome');
    print('👆 [WELCOME] Current ads count: ${_ads.length}');
    _welcomeTimer?.cancel();
    _startAdCycle();
  }

  // Logout and clear authentication state
  Future<void> logout() async {
    print('🔐 [APP] Logging out and clearing authentication state');
    
    // Clear all timers
    _clearAllTimers();
    _rideStatusTimer?.cancel();
    _contentUpdateTimer?.cancel();
    
    // Clear authentication state
    _isAuthenticated = false;
    _ads.clear();
    _logoUrl = null;
    _currentState = AppState.authentication;
    
    // Clear saved authentication data
    await LocalStorageService.clearAuthenticationState();
    
    notifyListeners();
  }


  // State transition guards
  bool _canTransitionToLogoScreen() {
    // Don't interrupt active ad display, QR display, or during active ad cycles
    return _currentState != AppState.adDisplay && 
           _currentState != AppState.qrDisplay &&
           !_isInAdCycle; // Respect active ad cycles
  }

  bool _canTransitionToWelcomeScreen() {
    // Can transition to welcome from logo screen or during non-critical states
    return _currentState == AppState.logoScreen || 
           _currentState == AppState.nonAdContent;
  }

  void _processPendingStateChange() {
    if (_pendingStateChange != null) {
      final pendingState = _pendingStateChange!;
      _pendingStateChange = null;
      
      print('📱 [STATE] Processing pending state change to: $pendingState');
      
      if (pendingState == AppState.logoScreen) {
        _goToLogoScreen();
      } else if (pendingState == AppState.welcome) {
        _goToWelcomeScreen();
      }
    }
  }

  // Simple method to calculate total duration of an ad including QR time and potential quiz
  int _calculateAdTotalDuration(AdModel ad) {
    // Simple approach: Ad duration + QR (if exists) + quiz estimate
    int adDuration = ad.type == 'video' ? ad.duration : 15; // Images = 15s
    int qrDuration = (ad.qrLink != null && ad.qrLink!.isNotEmpty) ? 5 : 0;
    int quizEstimate = 45; // Assume ~3 questions * 15 seconds each
    
    int total = adDuration + qrDuration + quizEstimate;
    print('📊 [TIMING] Ad ${ad.id}: ${adDuration}s + ${qrDuration}s QR + ${quizEstimate}s quiz = ${total}s');
    
    return total;
  }

  Future<void> _tryReloadAds() async {
    print('📺 [ADS] Attempting to reload ads from local storage...');
    try {
      final savedAds = await LocalStorageService.getAds();
      if (savedAds.isNotEmpty) {
        print('📺 [ADS] Successfully reloaded ${savedAds.length} ads from storage');
        _ads = savedAds;
        _startAdCycle(); // Try again now that we have ads
        return;
      } else {
        print('📺 [ADS] ⚠️ Still no ads in local storage');
      }
    } catch (e) {
      print('📺 [ADS] ❌ Error reloading ads: $e');
    }
    
    // If we still don't have ads, check if we can fetch from API
    if (_isAuthenticated && _apiService != null) {
      print('📺 [ADS] Attempting to fetch fresh ads from API...');
      try {
        final updateResult = await _apiService.checkForUpdates(_ads);
        if (updateResult['success'] == true && updateResult['hasChanges'] == true) {
          final newAds = updateResult['allUpdatedAds'] as List<AdModel>?;
          if (newAds != null && newAds.isNotEmpty) {
            print('📺 [ADS] Successfully fetched ${newAds.length} fresh ads from API');
            _ads = newAds;
            await LocalStorageService.saveAds(_ads);
            _startAdCycle(); // Try again with fresh ads
            return;
          }
        }
      } catch (e) {
        print('📺 [ADS] ❌ Error fetching fresh ads from API: $e');
      }
    }
    
    // If all attempts failed, go to logo screen
    print('📺 [ADS] ❌ All attempts to load ads failed - going to logo screen');
    _goToLogoScreen();
  }

  void _startAdCycle() {
    if (_ads.isEmpty) {
      print('📺 [ADS] No ads available - attempting to reload from storage');
      _tryReloadAds();
      return;
    }
    
    // Clear any pending state changes since we're starting a new ad cycle
    if (_pendingStateChange != null) {
      print('📺 [ADS] Clearing pending state change: $_pendingStateChange');
      _pendingStateChange = null;
    }
    
    // Reset 5-minute cycle tracking
    _adCycleStartTime = DateTime.now();
    _totalAdTimeElapsed = 0;
    _currentAdIndex = 0;
    _isInAdCycle = true;
    
    // Calculate total duration for one complete ad loop
    int totalLoopDuration = _ads.fold(0, (sum, ad) => sum + _calculateAdTotalDuration(ad));
    
    print('📺 [ADS] Starting 5-minute ad cycle with ${_ads.length} ads');
    print('📺 [ADS] One loop duration: ${totalLoopDuration}s, Target: ${_targetAdCycleDuration}s');
    
    _showCurrentAd();
  }

  void _showCurrentAd() {
    // Check if we've reached the 5-minute target before starting next ad
    if (_totalAdTimeElapsed >= _targetAdCycleDuration) {
      print('📺 [ADS] 5-minute cycle completed (${_totalAdTimeElapsed}s) - starting non-ad content');
      _startNonAdContent();
      return;
    }
    
    // Loop back to first ad if we've shown all ads
    if (_currentAdIndex >= _ads.length) {
      print('📺 [ADS] Completed one loop - continuing with ad cycle (${_totalAdTimeElapsed}s/${_targetAdCycleDuration}s)');
      _currentAdIndex = 0;
      
      // Force a state change to ensure video player resets properly when looping back
      print('📺 [ADS] Forcing state reset for video player reload');
      _currentState = AppState.logoScreen;
      notifyListeners();
      
      // Add a small delay then switch back to ad display
      Timer(const Duration(milliseconds: 200), () {
        _showCurrentAd();
      });
      return;
    }
    
    // Check if adding the next ad would significantly exceed 5 minutes
    final nextAd = _ads[_currentAdIndex];
    final nextAdDuration = _calculateAdTotalDuration(nextAd);
    final wouldExceedTarget = (_totalAdTimeElapsed + nextAdDuration) > (_targetAdCycleDuration + 30); // 30s tolerance
    
    if (wouldExceedTarget && _totalAdTimeElapsed >= (_targetAdCycleDuration - 60)) {
      print('📺 [ADS] Next ad would exceed 5-minute target significantly - starting non-ad content now');
      print('📺 [ADS] Current time: ${_totalAdTimeElapsed}s, Next ad: ${nextAdDuration}s, Would total: ${_totalAdTimeElapsed + nextAdDuration}s');
      _startNonAdContent();
      return;
    }
    
    final ad = _ads[_currentAdIndex];
    print('📺 [ADS] Preparing ad ${_currentAdIndex + 1}/${_ads.length} (ID: ${ad.id}, Type: ${ad.type})');
    print('📺 [ADS] Remote URL: "${ad.url}"');
    print('📺 [ADS] Local path: "${ad.localPath}"');
    print('📺 [ADS] Will use: "${ad.localPath ?? ad.url}" (${ad.localPath != null ? 'LOCAL' : 'REMOTE'})');
    
    // If it's a video, preload it before switching states (only if not already preloaded)
    if (ad.type == 'video') {
      // Check if we already have this video preloaded
      if (_preloadedVideoAdId == ad.id && _preloadedVideoController != null) {
        print('📹 [PRELOAD] Video already preloaded for ad: ${ad.id}');
        // Video is already preloaded, switch to ad display immediately
        _currentState = AppState.adDisplay;
        _currentAdStartTime = DateTime.now();
        notifyListeners();
        print('📺 [ADS] Ad session started at: ${_currentAdStartTime!.toIso8601String()}');
      } else {
        // Preload in background but don't block UI
        _preloadVideoAd(ad).then((_) {
          // After preloading, switch to ad display state
          _currentState = AppState.adDisplay;
          _currentAdStartTime = DateTime.now(); // Track when this ad started
          notifyListeners();
          print('📺 [ADS] Ad session started at: ${_currentAdStartTime!.toIso8601String()}');
        }).catchError((error) {
          // If preloading fails, still switch to ad display (fallback to regular loading)
          print('📹 [PRELOAD] ⚠️ Preloading failed, using fallback loading: $error');
          _currentState = AppState.adDisplay;
          _currentAdStartTime = DateTime.now();
          notifyListeners();
          print('📺 [ADS] Ad session started at: ${_currentAdStartTime!.toIso8601String()}');
        });
      }
      return; // Exit early to avoid duplicate state changes
    }
    
    // For non-video ads, switch immediately
    _currentState = AppState.adDisplay;
    _currentAdStartTime = DateTime.now(); // Track when this ad started
    notifyListeners();
    print('📺 [ADS] Ad session started at: ${_currentAdStartTime!.toIso8601String()}');
    
    // Record view immediately
    LocalStorageService.updateAdPerformance(ad.id, viewIncrement: 1);
    print('📊 [PERF] Recorded 1 view for ad: ${ad.id}');
    
    // For images, record played time immediately (always 15s)
    // For videos, wait for actual duration from video player
    if (ad.type != 'video') {
      LocalStorageService.updateAdPerformance(
        ad.id, 
        playedSecondsIncrement: 15.0
      );
      print('📊 [PERF] Recorded 15.0 seconds for image ad: ${ad.id}');
    } else {
      print('📊 [PERF] Will record actual video duration when available for ad: ${ad.id}');
    }
    
    // Set timer based on ad type
    Duration duration;
    if (ad.type == 'video') {
      // For videos, the video player will call onVideoCompleted() when done
      // But set a fallback timer slightly longer than expected duration
      duration = Duration(seconds: ad.duration + 5); // 5 second buffer
      print('⏰ [ADS] Video ad - will be controlled by video player with ${duration.inSeconds}s fallback timer');
    } else {
      // For images, always 15 seconds
      duration = const Duration(seconds: 15);
      print('⏰ [ADS] Image ad will display for ${duration.inSeconds} seconds');
    }
    
    _adTimer?.cancel();
    _adTimer = Timer(duration, () {
      print('⏰ [ADS] Ad ${_currentAdIndex + 1} finished by ${ad.type == 'video' ? 'fallback timer' : 'timer'}');
      _completeCurrentAd(ad, ad.type == 'video' ? ad.duration : 15);
    });
  }

  Future<void> _generateAndShowQrCode(String adId) async {
    print('📱 [QR] Generating QR code for ad: $adId');
    
    // Get the original ad data to extract the text
    final originalAd = _originalAdsBackup.isNotEmpty ? 
      _originalAdsBackup.firstWhere((a) => a.id == adId, orElse: () => 
        _ads.firstWhere((a) => a.id == adId, orElse: () => 
          AdModel(id: adId, type: 'unknown', url: '', duration: 0, createdAt: DateTime.now()))) :
      _ads.firstWhere((a) => a.id == adId, orElse: () => 
        AdModel(id: adId, type: 'unknown', url: '', duration: 0, createdAt: DateTime.now()));
    
    // Store the text from the original ad
    _qrText = originalAd.text;
    print('📱 [QR] Setting QR text from original ad: "${_qrText}"');
    
    // Generate QR code using the new endpoint
    final qrResult = await _apiService.generateQrCode(adId);
    
    if (qrResult['qr_code'] != null) {
      _qrCodeUrl = qrResult['qr_code'];
      _qrLogoUrl = qrResult['logo'];
      print('📱 [QR] Generated QR code URL: $_qrCodeUrl');
      print('📱 [QR] Generated logo URL: $_qrLogoUrl');
      
      print('📱 [QR] Displaying QR code for 5 seconds');
      _currentState = AppState.qrDisplay;
      notifyListeners();
      
      _qrTimer?.cancel();
      _qrTimer = Timer(const Duration(seconds: 5), () {
        print('📱 [QR] QR display finished - checking for order completion');
        
        // Update elapsed time with QR duration
        _totalAdTimeElapsed += 5;
        print('📊 [TIMING] QR completed. Total elapsed: ${_totalAdTimeElapsed}s/${_targetAdCycleDuration}s');
        
        _qrCodeUrl = null;
        _qrLogoUrl = null;
        _qrText = null;
        
        // Check for pending order completion first
        if (_pendingOrderCompletion) {
          print('🏁 [ORDER] QR finished - order completed during QR display');
          _pendingOrderCompletion = false;
          _isInAdCycle = false; // End the ad cycle
          
          print('📊 [DATA] Collecting: Ad views, clicks, play time, ratings, detailed ratings');
          _sendPerformanceData().then((_) {
            print('📊 [DATA] ✅ Performance data sent and local storage cleared');
            print('🏠 [ORDER] Going to logo screen after data transmission');
            _goToLogoScreen();
          });
          return;
        }
        
        // Process any pending state changes now that QR is complete
        _processPendingStateChange();
        
        // If no pending state change, QR is done so move to next ad
        if (_pendingStateChange == null) {
          print('📱 [QR] QR completed - moving to next ad');
          _moveToNextAdInSequence();
        }
      });
    } else {
      print('📱 [QR] Failed to generate QR code - moving to next ad');
      _moveToNextAdInSequence();
    }
  }


  void _startNonAdContent() {
    print('📰 [NON-AD] Starting non-ad content cycle');
    _isInAdCycle = false; // Mark ad cycle as complete
    
    // Check ride status now that ad cycle is complete
    // If user went off-ride during the ad cycle, we should go to logo screen instead
    if (!_isOnRide) {
      print('📰 [NON-AD] Ride status is OFF - going to logo screen instead of non-ad content');
      _goToLogoScreen();
      return;
    }
    
    _currentNonAdIndex = 0;
    _showCurrentNonAdContent();
  }

  void _showCurrentNonAdContent() {
    if (_currentNonAdIndex >= NonAdContentType.values.length) {
      print('📰 [NON-AD] All non-ad content shown - checking for updates before restarting');
      _checkForUpdatesAndRestartCycle();
      return;
    }
    
    final contentType = NonAdContentType.values[_currentNonAdIndex];
    print('📰 [NON-AD] Showing ${contentType.name} (${_currentNonAdIndex + 1}/${NonAdContentType.values.length})');
    
    _currentState = AppState.nonAdContent;
    notifyListeners();
    
    _nonAdTimer?.cancel();
    _nonAdTimer = Timer(const Duration(seconds: 15), () {
      print('⏰ [NON-AD] ${contentType.name} finished (15 seconds)');
      
      // If we just finished showing news, advance to next news article for next cycle
      if (contentType == NonAdContentType.news) {
        NewsService.moveToNextArticle();
      }
      
      _currentNonAdIndex++;
      _showCurrentNonAdContent();
    });
  }

  void _goToLogoScreen() {
    print('🏠 [STATE] Switching to logo screen - clearing all timers');
    _clearAllTimers();
    _isInAdCycle = false; // Mark ad cycle as complete
    _currentState = AppState.logoScreen;
    notifyListeners();
  }

  void onAdClicked() {
    final ad = currentAd;
    if (ad != null) {
      print('👆 [CLICK] User clicked on ad: ${ad.id}');
      LocalStorageService.updateAdPerformance(ad.id, clickIncrement: 1);
      print('📊 [PERF] Recorded click for ad: ${ad.id}');
    }
  }

  void onRatingSelected(int rating) {
    print('⭐ [RATING] User selected rating: $rating stars');
    LocalStorageService.saveRideRating(rating);
    print('💾 [RATING] Saved rating to local storage');
  }

  void setRating(String ratingType, int rating) {
    if (_detailedRatings.containsKey(ratingType)) {
      _detailedRatings[ratingType] = rating;
      print('⭐ [DETAILED_RATING] Set $ratingType rating to $rating stars');
      
      // Save detailed rating to local storage
      LocalStorageService.saveDetailedRating(ratingType, rating);
      print('💾 [DETAILED_RATING] Saved $ratingType rating to local storage');
      
      notifyListeners();
    }
  }

  void onVideoCompleted() {
    print('⏰ [ADS] Video completed naturally');
    _adTimer?.cancel(); // Cancel the fallback timer
    
    final ad = _ads.isNotEmpty && _currentAdIndex < _ads.length ? 
        _ads[_currentAdIndex] : null;
    
    if (ad != null && ad.type == 'video') {
      print('📊 [PERF] Video completed naturally for ad: ${ad.id}');
      _completeCurrentAd(ad, ad.duration);
    }
  }

  void onAdCompleted() {
    print('⏰ [ADS] Ad/Quiz completed naturally');
    _adTimer?.cancel(); // Cancel the fallback timer
    
    final ad = _ads.isNotEmpty && _currentAdIndex < _ads.length ? 
        _ads[_currentAdIndex] : null;
    
    if (ad != null) {
      print('📊 [PERF] Ad completed naturally for ad: ${ad.id} (${ad.type})');
      
      if (ad.type == 'quiz') {
        // Quiz completed - update timing and proceed with QR check
        _totalAdTimeElapsed += ad.duration;
        print('📊 [TIMING] Quiz completed. Duration: ${ad.duration}s, Total elapsed: ${_totalAdTimeElapsed}s/${_targetAdCycleDuration}s');
        
        // Check for pending order completion first
        if (_pendingOrderCompletion) {
          print('🏁 [ORDER] Current quiz finished - order completed during this quiz');
          _pendingOrderCompletion = false;
          _isInAdCycle = false; // End the ad cycle
          
          print('📊 [DATA] Collecting: Ad views, clicks, play time, ratings, detailed ratings');
          _sendPerformanceData().then((_) {
            print('📊 [DATA] ✅ Performance data sent and local storage cleared');
            print('🏠 [ORDER] Going to logo screen after data transmission');
            _goToLogoScreen();
          });
          return;
        }
        
        // Process any pending state changes
        _processPendingStateChange();
        
        // Continue with QR check after quiz
        if (_pendingStateChange == null) {
          final originalAdId = ad.id.replaceAll('_quiz', '');
          final originalAd = _originalAdsBackup.isNotEmpty ? 
            _originalAdsBackup.firstWhere((a) => a.id == originalAdId, orElse: () => ad) :
            _ads.firstWhere((a) => a.id == originalAdId, orElse: () => ad);
          
          print('📱 [QR] Quiz completed - checking for QR. Original ad: ${originalAd.id}, QR: ${originalAd.qrLink}');
          
          if (originalAd.qrLink != null && originalAd.qrLink!.isNotEmpty) {
            print('📱 [QR] Quiz completed - now showing QR for original ad: ${originalAdId}');
            _generateAndShowQrCode(originalAdId);
          } else {
            print('📱 [QR] No QR for original ad after quiz - moving to next ad');
            _moveToNextAdInSequence();
          }
        }
      } else {
        // Regular ad completion - proceed with quiz check
        _completeCurrentAd(ad, ad.duration);
      }
    }
  }

  // Centralized method to handle ad completion - prevents double counting
  void _completeCurrentAd(AdModel ad, int actualDisplayTime) {
    // Update elapsed time with actual display duration
    _totalAdTimeElapsed += actualDisplayTime;
    print('📊 [TIMING] Ad completed. Actual display time: ${actualDisplayTime}s, Total elapsed: ${_totalAdTimeElapsed}s/${_targetAdCycleDuration}s');
    
    // Check for pending order completion first
    if (_pendingOrderCompletion) {
      print('🏁 [ORDER] Current ad finished - order completed during this ad');
      _pendingOrderCompletion = false;
      _isInAdCycle = false; // End the ad cycle
      
      print('📊 [DATA] Collecting: Ad views, clicks, play time, ratings, detailed ratings');
      _sendPerformanceData().then((_) {
        print('📊 [DATA] ✅ Performance data sent and local storage cleared');
        print('🏠 [ORDER] Going to logo screen after data transmission');
        _goToLogoScreen();
      });
      return;
    }
    
    // Process any pending state changes now that ad is complete
    _processPendingStateChange();
    
    // If no pending state change, continue with normal flow: Ad → Quiz → QR → Next Ad
    if (_pendingStateChange == null) {
      print('🧠 [QUIZ] Checking for quiz after ad completion for ad: ${ad.id}');
      _fetchAndShowQuizIfAvailable(ad.id);
    }
  }

  // Store original ads to prevent data loss during quiz display
  List<AdModel> _originalAdsBackup = [];
  
  Future<void> _fetchAndShowQuizIfAvailable(String adId) async {
    try {
      print('🧠 [QUIZ] ===============================================');
      print('🧠 [QUIZ] 🔍 CHECKING FOR QUIZ: Ad ID = $adId');
      print('🧠 [QUIZ] ===============================================');
      
      // CRITICAL: Backup original ads before any modification
      _originalAdsBackup = List.from(_ads);
      
      print('🧠 [QUIZ] 📞 Making API call to fetch quiz data...');
      final quiz = await _apiService.fetchQuizForAd(adId);
      print('🧠 [QUIZ] 📞 API call completed');
      
      if (quiz != null && quiz.questions.isNotEmpty) {
        print('🧠 [QUIZ] ✅ QUIZ FOUND! ${quiz.questions.length} questions for ad $adId');
        
        // Check if all questions are already answered
        final savedAnswers = getQuizAnswersForAd(adId);
        final answeredQuestions = <String>{};
        
        for (int i = 0; i < quiz.questions.length; i++) {
          final question = quiz.questions[i];
          final isAnswered = savedAnswers.containsKey(question.question);
          if (isAnswered) {
            answeredQuestions.add(question.question);
          }
          print('🧠 [QUIZ]   Q${i + 1}: ${question.question} ${isAnswered ? "✅ ANSWERED" : "❓ UNANSWERED"}');
          print('🧠 [QUIZ]       Options: ${question.options.join(', ')}');
        }
        
        print('🧠 [QUIZ] Progress: ${answeredQuestions.length}/${quiz.questions.length} questions answered');
        
        // If all questions are answered, skip quiz entirely
        if (answeredQuestions.length >= quiz.questions.length) {
          print('🧠 [QUIZ] 🎯 ALL QUESTIONS ANSWERED - SKIPPING QUIZ ENTIRELY');
          print('🧠 [QUIZ] Proceeding directly to QR code generation');
          _generateAndShowQrCode(adId);
          return;
        }
        
        // Calculate total quiz duration from individual question durations
        final totalQuizDuration = quiz.questions.fold<int>(0, (sum, question) => sum + question.duration);
        print('🧠 [QUIZ] Total quiz duration: ${totalQuizDuration}s (${quiz.questions.length} questions)');
        
        // Create a temporary ad with quiz data to display
        final quizAd = AdModel(
          id: '${adId}_quiz',
          type: 'quiz',
          url: '',
          duration: totalQuizDuration, // Sum of individual question durations
          quiz: quiz,
          createdAt: DateTime.now(),
        );
        
        // Temporarily replace current ad with quiz ad
        _ads[_currentAdIndex] = quizAd;
        
        print('🧠 [QUIZ] Showing quiz for ad $adId with ${quiz.questions.length} questions');
        _currentState = AppState.adDisplay;
        notifyListeners();
        
        // Cancel any existing ad timer - let quiz screen handle timing
        _adTimer?.cancel();
        
        // Don't set a fallback timer - quiz screen will call onAdCompleted() when done
      } else {
        if (quiz == null) {
          print('🧠 [QUIZ] ❌ NO QUIZ: API returned null for ad $adId');
        } else if (quiz.questions.isEmpty) {
          print('🧠 [QUIZ] ❌ NO QUESTIONS: Quiz object exists but has 0 questions for ad $adId');
        } else {
          print('🧠 [QUIZ] ❌ UNKNOWN: Unexpected condition for ad $adId');
        }
        print('🧠 [QUIZ] 📱 Proceeding to QR check...');
        // Get original ad data for QR check
        final originalAd = _originalAdsBackup.firstWhere((a) => a.id == adId, 
          orElse: () => _ads.firstWhere((a) => a.id == adId, orElse: () => 
            AdModel(id: adId, type: 'unknown', url: '', duration: 0, createdAt: DateTime.now())));
        
        if (originalAd.qrLink != null && originalAd.qrLink!.isNotEmpty) {
          print('📱 [QR] No quiz but found QR for ad: $adId');
          _generateAndShowQrCode(adId);
        } else {
          print('📱 [QR] No quiz and no QR for ad $adId - moving to next ad');
          _moveToNextAdInSequence();
        }
      }
    } catch (e) {
      print('🧠 [QUIZ] ❌ EXCEPTION: Error fetching quiz for ad $adId: $e');
      print('🧠 [QUIZ] 📱 Exception caught - proceeding to QR check...');
      // Get original ad data for QR check
      final originalAd = _originalAdsBackup.isNotEmpty ? 
        _originalAdsBackup.firstWhere((a) => a.id == adId, orElse: () => 
          _ads.firstWhere((a) => a.id == adId, orElse: () => 
            AdModel(id: adId, type: 'unknown', url: '', duration: 0, createdAt: DateTime.now()))) :
        _ads.firstWhere((a) => a.id == adId, orElse: () => 
          AdModel(id: adId, type: 'unknown', url: '', duration: 0, createdAt: DateTime.now()));
      
      if (originalAd.qrLink != null && originalAd.qrLink!.isNotEmpty) {
        print('📱 [QR] Quiz failed but found QR for ad: $adId');
        _generateAndShowQrCode(adId);
      } else {
        print('📱 [QR] Quiz failed and no QR for ad $adId - moving to next ad');
        _moveToNextAdInSequence();
      }
    }
  }
  
  void _moveToNextAdInSequence() {
    // Restore original ads before moving to next
    if (_originalAdsBackup.isNotEmpty) {
      _ads = List.from(_originalAdsBackup);
      _originalAdsBackup.clear();
      print('🔄 [AD] Restored original ads array');
    }
    
    _currentAdIndex++;
    Timer(const Duration(milliseconds: 500), () {
      _showCurrentAd();
    });
  }


  void updateVideoActualDuration(int actualDurationSeconds) {
    final ad = currentAd;
    if (ad != null && ad.type == 'video') {
      print('📊 [PERF] Recording actual video duration: ${actualDurationSeconds}s for ad: ${ad.id}');
      
      // Record the actual played time for this video view
      LocalStorageService.updateAdPerformance(
        ad.id, 
        playedSecondsIncrement: actualDurationSeconds.toDouble()
      );
      print('📊 [PERF] Recorded ${actualDurationSeconds} seconds played time for video: ${ad.id}');
    }
  }

  Future<void> _sendPerformanceData() async {
    print('📊 [DATA_SEND] 🚀 Starting performance data collection and transmission...');
    
    final performances = await LocalStorageService.getAllAdPerformances();
    final ratings = await LocalStorageService.getAllRideRatings();
    final detailedRatings = LocalStorageService.getAllDetailedRatingsWithTimestamp();
    
    print('📊 [DATA_SEND] 📈 Collected ${performances.length} ad performances');
    for (var perf in performances) {
      print('📊 [DATA_SEND]   Ad ${perf.adId}: ${perf.viewCount} views, ${perf.clickCount} clicks, ${perf.playedSeconds.toStringAsFixed(1)}s played');
      
      // Calculate expected played time based on views
      final avgSecondsPerView = perf.viewCount > 0 ? perf.playedSeconds / perf.viewCount : 0;
      print('📊 [DATA_SEND]   → Average ${avgSecondsPerView.toStringAsFixed(1)}s per view for ad ${perf.adId}');
    }
    
    print('📊 [DATA_SEND] ⭐ Collected ${ratings.length} ride ratings');
    for (var rating in ratings) {
      print('📊 [DATA_SEND]   Rating: ${rating.rating} stars at ${rating.timestamp}');
    }
    
    print('📊 [DATA_SEND] 📝 Collected detailed ratings: $detailedRatings');
    
    // Collect quiz answers
    final allQuizAnswers = await LocalStorageService.getAllQuizAnswers();
    print('📊 [DATA_SEND] 🧠 Collected quiz answers for ${allQuizAnswers.length} ads');
    for (final entry in allQuizAnswers.entries) {
      print('📊 [DATA_SEND]   Ad ${entry.key}: ${entry.value.length} answers');
    }
    
    // Send regular performance data
    print('📊 [DATA_SEND] 📤 Sending ad performance and ride ratings to backend...');
    final performanceSuccess = await _apiService.sendPerformanceData(performances, ratings);
    print('📊 [DATA_SEND] Performance data send: ${performanceSuccess ? '✅ SUCCESS' : '❌ FAILED'}');
    
    // Send detailed ratings (only if there are ratings to send OR using test credentials)
    bool detailedRatingsSuccess = true;
    final hasDetailedRatings = detailedRatings.values.any((value) => value.split('|')[0] != '0');
    final isUsingTestCredentials = !_isAuthenticated; // Not authenticated means using test credentials
    
    if (hasDetailedRatings || isUsingTestCredentials) {
      print('📊 [DATA_SEND] 📤 Sending detailed ratings to backend...');
      detailedRatingsSuccess = await _apiService.sendDetailedRatings(detailedRatings);
      print('📊 [DATA_SEND] Detailed ratings send: ${detailedRatingsSuccess ? '✅ SUCCESS' : '❌ FAILED'}');
    } else {
      print('📊 [DATA_SEND] ℹ️ No detailed ratings to send');
    }
    
    // Send quiz answers
    bool quizAnswersSuccess = true;
    if (allQuizAnswers.isNotEmpty) {
      print('📊 [DATA_SEND] 📤 Sending quiz answers to backend...');
      quizAnswersSuccess = await _apiService.sendAllQuizResults(allQuizAnswers);
      print('📊 [DATA_SEND] Quiz answers send: ${quizAnswersSuccess ? '✅ SUCCESS' : '❌ FAILED'}');
    } else {
      print('📊 [DATA_SEND] ℹ️ No quiz answers to send');
    }
    
    // Clear local data only if operations succeeded
    if (performanceSuccess) {
      print('📊 [DATA_SEND] 🗑️ Clearing ad performances and ride ratings from local storage...');
      await LocalStorageService.clearAdPerformances();
      await LocalStorageService.clearRideRatings();
      print('📊 [DATA_SEND] ✅ Ad performances and ride ratings cleared');
    } else {
      print('📊 [DATA_SEND] ⚠️ Performance data send failed - keeping local data for retry');
    }
    
    if (detailedRatingsSuccess && hasDetailedRatings) {
      print('📊 [DATA_SEND] 🗑️ Clearing detailed ratings from local storage...');
      await LocalStorageService.clearDetailedRatings();
      // Reset local ratings state
      _detailedRatings = {
        'interest': 0,
        'attention': 0,
        'frequency': 0,
        'quality': 0,
      };
      notifyListeners();
      print('📊 [DATA_SEND] ✅ Detailed ratings cleared and reset');
    } else if (hasDetailedRatings) {
      print('📊 [DATA_SEND] ⚠️ Detailed ratings send failed - keeping local data for retry');
    }
    
    if (quizAnswersSuccess && allQuizAnswers.isNotEmpty) {
      print('📊 [DATA_SEND] 🗑️ Clearing quiz answers from local storage...');
      await LocalStorageService.clearAllQuizAnswers();
      print('📊 [DATA_SEND] ✅ Quiz answers cleared');
    } else if (allQuizAnswers.isNotEmpty) {
      print('📊 [DATA_SEND] ⚠️ Quiz answers send failed - keeping local data for retry');
    }
    
    print('📊 [DATA_SEND] 🏁 Performance data transmission completed!');
  }

  Future<void> checkAndUpdateAds() async {
    if (!_isAuthenticated) {
      print('🔄 [UPDATE] Skipped - not authenticated');
      return;
    }
    
    try {
      print('🔄 [UPDATE] Checking for ad updates...');
      final updateResult = await _apiService.checkForUpdates(_ads);
      
      if (updateResult['success'] && updateResult['hasChanges']) {
        print('🔄 [UPDATE] Processing ad updates...');
        
        final List<AdModel> adsToRemove = updateResult['toRemove'] ?? [];
        final List<AdModel> newAds = updateResult['allUpdatedAds'] ?? [];
        
        // Clean up removed ads from local storage
        if (adsToRemove.isNotEmpty) {
          print('🔄 [UPDATE] Removing ${adsToRemove.length} old ads...');
          await _apiService.cleanupRemovedAds(adsToRemove);
        }
        
        // Update the ads list and logo URL
        _ads = newAds;
        print('🔄 [UPDATE] Updated ads list:');
        for (final ad in _ads) {
          print('🔄 [UPDATE] Ad ${ad.id}: type=${ad.type}, localPath=${ad.localPath}');
        }
        
        if (updateResult['logoUrl'] != null) {
          _logoUrl = updateResult['logoUrl'];
          print('🔄 [UPDATE] Logo URL updated: $_logoUrl');
        }
        
        // Save updated ads to local storage
        print('💾 [UPDATE] Saving ${_ads.length} updated ads to local storage');
        await LocalStorageService.saveAds(_ads);
        
        // If currently showing ads, we might need to adjust the current index
        if (_currentState == AppState.adDisplay && _currentAdIndex >= _ads.length) {
          print('🔄 [UPDATE] Current ad index out of bounds, restarting cycle');
          _currentAdIndex = 0;
        }
        
        // If no ads left, go to logo screen
        if (_ads.isEmpty && _currentState == AppState.adDisplay) {
          print('🔄 [UPDATE] No ads remaining, going to logo screen');
          _goToLogoScreen();
        }
        
        notifyListeners();
        print('🔄 [UPDATE] Ad update complete! Now have ${_ads.length} ads');
      } else if (updateResult['success']) {
        print('🔄 [UPDATE] No updates available');
      } else {
        print('🔄 [UPDATE] Failed to check for updates: ${updateResult['error']}');
      }
    } catch (e) {
      print('🔄 [UPDATE] Error during update check: $e');
    }
  }

  Future<void> _checkForUpdatesAndRestartCycle() async {
    print('🔄 [CYCLE] Checking for updates at end of cycle...');
    
    // Check for updates
    await checkAndUpdateAds();
    
    // Force a fresh ride status check before making decision
    print('🔄 [CYCLE] Getting fresh ride status before restart decision...');
    final rideStatusResult = await _apiService.checkRideStatusAndOrderCompletion();
    final currentRideStatus = rideStatusResult['isOnRide'] ?? false;
    
    print('🔄 [CYCLE] Fresh ride status check result: $currentRideStatus (cached: $_isOnRide)');
    
    // Use the fresh status check result
    if (!currentRideStatus) {
      print('🔄 [CYCLE] Fresh check confirms ride status is OFF - going to logo screen');
      _isOnRide = false; // Update our cached status
      _goToLogoScreen();
      return;
    }
    
    // Update our cached status and restart cycle
    _isOnRide = true;
    print('🔄 [CYCLE] Fresh check confirms ride status is ON - restarting ad cycle');
    _startAdCycle();
  }

  void _startContentUpdateTimer() {
    print('🔄 [CONTENT] Starting content update timer (every 1 hour)');
    _contentUpdateTimer?.cancel();
    
    // Fetch initial content immediately
    _fetchContentData();
    
    // Then update every 1 hour to match weather cache duration
    _contentUpdateTimer = Timer.periodic(const Duration(hours: 1), (timer) async {
      print('🔄 [CONTENT] Content update timer triggered - fetching fresh data...');
      await _fetchContentData();
    });
  }

  Future<void> _fetchContentData() async {
    try {
      print('🔄 [CONTENT] Fetching weather, news, and driver profile data...');
      
      // Fetch content data in parallel
      final futures = [
        WeatherService.fetchBakuWeather(),
        NewsService.fetchNews(),
      ];
      
      // Add driver profile fetch if driver ID is available
      final driverId = _apiService.driverId; // Use the long driver ID for profile API
      if (driverId != null) {
        futures.add(_fetchDriverProfile(driverId));
      } else {
        print('🔄 [CONTENT] Skipping driver profile fetch - no driver ID available');
      }
      
      await Future.wait(futures);
      
      print('🔄 [CONTENT] Content data updated successfully');
      notifyListeners();
    } catch (e) {
      print('❌ [CONTENT] Error fetching content data: $e');
    }
  }
  
  Future<void> _fetchDriverProfile(String driverId) async {
    try {
      print('👤 [CONTENT] Attempting to fetch driver profile for ID: $driverId');
      final profile = await _apiService.fetchDriverProfile(driverId);
      if (profile != null) {
        _driverProfile = profile;
        print('👤 [CONTENT] ✅ Driver profile updated: ${profile.fullName}');
        print('👤 [CONTENT] Car: ${profile.fullCarModel}');
        print('👤 [CONTENT] Phone: ${profile.driverPhone}');
        notifyListeners(); // Make sure UI updates
      } else {
        print('❌ [CONTENT] Driver profile returned null');
      }
    } catch (e) {
      print('❌ [CONTENT] Error fetching driver profile: $e');
    }
  }

  Future<void> _preloadVideoAd(AdModel ad) async {
    if (_isPreloadingVideo) {
      print('📹 [PRELOAD] Already preloading, waiting for completion');
      return;
    }
    
    // Validate this is actually a video ad before proceeding
    if (ad.type != 'video') {
      print('📹 [PRELOAD] ❌ Attempted to preload non-video ad: ${ad.id} (type: ${ad.type})');
      return;
    }
    
    _isPreloadingVideo = true;
    print('📹 [PRELOAD] Starting video preload for: ${ad.id} (type: ${ad.type})');
    
    try {
      // Properly dispose any existing preloaded controller with delay to prevent buffer issues
      if (_preloadedVideoController != null) {
        print('📹 [PRELOAD] Disposing existing controller to free buffers');
        try {
          // Pause first to prevent buffer conflicts
          if (_preloadedVideoController!.value.isInitialized) {
            await _preloadedVideoController!.pause();
          }
          await _preloadedVideoController!.dispose();
        } catch (e) {
          print('📹 [PRELOAD] Error disposing existing controller: $e');
        }
        _preloadedVideoController = null;
        
        // Add small delay to allow buffers to be fully released
        await Future.delayed(const Duration(milliseconds: 100));
      }
      
      // Use local file if available, otherwise use remote URL
      final videoSource = ad.localPath ?? ad.url;
      final isLocal = ad.localPath != null;
      
      // Validate video source
      if (videoSource.isEmpty) {
        throw Exception('No valid video source available - both localPath and url are empty for ad ${ad.id}');
      }
      
      print('📹 [PRELOAD] Video source validation passed for ad ${ad.id}');
      
      print('📹 [PRELOAD] Loading video: $videoSource (${isLocal ? 'LOCAL' : 'REMOTE'})');
      
      // Create new controller with buffer configuration
      if (isLocal) {
        _preloadedVideoController = VideoPlayerController.file(File(videoSource));
      } else {
        _preloadedVideoController = VideoPlayerController.networkUrl(Uri.parse(videoSource));
      }
      
      // Initialize the video with timeout to prevent hanging
      if (_preloadedVideoController != null) {
        await _preloadedVideoController!.initialize().timeout(
          const Duration(seconds: 10),
          onTimeout: () {
            throw Exception('Video initialization timeout');
          },
        );
        
        if (_preloadedVideoController?.value.isInitialized == true) {
          final duration = _preloadedVideoController!.value.duration;
          final actualDuration = duration.inSeconds;
          print('📹 [PRELOAD] ✅ Video preloaded successfully - Duration: ${actualDuration}s');
          
          // Configure for optimal playback - don't start playing yet to save resources
          _preloadedVideoController!.setLooping(false);
          
          // Track which ad is preloaded to avoid duplicate preloading
          _preloadedVideoAdId = ad.id;
        } else {
          throw Exception('Video failed to initialize properly');
        }
      } else {
        throw Exception('Video controller is null after creation');
      }
      
    } catch (e) {
      print('📹 [PRELOAD] ❌ Error preloading video: $e');
      if (_preloadedVideoController != null) {
        try {
          await _preloadedVideoController!.dispose();
        } catch (disposeError) {
          print('📹 [PRELOAD] Error disposing failed controller: $disposeError');
        }
        _preloadedVideoController = null;
      }
      _preloadedVideoAdId = null; // Clear failed preload ID
    } finally {
      _isPreloadingVideo = false;
    }
  }

  void _clearAllTimers() {
    // DON'T cancel alive timer - it should run continuously while app is open
    // _aliveTimer?.cancel();
    _welcomeTimer?.cancel();
    _adTimer?.cancel();
    _nonAdTimer?.cancel();
    _qrTimer?.cancel();
    // Note: Don't cancel _contentUpdateTimer - it should run continuously
  }

  // Quiz answer management
  void saveQuizAnswers(List<QuizAnswer> answers) {
    print('🧠 [QUIZ] Saving ${answers.length} quiz answers');
    _quizAnswers.addAll(answers);
    for (final answer in answers) {
      print('🧠 [QUIZ] Answer: Quiz ${answer.quizId}, Question ${answer.questionId}, Option ${answer.selectedOption}');
    }
  }

  List<QuizAnswer> getQuizAnswers() {
    return List.from(_quizAnswers);
  }

  // New methods for persistent quiz answer storage per ad
  Future<void> saveQuizAnswersForAd(String adId, Map<String, String> questionAnswers) async {
    await LocalStorageService.saveQuizAnswersForAd(adId, questionAnswers);
    print('🧠 [QUIZ] Saved ${questionAnswers.length} answers for ad: $adId');
  }

  Map<String, String> getQuizAnswersForAd(String adId) {
    return LocalStorageService.getQuizAnswersForAd(adId);
  }

  void clearQuizAnswers() {
    print('🧠 [QUIZ] Clearing ${_quizAnswers.length} quiz answers');
    _quizAnswers.clear();
  }

  @override
  void dispose() {
    _clearAllTimers();
    _rideStatusTimer?.cancel();
    _contentUpdateTimer?.cancel();
    super.dispose();
  }
}