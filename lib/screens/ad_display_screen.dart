import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:video_player/video_player.dart';
import 'dart:io';
import '../services/app_state_service.dart';
import '../models/ad_model.dart';
import 'quiz_display_screen.dart';

class AdDisplayScreen extends StatefulWidget {
  const AdDisplayScreen({super.key});

  @override
  State<AdDisplayScreen> createState() => _AdDisplayScreenState();
}

class _AdDisplayScreenState extends State<AdDisplayScreen> {
  VideoPlayerController? _videoController;
  bool _isVideoInitialized = false;

  @override
  void initState() {
    super.initState();
    _initializeAd();
  }

  void _initializeAd() {
    final appState = context.read<AppStateService>();
    final ad = appState.currentAd;
    
    if (ad != null) {
      print('📺 [AD_DISPLAY] Current ad - ID: ${ad.id}, Type: ${ad.type}, URL: ${ad.url}');
      print('📺 [AD_DISPLAY] Local path: ${ad.localPath}');
      
      if (ad.type == 'video') {
        // Check if video is already preloaded
        final preloadedController = appState.preloadedVideoController;
        if (preloadedController != null) {
          print('📹 [VIDEO] Using preloaded video controller');
          _usePreloadedVideo(preloadedController);
        } else {
          // Fallback to regular initialization
          final videoSource = ad.localPath ?? ad.url;
          final isLocal = ad.localPath != null;
          print('📹 [VIDEO] Video source: $videoSource (${isLocal ? 'LOCAL' : 'REMOTE'})');
          _initializeVideo(videoSource, isLocal);
        }
      } else {
        print('📺 [AD_DISPLAY] Not a video, will display as image');
      }
    }
  }

  void _usePreloadedVideo(VideoPlayerController preloadedController) {
    print('📹 [VIDEO] Taking control of preloaded video');
    
    // Properly dispose current controller if any to prevent buffer conflicts
    if (_videoController != null) {
      try {
        _videoController!.removeListener(_videoListener);
        _videoController!.dispose();
        print('📹 [VIDEO] Previous controller disposed before using preloaded');
      } catch (e) {
        print('📹 [VIDEO] Error disposing previous controller: $e');
      }
    }
    
    // Take ownership of the preloaded controller
    _videoController = preloadedController;
    
    // Clear the preloaded reference from app state
    final appState = context.read<AppStateService>();
    appState.clearPreloadedVideo();
    
    // Update state to show the video is ready
    setState(() {
      _isVideoInitialized = true;
    });
    
    // Start playback immediately since video is already loaded
    _videoController!.play();
    
    // Listen for video completion
    _videoController!.addListener(_videoListener);
    print('📹 [VIDEO] Preloaded video playback started with completion listener');
  }

  Future<void> _initializeVideo(String videoSource, bool isLocal) async {
    // Dispose previous controller to prevent buffer buildup
    await _disposeVideoController();
    
    try {
      print('📹 [VIDEO] Initializing video: $videoSource (${isLocal ? 'LOCAL' : 'REMOTE'})');
      
      if (isLocal) {
        _videoController = VideoPlayerController.file(File(videoSource));
      } else {
        _videoController = VideoPlayerController.networkUrl(Uri.parse(videoSource));
      }
      
      // Configure video player for optimal memory usage
      await _videoController!.initialize();
      
      if (mounted) {
        final actualDuration = _videoController!.value.duration.inSeconds;
        print('📹 [VIDEO] Video initialized successfully - Actual duration: ${actualDuration}s');
        
        // Update the app state with actual video duration if different
        final appState = context.read<AppStateService>();
        final currentAd = appState.currentAd;
        if (currentAd != null && currentAd.duration != actualDuration && actualDuration > 0) {
          print('📹 [VIDEO] Updating ad duration from ${currentAd.duration}s to ${actualDuration}s');
          // Note: This would need a method in app state to update the current ad duration
        }
        
        setState(() {
          _isVideoInitialized = true;
        });
        
        // Configure video playback settings for memory efficiency
        _videoController!.setLooping(false);
        
        // Start playback
        await _videoController!.play();
        
        // Listen for video completion
        _videoController!.addListener(_videoListener);
        print('📹 [VIDEO] Video playback started with completion listener');
      }
    } catch (e) {
      print('📹 [VIDEO] Error initializing video: $e');
      print('📹 [VIDEO] Failed URL: $videoSource');
      // Set a flag to show error state
      if (mounted) {
        setState(() {
          _isVideoInitialized = false;
        });
      }
    }
  }

  void _videoListener() {
    if (_videoController != null && _videoController!.value.isInitialized) {
      final position = _videoController!.value.position;
      final duration = _videoController!.value.duration;
      
      // Check if video has reached the end
      if (position >= duration && duration.inMilliseconds > 0) {
        print('📹 [VIDEO] Video completed - position: ${position.inSeconds}s, duration: ${duration.inSeconds}s');
        
        // Remove listener to prevent multiple calls
        _videoController!.removeListener(_videoListener);
        
        // Notify app state that video completed
        if (mounted) {
          final appState = context.read<AppStateService>();
          // Update with actual duration
          appState.updateVideoActualDuration(duration.inSeconds);
          appState.onVideoCompleted();
        }
      }
    }
  }

  Future<void> _disposeVideoController() async {
    if (_videoController != null) {
      try {
        print('📹 [VIDEO] Disposing previous video controller to free buffers');
        _videoController!.removeListener(_videoListener);
        
        // Only pause if the controller is still valid and not already disposed
        if (_videoController!.value.isInitialized) {
          await _videoController!.pause();
        }
        
        await _videoController!.dispose();
        print('📹 [VIDEO] Video controller disposed successfully');
        
        // Add small delay to allow buffers to be fully released
        await Future.delayed(const Duration(milliseconds: 50));
        
      } catch (e) {
        print('📹 [VIDEO] Error disposing video controller: $e');
      } finally {
        _videoController = null;
        _isVideoInitialized = false;
      }
    }
  }

  @override
  void dispose() {
    _disposeVideoController();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AppStateService>(
      builder: (context, appState, child) {
        final ad = appState.currentAd;
        
        if (ad == null) {
          return const Scaffold(
            backgroundColor: Color(0xFF0A1428), // Dark blue background
            body: Center(
              child: CircularProgressIndicator(color: Color(0xFF3B82F6)),
            ),
          );
        }

        // Route quiz ads to the quiz display screen
        if (ad.type == 'quiz') {
          return const QuizDisplayScreen();
        }

        return Scaffold(
          backgroundColor: const Color(0xFF0A1428), // Dark blue background
          body: Stack(
            children: [
              TweenAnimationBuilder<double>(
                duration: const Duration(milliseconds: 600),
                tween: Tween(begin: 0.0, end: 1.0),
                builder: (context, value, child) {
                  return Opacity(
                    opacity: value,
                    child: Transform.scale(
                      scale: 0.9 + (0.1 * value),
                      child: GestureDetector(
                        onTap: () {
                          appState.onAdClicked();
                        },
                        child: SizedBox.expand(
                          child: ad.type == 'video'
                              ? _buildVideoPlayer(ad)
                              : _buildImageDisplay(ad),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildVideoPlayer(AdModel ad) {
    if (!_isVideoInitialized || _videoController == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(color: Colors.white),
            const SizedBox(height: 16),
            Text(
              'Loading video...\n${ad.url}',
              style: const TextStyle(fontFamily: 'Poppins', color: Colors.white70),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    // Check if video failed to load
    if (_videoController!.value.hasError) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error, color: Colors.red, size: 64),
            const SizedBox(height: 16),
            Text(
              'Failed to load video\n${ad.url}',
              style: const TextStyle(fontFamily: 'Poppins', color: Colors.white),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return Center(
      child: AspectRatio(
        aspectRatio: _videoController!.value.aspectRatio,
        child: VideoPlayer(_videoController!),
      ),
    );
  }

  Widget _buildImageDisplay(AdModel ad) {
    print('🖼️ [IMAGE] Building image display for ad: ${ad.id}');
    print('🖼️ [IMAGE] Local path: "${ad.localPath}"');
    print('🖼️ [IMAGE] Remote URL: "${ad.url}"');
    
    // Check if we have a valid source
    final hasLocalPath = ad.localPath != null && ad.localPath!.isNotEmpty;
    final hasRemoteUrl = ad.url.isNotEmpty;
    
    if (!hasLocalPath && !hasRemoteUrl) {
      print('🖼️ [IMAGE] ❌ ERROR: No valid image source for ad ${ad.id}');
      return Container(
        width: double.infinity,
        height: double.infinity,
        color: const Color(0xFF0A1428),
        child: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error, color: Colors.red, size: 64),
              SizedBox(height: 16),
              Text(
                'Image not available',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  color: Colors.white,
                  fontSize: 18,
                ),
              ),
            ],
          ),
        ),
      );
    }
    
    // Use local file if available, otherwise use remote URL
    final imageProvider = hasLocalPath
        ? FileImage(File(ad.localPath!)) as ImageProvider
        : NetworkImage(ad.url);
        
    print('🖼️ [IMAGE] Displaying: ${hasLocalPath ? 'LOCAL' : 'REMOTE'} - ${hasLocalPath ? ad.localPath : ad.url}');
    
    return Container(
      width: double.infinity,
      height: double.infinity,
      decoration: BoxDecoration(
        image: DecorationImage(
          image: imageProvider,
          fit: BoxFit.cover,
          onError: (error, stackTrace) {
            print('🖼️ [IMAGE] Error loading image: $error');
          },
        ),
      ),
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.transparent,
              Colors.black.withOpacity(0.3),
            ],
          ),
        ),
      ),
    );
  }

}