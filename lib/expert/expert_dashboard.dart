import 'package:flutter/material.dart';
import 'scan_request_list.dart';
import 'disease_editor.dart';
import 'expert_profile.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:hive/hive.dart';
import 'package:fl_chart/fl_chart.dart';
import 'dart:async'; // Added for StreamSubscription

class ExpertDashboard extends StatefulWidget {
  const ExpertDashboard({Key? key}) : super(key: key);

  @override
  State<ExpertDashboard> createState() => _ExpertDashboardState();
}

class _ExpertDashboardState extends State<ExpertDashboard> {
  int _selectedIndex = 0;
  int _requestsInitialTab = 0; // 0 for pending, 1 for completed
  int _pendingNotifications = 0; // Track pending notifications

  List<Widget> _pages = [];

  @override
  void initState() {
    super.initState();
    _updatePages();
    _loadNotificationCount(); // Load notification count
  }

  void _updatePages() {
    _pages = <Widget>[
      ExpertHomePage(), // Home tab
      ScanRequestList(initialTabIndex: _requestsInitialTab), // Requests tab
      DiseaseEditor(), // Diseases tab
      ExpertProfile(), // Profile tab
    ];
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });

    // Clear notifications when Requests tab is clicked
    if (index == 1) {
      _clearNotifications();
    }
  }

  // Load notification count from Hive
  Future<void> _loadNotificationCount() async {
    try {
      final notificationBox = await Hive.openBox('notificationBox');
      final count = notificationBox.get(
        'pendingNotifications',
        defaultValue: 0,
      );
      setState(() {
        _pendingNotifications = count;
      });
    } catch (e) {
      print('Error loading notification count: $e');
    }
  }

  // Save notification count to Hive
  Future<void> _saveNotificationCount(int count) async {
    try {
      final notificationBox = await Hive.openBox('notificationBox');
      await notificationBox.put('pendingNotifications', count);
    } catch (e) {
      print('Error saving notification count: $e');
    }
  }

  // Clear notifications when Requests tab is clicked
  void _clearNotifications() async {
    await _saveNotificationCount(0);
    setState(() {
      _pendingNotifications = 0;
    });
  }

  void _navigateToRequests(int tabIndex) {
    setState(() {
      _requestsInitialTab = tabIndex;
      _selectedIndex = 1; // Switch to Requests tab
      _updatePages();
    });
    _clearNotifications(); // Clear notifications when navigating to requests
  }

  @override
  Widget build(BuildContext context) {
    // Get the appropriate title based on selected index
    String getTitle() {
      switch (_selectedIndex) {
        case 0:
          return 'Home';
        case 1:
          return 'Requests';
        case 2:
          return 'Diseases';
        case 3:
          return 'Profile';
        default:
          return 'Expert Dashboard';
      }
    }

    return Scaffold(
      appBar: AppBar(title: Text(getTitle()), backgroundColor: Colors.green),
      body:
          _pages.isNotEmpty
              ? _pages[_selectedIndex]
              : const Center(child: CircularProgressIndicator()),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        selectedItemColor: Colors.green,
        type: BottomNavigationBarType.fixed,
        items: [
          const BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
          BottomNavigationBarItem(
            icon: Stack(
              clipBehavior: Clip.none,
              children: [
                const Icon(Icons.list_alt),
                if (_pendingNotifications > 0)
                  Positioned(
                    right: -6,
                    top: -6,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 4,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.red,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.2),
                            blurRadius: 2,
                            offset: const Offset(0, 1),
                          ),
                        ],
                      ),
                      constraints: const BoxConstraints(
                        minWidth: 16,
                        minHeight: 16,
                      ),
                      child: Text(
                        _pendingNotifications > 9
                            ? '9+'
                            : '$_pendingNotifications',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
              ],
            ),
            label: 'Requests',
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.local_hospital),
            label: 'Diseases',
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}

// Expert Home Page Widget
class ExpertHomePage extends StatefulWidget {
  const ExpertHomePage({Key? key}) : super(key: key);

  @override
  State<ExpertHomePage> createState() => _ExpertHomePageState();
}

class _ExpertHomePageState extends State<ExpertHomePage> {
  int _totalCompleted = 0;
  int _pendingRequests = 0;
  String _expertName = 'Expert';
  double _averageResponseTime = 0.0;
  List<Map<String, dynamic>> _recentReviews = [];
  bool _isOffline = false;
  StreamSubscription<QuerySnapshot>? _streamSubscription;

  // Debug tracking variables
  int _lastPendingCount = 0;
  int _lastCompletedCount = 0;

  // Update notification count
  void _updateNotificationCount(int newCount) {
    // Find the parent dashboard to update notification count
    final dashboard = context.findAncestorStateOfType<_ExpertDashboardState>();
    if (dashboard != null) {
      dashboard._pendingNotifications = newCount;
      dashboard._saveNotificationCount(newCount);
      dashboard.setState(() {});
    }
  }

  @override
  void initState() {
    super.initState();
    _loadExpertStats();
  }

  @override
  void dispose() {
    _streamSubscription?.cancel();
    super.dispose();
  }

  // Clean up old cached data to prevent memory buildup
  Future<void> _cleanupOldCache() async {
    try {
      final statsBox = await Hive.openBox('expertStatsBox');
      final cachedData = statsBox.get('expertStats');

      if (cachedData != null) {
        final lastUpdated = DateTime.tryParse(cachedData['lastUpdated'] ?? '');
        if (lastUpdated != null) {
          final daysSinceUpdate = DateTime.now().difference(lastUpdated).inDays;
          // Remove cache older than 7 days
          if (daysSinceUpdate > 7) {
            await statsBox.delete('expertStats');
            print('Cleaned up old cached data');
          }
        }
      }
    } catch (e) {
      print('Error cleaning up cache: $e');
    }
  }

  // Force clear cache to get fresh calculation
  Future<void> _clearCache() async {
    try {
      final statsBox = await Hive.openBox('expertStatsBox');
      await statsBox.clear(); // Clear entire box instead of just one key
      print('Completely cleared cached data for fresh calculation');
    } catch (e) {
      print('Error clearing cache: $e');
    }
  }

  Future<void> _loadExpertStats() async {
    // Force clear cache to get fresh calculation
    await _clearCache();

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        setState(() => _isOffline = true);
        return;
      }

      // Get expert name
      final userBox = await Hive.openBox('userBox');
      final userProfile = userBox.get('userProfile');
      final expertName = userProfile?['fullName'] ?? 'Expert';

      // Try to load from Firestore first
      try {
        // Count completed reviews for this expert
        final completedQuery =
            await FirebaseFirestore.instance
                .collection('scan_requests')
                .where('expertUid', isEqualTo: user.uid)
                .where('status', whereIn: ['completed', 'reviewed'])
                .get();

        // Count pending requests available for this expert (either assigned or unassigned)
        final pendingQuery =
            await FirebaseFirestore.instance
                .collection('scan_requests')
                .where('status', whereIn: ['pending', 'pending_review'])
                .get();

        // Filter to show requests that are either assigned to this expert OR unassigned
        final pendingDocs =
            pendingQuery.docs.where((doc) {
              final data = doc.data();
              final expertUid = data['expertUid'];
              // Show if assigned to this expert OR if no expert assigned yet
              return expertUid == null || expertUid == user.uid;
            }).toList();

        // Calculate average response time
        double totalResponseTime = 0.0;
        int validReviews = 0;
        List<Map<String, dynamic>> recentReviews = [];

        for (var doc in completedQuery.docs) {
          final data = doc.data();
          final submittedAt = data['submittedAt'];
          final reviewedAt = data['reviewedAt'];

          if (submittedAt != null && reviewedAt != null) {
            try {
              print('Raw submittedAt: $submittedAt');
              print('Raw reviewedAt: $reviewedAt');

              final submitted = DateTime.parse(submittedAt);
              final reviewed = DateTime.parse(reviewedAt);

              // Debug: Print the actual times
              print('Submitted: $submitted');
              print('Reviewed: $reviewed');

              final difference = reviewed.difference(submitted);
              print(
                'Raw difference: ${difference.inMilliseconds} milliseconds',
              );
              print('Raw difference: ${difference.inMinutes} minutes');

              final responseTime =
                  difference.inMilliseconds.toDouble() /
                  (1000 * 60 * 60); // Convert ms to hours

              // Debug: Print the calculated response time
              print('Calculated response time: $responseTime hours');

              if (responseTime >= 0) {
                totalResponseTime += responseTime;
                validReviews++;
                print(
                  'Added to calculation - Total: $totalResponseTime, Count: $validReviews',
                );

                // Store recent reviews for graph
                recentReviews.add({
                  'date': reviewed,
                  'responseTime': responseTime,
                  'disease':
                      data['diseaseSummary']?[0]?['disease'] ?? 'Unknown',
                });
              }
            } catch (e) {
              print('Error parsing dates: $e');
            }
          }
        }

        // Sort recent reviews by date (latest first) and take last 7
        recentReviews.sort((a, b) => b['date'].compareTo(a['date']));
        recentReviews = recentReviews.take(7).toList();

        // Cache the data for offline access
        final statsData = {
          'expertName': expertName,
          'totalCompleted': completedQuery.docs.length,
          'pendingRequests': pendingQuery.docs.length,
          'averageResponseTime':
              validReviews > 0 ? (totalResponseTime / validReviews) : 0.0,
          'recentReviews': recentReviews,
          'lastUpdated': DateTime.now().toIso8601String(),
        };

        // Debug: Print the calculation details
        print('Total response time: $totalResponseTime hours');
        print('Valid reviews count: $validReviews');
        print('Calculated average: ${totalResponseTime / validReviews} hours');

        // Save to Hive for offline access
        final statsBox = await Hive.openBox('expertStatsBox');
        await statsBox.put('expertStats', statsData);

        setState(() {
          _expertName = expertName;
          _totalCompleted = completedQuery.docs.length;
          _pendingRequests = pendingDocs.length;
          _averageResponseTime =
              validReviews > 0 ? (totalResponseTime / validReviews) : 0.0;
          _recentReviews = recentReviews;
          _isOffline = false;
        });
      } catch (e) {
        print('Error loading from Firestore: $e');
        // Fallback to cached data
        await _loadCachedStats();
      }
    } catch (e) {
      print('Error loading expert stats: $e');
      // Fallback to cached data
      await _loadCachedStats();
    }
  }

  Future<void> _loadCachedStats() async {
    try {
      final statsBox = await Hive.openBox('expertStatsBox');
      final cachedData = statsBox.get('expertStats');

      if (cachedData != null) {
        setState(() {
          _expertName = cachedData['expertName'] ?? 'Expert';
          _totalCompleted = cachedData['totalCompleted'] ?? 0;
          _pendingRequests = cachedData['pendingRequests'] ?? 0;
          _averageResponseTime = cachedData['averageResponseTime'] ?? 0.0;
          _recentReviews = List<Map<String, dynamic>>.from(
            cachedData['recentReviews'] ?? [],
          );
          _isOffline = true;
        });
      }
    } catch (e) {
      print('Error loading cached stats: $e');
    }
  }

  void _updateStatsFromStream(List<QueryDocumentSnapshot> docs) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      // Get expert name
      final userBox = await Hive.openBox('userBox');
      final userProfile = userBox.get('userProfile');
      final expertName = userProfile?['fullName'] ?? 'Expert';

      // Filter data from stream for this expert
      final completedDocs =
          docs.where((doc) {
            final data = doc.data() as Map<String, dynamic>;
            return (data['status'] == 'completed' ||
                    data['status'] == 'reviewed') &&
                (data['expertUid'] == user.uid);
          }).toList();

      final pendingDocs =
          docs.where((doc) {
            final data = doc.data() as Map<String, dynamic>;
            final expertUid = data['expertUid'];
            // Show if assigned to this expert OR if no expert assigned yet
            return (data['status'] == 'pending' ||
                    data['status'] == 'pending_review') &&
                (expertUid == null || expertUid == user.uid);
          }).toList();

      // Debug logging
      print('Total docs in stream: ${docs.length}');
      print('Completed docs for expert: ${completedDocs.length}');
      print('Pending docs for expert: ${pendingDocs.length}');
      print('Current expert UID: ${user.uid}');

      // Additional debug for pending requests
      final allPending =
          docs.where((doc) {
            final data = doc.data() as Map<String, dynamic>;
            return data['status'] == 'pending' ||
                data['status'] == 'pending_review';
          }).toList();
      print('Total pending requests in system: ${allPending.length}');
      for (var doc in allPending.take(3)) {
        final data = doc.data() as Map<String, dynamic>;
        print(
          'Pending request - expertUid: ${data['expertUid']}, status: ${data['status']}',
        );
      }

      // Update notification count if pending requests changed
      if (_lastPendingCount != pendingDocs.length) {
        _updateNotificationCount(pendingDocs.length);
        _lastPendingCount = pendingDocs.length;
      }

      // Calculate average response time using fixed logic
      double totalResponseTime = 0.0;
      int validReviews = 0;
      List<Map<String, dynamic>> recentReviews = [];

      for (var doc in completedDocs) {
        final data = doc.data() as Map<String, dynamic>;
        final submittedAt = data['submittedAt'];
        final reviewedAt = data['reviewedAt'];

        if (submittedAt != null && reviewedAt != null) {
          try {
            final submitted = DateTime.parse(submittedAt);
            final reviewed = DateTime.parse(reviewedAt);
            final difference = reviewed.difference(submitted);
            final responseTime =
                difference.inMilliseconds.toDouble() / (1000 * 60 * 60);

            if (responseTime >= 0) {
              totalResponseTime += responseTime;
              validReviews++;

              recentReviews.add({
                'date': reviewed,
                'responseTime': responseTime,
                'disease': data['diseaseSummary']?[0]?['disease'] ?? 'Unknown',
              });
            }
          } catch (e) {
            print('Error parsing dates: $e');
          }
        }
      }

      // Sort recent reviews by date (latest first) and take last 7
      recentReviews.sort((a, b) => b['date'].compareTo(a['date']));
      recentReviews = recentReviews.take(7).toList();

      // Cache the data for offline access
      final statsData = {
        'expertName': expertName,
        'totalCompleted': completedDocs.length,
        'pendingRequests': pendingDocs.length,
        'averageResponseTime':
            validReviews > 0 ? (totalResponseTime / validReviews) : 0.0,
        'recentReviews': recentReviews,
        'lastUpdated': DateTime.now().toIso8601String(),
      };

      // Save to Hive for offline access
      final statsBox = await Hive.openBox('expertStatsBox');
      await statsBox.put('expertStats', statsData);

      setState(() {
        _expertName = expertName;
        _totalCompleted = completedDocs.length;
        _pendingRequests = pendingDocs.length;
        _averageResponseTime =
            validReviews > 0 ? (totalResponseTime / validReviews) : 0.0;
        _recentReviews = recentReviews;
        _isOffline = false;
      });
    } catch (e) {
      print('Error updating stats from stream: $e');
    }
  }

  // Helper function to format response time in a user-friendly way
  String _formatResponseTime(double hours) {
    if (hours < 1) {
      final minutes = (hours * 60).round();
      return '$minutes minute${minutes == 1 ? '' : 's'}';
    } else if (hours < 24) {
      if (hours == hours.round()) {
        return '${hours.round()} hour${hours.round() == 1 ? '' : 's'}';
      } else {
        final wholeHours = hours.floor();
        final minutes = ((hours - wholeHours) * 60).round();
        if (minutes == 0) {
          return '${wholeHours} hour${wholeHours == 1 ? '' : 's'}';
        } else {
          return '${wholeHours}h ${minutes}m';
        }
      }
    } else {
      final days = (hours / 24).floor();
      final remainingHours = hours % 24;
      if (remainingHours == 0) {
        return '$days day${days == 1 ? '' : 's'}';
      } else {
        return '$days day${days == 1 ? '' : 's'} ${remainingHours.round()}h';
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream:
          FirebaseFirestore.instance
              .collection('scan_requests')
              .where(
                'status',
                whereIn: ['completed', 'reviewed', 'pending', 'pending_review'],
              )
              .snapshots(),
      builder: (context, snapshot) {
        // Update stats when stream data changes
        if (snapshot.hasData) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _updateStatsFromStream(snapshot.data!.docs);
          });
        }

        return Scaffold(
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Offline indicator banner
                if (_isOffline)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      vertical: 8,
                      horizontal: 16,
                    ),
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: Colors.orange.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.orange.withOpacity(0.3)),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.wifi_off, color: Colors.orange, size: 16),
                        const SizedBox(width: 8),
                        Text(
                          'Offline mode - Showing cached data',
                          style: TextStyle(
                            color: Colors.orange[700],
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                // Welcome Section
                Card(
                  color: Colors.green[50],
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.person,
                              color: Colors.green[700],
                              size: 24,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'Welcome back, $_expertName!',
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.green[700],
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Ready to review some requests?',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.green[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // Statistics Section
                Text(
                  'Your Statistics',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[800],
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () {
                          // Navigate to requests tab and show completed requests
                          if (context.mounted) {
                            final dashboard =
                                context
                                    .findAncestorStateOfType<
                                      _ExpertDashboardState
                                    >();
                            dashboard?._navigateToRequests(
                              1,
                            ); // Show completed tab
                          }
                        },
                        child: Card(
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              children: [
                                Icon(
                                  Icons.check_circle,
                                  color: Colors.green,
                                  size: 32,
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  '$_totalCompleted',
                                  style: const TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const Text(
                                  'Completed Reviews',
                                  style: TextStyle(fontSize: 12),
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: GestureDetector(
                        onTap: () {
                          // Navigate to requests tab and show pending requests
                          if (context.mounted) {
                            final dashboard =
                                context
                                    .findAncestorStateOfType<
                                      _ExpertDashboardState
                                    >();
                            dashboard?._navigateToRequests(
                              0,
                            ); // Show pending tab
                          }
                        },
                        child: Card(
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              children: [
                                Icon(
                                  Icons.pending,
                                  color: Colors.orange,
                                  size: 32,
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  '$_pendingRequests',
                                  style: const TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const Text(
                                  'Pending Requests',
                                  style: TextStyle(fontSize: 12),
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // Response Time Analysis Section
                Text(
                  'Response Time Analysis',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[800],
                  ),
                ),
                const SizedBox(height: 12),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.timer, color: Colors.blue, size: 20),
                            const SizedBox(width: 8),
                            Text(
                              'Average Response Time',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: Colors.grey[800],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '${_formatResponseTime(_averageResponseTime)}',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.blue[700],
                          ),
                        ),
                        const SizedBox(height: 16),
                        if (_recentReviews.isNotEmpty) ...[
                          Text(
                            'Recent Response Times',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Colors.grey[700],
                            ),
                          ),
                          const SizedBox(height: 12),
                          SizedBox(
                            height: 200,
                            child: LineChart(
                              LineChartData(
                                gridData: FlGridData(show: true),
                                titlesData: FlTitlesData(
                                  leftTitles: AxisTitles(
                                    sideTitles: SideTitles(
                                      showTitles: true,
                                      reservedSize: 40,
                                      getTitlesWidget: (value, meta) {
                                        return Text(
                                          '${value.toInt()}h',
                                          style: const TextStyle(fontSize: 10),
                                        );
                                      },
                                    ),
                                  ),
                                  bottomTitles: AxisTitles(
                                    sideTitles: SideTitles(
                                      showTitles: true,
                                      reservedSize: 30,
                                      getTitlesWidget: (value, meta) {
                                        if (value.toInt() <
                                            _recentReviews.length) {
                                          final review =
                                              _recentReviews[value.toInt()];
                                          final date =
                                              review['date'] as DateTime;
                                          return Padding(
                                            padding: const EdgeInsets.only(
                                              top: 8,
                                            ),
                                            child: Text(
                                              '${date.day}/${date.month}',
                                              style: const TextStyle(
                                                fontSize: 10,
                                              ),
                                            ),
                                          );
                                        }
                                        return const Text('');
                                      },
                                    ),
                                  ),
                                  rightTitles: AxisTitles(
                                    sideTitles: SideTitles(showTitles: false),
                                  ),
                                  topTitles: AxisTitles(
                                    sideTitles: SideTitles(showTitles: false),
                                  ),
                                ),
                                borderData: FlBorderData(show: true),
                                lineBarsData: [
                                  LineChartBarData(
                                    spots:
                                        _recentReviews.asMap().entries.map((
                                          entry,
                                        ) {
                                          return FlSpot(
                                            entry.key.toDouble(),
                                            entry.value['responseTime']
                                                .toDouble(),
                                          );
                                        }).toList(),
                                    isCurved: true,
                                    color: Colors.blue,
                                    barWidth: 3,
                                    dotData: FlDotData(show: true),
                                    belowBarData: BarAreaData(
                                      show: true,
                                      color: Colors.blue.withOpacity(0.1),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ] else ...[
                          Container(
                            height: 100,
                            alignment: Alignment.center,
                            child: Text(
                              'No recent reviews to display',
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 14,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
