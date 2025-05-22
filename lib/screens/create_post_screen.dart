import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:io';
import 'dart:math';  // Add this for min()
import 'dart:typed_data';  // Add this for Uint8List
import 'package:video_player/video_player.dart';

class CreatePostScreen extends StatefulWidget {
  const CreatePostScreen({super.key});

  @override
  State<CreatePostScreen> createState() => _CreatePostScreenState();
}

class _CreatePostScreenState extends State<CreatePostScreen> {
  XFile? _selectedMedia;
  String _mediaType = 'image'; // 'image' or 'video'
  final TextEditingController _captionController = TextEditingController();
  bool _isLoading = false;
  final ImagePicker _picker = ImagePicker();
  VideoPlayerController? _videoController;
  
  @override
  void dispose() {
    _captionController.dispose();
    _videoController?.dispose();
    super.dispose();
  }
  
  Future<void> _pickImage() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 80,
      );
      
      if (image != null) {
        // Clean up any existing video controller
        _videoController?.dispose();
        _videoController = null;
        
        setState(() {
          _selectedMedia = image;
          _mediaType = 'image';
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error selecting image: $e')),
      );
    }
  }

  Future<void> _pickVideo() async {
    try {
      final XFile? video = await _picker.pickVideo(
        source: ImageSource.gallery,
        maxDuration: const Duration(minutes: 1), // Limit to 1 minute videos
      );
      
      if (video != null) {
        print('Video selected: ${video.path}');
        // Dispose any existing controller
        _videoController?.dispose();
        _videoController = null;
        
        // Set the selected media first
        setState(() {
          _selectedMedia = video;
          _mediaType = 'video';
        });
        
        try {
          if (kIsWeb) {
            // On web, we need to handle the path differently
            // Web paths are either data URLs or blob URLs
            _videoController = VideoPlayerController.networkUrl(
              Uri.parse(video.path)
            );
          } else {
            // On mobile, we can use the file directly
            _videoController = VideoPlayerController.file(File(video.path));
          }
          
          print('Initializing video controller');
          await _videoController!.initialize();
          await _videoController!.setLooping(true);
          
          if (mounted) {
            setState(() {
              // Update UI after controller is initialized
            });
            print('Video controller initialized successfully');
          }
        } catch (e) {
          print('Error initializing video controller: $e');
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error previewing video: $e')),
          );
        }
      }
    } catch (e) {
      print('Error selecting video: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error selecting video: $e')),
      );
    }
  }
  
  Future<void> _uploadPost() async {
    if (_selectedMedia == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select an image or video first')),
      );
      return;
    }
    
    setState(() {
      _isLoading = true;
    });
    
    try {
      final User? currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        throw Exception('User not authenticated');
      }
      
      // Get user data
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser.uid)
          .get();
      
      if (!userDoc.exists) {
        throw Exception('User data not found');
      }
      
      final userData = userDoc.data()!;
      
      // 1. Upload media to Firebase Storage
      final String fileExtension = _mediaType == 'image' ? '.jpg' : '.mp4';
      final String fileName = 'posts/${currentUser.uid}_${DateTime.now().millisecondsSinceEpoch}$fileExtension';
      final storageRef = FirebaseStorage.instance.ref().child(fileName);
      
      UploadTask uploadTask;
      if (kIsWeb) {
        // Web platform
        final bytes = await _selectedMedia!.readAsBytes();
        uploadTask = storageRef.putData(
          bytes,
          SettableMetadata(contentType: _mediaType == 'image' ? 'image/jpeg' : 'video/mp4'),
        );
      } else {
        // Mobile platform
        final mediaFile = File(_selectedMedia!.path);
        uploadTask = storageRef.putFile(mediaFile);
      }
      
      // Wait for upload to complete
      final TaskSnapshot taskSnapshot = await uploadTask;
      final String downloadUrl = await taskSnapshot.ref.getDownloadURL();
      
      // 2. Generate or upload thumbnail for videos
      String? thumbnailUrl;
      if (_mediaType == 'video') {
        // For simplicity, we're just using a specific frame from the video
        // In a real app, you'd want to generate an actual thumbnail
        final String thumbFileName = 'thumbnails/${currentUser.uid}_${DateTime.now().millisecondsSinceEpoch}.jpg';
        final thumbRef = FirebaseStorage.instance.ref().child(thumbFileName);
        
        // For web, we'd need to use a package like video_thumbnail to generate
        // For this example, we're just using a placeholder approach
        // In a real app, you'd generate a proper thumbnail:
        
        // Example placeholder logic - in reality, generate from the video:
        final Uint8List placeholderData = await _selectedMedia!.readAsBytes(); // This isn't a real thumbnail
        
        final thumbUploadTask = thumbRef.putData(
          placeholderData.sublist(0, min(100000, placeholderData.length)), // Just use part of the data as a mock
          SettableMetadata(contentType: 'image/jpeg'),
        );
        
        final thumbSnapshot = await thumbUploadTask;
        thumbnailUrl = await thumbSnapshot.ref.getDownloadURL();
      }
      
      // 3. Create post document in Firestore
      await FirebaseFirestore.instance.collection('posts').add({
        'userId': currentUser.uid,
        'username': userData['username'] ?? 'Unknown User',
        'userProfileImage': userData['profileImageUrl'] ?? '',
        'mediaType': _mediaType,
        'imageUrl': _mediaType == 'image' ? downloadUrl : null,
        'videoUrl': _mediaType == 'video' ? downloadUrl : null,
        'thumbnailUrl': thumbnailUrl,  // Only for videos
        'caption': _captionController.text,
        'likes': 0,
        'comments': 0,
        'timestamp': FieldValue.serverTimestamp(),
      });
      
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${_mediaType.capitalize()} posted successfully!'),
            backgroundColor: Colors.green,
          ),
        );
        
        // Navigate back to the profile or home screen
        context.go('/home');
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to create post: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Create ${_mediaType.capitalize()}'),
        actions: [
          TextButton(
            onPressed: _isLoading ? null : _uploadPost,
            child: _isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Text(
                    'Share',
                    style: TextStyle(
                      color: Colors.blue,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: 700,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Media type selector
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                  child: SegmentedButton<String>(
                    segments: const [
                      ButtonSegment<String>(
                        value: 'image',
                        label: Text('Photo'),
                        icon: Icon(Icons.image),
                      ),
                      ButtonSegment<String>(
                        value: 'video',
                        label: Text('Reel'),
                        icon: Icon(Icons.videocam),
                      ),
                    ],
                    selected: {_mediaType},
                    onSelectionChanged: (Set<String> selection) {
                      setState(() {
                        _mediaType = selection.first;
                      });
                    },
                  ),
                ),
                
                // Media Preview or Selector
                GestureDetector(
                  onTap: _mediaType == 'image' ? _pickImage : _pickVideo,
                  child: AspectRatio(
                    aspectRatio: 1.0,
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.grey[200],
                        border: Border.all(
                          color: Colors.grey.shade300, 
                          width: 1,
                        ),
                      ),
                      child: _buildMediaPreview(),
                    ),
                  ),
                ),
                
                // Caption input
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Caption',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.grey[100],
                          borderRadius: BorderRadius.circular(8),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        child: TextField(
                          controller: _captionController,
                          decoration: const InputDecoration(
                            hintText: 'Write a caption...',
                            border: InputBorder.none,
                          ),
                          maxLines: 5,
                          style: const TextStyle(fontSize: 16),
                        ),
                      ),
                      
                      // Hashtags suggestion
                      const SizedBox(height: 16),
                      const Text(
                        'Popular Hashtags',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        height: 36,
                        child: ListView(
                          scrollDirection: Axis.horizontal,
                          children: [
                            _buildHashtagChip('#fashion'),
                            _buildHashtagChip('#style'),
                            _buildHashtagChip('#trendy'),
                            _buildHashtagChip('#ootd'),
                            _buildHashtagChip('#lifestyle'),
                            _buildHashtagChip('#beauty'),
                            _buildHashtagChip('#reels'),
                            _buildHashtagChip('#trending'),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                
                // Post settings
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Divider(),
                      ListTile(
                        leading: const Icon(Icons.location_on_outlined),
                        title: const Text('Add Location'),
                        trailing: const Icon(Icons.chevron_right),
                        contentPadding: EdgeInsets.zero,
                        onTap: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Location feature coming soon')),
                          );
                        },
                      ),
                      const Divider(),
                      ListTile(
                        leading: const Icon(Icons.tag),
                        title: const Text('Tag People'),
                        trailing: const Icon(Icons.chevron_right),
                        contentPadding: EdgeInsets.zero,
                        onTap: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Tag feature coming soon')),
                          );
                        },
                      ),
                      const Divider(),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMediaPreview() {
    if (_selectedMedia == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              _mediaType == 'image' ? Icons.add_photo_alternate : Icons.video_call,
              size: 64,
              color: Colors.grey,
            ),
            const SizedBox(height: 16),
            Text(
              'Tap to select ${_mediaType == 'image' ? 'an image' : 'a video'}',
              style: const TextStyle(
                color: Colors.grey,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      );
    } else if (_mediaType == 'image') {
      return kIsWeb
          ? Image.network(
              _selectedMedia!.path,
              fit: BoxFit.contain,
            )
          : Image.file(
              File(_selectedMedia!.path),
              fit: BoxFit.contain,
            );
    } else {
      // Video preview
      if (_videoController != null && _videoController!.value.isInitialized) {
        return Stack(
          alignment: Alignment.center,
          children: [
            AspectRatio(
              aspectRatio: _videoController!.value.aspectRatio,
              child: VideoPlayer(_videoController!),
            ),
            FloatingActionButton(
              onPressed: () {
                setState(() {
                  if (_videoController!.value.isPlaying) {
                    _videoController!.pause();
                  } else {
                    _videoController!.play();
                  }
                });
              },
              backgroundColor: Colors.black54,
              child: Icon(
                _videoController!.value.isPlaying ? Icons.pause : Icons.play_arrow,
              ),
            ),
          ],
        );
      } else {
        return const Center(
          child: CircularProgressIndicator(),
        );
      }
    }
  }

  Widget _buildHashtagChip(String hashtag) {
    return Padding(
      padding: const EdgeInsets.only(right: 8.0),
      child: GestureDetector(
        onTap: () {
          // Append hashtag to caption
          final currentText = _captionController.text;
          if (currentText.isEmpty) {
            _captionController.text = '$hashtag ';
          } else if (currentText.endsWith(' ')) {
            _captionController.text = '$currentText$hashtag ';
          } else {
            _captionController.text = '$currentText $hashtag ';
          }
          // Move cursor to end
          _captionController.selection = TextSelection.fromPosition(
            TextPosition(offset: _captionController.text.length),
          );
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.blue.withOpacity(0.1),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Text(
            hashtag,
            style: TextStyle(
              color: Colors.blue.shade700,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }
}

// Extension to capitalize first letter of a string
extension StringExtension on String {
  String capitalize() {
    return "${this[0].toUpperCase()}${substring(1)}";
  }
}