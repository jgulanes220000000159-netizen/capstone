import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:intl/intl.dart';
import 'dart:io';
import 'package:fl_chart/fl_chart.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:easy_localization/easy_localization.dart';
import 'tracking_models.dart';
import 'tracking_chart.dart';

class TrackingPage extends StatefulWidget {
  const TrackingPage({Key? key}) : super(key: key);

  @override
  State<TrackingPage> createState() => _TrackingPageState();
}

class _TrackingPageState extends State<TrackingPage> {
  int _selectedRangeIndex = 0; // 0: Last 7 Days, 1: Custom
  DateTime? _customStartDate;
  DateTime? _customEndDate;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _loadSelectedRangeIndex();
  }

  Future<void> _loadSelectedRangeIndex() async {
    final box = await Hive.openBox('trackingBox');
    final idx = box.get('selectedRangeIndex');
    if (idx is int && idx >= 0 && idx < TrackingModels.timeRanges.length) {
      setState(() {
        _selectedRangeIndex = idx;
      });
    }
    final startStr = box.get('customStartDate') as String?;
    final endStr = box.get('customEndDate') as String?;
    if (startStr != null) {
      _customStartDate = DateTime.tryParse(startStr);
    }
    if (endStr != null) {
      _customEndDate = DateTime.tryParse(endStr);
    }
  }

  Future<void> _saveSelectedRangeIndex(int idx) async {
    final box = await Hive.openBox('trackingBox');
    await box.put('selectedRangeIndex', idx);
  }

  Future<void> _saveCustomRange(DateTime start, DateTime end) async {
    final box = await Hive.openBox('trackingBox');
    await box.put(
      'customStartDate',
      DateTime(start.year, start.month, start.day).toIso8601String(),
    );
    await box.put(
      'customEndDate',
      DateTime(end.year, end.month, end.day).toIso8601String(),
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
    );
    if (picked != null) {
      setState(() {
        _customStartDate = picked.start;
        _customEndDate = picked.end;
        _selectedRangeIndex = 1; // Custom
      });
      await _saveSelectedRangeIndex(1);
      await _saveCustomRange(picked.start, picked.end);
    }
  }

  String _getTimeRangeLabel(int index) {
    switch (index) {
      case 0:
        return tr('last_7_days');
      case 1:
        if (_customStartDate != null && _customEndDate != null) {
          final s = DateFormat('MMM d').format(_customStartDate!);
          final e = DateFormat('MMM d').format(_customEndDate!);
          return '${tr('custom')}: $s – $e';
        }
        return tr('custom');
      default:
        return tr('last_7_days');
    }
  }

  Future<List<Map<String, dynamic>>> _loadSessionsWithFallback(
    String userId,
  ) async {
    try {
      // Try to load from Firestore first
      final trackingQuery =
          await FirebaseFirestore.instance
              .collection('tracking')
              .where('userId', isEqualTo: userId)
              .orderBy('date', descending: true)
              .get();

      final scanRequestsQuery =
          await FirebaseFirestore.instance
              .collection('scan_requests')
              .where('userId', isEqualTo: userId)
              .get();

      final cloudSessions =
          trackingQuery.docs
              .map((doc) => Map<String, dynamic>.from(doc.data()))
              .toList();

      final scanRequests =
          scanRequestsQuery.docs.map((doc) {
            final data = Map<String, dynamic>.from(doc.data());
            return {
              'sessionId': data['id'] ?? data['sessionId'] ?? doc.id,
              'date': data['submittedAt'] ?? '',
              'images': data['images'] ?? [],
              'source': data['status'] ?? 'pending',
              'diseaseSummary': data['diseaseSummary'] ?? [],
              'status': data['status'] ?? 'pending',
              'userName': data['userName'] ?? '',
              'expertReview': data['expertReview'],
              'expertName': data['expertName'],
            };
          }).toList();

      final sessions = [...scanRequests, ...cloudSessions];

      // Save to Hive for offline use
      final box = await Hive.openBox('trackingBox');
      await box.put('scans', sessions);

      return sessions;
    } catch (e) {
      print('Error loading from Firestore: $e');
      // Fallback to local Hive data
      try {
        final box = await Hive.openBox('trackingBox');
        final sessions = box.get('scans', defaultValue: []);
        if (sessions is List) {
          return sessions
              .whereType<Map>()
              .map<Map<String, dynamic>>((e) => Map<String, dynamic>.from(e))
              .toList();
        }
        return [];
      } catch (e2) {
        print('Error loading local data: $e2');
        return [];
      }
    }
  }

  void _showSessionDetails(Map<String, dynamic> session) {
    final images = session['images'] as List? ?? [];
    final source = TrackingModels.getSourceDisplayText(session['source']);
    final sourceColor = TrackingModels.getSourceColor(session['source']);
    final expertReview = session['expertReview'] as Map<String, dynamic>?;
    final expertName = session['expertName'] as String?;

    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Row(
              children: [
                Expanded(
                  child: Text(
                    tr('session_details'),
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
                      '${tr('date')} ${session['date'] != null ? DateFormat('MMM d, yyyy – h:mma').format(DateTime.parse(session['date'])) : tr('unknown')}',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      tr(
                        'image_count',
                        namedArgs: {'count': images.length.toString()},
                      ),
                      style: const TextStyle(fontSize: 14),
                    ),
                    // Show expert review if available
                    if (expertReview != null &&
                        (session['source'] == 'completed' ||
                            session['source'] == 'reviewed'))
                      Container(
                        margin: const EdgeInsets.only(top: 16),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.green.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: Colors.green.withOpacity(0.3),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(
                                  Icons.check_circle,
                                  color: Colors.green,
                                  size: 20,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  tr('expert_review'),
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.green,
                                  ),
                                ),
                              ],
                            ),
                            if (expertName != null &&
                                expertName.isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Text(
                                tr(
                                  'reviewed_by',
                                  namedArgs: {'name': expertName},
                                ),
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ],
                            if (expertReview['comment'] != null) ...[
                              const SizedBox(height: 8),
                              Text(
                                tr('comment'),
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                expertReview['comment'],
                                style: const TextStyle(fontSize: 14),
                              ),
                            ],
                            if (expertReview['treatmentPlan'] != null) ...[
                              const SizedBox(height: 12),
                              Text(
                                tr('treatment_plan'),
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(height: 4),
                              if (expertReview['treatmentPlan']['recommendations'] !=
                                  null) ...[
                                for (var rec
                                    in expertReview['treatmentPlan']['recommendations']) ...[
                                  Text(
                                    '• ${rec['treatment'] ?? tr('no_treatment_specified')}',
                                    style: const TextStyle(fontSize: 14),
                                  ),
                                ],
                              ],
                              if (expertReview['treatmentPlan']['precautions'] !=
                                  null) ...[
                                const SizedBox(height: 8),
                                Text(
                                  '${tr('precautions')} ${expertReview['treatmentPlan']['precautions']}',
                                  style: const TextStyle(fontSize: 14),
                                ),
                              ],
                            ],
                          ],
                        ),
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
                                tr('results'),
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
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
                                        ? '${TrackingModels.formatLabel(disease)} (${(confidence * 100).toStringAsFixed(1)}%)'
                                        : TrackingModels.formatLabel(disease),
                                    style: const TextStyle(fontSize: 15),
                                  ),
                                );
                              }).toList(),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text(tr('close')),
              ),
            ],
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final userBox = Hive.box('userBox');
    final userProfile = userBox.get('userProfile');
    final userId = userProfile?['userId'];
    if (userId == null) {
      return Center(child: Text(tr('not_logged_in')));
    }

    // Note: Real-time streams removed; we use a one-time load with offline cache.

    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _loadSessionsWithFallback(userId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.hasError) {
          return Scaffold(
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.wifi_off, size: 64, color: Colors.grey),
                  const SizedBox(height: 16),
                  Text(
                    tr('offline_mode'),
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    tr('showing_cached_data'),
                    style: TextStyle(color: Colors.grey[600], fontSize: 16),
                  ),
                ],
              ),
            ),
          );
        }

        final sessions = snapshot.data ?? [];
        // Note: Do not early-return on empty sessions; allow selector to show

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

        final filteredSessions = TrackingModels.filterSessions(
          sessions,
          _selectedRangeIndex,
          customStart: _customStartDate,
          customEnd: _customEndDate,
        );
        final flatScans = TrackingModels.flattenScans(filteredSessions);
        final chartData = TrackingChart.chartData(
          flatScans,
          _selectedRangeIndex,
          customStart: _customStartDate,
          customEnd: _customEndDate,
        );
        final overallCounts = TrackingModels.overallHealthyAndDiseases(
          flatScans,
        );
        final healthy = overallCounts['healthy'] ?? 0;
        final totalDiseased = TrackingModels.diseaseLabels.fold(
          0,
          (sum, d) => sum + (overallCounts[d] ?? 0),
        );
        final total = healthy + totalDiseased;
        final healthyPercent =
            total > 0 ? (healthy / total * 100).toStringAsFixed(1) : '0';
        final diseasedPercent =
            total > 0 ? (totalDiseased / total * 100).toStringAsFixed(1) : '0';

        return Scaffold(
          body: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Time range selector
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey[300]!, width: 1),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.03),
                          blurRadius: 4,
                          offset: Offset(0, 1),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.calendar_today,
                          size: 20,
                          color: Colors.green[700],
                        ),
                        const SizedBox(width: 12),
                        Text(
                          tr('time_range'),
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: DropdownButton<int>(
                            value: _selectedRangeIndex,
                            isExpanded: true,
                            underline: const SizedBox.shrink(),
                            items: [
                              DropdownMenuItem(
                                value: 0,
                                child: Text(
                                  _getTimeRangeLabel(0),
                                  style: const TextStyle(fontSize: 15),
                                ),
                              ),
                              DropdownMenuItem(
                                value: 1,
                                child: Text(
                                  _getTimeRangeLabel(1),
                                  style: const TextStyle(fontSize: 15),
                                ),
                              ),
                            ],
                            onChanged: (i) async {
                              if (i == null) return;
                              if (i == 1) {
                                await _pickCustomRange();
                              } else {
                                setState(() => _selectedRangeIndex = 0);
                                await _saveSelectedRangeIndex(0);
                              }
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (filteredSessions.isEmpty) ...[
                    Container(
                      margin: const EdgeInsets.only(bottom: 16),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey[300]!),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.info_outline, color: Colors.grey),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              tr('no_tracked_scans'),
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  // Friendly summary
                  Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [Colors.blue[50]!, Colors.green[50]!],
                      ),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.green[200]!, width: 1),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(20.0),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.green[100],
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(
                              Icons.insights,
                              color: Colors.green[700],
                              size: 28,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  tr('farm_health_summary'),
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.green[800],
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '${_getTimeRangeLabel(_selectedRangeIndex)}: $healthyPercent% healthy, $diseasedPercent% diseased.',
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w500,
                                    color: Colors.green[700],
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  tr('keep_tracking_message'),
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: Colors.green[600],
                                    fontStyle: FontStyle.italic,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  // Trend Bar Chart
                  Text(
                    tr('farm_health_trend'),
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
                            ? Center(child: Text(tr('not_enough_data')))
                            : LineChart(
                              LineChartData(
                                minY: 0,
                                maxY:
                                    chartData
                                        .expand(
                                          (m) => m.values.whereType<int>(),
                                        )
                                        .fold<double>(
                                          0,
                                          (prev, e) =>
                                              e > prev ? e.toDouble() : prev,
                                        ) *
                                    1.2,
                                lineBarsData: [
                                  // Healthy line
                                  LineChartBarData(
                                    spots: [
                                      for (int i = 0; i < chartData.length; i++)
                                        FlSpot(
                                          i.toDouble(),
                                          (chartData[i]['healthy'] as int?)
                                                  ?.toDouble() ??
                                              0,
                                        ),
                                    ],
                                    isCurved: true,
                                    color:
                                        TrackingModels.diseaseColors['healthy'],
                                    barWidth: 4,
                                    dotData: FlDotData(show: true),
                                    belowBarData: BarAreaData(show: false),
                                  ),
                                  // Disease lines
                                  for (final d in TrackingModels.diseaseLabels)
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
                                      color: TrackingModels.diseaseColors[d],
                                      barWidth: 4,
                                      dotData: FlDotData(show: true),
                                      belowBarData: BarAreaData(show: false),
                                    ),
                                ],
                                titlesData: FlTitlesData(
                                  show: true,
                                  bottomTitles: AxisTitles(
                                    sideTitles: SideTitles(
                                      showTitles: _selectedRangeIndex == 0,
                                      reservedSize:
                                          _selectedRangeIndex == 0 ? 48 : 0,
                                      getTitlesWidget: (value, meta) {
                                        if (value < 0 ||
                                            value >= chartData.length) {
                                          return const SizedBox.shrink();
                                        }
                                        final group =
                                            chartData[value.toInt()]['group']
                                                as String;
                                        Widget labelWidget;
                                        if (_selectedRangeIndex == 0) {
                                          int n = chartData.length > 24 ? 3 : 1;
                                          if (value.toInt() % n != 0 &&
                                              chartData.length > 12) {
                                            return const SizedBox.shrink();
                                          }
                                          if (group.length >= 7 &&
                                              group.contains('-')) {
                                            labelWidget = Transform.rotate(
                                              angle: -0.5708,
                                              child: Text(
                                                group.substring(5),
                                                style: const TextStyle(
                                                  fontSize: 12,
                                                ),
                                              ),
                                            );
                                          } else {
                                            labelWidget = Transform.rotate(
                                              angle: -0.5708,
                                              child: Text(
                                                group,
                                                style: const TextStyle(
                                                  fontSize: 12,
                                                ),
                                              ),
                                            );
                                          }
                                        } else if (_selectedRangeIndex >= 1 &&
                                            _selectedRangeIndex <= 4) {
                                          labelWidget = Transform.rotate(
                                            angle: -0.5708,
                                            child: Text(
                                              group,
                                              style: const TextStyle(
                                                fontSize: 12,
                                              ),
                                            ),
                                          );
                                        } else {
                                          final year = int.parse(
                                            group.substring(0, 4),
                                          );
                                          final month = int.parse(
                                            group.substring(5),
                                          );
                                          final monthAbbr = DateFormat(
                                            'MMM',
                                          ).format(DateTime(year, month));
                                          labelWidget = Transform.rotate(
                                            angle: -0.5708,
                                            child: Text(
                                              monthAbbr,
                                              style: const TextStyle(
                                                fontSize: 12,
                                              ),
                                            ),
                                          );
                                        }
                                        return Padding(
                                          padding: const EdgeInsets.only(
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
                                    sideTitles: SideTitles(showTitles: false),
                                  ),
                                  rightTitles: AxisTitles(
                                    sideTitles: SideTitles(showTitles: false),
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
                        TrackingChart.buildLegendItem(
                          TrackingModels.diseaseColors['healthy']!,
                          TrackingModels.formatLabel('healthy'),
                        ),
                        for (final d in TrackingModels.diseaseLabels)
                          TrackingChart.buildLegendItem(
                            TrackingModels.diseaseColors[d]!,
                            TrackingModels.formatLabel(d),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),
                  Text(
                    tr('history'),
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    tr(
                      'scans_from_period',
                      namedArgs: {
                        'period': _getTimeRangeLabel(_selectedRangeIndex),
                      },
                    ),
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: filteredSessions.length,
                    itemBuilder: (context, index) {
                      final session = filteredSessions[index];
                      final date =
                          session['date'] != null
                              ? DateFormat(
                                'MMM d, yyyy – h:mma',
                              ).format(DateTime.parse(session['date']))
                              : '';
                      final images = session['images'] as List? ?? [];

                      return Card(
                        margin: const EdgeInsets.symmetric(vertical: 6),
                        child: ListTile(
                          leading:
                              images.isNotEmpty &&
                                      images[0]['imageUrl'] != null &&
                                      (images[0]['imageUrl'] as String)
                                          .isNotEmpty
                                  ? CachedNetworkImage(
                                    imageUrl: images[0]['imageUrl'],
                                    width: 56,
                                    height: 56,
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
                                  )
                                  : images.isNotEmpty &&
                                      images[0]['imagePath'] != null
                                  ? Image.file(
                                    File(images[0]['imagePath']),
                                    width: 56,
                                    height: 56,
                                    fit: BoxFit.cover,
                                  )
                                  : const Icon(Icons.image, size: 56),
                          title: Text(tr('session', namedArgs: {'date': date})),
                          subtitle: Text(
                            tr(
                              'image_count',
                              namedArgs: {'count': images.length.toString()},
                            ),
                          ),
                          trailing: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: TrackingModels.getSourceColor(
                                session['source'],
                              ),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              TrackingModels.getSourceDisplayText(
                                session['source'],
                              ),
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                          ),
                          onLongPress:
                              session['source'] != 'completed' &&
                                      session['source'] != 'reviewed'
                                  ? () async {
                                    final confirm = await showDialog<bool>(
                                      context: context,
                                      builder:
                                          (context) => AlertDialog(
                                            title: Text(tr('delete_session')),
                                            content: Text(
                                              tr('delete_session_confirm'),
                                            ),
                                            actions: [
                                              TextButton(
                                                onPressed:
                                                    () => Navigator.of(
                                                      context,
                                                    ).pop(false),
                                                child: Text(tr('cancel')),
                                              ),
                                              TextButton(
                                                onPressed:
                                                    () => Navigator.of(
                                                      context,
                                                    ).pop(true),
                                                child: Text(
                                                  tr('delete'),
                                                  style: const TextStyle(
                                                    color: Colors.red,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                    );
                                    if (confirm == true) {
                                      final images =
                                          (session['images'] as List?) ?? [];
                                      bool imageDeleteError = false;
                                      for (final img in images) {
                                        try {
                                          final storagePath =
                                              img['storagePath'] as String?;
                                          final imageUrl =
                                              img['imageUrl'] as String?;

                                          if (storagePath != null &&
                                              storagePath.isNotEmpty) {
                                            // Preferred: delete by known storage path
                                            await FirebaseStorage.instance
                                                .ref()
                                                .child(storagePath)
                                                .delete();
                                          } else if (imageUrl != null &&
                                              imageUrl.isNotEmpty) {
                                            // If it's a Firebase URL, delete via URL
                                            if (imageUrl.startsWith('gs://') ||
                                                imageUrl.startsWith(
                                                  'https://firebasestorage.googleapis.com',
                                                )) {
                                              await FirebaseStorage.instance
                                                  .refFromURL(imageUrl)
                                                  .delete();
                                            } else {
                                              // Legacy Supabase cleanup (best-effort)
                                              final uri = Uri.parse(imageUrl);
                                              final segments = uri.pathSegments;
                                              final bucketIndex = segments
                                                  .indexOf('mangosense');
                                              if (bucketIndex != -1 &&
                                                  bucketIndex + 1 <
                                                      segments.length) {
                                                final supabase =
                                                    Supabase.instance.client;
                                                final supabasePath = segments
                                                    .sublist(bucketIndex + 1)
                                                    .join('/');
                                                await supabase.storage
                                                    .from('mangosense')
                                                    .remove([supabasePath]);
                                              }
                                            }
                                          }
                                        } catch (e) {
                                          imageDeleteError = true;
                                        }
                                      }
                                      try {
                                        if (session['source'] == 'pending') {
                                          final docId =
                                              session['sessionId'] ??
                                              session['id'];
                                          await FirebaseFirestore.instance
                                              .collection('scan_requests')
                                              .doc(docId)
                                              .delete();
                                        } else {
                                          final docId =
                                              session['sessionId'] ??
                                              session['id'];
                                          await FirebaseFirestore.instance
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
                                                    ? tr(
                                                      'session_deleted_with_errors',
                                                    )
                                                    : tr('session_deleted'),
                                              ),
                                              backgroundColor:
                                                  imageDeleteError
                                                      ? Colors.orange
                                                      : Colors.red,
                                            ),
                                          );
                                        }
                                      } catch (e) {
                                        if (context.mounted) {
                                          ScaffoldMessenger.of(
                                            context,
                                          ).showSnackBar(
                                            SnackBar(
                                              content: Text(
                                                tr(
                                                  'failed_to_delete_session',
                                                  args: [e.toString()],
                                                ),
                                              ),
                                              backgroundColor: Colors.red,
                                            ),
                                          );
                                        }
                                      }
                                    }
                                  }
                                  : null,
                          onTap: () => _showSessionDetails(session),
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
}
