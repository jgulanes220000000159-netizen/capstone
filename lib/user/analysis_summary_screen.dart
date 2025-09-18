import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'dart:io';
// import 'dart:convert';
// import 'package:path_provider/path_provider.dart';
// import 'package:uuid/uuid.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:hive/hive.dart';
import 'package:image/image.dart' as img;
import 'tflite_detector.dart';
import 'detection_painter.dart';
import 'detection_screen.dart';
// import 'detection_carousel_screen.dart';
import 'detection_result_card.dart';
// import 'tracking_page.dart';
// import '../shared/user_profile.dart';
// import '../shared/review_manager.dart';

class AnalysisSummaryScreen extends StatefulWidget {
  final Map<int, List<DetectionResult>> allResults;
  final List<String> imagePaths;

  const AnalysisSummaryScreen({
    Key? key,
    required this.allResults,
    required this.imagePaths,
  }) : super(key: key);

  @override
  State<AnalysisSummaryScreen> createState() => _AnalysisSummaryScreenState();
}

class _AnalysisSummaryScreenState extends State<AnalysisSummaryScreen> {
  final Map<String, Size> imageSizes = {};
  bool showBoundingBoxes = false;
  bool _isSubmitting = false;
  // final ReviewManager _reviewManager = ReviewManager();

  @override
  void initState() {
    super.initState();
    // sync from persistent preference used across farmer screens
    Future.microtask(() async {
      final box = await Hive.openBox('userBox');
      final pref = box.get('showBoundingBoxes');
      if (pref is bool && mounted) {
        setState(() {
          showBoundingBoxes = pref;
        });
      }
    });
  }

  Map<String, int> _getOverallDiseaseCount() {
    final Map<String, int> counts = {};
    for (var results in widget.allResults.values) {
      for (var result in results) {
        counts[result.label] = (counts[result.label] ?? 0) + 1;
      }
    }
    return counts;
  }

  double _getDiseasePercentage(String disease, Map<String, int> diseaseCounts) {
    final totalLeaves = diseaseCounts.values.fold(0, (a, b) => a + b);
    if (totalLeaves == 0) return 0;
    return diseaseCounts[disease]! / totalLeaves;
  }

  Future<void> _loadImageSizes() async {
    for (int index = 0; index < widget.imagePaths.length; index++) {
      final image = File(widget.imagePaths[index]);
      final decodedImage = await image.readAsBytes();
      final imageInfo = await img.decodeImage(decodedImage);
      if (mounted) {
        setState(() {
          imageSizes[widget.imagePaths[index]] = Size(
            imageInfo!.width.toDouble(),
            imageInfo.height.toDouble(),
          );
        });
      }
    }
  }

  void _showSendingDialog(BuildContext context, String message) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder:
          (context) => Dialog(
            backgroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(width: 24),
                  Flexible(
                    child: Text(
                      message,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
    );
  }

  Future<void> _sendForExternalReview() async {
    print('DEBUG: _sendForExternalReview called');
    setState(() {
      _isSubmitting = true;
    });
    _showSendingDialog(context, tr('sending_to_expert'));
    try {
      // final _userProfile = UserProfile();
      final user = FirebaseAuth.instance.currentUser;
      final userId = user?.uid ?? 'unknown';
      // final _reviewManager = ReviewManager();

      // --- Upload images to Firebase Storage and get URLs ---
      final List<Map<String, String>> uploadedImages = [];
      for (int i = 0; i < widget.imagePaths.length; i++) {
        final file = File(widget.imagePaths[i]);
        final fileName =
            '${userId}_${DateTime.now().millisecondsSinceEpoch}_$i.jpg';
        final storagePath = 'leaf/$fileName';
        final ref = FirebaseStorage.instance.ref().child(storagePath);
        await ref.putFile(file);
        final downloadUrl = await ref.getDownloadURL();
        uploadedImages.add({'url': downloadUrl, 'path': storagePath});
      }

      // Convert detection results to the format expected by ReviewManager
      final detections = <Map<String, dynamic>>[];
      for (var i = 0; i < widget.allResults.length; i++) {
        final results = widget.allResults[i] ?? [];
        for (var result in results) {
          detections.add({
            'disease': result.label,
            'confidence': result.confidence,
            'imageUrl': uploadedImages[i]['url'],
            'boundingBox': {
              'left': result.boundingBox.left,
              'top': result.boundingBox.top,
              'right': result.boundingBox.right,
              'bottom': result.boundingBox.bottom,
            },
          });
        }
      }

      // Convert disease counts to the format expected by ReviewManager
      final Map<String, int> diseaseLabelCounts = {};
      widget.allResults.values.forEach((results) {
        for (var result in results) {
          diseaseLabelCounts[result.label] =
              (diseaseLabelCounts[result.label] ?? 0) + 1;
        }
      });
      final diseaseCounts =
          diseaseLabelCounts.entries.map((entry) {
            return {
              'name': _formatLabel(entry.key),
              'label': entry.key,
              'count': entry.value,
            };
          }).toList();

      // --- Also add to tracking (history) ---
      final box = await Hive.openBox('trackingBox');
      final List sessions = box.get('scans', defaultValue: []);
      final now = DateTime.now().toIso8601String();
      final sessionId = DateTime.now().millisecondsSinceEpoch.toString();
      final List<Map<String, dynamic>> images = [];
      for (int i = 0; i < widget.imagePaths.length; i++) {
        final results = widget.allResults[i] ?? [];
        List<Map<String, dynamic>> resultList = [];
        if (results.isNotEmpty) {
          for (var result in results) {
            resultList.add({
              'disease': result.label,
              'confidence': result.confidence,
              'boundingBox': {
                'left': result.boundingBox.left,
                'top': result.boundingBox.top,
                'right': result.boundingBox.right,
                'bottom': result.boundingBox.bottom,
              },
            });
          }
        } else {
          resultList.add({'disease': 'Unknown', 'confidence': null});
        }

        // Get actual image dimensions for accurate offline bounding box positioning
        final imageFile = File(widget.imagePaths[i]);
        final imageBytes = await imageFile.readAsBytes();
        final imageInfo = await img.decodeImage(imageBytes);
        final imageWidth = imageInfo!.width.toDouble();
        final imageHeight = imageInfo.height.toDouble();

        // Save network URL and dimensions for proper caching
        images.add({
          'imageUrl': uploadedImages[i]['url'],
          'storagePath': uploadedImages[i]['path'],
          'imageWidth': imageWidth, // Add actual image width
          'imageHeight': imageHeight, // Add actual image height
          'results': resultList,
        });
      }
      sessions.add({
        'sessionId': sessionId,
        'date': now,
        'images': images,
        'source': 'expert_review',
      });
      await box.put('scans', sessions);
      print('DEBUG: sessions after add (review): ' + sessions.toString());
      // --- Upload to Firestore scan_requests collection ---
      // Get full name from Hive userBox
      final userBox = await Hive.openBox('userBox');
      final userProfile = userBox.get('userProfile');
      final fullName = userProfile?['fullName'] ?? 'Unknown';
      await FirebaseFirestore.instance
          .collection('scan_requests')
          .doc(sessionId)
          .set({
            'id': sessionId,
            'userId': userId,
            'userName': fullName,
            'status': 'pending',
            'submittedAt': now,
            'images': images, // This now includes both imageUrl and imagePath
            'diseaseSummary':
                diseaseCounts
                    .map((e) => {'name': e['name'], 'count': e['count']})
                    .toList(),
            // No expertReview yet
          });
      // --- End add to tracking ---

      if (mounted) {
        Navigator.of(context, rootNavigator: true).pop(); // Dismiss dialog
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(tr('analysis_sent_successfully')),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsets.only(bottom: 70, left: 16, right: 16),
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.all(Radius.circular(12)),
            ),
            duration: const Duration(seconds: 2),
          ),
        );
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
    } catch (e) {
      if (mounted) {
        Navigator.of(context, rootNavigator: true).pop(); // Dismiss dialog
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              tr('error_sending_for_review', namedArgs: {'error': '$e'}),
            ),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsets.only(bottom: 70, left: 16, right: 16),
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.all(Radius.circular(12)),
            ),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  // String _getSeverityLevel(String disease) {
  //   final avgConfidence = _getDiseasePercentage(
  //     disease,
  //     _getOverallDiseaseCount(),
  //   );
  //   if (avgConfidence > 0.8) return 'high';
  //   if (avgConfidence > 0.5) return 'medium';
  //   return 'low';
  // }

  String _formatLabel(String label) {
    switch (label.toLowerCase()) {
      case 'backterial_blackspot':
        return 'Bacterial black spot';
      case 'powdery_mildew':
        return 'Powdery Mildew';
      case 'tip_burn':
        return 'Tip Burn';
      default:
        return label
            .split('_')
            .map((word) => word[0].toUpperCase() + word.substring(1))
            .join(' ');
    }
  }

  Widget _buildDiseaseSummaryCard(
    String disease,
    int count,
    Map<String, int> diseaseCounts,
  ) {
    final color = DetectionPainter.diseaseColors[disease] ?? Colors.grey;
    final percentage = _getDiseasePercentage(disease, diseaseCounts);
    final isHealthy = disease.toLowerCase() == 'healthy';
    final isUnknown = disease.toLowerCase() == 'tip_burn';

    if (isUnknown) {
      // Use DetectionResultCard for Unknown (tip_burn)
      return DetectionResultCard(
        result: DetectionResult(
          label: 'tip_burn',
          confidence: percentage,
          boundingBox: Rect.zero,
        ),
        count: count,
        percentage: percentage,
      );
    }

    return Card(
      elevation: 4,
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap: () {
          if (!isHealthy) {
            _showDiseaseRecommendations(context, disease);
          } else {
            _showHealthyStatus(context);
          }
        },
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: color.withOpacity(0.5)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Center(
                      child: Icon(Icons.check_circle, size: 16, color: color),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _formatLabel(disease),
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      tr('found_count', namedArgs: {'count': '$count'}),
                      style: TextStyle(
                        color: color,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          tr('percentage_of_total_leaves'),
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 4),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: LinearProgressIndicator(
                            value: percentage,
                            backgroundColor: color.withOpacity(0.1),
                            valueColor: AlwaysStoppedAnimation<Color>(color),
                            minHeight: 8,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    '${(percentage * 100).toStringAsFixed(1)}%',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: color,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      isHealthy || disease.toLowerCase() == 'tip_burn'
                          ? Icons.info_outline
                          : Icons.medical_services_outlined,
                      color: color,
                      size: disease.toLowerCase() == 'tip_burn' ? 18 : 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      isHealthy || disease.toLowerCase() == 'tip_burn'
                          ? tr('not_applicable')
                          : tr('see_recommendation'),
                      style: TextStyle(
                        color: color,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Disease information (copied from homepage)
  static const Map<String, Map<String, dynamic>> diseaseInfo = {
    'anthracnose': {
      'symptoms': [
        'Irregular black or brown spots that expand and merge, leading to necrosis and leaf drop (Li et al., 2024).',
      ],
      'treatments': [
        'Apply copper-based fungicides like copper oxychloride or Mancozeb during wet and humid conditions to prevent spore germination.',
        'Prune mango trees regularly to improve air circulation and reduce humidity around foliage.',
        'Remove and burn infected leaves to limit reinfection cycles.',
      ],
    },
    'powdery_mildew': {
      'symptoms': [
        'A white, powdery fungal coating forms on young mango leaves, leading to distortion, yellowing, and reduced photosynthesis (Nasir, 2016).',
      ],
      'treatments': [
        'Use sulfur-based or systemic fungicides like tebuconazole at the first sign of infection and repeat at 10–14-day intervals.',
        'Avoid overhead irrigation which increases humidity and spore spread on leaf surfaces.',
        'Remove heavily infected leaves to reduce fungal load.',
      ],
    },
    'dieback': {
      'symptoms': [
        'Browning of leaf tips, followed by downward necrosis and eventual branch dieback (Ploetz, 2003).',
      ],
      'treatments': [
        'Prune affected twigs at least 10 cm below the last symptom to halt pathogen progression.',
        'Apply systemic fungicides such as carbendazim to protect surrounding healthy leaves.',
        'Maintain plant vigor through balanced nutrition and irrigation to resist infection.',
      ],
    },
    'backterial_blackspot': {
      'symptoms': [
        'Angular black lesions with yellow halos often appear along veins and can lead to early leaf drop (Ploetz, 2003).',
      ],
      'treatments': [
        'Apply copper hydroxide or copper oxychloride sprays to suppress bacterial activity on the leaf surface.',
        'Remove and properly dispose of infected leaves to reduce inoculum sources.',
        'Avoid causing wounds on leaves during handling, as these can be entry points for bacteria.',
      ],
    },
    'healthy': {
      'symptoms': [
        'Vibrant green leaves without spots or lesions',
        'Normal growth pattern',
        'No visible signs of disease or pest damage',
      ],
      'treatments': [
        'Regular monitoring for early detection of problems',
        'Maintain proper irrigation and fertilization',
        'Practice good orchard sanitation',
      ],
    },
    'tip_burn': {
      'symptoms': [
        'The tips and edges of leaves turn brown and dry, often due to non-pathogenic causes such as nutrient imbalance or salt injury (Gardening Know How, n.d.).',
      ],
      'treatments': [
        'Ensure consistent, deep watering to avoid drought stress that can worsen tip burn symptoms.',
        'Avoid excessive use of nitrogen-rich or saline fertilizers which may lead to root toxicity and leaf damage.',
        'Supplement calcium or potassium via foliar feeding if nutrient deficiency is suspected.',
        'Conduct regular soil testing to detect salinity or imbalance that might affect leaf health.',
      ],
    },
  };

  void _showDiseaseRecommendations(BuildContext context, String disease) {
    final label = disease.toLowerCase();
    final info = diseaseInfo[label];
    final isHealthy = label == 'healthy';
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder:
          (context) => DraggableScrollableSheet(
            initialChildSize: 0.7,
            minChildSize: 0.5,
            maxChildSize: 0.95,
            expand: false,
            builder:
                (context, scrollController) => SingleChildScrollView(
                  controller: scrollController,
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              isHealthy
                                  ? Icons.check_circle
                                  : Icons.medical_services_outlined,
                              color:
                                  isHealthy
                                      ? Colors.green
                                      : DetectionPainter
                                              .diseaseColors[disease] ??
                                          Colors.grey,
                              size: 24,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                _formatLabel(disease),
                                style: const TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.close),
                              onPressed: () => Navigator.pop(context),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        if (info != null) ...[
                          Text(
                            tr('symptoms'),
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          ...info['symptoms'].map<Widget>(
                            (s) => Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: Text(
                                '• $s',
                                style: const TextStyle(fontSize: 15),
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            tr('treatment_and_recommendations'),
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          ...info['treatments'].map<Widget>(
                            (t) => Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: Text(
                                '• $t',
                                style: const TextStyle(fontSize: 15),
                              ),
                            ),
                          ),
                        ] else ...[
                          Text(tr('no_detailed_information')),
                        ],
                      ],
                    ),
                  ),
                ),
          ),
    );
  }

  void _showHealthyStatus(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder:
          (context) => DraggableScrollableSheet(
            initialChildSize: 0.7,
            minChildSize: 0.5,
            maxChildSize: 0.95,
            expand: false,
            builder:
                (context, scrollController) => SingleChildScrollView(
                  controller: scrollController,
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.check_circle,
                              color: Colors.green,
                              size: 24,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                tr('healthy_leaves'),
                                style: TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.close),
                              onPressed: () => Navigator.pop(context),
                            ),
                          ],
                        ),
                        const SizedBox(height: 40),
                        Center(
                          child: Text(
                            tr('not_applicable'),
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: Colors.grey,
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Center(
                          child: Text(
                            tr('no_additional_info_healthy_leaves'),
                            style: TextStyle(fontSize: 16, color: Colors.grey),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
          ),
    );
  }

  // Widget _buildStatusSection(String title, List<String> items) {
  //   return Column(
  //     crossAxisAlignment: CrossAxisAlignment.start,
  //     children: [
  //       Text(
  //         title,
  //         style: const TextStyle(
  //           fontSize: 16,
  //           fontWeight: FontWeight.bold,
  //           color: Colors.green,
  //         ),
  //       ),
  //       const SizedBox(height: 8),
  //       ...items.map(
  //         (item) => Padding(
  //           padding: const EdgeInsets.only(bottom: 8),
  //           child: Row(
  //             crossAxisAlignment: CrossAxisAlignment.start,
  //             children: [
  //               const Icon(
  //                 Icons.check_circle_outline,
  //                 size: 20,
  //                 color: Colors.green,
  //               ),
  //               const SizedBox(width: 8),
  //               Expanded(
  //                 child: Text(item, style: const TextStyle(fontSize: 14)),
  //               ),
  //             ],
  //           ),
  //         ),
  //       ),
  //     ],
  //   );
  // }

  Widget _buildImageGrid() {
    if (showBoundingBoxes && imageSizes.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
      ),
      itemCount: widget.imagePaths.length,
      itemBuilder: (context, index) {
        final imagePath = widget.imagePaths[index];
        final results = widget.allResults[index] ?? [];
        final imageSize = imageSizes[imagePath] ?? const Size(1, 1);

        return GestureDetector(
          onTap: () {
            showDialog(
              context: context,
              barrierDismissible: true,
              builder:
                  (context) => Dialog(
                    insetPadding: EdgeInsets.zero,
                    backgroundColor: Colors.black,
                    child: Stack(
                      children: [
                        DetectionScreen(
                          imagePath: imagePath,
                          results: results,
                          imageSize: imageSize,
                          allImagePaths: widget.imagePaths,
                          currentIndex: index,
                          allResults: widget.allResults.values.toList(),
                          imageSizes:
                              widget.imagePaths
                                  .map(
                                    (path) =>
                                        imageSizes[path] ?? const Size(1, 1),
                                  )
                                  .toList(),
                          showAppBar: false,
                        ),
                        Positioned(
                          top: 24,
                          left: 16,
                          child: Material(
                            color: Colors.transparent,
                            child: Ink(
                              decoration: BoxDecoration(
                                color: Colors.black.withOpacity(0.6),
                                shape: BoxShape.circle,
                              ),
                              child: IconButton(
                                icon: const Icon(
                                  Icons.arrow_back,
                                  color: Colors.white,
                                  size: 32,
                                ),
                                onPressed: () => Navigator.of(context).pop(),
                                tooltip: tr('back'),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
            );
          },
          child: LayoutBuilder(
            builder: (context, constraints) {
              final widgetW = constraints.maxWidth;
              final widgetH = constraints.maxHeight;
              final imgW = imageSize.width;
              final imgH = imageSize.height;
              if (imgW == 0 || imgH == 0) {
                return const Center(child: CircularProgressIndicator());
              }
              // Calculate scale and offset for BoxFit.cover
              final widgetAspect = widgetW / widgetH;
              final imageAspect = imgW / imgH;
              double displayW, displayH, dx = 0, dy = 0;
              if (widgetAspect > imageAspect) {
                // Widget is wider than image
                displayW = widgetW;
                displayH = widgetW / imageAspect;
                dy = (widgetH - displayH) / 2;
              } else {
                // Widget is taller than image
                displayH = widgetH;
                displayW = widgetH * imageAspect;
                dx = (widgetW - displayW) / 2;
              }
              final displayedImageSize = Size(displayW, displayH);
              final displayedImageOffset = Offset(dx, dy);
              return Stack(
                fit: StackFit.expand,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.file(File(imagePath), fit: BoxFit.cover),
                  ),
                  if (showBoundingBoxes &&
                      results.isNotEmpty &&
                      imageSizes.isNotEmpty)
                    CustomPaint(
                      painter: DetectionPainter(
                        results: results,
                        originalImageSize: imageSize,
                        displayedImageSize: displayedImageSize,
                        displayedImageOffset: displayedImageOffset,
                      ),
                      size: Size(widgetW, widgetH),
                    ),
                  if (results.isNotEmpty)
                    Positioned(
                      top: 8,
                      right: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.5),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '${results.length}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
        );
      },
    );
  }

  // Add this method to handle 'Add to Tracking' logic
  Future<void> _addToTracking() async {
    print('DEBUG: _addToTracking called');
    setState(() {
      _isSubmitting = true;
    });
    _showSendingDialog(context, tr('adding_to_tracking'));
    try {
      // final _userProfile = UserProfile();
      final user = FirebaseAuth.instance.currentUser;
      final userId = user?.uid ?? 'unknown';
      final box = await Hive.openBox('trackingBox');
      final List sessions = box.get('scans', defaultValue: []);
      final now = DateTime.now().toIso8601String();
      final sessionId = DateTime.now().millisecondsSinceEpoch.toString();
      final List<Map<String, dynamic>> images = [];
      // --- Upload images to Firebase Storage and get URLs ---
      final List<Map<String, String>> uploadedImages2 = [];
      for (int i = 0; i < widget.imagePaths.length; i++) {
        final file = File(widget.imagePaths[i]);
        final fileName =
            '${userId}_${DateTime.now().millisecondsSinceEpoch}_$i.jpg';
        final storagePath = 'leaf/$fileName';
        final ref = FirebaseStorage.instance.ref().child(storagePath);
        await ref.putFile(file);
        final downloadUrl = await ref.getDownloadURL();
        uploadedImages2.add({'url': downloadUrl, 'path': storagePath});
      }
      for (int i = 0; i < widget.imagePaths.length; i++) {
        final results = widget.allResults[i] ?? [];
        List<Map<String, dynamic>> resultList = [];
        if (results.isNotEmpty) {
          for (var result in results) {
            resultList.add({
              'disease': result.label,
              'confidence': result.confidence,
            });
          }
        } else {
          resultList.add({'disease': 'Unknown', 'confidence': null});
        }
        images.add({
          'imageUrl': uploadedImages2[i]['url'],
          'storagePath': uploadedImages2[i]['path'],
          'results': resultList,
        });
      }
      sessions.add({
        'sessionId': sessionId,
        'date': now,
        'images': images,
        'source': 'tracking',
      });
      await box.put('scans', sessions);
      print('DEBUG: sessions after add: ' + sessions.toString());
      // --- Upload to Firestore tracking collection ---
      await FirebaseFirestore.instance
          .collection('tracking')
          .doc(sessionId)
          .set({
            'sessionId': sessionId,
            'date': now,
            'images': images,
            'source': 'tracking',
            'userId': userId,
          });
      // --- End upload to Firestore ---
      if (mounted) {
        Navigator.of(context, rootNavigator: true).pop(); // Dismiss dialog
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(tr('analysis_added_to_tracking')),
            backgroundColor: Colors.blue,
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsets.only(bottom: 70, left: 16, right: 16),
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.all(Radius.circular(12)),
            ),
            duration: const Duration(seconds: 2),
          ),
        );
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
    } catch (e) {
      if (mounted) {
        Navigator.of(context, rootNavigator: true).pop(); // Dismiss dialog
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              tr('error_adding_to_tracking', namedArgs: {'error': '$e'}),
            ),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsets.only(bottom: 70, left: 16, right: 16),
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.all(Radius.circular(12)),
            ),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final diseaseCounts = _getOverallDiseaseCount();
    final totalDetections = diseaseCounts.values.fold(0, (a, b) => a + b);
    // Kick off image size loading only when needed (first build), avoid blocking transition
    if (showBoundingBoxes && imageSizes.isEmpty) {
      // Defer loading sizes to next microtask to avoid layout jank
      Future.microtask(() => _loadImageSizes());
    }

    // Sort diseases by percentage in descending order
    final sortedDiseases =
        diseaseCounts.entries.toList()..sort((a, b) {
          final percentageA = _getDiseasePercentage(a.key, diseaseCounts);
          final percentageB = _getDiseasePercentage(b.key, diseaseCounts);
          return percentageB.compareTo(percentageA);
        });

    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: Text(tr('analysis_summary')),
        centerTitle: true,
        backgroundColor: Colors.green,
        elevation: 0,
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0),
            child: Ink(
              decoration: BoxDecoration(
                color: showBoundingBoxes ? Colors.green[700] : Colors.grey[300],
                shape: BoxShape.circle,
              ),
              child: IconButton(
                onPressed: () async {
                  setState(() {
                    showBoundingBoxes = !showBoundingBoxes;
                  });
                  // persist same as detail page for consistency
                  final box = await Hive.openBox('userBox');
                  await box.put('showBoundingBoxes', showBoundingBoxes);
                },
                icon: Icon(Icons.visibility, color: Colors.white),
                tooltip:
                    showBoundingBoxes
                        ? tr('hide_bounding_boxes')
                        : tr('show_bounding_boxes'),
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    color: Colors.white,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    tr('total_images'),
                                    style: TextStyle(
                                      color: Colors.grey[600],
                                      fontSize: 14,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '${widget.imagePaths.length}',
                                    style: const TextStyle(
                                      fontSize: 24,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              width: 1,
                              height: 40,
                              color: Colors.grey[300],
                            ),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    tr('total_leaves'),
                                    style: TextStyle(
                                      color: Colors.grey[600],
                                      fontSize: 14,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '$totalDetections',
                                    style: const TextStyle(
                                      fontSize: 24,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          tr('analyzed_images'),
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey[800],
                          ),
                        ),
                        const SizedBox(height: 8),
                        _buildImageGrid(),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      tr('disease_summary'),
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey[800],
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.all(16),
                    color: Colors.white,
                    child: Column(
                      children: [
                        ...sortedDiseases.map((entry) {
                          return _buildDiseaseSummaryCard(
                            entry.key,
                            entry.value,
                            diseaseCounts,
                          );
                        }).toList(),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar:
          !_isSubmitting
              ? Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 10,
                      offset: const Offset(0, -5),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: SizedBox(
                        height: 50,
                        child: ElevatedButton.icon(
                          onPressed: _addToTracking,
                          icon: const Icon(Icons.save),
                          label: Text(tr('add_to_tracking')),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.grey[700],
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: SizedBox(
                        height: 50,
                        child: ElevatedButton.icon(
                          onPressed: _sendForExternalReview,
                          icon: const Icon(Icons.send),
                          label: Text(tr('send_for_review')),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              )
              : null,
    );
  }
}
