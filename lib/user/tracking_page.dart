import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:intl/intl.dart';
import 'dart:io';
import 'package:fl_chart/fl_chart.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:rxdart/rxdart.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class TrackingPage extends StatefulWidget {
  const TrackingPage({Key? key}) : super(key: key);

  @override
  State<TrackingPage> createState() => _TrackingPageState();
}

class _TrackingPageState extends State<TrackingPage> {
  List<Map<String, dynamic>> _sessionScans = [];
  bool _isLoading = true;

  final List<Map<String, dynamic>> _timeRanges = [
    {'label': 'Show Everything', 'days': null},
    {'label': 'Last 7 Days', 'days': 7},
    {'label': 'Last 30 Days', 'days': 30},
    {'label': 'Last 60 Days', 'days': 60},
    {'label': 'Last 90 Days', 'days': 90},
    {'label': 'Last Year', 'days': 365},
  ];
  int _selectedRangeIndex = 1; // Default to Last 7 Days

  // Use the same color mapping as DetectionPainter
  static const Map<String, Color> _diseaseColors = {
    'anthracnose': Colors.orange,
    'backterial_blackspot': Colors.purple,
    'dieback': Colors.red,
    'healthy': Color.fromARGB(255, 2, 119, 252),
    'powdery_mildew': Color.fromARGB(255, 9, 46, 2),
    'tip_burn': Colors.brown,
    'Unknown': Colors.grey,
  };

  // List of real diseases (excluding tip burn/unknown)
  final List<String> _diseaseLabels = [
    'anthracnose',
    'backterial_blackspot',
    'powdery_mildew',
    'dieback',
  ];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _loadSelectedRangeIndex();
    _loadTrackedScans();
  }

  Future<void> _loadSelectedRangeIndex() async {
    final box = await Hive.openBox('trackingBox');
    final idx = box.get('selectedRangeIndex');
    if (idx is int && idx >= 0 && idx < _timeRanges.length) {
      setState(() {
        _selectedRangeIndex = idx;
      });
    }
  }

  Future<void> _saveSelectedRangeIndex(int idx) async {
    final box = await Hive.openBox('trackingBox');
    await box.put('selectedRangeIndex', idx);
  }

  Future<void> _loadTrackedScans() async {
    try {
      final userBox = await Hive.openBox('userBox');
      final userProfile = userBox.get('userProfile');
      final userId = userProfile?['userId'];
      List<Map<String, dynamic>> cloudSessions = [];
      List<Map<String, dynamic>> pendingSessions = [];
      if (userId != null) {
        // Fetch tracking sessions
        final query =
            await FirebaseFirestore.instance
                .collection('tracking')
                .where('userId', isEqualTo: userId)
                .orderBy('date', descending: true)
                .get();
        cloudSessions =
            query.docs
                .map((doc) => Map<String, dynamic>.from(doc.data()))
                .toList();
        // Fetch pending scan_requests
        final pendingQuery =
            await FirebaseFirestore.instance
                .collection('scan_requests')
                .where('userId', isEqualTo: userId)
                .where('status', isEqualTo: 'pending')
                .orderBy('submittedAt', descending: true)
                .get();
        pendingSessions =
            pendingQuery.docs.map((doc) {
              final data = Map<String, dynamic>.from(doc.data());
              // Normalize to tracking session structure
              return {
                'sessionId': data['id'] ?? data['sessionId'] ?? doc.id,
                'date': data['submittedAt'] ?? '',
                'images': data['images'] ?? [],
                'source': 'pending',
                'diseaseSummary': data['diseaseSummary'] ?? [],
                'status': 'pending',
                'userName': data['userName'] ?? '',
              };
            }).toList();
        print('Loaded pending scan_requests: ${pendingSessions.length}');
        for (var s in pendingSessions) print('Pending: $s');
      }
      // Merge pending and tracking sessions
      List<Map<String, dynamic>> sessions = [
        ...pendingSessions,
        ...cloudSessions,
      ];
      // Sort sessions by date descending (most recent first)
      sessions.sort((a, b) {
        final dateA =
            a['date'] != null && a['date'].toString().isNotEmpty
                ? DateTime.tryParse(a['date'].toString())
                : null;
        final dateB =
            b['date'] != null && b['date'].toString().isNotEmpty
                ? DateTime.tryParse(b['date'].toString())
                : null;
        if (dateA == null && dateB == null) return 0;
        if (dateA == null) return 1;
        if (dateB == null) return -1;
        return dateB.compareTo(dateA); // Descending
      });
      // Save to Hive for offline use
      final box = await Hive.openBox('trackingBox');
      await box.put('scans', sessions);
      setState(() {
        _sessionScans = sessions;
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading tracked scans: $e');
      // Fallback to local Hive data if Firestore fails
      try {
        final box = await Hive.openBox('trackingBox');
        final sessions = box.get('scans', defaultValue: []);
        if (sessions is List) {
          setState(() {
            _sessionScans =
                sessions
                    .whereType<Map>()
                    .map<Map<String, dynamic>>(
                      (e) => Map<String, dynamic>.from(e as Map),
                    )
                    .toList();
            _isLoading = false;
          });
        } else {
          setState(() {
            _sessionScans = [];
            _isLoading = false;
          });
        }
      } catch (e2) {
        print('Error loading local tracked scans: $e2');
        setState(() {
          _sessionScans = [];
          _isLoading = false;
        });
      }
    }
  }

  bool _isRealDisease(String label) {
    final l = label.toLowerCase();
    return _diseaseLabels.contains(l);
  }

  List<Map<String, dynamic>> _filteredSessions() {
    if (_sessionScans.isEmpty) return [];
    final now = DateTime.now();
    final days = _timeRanges[_selectedRangeIndex]['days'] as int?;
    if (days == null) {
      // Show everything
      return List<Map<String, dynamic>>.from(_sessionScans);
    }
    final filtered =
        _sessionScans.where((session) {
          final dateStr = session['date'];
          if (dateStr == null) return false;
          final date = DateTime.tryParse(dateStr);
          if (date == null) return false;
          return now.difference(date).inDays.abs() < days;
        }).toList();
    print('DEBUG: filtered sessions: ' + filtered.toString());
    return filtered;
  }

  Map<String, Map<String, int>> _monthlyHealthyAndDiseases(
    List<Map<String, dynamic>> scans,
  ) {
    final Map<String, Map<String, int>> result = {};
    for (final scan in scans) {
      final date = scan['date'] ?? '';
      final label = (scan['disease'] ?? '').toLowerCase();
      if (date.isEmpty || label == 'tip_burn' || label == 'unknown') continue;
      final month = date.substring(0, 7); // 'YYYY-MM'
      result.putIfAbsent(
        month,
        () => {
          'healthy': 0,
          ...{for (var d in _diseaseLabels) d: 0},
        },
      );
      if (label == 'healthy') {
        result[month]!['healthy'] = (result[month]!['healthy'] ?? 0) + 1;
      } else if (_isRealDisease(label)) {
        result[month]![label] = (result[month]![label] ?? 0) + 1;
      }
    }
    return result;
  }

  Map<String, int> _overallHealthyAndDiseases(
    List<Map<String, dynamic>> scans,
  ) {
    final Map<String, int> result = {
      'healthy': 0,
      ...{for (var d in _diseaseLabels) d: 0},
    };
    for (final scan in scans) {
      final label = (scan['disease'] ?? '').toLowerCase();
      if (label == 'tip_burn' || label == 'unknown') continue;
      if (label == 'healthy') {
        result['healthy'] = (result['healthy'] ?? 0) + 1;
      } else if (_isRealDisease(label)) {
        result[label] = (result[label] ?? 0) + 1;
      }
    }
    return result;
  }

  void _showScanDetails(Map<String, dynamic> scan) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text(_formatLabel(scan['disease'] ?? 'Unknown')),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (scan['imageUrl'] != null &&
                    (scan['imageUrl'] as String).isNotEmpty)
                  CachedNetworkImage(
                    imageUrl: scan['imageUrl'],
                    width: 200,
                    height: 200,
                    fit: BoxFit.cover,
                    placeholder:
                        (context, url) =>
                            const Center(child: CircularProgressIndicator()),
                    errorWidget:
                        (context, url, error) => const Icon(
                          Icons.broken_image,
                          size: 40,
                          color: Colors.grey,
                        ),
                  )
                else if (scan['imagePath'] != null)
                  Image.file(
                    File(scan['imagePath']),
                    width: 200,
                    height: 200,
                    fit: BoxFit.cover,
                  ),
                const SizedBox(height: 12),
                Text(
                  'Date: ${scan['date'] != null ? DateFormat('MMM d, yyyy – h:mma').format(DateTime.parse(scan['date'])) : 'Unknown'}',
                ),
                if (scan['confidence'] != null)
                  Text(
                    'Confidence: ${(scan['confidence'] * 100).toStringAsFixed(1)}%',
                  ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Close'),
              ),
            ],
          ),
    );
  }

  void _showSessionDetails(Map<String, dynamic> session) {
    final images = session['images'] as List? ?? [];
    final source =
        session['source'] == 'expert_review' ? 'Reviewing' : 'Tracking';
    final sourceColor =
        session['source'] == 'expert_review' ? Colors.orange : Colors.blue;
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Row(
              children: [
                Expanded(
                  child: Text(
                    'Session Details',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: sourceColor,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    source,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
            content: SizedBox(
              width: 400,
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Date: ${session['date'] != null ? DateFormat('MMM d, yyyy – h:mma').format(DateTime.parse(session['date'])) : 'Unknown'}',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${images.length} image(s)',
                      style: const TextStyle(fontSize: 14),
                    ),
                    const Divider(height: 24),
                    for (int idx = 0; idx < images.length; idx++) ...[
                      Card(
                        margin: const EdgeInsets.symmetric(vertical: 8),
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (images[idx]['imageUrl'] != null &&
                                  (images[idx]['imageUrl'] as String)
                                      .isNotEmpty)
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: CachedNetworkImage(
                                    imageUrl: images[idx]['imageUrl'],
                                    width: 320,
                                    height: 180,
                                    fit: BoxFit.cover,
                                    placeholder:
                                        (context, url) => const Center(
                                          child: CircularProgressIndicator(),
                                        ),
                                    errorWidget:
                                        (context, url, error) => const Icon(
                                          Icons.broken_image,
                                          size: 40,
                                          color: Colors.grey,
                                        ),
                                  ),
                                )
                              else if (images[idx]['imagePath'] != null)
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: Image.file(
                                    File(images[idx]['imagePath']),
                                    width: 320,
                                    height: 180,
                                    fit: BoxFit.cover,
                                  ),
                                ),
                              const SizedBox(height: 8),
                              Text(
                                'Results:',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                              ...((images[idx]['results'] as List?) ?? []).map((
                                res,
                              ) {
                                final disease = res['disease'] ?? 'Unknown';
                                final confidence = res['confidence'];
                                return Padding(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 2,
                                  ),
                                  child: Text(
                                    confidence != null
                                        ? '${_formatLabel(disease)} (${(confidence * 100).toStringAsFixed(1)}%)'
                                        : _formatLabel(disease),
                                    style: const TextStyle(fontSize: 15),
                                  ),
                                );
                              }).toList(),
                            ],
                          ),
                        ),
                      ),
                    ],
                    if (session['source'] == 'expert_review')
                      Padding(
                        padding: const EdgeInsets.only(top: 12.0),
                        child: Row(
                          children: const [
                            Icon(
                              Icons.hourglass_empty,
                              color: Colors.orange,
                              size: 20,
                            ),
                            SizedBox(width: 8),
                            Text(
                              'Waiting for expert review',
                              style: TextStyle(
                                color: Colors.orange,
                                fontWeight: FontWeight.w600,
                                fontSize: 15,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Close'),
              ),
            ],
          ),
    );
  }

  String _formatLabel(String label) {
    switch (label.toLowerCase()) {
      case 'backterial_blackspot':
        return 'Bacterial black spot';
      case 'powdery_mildew':
        return 'Powdery Mildew';
      case 'tip_burn':
        return 'Tip Burn';
      case 'healthy':
        return 'Healthy';
      case 'dieback':
        return 'Dieback';
      case 'anthracnose':
        return 'Anthracnose';
      default:
        return label.isNotEmpty
            ? label[0].toUpperCase() + label.substring(1)
            : 'Unknown';
    }
  }

  // Helper to get the start date for the selected range
  DateTime _rangeStartDate() {
    final days = _timeRanges[_selectedRangeIndex]['days'] as int?;
    if (days == null) {
      // Show Everything: return a very early date
      return DateTime(1970);
    }
    final now = DateTime.now();
    return now.subtract(Duration(days: days - 1));
  }

  // Group scans for charting based on selected range
  List<String> _chartWeekLabels(int weeks) {
    return List.generate(weeks, (i) => 'W${i + 1}');
  }

  // Helper to get the last 12 months ending with the current month
  List<String> _last12Months(DateTime now) {
    return List.generate(12, (i) {
      final d = DateTime(now.year, now.month - 11 + i, 1);
      return DateFormat('yyyy-MM').format(d);
    });
  }

  // Aggregate chart data for the selected range
  List<Map<String, dynamic>> _chartData(List<Map<String, dynamic>> scans) {
    final start = _rangeStartDate();
    final now = DateTime.now();
    // Show Everything: group by month (or by year if >24 months)
    if (_selectedRangeIndex == 0) {
      // Find earliest and latest scan dates
      if (scans.isEmpty) return [];
      final dates =
          scans
              .map((s) => DateTime.tryParse(s['date'] ?? ''))
              .whereType<DateTime>()
              .toList();
      if (dates.isEmpty) return [];
      dates.sort();
      final first = dates.first;
      final last = dates.last;
      final monthsBetween =
          (last.year - first.year) * 12 + (last.month - first.month) + 1;
      if (monthsBetween > 24) {
        // Group by year
        final years = <String>[];
        for (int y = first.year; y <= last.year; y++) {
          years.add(y.toString());
        }
        final Map<String, Map<String, int>> data = {
          for (final y in years)
            y: {
              'healthy': 0,
              ...{for (var d in _diseaseLabels) d: 0},
            },
        };
        for (final scan in scans) {
          final label = (scan['disease'] ?? '').toLowerCase();
          if (label == 'tip_burn' || label == 'unknown') continue;
          final dateStr = scan['date'];
          if (dateStr == null) continue;
          final date = DateTime.tryParse(dateStr);
          if (date == null) continue;
          final groupKey = date.year.toString();
          if (!data.containsKey(groupKey)) continue;
          if (label == 'healthy') {
            data[groupKey]!['healthy'] = (data[groupKey]!['healthy'] ?? 0) + 1;
          } else if (_isRealDisease(label)) {
            data[groupKey]![label] = (data[groupKey]![label] ?? 0) + 1;
          }
        }
        return years.map((y) => {'group': y, ...data[y]!}).toList();
      } else {
        // Group by month
        final months = <String>[];
        DateTime d = DateTime(first.year, first.month);
        while (d.isBefore(DateTime(last.year, last.month + 1))) {
          months.add(DateFormat('yyyy-MM').format(d));
          d = DateTime(d.year, d.month + 1);
        }
        final Map<String, Map<String, int>> data = {
          for (final m in months)
            m: {
              'healthy': 0,
              ...{for (var d in _diseaseLabels) d: 0},
            },
        };
        for (final scan in scans) {
          final label = (scan['disease'] ?? '').toLowerCase();
          if (label == 'tip_burn' || label == 'unknown') continue;
          final dateStr = scan['date'];
          if (dateStr == null) continue;
          final date = DateTime.tryParse(dateStr);
          if (date == null) continue;
          final groupKey = DateFormat('yyyy-MM').format(date);
          if (!data.containsKey(groupKey)) continue;
          if (label == 'healthy') {
            data[groupKey]!['healthy'] = (data[groupKey]!['healthy'] ?? 0) + 1;
          } else if (_isRealDisease(label)) {
            data[groupKey]![label] = (data[groupKey]![label] ?? 0) + 1;
          }
        }
        return months.map((m) => {'group': m, ...data[m]!}).toList();
      }
    }
    // Last 7 days: group by day
    if (_selectedRangeIndex == 1) {
      final groups = List.generate(7, (i) {
        final d = start.add(Duration(days: i));
        return DateFormat('yyyy-MM-dd').format(d);
      });
      final Map<String, Map<String, int>> data = {
        for (final g in groups)
          g: {
            'healthy': 0,
            ...{for (var d in _diseaseLabels) d: 0},
          },
      };
      for (final scan in scans) {
        final label = (scan['disease'] ?? '').toLowerCase();
        if (label == 'tip_burn' || label == 'unknown') continue;
        final dateStr = scan['date'];
        if (dateStr == null) continue;
        final date = DateTime.tryParse(dateStr);
        if (date == null) continue;
        final groupKey = DateFormat('yyyy-MM-dd').format(date);
        if (!data.containsKey(groupKey)) continue;
        if (label == 'healthy') {
          data[groupKey]!['healthy'] = (data[groupKey]!['healthy'] ?? 0) + 1;
        } else if (_isRealDisease(label)) {
          data[groupKey]![label] = (data[groupKey]![label] ?? 0) + 1;
        }
      }
      return groups.map((g) => {'group': g, ...data[g]!}).toList();
    }
    // Last 30/60/90 days: group by week
    if (_selectedRangeIndex >= 2 && _selectedRangeIndex <= 4) {
      final days = _timeRanges[_selectedRangeIndex]['days'] as int;
      final weeks = (days / 7).ceil();
      // Defensive: ensure weekLabels and chartData are always the same length
      final weekLabels = _chartWeekLabels(weeks);
      final List<Map<String, dynamic>> chartData = List.generate(
        weekLabels.length,
        (i) => {
          'group': weekLabels[i],
          'healthy': 0,
          ...{for (var d in _diseaseLabels) d: 0},
        },
      );
      for (final scan in scans) {
        final label = (scan['disease'] ?? '').toLowerCase();
        if (label == 'tip_burn' || label == 'unknown') continue;
        final dateStr = scan['date'];
        if (dateStr == null) continue;
        final date = DateTime.tryParse(dateStr);
        if (date == null) continue;
        final weekIndex = ((date.difference(start).inDays) / 7).floor();
        if (weekIndex < 0 || weekIndex >= weekLabels.length) continue;
        if (label == 'healthy') {
          chartData[weekIndex]['healthy'] =
              (chartData[weekIndex]['healthy'] as int) + 1;
        } else if (_isRealDisease(label)) {
          chartData[weekIndex][label] =
              (chartData[weekIndex][label] as int) + 1;
        }
      }
      return chartData;
    }
    // Last year: group by month
    if (_selectedRangeIndex == 5) {
      final months = _last12Months(now);
      final Map<String, Map<String, int>> data = {
        for (final m in months)
          m: {
            'healthy': 0,
            ...{for (var d in _diseaseLabels) d: 0},
          },
      };
      for (final scan in scans) {
        final label = (scan['disease'] ?? '').toLowerCase();
        if (label == 'tip_burn' || label == 'unknown') continue;
        final dateStr = scan['date'];
        if (dateStr == null) continue;
        final date = DateTime.tryParse(dateStr);
        if (date == null) continue;
        final groupKey = DateFormat('yyyy-MM').format(date);
        if (!data.containsKey(groupKey)) continue;
        if (label == 'healthy') {
          data[groupKey]!['healthy'] = (data[groupKey]!['healthy'] ?? 0) + 1;
        } else if (_isRealDisease(label)) {
          data[groupKey]![label] = (data[groupKey]![label] ?? 0) + 1;
        }
      }
      return months.map((m) => {'group': m, ...data[m]!}).toList();
    }
    // fallback
    return [];
  }

  // Helper to flatten sessions into a flat list of scans
  List<Map<String, dynamic>> _flattenScans(
    List<Map<String, dynamic>> sessions,
  ) {
    final List<Map<String, dynamic>> scans = [];
    for (final session in sessions) {
      final date = session['date'];
      final images = session['images'] as List? ?? [];
      for (final img in images) {
        final results = img['results'] as List? ?? [];
        for (final res in results) {
          scans.add({
            'disease': res['disease'],
            'confidence': res['confidence'],
            'date': date,
            'imagePath': img['imagePath'],
          });
        }
      }
    }
    return scans;
  }

  @override
  Widget build(BuildContext context) {
    final userBox = Hive.box('userBox');
    final userProfile = userBox.get('userProfile');
    final userId = userProfile?['userId'];
    if (userId == null) {
      return const Center(child: Text('Not logged in'));
    }
    // Real-time streams for tracking and pending scan_requests
    final trackingStream =
        FirebaseFirestore.instance
            .collection('tracking')
            .where('userId', isEqualTo: userId)
            .orderBy('date', descending: true)
            .snapshots();
    final pendingStream =
        FirebaseFirestore.instance
            .collection('scan_requests')
            .where('userId', isEqualTo: userId)
            .where('status', isEqualTo: 'pending')
            .orderBy('submittedAt', descending: true)
            .snapshots();
    return StreamBuilder<List<List<Map<String, dynamic>>>>(
      stream: Rx.combineLatest2(
        trackingStream.map(
          (snapshot) =>
              snapshot.docs
                  .map((doc) => Map<String, dynamic>.from(doc.data()))
                  .toList(),
        ),
        pendingStream.map(
          (snapshot) =>
              snapshot.docs.map((doc) {
                final data = Map<String, dynamic>.from(doc.data());
                return {
                  'sessionId': data['id'] ?? data['sessionId'] ?? doc.id,
                  'date': data['submittedAt'] ?? '',
                  'images': data['images'] ?? [],
                  'source': 'pending',
                  'diseaseSummary': data['diseaseSummary'] ?? [],
                  'status': 'pending',
                  'userName': data['userName'] ?? '',
                };
              }).toList(),
        ),
        (
          List<Map<String, dynamic>> tracking,
          List<Map<String, dynamic>> pending,
        ) => [pending, tracking],
      ),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final pendingSessions = snapshot.data![0];
        final cloudSessions = snapshot.data![1];
        List<Map<String, dynamic>> sessions = [
          ...pendingSessions,
          ...cloudSessions,
        ];
        // Sort sessions by date descending (most recent first)
        sessions.sort((a, b) {
          final dateA =
              a['date'] != null && a['date'].toString().isNotEmpty
                  ? DateTime.tryParse(a['date'].toString())
                  : null;
          final dateB =
              b['date'] != null && b['date'].toString().isNotEmpty
                  ? DateTime.tryParse(b['date'].toString())
                  : null;
          if (dateA == null && dateB == null) return 0;
          if (dateA == null) return 1;
          if (dateB == null) return -1;
          return dateB.compareTo(dateA); // Descending
        });
        // Save to Hive for offline use
        Hive.openBox('trackingBox').then((box) => box.put('scans', sessions));
        final filteredSessions = _filteredSessionsFromList(sessions);
        final flatScans = _flattenScans(filteredSessions);
        final chartData = _chartData(flatScans);
        final overallCounts = _overallHealthyAndDiseases(flatScans);
        final healthy = overallCounts['healthy'] ?? 0;
        final totalDiseased = _diseaseLabels.fold(
          0,
          (sum, d) => sum + (overallCounts[d] ?? 0),
        );
        final total = healthy + totalDiseased;
        final healthyPercent =
            total > 0 ? (healthy / total * 100).toStringAsFixed(1) : '0';
        final diseasedPercent =
            total > 0 ? (totalDiseased / total * 100).toStringAsFixed(1) : '0';
        return Scaffold(
          appBar: AppBar(
            title: const Text('Tracking & Progress'),
            backgroundColor: Colors.green,
          ),
          body:
              filteredSessions.isEmpty
                  ? const Center(child: Text('No tracked scans yet.'))
                  : SingleChildScrollView(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Time range selector
                          Row(
                            children: [
                              const Text(
                                'Show:',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(width: 8),
                              DropdownButton<int>(
                                value: _selectedRangeIndex,
                                items: List.generate(
                                  _timeRanges.length,
                                  (i) => DropdownMenuItem(
                                    value: i,
                                    child: Text(
                                      _timeRanges[i]['label'] as String,
                                    ),
                                  ),
                                ),
                                onChanged: (i) async {
                                  if (i != null) {
                                    setState(() => _selectedRangeIndex = i);
                                    await _saveSelectedRangeIndex(i);
                                  }
                                },
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          // Friendly summary
                          Card(
                            color: Colors.green[50],
                            margin: const EdgeInsets.only(bottom: 16),
                            child: Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.insights,
                                    color: Colors.green[700],
                                    size: 32,
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      '${_timeRanges[_selectedRangeIndex]['label']}: $healthyPercent% healthy, $diseasedPercent% diseased. Keep tracking your farm health!',
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          // Trend Bar Chart
                          Text(
                            'Farm Health Trend',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: 8),
                          Container(
                            height: 260,
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.04),
                                  blurRadius: 8,
                                ),
                              ],
                            ),
                            child:
                                chartData.isEmpty
                                    ? const Center(
                                      child: Text('Not enough data for chart.'),
                                    )
                                    : LineChart(
                                      LineChartData(
                                        minY: 0,
                                        maxY:
                                            chartData
                                                .expand(
                                                  (m) =>
                                                      m.values.whereType<int>(),
                                                )
                                                .fold<double>(
                                                  0,
                                                  (prev, e) =>
                                                      e > prev
                                                          ? e.toDouble()
                                                          : prev,
                                                ) *
                                            1.2,
                                        lineBarsData: [
                                          // Healthy line
                                          LineChartBarData(
                                            spots: [
                                              for (
                                                int i = 0;
                                                i < chartData.length;
                                                i++
                                              )
                                                FlSpot(
                                                  i.toDouble(),
                                                  (chartData[i]['healthy']
                                                              as int?)
                                                          ?.toDouble() ??
                                                      0,
                                                ),
                                            ],
                                            isCurved: true,
                                            color: _diseaseColors['healthy'],
                                            barWidth: 4,
                                            dotData: FlDotData(show: true),
                                            belowBarData: BarAreaData(
                                              show: false,
                                            ),
                                          ),
                                          // Disease lines
                                          for (final d in _diseaseLabels)
                                            LineChartBarData(
                                              spots: [
                                                for (
                                                  int i = 0;
                                                  i < chartData.length;
                                                  i++
                                                )
                                                  FlSpot(
                                                    i.toDouble(),
                                                    (chartData[i][d] as int?)
                                                            ?.toDouble() ??
                                                        0,
                                                  ),
                                              ],
                                              isCurved: true,
                                              color: _diseaseColors[d],
                                              barWidth: 4,
                                              dotData: FlDotData(show: true),
                                              belowBarData: BarAreaData(
                                                show: false,
                                              ),
                                            ),
                                        ],
                                        titlesData: FlTitlesData(
                                          show: true,
                                          bottomTitles: AxisTitles(
                                            sideTitles: SideTitles(
                                              showTitles: true,
                                              reservedSize:
                                                  48, // Increased for more vertical space
                                              getTitlesWidget: (value, meta) {
                                                if (value < 0 ||
                                                    value >= chartData.length)
                                                  return const SizedBox.shrink();
                                                final group =
                                                    chartData[value
                                                            .toInt()]['group']
                                                        as String;
                                                Widget labelWidget;
                                                if (_selectedRangeIndex == 0) {
                                                  // Only show every Nth label if there are many
                                                  int n =
                                                      chartData.length > 24
                                                          ? 3
                                                          : 1;
                                                  if (value.toInt() % n != 0 &&
                                                      chartData.length > 12) {
                                                    return const SizedBox.shrink();
                                                  }
                                                  // Only do substring if group is a month label (yyyy-MM)
                                                  if (group.length >= 7 &&
                                                      group.contains('-')) {
                                                    labelWidget = Transform.rotate(
                                                      angle:
                                                          -0.5708, // -90 degrees in radians
                                                      child: Text(
                                                        group.substring(5),
                                                        style: const TextStyle(
                                                          fontSize: 12,
                                                        ),
                                                      ),
                                                    );
                                                  } else {
                                                    labelWidget =
                                                        Transform.rotate(
                                                          angle: -0.5708,
                                                          child: Text(
                                                            group,
                                                            style:
                                                                const TextStyle(
                                                                  fontSize: 12,
                                                                ),
                                                          ),
                                                        );
                                                  }
                                                } else if (_selectedRangeIndex >=
                                                        1 &&
                                                    _selectedRangeIndex <= 4) {
                                                  labelWidget = Transform.rotate(
                                                    angle:
                                                        -0.5708, // -90 degrees in radians
                                                    child: Text(
                                                      group,
                                                      style: const TextStyle(
                                                        fontSize: 12,
                                                      ),
                                                    ),
                                                  );
                                                } else {
                                                  // Show month as 3-letter abbreviation, vertical
                                                  final year = int.parse(
                                                    group.substring(0, 4),
                                                  );
                                                  final month = int.parse(
                                                    group.substring(5),
                                                  );
                                                  final monthAbbr = DateFormat(
                                                    'MMM',
                                                  ).format(
                                                    DateTime(year, month),
                                                  );
                                                  labelWidget =
                                                      Transform.rotate(
                                                        angle: -0.5708,
                                                        child: Text(
                                                          monthAbbr,
                                                          style:
                                                              const TextStyle(
                                                                fontSize: 12,
                                                              ),
                                                        ),
                                                      );
                                                }
                                                // Add space between axis and label
                                                return Padding(
                                                  padding:
                                                      const EdgeInsets.only(
                                                        top: 16,
                                                      ),
                                                  child: labelWidget,
                                                );
                                              },
                                            ),
                                          ),
                                          leftTitles: AxisTitles(
                                            sideTitles: SideTitles(
                                              showTitles: true,
                                              reservedSize: 32,
                                              getTitlesWidget: (value, meta) {
                                                if (value % 1 == 0) {
                                                  return Text(
                                                    value.toInt().toString(),
                                                    style: const TextStyle(
                                                      fontSize: 12,
                                                    ),
                                                  );
                                                }
                                                return const SizedBox.shrink();
                                              },
                                            ),
                                          ),
                                          topTitles: AxisTitles(
                                            sideTitles: SideTitles(
                                              showTitles: false,
                                            ),
                                          ),
                                          rightTitles: AxisTitles(
                                            sideTitles: SideTitles(
                                              showTitles: false,
                                            ),
                                          ),
                                        ),
                                        gridData: FlGridData(
                                          show: true,
                                          drawVerticalLine: false,
                                        ),
                                        borderData: FlBorderData(show: false),
                                      ),
                                    ),
                          ),
                          const SizedBox(height: 12),
                          // Legend
                          SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: Row(
                              children: [
                                _buildLegendItem(
                                  _diseaseColors['healthy']!,
                                  _formatLabel('healthy'),
                                ),
                                for (final d in _diseaseLabels)
                                  _buildLegendItem(
                                    _diseaseColors[d]!,
                                    _formatLabel(d),
                                  ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 32),
                          Text(
                            'History',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Scans from \'${_timeRanges[_selectedRangeIndex]['label']}\'',
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 8),
                          ListView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: filteredSessions.length,
                            itemBuilder: (context, index) {
                              final session =
                                  filteredSessions[index]; // newest at top
                              final date =
                                  session['date'] != null
                                      ? DateFormat(
                                        'MMM d, yyyy – h:mma',
                                      ).format(DateTime.parse(session['date']))
                                      : '';
                              final images = session['images'] as List? ?? [];
                              return Card(
                                margin: const EdgeInsets.symmetric(vertical: 6),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    ListTile(
                                      leading:
                                          images.isNotEmpty &&
                                                  images[0]['imageUrl'] !=
                                                      null &&
                                                  (images[0]['imageUrl']
                                                          as String)
                                                      .isNotEmpty
                                              ? CachedNetworkImage(
                                                imageUrl: images[0]['imageUrl'],
                                                width: 56,
                                                height: 56,
                                                fit: BoxFit.cover,
                                                placeholder:
                                                    (
                                                      context,
                                                      url,
                                                    ) => const Center(
                                                      child:
                                                          CircularProgressIndicator(),
                                                    ),
                                                errorWidget:
                                                    (context, url, error) =>
                                                        const Icon(
                                                          Icons.broken_image,
                                                          size: 40,
                                                          color: Colors.grey,
                                                        ),
                                              )
                                              : images.isNotEmpty &&
                                                  images[0]['imagePath'] != null
                                              ? Image.file(
                                                File(images[0]['imagePath']),
                                                width: 56,
                                                height: 56,
                                                fit: BoxFit.cover,
                                              )
                                              : const Icon(
                                                Icons.image,
                                                size: 56,
                                              ),
                                      title: Row(
                                        children: [
                                          Expanded(
                                            child: Text('Session: $date'),
                                          ),
                                          if (session['source'] == 'pending')
                                            Padding(
                                              padding: const EdgeInsets.only(
                                                left: 8.0,
                                              ),
                                              child: Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      horizontal: 10,
                                                      vertical: 4,
                                                    ),
                                                decoration: BoxDecoration(
                                                  color: Colors.orange,
                                                  borderRadius:
                                                      BorderRadius.circular(12),
                                                ),
                                                child: const Text(
                                                  'Pending',
                                                  style: TextStyle(
                                                    color: Colors.white,
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 13,
                                                  ),
                                                ),
                                              ),
                                            )
                                          else
                                            Padding(
                                              padding: const EdgeInsets.only(
                                                left: 8.0,
                                              ),
                                              child: Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      horizontal: 10,
                                                      vertical: 4,
                                                    ),
                                                decoration: BoxDecoration(
                                                  color: Colors.blue,
                                                  borderRadius:
                                                      BorderRadius.circular(12),
                                                ),
                                                child: const Text(
                                                  'Tracking',
                                                  style: TextStyle(
                                                    color: Colors.white,
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 13,
                                                  ),
                                                ),
                                              ),
                                            ),
                                          IconButton(
                                            icon: const Icon(
                                              Icons.delete,
                                              color: Colors.red,
                                            ),
                                            tooltip: 'Delete Session',
                                            onPressed: () async {
                                              final confirm = await showDialog<
                                                bool
                                              >(
                                                context: context,
                                                builder:
                                                    (context) => AlertDialog(
                                                      title: const Text(
                                                        'Delete Session',
                                                      ),
                                                      content: const Text(
                                                        'Are you sure you want to delete this session? This action cannot be undone.',
                                                      ),
                                                      actions: [
                                                        TextButton(
                                                          onPressed:
                                                              () =>
                                                                  Navigator.of(
                                                                    context,
                                                                  ).pop(false),
                                                          child: const Text(
                                                            'Cancel',
                                                          ),
                                                        ),
                                                        TextButton(
                                                          onPressed:
                                                              () =>
                                                                  Navigator.of(
                                                                    context,
                                                                  ).pop(true),
                                                          child: const Text(
                                                            'Delete',
                                                            style: TextStyle(
                                                              color: Colors.red,
                                                            ),
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                              );
                                              if (confirm == true) {
                                                final images =
                                                    (session['images']
                                                        as List?) ??
                                                    [];
                                                final supabase =
                                                    Supabase.instance.client;
                                                bool imageDeleteError = false;
                                                for (final img in images) {
                                                  final imageUrl =
                                                      img['imageUrl'] ?? '';
                                                  if (imageUrl is String &&
                                                      imageUrl.isNotEmpty) {
                                                    final uri = Uri.parse(
                                                      imageUrl,
                                                    );
                                                    final segments =
                                                        uri.pathSegments;
                                                    final bucketIndex = segments
                                                        .indexOf('mangosense');
                                                    if (bucketIndex != -1 &&
                                                        bucketIndex + 1 <
                                                            segments.length) {
                                                      final storagePath =
                                                          segments
                                                              .sublist(
                                                                bucketIndex + 1,
                                                              )
                                                              .join('/');
                                                      try {
                                                        await supabase.storage
                                                            .from('mangosense')
                                                            .remove([
                                                              storagePath,
                                                            ]);
                                                      } catch (e) {
                                                        imageDeleteError = true;
                                                      }
                                                    }
                                                  }
                                                }
                                                try {
                                                  if (session['source'] ==
                                                      'pending') {
                                                    final docId =
                                                        session['sessionId'] ??
                                                        session['id'];
                                                    await FirebaseFirestore
                                                        .instance
                                                        .collection(
                                                          'scan_requests',
                                                        )
                                                        .doc(docId)
                                                        .delete();
                                                  } else {
                                                    final docId =
                                                        session['sessionId'] ??
                                                        session['id'];
                                                    await FirebaseFirestore
                                                        .instance
                                                        .collection('tracking')
                                                        .doc(docId)
                                                        .delete();
                                                  }
                                                  if (context.mounted) {
                                                    ScaffoldMessenger.of(
                                                      context,
                                                    ).showSnackBar(
                                                      SnackBar(
                                                        content: Text(
                                                          imageDeleteError
                                                              ? 'Session deleted, but some images could not be removed from storage.'
                                                              : 'Session deleted successfully!',
                                                        ),
                                                        backgroundColor:
                                                            imageDeleteError
                                                                ? Colors.orange
                                                                : Colors.red,
                                                      ),
                                                    );
                                                    setState(() {
                                                      filteredSessions.removeAt(
                                                        index,
                                                      );
                                                    });
                                                  }
                                                } catch (e) {
                                                  if (context.mounted) {
                                                    ScaffoldMessenger.of(
                                                      context,
                                                    ).showSnackBar(
                                                      SnackBar(
                                                        content: Text(
                                                          'Failed to delete session: $e',
                                                        ),
                                                        backgroundColor:
                                                            Colors.red,
                                                      ),
                                                    );
                                                  }
                                                }
                                              }
                                            },
                                          ),
                                        ],
                                      ),
                                      subtitle: Text(
                                        '${images.length} image(s)',
                                      ),
                                      onTap: () => _showSessionDetails(session),
                                    ),
                                    if (session['source'] == 'expert_review')
                                      const Padding(
                                        padding: EdgeInsets.only(
                                          left: 16,
                                          right: 16,
                                          bottom: 12,
                                        ),
                                        child: Text(
                                          'Waiting for expert review',
                                          style: TextStyle(
                                            color: Colors.orange,
                                            fontWeight: FontWeight.w600,
                                            fontSize: 14,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
        );
      },
    );
  }

  // Helper for filtering sessions in real-time
  List<Map<String, dynamic>> _filteredSessionsFromList(
    List<Map<String, dynamic>> sessions,
  ) {
    if (sessions.isEmpty) return [];
    final now = DateTime.now();
    final days = _timeRanges[_selectedRangeIndex]['days'] as int?;
    if (days == null) {
      // Show everything
      return List<Map<String, dynamic>>.from(sessions);
    }
    final filtered =
        sessions.where((session) {
          final dateStr = session['date'];
          if (dateStr == null) return false;
          final date = DateTime.tryParse(dateStr);
          if (date == null) return false;
          return now.difference(date).inDays.abs() < days;
        }).toList();
    return filtered;
  }

  Widget _buildLegendItem(Color color, String label) {
    return Row(
      children: [
        Container(
          width: 16,
          height: 16,
          color: color,
          margin: const EdgeInsets.only(right: 4),
        ),
        Text(label, style: const TextStyle(fontSize: 13)),
        const SizedBox(width: 12),
      ],
    );
  }
}
