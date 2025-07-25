import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'camera_page.dart';
import 'detection_carousel_screen.dart';
import 'disease_details_page.dart';
import 'profile_page.dart';
import 'user_request_list.dart';
import 'scan_page.dart';
import '../shared/review_manager.dart';
import 'package:hive/hive.dart';
import 'package:easy_localization/easy_localization.dart';
import 'tracking_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({Key? key}) : super(key: key);

  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final ImagePicker _picker = ImagePicker();
  int _selectedIndex = 0;
  final ReviewManager _reviewManager = ReviewManager();

  // User data variables
  String _userName = 'Loading...';
  bool _isLoading = true;

  // Disease information (now loaded from Firestore and cached in Hive)
  Map<String, Map<String, dynamic>> _diseaseInfo = {};

  final List<Widget> _pages = [
    // Home
    Container(), // Placeholder for home content
    // Scan
    const ScanPage(),
    // My Requests
    const UserRequestTabbedList(),
    // Tracking (new page)
    const TrackingPage(),
  ];

  int get _pendingCount =>
      _reviewManager.pendingReviews
          .where((r) => r['status'] == 'pending')
          .length;

  @override
  void initState() {
    super.initState();
    _loadUserData();
    _loadDiseaseInfo();
  }

  Future<void> _loadUserData() async {
    try {
      final userBox = await Hive.openBox('userBox');
      final localProfile = userBox.get('userProfile');
      if (localProfile != null) {
        setState(() {
          _userName = localProfile['fullName'] ?? 'Farmer';
          _isLoading = false;
        });
        return;
      }
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final userDoc =
            await FirebaseFirestore.instance
                .collection('users')
                .doc(user.uid)
                .get();
        if (userDoc.exists) {
          final data = userDoc.data() as Map<String, dynamic>;
          setState(() {
            _userName = data['fullName'] ?? 'Farmer';
            _isLoading = false;
          });
        } else {
          setState(() {
            _userName = 'Farmer';
            _isLoading = false;
          });
        }
      } else {
        setState(() {
          _userName = 'Farmer';
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error loading user data: $e');
      setState(() {
        _userName = 'Farmer';
        _isLoading = false;
      });
    }
  }

  Future<void> _loadDiseaseInfo() async {
    final diseaseBox = await Hive.openBox('diseaseBox');
    // Try to load from local storage first
    final localDiseaseInfo = diseaseBox.get('diseaseInfo');
    if (localDiseaseInfo != null && localDiseaseInfo is Map) {
      setState(() {
        _diseaseInfo = Map<String, Map<String, dynamic>>.from(
          (localDiseaseInfo as Map).map(
            (k, v) =>
                MapEntry(k as String, Map<String, dynamic>.from(v as Map)),
          ),
        );
      });
    }
    // Always try to fetch latest from Firestore
    try {
      final snapshot =
          await FirebaseFirestore.instance.collection('diseases').get();
      final Map<String, Map<String, dynamic>> fetched = {};
      for (var doc in snapshot.docs) {
        final data = doc.data();
        final name = data['name'] ?? '';
        if (name.isNotEmpty) {
          fetched[name] = {
            'scientificName': data['scientificName'] ?? '',
            'symptoms': List<String>.from(data['symptoms'] ?? []),
            'treatments': List<String>.from(data['treatments'] ?? []),
          };
        }
      }
      if (fetched.isNotEmpty) {
        setState(() {
          _diseaseInfo = fetched;
        });
        await diseaseBox.put('diseaseInfo', fetched);
      }
    } catch (e) {
      print('Error fetching disease info: $e');
    }
  }

  Future<void> _selectFromGallery(BuildContext context) async {
    final List<XFile>? images = await _picker.pickMultiImage();
    if (images != null && images.isNotEmpty) {
      if (images.length > 5) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Maximum 5 images can be selected'),
            duration: Duration(seconds: 2),
          ),
        );
        return;
      }

      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder:
              (context) => DetectionCarouselScreen(
                imagePaths: images.map((img) => img.path).toList(),
              ),
        ),
      );
    }
  }

  void _showDiseaseDetails(String name, String imagePath) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder:
            (context) => DiseaseDetailsPage(
              name: name,
              imagePath: imagePath,
              scientificName: _diseaseInfo[name]?['scientificName'] ?? '',
              details: {
                'Symptoms': _diseaseInfo[name]?['symptoms'] ?? [],
                'Treatments': _diseaseInfo[name]?['treatments'] ?? [],
              },
            ),
      ),
    );
  }

  Widget _buildDiseaseCard(String name, String imagePath) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(15),
        side: BorderSide(color: Colors.green.shade200),
      ),
      child: InkWell(
        onTap: () => _showDiseaseDetails(name, imagePath),
        borderRadius: BorderRadius.circular(15),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.asset(
                  imagePath,
                  width: 100,
                  height: 80,
                  fit: BoxFit.cover,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  name,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              const Icon(Icons.arrow_forward_ios, size: 20),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // Green header
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.green,
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(20),
                  bottomRight: Radius.circular(20),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
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
                      const SizedBox(width: 8),
                      const Text(
                        'MangoSense',
                        style: TextStyle(
                          color: Colors.yellow,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const ProfilePage(),
                        ),
                      );
                    },
                    child: const CircleAvatar(
                      backgroundColor: Colors.white,
                      child: Icon(Icons.person, color: Colors.green),
                    ),
                  ),
                ],
              ),
            ),
            // Main content
            Expanded(
              child:
                  _selectedIndex == 0
                      ? StreamBuilder<QuerySnapshot>(
                        stream:
                            FirebaseFirestore.instance
                                .collection('diseases')
                                .snapshots(),
                        builder: (context, snapshot) {
                          if (!snapshot.hasData) {
                            return const Center(
                              child: CircularProgressIndicator(),
                            );
                          }
                          final diseaseDocs = snapshot.data!.docs;
                          final diseaseNames =
                              diseaseDocs
                                  .map((doc) => doc['name'] as String)
                                  .toList();
                          final diseaseImages = [
                            'assets/diseases/anthracnose.jpg',
                            'assets/diseases/backterial_blackspot1.jpg',
                            'assets/diseases/dieback.jpg',
                            'assets/diseases/powdery_mildew3.jpg',
                            'assets/diseases/healthy.jpg',
                          ];
                          return SingleChildScrollView(
                            physics: const BouncingScrollPhysics(),
                            child: Column(
                              children: [
                                const SizedBox(height: 16),
                                // Welcome text
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                  ),
                                  child: Align(
                                    alignment: Alignment.centerLeft,
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          tr(
                                            'good_day',
                                            namedArgs: {'name': _userName},
                                          ),
                                          style: TextStyle(
                                            fontSize: 24,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.green[700],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 16),
                                // Diseases section
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                  ),
                                  child: Align(
                                    alignment: Alignment.centerLeft,
                                    child: Text(
                                      tr('diseases'),
                                      style: TextStyle(
                                        fontSize: 20,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.grey[800],
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                // Disease cards (from Firestore)
                                for (
                                  int i = 0;
                                  i < diseaseNames.length &&
                                      i < diseaseImages.length;
                                  i++
                                )
                                  _buildDiseaseCard(
                                    diseaseNames[i],
                                    diseaseImages[i],
                                  ),
                                const SizedBox(height: 16),
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                  ),
                                  child: Align(
                                    alignment: Alignment.centerLeft,
                                    child: Text(
                                      tr('none_disease'),
                                      style: const TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ),
                                _buildDiseaseCard(
                                  tr('healthy'),
                                  'assets/diseases/healthy.jpg',
                                ),
                                const SizedBox(height: 16),
                              ],
                            ),
                          );
                        },
                      )
                      : _pages[_selectedIndex],
            ),
            // Bottom navigation bar
            BottomNavigationBar(
              currentIndex: _selectedIndex,
              onTap: (index) {
                setState(() {
                  _selectedIndex = index;
                });
              },
              selectedItemColor: Colors.green,
              unselectedItemColor: Colors.grey,
              items: [
                BottomNavigationBarItem(
                  icon: const Icon(Icons.home),
                  label: tr('home'),
                ),
                BottomNavigationBarItem(
                  icon: const Icon(Icons.camera_alt),
                  label: tr('scan'),
                ),
                BottomNavigationBarItem(
                  icon: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      const Icon(Icons.list_alt, size: 28),
                      if (_pendingCount > 0)
                        Positioned(
                          right: -8,
                          top: -8,
                          child: Container(
                            padding: const EdgeInsets.all(0),
                            decoration: BoxDecoration(
                              color: Colors.red,
                              border: Border.all(color: Colors.white, width: 2),
                              shape: BoxShape.circle,
                            ),
                            constraints: const BoxConstraints(
                              minWidth: 22,
                              minHeight: 22,
                            ),
                            child: Center(
                              child: Text(
                                '$_pendingCount',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                  label: tr('my_requests'),
                ),
                BottomNavigationBarItem(
                  icon: const Icon(Icons.show_chart),
                  label: tr('tracking'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
