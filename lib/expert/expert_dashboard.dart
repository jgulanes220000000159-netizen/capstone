import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'scan_request_list.dart';
import 'disease_editor.dart';
import 'expert_profile.dart';
// import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:hive/hive.dart';
import 'package:fl_chart/fl_chart.dart';
import 'dart:async'; // Added for StreamSubscription
import 'package:intl/intl.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

class ExpertDashboard extends StatefulWidget {
  const ExpertDashboard({Key? key}) : super(key: key);

  @override
  State<ExpertDashboard> createState() => _ExpertDashboardState();
}

class _ExpertDashboardState extends State<ExpertDashboard> {
  int _selectedIndex = 0;
  int _requestsInitialTab = 0; // 0 for pending, 1 for completed
  int _pendingNotifications = 0; // Track pending notifications
  Set<String> _lastPendingIds = <String>{};
  StreamSubscription? _seenPendingWatch;

  List<Widget> _pages = [];

  @override
  void initState() {
    super.initState();
    _updatePages();
    // Start live unseen pending subscription; do not preload stale counts
    _subscribePendingUnseen();
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
  }

  // Load notification count from Hive
  // Removed: count is set solely by unseen-pending subscription

  // Subscribe to pending unseen (ids not marked as seen locally)
  void _subscribePendingUnseen() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;
      FirebaseFirestore.instance.collection('scan_requests').snapshots().listen(
        (snapshot) async {
          final pendingIds = <String>{};
          for (final doc in snapshot.docs) {
            final data = doc.data();
            final status = data['status'];
            final expertUid = data['expertUid'];
            final isPending = status == 'pending' || status == 'pending_review';
            final isUnassigned =
                expertUid == null || expertUid.toString().isEmpty;
            final isAssignedToMe = expertUid == user.uid;
            if (isPending && (isUnassigned || isAssignedToMe)) {
              final id = (data['id'] ?? data['requestId'] ?? doc.id).toString();
              if (id.isNotEmpty) pendingIds.add(id);
            }
          }
          _lastPendingIds = pendingIds;
          // Initialize baseline once so historical backlog doesn't count as new
          final box = await Hive.openBox('expertRequestsSeenBox');
          final bool baselineSet =
              box.get('pendingBaselineSet', defaultValue: false) as bool;
          final savedList = box.get('seenPendingIds', defaultValue: []);
          if (!baselineSet && (savedList is List ? savedList.isEmpty : true)) {
            await box.put('seenPendingIds', pendingIds.toList());
            await box.put('pendingBaselineSet', true);
          }
          int unseen = await _computePendingUnseen();
          _updateNotificationCount(unseen);
          // Watch local seen set for immediate updates
          _seenPendingWatch?.cancel();
          _seenPendingWatch = box.watch(key: 'seenPendingIds').listen((
            _,
          ) async {
            int unseen2 = await _computePendingUnseen();
            _updateNotificationCount(unseen2);
          });
        },
      );
    } catch (_) {}
  }

  Future<int> _computePendingUnseen() async {
    try {
      final box = await Hive.openBox('expertRequestsSeenBox');
      final saved = box.get('seenPendingIds', defaultValue: []);
      final seen =
          saved is List ? saved.map((e) => e.toString()).toSet() : <String>{};
      return _lastPendingIds.where((id) => !seen.contains(id)).length;
    } catch (_) {
      return _lastPendingIds.length;
    }
  }

  void _updateNotificationCount(int count) {
    if (!mounted) return;
    setState(() {
      _pendingNotifications = count;
    });
  }

  // Removed: no longer persisting badge count

  // Clear notifications when Requests tab is clicked
  // Removed: do not clear on navigation; clearing happens per-card open

  void _navigateToRequests(int tabIndex) {
    setState(() {
      _requestsInitialTab = tabIndex;
      _selectedIndex = 1; // Switch to Requests tab
      _updatePages();
    });
    // Do not auto-clear; Clear when opening individual pending card
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
      body: Stack(
        children: [
          // Main content
          Column(
            children: [
              SafeArea(
                bottom: false,
                child: SizedBox(
                  height: 64, // Height of the header + padding
                ),
              ),
              Expanded(
                child: SafeArea(
                  top: false,
                  child: Padding(
                    padding: const EdgeInsets.only(top: 15),
                    child:
                        _pages.isNotEmpty
                            ? _pages[_selectedIndex]
                            : const Center(child: CircularProgressIndicator()),
                  ),
                ),
              ),
            ],
          ),
          // Green header with shadow on top
          SafeArea(
            bottom: false,
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.green,
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(20),
                  bottomRight: Radius.circular(20),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 12,
                    offset: const Offset(0, 6),
                    spreadRadius: 1,
                  ),
                ],
              ),
              child: Row(
                children: [
                  // Logo with circular container (matching farmer side)
                  Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white,
                    ),
                    padding: const EdgeInsets.all(8),
                    child: Image.asset(
                      'assets/logo.png',
                      width: 30,
                      height: 30,
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Title only (no subtitle)
                  Expanded(
                    child: Text(
                      getTitle(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  // Expert Panel badge
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Colors.white.withOpacity(0.3),
                        width: 1,
                      ),
                    ),
                    child: Text(
                      'Expert Panel',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 12,
              offset: const Offset(0, -4),
              spreadRadius: 1,
            ),
          ],
        ),
        child: BottomNavigationBar(
          currentIndex: _selectedIndex,
          onTap: _onItemTapped,
          selectedItemColor: Colors.green,
          type: BottomNavigationBarType.fixed,
          elevation: 0,
          items: [
            const BottomNavigationBarItem(
              icon: Icon(Icons.home),
              label: 'Home',
            ),
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
  // double _averageResponseTime = 0.0; // superseded by filtered average
  List<Map<String, dynamic>> _recentReviews = [];
  bool _isOffline = false;
  bool _isLoading = true;
  StreamSubscription<QuerySnapshot>? _streamSubscription;

  // Time range state for the response time chart (0: Last 7 Days, 1: Monthly, 2: Custom)
  int _selectedRangeIndex = 0;
  DateTime? _customStartDate;
  DateTime? _customEndDate;
  int? _monthlyYear;
  int? _monthlyMonth;
  int? _lastStreamDocsCount;

  // Filter reviews according to the selected range
  List<Map<String, dynamic>> _filterReviewsForRange() {
    if (_recentReviews.isEmpty) return const [];
    final today = DateTime.now();
    final todayOnly = DateTime(today.year, today.month, today.day);
    if (_selectedRangeIndex == 0) {
      final start7 = todayOnly.subtract(const Duration(days: 6));
      return _recentReviews.where((r) {
          final d = r['date'] as DateTime?;
          if (d == null) return false;
          final dayOnly = DateTime(d.year, d.month, d.day);
          return !dayOnly.isBefore(start7) && !dayOnly.isAfter(todayOnly);
        }).toList()
        ..sort(
          (a, b) => (a['date'] as DateTime).compareTo(b['date'] as DateTime),
        );
    }
    if (_selectedRangeIndex == 1 &&
        _monthlyYear != null &&
        _monthlyMonth != null) {
      // Monthly filter
      final startOfMonth = DateTime(_monthlyYear!, _monthlyMonth!, 1);
      final endOfMonth = DateTime(_monthlyYear!, _monthlyMonth! + 1, 0);
      return _recentReviews.where((r) {
          final d = r['date'] as DateTime?;
          if (d == null) return false;
          final dayOnly = DateTime(d.year, d.month, d.day);
          return !dayOnly.isBefore(startOfMonth) &&
              !dayOnly.isAfter(endOfMonth);
        }).toList()
        ..sort(
          (a, b) => (a['date'] as DateTime).compareTo(b['date'] as DateTime),
        );
    }
    if (_selectedRangeIndex == 2 &&
        _customStartDate != null &&
        _customEndDate != null) {
      // Custom range filter
      final s = DateTime(
        _customStartDate!.year,
        _customStartDate!.month,
        _customStartDate!.day,
      );
      final e = DateTime(
        _customEndDate!.year,
        _customEndDate!.month,
        _customEndDate!.day,
      );
      return _recentReviews.where((r) {
          final d = r['date'] as DateTime?;
          if (d == null) return false;
          final dayOnly = DateTime(d.year, d.month, d.day);
          return !dayOnly.isBefore(s) && !dayOnly.isAfter(e);
        }).toList()
        ..sort(
          (a, b) => (a['date'] as DateTime).compareTo(b['date'] as DateTime),
        );
    }
    // Fallback: return all sorted
    return List<Map<String, dynamic>>.from(
      _recentReviews,
    )..sort((a, b) => (a['date'] as DateTime).compareTo(b['date'] as DateTime));
  }

  double _filteredAverageHours() {
    final filtered = _filterReviewsForRange();
    if (filtered.isEmpty) return 0.0;
    final total = filtered.fold<double>(
      0.0,
      (sum, r) => sum + ((r['responseTime'] as num?)?.toDouble() ?? 0.0),
    );
    return total / filtered.length;
  }

  // Debug tracking variables
  // int _lastPendingCount = 0; // removed: do not override badge from here
  // int _lastCompletedCount = 0; // unused

  @override
  void initState() {
    super.initState();
    _loadCachedDataFirst(); // Load cached data immediately for instant display
    _loadExpertStats();
    _loadRangePrefs();
  }

  @override
  void dispose() {
    _streamSubscription?.cancel();
    super.dispose();
  }

  // Check network connectivity
  Future<bool> _checkNetworkConnectivity() async {
    try {
      final connectivityResult = await Connectivity().checkConnectivity();
      return connectivityResult == ConnectivityResult.wifi ||
          connectivityResult == ConnectivityResult.mobile ||
          connectivityResult == ConnectivityResult.ethernet;
    } catch (e) {
      return false;
    }
  }

  // Load cached data first for immediate display
  Future<void> _loadCachedDataFirst() async {
    try {
      final statsBox = await Hive.openBox('expertStatsBox');
      final cachedData = statsBox.get('expertStats');

      if (cachedData != null && mounted) {
        setState(() {
          _expertName = cachedData['expertName'] ?? 'Expert';
          _totalCompleted = cachedData['totalCompleted'] ?? 0;
          _pendingRequests = cachedData['pendingRequests'] ?? 0;

          // Parse cached reviews and ensure dates are DateTime objects
          final cachedReviews = List<Map<String, dynamic>>.from(
            cachedData['recentReviews'] ?? [],
          );
          _recentReviews =
              cachedReviews.map((review) {
                final dateValue = review['date'];
                DateTime? parsedDate;

                if (dateValue is DateTime) {
                  parsedDate = dateValue;
                } else if (dateValue is String) {
                  try {
                    parsedDate = DateTime.parse(dateValue);
                  } catch (e) {
                    parsedDate = null;
                  }
                }

                return {
                  'date': parsedDate,
                  'responseTime': review['responseTime'],
                  'disease': review['disease'],
                };
              }).toList();

          _isLoading = false; // Show cached data immediately
        });
      } else if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // Clean up old cached data to prevent memory buildup
  // Removed unused _cleanupOldCache (was only used for debugging)

  // Force clear cache to get fresh calculation
  Future<void> _clearCache() async {
    try {
      final statsBox = await Hive.openBox('expertStatsBox');
      await statsBox.clear(); // Clear entire box instead of just one key
      // print('Completely cleared cached data for fresh calculation');
    } catch (e) {
      // print('Error clearing cache: $e');
    }
  }

  Future<void> _loadRangePrefs() async {
    try {
      final box = await Hive.openBox('expertFilterBox');
      final idx = box.get('selectedRangeIndex', defaultValue: 0);
      final startStr = box.get('customStartDate') as String?;
      final endStr = box.get('customEndDate') as String?;
      final y = box.get('monthlyYear');
      final m = box.get('monthlyMonth');
      setState(() {
        _selectedRangeIndex = (idx is int && idx >= 0 && idx <= 2) ? idx : 0;
        _customStartDate =
            startStr != null ? DateTime.tryParse(startStr) : null;
        _customEndDate = endStr != null ? DateTime.tryParse(endStr) : null;
        if (y is int && m is int) {
          _monthlyYear = y;
          _monthlyMonth = m;
        }
      });
    } catch (_) {}
  }

  Future<void> _saveRangeIndex(int idx) async {
    try {
      final box = await Hive.openBox('expertFilterBox');
      await box.put('selectedRangeIndex', idx);
    } catch (_) {}
  }

  Future<void> _saveCustomRange(DateTime start, DateTime end) async {
    try {
      final box = await Hive.openBox('expertFilterBox');
      await box.put(
        'customStartDate',
        DateTime(start.year, start.month, start.day).toIso8601String(),
      );
      await box.put(
        'customEndDate',
        DateTime(end.year, end.month, end.day).toIso8601String(),
      );
    } catch (_) {}
  }

  Future<void> _saveMonthly(int year, int month) async {
    try {
      final box = await Hive.openBox('expertFilterBox');
      await box.put('monthlyYear', year);
      await box.put('monthlyMonth', month);
    } catch (_) {}
  }

  Future<DateTime?> _showMonthYearPicker({
    required BuildContext context,
    required DateTime initialDate,
    required DateTime firstDate,
    required DateTime lastDate,
  }) async {
    DateTime selectedDate = initialDate;

    return await showDialog<DateTime>(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('Select Month and Year'),
              content: SizedBox(
                width: 300,
                height: 400,
                child: Column(
                  children: [
                    // Year selector
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.arrow_back_ios),
                          tooltip: '', // Disable tooltip
                          onPressed:
                              selectedDate.year > firstDate.year
                                  ? () {
                                    setState(() {
                                      selectedDate = DateTime(
                                        selectedDate.year - 1,
                                        selectedDate.month,
                                      );
                                    });
                                  }
                                  : null,
                        ),
                        Text(
                          '${selectedDate.year}',
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.arrow_forward_ios),
                          tooltip: '', // Disable tooltip
                          onPressed:
                              selectedDate.year < lastDate.year
                                  ? () {
                                    setState(() {
                                      selectedDate = DateTime(
                                        selectedDate.year + 1,
                                        selectedDate.month,
                                      );
                                    });
                                  }
                                  : null,
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    // Month grid
                    Expanded(
                      child: GridView.builder(
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 3,
                              crossAxisSpacing: 8,
                              mainAxisSpacing: 8,
                              childAspectRatio: 2,
                            ),
                        itemCount: 12,
                        itemBuilder: (context, index) {
                          final month = index + 1;
                          final isSelected = selectedDate.month == month;
                          final monthDate = DateTime(selectedDate.year, month);
                          final isDisabled =
                              monthDate.isBefore(
                                DateTime(firstDate.year, firstDate.month),
                              ) ||
                              monthDate.isAfter(
                                DateTime(lastDate.year, lastDate.month),
                              );

                          const monthNames = [
                            'Jan',
                            'Feb',
                            'Mar',
                            'Apr',
                            'May',
                            'Jun',
                            'Jul',
                            'Aug',
                            'Sep',
                            'Oct',
                            'Nov',
                            'Dec',
                          ];

                          return InkWell(
                            onTap:
                                isDisabled
                                    ? null
                                    : () {
                                      setState(() {
                                        selectedDate = DateTime(
                                          selectedDate.year,
                                          month,
                                        );
                                      });
                                    },
                            child: Container(
                              decoration: BoxDecoration(
                                color:
                                    isSelected
                                        ? const Color(0xFF2D7204)
                                        : isDisabled
                                        ? Colors.grey.shade200
                                        : Colors.grey.shade100,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color:
                                      isSelected
                                          ? const Color(0xFF2D7204)
                                          : Colors.grey.shade300,
                                  width: isSelected ? 2 : 1,
                                ),
                              ),
                              alignment: Alignment.center,
                              child: Text(
                                monthNames[index],
                                style: TextStyle(
                                  color:
                                      isDisabled
                                          ? Colors.grey.shade400
                                          : isSelected
                                          ? Colors.white
                                          : Colors.black87,
                                  fontWeight:
                                      isSelected
                                          ? FontWeight.bold
                                          : FontWeight.normal,
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, null),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.pop(context, selectedDate),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2D7204),
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('OK'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _pickCustomRange() async {
    final initialRange =
        _customStartDate != null && _customEndDate != null
            ? DateTimeRange(start: _customStartDate!, end: _customEndDate!)
            : DateTimeRange(
              start: DateTime.now().subtract(const Duration(days: 6)),
              end: DateTime.now(),
            );
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(1970),
      lastDate: DateTime.now(),
      initialDateRange: initialRange,
      locale: const Locale('en'),
    );
    if (picked != null) {
      setState(() {
        _customStartDate = picked.start;
        _customEndDate = picked.end;
        _selectedRangeIndex = 2;
      });
      await _saveRangeIndex(2);
      await _saveCustomRange(picked.start, picked.end);
    }
  }

  Future<void> _loadExpertStats() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        setState(() => _isOffline = true);
        return;
      }

      // Check connectivity first
      bool isOnline = await _checkNetworkConnectivity();
      if (!isOnline) {
        // Load cached data when offline
        await _loadCachedStats();
        setState(() => _isOffline = true);
        return;
      }

      // Only clear cache when we're sure we can get fresh data
      await _clearCache();

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
              // Debug removed

              final submitted = DateTime.parse(submittedAt);
              final reviewed = DateTime.parse(reviewedAt);

              // Debug: Print the actual times
              // Debug removed

              final difference = reviewed.difference(submitted);
              // Debug removed

              final responseTime =
                  difference.inMilliseconds.toDouble() /
                  (1000 * 60 * 60); // Convert ms to hours

              // Debug: Print the calculated response time
              // Debug removed

              if (responseTime >= 0) {
                totalResponseTime += responseTime;
                validReviews++;
                // Debug removed

                // Store recent reviews for graph
                recentReviews.add({
                  'date': reviewed,
                  'responseTime': responseTime,
                  'disease':
                      data['diseaseSummary']?[0]?['disease'] ?? 'Unknown',
                });
              }
            } catch (e) {
              // print('Error parsing dates: $e');
            }
          }
        }

        // Sort recent reviews by date (latest first)
        recentReviews.sort((a, b) => b['date'].compareTo(a['date']));

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
        // Debug removed

        // Save to Hive for offline access
        final statsBox = await Hive.openBox('expertStatsBox');
        await statsBox.put('expertStats', statsData);

        setState(() {
          _expertName = expertName;
          _totalCompleted = completedQuery.docs.length;
          _pendingRequests = pendingDocs.length;
          // Keep computing average for caching/debug, but UI uses filtered average
          _recentReviews = recentReviews;
          _isOffline = false;
        });
      } catch (e) {
        // print('Error loading from Firestore: $e');
        // Fallback to cached data
        await _loadCachedStats();
      }
    } catch (e) {
      // print('Error loading expert stats: $e');
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

          // Parse cached reviews and ensure dates are DateTime objects
          final cachedReviews = List<Map<String, dynamic>>.from(
            cachedData['recentReviews'] ?? [],
          );
          _recentReviews =
              cachedReviews.map((review) {
                final dateValue = review['date'];
                DateTime? parsedDate;

                if (dateValue is DateTime) {
                  parsedDate = dateValue;
                } else if (dateValue is String) {
                  try {
                    parsedDate = DateTime.parse(dateValue);
                  } catch (e) {
                    parsedDate = null;
                  }
                }

                return {
                  'date': parsedDate,
                  'responseTime': review['responseTime'],
                  'disease': review['disease'],
                };
              }).toList();

          _isOffline = true;
        });
      }
    } catch (e) {
      // print('Error loading cached stats: $e');
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
      // Debug removed

      // Additional debug for pending requests
      final allPending =
          docs
              .where(
                (doc) =>
                    ((doc.data() as Map<String, dynamic>)['status'] ==
                            'pending' ||
                        (doc.data() as Map<String, dynamic>)['status'] ==
                            'pending_review'),
              )
              .toList();
      // print('Total pending requests in system: ${allPending.length}');
      for (var _ in allPending.take(3)) {
        // print('Pending request - expertUid: ...');
      }

      // Do not update the bottom nav badge here. Badge is managed in
      // the parent dashboard via unseen-pending logic only.

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
            // print('Error parsing dates: $e');
          }
        }
      }

      // Sort recent reviews by date (latest first)
      recentReviews.sort((a, b) => b['date'].compareTo(a['date']));

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
        // Keep computing average for caching/debug, but UI uses filtered average
        _recentReviews = recentReviews;
        _isOffline = false;
      });
    } catch (e) {
      // print('Error updating stats from stream: $e');
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

  // Helper function to get performance feedback based on response time
  Map<String, dynamic> _getPerformanceFeedback(double hours) {
    if (hours == 0) {
      return {
        'message': 'No data available',
        'icon': Icons.info_outline,
        'color': Colors.grey,
      };
    } else if (hours < 6) {
      return {
        'message': 'Excellent! Lightning-fast response time',
        'icon': Icons.emoji_events,
        'color': Colors.green[700],
      };
    } else if (hours < 24) {
      return {
        'message': 'Great! Responding within the same day',
        'icon': Icons.thumb_up,
        'color': Colors.green[600],
      };
    } else if (hours < 48) {
      return {
        'message': 'Good response time, keep it up',
        'icon': Icons.check_circle_outline,
        'color': Colors.blue[600],
      };
    } else if (hours < 72) {
      return {
        'message': 'Room for improvement - try to respond faster',
        'icon': Icons.timeline,
        'color': Colors.orange[700],
      };
    } else {
      return {
        'message': 'Needs improvement - farmers expect faster responses',
        'icon': Icons.warning_amber_rounded,
        'color': Colors.red[600],
      };
    }
  }

  @override
  Widget build(BuildContext context) {
    // Show loading state initially
    if (_isLoading) {
      return const Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Loading dashboard...'),
            ],
          ),
        ),
      );
    }

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
        // Update stats when stream data changes (prevent tight loop)
        if (snapshot.hasData) {
          // Only update when the doc count changes; prevents constant re-calls
          final currentCount = snapshot.data!.docs.length;
          if (_lastStreamDocsCount != currentCount) {
            _lastStreamDocsCount = currentCount;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              _updateStatsFromStream(snapshot.data!.docs);
            });
          }
        } else if (snapshot.hasError) {
          // Handle stream errors by setting offline mode
          if (!_isOffline) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              setState(() => _isOffline = true);
            });
          }
        }

        return Scaffold(
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
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
                        // Time Range Filter at top
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.grey[50],
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: Colors.grey[300]!),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.calendar_today, size: 18),
                              const SizedBox(width: 10),
                              Expanded(
                                child: DropdownButton<int>(
                                  value: _selectedRangeIndex,
                                  isExpanded: true,
                                  underline: const SizedBox.shrink(),
                                  items: [
                                    const DropdownMenuItem(
                                      value: 0,
                                      child: Text('Last 7 Days'),
                                    ),
                                    DropdownMenuItem(
                                      value: 1,
                                      child: Text(
                                        _monthlyYear != null &&
                                                _monthlyMonth != null
                                            ? DateFormat(
                                              'MMMM yyyy',
                                              'en',
                                            ).format(
                                              DateTime(
                                                _monthlyYear!,
                                                _monthlyMonth!,
                                                1,
                                              ),
                                            )
                                            : 'Monthly',
                                      ),
                                    ),
                                    DropdownMenuItem(
                                      value: 2,
                                      child: Text(
                                        _customStartDate != null &&
                                                _customEndDate != null
                                            ? 'Custom: ${DateFormat('MMM d', 'en').format(_customStartDate!)} – ${DateFormat('MMM d', 'en').format(_customEndDate!)}'
                                            : 'Custom',
                                      ),
                                    ),
                                  ],
                                  onChanged: (i) async {
                                    if (i == null) return;
                                    if (i == 1) {
                                      // Show custom month-year picker
                                      final now = DateTime.now();
                                      final picked = await _showMonthYearPicker(
                                        context: context,
                                        initialDate: DateTime(
                                          _monthlyYear ?? now.year,
                                          _monthlyMonth ?? now.month,
                                          1,
                                        ),
                                        firstDate: DateTime(2020, 1),
                                        lastDate: DateTime(now.year, now.month),
                                      );
                                      if (picked != null) {
                                        setState(() {
                                          _monthlyYear = picked.year;
                                          _monthlyMonth = picked.month;
                                          _selectedRangeIndex = 1;
                                        });
                                        await _saveRangeIndex(1);
                                        await _saveMonthly(
                                          picked.year,
                                          picked.month,
                                        );
                                      }
                                    } else if (i == 2) {
                                      await _pickCustomRange();
                                    } else {
                                      setState(() => _selectedRangeIndex = 0);
                                      await _saveRangeIndex(0);
                                    }
                                  },
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        // Metrics Row
                        Row(
                          children: [
                            // Completed Reviews for timeframe
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Icon(
                                        Icons.check_circle,
                                        color: Colors.green,
                                        size: 20,
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          'Reviews in Period',
                                          style: TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w600,
                                            color: Colors.grey[800],
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    '${_filterReviewsForRange().length}',
                                    style: TextStyle(
                                      fontSize: 24,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.green[700],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 16),
                            // Average Response Time
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Icon(
                                        Icons.timer,
                                        color: Colors.blue,
                                        size: 20,
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          'Avg Response Time',
                                          style: TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w600,
                                            color: Colors.grey[800],
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    '${_formatResponseTime(_filteredAverageHours())}',
                                    style: TextStyle(
                                      fontSize: 24,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.blue[700],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        // Performance Feedback
                        Builder(
                          builder: (context) {
                            final feedback = _getPerformanceFeedback(
                              _filteredAverageHours(),
                            );
                            return Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: (feedback['color'] as Color).withOpacity(
                                  0.1,
                                ),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: (feedback['color'] as Color)
                                      .withOpacity(0.3),
                                  width: 1,
                                ),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    feedback['icon'] as IconData,
                                    color: feedback['color'] as Color,
                                    size: 18,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      feedback['message'] as String,
                                      style: TextStyle(
                                        color: feedback['color'] as Color,
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                        const SizedBox(height: 16),
                        if (_recentReviews.isNotEmpty) ...[
                          Text(
                            'Response Time Trend',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Colors.grey[700],
                            ),
                          ),
                          const SizedBox(height: 12),
                          SizedBox(
                            height: 200,
                            child: Builder(
                              builder: (context) {
                                // Filter reviews per selected range
                                DateTime today = DateTime.now();
                                DateTime start7 = DateTime(
                                  today.year,
                                  today.month,
                                  today.day,
                                ).subtract(const Duration(days: 6));
                                final List<Map<String, dynamic>> filtered =
                                    _recentReviews.where((r) {
                                        final d = r['date'] as DateTime?;
                                        if (d == null) return false;
                                        final dayOnly = DateTime(
                                          d.year,
                                          d.month,
                                          d.day,
                                        );
                                        if (_selectedRangeIndex == 0) {
                                          return !dayOnly.isBefore(start7) &&
                                              !dayOnly.isAfter(
                                                DateTime(
                                                  today.year,
                                                  today.month,
                                                  today.day,
                                                ),
                                              );
                                        }
                                        if (_selectedRangeIndex == 1 &&
                                            _monthlyYear != null &&
                                            _monthlyMonth != null) {
                                          // Monthly filter
                                          final startOfMonth = DateTime(
                                            _monthlyYear!,
                                            _monthlyMonth!,
                                            1,
                                          );
                                          final endOfMonth = DateTime(
                                            _monthlyYear!,
                                            _monthlyMonth! + 1,
                                            0,
                                          );
                                          return !dayOnly.isBefore(
                                                startOfMonth,
                                              ) &&
                                              !dayOnly.isAfter(endOfMonth);
                                        }
                                        if (_selectedRangeIndex == 2) {
                                          if (_customStartDate == null ||
                                              _customEndDate == null)
                                            return true;
                                          final s = DateTime(
                                            _customStartDate!.year,
                                            _customStartDate!.month,
                                            _customStartDate!.day,
                                          );
                                          final e = DateTime(
                                            _customEndDate!.year,
                                            _customEndDate!.month,
                                            _customEndDate!.day,
                                          );
                                          return !dayOnly.isBefore(s) &&
                                              !dayOnly.isAfter(e);
                                        }
                                        return true; // Fallback
                                      }).toList()
                                      ..sort(
                                        (a, b) => (a['date'] as DateTime)
                                            .compareTo(b['date'] as DateTime),
                                      );

                                final showBottomTitles =
                                    true; // Show dates for all ranges
                                // Find max value for better Y-axis scaling
                                final maxValue =
                                    filtered.isEmpty
                                        ? 100.0
                                        : filtered
                                            .map(
                                              (e) =>
                                                  (e['responseTime'] as num)
                                                      .toDouble(),
                                            )
                                            .reduce((a, b) => a > b ? a : b);
                                final yInterval =
                                    maxValue > 100
                                        ? 100.0
                                        : (maxValue > 50 ? 50.0 : 20.0);

                                return LineChart(
                                  LineChartData(
                                    lineTouchData: LineTouchData(
                                      enabled: true,
                                      touchTooltipData: LineTouchTooltipData(
                                        getTooltipItems: (touchedSpots) {
                                          return touchedSpots.map((spot) {
                                            final hours = spot.y;
                                            final index = spot.x.toInt();
                                            final date =
                                                filtered[index]['date']
                                                    as DateTime;
                                            return LineTooltipItem(
                                              '${_formatResponseTime(hours)}\n${date.day}/${date.month}/${date.year}',
                                              const TextStyle(
                                                color: Colors.white,
                                                fontWeight: FontWeight.bold,
                                                fontSize: 12,
                                              ),
                                            );
                                          }).toList();
                                        },
                                      ),
                                    ),
                                    gridData: FlGridData(
                                      show: true,
                                      drawVerticalLine: true,
                                      horizontalInterval: yInterval,
                                    ),
                                    titlesData: FlTitlesData(
                                      leftTitles: AxisTitles(
                                        sideTitles: SideTitles(
                                          showTitles: true,
                                          reservedSize: 45,
                                          interval: yInterval,
                                          getTitlesWidget: (value, meta) {
                                            // Only show labels at specific intervals
                                            if (value % yInterval != 0) {
                                              return const SizedBox.shrink();
                                            }
                                            return Text(
                                              '${value.toInt()}h',
                                              style: const TextStyle(
                                                fontSize: 10,
                                                color: Colors.black87,
                                              ),
                                            );
                                          },
                                        ),
                                      ),
                                      bottomTitles: AxisTitles(
                                        sideTitles: SideTitles(
                                          showTitles: showBottomTitles,
                                          reservedSize: 30,
                                          getTitlesWidget: (value, meta) {
                                            final idx = value.toInt();
                                            if (idx >= 0 &&
                                                idx < filtered.length) {
                                              final date =
                                                  filtered[idx]['date']
                                                      as DateTime;
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
                                            return const SizedBox.shrink();
                                          },
                                        ),
                                      ),
                                      rightTitles: AxisTitles(
                                        sideTitles: SideTitles(
                                          showTitles: false,
                                        ),
                                      ),
                                      topTitles: AxisTitles(
                                        sideTitles: SideTitles(
                                          showTitles: false,
                                        ),
                                      ),
                                    ),
                                    borderData: FlBorderData(show: true),
                                    lineBarsData: [
                                      LineChartBarData(
                                        spots:
                                            filtered
                                                .asMap()
                                                .entries
                                                .map(
                                                  (entry) => FlSpot(
                                                    entry.key.toDouble(),
                                                    (entry.value['responseTime']
                                                            as num)
                                                        .toDouble(),
                                                  ),
                                                )
                                                .toList(),
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
                                );
                              },
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
