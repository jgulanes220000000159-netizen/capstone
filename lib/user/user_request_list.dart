import 'package:flutter/material.dart';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:hive/hive.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'user_request_detail.dart';

class UserRequestList extends StatefulWidget {
  final List<Map<String, dynamic>> requests;
  const UserRequestList({Key? key, required this.requests}) : super(key: key);

  @override
  State<UserRequestList> createState() => _UserRequestListState();
}

class _UserRequestListState extends State<UserRequestList> {
  // Remove the bounding box preference for list view - we don't want bounding boxes in the list
  // bool _showBoundingBoxes = true;

  @override
  void initState() {
    super.initState();
    // Remove bounding box preference loading for list view
    // _loadBoundingBoxPreference();
  }

  // Remove these methods as they're not needed for list view
  // Future<void> _loadBoundingBoxPreference() async {
  //   final box = await Hive.openBox('userBox');
  //   final savedPreference = box.get('showBoundingBoxes');
  //   if (savedPreference != null) {
  //     setState(() {
  //       _showBoundingBoxes = savedPreference as bool;
  //     });
  //   }
  // }

  // Future<void> _saveBoundingBoxPreference(bool value) async {
  //   final box = await Hive.openBox('userBox');
  //   await box.put('showBoundingBoxes', value);
  // }

  Widget _buildImageWidgetWithBoundingBoxes(
    String path,
    List detections, {
    double? width,
    double? height,
    BoxFit fit = BoxFit.cover,
  }) {
    // For list view, always show images without bounding boxes
    return _buildImageWidget(path, width: width, height: height, fit: fit);

    // Comment out the bounding box logic for list view
    // if (!_showBoundingBoxes || detections.isEmpty) {
    //   return _buildImageWidget(path, width: width, height: height, fit: fit);
    // }

    // return FutureBuilder<Size>(
    //   future: _getImageSize(
    //     path.startsWith('http') ? NetworkImage(path) : FileImage(File(path)),
    //   ),
    //   builder: (context, snapshot) {
    //     if (!snapshot.hasData) {
    //       return _buildImageWidget(
    //         path,
    //         width: width,
    //         height: height,
    //         fit: fit,
    //       );
    //     }

    //     final imageSize = snapshot.data!;
    //     final widgetSize = Size(width ?? 80, height ?? 80);

    //     // Calculate scaling for BoxFit.cover
    //     final scaleX = widgetSize.width / imageSize.width;
    //     final scaleY = widgetSize.height / imageSize.height;
    //     final scale = scaleX > scaleY ? scaleX : scaleY;

    //     final scaledW = imageSize.width * scale;
    //     final scaledH = imageSize.height * scale;
    //     final dx = (widgetSize.width - scaledW) / 2;
    //     final dy = (widgetSize.height - scaledH) / 2;

    //     return Stack(
    //       children: [
    //         _buildImageWidget(path, width: width, height: height, fit: fit),
    //         CustomPaint(
    //           painter: DetectionPainter(
    //             results:
    //                 detections
    //                     .map((d) {
    //                       if (d == null ||
    //                           d['disease'] == null ||
    //                           d['boundingBox'] == null) {
    //                         return null;
    //                       }
    //                       return DetectionResult(
    //                         label: d['disease'].toString(),
    //                         confidence:
    //                             (d['confidence'] as num?)?.toDouble() ?? 0.0,
    //                         boundingBox: Rect.fromLTRB(
    //                           (d['boundingBox']['left'] as num).toDouble(),
    //                           (d['boundingBox']['top'] as num).toDouble(),
    //                           (d['boundingBox']['right'] as num).toDouble(),
    //                           (d['boundingBox']['bottom'] as num).toDouble(),
    //                         ),
    //                       );
    //                     })
    //                     .whereType<DetectionResult>()
    //                     .toList(),
    //             originalImageSize: imageSize,
    //             displayedImageSize: Size(scaledW, scaledH),
    //             displayedImageOffset: Offset(dx, dy),
    //           ),
    //           size: widgetSize,
    //         ),
    //       ],
    //     );
    //   },
    // );
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
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: sortedRequests.length,
      itemBuilder: (context, index) {
        final request = sortedRequests[index];
        return _buildRequestCard(request);
      },
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

Widget _buildImageWidget(
  String path, {
  double? width,
  double? height,
  BoxFit fit = BoxFit.cover,
}) {
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

bool _isFilePath(String path) {
  // Heuristic: treat as file path if it is absolute or starts with /data/ or C:/ or similar
  return path.startsWith('/') || path.contains(':');
}

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
