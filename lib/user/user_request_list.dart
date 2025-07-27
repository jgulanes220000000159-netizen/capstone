import 'package:flutter/material.dart';
import '../shared/review_manager.dart';
import 'dart:io';
import 'dart:async';
import 'package:easy_localization/easy_localization.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:hive/hive.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'detection_painter.dart';
import 'tflite_detector.dart';

final List<Map<String, dynamic>> userRequests = [
  {
    'requestId': 'REQ_001',
    'userId': 'USER_001',
    'userName': 'Maria Santos',
    'submittedAt': '2024-06-10 09:15',
    'status': 'completed',
    'images': [
      {
        'path': 'assets/diseases/backterial_blackspot1.jpg',
        'detections': [
          {
            'label': 'Bacterial Blackspot',
            'confidence': 0.95,
            'boundingBox': {
              'left': 0.1,
              'top': 0.1,
              'right': 0.3,
              'bottom': 0.3,
            },
          },
          {
            'label': 'Healthy',
            'confidence': 0.90,
            'boundingBox': {
              'left': 0.4,
              'top': 0.4,
              'right': 0.6,
              'bottom': 0.6,
            },
          },
        ],
      },
      {
        'path': 'assets/diseases/healthy1.jpg',
        'detections': [
          {
            'label': 'Bacterial Blackspot',
            'confidence': 0.88,
            'boundingBox': {
              'left': 0.2,
              'top': 0.2,
              'right': 0.4,
              'bottom': 0.4,
            },
          },
          {
            'label': 'Healthy',
            'confidence': 0.85,
            'boundingBox': {
              'left': 0.5,
              'top': 0.5,
              'right': 0.7,
              'bottom': 0.7,
            },
          },
        ],
      },
      {
        'path': 'assets/diseases/healthy2.jpg',
        'detections': [
          {
            'label': 'Bacterial Blackspot',
            'confidence': 0.92,
            'boundingBox': {
              'left': 0.3,
              'top': 0.3,
              'right': 0.5,
              'bottom': 0.5,
            },
          },
        ],
      },
      {
        'path': 'assets/diseases/backterial_blackspot.jpg',
        'detections': [
          {
            'label': 'Bacterial Blackspot',
            'confidence': 0.90,
            'boundingBox': {
              'left': 0.4,
              'top': 0.4,
              'right': 0.6,
              'bottom': 0.6,
            },
          },
        ],
      },
      {
        'path': 'assets/diseases/healthy3.jpg',
        'detections': [
          {
            'label': 'Bacterial Blackspot',
            'confidence': 0.89,
            'boundingBox': {
              'left': 0.5,
              'top': 0.5,
              'right': 0.7,
              'bottom': 0.7,
            },
          },
        ],
      },
    ],
    'diseaseSummary': [
      {
        'name': 'Bacterial Blackspot',
        'count': 2,
        'averageConfidence': 0.50, // 2 out of 4 leaves = 50%
        'severity': 'high',
      },
      {
        'name': 'Healthy',
        'count': 2,
        'averageConfidence': 0.50, // 2 out of 4 leaves = 50%
        'severity': 'low',
      },
    ],
    'expertReview': {
      'expertId': 'EXP_001',
      'expertName': 'Dr. Jose Garcia',
      'reviewedAt': '2024-06-10 11:05',
      'comment':
          'Severe bacterial blackspot infection detected. Immediate treatment required.',
      'severityAssessment': {
        'level': 'high',
        'confidence': 0.50, // Updated to match the percentage
        'notes': 'Expert assessment based on image analysis',
      },
      'treatmentPlan': {
        'recommendations': [
          {
            'treatment': 'Copper-based fungicide treatment',
            'dosage': '2-3 ml per liter of water',
            'frequency': 'Every 7-10 days',
            'precautions':
                'Apply early morning or late evening. Avoid application before rain. Wear gloves and mask during application.',
          },
        ],
        'preventiveMeasures': [
          'Regular pruning',
          'Proper spacing between plants',
          'Adequate ventilation',
          'Remove infected leaves promptly',
        ],
      },
    },
  },
  {
    'requestId': 'REQ_002',
    'userId': 'USER_001',
    'userName': 'Maria Santos',
    'submittedAt': '2024-06-10 10:22',
    'status': 'pending_review',
    'images': [
      {
        'path': 'assets/diseases/powdery_mildew1.jpg',
        'detections': [
          {
            'label': 'Powdery Mildew',
            'confidence': 0.75,
            'boundingBox': {
              'left': 0.1,
              'top': 0.1,
              'right': 0.3,
              'bottom': 0.3,
            },
          },
          {
            'label': 'Healthy',
            'confidence': 0.85,
            'boundingBox': {
              'left': 0.4,
              'top': 0.4,
              'right': 0.6,
              'bottom': 0.6,
            },
          },
        ],
      },
      {
        'path': 'assets/diseases/powdery_mildew2.jpg',
        'detections': [
          {
            'label': 'Powdery Mildew',
            'confidence': 0.68,
            'boundingBox': {
              'left': 0.6,
              'top': 0.3,
              'right': 0.5,
              'bottom': 0.5,
            },
          },
          {
            'label': 'Healthy',
            'confidence': 0.92,
            'boundingBox': {
              'left': 0.7,
              'top': 0.7,
              'right': 0.9,
              'bottom': 0.9,
            },
          },
        ],
      },
      {
        'path': 'assets/diseases/powdery_mildew3.jpg',
        'detections': [
          {
            'label': 'Powdery Mildew',
            'confidence': 0.72,
            'boundingBox': {
              'left': 0.3,
              'top': 0.2,
              'right': 0.4,
              'bottom': 0.4,
            },
          },
          {
            'label': 'Healthy',
            'confidence': 0.88,
            'boundingBox': {
              'left': 0.5,
              'top': 0.5,
              'right': 0.7,
              'bottom': 0.7,
            },
          },
        ],
      },
    ],
    'diseaseSummary': [
      {
        'name': 'Powdery Mildew',
        'count': 3,
        'averageConfidence': 0.50, // 3 out of 6 leaves = 50%
        'severity': 'medium',
      },
      {
        'name': 'Healthy',
        'count': 3,
        'averageConfidence': 0.50, // 3 out of 6 leaves = 50%
        'severity': 'low',
      },
    ],
    'expertReview': null,
  },
  {
    'requestId': 'REQ_003',
    'userId': 'USER_001',
    'userName': 'Maria Santos',
    'submittedAt': '2024-06-11 08:00',
    'status': 'pending_review',
    'images': [
      {
        'path': 'assets/diseases/anthracnose1.jpg',
        'detections': [
          {
            'label': 'Anthracnose',
            'confidence': 0.82,
            'boundingBox': {
              'left': 0.1,
              'top': 0.1,
              'right': 0.3,
              'bottom': 0.3,
            },
          },
        ],
      },
      {
        'path': 'assets/diseases/anthracnose2.jpg',
        'detections': [
          {
            'label': 'Anthracnose',
            'confidence': 0.78,
            'boundingBox': {
              'left': 0.2,
              'top': 0.2,
              'right': 0.4,
              'bottom': 0.4,
            },
          },
        ],
      },
    ],
    'diseaseSummary': [
      {
        'name': 'Anthracnose',
        'count': 2,
        'averageConfidence': 0.82,
        'severity': 'low',
      },
    ],
    'expertReview': null,
  },
];

String _formatExpertLabel(String label) {
  switch (label.toLowerCase()) {
    case 'backterial_blackspot':
    case 'bacterial blackspot':
      return 'Bacterial black spot';
    case 'powdery_mildew':
    case 'powdery mildew':
      return 'Powdery Mildew';
    case 'tip_burn':
    case 'tip burn':
      return 'Unknown';
    default:
      return label
          .split('_')
          .map((word) => word[0].toUpperCase() + word.substring(1))
          .join(' ');
  }
}

class UserRequestList extends StatefulWidget {
  final List<Map<String, dynamic>> requests;
  const UserRequestList({Key? key, required this.requests}) : super(key: key);

  @override
  State<UserRequestList> createState() => _UserRequestListState();
}

class _UserRequestListState extends State<UserRequestList> {
  bool _showBoundingBoxes = true;

  @override
  void initState() {
    super.initState();
    _loadBoundingBoxPreference();
  }

  Future<void> _loadBoundingBoxPreference() async {
    final box = await Hive.openBox('userBox');
    final savedPreference = box.get('showBoundingBoxes');
    if (savedPreference != null) {
      setState(() {
        _showBoundingBoxes = savedPreference as bool;
      });
    }
  }

  Future<void> _saveBoundingBoxPreference(bool value) async {
    final box = await Hive.openBox('userBox');
    await box.put('showBoundingBoxes', value);
  }

  Future<Size> _getImageSize(ImageProvider imageProvider) async {
    final ImageStream stream = imageProvider.resolve(ImageConfiguration.empty);
    final Completer<Size> completer = Completer<Size>();

    stream.addListener(
      ImageStreamListener((ImageInfo info, bool _) {
        completer.complete(
          Size(info.image.width.toDouble(), info.image.height.toDouble()),
        );
      }),
    );

    return completer.future;
  }

  Widget _buildImageWidgetWithBoundingBoxes(
    String path,
    List detections, {
    double? width,
    double? height,
    BoxFit fit = BoxFit.cover,
  }) {
    if (!_showBoundingBoxes || detections.isEmpty) {
      return _buildImageWidget(path, width: width, height: height, fit: fit);
    }

    return FutureBuilder<Size>(
      future: _getImageSize(
        path.startsWith('http') ? NetworkImage(path) : FileImage(File(path)),
      ),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return _buildImageWidget(
            path,
            width: width,
            height: height,
            fit: fit,
          );
        }

        final imageSize = snapshot.data!;
        final widgetSize = Size(width ?? 80, height ?? 80);

        // Calculate scaling for BoxFit.cover
        final scaleX = widgetSize.width / imageSize.width;
        final scaleY = widgetSize.height / imageSize.height;
        final scale = scaleX > scaleY ? scaleX : scaleY;

        final scaledW = imageSize.width * scale;
        final scaledH = imageSize.height * scale;
        final dx = (widgetSize.width - scaledW) / 2;
        final dy = (widgetSize.height - scaledH) / 2;

        return Stack(
          children: [
            _buildImageWidget(path, width: width, height: height, fit: fit),
            CustomPaint(
              painter: DetectionPainter(
                results:
                    detections
                        .map((d) {
                          if (d == null ||
                              d['disease'] == null ||
                              d['boundingBox'] == null) {
                            return null;
                          }
                          return DetectionResult(
                            label: d['disease'].toString(),
                            confidence:
                                (d['confidence'] as num?)?.toDouble() ?? 0.0,
                            boundingBox: Rect.fromLTRB(
                              (d['boundingBox']['left'] as num).toDouble(),
                              (d['boundingBox']['top'] as num).toDouble(),
                              (d['boundingBox']['right'] as num).toDouble(),
                              (d['boundingBox']['bottom'] as num).toDouble(),
                            ),
                          );
                        })
                        .whereType<DetectionResult>()
                        .toList(),
                originalImageSize: imageSize,
                displayedImageSize: Size(scaledW, scaledH),
                displayedImageOffset: Offset(dx, dy),
              ),
              size: widgetSize,
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    // Sort requests by submittedAt descending (most recent first)
    final sortedRequests = [...widget.requests];
    sortedRequests.sort((a, b) {
      final dateA =
          a['submittedAt'] != null && a['submittedAt'].toString().isNotEmpty
              ? DateTime.tryParse(a['submittedAt'].toString())
              : null;
      final dateB =
          b['submittedAt'] != null && b['submittedAt'].toString().isNotEmpty
              ? DateTime.tryParse(b['submittedAt'].toString())
              : null;
      if (dateA == null && dateB == null) return 0;
      if (dateA == null) return 1;
      if (dateB == null) return -1;
      return dateB.compareTo(dateA); // Descending
    });
    return Column(
      children: [
        // Bounding box toggle
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              const Text('Show Bounding Boxes', style: TextStyle(fontSize: 14)),
              const SizedBox(width: 8),
              Switch(
                value: _showBoundingBoxes,
                onChanged: (value) async {
                  setState(() {
                    _showBoundingBoxes = value;
                  });
                  await _saveBoundingBoxPreference(value);
                },
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: sortedRequests.length,
            itemBuilder: (context, index) {
              final request = sortedRequests[index];
              return _buildRequestCard(request);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildRequestCard(Map<String, dynamic> request) {
    final diseaseSummary = (request['diseaseSummary'] as List?) ?? [];
    final mainDisease =
        (diseaseSummary.isNotEmpty && diseaseSummary[0]['name'] != null)
            ? diseaseSummary[0]['name'] as String
            : 'Unknown';
    final status = request['status']?.toString() ?? 'pending';
    final submittedAt = request['submittedAt']?.toString() ?? '';
    // Format date
    final formattedDate =
        submittedAt.isNotEmpty && DateTime.tryParse(submittedAt) != null
            ? DateFormat(
              'MMM d, yyyy – h:mma',
            ).format(DateTime.parse(submittedAt))
            : submittedAt;
    final reviewedAt = request['reviewedAt']?.toString() ?? '';
    final isCompleted = status == 'completed';
    final images = (request['images'] as List?) ?? [];
    final totalImages = images.length;
    final totalDetections = diseaseSummary.length;
    // Use imageUrl if present and not empty, else imagePath, else path
    final imageUrl = images.isNotEmpty ? (images[0]['imageUrl'] ?? '') : '';
    final imagePath =
        images.isNotEmpty
            ? (images[0]['imagePath'] ?? images[0]['path'] ?? '')
            : '';
    final displayPath = (imageUrl.isNotEmpty) ? imageUrl : imagePath;
    print('Loading image: $displayPath');
    if (displayPath.isNotEmpty) {
      if (_isFilePath(displayPath)) {
        print('File exists: ${File(displayPath).existsSync()}');
      }
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 2,
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => UserRequestDetail(request: request),
            ),
          );
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: _buildImageWidgetWithBoundingBoxes(
                      displayPath,
                      images.isNotEmpty
                          ? (images[0]['results'] as List?) ?? []
                          : [],
                      width: 80,
                      height: 80,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${_formatExpertLabel(mainDisease)} Detection',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          formattedDate,
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color:
                                status == 'completed'
                                    ? Colors.green.withOpacity(0.1)
                                    : Colors.orange.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            _formatStatusLabel(status),
                            style: TextStyle(
                              color:
                                  status == 'completed'
                                      ? Colors.green
                                      : Colors.orange,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (status == 'pending' || status == 'pending_review')
                    IconButton(
                      icon: const Icon(Icons.delete, color: Colors.red),
                      tooltip: 'Delete Report',
                      onPressed: () async {
                        final confirm = await showDialog<bool>(
                          context: context,
                          builder:
                              (context) => AlertDialog(
                                title: const Text('Delete Report'),
                                content: const Text(
                                  'Are you sure you want to delete this report? This action cannot be undone.',
                                ),
                                actions: [
                                  TextButton(
                                    onPressed:
                                        () => Navigator.of(context).pop(false),
                                    child: const Text('Cancel'),
                                  ),
                                  TextButton(
                                    onPressed:
                                        () => Navigator.of(context).pop(true),
                                    child: const Text(
                                      'Delete',
                                      style: TextStyle(color: Colors.red),
                                    ),
                                  ),
                                ],
                              ),
                        );
                        if (confirm == true) {
                          final docId = request['id'] ?? request['requestId'];
                          final images = (request['images'] as List?) ?? [];
                          final supabase = Supabase.instance.client;
                          bool imageDeleteError = false;
                          for (final img in images) {
                            final imageUrl = img['imageUrl'] ?? '';
                            if (imageUrl is String && imageUrl.isNotEmpty) {
                              // Extract storage path from public URL
                              final uri = Uri.parse(imageUrl);
                              final segments = uri.pathSegments;
                              // Find the index of 'mangosense' and get the rest as the storage path
                              final bucketIndex = segments.indexOf(
                                'mangosense',
                              );
                              if (bucketIndex != -1 &&
                                  bucketIndex + 1 < segments.length) {
                                final storagePath = segments
                                    .sublist(bucketIndex + 1)
                                    .join('/');
                                try {
                                  await supabase.storage
                                      .from('mangosense')
                                      .remove([storagePath]);
                                } catch (e) {
                                  imageDeleteError = true;
                                }
                              }
                            }
                          }
                          try {
                            await FirebaseFirestore.instance
                                .collection('scan_requests')
                                .doc(docId)
                                .delete();
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    imageDeleteError
                                        ? 'Report deleted, but some images could not be removed from storage.'
                                        : 'Report deleted successfully!',
                                  ),
                                  backgroundColor:
                                      imageDeleteError
                                          ? Colors.orange
                                          : Colors.red,
                                ),
                              );
                              setState(() {
                                widget.requests.removeWhere(
                                  (r) => (r['id'] ?? r['requestId']) == docId,
                                );
                              });
                            }
                          } catch (e) {
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Failed to delete report: $e'),
                                  backgroundColor: Colors.red,
                                ),
                              );
                            }
                          }
                        }
                      },
                    ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _buildStatItem(
                      'Images',
                      totalImages.toString(),
                      Icons.image,
                    ),
                  ),
                  Container(width: 1, height: 40, color: Colors.grey[300]),
                  Expanded(
                    child: _buildStatItem(
                      'Detections',
                      totalDetections.toString(),
                      Icons.search,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatStatusLabel(String status) {
    switch (status) {
      case 'pending_review':
        return 'Pending';
      case 'completed':
        return 'Completed';
      default:
        return status[0].toUpperCase() +
            status.substring(1).replaceAll('_', ' ');
    }
  }

  Widget _buildStatItem(String label, String value, IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          Icon(icon, color: Colors.grey[600], size: 20),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          Text(label, style: TextStyle(color: Colors.grey[600], fontSize: 12)),
        ],
      ),
    );
  }
}

class UserRequestDetail extends StatefulWidget {
  final Map<String, dynamic> request;
  const UserRequestDetail({Key? key, required this.request}) : super(key: key);

  @override
  _UserRequestDetailState createState() => _UserRequestDetailState();
}

class _UserRequestDetailState extends State<UserRequestDetail> {
  bool _showBoundingBoxes = true;

  @override
  void initState() {
    super.initState();
    _loadBoundingBoxPreference();
  }

  Future<void> _loadBoundingBoxPreference() async {
    final box = await Hive.openBox('userBox');
    final savedPreference = box.get('showBoundingBoxes');
    if (savedPreference != null) {
      setState(() {
        _showBoundingBoxes = savedPreference as bool;
      });
    }
  }

  Future<void> _saveBoundingBoxPreference(bool value) async {
    final box = await Hive.openBox('userBox');
    await box.put('showBoundingBoxes', value);
  }

  Widget build(BuildContext context) {
    final diseaseSummary = (widget.request['diseaseSummary'] as List?) ?? [];
    final mainDisease =
        (diseaseSummary.isNotEmpty && diseaseSummary[0]['name'] != null)
            ? diseaseSummary[0]['name']
            : 'Unknown';
    final status = widget.request['status'] ?? '';
    final submittedAt = widget.request['submittedAt'] ?? '';
    // Format date
    final formattedDate =
        submittedAt.isNotEmpty && DateTime.tryParse(submittedAt) != null
            ? DateFormat(
              'MMM d, yyyy – h:mma',
            ).format(DateTime.parse(submittedAt))
            : submittedAt;
    final reviewedAt = widget.request['reviewedAt'] ?? '';
    // Format reviewed date
    final formattedReviewedDate =
        reviewedAt.isNotEmpty && DateTime.tryParse(reviewedAt) != null
            ? DateFormat(
              'MMM d, yyyy – h:mma',
            ).format(DateTime.parse(reviewedAt))
            : reviewedAt;
    final expertReview = widget.request['expertReview'];
    final expertName = widget.request['expertName'] ?? '';
    final isCompleted = status == 'completed';
    final images = (widget.request['images'] as List?) ?? [];

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.green,
        title: const Text(
          'Request Details',
          style: TextStyle(color: Colors.white),
        ),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // User and timestamp info
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: Card(
                color: Colors.grey[50],
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 0,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    vertical: 12,
                    horizontal: 16,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(
                            Icons.person,
                            size: 18,
                            color: Colors.green,
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              'Your Request',
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: Colors.green,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          const Icon(
                            Icons.schedule,
                            size: 16,
                            color: Colors.grey,
                          ),
                          const SizedBox(width: 4),
                          const Text(
                            'Submitted:',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.black54,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            formattedDate,
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.grey,
                            ),
                          ),
                        ],
                      ),
                      if (isCompleted && reviewedAt.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            const Icon(
                              Icons.check_circle,
                              size: 16,
                              color: Colors.green,
                            ),
                            const SizedBox(width: 4),
                            const Text(
                              'Reviewed:',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.black54,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              formattedReviewedDate,
                              style: const TextStyle(
                                fontSize: 12,
                                color: Colors.green,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
            // Images Grid
            if (images.isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Submitted Images',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            const Text(
                              'Show Bounding Boxes',
                              style: TextStyle(fontSize: 14),
                            ),
                            const SizedBox(width: 8),
                            Switch(
                              value: _showBoundingBoxes,
                              onChanged: (value) async {
                                setState(() {
                                  _showBoundingBoxes = value;
                                });
                                await _saveBoundingBoxPreference(value);
                              },
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            crossAxisSpacing: 8,
                            mainAxisSpacing: 8,
                          ),
                      itemCount: images.length,
                      itemBuilder: (context, idx) {
                        final img = images[idx];
                        final imageUrl = img['imageUrl'] ?? '';
                        final imagePath = img['imagePath'] ?? img['path'] ?? '';
                        final displayPath =
                            (imageUrl.isNotEmpty) ? imageUrl : imagePath;
                        final detections = (img['results'] as List?) ?? [];
                        return GestureDetector(
                          onTap: () {
                            showDialog(
                              context: context,
                              builder:
                                  (context) => Dialog(
                                    backgroundColor: Colors.transparent,
                                    insetPadding: const EdgeInsets.all(16),
                                    child: LayoutBuilder(
                                      builder: (context, constraints) {
                                        final imageWidth = constraints.maxWidth;
                                        final imageHeight =
                                            constraints.maxHeight;
                                        return Stack(
                                          children: [
                                            ClipRRect(
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                              child: _buildImageWidget(
                                                displayPath,
                                                width: imageWidth,
                                                height: imageHeight,
                                                fit: BoxFit.contain,
                                              ),
                                            ),
                                            if (_showBoundingBoxes &&
                                                detections.isNotEmpty)
                                              FutureBuilder<Size>(
                                                future: _getImageSize(
                                                  imageUrl.isNotEmpty
                                                      ? NetworkImage(imageUrl)
                                                      : FileImage(
                                                        File(imagePath),
                                                      ),
                                                ),
                                                builder: (context, snapshot) {
                                                  if (!snapshot.hasData) {
                                                    return const SizedBox.shrink();
                                                  }
                                                  final imageSize =
                                                      snapshot.data!;
                                                  return CustomPaint(
                                                    painter: DetectionPainter(
                                                      results:
                                                          detections
                                                              .where(
                                                                (d) =>
                                                                    d['boundingBox'] !=
                                                                    null,
                                                              )
                                                              .map(
                                                                (
                                                                  d,
                                                                ) => DetectionResult(
                                                                  label:
                                                                      d['disease'],
                                                                  confidence:
                                                                      d['confidence'],
                                                                  boundingBox: Rect.fromLTRB(
                                                                    d['boundingBox']['left'],
                                                                    d['boundingBox']['top'],
                                                                    d['boundingBox']['right'],
                                                                    d['boundingBox']['bottom'],
                                                                  ),
                                                                ),
                                                              )
                                                              .toList(),
                                                      originalImageSize:
                                                          imageSize,
                                                      displayedImageSize:
                                                          imageSize,
                                                      displayedImageOffset:
                                                          Offset.zero,
                                                    ),
                                                    size: imageSize,
                                                  );
                                                },
                                              ),
                                            Positioned(
                                              top: 8,
                                              right: 8,
                                              child: IconButton(
                                                icon: const Icon(
                                                  Icons.close,
                                                  color: Colors.white,
                                                ),
                                                onPressed:
                                                    () =>
                                                        Navigator.pop(context),
                                              ),
                                            ),
                                          ],
                                        );
                                      },
                                    ),
                                  ),
                            );
                          },
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: _buildImageWidget(
                                  displayPath,
                                  fit: BoxFit.cover,
                                ),
                              ),
                              if (_showBoundingBoxes && detections.isNotEmpty)
                                FutureBuilder<Size>(
                                  future: _getImageSize(
                                    imageUrl.isNotEmpty
                                        ? NetworkImage(imageUrl)
                                        : FileImage(File(imagePath)),
                                  ),
                                  builder: (context, snapshot) {
                                    if (!snapshot.hasData) {
                                      return const SizedBox.shrink();
                                    }
                                    final imageSize = snapshot.data!;
                                    return LayoutBuilder(
                                      builder: (context, constraints) {
                                        // Calculate the actual displayed image size
                                        final imgW = imageSize.width;
                                        final imgH = imageSize.height;
                                        final widgetW = constraints.maxWidth;
                                        final widgetH = constraints.maxHeight;

                                        // Calculate scale and offset for BoxFit.cover
                                        final scale =
                                            imgW / imgH > widgetW / widgetH
                                                ? widgetH /
                                                    imgH // Height constrained
                                                : widgetW /
                                                    imgW; // Width constrained

                                        final scaledW = imgW * scale;
                                        final scaledH = imgH * scale;
                                        final dx = (widgetW - scaledW) / 2;
                                        final dy = (widgetH - scaledH) / 2;

                                        return CustomPaint(
                                          painter: DetectionPainter(
                                            results:
                                                detections
                                                    .map((d) {
                                                      if (d == null ||
                                                          d['disease'] ==
                                                              null ||
                                                          d['confidence'] ==
                                                              null ||
                                                          d['boundingBox'] ==
                                                              null ||
                                                          d['boundingBox']['left'] ==
                                                              null ||
                                                          d['boundingBox']['top'] ==
                                                              null ||
                                                          d['boundingBox']['right'] ==
                                                              null ||
                                                          d['boundingBox']['bottom'] ==
                                                              null) {
                                                        return null;
                                                      }
                                                      return DetectionResult(
                                                        label:
                                                            d['disease']
                                                                .toString(),
                                                        confidence:
                                                            (d['confidence']
                                                                    as num)
                                                                .toDouble(),
                                                        boundingBox: Rect.fromLTRB(
                                                          (d['boundingBox']['left']
                                                                  as num)
                                                              .toDouble(),
                                                          (d['boundingBox']['top']
                                                                  as num)
                                                              .toDouble(),
                                                          (d['boundingBox']['right']
                                                                  as num)
                                                              .toDouble(),
                                                          (d['boundingBox']['bottom']
                                                                  as num)
                                                              .toDouble(),
                                                        ),
                                                      );
                                                    })
                                                    .whereType<
                                                      DetectionResult
                                                    >()
                                                    .toList(),
                                            originalImageSize: imageSize,
                                            displayedImageSize: Size(
                                              scaledW,
                                              scaledH,
                                            ),
                                            displayedImageOffset: Offset(
                                              dx,
                                              dy,
                                            ),
                                          ),
                                          size: Size(widgetW, widgetH),
                                        );
                                      },
                                    );
                                  },
                                ),
                              Positioned(
                                top: 8,
                                right: 8,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.black.withOpacity(0.7),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    detections.isNotEmpty
                                        ? '${detections.length} Detection${detections.length > 1 ? 's' : ''}'
                                        : 'No Detections',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                    ),
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
            // Disease Summary
            Padding(
              padding: const EdgeInsets.all(16),
              child: Builder(
                builder: (context) {
                  final mergedSummary = _mergeDiseaseSummary(diseaseSummary);
                  final totalLeaves = mergedSummary.fold<int>(
                    0,
                    (sum, d) => sum + (d['count'] as int? ?? 0),
                  );
                  final sortedSummary = [...mergedSummary]..sort((a, b) {
                    final percA =
                        totalLeaves == 0
                            ? 0.0
                            : (a['count'] as int? ?? 0) / totalLeaves;
                    final percB =
                        totalLeaves == 0
                            ? 0.0
                            : (b['count'] as int? ?? 0) / totalLeaves;
                    return percB.compareTo(percA);
                  });
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Disease Summary',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                      ...sortedSummary.map<Widget>((disease) {
                        final diseaseName =
                            (disease['disease'] ?? disease['name'] ?? 'Unknown')
                                .toString();
                        final count = disease['count'] ?? 0;
                        final percentage =
                            totalLeaves == 0 ? 0.0 : count / totalLeaves;
                        final color = _getExpertDiseaseColor(diseaseName);
                        final isHealthy =
                            diseaseName.toLowerCase() == 'healthy';
                        return Card(
                          margin: const EdgeInsets.only(bottom: 12),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
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
                                        child: Icon(
                                          isHealthy
                                              ? Icons.check_circle
                                              : Icons.local_florist,
                                          size: 16,
                                          color: color,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Text(
                                        _formatExpertLabel(diseaseName),
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
                                        '$count found',
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
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'Percentage of Total Leaves',
                                            style: TextStyle(
                                              color: Colors.grey[600],
                                              fontSize: 14,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          ClipRRect(
                                            borderRadius: BorderRadius.circular(
                                              10,
                                            ),
                                            child: LinearProgressIndicator(
                                              value: percentage,
                                              backgroundColor: color
                                                  .withOpacity(0.1),
                                              valueColor:
                                                  AlwaysStoppedAnimation<Color>(
                                                    color,
                                                  ),
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
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                    ],
                  );
                },
              ),
            ),
            // Expert Review Section
            if (isCompleted && expertReview != null)
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.person, color: Colors.green, size: 18),
                        const SizedBox(width: 6),
                        Text(
                          'Reviewed by: ${expertName.isNotEmpty ? expertName : 'Expert'}',
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            color: Colors.green,
                            fontSize: 15,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Expert Review',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Severity Assessment
                    if (expertReview['severityAssessment'] != null)
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Severity Assessment',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  Icon(
                                    Icons.warning,
                                    color: _getSeverityColor(
                                      expertReview['severityAssessment']['level'] ??
                                          'low',
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    (expertReview['severityAssessment']['level'] ??
                                            'low')
                                        .toString()
                                        .toUpperCase(),
                                    style: TextStyle(
                                      color: _getSeverityColor(
                                        expertReview['severityAssessment']['level'] ??
                                            'low',
                                      ),
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    const SizedBox(height: 16),
                    // Treatment Plan
                    if (expertReview['treatmentPlan'] != null)
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Treatment Plan',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 8),
                              ...((expertReview['treatmentPlan']['recommendations']
                                          as List?) ??
                                      [])
                                  .map<Widget>((treatment) {
                                    return Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        if (treatment['treatment'] != null)
                                          Padding(
                                            padding: const EdgeInsets.only(
                                              bottom: 4,
                                            ),
                                            child: Text(
                                              'Treatment: ${treatment['treatment']}',
                                              style: const TextStyle(
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                          ),
                                        if (treatment['dosage'] != null)
                                          Padding(
                                            padding: const EdgeInsets.only(
                                              bottom: 4,
                                            ),
                                            child: Text(
                                              'Dosage: ${treatment['dosage']}',
                                            ),
                                          ),
                                        if (treatment['frequency'] != null)
                                          Padding(
                                            padding: const EdgeInsets.only(
                                              bottom: 4,
                                            ),
                                            child: Text(
                                              'Frequency: ${treatment['frequency']}',
                                            ),
                                          ),
                                        if (treatment['precautions'] != null)
                                          Padding(
                                            padding: const EdgeInsets.only(
                                              bottom: 4,
                                            ),
                                            child: Text(
                                              'Precautions: ${treatment['precautions']}',
                                            ),
                                          ),
                                        const SizedBox(height: 8),
                                      ],
                                    );
                                  })
                                  .toList(),
                            ],
                          ),
                        ),
                      ),
                    const SizedBox(height: 16),
                    // Preventive Measures
                    if (expertReview['treatmentPlan']?['preventiveMeasures'] !=
                        null)
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Preventive Measures',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children:
                                    ((expertReview['treatmentPlan']['preventiveMeasures']
                                                as List?) ??
                                            [])
                                        .map<Widget>((measure) {
                                          return Chip(
                                            label: Text(measure.toString()),
                                            backgroundColor: Colors.green
                                                .withOpacity(0.1),
                                          );
                                        })
                                        .toList(),
                              ),
                            ],
                          ),
                        ),
                      ),
                    const SizedBox(height: 16),
                    // Expert Comment
                    if (expertReview['comment'] != null)
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Expert Comment',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                expertReview['comment'],
                                style: const TextStyle(
                                  fontSize: 15,
                                  color: Colors.black87,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              )
            else if (!isCompleted)
              const Padding(
                padding: EdgeInsets.all(16),
                child: Center(
                  child: Text(
                    'Awaiting expert review...',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.orange,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Color _getSeverityColor(String severity) {
    switch (severity.toLowerCase()) {
      case 'high':
        return Colors.red;
      case 'medium':
        return Colors.orange;
      case 'low':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  Color _getExpertDiseaseColor(String diseaseName) {
    switch (diseaseName.toLowerCase()) {
      case 'anthracnose':
        return Colors.orange;
      case 'backterial_blackspot':
      case 'bacterial blackspot':
      case 'bacterial black spot':
        return Colors.purple;
      case 'dieback':
        return Colors.red;
      case 'healthy':
        return const Color.fromARGB(255, 2, 119, 252);
      case 'powdery_mildew':
      case 'powdery mildew':
        return const Color.fromARGB(255, 9, 46, 2);
      case 'tip_burn':
      case 'tip burn':
        return Colors.brown;
      default:
        return Colors.grey;
    }
  }

  List<Map<String, dynamic>> _mergeDiseaseSummary(List<dynamic> summary) {
    final Map<String, Map<String, dynamic>> merged = {};
    for (final entry in summary) {
      final rawName = entry['disease'] ?? entry['name'] ?? 'Unknown';
      final disease =
          rawName.toString().toLowerCase().replaceAll('_', ' ').trim();
      final count = entry['count'] ?? 0;
      if (!merged.containsKey(disease)) {
        merged[disease] = {'disease': rawName, 'count': count};
      } else {
        merged[disease]!['count'] += count;
      }
    }
    return merged.values.toList();
  }

  Future<Size> _getImageSize(ImageProvider provider) async {
    final Completer<Size> completer = Completer();
    final ImageStreamListener listener = ImageStreamListener((
      ImageInfo info,
      bool _,
    ) {
      final myImage = info.image;
      completer.complete(
        Size(myImage.width.toDouble(), myImage.height.toDouble()),
      );
    });
    provider.resolve(const ImageConfiguration()).addListener(listener);
    final size = await completer.future;
    return size;
  }
}

class UserRequestTabbedList extends StatefulWidget {
  const UserRequestTabbedList({Key? key}) : super(key: key);

  @override
  State<UserRequestTabbedList> createState() => _UserRequestTabbedListState();
}

class _UserRequestTabbedListState extends State<UserRequestTabbedList>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  final ReviewManager _reviewManager = ReviewManager();

  // Add missing _buildSearchBar method
  Widget _buildSearchBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 2,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: tr('search'),
              prefixIcon: const Icon(Icons.search, color: Colors.grey),
              suffixIcon:
                  _searchQuery.isNotEmpty
                      ? IconButton(
                        icon: const Icon(Icons.clear, color: Colors.grey),
                        onPressed: () {
                          setState(() {
                            _searchController.clear();
                            _searchQuery = '';
                          });
                        },
                      )
                      : null,
              filled: true,
              fillColor: Colors.grey[50],
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(vertical: 0),
            ),
            onChanged: (value) {
              setState(() {
                _searchQuery = value;
              });
            },
          ),
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Text(
              tr('try_searching_for'),
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  List<Map<String, dynamic>> _filterRequests(
    List<Map<String, dynamic>> requests,
  ) {
    if (_searchQuery.isEmpty) return requests;

    return requests.where((request) {
      final diseaseName =
          request['diseaseSummary'][0]['name']?.toString().toLowerCase() ?? '';
      final status = request['status']?.toString().toLowerCase() ?? '';
      final submittedAt =
          request['submittedAt']?.toString().toLowerCase() ?? '';
      final query = _searchQuery.toLowerCase();

      return diseaseName.contains(query) ||
          status.contains(query) ||
          submittedAt.contains(query);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const Center(child: Text('Not logged in'));
    }

    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _loadRequestsWithFallback(user.uid),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return _buildWithOfflineFallback();
        }

        final allRequests = snapshot.data ?? [];
        if (allRequests.isEmpty) {
          return Column(
            children: [
              _buildSearchBar(),
              Container(
                color: Colors.green,
                child: TabBar(
                  controller: _tabController,
                  indicatorColor: Colors.white,
                  labelColor: Colors.white,
                  unselectedLabelColor: Colors.white70,
                  tabs: [Tab(text: tr('pending')), Tab(text: tr('completed'))],
                ),
              ),
              Expanded(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.description_outlined,
                        size: 64,
                        color: Colors.grey,
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'No requests yet',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Start scanning to see your requests here',
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        }

        final pending = _filterRequests(
          allRequests.where((r) => r['status'] == 'pending').toList(),
        );
        final completed = _filterRequests(
          allRequests.where((r) => r['status'] == 'completed').toList(),
        );
        return Column(
          children: [
            _buildSearchBar(),
            Container(
              color: Colors.green,
              child: TabBar(
                controller: _tabController,
                indicatorColor: Colors.white,
                labelColor: Colors.white,
                unselectedLabelColor: Colors.white70,
                tabs: [Tab(text: tr('pending')), Tab(text: tr('completed'))],
              ),
            ),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  pending.isEmpty
                      ? _buildEmptyState(
                        _searchQuery.isNotEmpty
                            ? 'No pending requests found for "$_searchQuery"'
                            : 'No pending requests',
                      )
                      : Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: UserRequestList(requests: pending),
                      ),
                  completed.isEmpty
                      ? _buildEmptyState(
                        _searchQuery.isNotEmpty
                            ? 'No completed requests found for "$_searchQuery"'
                            : 'No completed requests',
                      )
                      : Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: UserRequestList(requests: completed),
                      ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  // Cache requests to Hive for offline access
  Future<void> _cacheRequestsToHive(List<Map<String, dynamic>> requests) async {
    try {
      final box = await Hive.openBox('userRequestsBox');
      await box.put('cachedRequests', requests);
      await box.put('lastUpdated', DateTime.now().toIso8601String());
    } catch (e) {
      print('Error caching requests to Hive: $e');
    }
  }

  // Load requests with fallback to cached data
  Future<List<Map<String, dynamic>>> _loadRequestsWithFallback(
    String userId,
  ) async {
    try {
      // Try to load from Firestore first
      final query =
          await FirebaseFirestore.instance
              .collection('scan_requests')
              .where('userId', isEqualTo: userId)
              .get();

      final allRequests =
          query.docs.map((doc) => doc.data() as Map<String, dynamic>).toList();

      // Cache requests to Hive for offline access
      await _cacheRequestsToHive(allRequests);

      return allRequests;
    } catch (e) {
      print('Error loading from Firestore: $e');
      // Fallback to local Hive data
      return await _loadCachedRequests();
    }
  }

  // Load cached requests from Hive for offline access
  Future<List<Map<String, dynamic>>> _loadCachedRequests() async {
    try {
      final box = await Hive.openBox('userRequestsBox');
      final cachedRequests = box.get('cachedRequests', defaultValue: []);
      if (cachedRequests is List) {
        return cachedRequests
            .whereType<Map>()
            .map<Map<String, dynamic>>(
              (e) => Map<String, dynamic>.from(e as Map),
            )
            .toList();
      }
    } catch (e) {
      print('Error loading cached requests: $e');
    }
    return [];
  }

  // Build widget with offline fallback
  Widget _buildWithOfflineFallback() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const Center(child: Text('Not logged in'));
    }

    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _loadCachedRequests(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final cachedRequests = snapshot.data!;
        final pending = _filterRequests(
          cachedRequests.where((r) => r['status'] == 'pending').toList(),
        );
        final completed = _filterRequests(
          cachedRequests.where((r) => r['status'] == 'completed').toList(),
        );

        return Column(
          children: [
            // Offline indicator banner
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
              color: Colors.orange.withOpacity(0.1),
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
            _buildSearchBar(),
            Container(
              color: Colors.green,
              child: TabBar(
                controller: _tabController,
                indicatorColor: Colors.white,
                labelColor: Colors.white,
                unselectedLabelColor: Colors.white70,
                tabs: [Tab(text: tr('pending')), Tab(text: tr('completed'))],
              ),
            ),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  pending.isEmpty
                      ? _buildEmptyState(
                        _searchQuery.isNotEmpty
                            ? 'No pending requests found for "$_searchQuery"'
                            : 'No pending requests',
                      )
                      : Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: UserRequestList(requests: pending),
                      ),
                  completed.isEmpty
                      ? _buildEmptyState(
                        _searchQuery.isNotEmpty
                            ? 'No completed requests found for "$_searchQuery"'
                            : 'No completed requests',
                      )
                      : Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: UserRequestList(requests: completed),
                      ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildEmptyState(String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              _searchQuery.isNotEmpty ? Icons.search_off : Icons.inbox,
              size: 64,
              color: Colors.green[200],
            ),
            const SizedBox(height: 16),
            Text(
              message,
              style: const TextStyle(fontSize: 18, color: Colors.grey),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

Widget _buildImageWidget(
  String path, {
  double? width,
  double? height,
  BoxFit fit = BoxFit.cover,
}) {
  print('Attempting to display image: $path');
  if (path.isEmpty) {
    return Container(
      width: width,
      height: height,
      color: Colors.grey[200],
      child: const Icon(Icons.broken_image, size: 40, color: Colors.grey),
    );
  }
  if (path.startsWith('http')) {
    return CachedNetworkImage(
      imageUrl: path,
      width: width,
      height: height,
      fit: fit,
      placeholder:
          (context, url) => const Center(child: CircularProgressIndicator()),
      errorWidget:
          (context, url, error) =>
              const Icon(Icons.broken_image, size: 40, color: Colors.grey),
    );
  } else if (_isFilePath(path)) {
    return Image.file(
      File(path),
      width: width,
      height: height,
      fit: fit,
      errorBuilder:
          (context, error, stackTrace) =>
              const Icon(Icons.broken_image, size: 40, color: Colors.grey),
    );
  } else {
    return Image.asset(
      path,
      width: width,
      height: height,
      fit: fit,
      errorBuilder:
          (context, error, stackTrace) =>
              const Icon(Icons.broken_image, size: 40, color: Colors.grey),
    );
  }
}

Future<Size> _getImageSize(ImageProvider imageProvider) async {
  final ImageStream stream = imageProvider.resolve(ImageConfiguration.empty);
  final Completer<Size> completer = Completer<Size>();

  stream.addListener(
    ImageStreamListener((ImageInfo info, bool _) {
      completer.complete(
        Size(info.image.width.toDouble(), info.image.height.toDouble()),
      );
    }),
  );

  return completer.future;
}

bool _isFilePath(String path) {
  // Heuristic: treat as file path if it is absolute or starts with /data/ or C:/ or similar
  return path.startsWith('/') || path.contains(':');
}
