import 'package:flutter/material.dart';
// import '../routes.dart';
import '../about_app_page.dart';
import '../user/login_page.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:mime/mime.dart';
import 'package:hive/hive.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:cached_network_image/cached_network_image.dart';

class ExpertProfile extends StatefulWidget {
  const ExpertProfile({Key? key}) : super(key: key);

  @override
  State<ExpertProfile> createState() => _ExpertProfileState();
}

class _ExpertProfileState extends State<ExpertProfile> {
  File? _profileImage;
  final ImagePicker _picker = ImagePicker();
  bool _notificationsEnabled = false;
  bool _isUploadingImage = false;

  // User data variables
  String _userName = 'Loading...';
  String _userRole = 'Expert';
  String _userEmail = '';
  String _userPhone = '';
  String _userAddress = '';
  String? _profileImageUrl;
  String _memberSince = 'Loading...';
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadUserData();
    _saveFcmTokenToFirestore();
    _listenToProfileUpdates();
    try {
      final settingsBox = Hive.box('settings');
      if (!settingsBox.containsKey('enableNotifications')) {
        settingsBox.put('enableNotifications', true);
      }
      final enabled =
          settingsBox.get('enableNotifications', defaultValue: true) as bool;
      _notificationsEnabled = enabled;
    } catch (_) {}
  }

  void _listenToProfileUpdates() {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .snapshots()
          .listen((snapshot) async {
            if (snapshot.exists) {
              final data = snapshot.data() as Map<String, dynamic>;

              // Save to Hive cache
              final userBox = await Hive.openBox('userBox');
              await userBox.put('userProfile', data);

              // Update UI
              if (mounted) {
                setState(() {
                  _userName = data['fullName'] ?? 'Unknown Expert';
                  _userRole = data['role'] ?? 'Expert';
                  _userEmail = data['email'] ?? '';
                  _userPhone = data['phoneNumber'] ?? '';
                  _userAddress = data['address'] ?? '';
                  _profileImageUrl = data['imageProfile'];
                });
              }
            }
          });
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Refresh member since when page is focused
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      _loadMemberSince(user);
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

        // Load member since even when using local data
        final user = FirebaseAuth.instance.currentUser;
        if (user != null) {
          _loadMemberSince(user);
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

          // Load member since
          _loadMemberSince(user);
        }
      }
    } catch (e) {
      print('Error loading user data: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _loadMemberSince(User user) {
    try {
      final creationTime = user.metadata.creationTime;
      if (creationTime != null) {
        // Format as "Month Year" (e.g., "January 2024")
        final monthNames = [
          'January',
          'February',
          'March',
          'April',
          'May',
          'June',
          'July',
          'August',
          'September',
          'October',
          'November',
          'December',
        ];
        final month = monthNames[creationTime.month - 1];
        final year = creationTime.year;

        setState(() {
          _memberSince = '$month $year';
        });
      }
    } catch (e) {
      print('Error loading member since: $e');
      setState(() {
        _memberSince = 'N/A';
      });
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
    setState(() {
      _isUploadingImage = true;
    });

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final file = File(imagePath);
        final ref = FirebaseStorage.instance
            .ref()
            .child('profile')
            .child('${user.uid}.jpg');

        final detectedMime = lookupMimeType(file.path) ?? 'image/jpeg';

        // Upload with 20 second timeout
        await ref
            .putFile(file, SettableMetadata(contentType: detectedMime))
            .timeout(
              const Duration(seconds: 20),
              onTimeout: () {
                throw Exception(
                  'Upload timeout - Please check your internet connection',
                );
              },
            );

        final url = await ref.getDownloadURL().timeout(
          const Duration(seconds: 10),
          onTimeout: () {
            throw Exception('Timeout getting image URL - Please try again');
          },
        );

        // Update Firestore with new image URL
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .update({'imageProfile': url})
            .timeout(
              const Duration(seconds: 10),
              onTimeout: () {
                throw Exception(
                  'Timeout updating profile - Please check your connection',
                );
              },
            );

        // Update Hive cache immediately
        final userBox = await Hive.openBox('userBox');
        final cachedProfile =
            userBox.get('userProfile') as Map<dynamic, dynamic>?;
        if (cachedProfile != null) {
          final updatedProfile = Map<String, dynamic>.from(cachedProfile);
          updatedProfile['imageProfile'] = url;
          await userBox.put('userProfile', updatedProfile);
        }

        if (!mounted) return;
        setState(() {
          _profileImageUrl = url;
          _isUploadingImage = false;
        });

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profile image updated successfully!'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      print('Error uploading profile image: $e');
      if (!mounted) return;
      setState(() {
        _isUploadingImage = false;
      });

      // Determine error message based on error type
      String errorMessage = 'Failed to update profile image';
      if (e.toString().contains('timeout') ||
          e.toString().contains('Timeout')) {
        errorMessage =
            'Upload timeout - Please check your internet connection and try again';
      } else if (e.toString().contains('network') ||
          e.toString().contains('connection')) {
        errorMessage = 'Network error - Please check your internet connection';
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(errorMessage),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 4),
        ),
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
              : _isLoading
              ? const Center(child: CircularProgressIndicator())
              : SingleChildScrollView(
                child: Column(
                  children: [
                    // Profile Card
                    Container(
                      color: Colors.green[50],
                      padding: const EdgeInsets.symmetric(vertical: 24.0),
                      child: Column(
                        children: [
                          // Profile Picture
                          Stack(
                            children: [
                              Container(
                                width: 120,
                                height: 120,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: Colors.white,
                                    width: 4,
                                  ),
                                  color: Colors.white,
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.2),
                                      blurRadius: 10,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: Stack(
                                  children: [
                                    _profileImage != null
                                        ? ClipOval(
                                          child: Image.file(
                                            _profileImage!,
                                            width: 120,
                                            height: 120,
                                            fit: BoxFit.cover,
                                          ),
                                        )
                                        : _profileImageUrl != null
                                        ? ClipOval(
                                          child: CachedNetworkImage(
                                            imageUrl: _profileImageUrl!,
                                            width: 120,
                                            height: 120,
                                            fit: BoxFit.cover,
                                            placeholder:
                                                (context, url) =>
                                                    const CircularProgressIndicator(),
                                            errorWidget:
                                                (context, url, error) =>
                                                    const Icon(
                                                      Icons.person,
                                                      size: 70,
                                                      color: Colors.green,
                                                    ),
                                          ),
                                        )
                                        : const Icon(
                                          Icons.person,
                                          size: 70,
                                          color: Colors.green,
                                        ),
                                    // Upload indicator overlay
                                    if (_isUploadingImage)
                                      Container(
                                        width: 120,
                                        height: 120,
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          color: Colors.black.withOpacity(0.6),
                                        ),
                                        child: const Center(
                                          child: Column(
                                            mainAxisAlignment:
                                                MainAxisAlignment.center,
                                            children: [
                                              CircularProgressIndicator(
                                                color: Colors.white,
                                                strokeWidth: 3,
                                              ),
                                              SizedBox(height: 8),
                                              Text(
                                                'Uploading...',
                                                style: TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                              Positioned(
                                bottom: 0,
                                right: 0,
                                child: GestureDetector(
                                  onTap: _pickProfileImage,
                                  child: Container(
                                    width: 36,
                                    height: 36,
                                    decoration: BoxDecoration(
                                      color: Colors.green[700],
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: Colors.white,
                                        width: 3,
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withOpacity(0.2),
                                          blurRadius: 6,
                                          offset: const Offset(0, 2),
                                        ),
                                      ],
                                    ),
                                    child: const Center(
                                      child: Icon(
                                        Icons.camera_alt,
                                        size: 18,
                                        color: Colors.white,
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
                              color: Colors.black87,
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 8),
                          // Expert Role Badge
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.green,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              _userRole.toLowerCase(),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                          const SizedBox(height: 20),
                          // Member Since Card
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 24,
                              vertical: 16,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.1),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Column(
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.calendar_today,
                                      color: Colors.green,
                                      size: 20,
                                    ),
                                    const SizedBox(width: 8),
                                    Flexible(
                                      child: Text(
                                        _memberSince,
                                        style: TextStyle(
                                          color: Colors.green[700],
                                          fontSize: 24,
                                          fontWeight: FontWeight.bold,
                                        ),
                                        textAlign: TextAlign.center,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Member Since',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: Colors.grey[700],
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
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
                                  builder: (context) => const AboutAppPage(),
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
                                final userBox = await Hive.openBox('userBox');
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
                              final user = FirebaseAuth.instance.currentUser;
                              if (user != null) {
                                try {
                                  await FirebaseFirestore.instance
                                      .collection('users')
                                      .doc(user.uid)
                                      .update({'enableNotifications': value});
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
              ),
    );
  }
}
