import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:video_thumbnail/video_thumbnail.dart';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:firebase_storage/firebase_storage.dart';

class VideoPlayerService extends ChangeNotifier {
  Map<String, VideoPlayerController> _controllers = {};
  String? _currentlyPlayingId;
  Map<String, String> _thumbnailCache = {}; // Cache for generated thumbnails

  // Get controller for a video
  Future<VideoPlayerController> getControllerForVideo(String postId, String videoUrl) async {
    // Return existing controller if available
    if (_controllers.containsKey(postId)) {
      return _controllers[postId]!;
    }
    
    print('Creating new controller for video: $videoUrl');
    
    try {
      // For web platform, we need to ensure we have a token in the URL
      if (kIsWeb && videoUrl.contains('firebasestorage.googleapis.com')) {
        // Try to get a fresh URL with token if this is a Firebase Storage URL
        try {
          // Extract path from URL
          final uri = Uri.parse(videoUrl);
          final path = uri.path.split('/o/').last;
          final decodedPath = Uri.decodeComponent(path).split('?').first;
          
          // Get reference and fresh URL
          final ref = FirebaseStorage.instance.ref(decodedPath);
          videoUrl = await ref.getDownloadURL();
          print('Refreshed URL with token: $videoUrl');
        } catch (e) {
          print('Could not refresh Firebase Storage URL: $e');
        }
      }
      
      // Ensure URL is https when in production
      if (videoUrl.startsWith('http://') && 
          !videoUrl.contains('localhost') && 
          !videoUrl.contains('127.0.0.1')) {
        videoUrl = videoUrl.replaceFirst('http://', 'https://');
      }
      
      // Create controller with different approach for web vs mobile
      late VideoPlayerController controller;
      
      if (kIsWeb) {
        // On web, use simpler initialization
        controller = VideoPlayerController.networkUrl(
          Uri.parse(videoUrl),
        );
      } else {
        // On mobile, use headers
        controller = VideoPlayerController.networkUrl(
          Uri.parse(videoUrl),
          httpHeaders: {
            'Access-Control-Allow-Origin': '*',
          },
        );
      }
      
      // Initialize the controller
      await controller.initialize();
      controller.setLooping(true);
      
      // Store the controller
      _controllers[postId] = controller;
      
      print('Video controller initialized for $postId');
      return controller;
    } catch (e) {
      print('Error initializing video controller for $postId: $e');
      
      // Create a dummy controller for safety
      if (kIsWeb) {
        // Return an empty video as a fallback for web
        final fallbackController = VideoPlayerController.asset('assets/fallback_video.mp4');
        
        try {
          await fallbackController.initialize();
          _controllers[postId] = fallbackController;
          return fallbackController;
        } catch (fallbackError) {
          print('Error creating fallback controller: $fallbackError');
          throw e; // Re-throw the original error
        }
      } else {
        throw e;
      }
    }
  }
  
  // Play a specific video
  void playVideo(String postId) {
    print('Attempting to play video: $postId');
    
    // Pause currently playing video if any
    if (_currentlyPlayingId != null && 
        _currentlyPlayingId != postId && 
        _controllers.containsKey(_currentlyPlayingId)) {
      print('Pausing previously playing video: $_currentlyPlayingId');
      _controllers[_currentlyPlayingId]!.pause();
    }
    
    // Play the new video if controller exists
    if (_controllers.containsKey(postId)) {
      print('Playing video: $postId');
      _controllers[postId]!.play();
      _currentlyPlayingId = postId;
      notifyListeners();
    } else {
      print('Controller not found for video: $postId');
    }
  }
  
  // Generate a thumbnail from a video URL
  Future<String?> generateThumbnail(String videoUrl, String postId) async {
    // Return cached thumbnail if exists
    if (_thumbnailCache.containsKey(postId)) {
      print('Using cached thumbnail for $postId');
      return _thumbnailCache[postId];
    }
    
    try {
      print('Generating thumbnail for video: $videoUrl');
      
      // Create a temporary directory to store the thumbnail
      final tempDir = await getTemporaryDirectory();
      final thumbnailPath = '${tempDir.path}/${postId}_thumbnail.jpg';
      
      // Generate thumbnail from the video URL
      // Seek to 3 seconds to avoid black frames at the beginning
      final thumbnail = await VideoThumbnail.thumbnailFile(
        video: videoUrl,
        thumbnailPath: thumbnailPath,
        imageFormat: ImageFormat.JPEG,
        maxHeight: 640,
        quality: 75,
        timeMs: 3000, // Seek 3 seconds into the video
      );
      
      if (thumbnail == null) {
        print('Failed to generate thumbnail for $postId');
        return null;
      }
      
      print('Thumbnail generated at: $thumbnail for $postId');
      
      // Cache the thumbnail path
      _thumbnailCache[postId] = thumbnail;
      return thumbnail;
    } catch (e) {
      print('Error generating thumbnail for $postId: $e');
      return null;
    }
  }
  
  // Generate thumbnail from a controller for preview purposes
  Future<ui.Image?> generateThumbnailFromController(VideoPlayerController controller) async {
    try {
      // Seek to 3 seconds or the middle of the video
      final duration = controller.value.duration;
      final position = duration.inSeconds > 5 
          ? const Duration(seconds: 3) 
          : Duration(milliseconds: duration.inMilliseconds ~/ 2);
      
      await controller.seekTo(position);
      await Future.delayed(const Duration(milliseconds: 100));
      
      // Get the video frame as a texture
      return null; // Actual implementation depends on lower level access to VideoPlayer
    } catch (e) {
      print('Error generating thumbnail from controller: $e');
      return null;
    }
  }
  
  // Create thumbnail from a remote video URL
  Future<Uint8List?> downloadThumbnailFromServer(String videoUrl) async {
    try {
      // Attempt to download a small chunk from the video to check if it's accessible
      final response = await http.get(
        Uri.parse(videoUrl),
        headers: {'Range': 'bytes=0-65536'}, // Just download a small chunk
      );
      
      if (response.statusCode == 200 || response.statusCode == 206) {
        // Video is accessible, use video_thumbnail package to generate
        final tempDir = await getTemporaryDirectory();
        final thumbnailPath = await VideoThumbnail.thumbnailFile(
          video: videoUrl,
          thumbnailPath: '${tempDir.path}/temp_thumbnail.jpg',
          imageFormat: ImageFormat.JPEG,
          maxHeight: 640,
          quality: 75,
          timeMs: 3000,
        );
        
        if (thumbnailPath == null) return null;
        
        final file = File(thumbnailPath);
        return await file.readAsBytes();
      } else {
        print('Video not accessible: $videoUrl, status: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      print('Error downloading thumbnail: $e');
      return null;
    }
  }
  
  // Pause a specific video
  void pauseVideo(String postId) {
    print('Attempting to pause video: $postId');
    if (_controllers.containsKey(postId)) {
      _controllers[postId]!.pause();
      if (_currentlyPlayingId == postId) {
        _currentlyPlayingId = null;
      }
      notifyListeners();
    }
  }
  
  // Pause all videos
  void pauseAllVideos() {
    print('Pausing all videos');
    _controllers.forEach((id, controller) {
      controller.pause();
    });
    _currentlyPlayingId = null;
    notifyListeners();
  }
  
  // Check if a video is playing
  bool isPlaying(String postId) {
    if (!_controllers.containsKey(postId)) return false;
    return _controllers[postId]!.value.isPlaying;
  }
  
  // Clean up resources for a specific video
  void disposeController(String postId) {
    if (_controllers.containsKey(postId)) {
      print('Disposing controller for: $postId');
      _controllers[postId]!.dispose();
      _controllers.remove(postId);
      if (_currentlyPlayingId == postId) {
        _currentlyPlayingId = null;
      }
    }
  }
  
  // Clear thumbnail cache for a specific post
  void clearThumbnailCache(String postId) {
    if (_thumbnailCache.containsKey(postId)) {
      _thumbnailCache.remove(postId);
    }
  }
  
  // Clean up all resources
  @override
  void dispose() {
    print('Disposing all video controllers');
    _controllers.forEach((_, controller) {
      controller.dispose();
    });
    _controllers.clear();
    _currentlyPlayingId = null;
    super.dispose();
  }
}