import 'package:flutter/material.dart';
import '../models/post_model.dart';
import '../services/storage_service.dart';

class PostWidget extends StatefulWidget {
  final Post post;

  const PostWidget({super.key, required this.post});

  @override
  State<PostWidget> createState() => _PostWidgetState();
}

class _PostWidgetState extends State<PostWidget> {
  @override
  void initState() {
    super.initState();
    _loadLikeState();
  }

  Future<void> _loadLikeState() async {
    final liked = await StorageService.loadLikeState(widget.post.user.id);
    setState(() {
      widget.post.liked = liked;
    });
  }

  void _toggleLike() async {
    setState(() {
      widget.post.liked = !widget.post.liked;
      if (widget.post.liked) {
        widget.post.likes++;
      } else {
        widget.post.likes--;
      }
    });
    await StorageService.saveLikeState(widget.post.user.id, widget.post.liked);
  }

  @override
  Widget build(BuildContext context) {
    // Wrap the entire post in a Center and ConstrainedBox to limit width
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          maxWidth: 700, // Instagram-like max width
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
        // User Info
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: Row(
            children: [
              CircleAvatar(
                backgroundImage: AssetImage(widget.post.user.profileImageUrl),
              ),
              const SizedBox(width: 8),
              Text(
                widget.post.user.username,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ],
          ),
        ),
        // Post Image with fixed aspect ratio
        AspectRatio(
          aspectRatio: 1.0, // 1:1 Square aspect ratio (Instagram default)
          child: widget.post.imageUrl != null
              ? Image.asset(
                  widget.post.imageUrl!,
                  fit: BoxFit.cover,
                  width: double.infinity,
                )
              : Container(
                  color: Colors.grey[300],
                  child: const Center(
                    child: Icon(
                      Icons.image_not_supported,
                      size: 50,
                      color: Colors.grey,
                    ),
                  ),
                ),
        ),
        // Interaction Buttons
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: Row(
            children: [
              IconButton(
                icon: Icon(
                  widget.post.liked ? Icons.favorite : Icons.favorite_border,
                  color: widget.post.liked ? Colors.red : null,
                ),
                onPressed: _toggleLike,
              ),
              IconButton(
                icon: const Icon(Icons.comment_outlined),
                onPressed: () {},
              ),
              IconButton(
                icon: const Icon(Icons.send),
                onPressed: () {},
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.bookmark_border),
                onPressed: () {},
              ),
            ],
          ),
        ),
        // Likes and Caption
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${widget.post.likes} likes',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                widget.post.caption,
                style: const TextStyle(fontSize: 14),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}