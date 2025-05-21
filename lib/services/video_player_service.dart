import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

class VideoPlayerService extends ChangeNotifier {
  Map<String, VideoPlayerController> _controllers = {};
  String? _currentlyPlayingId;

  // Get controller for a video
  Future<VideoPlayerController> getControllerForVideo(String postId, String videoUrl) async {
    // Return existing controller if available
    if (_controllers.containsKey(postId)) {
      return _controllers[postId]!;
    }
    
    print('Creating new controller for video: $videoUrl');
    
    // Create a new controller
    final controller = VideoPlayerController.networkUrl(Uri.parse(videoUrl));
    
    try {
      // Initialize the controller
      await controller.initialize();
      controller.setLooping(true);
      
      // Store the controller
      _controllers[postId] = controller;
      
      print('Video controller initialized for $postId');
      return controller;
    } catch (e) {
      print('Error initializing video controller: $e');
      throw e;
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