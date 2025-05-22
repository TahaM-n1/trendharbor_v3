import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:video_player/video_player.dart';
import 'package:visibility_detector/visibility_detector.dart';
import '../services/video_player_service.dart';
import 'package:http/http.dart' as http;

class VideoPostWidget extends StatefulWidget {
  final String postId;
  final String videoUrl;
  final String thumbnailUrl;
  final bool autoplay;

  const VideoPostWidget({
    Key? key,
    required this.postId,
    required this.videoUrl,
    required this.thumbnailUrl,
    this.autoplay = true,
  }) : super(key: key);

  @override
  State<VideoPostWidget> createState() => _VideoPostWidgetState();
}

class _VideoPostWidgetState extends State<VideoPostWidget> {
  VideoPlayerController? _controller;
  bool _isPlaying = false;
  bool _isVisible = false;
  bool _controlsVisible = false;
  bool _isInitialized = false;
  bool _isError = false;

  @override
  void initState() {
    super.initState();
    print('VideoPostWidget initialized for ${widget.postId}');
    _initializeController();
  }

  @override
  void dispose() {
    print('VideoPostWidget disposed for ${widget.postId}');
    super.dispose();
  }

  Future<void> _initializeController() async {
    print('Initializing controller for video: ${widget.videoUrl}');
    try {
      // First, verify the video URL is accessible
      final response = await http.head(Uri.parse(widget.videoUrl));
      if (response.statusCode != 200) {
        throw Exception('Video URL returned status code ${response.statusCode}');
      }

      _controller = VideoPlayerController.networkUrl(
        Uri.parse(widget.videoUrl),
        httpHeaders: {
          'Access-Control-Allow-Origin': '*',
        },
      );
      
      await _controller!.initialize();
      _controller!.setLooping(true);
      
      if (mounted) {
        setState(() {
          _isInitialized = true;
        });
        
        _controller!.addListener(_onControllerUpdate);
        
        if (_isVisible && widget.autoplay && mounted) {
          _playVideo();
        }
      }
      
      print('Video controller initialized successfully for ${widget.postId}');
    } catch (e) {
      print('Error initializing video controller for ${widget.postId}: $e');
      if (mounted) {
        setState(() {
          _isError = true;
        });
      }
    }
  }
  
  void _onControllerUpdate() {
    if (_controller == null || !mounted) return;
    
    final isPlaying = _controller!.value.isPlaying;
    if (_isPlaying != isPlaying) {
      setState(() {
        _isPlaying = isPlaying;
      });
    }
  }

  void _playVideo() {
    if (_controller == null || !_isInitialized || !mounted) return;
    
    print('Playing video for ${widget.postId}');
    _controller!.play();
    setState(() {
      _isPlaying = true;
    });
  }

  void _pauseVideo() {
    if (_controller == null || !_isInitialized || !mounted) return;
    
    print('Pausing video for ${widget.postId}');
    _controller!.pause();
    setState(() {
      _isPlaying = false;
    });
  }

  void _togglePlayPause() {
    if (_isPlaying) {
      _pauseVideo();
    } else {
      _playVideo();
    }
  }

  void _onVisibilityChanged(VisibilityInfo info) {
    final visibleFraction = info.visibleFraction;
    final isVisible = visibleFraction > 0.7;
    
    print('Video ${widget.postId} visibility changed: $visibleFraction');
    
    if (_isVisible != isVisible) {
      setState(() {
        _isVisible = isVisible;
      });
      
      if (_isInitialized && widget.autoplay) {
        if (isVisible) {
          _playVideo();
        } else {
          _pauseVideo();
        }
      }
    }
  }

  void _toggleControls() {
    setState(() {
      _controlsVisible = !_controlsVisible;
    });
    
    if (_controlsVisible) {
      Future.delayed(const Duration(seconds: 3), () {
        if (mounted) {
          setState(() {
            _controlsVisible = false;
          });
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return VisibilityDetector(
      key: Key('video-${widget.postId}'),
      onVisibilityChanged: _onVisibilityChanged,
      child: GestureDetector(
        onTap: _toggleControls,
        child: _isError 
            ? _buildErrorWidget()
            : _isInitialized
                ? _buildVideoPlayer()
                : _buildLoadingWidget(),
      ),
    );
  }

  Widget _buildVideoPlayer() {
    if (_controller == null) return _buildLoadingWidget();
    
    return AspectRatio(
      aspectRatio: _controller!.value.aspectRatio,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Video player
          VideoPlayer(_controller!),
          
          // Play/pause overlay
          AnimatedOpacity(
            opacity: _controlsVisible || !_isPlaying ? 1.0 : 0.0,
            duration: const Duration(milliseconds: 200),
            child: GestureDetector(
              onTap: _togglePlayPause,
              child: Container(
                color: Colors.black26,
                child: Center(
                  child: Icon(
                    _isPlaying ? Icons.pause_circle_outline : Icons.play_circle_outline,
                    color: Colors.white,
                    size: 64,
                  ),
                ),
              ),
            ),
          ),
          
          // Loading indicator
          if (_controller!.value.isBuffering)
            const Center(
              child: CircularProgressIndicator(
                color: Colors.white,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildLoadingWidget() {
    return AspectRatio(
      aspectRatio: 1.0,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Thumbnail
          Image.network(
            widget.thumbnailUrl,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) {
              print("Error loading thumbnail for ${widget.postId}: $error");
              return Container(
                color: Colors.grey.shade300,
                child: const Center(
                  child: Icon(Icons.video_library, size: 50, color: Colors.grey),
                ),
              );
            },
          ),
          
          // Loading indicator overlay
          Container(
            color: Colors.black38,
            child: const Center(
              child: CircularProgressIndicator(
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorWidget() {
    return AspectRatio(
      aspectRatio: 1.0,
      child: Container(
        color: Colors.black12,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.error_outline,
              color: Colors.red,
              size: 60,
            ),
            const SizedBox(height: 16),
            Text(
              'Error loading video',
              style: TextStyle(color: Colors.grey.shade800),
            ),
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: _initializeController,
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}