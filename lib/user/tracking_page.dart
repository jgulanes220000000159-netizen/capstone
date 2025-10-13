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
  int _selectedRangeIndex = 0; // 0: Last 7 Days, 1: Monthly, 2: Custom
  DateTime? _customStartDate;
  DateTime? _customEndDate;
  int? _monthlyYear;
  int? _monthlyMonth; // 1-12

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
    final y = box.get('monthlyYear');
    final m = box.get('monthlyMonth');
    if (y is int && m is int) {
      _monthlyYear = y;
      _monthlyMonth = m;
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

  Future<void> _saveMonthly(int year, int month) async {
    final box = await Hive.openBox('trackingBox');
    await box.put('monthlyYear', year);
    await box.put('monthlyMonth', month);
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
              title: Text(tr('select_month_year')),
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
                  child: Text(tr('cancel')),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.pop(context, selectedDate),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2D7204),
                    foregroundColor: Colors.white,
                  ),
                  child: Text(tr('ok')),
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
    );
    if (picked != null) {
      setState(() {
        _customStartDate = picked.start;
        _customEndDate = picked.end;
        _selectedRangeIndex = 2; // Custom
      });
      await _saveSelectedRangeIndex(2);
      await _saveCustomRange(picked.start, picked.end);
    }
  }

  String _getTimeRangeLabel(int index) {
    switch (index) {
      case 0:
        return tr('last_7_days');
      case 1:
        if (_monthlyYear != null && _monthlyMonth != null) {
          final dt = DateTime(_monthlyYear!, _monthlyMonth!, 1);
          return DateFormat('MMMM yyyy').format(dt);
        }
        return tr('monthly');
      case 2:
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

  Widget _buildStatusCard(String label, int count, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.3), width: 1.5),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 8),
          Text(
            count.toString(),
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: Colors.grey[700],
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildDiseaseRow(
    String name,
    int count,
    int total,
    Color color,
    IconData icon,
  ) {
    final percentage = total > 0 ? (count / total * 100) : 0.0;
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.15),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                name,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[800],
                ),
              ),
              const SizedBox(height: 4),
              Stack(
                children: [
                  Container(
                    height: 8,
                    decoration: BoxDecoration(
                      color: Colors.grey[200],
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  FractionallySizedBox(
                    widthFactor: percentage / 100,
                    child: Container(
                      height: 8,
                      decoration: BoxDecoration(
                        color: color,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              count.toString(),
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            Text(
              '${percentage.toStringAsFixed(1)}%',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      ],
    );
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
          monthlyYear: _monthlyYear,
          monthlyMonth: _monthlyMonth,
        );
        final flatScans = TrackingModels.flattenScans(filteredSessions);
        final chartData = TrackingChart.chartData(
          flatScans,
          _selectedRangeIndex,
          customStart: _customStartDate,
          customEnd: _customEndDate,
          monthlyYear: _monthlyYear,
          monthlyMonth: _monthlyMonth,
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
                              DropdownMenuItem(
                                value: 2,
                                child: Text(
                                  _getTimeRangeLabel(2),
                                  style: const TextStyle(fontSize: 15),
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
                                  await _saveSelectedRangeIndex(1);
                                  await _saveMonthly(picked.year, picked.month);
                                } else {
                                  // User cancelled, revert to previous selection
                                  setState(() {});
                                }
                              } else if (i == 2) {
                                await _pickCustomRange();
                                // Force rebuild to show updated selection
                                setState(() {});
                              } else {
                                setState(() => _selectedRangeIndex = i);
                                await _saveSelectedRangeIndex(i);
                              }
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Scan Status Summary
                  Builder(
                    builder: (context) {
                      int pendingCount = 0;
                      int trackingCount = 0;
                      int completedCount = 0;

                      for (final session in filteredSessions) {
                        final status = session['status'] ?? session['source'];
                        if (status == 'pending' || status == 'pending_review') {
                          pendingCount++;
                        } else if (status == 'expert_review' ||
                            status == 'tracking') {
                          trackingCount++;
                        } else if (status == 'completed' ||
                            status == 'reviewed') {
                          completedCount++;
                        }
                      }

                      return Container(
                        margin: const EdgeInsets.only(bottom: 16),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey[200]!),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.04),
                              blurRadius: 6,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  Icons.analytics_outlined,
                                  color: Colors.green[700],
                                  size: 20,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  tr('scan_summary'),
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.grey[800],
                                  ),
                                ),
                                const Spacer(),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.green[50],
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    tr(
                                      'total_count',
                                      namedArgs: {
                                        'count':
                                            filteredSessions.length.toString(),
                                      },
                                    ),
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.green[700],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            Row(
                              children: [
                                Expanded(
                                  child: _buildStatusCard(
                                    tr('pending'),
                                    pendingCount,
                                    Icons.schedule,
                                    Colors.orange,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: _buildStatusCard(
                                    tr('tracking'),
                                    trackingCount,
                                    Icons.track_changes,
                                    Colors.blue,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: _buildStatusCard(
                                    tr('completed'),
                                    completedCount,
                                    Icons.check_circle,
                                    Colors.green,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      );
                    },
                  ),
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
                  // Disease Breakdown Summary
                  Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.grey[200]!, width: 1),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: Colors.green[50],
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Icon(
                                Icons.pie_chart,
                                color: Colors.green[700],
                                size: 24,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    tr('farm_health_breakdown'),
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.grey[800],
                                    ),
                                  ),
                                  Text(
                                    _getTimeRangeLabel(_selectedRangeIndex),
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.grey[100],
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                tr(
                                  'total_count',
                                  namedArgs: {'count': total.toString()},
                                ),
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.grey[800],
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        // Healthy count
                        _buildDiseaseRow(
                          'Healthy',
                          healthy,
                          total,
                          TrackingModels.diseaseColors['healthy']!,
                          Icons.check_circle,
                        ),
                        const SizedBox(height: 12),
                        // Individual diseases
                        for (final disease in TrackingModels.diseaseLabels)
                          if (overallCounts[disease] != null &&
                              overallCounts[disease]! > 0) ...[
                            _buildDiseaseRow(
                              TrackingModels.formatLabel(disease),
                              overallCounts[disease]!,
                              total,
                              TrackingModels.diseaseColors[disease]!,
                              Icons.warning_rounded,
                            ),
                            const SizedBox(height: 12),
                          ],
                      ],
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
                        child: InkWell(
                          onTap: () => _showSessionDetails(session),
                          child: ListTile(
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                            isThreeLine: true,
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
                            title: Text(
                              tr('session', namedArgs: {'date': date}),
                            ),
                            subtitle: Text(
                              tr(
                                'image_count',
                                namedArgs: {'count': images.length.toString()},
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            trailing: Column(
                              mainAxisSize: MainAxisSize.min,
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                if (session['source'] != 'completed' &&
                                    session['source'] != 'reviewed')
                                  InkWell(
                                    borderRadius: BorderRadius.circular(12),
                                    onTap: () async {
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
                                              if (imageUrl.startsWith(
                                                    'gs://',
                                                  ) ||
                                                  imageUrl.startsWith(
                                                    'https://firebasestorage.googleapis.com',
                                                  )) {
                                                await FirebaseStorage.instance
                                                    .refFromURL(imageUrl)
                                                    .delete();
                                              } else {
                                                // Legacy Supabase cleanup (best-effort)
                                                final uri = Uri.parse(imageUrl);
                                                final segments =
                                                    uri.pathSegments;
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
                                    },
                                    child: const Icon(
                                      Icons.delete,
                                      color: Colors.red,
                                      size: 22,
                                    ),
                                  ),
                                if (session['source'] != 'completed' &&
                                    session['source'] != 'reviewed')
                                  const SizedBox(height: 10),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 2,
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
                              ],
                            ),
                          ),
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
