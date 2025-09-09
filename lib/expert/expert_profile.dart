import 'package:flutter/material.dart';
// import '../routes.dart';
import '../about_app_page.dart';
import '../user/login_page.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:hive/hive.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:easy_localization/easy_localization.dart';

class ExpertProfile extends StatefulWidget {
  const ExpertProfile({Key? key}) : super(key: key);

  @override
  State<ExpertProfile> createState() => _ExpertProfileState();
}

class _ExpertProfileState extends State<ExpertProfile> {
  File? _profileImage;
  final ImagePicker _picker = ImagePicker();
  bool _notificationsEnabled = false;

  // User data variables
  String _userName = 'Loading...';
  String _userRole = 'Expert';
  String _userEmail = '';
  String _userPhone = '';
  String _userAddress = '';
  String? _profileImageUrl;
  int _completedReviews = 0;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadUserData();
    _saveFcmTokenToFirestore();
    try {
      final settingsBox = Hive.box('settings');
      final enabled =
          settingsBox.get('enableNotifications', defaultValue: false) as bool;
      _notificationsEnabled = enabled;
    } catch (_) {}
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Refresh stats when page is focused
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      _loadExpertStats(user.uid);
    }
  }

  Future<void> _loadUserData() async {
    try {
      final userBox = await Hive.openBox('userBox');
      final localProfile = userBox.get('userProfile');
      if (localProfile != null) {
        setState(() {
          _userName = localProfile['fullName'] ?? 'Unknown Expert';
          _userRole = localProfile['role'] ?? 'Expert';
          _userEmail = localProfile['email'] ?? '';
          _userPhone = localProfile['phoneNumber'] ?? '';
          _userAddress = localProfile['address'] ?? '';
          _profileImageUrl = localProfile['imageProfile'];
          _isLoading = false;
        });

        // Load expert statistics even when using local data
        final user = FirebaseAuth.instance.currentUser;
        if (user != null) {
          _loadExpertStats(user.uid);
        }
        return;
      }
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        // Fetch user profile from Firestore
        final userDoc =
            await FirebaseFirestore.instance
                .collection('users')
                .doc(user.uid)
                .get();

        if (userDoc.exists) {
          final data = userDoc.data() as Map<String, dynamic>;
          setState(() {
            _userName = data['fullName'] ?? 'Unknown Expert';
            _userRole = data['role'] ?? 'Expert';
            _userEmail = data['email'] ?? '';
            _userPhone = data['phoneNumber'] ?? '';
            _userAddress = data['address'] ?? '';
            _profileImageUrl = data['imageProfile'];
            _isLoading = false;
          });

          // Load expert statistics
          _loadExpertStats(user.uid);
        }
      }
    } catch (e) {
      print('Error loading user data: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _loadExpertStats(String userId) async {
    try {
      print('Loading expert stats for user: $userId');

      // Count completed reviews for this expert
      final reviewsQuery =
          await FirebaseFirestore.instance
              .collection('scan_requests')
              .where('expertUid', isEqualTo: userId)
              .where('status', whereIn: ['completed', 'reviewed'])
              .get();

      print(
        'Found ${reviewsQuery.docs.length} completed reviews for expert $userId',
      );

      setState(() {
        _completedReviews = reviewsQuery.docs.length;
      });
    } catch (e) {
      print('Error loading expert stats: $e');
    }
  }

  Future<void> _pickProfileImage() async {
    final XFile? pickedFile = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
    );
    if (pickedFile != null) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder:
            (context) => AlertDialog(
              title: Text(tr('change_profile_photo')),
              content: Text(tr('confirm_change_profile_photo')),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: Text(tr('cancel')),
                ),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  child: Text(tr('update')),
                ),
              ],
            ),
      );
      if (confirmed == true) {
        if (!mounted) return;
        setState(() {
          _profileImage = File(pickedFile.path);
        });

        // Upload to Firebase Storage
        await _uploadProfileImage(pickedFile.path);
      }
    }
  }

  Future<void> _uploadProfileImage(String imagePath) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final file = File(imagePath);
        final ref = FirebaseStorage.instance
            .ref()
            .child('profile')
            .child('${user.uid}.jpg');

        await ref.putFile(file);
        final url = await ref.getDownloadURL();

        // Update Firestore with new image URL
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .update({'imageProfile': url});

        if (!mounted) return;
        setState(() {
          _profileImageUrl = url;
        });

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile image updated successfully!')),
        );
      }
    } catch (e) {
      print('Error uploading profile image: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to update profile image')),
      );
    }
  }

  Future<void> _saveFcmTokenToFirestore() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      String? token = await FirebaseMessaging.instance.getToken();
      if (token != null) {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .update({'fcmToken': token});
      }
    }
  }

  Widget _buildStat(String label, String value, {VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white.withOpacity(0.8),
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileOption({
    required String title,
    required IconData icon,
    VoidCallback? onTap,
    bool showDivider = true,
  }) {
    return Column(
      children: [
        ListTile(
          leading: Icon(icon, color: Colors.green),
          title: Text(
            title,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
          ),
          trailing: const Icon(Icons.arrow_forward_ios, size: 16),
          onTap: onTap,
        ),
        if (showDivider) const Divider(height: 1),
      ],
    );
  }

  void _showEditProfileDialog(BuildContext context) {
    final TextEditingController nameController = TextEditingController(
      text: _userName,
    );
    final TextEditingController emailController = TextEditingController(
      text: _userEmail,
    );
    final TextEditingController phoneController = TextEditingController(
      text: _userPhone,
    );
    final TextEditingController addressController = TextEditingController(
      text: _userAddress,
    );

    showDialog(
      context: context,
      builder:
          (context) => Dialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Edit Profile',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: nameController,
                      decoration: InputDecoration(
                        labelText: 'Full Name',
                        prefixIcon: const Icon(Icons.person),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: emailController,
                      decoration: InputDecoration(
                        labelText: 'Email',
                        prefixIcon: const Icon(Icons.email),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: phoneController,
                      decoration: InputDecoration(
                        labelText: 'Phone Number',
                        prefixIcon: const Icon(Icons.phone),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: addressController,
                      decoration: InputDecoration(
                        labelText: 'Address',
                        prefixIcon: const Icon(Icons.location_on),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () async {
                          try {
                            final user = FirebaseAuth.instance.currentUser;
                            if (user != null) {
                              await FirebaseFirestore.instance
                                  .collection('users')
                                  .doc(user.uid)
                                  .update({
                                    'fullName': nameController.text.trim(),
                                    'phoneNumber': phoneController.text.trim(),
                                    'address': addressController.text.trim(),
                                  });

                              // Update local state
                              setState(() {
                                _userName = nameController.text.trim();
                                _userPhone = phoneController.text.trim();
                                _userAddress = addressController.text.trim();
                              });

                              Navigator.pop(context);
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Profile updated successfully'),
                                  backgroundColor: Colors.green,
                                ),
                              );
                            }
                          } catch (e) {
                            print('Error updating profile: $e');
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Failed to update profile'),
                                backgroundColor: Colors.red,
                              ),
                            );
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text(
                          'Save Changes',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
    );
  }

  void _showChangePasswordDialog(BuildContext context) {
    final TextEditingController currentPasswordController =
        TextEditingController();
    final TextEditingController newPasswordController = TextEditingController();
    final TextEditingController confirmPasswordController =
        TextEditingController();
    final ValueNotifier<String?> errorNotifier = ValueNotifier<String?>(null);

    showDialog(
      context: context,
      builder:
          (context) => Dialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Change Password',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: currentPasswordController,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: 'Current Password',
                      prefixIcon: Icon(Icons.lock_outline),
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: newPasswordController,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: 'New Password',
                      prefixIcon: Icon(Icons.lock),
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: confirmPasswordController,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: 'Confirm New Password',
                      prefixIcon: Icon(Icons.lock),
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  ValueListenableBuilder<String?>(
                    valueListenable: errorNotifier,
                    builder:
                        (context, error, child) =>
                            error == null
                                ? const SizedBox.shrink()
                                : Padding(
                                  padding: const EdgeInsets.only(bottom: 8),
                                  child: Text(
                                    error,
                                    style: const TextStyle(color: Colors.red),
                                  ),
                                ),
                  ),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () async {
                        final current = currentPasswordController.text;
                        final newPass = newPasswordController.text;
                        final confirm = confirmPasswordController.text;

                        if (current.isEmpty ||
                            newPass.isEmpty ||
                            confirm.isEmpty) {
                          errorNotifier.value = 'All fields are required.';
                          return;
                        }

                        if (newPass != confirm) {
                          errorNotifier.value = 'New passwords do not match.';
                          return;
                        }

                        if (newPass.length < 6) {
                          errorNotifier.value =
                              'New password must be at least 6 characters.';
                          return;
                        }

                        try {
                          final user = FirebaseAuth.instance.currentUser;
                          if (user != null && user.email != null) {
                            // Re-authenticate user with current password
                            final credential = EmailAuthProvider.credential(
                              email: user.email!,
                              password: current,
                            );
                            await user.reauthenticateWithCredential(credential);

                            // Update password
                            await user.updatePassword(newPass);

                            Navigator.pop(context);
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Password changed successfully!'),
                                backgroundColor: Colors.green,
                              ),
                            );
                          }
                        } on FirebaseAuthException catch (e) {
                          String errorMessage =
                              'An error occurred while changing password.';
                          if (e.code == 'wrong-password') {
                            errorMessage = 'Current password is incorrect.';
                          } else if (e.code == 'weak-password') {
                            errorMessage = 'New password is too weak.';
                          } else if (e.code == 'requires-recent-login') {
                            errorMessage =
                                'Please log out and log in again before changing password.';
                          }
                          errorNotifier.value = errorMessage;
                        } catch (e) {
                          errorNotifier.value = 'An unexpected error occurred.';
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'Change Password',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    return Scaffold(
      body:
          user == null
              ? const Center(child: Text('Not logged in'))
              : StreamBuilder<DocumentSnapshot>(
                stream:
                    FirebaseFirestore.instance
                        .collection('users')
                        .doc(user.uid)
                        .snapshots(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final data = snapshot.data!.data() as Map<String, dynamic>?;
                  if (data == null) {
                    return const Center(child: Text('No user data found'));
                  }
                  _userName = data['fullName'] ?? 'Unknown Expert';
                  _userRole = data['role'] ?? 'Expert';
                  _userEmail = data['email'] ?? '';
                  _userPhone = data['phoneNumber'] ?? '';
                  _userAddress = data['address'] ?? '';
                  _profileImageUrl = data['imageProfile'];
                  _isLoading = false;
                  return SingleChildScrollView(
                    child: Column(
                      children: [
                        // Profile Header
                        Container(
                          color: Colors.green,
                          padding: const EdgeInsets.only(bottom: 24.0),
                          child: Column(
                            children: [
                              // Profile Picture
                              Stack(
                                children: [
                                  Container(
                                    margin: const EdgeInsets.only(top: 16),
                                    width: 140,
                                    height: 140,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: Colors.white,
                                        width: 4,
                                      ),
                                      color: Colors.white,
                                    ),
                                    child:
                                        _profileImage != null
                                            ? ClipOval(
                                              child: Image.file(
                                                _profileImage!,
                                                width: 140,
                                                height: 140,
                                                fit: BoxFit.cover,
                                              ),
                                            )
                                            : _profileImageUrl != null
                                            ? ClipOval(
                                              child: Image.network(
                                                _profileImageUrl!,
                                                width: 140,
                                                height: 140,
                                                fit: BoxFit.cover,
                                                errorBuilder:
                                                    (
                                                      context,
                                                      error,
                                                      stackTrace,
                                                    ) => const Icon(
                                                      Icons.person,
                                                      size: 90,
                                                      color: Colors.green,
                                                    ),
                                              ),
                                            )
                                            : const Icon(
                                              Icons.person,
                                              size: 90,
                                              color: Colors.green,
                                            ),
                                  ),
                                  Positioned(
                                    bottom: 0,
                                    right: 0,
                                    child: GestureDetector(
                                      onTap: _pickProfileImage,
                                      child: Container(
                                        width: 38,
                                        height: 38,
                                        decoration: const BoxDecoration(
                                          color: Colors.white,
                                          shape: BoxShape.circle,
                                          boxShadow: [
                                            BoxShadow(
                                              color: Colors.black12,
                                              blurRadius: 4,
                                              offset: Offset(0, 2),
                                            ),
                                          ],
                                        ),
                                        child: const Center(
                                          child: Icon(
                                            Icons.camera_alt,
                                            size: 22,
                                            color: Colors.green,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              // Expert Name
                              Text(
                                _isLoading ? 'Loading...' : _userName,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 4),
                              // Expert Role
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  _userRole,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 20),
                              // Stats Row
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 32,
                                ),
                                child: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceEvenly,
                                  children: [
                                    GestureDetector(
                                      onTap: () {
                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
                                          const SnackBar(
                                            content: Text(
                                              'Overall Completed Reviews clicked!',
                                            ),
                                          ),
                                        );
                                      },
                                      child: Column(
                                        children: [
                                          Text(
                                            _completedReviews.toString(),
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 24,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          const Text(
                                            'Completed Reviews',
                                            textAlign: TextAlign.center,
                                            style: TextStyle(
                                              color: Colors.white70,
                                              fontSize: 13,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    // REMOVE divider and Farmers Under Care stat
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        // Profile Options
                        Container(
                          margin: const EdgeInsets.symmetric(horizontal: 16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.05),
                                blurRadius: 10,
                                offset: const Offset(0, 5),
                              ),
                            ],
                          ),
                          child: Column(
                            children: [
                              _buildProfileOption(
                                title: 'Edit Profile',
                                icon: Icons.edit,
                                onTap: () => _showEditProfileDialog(context),
                              ),
                              _buildProfileOption(
                                title: 'About App',
                                icon: Icons.info,
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder:
                                          (context) => const AboutAppPage(),
                                    ),
                                  );
                                },
                              ),
                              _buildProfileOption(
                                title: 'Change Password',
                                icon: Icons.lock,
                                onTap: () => _showChangePasswordDialog(context),
                              ),
                              _buildProfileOption(
                                title: 'Log Out',
                                icon: Icons.logout,
                                showDivider: false,
                                onTap: () async {
                                  final shouldLogout = await showDialog<bool>(
                                    context: context,
                                    builder:
                                        (context) => AlertDialog(
                                          title: const Text('Confirm Logout'),
                                          content: const Text(
                                            'Are you sure you want to logout?',
                                          ),
                                          actions: [
                                            TextButton(
                                              onPressed:
                                                  () => Navigator.of(
                                                    context,
                                                  ).pop(false),
                                              child: const Text('Cancel'),
                                            ),
                                            TextButton(
                                              onPressed:
                                                  () => Navigator.of(
                                                    context,
                                                  ).pop(true),
                                              child: const Text('Logout'),
                                            ),
                                          ],
                                        ),
                                  );
                                  if (shouldLogout == true) {
                                    // Sign out from Firebase
                                    await FirebaseAuth.instance.signOut();
                                    // Clear Hive userBox
                                    final userBox = await Hive.openBox(
                                      'userBox',
                                    );
                                    await userBox.clear();
                                    Navigator.pushAndRemoveUntil(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) => const LoginPage(),
                                      ),
                                      (route) => false,
                                    );
                                  }
                                },
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        // Preferences Section
                        Container(
                          margin: const EdgeInsets.symmetric(horizontal: 16),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.05),
                                blurRadius: 10,
                                offset: const Offset(0, 5),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Padding(
                                padding: EdgeInsets.only(top: 8, bottom: 4),
                                child: Text(
                                  'Preferences',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.green,
                                  ),
                                ),
                              ),
                              SwitchListTile(
                                value: _notificationsEnabled,
                                onChanged: (value) async {
                                  setState(() {
                                    _notificationsEnabled = value;
                                  });
                                  // Persist locally
                                  try {
                                    final settingsBox = await Hive.openBox(
                                      'settings',
                                    );
                                    await settingsBox.put(
                                      'enableNotifications',
                                      value,
                                    );
                                  } catch (_) {}
                                  // Mirror to Firestore for backend gating
                                  final user =
                                      FirebaseAuth.instance.currentUser;
                                  if (user != null) {
                                    try {
                                      await FirebaseFirestore.instance
                                          .collection('users')
                                          .doc(user.uid)
                                          .update({
                                            'enableNotifications': value,
                                          });
                                    } catch (_) {}
                                  }
                                  // Apply topic change immediately (experts -> all_users + experts)
                                  try {
                                    if (value) {
                                      await FirebaseMessaging.instance
                                          .subscribeToTopic('all_users');
                                      await FirebaseMessaging.instance
                                          .subscribeToTopic('experts');
                                    } else {
                                      await FirebaseMessaging.instance
                                          .unsubscribeFromTopic('all_users');
                                      await FirebaseMessaging.instance
                                          .unsubscribeFromTopic('experts');
                                    }
                                  } catch (_) {}
                                },
                                title: const Text('Enable Notifications'),
                                secondary: const Icon(
                                  Icons.notifications,
                                  color: Colors.green,
                                ),
                                contentPadding: EdgeInsets.zero,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        // Description
                        Container(
                          margin: const EdgeInsets.symmetric(horizontal: 16),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.green.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: Colors.green.withOpacity(0.3),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Expert Access',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.green,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'This profile is exclusively for plant disease experts. Regular users and other personnel do not have access to this interface.',
                                style: TextStyle(
                                  color: Colors.grey[700],
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),
                        // App Version
                        const SizedBox(height: 24),
                      ],
                    ),
                  );
                },
              ),
    );
  }
}
