// Add this Analytics Screen Widget at the end of the file
import 'dart:ui';

import 'package:flutter/material.dart';

class AnalyticsScreen extends StatefulWidget {
  final String campaignId;
  final String influencerId;
  final String influencerName;
  final String campaignTitle;

  const AnalyticsScreen({
    Key? key,
    required this.campaignId,
    required this.influencerId,
    required this.influencerName,
    required this.campaignTitle,
  }) : super(key: key);

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isLoading = true;

  // Dummy analytics data
  final Map<String, dynamic> _analyticsData = {
    'impressions': 4287,
    'engagement': 842,
    'clicks': 356,
    'conversion': 28,
    'roi': 3.7,
    'likes': 523,
    'comments': 89,
    'shares': 127,
    'saves': 75,
    'timeSpent': 2.8, // minutes
  };

  // Daily engagement data for charts (7 days)
  final List<Map<String, dynamic>> _dailyData = [
    {'day': 'Mon', 'likes': 42, 'comments': 8, 'shares': 12},
    {'day': 'Tue', 'likes': 67, 'comments': 12, 'shares': 15},
    {'day': 'Wed', 'likes': 103, 'comments': 18, 'shares': 26},
    {'day': 'Thu', 'likes': 89, 'comments': 14, 'shares': 21},
    {'day': 'Fri', 'likes': 118, 'comments': 22, 'shares': 31},
    {'day': 'Sat', 'likes': 76, 'comments': 11, 'shares': 16},
    {'day': 'Sun', 'likes': 28, 'comments': 4, 'shares': 6},
  ];

  // Demographic data
  final List<Map<String, dynamic>> _demographicData = [
    {'age': '18-24', 'percentage': 32},
    {'age': '25-34', 'percentage': 41},
    {'age': '35-44', 'percentage': 18},
    {'age': '45-54', 'percentage': 7},
    {'age': '55+', 'percentage': 2},
  ];

  // Geographic data
  final List<Map<String, dynamic>> _geographicData = [
    {'region': 'North America', 'percentage': 43},
    {'region': 'Europe', 'percentage': 28},
    {'region': 'Asia', 'percentage': 18},
    {'region': 'South America', 'percentage': 7},
    {'region': 'Other', 'percentage': 4},
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);

    // Simulate loading data
    Future.delayed(const Duration(seconds: 1), () {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // Build a metric card for key stats
  Widget _buildMetricCard(
      String title, dynamic value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 6,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value.toString(),
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.grey[800],
            ),
          ),
        ],
      ),
    );
  }

  // Build engagement chart
  Widget _buildEngagementChart() {
    return Container(
      height: 250,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 6,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Daily Engagement',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.grey[800],
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: CustomPaint(
              size: const Size(double.infinity, 200),
              painter: ChartPainter(_dailyData),
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildLegendItem('Likes', Colors.blue),
              const SizedBox(width: 16),
              _buildLegendItem('Comments', Colors.green),
              const SizedBox(width: 16),
              _buildLegendItem('Shares', Colors.purple),
            ],
          ),
        ],
      ),
    );
  }

  // Build legend item
  Widget _buildLegendItem(String label, Color color) {
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(
            color: Colors.grey[600],
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  // Build demographic chart
  Widget _buildDemographicChart() {
    return Container(
      height: 250,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 6,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Age Demographics',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.grey[800],
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: Row(
              children: [
                SizedBox(
                  width: 100,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: _demographicData.map((data) {
                      return Text(
                        '${data['age']}: ${data['percentage']}%',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[700],
                        ),
                      );
                    }).toList(),
                  ),
                ),
                Expanded(
                  child: CustomPaint(
                    size: const Size(double.infinity, 200),
                    painter: PieChartPainter(_demographicData),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: MediaQuery.of(context).size.width * 0.9,
      height: MediaQuery.of(context).size.height * 0.8,
      padding: const EdgeInsets.all(16),
      child: _isLoading
          ? const Center(
              child: CircularProgressIndicator(),
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Campaign Analytics',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey[800],
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          widget.campaignTitle,
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close),
                      color: Colors.grey[600],
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                  decoration: BoxDecoration(
                    color: Colors.purple.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.person, color: Colors.purple[700], size: 16),
                      const SizedBox(width: 8),
                      Text(
                        'Influencer: ${widget.influencerName}',
                        style: TextStyle(
                          color: Colors.purple[700],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                // Tab bar
                TabBar(
                  controller: _tabController,
                  labelColor: Colors.purple[700],
                  unselectedLabelColor: Colors.grey[600],
                  indicatorColor: Colors.purple[700],
                  tabs: const [
                    Tab(text: 'Overview'),
                    Tab(text: 'Engagement'),
                    Tab(text: 'Demographics'),
                  ],
                ),
                const SizedBox(height: 16),
                // Tab content
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      // Overview tab
                      SingleChildScrollView(
                        child: Column(
                          children: [
                            GridView.count(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              crossAxisCount: 2,
                              childAspectRatio: 1.5,
                              crossAxisSpacing: 16,
                              mainAxisSpacing: 16,
                              children: [
                                _buildMetricCard(
                                    'Impressions',
                                    _analyticsData['impressions'],
                                    Icons.visibility,
                                    Colors.blue),
                                _buildMetricCard(
                                    'Engagement',
                                    '${(_analyticsData['engagement'] / _analyticsData['impressions'] * 100).toStringAsFixed(1)}%',
                                    Icons.thumb_up,
                                    Colors.green),
                                _buildMetricCard(
                                    'Click Rate',
                                    '${(_analyticsData['clicks'] / _analyticsData['impressions'] * 100).toStringAsFixed(1)}%',
                                    Icons.touch_app,
                                    Colors.amber),
                                _buildMetricCard(
                                    'ROI',
                                    '${_analyticsData['roi'].toStringAsFixed(1)}x',
                                    Icons.attach_money,
                                    Colors.purple),
                              ],
                            ),
                            const SizedBox(height: 16),
                            _buildEngagementChart(),
                          ],
                        ),
                      ),
                      // Engagement tab
                      SingleChildScrollView(
                        child: Column(
                          children: [
                            GridView.count(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              crossAxisCount: 2,
                              childAspectRatio: 1.5,
                              crossAxisSpacing: 16,
                              mainAxisSpacing: 16,
                              children: [
                                _buildMetricCard(
                                    'Likes',
                                    _analyticsData['likes'],
                                    Icons.favorite,
                                    Colors.red),
                                _buildMetricCard(
                                    'Comments',
                                    _analyticsData['comments'],
                                    Icons.chat_bubble,
                                    Colors.blue),
                                _buildMetricCard(
                                    'Shares',
                                    _analyticsData['shares'],
                                    Icons.share,
                                    Colors.green),
                                _buildMetricCard(
                                    'Saves',
                                    _analyticsData['saves'],
                                    Icons.bookmark,
                                    Colors.amber),
                              ],
                            ),
                            const SizedBox(height: 16),
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(16),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.grey.withOpacity(0.1),
                                    spreadRadius: 1,
                                    blurRadius: 6,
                                    offset: const Offset(0, 3),
                                  ),
                                ],
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Engagement Summary',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.grey[800],
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              'Total Engagement',
                                              style: TextStyle(
                                                color: Colors.grey[600],
                                                fontSize: 14,
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              _analyticsData['engagement']
                                                  .toString(),
                                              style: TextStyle(
                                                fontSize: 20,
                                                fontWeight: FontWeight.bold,
                                                color: Colors.grey[800],
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              'Engagement Rate',
                                              style: TextStyle(
                                                color: Colors.grey[600],
                                                fontSize: 14,
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              '${(_analyticsData['engagement'] / _analyticsData['impressions'] * 100).toStringAsFixed(1)}%',
                                              style: TextStyle(
                                                fontSize: 20,
                                                fontWeight: FontWeight.bold,
                                                color: Colors.grey[800],
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Demographics tab
                      SingleChildScrollView(
                        child: Column(
                          children: [
                            _buildDemographicChart(),
                            const SizedBox(height: 16),
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(16),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.grey.withOpacity(0.1),
                                    spreadRadius: 1,
                                    blurRadius: 6,
                                    offset: const Offset(0, 3),
                                  ),
                                ],
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Geographic Distribution',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.grey[800],
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  ..._geographicData.map((data) {
                                    return Padding(
                                      padding: const EdgeInsets.only(bottom: 8),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Text(
                                                data['region'],
                                                style: TextStyle(
                                                  color: Colors.grey[700],
                                                  fontSize: 14,
                                                ),
                                              ),
                                              const Spacer(),
                                              Text(
                                                '${data['percentage']}%',
                                                style: TextStyle(
                                                  color: Colors.grey[700],
                                                  fontSize: 14,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 4),
                                          LinearProgressIndicator(
                                            value: data['percentage'] / 100,
                                            backgroundColor: Colors.grey[200],
                                            valueColor:
                                                AlwaysStoppedAnimation<Color>(
                                              _getRegionColor(data['region']),
                                            ),
                                          ),
                                        ],
                                      ),
                                    );
                                  }).toList(),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  Color _getRegionColor(String region) {
    switch (region) {
      case 'North America':
        return Colors.blue;
      case 'Europe':
        return Colors.green;
      case 'Asia':
        return Colors.orange;
      case 'South America':
        return Colors.purple;
      default:
        return Colors.grey;
    }
  }
}

// Custom chart painter for engagement
class ChartPainter extends CustomPainter {
  final List<Map<String, dynamic>> data;

  ChartPainter(this.data);

  @override
  void paint(Canvas canvas, Size size) {
    // Find max values for scaling
    double maxLikes = 0;
    double maxComments = 0;
    double maxShares = 0;

    for (var item in data) {
      if (item['likes'] > maxLikes) maxLikes = item['likes'].toDouble();
      if (item['comments'] > maxComments)
        maxComments = item['comments'].toDouble();
      if (item['shares'] > maxShares) maxShares = item['shares'].toDouble();
    }

    final double maxValue =
        [maxLikes, maxComments, maxShares].reduce((a, b) => a > b ? a : b);

    // Calculate bar width
    final double barWidth = size.width / (data.length * 3 + 1);
    final double barSpacing = barWidth / 2;

    // Define paints
    final Paint likesPaint = Paint()
      ..color = Colors.blue
      ..style = PaintingStyle.fill;

    final Paint commentsPaint = Paint()
      ..color = Colors.green
      ..style = PaintingStyle.fill;

    final Paint sharesPaint = Paint()
      ..color = Colors.purple
      ..style = PaintingStyle.fill;

    // Draw grid lines
    final Paint gridPaint = Paint()
      ..color = Colors.grey.withOpacity(0.2)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    // Draw horizontal grid lines
    for (int i = 0; i <= 4; i++) {
      double y = size.height - (size.height * i / 4);
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    // Draw bars
    for (int i = 0; i < data.length; i++) {
      var item = data[i];

      // X position for group of bars
      double x = i * (barWidth * 3 + barSpacing) + barSpacing;

      // Likes bar
      double likesHeight = (item['likes'] / maxValue) * size.height;
      canvas.drawRect(
        Rect.fromLTWH(x, size.height - likesHeight, barWidth, likesHeight),
        likesPaint,
      );

      // Comments bar
      double commentsHeight = (item['comments'] / maxValue) * size.height;
      canvas.drawRect(
        Rect.fromLTWH(x + barWidth, size.height - commentsHeight, barWidth,
            commentsHeight),
        commentsPaint,
      );

      // Shares bar
      double sharesHeight = (item['shares'] / maxValue) * size.height;
      canvas.drawRect(
        Rect.fromLTWH(x + barWidth * 2, size.height - sharesHeight, barWidth,
            sharesHeight),
        sharesPaint,
      );

      // Day label
      TextPainter textPainter = TextPainter(
        text: TextSpan(
          text: item['day'],
          style: TextStyle(
            color: Colors.grey[600],
            fontSize: 10,
          ),
        ),
        textDirection: TextDirection.ltr,
      );

      textPainter.layout();
      textPainter.paint(
        canvas,
        Offset(x + barWidth, size.height + 5),
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// Custom pie chart painter for demographics
class PieChartPainter extends CustomPainter {
  final List<Map<String, dynamic>> data;

  PieChartPainter(this.data);

  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()..style = PaintingStyle.fill;

    // Calculate total for percentages
    final double total =
        data.fold(0, (sum, item) => sum + item['percentage'] as double);

    // Define colors for each segment
    final List<Color> colors = [
      Colors.blue,
      Colors.green,
      Colors.orange,
      Colors.purple,
      Colors.teal,
    ];

    // Draw pie segments
    double startAngle = 0;
    for (int i = 0; i < data.length; i++) {
      final percentage = data[i]['percentage'] / total;
      final sweepAngle = percentage * 2 * 3.14159; // Convert to radians

      paint.color = colors[i % colors.length];

      canvas.drawArc(
        Rect.fromCircle(
          center: Offset(size.width / 2, size.height / 2),
          radius: size.width / 3,
        ),
        startAngle,
        sweepAngle,
        true,
        paint,
      );

      startAngle += sweepAngle;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
