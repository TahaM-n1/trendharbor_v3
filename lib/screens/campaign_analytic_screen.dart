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

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final isTablet = screenSize.width > 768;
    final isMobile = screenSize.width <= 480;

    // Responsive dialog sizing
    final dialogWidth = isMobile
        ? screenSize.width * 0.95
        : isTablet
            ? screenSize.width * 0.7
            : screenSize.width * 0.9;

    final dialogHeight =
        isMobile ? screenSize.height * 0.9 : screenSize.height * 0.8;

    // Responsive grid settings
    final crossAxisCount = isMobile ? 1 : 2;
    final childAspectRatio = isMobile ? 2.5 : 1.5;
    final horizontalPadding = isMobile ? 12.0 : 16.0;

    return Container(
      width: dialogWidth,
      height: dialogHeight,
      padding: EdgeInsets.all(horizontalPadding),
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
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Campaign Analytics',
                            style: TextStyle(
                              fontSize: isMobile ? 20 : 24,
                              fontWeight: FontWeight.bold,
                              color: Colors.grey[800],
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            widget.campaignTitle,
                            style: TextStyle(
                              fontSize: isMobile ? 14 : 16,
                              color: Colors.grey[600],
                            ),
                            overflow: TextOverflow.ellipsis,
                            maxLines: isMobile ? 2 : 1,
                          ),
                        ],
                      ),
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
                  padding: EdgeInsets.symmetric(
                      vertical: 8, horizontal: isMobile ? 8 : 12),
                  decoration: BoxDecoration(
                    color: Colors.purple.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.person, color: Colors.purple[700], size: 16),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          'Influencer: ${widget.influencerName}',
                          style: TextStyle(
                            color: Colors.purple[700],
                            fontWeight: FontWeight.w500,
                            fontSize: isMobile ? 13 : 14,
                          ),
                          overflow: TextOverflow.ellipsis,
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
                  labelStyle: TextStyle(
                    fontSize: isMobile ? 13 : 14,
                    fontWeight: FontWeight.w500,
                  ),
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
                        padding:
                            EdgeInsets.symmetric(horizontal: isMobile ? 4 : 0),
                        child: Column(
                          children: [
                            GridView.count(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              crossAxisCount: crossAxisCount,
                              childAspectRatio: childAspectRatio,
                              crossAxisSpacing: isMobile ? 12 : 16,
                              mainAxisSpacing: isMobile ? 12 : 16,
                              children: [
                                _buildMetricCard(
                                    'Impressions',
                                    _analyticsData['impressions'],
                                    Icons.visibility,
                                    Colors.blue,
                                    isMobile),
                                _buildMetricCard(
                                    'Engagement',
                                    '${(_analyticsData['engagement'] / _analyticsData['impressions'] * 100).toStringAsFixed(1)}%',
                                    Icons.thumb_up,
                                    Colors.green,
                                    isMobile),
                                _buildMetricCard(
                                    'Click Rate',
                                    '${(_analyticsData['clicks'] / _analyticsData['impressions'] * 100).toStringAsFixed(1)}%',
                                    Icons.touch_app,
                                    Colors.amber,
                                    isMobile),
                                _buildMetricCard(
                                    'ROI',
                                    '${_analyticsData['roi'].toStringAsFixed(1)}x',
                                    Icons.attach_money,
                                    Colors.purple,
                                    isMobile),
                              ],
                            ),
                            const SizedBox(height: 16),
                            _buildEngagementChart(isMobile, isTablet),
                          ],
                        ),
                      ),
                      // Engagement tab
                      SingleChildScrollView(
                        padding:
                            EdgeInsets.symmetric(horizontal: isMobile ? 4 : 0),
                        child: Column(
                          children: [
                            GridView.count(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              crossAxisCount: crossAxisCount,
                              childAspectRatio: childAspectRatio,
                              crossAxisSpacing: isMobile ? 12 : 16,
                              mainAxisSpacing: isMobile ? 12 : 16,
                              children: [
                                _buildMetricCard(
                                    'Likes',
                                    _analyticsData['likes'],
                                    Icons.favorite,
                                    Colors.red,
                                    isMobile),
                                _buildMetricCard(
                                    'Comments',
                                    _analyticsData['comments'],
                                    Icons.chat_bubble,
                                    Colors.blue,
                                    isMobile),
                                _buildMetricCard(
                                    'Shares',
                                    _analyticsData['shares'],
                                    Icons.share,
                                    Colors.green,
                                    isMobile),
                                _buildMetricCard(
                                    'Saves',
                                    _analyticsData['saves'],
                                    Icons.bookmark,
                                    Colors.amber,
                                    isMobile),
                              ],
                            ),
                            SizedBox(height: isMobile ? 12 : 16),
                            Container(
                              padding: EdgeInsets.all(isMobile ? 12 : 16),
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
                                      fontSize: isMobile ? 14 : 16,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.grey[800],
                                    ),
                                  ),
                                  SizedBox(height: isMobile ? 12 : 16),
                                  Column(
                                    children: [
                                      _buildSummaryRow(
                                        'Total Engagement',
                                        _analyticsData['engagement'].toString(),
                                        isMobile,
                                      ),
                                      SizedBox(height: isMobile ? 12 : 16),
                                      _buildSummaryRow(
                                        'Engagement Rate',
                                        '${(_analyticsData['engagement'] / _analyticsData['impressions'] * 100).toStringAsFixed(1)}%',
                                        isMobile,
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
                        padding:
                            EdgeInsets.symmetric(horizontal: isMobile ? 4 : 0),
                        child: Column(
                          children: [
                            _buildDemographicChart(isMobile, isTablet),
                            SizedBox(height: isMobile ? 12 : 16),
                            Container(
                              padding: EdgeInsets.all(isMobile ? 12 : 16),
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
                                      fontSize: isMobile ? 14 : 16,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.grey[800],
                                    ),
                                  ),
                                  SizedBox(height: isMobile ? 12 : 16),
                                  ..._geographicData.map((data) {
                                    return Padding(
                                      padding: EdgeInsets.only(
                                          bottom: isMobile ? 6 : 8),
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
                                                  fontSize: isMobile ? 13 : 14,
                                                ),
                                              ),
                                              const Spacer(),
                                              Text(
                                                '${data['percentage']}%',
                                                style: TextStyle(
                                                  color: Colors.grey[700],
                                                  fontSize: isMobile ? 13 : 14,
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

  // Updated metric card with responsive sizing
  Widget _buildMetricCard(
      String title, dynamic value, IconData icon, Color color, bool isMobile) {
    return Container(
      padding: EdgeInsets.symmetric(
          vertical: isMobile ? 12 : 16, horizontal: isMobile ? 16 : 20),
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
              Icon(icon, color: color, size: isMobile ? 18 : 20),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  title,
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: isMobile ? 12 : 14,
                    fontWeight: FontWeight.w500,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          SizedBox(height: isMobile ? 6 : 8),
          Text(
            value.toString(),
            style: TextStyle(
              fontSize: isMobile ? 20 : 24,
              fontWeight: FontWeight.bold,
              color: Colors.grey[800],
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  // Updated engagement chart with responsive sizing
  Widget _buildEngagementChart(bool isMobile, bool isTablet) {
    return Container(
      height: isMobile ? 200 : 250,
      padding: EdgeInsets.all(isMobile ? 12 : 16),
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
              fontSize: isMobile ? 14 : 16,
              fontWeight: FontWeight.bold,
              color: Colors.grey[800],
            ),
          ),
          SizedBox(height: isMobile ? 12 : 16),
          Expanded(
            child: CustomPaint(
              size: Size(double.infinity, isMobile ? 150 : 200),
              painter: ChartPainter(_dailyData),
            ),
          ),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: isMobile ? 12 : 16,
            children: [
              _buildLegendItem('Likes', Colors.blue, isMobile),
              _buildLegendItem('Comments', Colors.green, isMobile),
              _buildLegendItem('Shares', Colors.purple, isMobile),
            ],
          ),
        ],
      ),
    );
  }

  // Updated legend item with responsive sizing
  Widget _buildLegendItem(String label, Color color, bool isMobile) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: isMobile ? 10 : 12,
          height: isMobile ? 10 : 12,
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
            fontSize: isMobile ? 11 : 12,
          ),
        ),
      ],
    );
  }

  // Updated demographic chart with responsive sizing
  Widget _buildDemographicChart(bool isMobile, bool isTablet) {
    return Container(
      height: isMobile ? 200 : 250,
      padding: EdgeInsets.all(isMobile ? 12 : 16),
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
              fontSize: isMobile ? 14 : 16,
              fontWeight: FontWeight.bold,
              color: Colors.grey[800],
            ),
          ),
          SizedBox(height: isMobile ? 12 : 16),
          Expanded(
            child: isMobile
                ? Column(
                    children: [
                      Expanded(
                        child: CustomPaint(
                          size: const Size(double.infinity, 120),
                          painter: PieChartPainter(_demographicData),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        alignment: WrapAlignment.center,
                        spacing: 8,
                        runSpacing: 4,
                        children: _demographicData.map((data) {
                          return Text(
                            '${data['age']}: ${data['percentage']}%',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey[700],
                            ),
                          );
                        }).toList(),
                      ),
                    ],
                  )
                : Row(
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

  // New helper method for summary rows
  Widget _buildSummaryRow(String title, String value, bool isMobile) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            color: Colors.grey[600],
            fontSize: isMobile ? 13 : 14,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: isMobile ? 18 : 20,
            fontWeight: FontWeight.bold,
            color: Colors.grey[800],
          ),
        ),
      ],
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
