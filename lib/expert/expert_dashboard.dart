import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'scan_request_list.dart';
import 'expert_profile.dart';
import 'package:hive/hive.dart';
import 'disease_editor.dart';

class ExpertDashboard extends StatefulWidget {
  const ExpertDashboard({Key? key}) : super(key: key);

  @override
  _ExpertDashboardState createState() => _ExpertDashboardState();
}

class _ExpertDashboardState extends State<ExpertDashboard> {
  int _selectedIndex = 0;

  // User data variables
  String _userName = 'Loading...';
  bool _isLoading = true;

  final List<Widget> _pages = [
    const ScanRequestList(),
    const DiseaseEditor(),
    const ExpertProfile(),
  ];

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    try {
      final userBox = await Hive.openBox('userBox');
      final localProfile = userBox.get('userProfile');
      if (localProfile != null) {
        setState(() {
          _userName = localProfile['fullName'] ?? 'Expert';
          _isLoading = false;
        });
        return;
      }
      final user = FirebaseAuth.instance.currentUser;
      print('Expert - Current user: ${user?.email}');
      print('Expert - Current user UID: ${user?.uid}');

      if (user != null) {
        // Fetch user profile from Firestore
        final userDoc =
            await FirebaseFirestore.instance
                .collection('users')
                .doc(user.uid)
                .get();

        print('Expert - User document exists: ${userDoc.exists}');

        if (userDoc.exists) {
          final data = userDoc.data() as Map<String, dynamic>;
          print('Expert - User data: $data');
          print('Expert - Full name from data: ${data['fullName']}');

          setState(() {
            _userName = data['fullName'] ?? 'Expert';
            _isLoading = false;
          });
          print('Expert - Set user name to: $_userName');
        } else {
          print('Expert - User document does not exist');
          setState(() {
            _userName = 'Expert';
            _isLoading = false;
          });
        }
      } else {
        print('Expert - No current user');
        setState(() {
          _userName = 'Expert';
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Expert - Error loading user data: $e');
      setState(() {
        _userName = 'Expert';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.green,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Expert Dashboard',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              'Welcome, $_userName',
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 12,
                fontWeight: FontWeight.normal,
              ),
            ),
          ],
        ),
        elevation: 0,
      ),
      body: _pages[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (index) {
          setState(() {
            _selectedIndex = index;
          });
        },
        selectedItemColor: Colors.green,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.list_alt),
            label: 'Requests',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.edit_note),
            label: 'Diseases',
          ),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
        ],
      ),
    );
  }
}
