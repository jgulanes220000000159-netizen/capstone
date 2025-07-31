import 'package:flutter/material.dart';
import '../user/profile_page.dart';

class AppHeader extends StatelessWidget {
  final String? title;
  final VoidCallback? onProfileTap;
  final bool showProfileButton;

  const AppHeader({
    Key? key,
    this.title,
    this.onProfileTap,
    this.showProfileButton = true,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
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
                child: Image.asset('assets/logo.png', width: 30, height: 30),
              ),
              const SizedBox(width: 8),
              Text(
                title ?? 'MangoSense',
                style: const TextStyle(
                  color: Colors.yellow,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          if (showProfileButton)
            GestureDetector(
              onTap:
                  onProfileTap ??
                  () {
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
    );
  }
}
