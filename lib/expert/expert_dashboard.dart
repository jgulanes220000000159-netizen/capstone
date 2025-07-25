import 'package:flutter/material.dart';
import 'scan_request_list.dart';
import 'disease_editor.dart';
import 'expert_profile.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class ExpertDashboard extends StatefulWidget {
  const ExpertDashboard({Key? key}) : super(key: key);

  @override
  State<ExpertDashboard> createState() => _ExpertDashboardState();
}

class _ExpertDashboardState extends State<ExpertDashboard> {
  int _selectedIndex = 0;

  static const List<Widget> _pages = <Widget>[
    ScanRequestList(), // Requests tab
    DiseaseEditor(), // Diseases tab
    ExpertProfile(), // Profile tab
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Expert Dashboard'),
        backgroundColor: Colors.green,
      ),
      body: _pages[_selectedIndex],
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final flutterLocalNotificationsPlugin =
              FlutterLocalNotificationsPlugin();
          await flutterLocalNotificationsPlugin.show(
            0,
            'Test Notification',
            'This is a test notification!',
            const NotificationDetails(
              android: AndroidNotificationDetails(
                'channel_id',
                'channel_name',
                importance: Importance.max,
                priority: Priority.high,
              ),
            ),
          );
        },
        backgroundColor: Colors.green,
        child: const Icon(Icons.notifications),
        tooltip: 'Test Notification',
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        selectedItemColor: Colors.green,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.list_alt),
            label: 'Requests',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.local_hospital),
            label: 'Diseases',
          ),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
        ],
      ),
    );
  }
}
