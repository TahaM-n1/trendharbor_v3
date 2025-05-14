import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';

class CampaignAnalyticsScreen extends StatefulWidget {
  final String campaignId;
  final String influencerId;

  const CampaignAnalyticsScreen({
    Key? key,
    required this.campaignId,
    required this.influencerId,
  }) : super(key: key);

  @override
  _CampaignAnalyticsScreenState createState() =>
      _CampaignAnalyticsScreenState();
}

class _CampaignAnalyticsScreenState extends State<CampaignAnalyticsScreen> {
  Stream<DocumentSnapshot>? _campaignStream;
  Stream<QuerySnapshot>? _postsStream;

  @override
  void initState() {
    super.initState();
    _initializeStreams();
  }

  void _initializeStreams() {
    // Stream for campaign details
    _campaignStream = FirebaseFirestore.instance
        .collection('campaigns')
        .doc(widget.campaignId)
        .snapshots();

    // Stream for posts created by this influencer for this campaign
    _postsStream = FirebaseFirestore.instance
        .collection('posts')
        .where('user.id', isEqualTo: widget.influencerId)
        .snapshots();
  }

  Widget _buildAnalyticsSummary(Map<String, dynamic> campaignData) {
    final bidData = campaignData['influencerBids']?[widget.influencerId] ?? {};

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.shade200,
            blurRadius: 10,
            spreadRadius: 2,
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Campaign Performance',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.deepPurple,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildStatCard(
                icon: Icons.attach_money,
                label: 'Campaign Fee',
                value: '\$${bidData['bid']?.toStringAsFixed(2) ?? '0.00'}',
                color: Colors.green,
              ),
              _buildStatCard(
                icon: Icons.calendar_today,
                label: 'Campaign Status',
                value: bidData['status']
                        ?.toString()
                        .replaceAll('_', ' ')
                        .toUpperCase() ??
                    'UNKNOWN',
                color: Colors.blue,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 30),
          const SizedBox(height: 8),
          Text(
            label,
            style: TextStyle(
              color: Colors.grey[700],
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPostAnalytics() {
    return StreamBuilder<QuerySnapshot>(
      stream: _postsStream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.shade200,
                  blurRadius: 10,
                  spreadRadius: 2,
                )
              ],
            ),
            child: Column(
              children: [
                Icon(Icons.no_photography, color: Colors.grey[400], size: 60),
                const SizedBox(height: 16),
                Text(
                  'No Posts Created Yet',
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          );
        }

        final posts = snapshot.data!.docs;
        int totalLikes = 0;
        int totalComments = 0;

        for (var post in posts) {
          final postData = post.data() as Map<String, dynamic>;
          totalLikes += postData['likes'] as int? ?? 0;
          totalComments += postData['comments'] as int? ?? 0;
        }

        return Container(
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.grey.shade200,
                blurRadius: 10,
                spreadRadius: 2,
              )
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Post Performance',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.deepPurple,
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildStatCard(
                    icon: Icons.thumb_up,
                    label: 'Total Likes',
                    value: totalLikes.toString(),
                    color: Colors.pink,
                  ),
                  _buildStatCard(
                    icon: Icons.comment,
                    label: 'Total Comments',
                    value: totalComments.toString(),
                    color: Colors.orange,
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                'Campaign Posts (${posts.length})',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[800],
                ),
              ),
              const SizedBox(height: 12),
              ...posts.map((post) {
                final postData = post.data() as Map<String, dynamic>;
                return _buildPostItem(postData);
              }).toList(),
            ],
          ),
        );
      },
    );
  }

  Widget _buildPostItem(Map<String, dynamic> postData) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(10)),
            child: CachedNetworkImage(
              imageUrl: postData['imageUrl'] ?? '',
              height: 200,
              width: double.infinity,
              fit: BoxFit.cover,
              placeholder: (context, url) =>
                  const Center(child: CircularProgressIndicator()),
              errorWidget: (context, url, error) => const Icon(Icons.error),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  postData['caption'] ?? 'No Caption',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[800],
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(Icons.thumb_up, size: 16, color: Colors.pink[300]),
                    const SizedBox(width: 4),
                    Text(
                      '${postData['likes'] ?? 0} Likes',
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                    const SizedBox(width: 16),
                    Icon(Icons.comment, size: 16, color: Colors.orange[300]),
                    const SizedBox(width: 4),
                    Text(
                      '${postData['comments'] ?? 0} Comments',
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Posted ${_formatTimestamp(postData['createdAt'])}',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[500],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatTimestamp(Timestamp? timestamp) {
    if (timestamp == null) return 'Unknown date';
    final dateTime = timestamp.toDate();
    return DateFormat('MMM d, yyyy - HH:mm').format(dateTime);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('Campaign Analytics'),
        backgroundColor: Colors.deepPurple,
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: _campaignStream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData) {
            return const Center(child: Text('No campaign data found'));
          }

          final campaignData = snapshot.data!.data() as Map<String, dynamic>;

          return ListView(
            children: [
              _buildAnalyticsSummary(campaignData),
              _buildPostAnalytics(),
            ],
          );
        },
      ),
    );
  }
}
