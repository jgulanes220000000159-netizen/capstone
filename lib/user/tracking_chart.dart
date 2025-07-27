import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'tracking_models.dart';

class TrackingChart {
  // Helper to get the start date for the selected range
  static DateTime rangeStartDate(int selectedRangeIndex) {
    final days = TrackingModels.timeRanges[selectedRangeIndex]['days'] as int?;
    if (days == null) {
      // Show Everything: return a very early date
      return DateTime(1970);
    }
    final now = DateTime.now();
    return now.subtract(Duration(days: days - 1));
  }

  // Group scans for charting based on selected range
  static List<String> chartWeekLabels(int weeks) {
    return List.generate(weeks, (i) => 'W${i + 1}');
  }

  // Helper to get the last 12 months ending with the current month
  static List<String> last12Months(DateTime now) {
    return List.generate(12, (i) {
      final d = DateTime(now.year, now.month - 11 + i, 1);
      return DateFormat('yyyy-MM').format(d);
    });
  }

  // Aggregate chart data for the selected range
  static List<Map<String, dynamic>> chartData(
    List<Map<String, dynamic>> scans,
    int selectedRangeIndex,
  ) {
    final start = rangeStartDate(selectedRangeIndex);
    final now = DateTime.now();
    // Show Everything: group by month (or by year if >24 months)
    if (selectedRangeIndex == 0) {
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
              ...{for (var d in TrackingModels.diseaseLabels) d: 0},
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
          } else if (TrackingModels.isRealDisease(label)) {
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
              ...{for (var d in TrackingModels.diseaseLabels) d: 0},
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
          } else if (TrackingModels.isRealDisease(label)) {
            data[groupKey]![label] = (data[groupKey]![label] ?? 0) + 1;
          }
        }
        return months.map((m) => {'group': m, ...data[m]!}).toList();
      }
    }
    // Last 7 days: group by day
    if (selectedRangeIndex == 1) {
      final groups = List.generate(7, (i) {
        final d = start.add(Duration(days: i));
        return DateFormat('yyyy-MM-dd').format(d);
      });
      final Map<String, Map<String, int>> data = {
        for (final g in groups)
          g: {
            'healthy': 0,
            ...{for (var d in TrackingModels.diseaseLabels) d: 0},
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
        } else if (TrackingModels.isRealDisease(label)) {
          data[groupKey]![label] = (data[groupKey]![label] ?? 0) + 1;
        }
      }
      return groups.map((g) => {'group': g, ...data[g]!}).toList();
    }
    // Last 30/60/90 days: group by week
    if (selectedRangeIndex >= 2 && selectedRangeIndex <= 4) {
      final days = TrackingModels.timeRanges[selectedRangeIndex]['days'] as int;
      final weeks = (days / 7).ceil();
      // Defensive: ensure weekLabels and chartData are always the same length
      final weekLabels = chartWeekLabels(weeks);
      final List<Map<String, dynamic>> chartData = List.generate(
        weekLabels.length,
        (i) => {
          'group': weekLabels[i],
          'healthy': 0,
          ...{for (var d in TrackingModels.diseaseLabels) d: 0},
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
        } else if (TrackingModels.isRealDisease(label)) {
          chartData[weekIndex][label] =
              (chartData[weekIndex][label] as int) + 1;
        }
      }
      return chartData;
    }
    // Last year: group by month
    if (selectedRangeIndex == 5) {
      final months = last12Months(now);
      final Map<String, Map<String, int>> data = {
        for (final m in months)
          m: {
            'healthy': 0,
            ...{for (var d in TrackingModels.diseaseLabels) d: 0},
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
        } else if (TrackingModels.isRealDisease(label)) {
          data[groupKey]![label] = (data[groupKey]![label] ?? 0) + 1;
        }
      }
      return months.map((m) => {'group': m, ...data[m]!}).toList();
    }
    // fallback
    return [];
  }

  static Widget buildLegendItem(Color color, String label) {
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
