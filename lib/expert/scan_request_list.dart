import 'package:flutter/material.dart';
import 'scan_request_detail.dart';
import '../shared/review_manager.dart';
import 'dart:io';
import '../user/user_request_list.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';
import 'package:hive/hive.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ScanRequestList extends StatefulWidget {
  final int initialTabIndex;

  const ScanRequestList({Key? key, this.initialTabIndex = 0}) : super(key: key);

  @override
  State<ScanRequestList> createState() => _ScanRequestListState();
}

class _ScanRequestListState extends State<ScanRequestList>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  bool _isLoading = true;
  List<Map<String, dynamic>> _pendingRequests = [];
  List<Map<String, dynamic>> _completedRequests = [];
  // Track which pending requests have been opened (to hide "New" badge)
  Set<String> _seenPendingIds = <String>{};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    // Set initial tab based on parameter
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (widget.initialTabIndex < _tabController.length) {
        _tabController.animateTo(widget.initialTabIndex);
      }
    });
    _fetchRequests();
    _loadSeenPending();
  }

  Future<void> _loadSeenPending() async {
    try {
      final box = await Hive.openBox('expertRequestsSeenBox');
      final saved = box.get('seenPendingIds', defaultValue: []);
      if (saved is List) {
        setState(() {
          _seenPendingIds = saved.map((e) => e.toString()).toSet();
        });
      }
    } catch (_) {}
  }

  Future<void> _markPendingSeen(String id) async {
    if (id.isEmpty || _seenPendingIds.contains(id)) return;
    setState(() {
      _seenPendingIds.add(id);
    });
    try {
      final box = await Hive.openBox('expertRequestsSeenBox');
      await box.put('seenPendingIds', _seenPendingIds.toList());
    } catch (_) {}
  }

  Future<void> _fetchRequests() async {
    setState(() => _isLoading = true);

    // Get current expert's UID from Firebase Auth
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      setState(() => _isLoading = false);
      return;
    }
    final currentExpertUid = user.uid;

    final pendingQuery =
        await FirebaseFirestore.instance
            .collection('scan_requests')
            .where('status', whereIn: ['pending', 'pending_review'])
            .get();
    final completedQuery =
        await FirebaseFirestore.instance
            .collection('scan_requests')
            .where('status', whereIn: ['reviewed', 'completed'])
            .get();

    setState(() {
      _pendingRequests = pendingQuery.docs.map((doc) => doc.data()).toList();
      // Filter completed requests to only show those reviewed by current expert
      _completedRequests =
          completedQuery.docs.map((doc) => doc.data()).where((request) {
            final expertUid = request['expertUid'] ?? '';
            return expertUid == currentExpertUid;
          }).toList();
      _isLoading = false;
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  List<Map<String, dynamic>> _filterRequests(
    List<Map<String, dynamic>> requests,
  ) {
    if (_searchQuery.isEmpty) return requests;
    final query = _searchQuery.trim().toLowerCase();
    return requests.where((request) {
      final userName =
          (request['userName'] ?? request['userId'] ?? '')
              .toString()
              .toLowerCase();
      final email = (request['email'] ?? '').toString().toLowerCase();

      String diseases = '';
      final summary = request['diseaseSummary'];
      if (summary is List) {
        diseases = summary
            .map((d) {
              if (d is Map) {
                final raw =
                    (d['label'] ?? d['disease'] ?? d['name'] ?? '').toString();
                return raw.replaceAll('_', ' ').toLowerCase();
              }
              return '';
            })
            .where((s) => s.isNotEmpty)
            .join(' ');
      }

      final submittedAt =
          (request['submittedAt'] ?? '').toString().toLowerCase();
      final reviewedAt = (request['reviewedAt'] ?? '').toString().toLowerCase();
      final status = (request['status'] ?? '').toString().toLowerCase();
      final id =
          (request['id'] ?? request['requestId'] ?? '')
              .toString()
              .toLowerCase();

      return userName.contains(query) ||
          email.contains(query) ||
          diseases.contains(query) ||
          submittedAt.contains(query) ||
          reviewedAt.contains(query) ||
          status.contains(query) ||
          id.contains(query);
    }).toList();
  }

  String _formatDiseaseName(String disease) {
    // Convert snake_case to Title Case and replace underscores with spaces
    final normalized = disease.replaceAll('_', ' ').toLowerCase();
    if (normalized == 'tip burn') {
      return 'Unknown';
    }
    return disease
        .split('_')
        .map((word) => word[0].toUpperCase() + word.substring(1))
        .join(' ');
  }

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
              hintText: 'Search',
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
              'Try searching for: "Anthracnose", "John", or "2024-06-10"',
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

  Widget _buildRequestCard(Map<String, dynamic> request) {
    final diseaseSummary = request['diseaseSummary'] as List<dynamic>;
    final mainDisease = diseaseSummary.isNotEmpty ? diseaseSummary.first : null;
    // Use 'label' if available, else 'disease', else 'name'
    final mainDiseaseKey =
        mainDisease != null
            ? (mainDisease['label'] ??
                mainDisease['disease'] ??
                mainDisease['name'] ??
                'unknown')
            : 'unknown';
    final isCompleted =
        request['status'] == 'reviewed' || request['status'] == 'completed';
    final userName = request['userName']?.toString() ?? '(No Name)';
    final submittedAt = request['submittedAt'] ?? '';
    // Format date
    final formattedDate =
        submittedAt.toString().isNotEmpty &&
                DateTime.tryParse(submittedAt.toString()) != null
            ? DateFormat(
              'MMM d, yyyy – h:mma',
            ).format(DateTime.parse(submittedAt.toString()))
            : submittedAt.toString();
    String? reviewedAt;
    if (isCompleted) {
      // reviewedAt is saved at document level, not inside expertReview
      reviewedAt = request['reviewedAt'] as String? ?? '';
    }

    // Format review date for completed requests
    final formattedReviewDate =
        reviewedAt != null &&
                reviewedAt.isNotEmpty &&
                DateTime.tryParse(reviewedAt) != null
            ? DateFormat(
              'MMM d, yyyy – h:mma',
            ).format(DateTime.parse(reviewedAt))
            : reviewedAt ?? '';

    // Use imageUrl if present and not empty, else path if not empty
    String? imageUrl = request['images']?[0]?['imageUrl'];
    String? imagePath = request['images']?[0]?['path'];
    String? displayPath =
        (imageUrl != null && imageUrl.isNotEmpty)
            ? imageUrl
            : (imagePath != null && imagePath.isNotEmpty)
            ? imagePath
            : null;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: () async {
          // Mark pending as seen when expert opens it
          final id = (request['id'] ?? request['requestId'] ?? '').toString();
          if ((request['status'] == 'pending' ||
                  request['status'] == 'pending_review') &&
              id.isNotEmpty) {
            await _markPendingSeen(id);
          }
          final updatedRequest = await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ScanRequestDetail(request: request),
            ),
          );

          if (updatedRequest != null) {
            setState(() {
              // Find and update the request in the appropriate list
              if (request['status'] == 'pending') {
                final index = _pendingRequests.indexOf(request);
                if (index != -1) {
                  _pendingRequests.removeAt(index);
                  _completedRequests.insert(0, updatedRequest);
                }
              } else {
                final index = _completedRequests.indexOf(request);
                if (index != -1) {
                  _completedRequests[index] = updatedRequest;
                }
              }
            });
          }
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Image
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: SizedBox(
                  width: 80,
                  height: 80,
                  child:
                      displayPath != null && displayPath.isNotEmpty
                          ? _buildImageWidget(displayPath)
                          : Container(
                            color: Colors.grey[200],
                            child: const Icon(Icons.image_not_supported),
                          ),
                ),
              ),
              const SizedBox(width: 16),
              // Details
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      mainDisease != null
                          ? '${_formatDiseaseName(mainDiseaseKey)} Detection'
                          : 'No Disease Detected',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(Icons.person, size: 16, color: Colors.green),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            userName,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: Colors.green,
                            ),
                            softWrap: false,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(
                          Icons.schedule,
                          size: 14,
                          color: Colors.grey,
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            'Sent: $formattedDate',
                            style: const TextStyle(
                              fontSize: 11,
                              color: Colors.grey,
                            ),
                            softWrap: false,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    if (isCompleted && formattedReviewDate.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(
                            Icons.check_circle,
                            size: 14,
                            color: Colors.green,
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              'Reviewed: $formattedReviewDate',
                              style: const TextStyle(
                                fontSize: 11,
                                color: Colors.green,
                                fontWeight: FontWeight.w500,
                              ),
                              softWrap: false,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              // Status indicator
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: isCompleted ? Colors.green : Colors.orange,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      isCompleted ? 'Completed' : 'Pending',
                      style: const TextStyle(color: Colors.white, fontSize: 12),
                    ),
                  ),
                  if ((request['status'] == 'pending' ||
                      request['status'] == 'pending_review')) ...[
                    const SizedBox(width: 6),
                    Builder(
                      builder: (context) {
                        final id =
                            (request['id'] ?? request['requestId'] ?? '')
                                .toString();
                        final isNew =
                            id.isNotEmpty && !_seenPendingIds.contains(id);
                        return isNew
                            ? Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.red.withOpacity(0.12),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: Colors.red.withOpacity(0.3),
                                ),
                              ),
                              child: const Text(
                                'New',
                                style: TextStyle(
                                  color: Colors.red,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 11,
                                ),
                              ),
                            )
                            : const SizedBox.shrink();
                      },
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Get current expert's UID from Firebase Auth
    final user = FirebaseAuth.instance.currentUser;
    final currentExpertUid = user?.uid ?? '';

    return StreamBuilder<QuerySnapshot>(
      stream:
          FirebaseFirestore.instance.collection('scan_requests').snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final allRequests =
            snapshot.data!.docs
                .map((doc) => doc.data() as Map<String, dynamic>)
                .toList();
        // Sort by submittedAt descending
        allRequests.sort((a, b) {
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
        final filteredPending = _filterRequests(
          allRequests
              .where(
                (r) =>
                    r['status'] == 'pending' || r['status'] == 'pending_review',
              )
              .toList(),
        );
        // Filter completed requests to only show those reviewed by current expert
        final filteredCompleted = _filterRequests(
          allRequests
              .where(
                (r) =>
                    (r['status'] == 'reviewed' || r['status'] == 'completed') &&
                    (r['expertUid'] == currentExpertUid),
              )
              .toList(),
        );
        return Scaffold(
          backgroundColor: Colors.grey[50],
          body: Column(
            children: [
              _buildSearchBar(),
              Container(
                color: Colors.green,
                child: Row(
                  children: [
                    Expanded(
                      child: TabBar(
                        controller: _tabController,
                        indicatorColor: Colors.white,
                        labelColor: Colors.white,
                        unselectedLabelColor: Colors.white70,
                        tabs: [
                          Tab(text: 'Pending (${filteredPending.length})'),
                          Tab(text: 'Completed (${filteredCompleted.length})'),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              // Removed separate totals row; counts are shown in tab labels
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    // Pending Requests
                    filteredPending.isEmpty
                        ? _buildEmptyState(
                          _searchQuery.isNotEmpty
                              ? 'No pending requests found for "$_searchQuery"'
                              : 'No pending requests',
                        )
                        : ListView.builder(
                          itemCount: filteredPending.length,
                          itemBuilder: (context, index) {
                            return _buildRequestCard(filteredPending[index]);
                          },
                        ),
                    // Completed Requests
                    filteredCompleted.isEmpty
                        ? _buildEmptyState(
                          _searchQuery.isNotEmpty
                              ? 'No completed requests found for "$_searchQuery"'
                              : 'No completed requests',
                        )
                        : ListView.builder(
                          itemCount: filteredCompleted.length,
                          itemBuilder: (context, index) {
                            return _buildRequestCard(filteredCompleted[index]);
                          },
                        ),
                  ],
                ),
              ),
            ],
          ),
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

  Widget _buildImageWidget(String path) {
    if (path.startsWith('http')) {
      // Supabase public URL - use cached network image with memory optimization
      return CachedNetworkImage(
        imageUrl: path,
        fit: BoxFit.cover,
        memCacheWidth: 200, // Limit memory usage
        memCacheHeight: 200,
        maxWidthDiskCache: 400,
        maxHeightDiskCache: 400,
        placeholder:
            (context, url) => Container(
              color: Colors.grey[200],
              child: const Center(child: CircularProgressIndicator()),
            ),
        errorWidget: (context, url, error) {
          return Container(
            color: Colors.grey[200],
            child: const Icon(Icons.image_not_supported),
          );
        },
      );
    } else if (path.startsWith('/') || path.contains(':')) {
      // File path - optimize file loading
      return Image.file(
        File(path),
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          return Container(
            color: Colors.grey[200],
            child: const Icon(Icons.image_not_supported),
          );
        },
      );
    } else {
      // Asset image - use optimized loading
      return Image.asset(
        path,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          return Container(
            color: Colors.grey[200],
            child: const Icon(Icons.image_not_supported),
          );
        },
      );
    }
  }
}
