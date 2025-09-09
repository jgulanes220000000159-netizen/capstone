import 'package:flutter/material.dart';
import 'login_page.dart';
import 'edit_profile_page.dart';
import '../about_app_page.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:hive/hive.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({Key? key}) : super(key: key);

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  File? _profileImage;
  final ImagePicker _picker = ImagePicker();
  bool _notificationsEnabled = false;

  // User data variables
  String _userName = 'Loading...';
  String _userRole = 'Farmer';
  String _userEmail = '';
  String _userPhone = '';
  String _userAddress = '';
  String? _profileImageUrl;
  int _scanCount = 0;
  int _diseaseCount = 0;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadUserData();
    _loadTotalScanCount();
    try {
      final settingsBox = Hive.box('settings');
      _notificationsEnabled =
          settingsBox.get('enableNotifications', defaultValue: false) as bool;
    } catch (_) {}
  }

  Future<void> _loadUserData() async {
    try {
      final userBox = await Hive.openBox('userBox');
      final localProfile = userBox.get('userProfile');
      if (localProfile != null) {
        setState(() {
          _userName = localProfile['fullName'] ?? 'Unknown User';
          _userRole = localProfile['role'] ?? 'Farmer';
          _userEmail = localProfile['email'] ?? '';
          _userPhone = localProfile['phoneNumber'] ?? '';
          _userAddress = localProfile['address'] ?? '';
          _profileImageUrl = localProfile['imageProfile'];
          _isLoading = false;
        });
        return;
      }
      // If not found locally, try Firestore (online)
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
            _userName = data['fullName'] ?? 'Unknown User';
            _userRole = data['role'] ?? 'Farmer';
            _userEmail = data['email'] ?? '';
            _userPhone = data['phoneNumber'] ?? '';
            _userAddress = data['address'] ?? '';
            _profileImageUrl = data['imageProfile'];
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      print('Error loading user data: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _loadTotalScanCount() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;
      final userId = user.uid;
      // Count all scan_requests
      final scanReqQuery =
          await FirebaseFirestore.instance
              .collection('scan_requests')
              .where('userId', isEqualTo: userId)
              .get();
      int scanReqCount = scanReqQuery.docs.length;
      // Count all tracking sessions
      final trackingQuery =
          await FirebaseFirestore.instance
              .collection('tracking')
              .where('userId', isEqualTo: userId)
              .get();
      int trackingCount = trackingQuery.docs.length;
      setState(() {
        _scanCount = scanReqCount + trackingCount;
      });
    } catch (e) {
      print('Error loading total scan count: $e');
    }
  }

  Future<void> _loadUserStats(String userId) async {
    try {
      // Count user's scan requests
      final scanQuery =
          await FirebaseFirestore.instance
              .collection('scan_requests')
              .where('userId', isEqualTo: userId)
              .get();

      // Count unique diseases detected
      final diseaseQuery =
          await FirebaseFirestore.instance
              .collection('scan_requests')
              .where('userId', isEqualTo: userId)
              .where('status', isEqualTo: 'completed')
              .get();

      int uniqueDiseases = 0;
      Set<String> diseases = {};

      for (var doc in diseaseQuery.docs) {
        final data = doc.data();
        if (data['diseaseSummary'] != null) {
          for (var disease in data['diseaseSummary']) {
            if (disease['name'] != null && disease['name'] != 'Healthy') {
              diseases.add(disease['name']);
            }
          }
        }
      }

      setState(() {
        _scanCount = scanQuery.docs.length;
        _diseaseCount = diseases.length;
      });
    } catch (e) {
      print('Error loading user stats: $e');
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

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        backgroundColor: Colors.green,
        title: Text(
          tr('profile'),
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        elevation: 0,
      ),
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
                  _userName = data['fullName'] ?? 'Unknown User';
                  _userRole = data['role'] ?? 'Farmer';
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
                                    width: 120,
                                    height: 120,
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
                                                width: 120,
                                                height: 120,
                                                fit: BoxFit.cover,
                                              ),
                                            )
                                            : _profileImageUrl != null
                                            ? ClipOval(
                                              child: Image.network(
                                                _profileImageUrl!,
                                                width: 120,
                                                height: 120,
                                                fit: BoxFit.cover,
                                                errorBuilder:
                                                    (
                                                      context,
                                                      error,
                                                      stackTrace,
                                                    ) => const Icon(
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
                                  ),
                                  Positioned(
                                    bottom: 0,
                                    right: 0,
                                    child: GestureDetector(
                                      onTap: _pickProfileImage,
                                      child: Container(
                                        padding: const EdgeInsets.all(4),
                                        decoration: const BoxDecoration(
                                          color: Colors.white,
                                          shape: BoxShape.circle,
                                        ),
                                        child: const Icon(
                                          Icons.camera_alt,
                                          size: 20,
                                          color: Colors.green,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              // User Name
                              Text(
                                _isLoading ? tr('loading') : _userName,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 4),
                              // Role
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
                                  tr(_userRole.toLowerCase()),
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
                                            content: Text('Scans clicked!'),
                                          ),
                                        );
                                      },
                                      child: _buildStat(
                                        tr('scans'),
                                        _scanCount.toString(),
                                      ),
                                    ),
                                    // Removed diseases detected stat
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
                                title: tr('edit_profile'),
                                icon: Icons.edit,
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder:
                                          (context) => const EditProfilePage(),
                                    ),
                                  );
                                },
                              ),
                              _buildProfileOption(
                                title: tr('about_app'),
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
                                title: tr('change_password'),
                                icon: Icons.lock,
                                onTap: () => _showChangePasswordDialog(context),
                              ),
                              _buildProfileOption(
                                title: tr('log_out'),
                                icon: Icons.logout,
                                showDivider: false,
                                onTap: () async {
                                  final shouldLogout = await showDialog<bool>(
                                    context: context,
                                    builder:
                                        (context) => AlertDialog(
                                          title: Text(tr('confirm_logout')),
                                          content: Text(
                                            tr('are_you_sure_logout'),
                                          ),
                                          actions: [
                                            TextButton(
                                              onPressed:
                                                  () => Navigator.of(
                                                    context,
                                                  ).pop(false),
                                              child: Text(tr('cancel')),
                                            ),
                                            TextButton(
                                              onPressed:
                                                  () => Navigator.of(
                                                    context,
                                                  ).pop(true),
                                              child: Text(tr('logout')),
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
                              Padding(
                                padding: const EdgeInsets.only(
                                  top: 8,
                                  bottom: 4,
                                ),
                                child: Text(
                                  tr('preferences'),
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.green,
                                  ),
                                ),
                              ),
                              // Language Picker
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 4.0,
                                ),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        tr('choose_language'),
                                        style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Flexible(
                                      child: DropdownButton<Locale>(
                                        value: context.locale,
                                        onChanged: (Locale? locale) async {
                                          if (locale != null &&
                                              locale != context.locale) {
                                            // Show confirmation dialog
                                            final confirmed = await showDialog<
                                              bool
                                            >(
                                              context: context,
                                              builder: (BuildContext context) {
                                                return AlertDialog(
                                                  title: Row(
                                                    children: [
                                                      Icon(
                                                        Icons.language,
                                                        color:
                                                            Colors.green[700],
                                                        size: 24,
                                                      ),
                                                      const SizedBox(width: 8),
                                                      Expanded(
                                                        child: Text(
                                                          tr('change_language'),
                                                          style:
                                                              const TextStyle(
                                                                fontWeight:
                                                                    FontWeight
                                                                        .bold,
                                                              ),
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                  content: Column(
                                                    mainAxisSize:
                                                        MainAxisSize.min,
                                                    crossAxisAlignment:
                                                        CrossAxisAlignment
                                                            .start,
                                                    children: [
                                                      Text(
                                                        tr(
                                                          'change_language_confirm',
                                                        ),
                                                        style: const TextStyle(
                                                          fontSize: 16,
                                                        ),
                                                      ),
                                                      const SizedBox(
                                                        height: 12,
                                                      ),
                                                      Container(
                                                        padding:
                                                            const EdgeInsets.all(
                                                              12,
                                                            ),
                                                        decoration: BoxDecoration(
                                                          color:
                                                              Colors.green[50],
                                                          borderRadius:
                                                              BorderRadius.circular(
                                                                8,
                                                              ),
                                                          border: Border.all(
                                                            color:
                                                                Colors
                                                                    .green[200]!,
                                                          ),
                                                        ),
                                                        child: Row(
                                                          crossAxisAlignment:
                                                              CrossAxisAlignment
                                                                  .start,
                                                          children: [
                                                            Icon(
                                                              Icons
                                                                  .info_outline,
                                                              color:
                                                                  Colors
                                                                      .green[700],
                                                              size: 20,
                                                            ),
                                                            const SizedBox(
                                                              width: 8,
                                                            ),
                                                            Expanded(
                                                              child: Text(
                                                                tr(
                                                                  'language_change_note',
                                                                ),
                                                                style: TextStyle(
                                                                  fontSize: 14,
                                                                  color:
                                                                      Colors
                                                                          .green[700],
                                                                ),
                                                              ),
                                                            ),
                                                          ],
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                  actions: [
                                                    TextButton(
                                                      onPressed:
                                                          () => Navigator.of(
                                                            context,
                                                          ).pop(false),
                                                      child: Text(tr('cancel')),
                                                    ),
                                                    ElevatedButton(
                                                      onPressed:
                                                          () => Navigator.of(
                                                            context,
                                                          ).pop(true),
                                                      style:
                                                          ElevatedButton.styleFrom(
                                                            backgroundColor:
                                                                Colors
                                                                    .green[600],
                                                            foregroundColor:
                                                                Colors.white,
                                                          ),
                                                      child: Text(tr('change')),
                                                    ),
                                                  ],
                                                );
                                              },
                                            );

                                            if (confirmed == true) {
                                              // Change the locale
                                              context.setLocale(locale);

                                              // Save to settings
                                              final settingsBox =
                                                  await Hive.openBox(
                                                    'settings',
                                                  );
                                              await settingsBox.put(
                                                'locale_code',
                                                locale.languageCode,
                                              );

                                              // Show success message
                                              if (mounted) {
                                                ScaffoldMessenger.of(
                                                  context,
                                                ).showSnackBar(
                                                  SnackBar(
                                                    content: Row(
                                                      children: [
                                                        const Icon(
                                                          Icons.check_circle,
                                                          color: Colors.white,
                                                          size: 20,
                                                        ),
                                                        const SizedBox(
                                                          width: 8,
                                                        ),
                                                        Text(
                                                          tr(
                                                            'language_changed_successfully',
                                                          ),
                                                          style:
                                                              const TextStyle(
                                                                fontSize: 16,
                                                              ),
                                                        ),
                                                      ],
                                                    ),
                                                    backgroundColor:
                                                        Colors.green[600],
                                                    duration: const Duration(
                                                      seconds: 2,
                                                    ),
                                                  ),
                                                );

                                                // Refresh the app after a short delay
                                                Future.delayed(
                                                  const Duration(
                                                    milliseconds: 500,
                                                  ),
                                                  () {
                                                    if (mounted) {
                                                      Navigator.of(
                                                        context,
                                                      ).pushNamedAndRemoveUntil(
                                                        '/user-home',
                                                        (route) => false,
                                                      );
                                                    }
                                                  },
                                                );
                                              }
                                            }
                                          }
                                        },
                                        items: [
                                          DropdownMenuItem(
                                            value: const Locale('en'),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                const Text('🇺🇸'),
                                                const SizedBox(width: 4),
                                                const Text('English'),
                                              ],
                                            ),
                                          ),
                                          DropdownMenuItem(
                                            value: const Locale('bs'),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                const Text('🇵🇭'),
                                                const SizedBox(width: 4),
                                                const Text('Bisaya'),
                                              ],
                                            ),
                                          ),
                                          DropdownMenuItem(
                                            value: const Locale('tl'),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                const Text('🇵🇭'),
                                                const SizedBox(width: 4),
                                                const Text('Tagalog'),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
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
                                  try {
                                    final user =
                                        FirebaseAuth.instance.currentUser;
                                    if (user != null) {
                                      await FirebaseFirestore.instance
                                          .collection('users')
                                          .doc(user.uid)
                                          .update({
                                            'enableNotifications': value,
                                          });
                                    }
                                  } catch (_) {}
                                  // Apply topic change immediately (farmers -> all_users)
                                  try {
                                    if (value) {
                                      await FirebaseMessaging.instance
                                          .subscribeToTopic('all_users');
                                      // keep farmers off experts
                                      await FirebaseMessaging.instance
                                          .unsubscribeFromTopic('experts');
                                    } else {
                                      await FirebaseMessaging.instance
                                          .unsubscribeFromTopic('all_users');
                                      await FirebaseMessaging.instance
                                          .unsubscribeFromTopic('experts');
                                    }
                                  } catch (_) {}
                                },
                                title: Text(tr('enable_notifications')),
                                secondary: const Icon(
                                  Icons.notifications,
                                  color: Colors.green,
                                ),
                                contentPadding: EdgeInsets.zero,
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

  Widget _buildStat(String label, String value) {
    return Column(
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
          style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 12),
        ),
      ],
    );
  }

  void _showChangePasswordDialog(BuildContext context) {
    final TextEditingController currentPasswordController =
        TextEditingController();
    final TextEditingController newPasswordController = TextEditingController();
    final TextEditingController confirmPasswordController =
        TextEditingController();
    final ValueNotifier<String?> errorNotifier = ValueNotifier<String?>(null);
    final ValueNotifier<bool> isLoadingNotifier = ValueNotifier<bool>(false);

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
                      Text(
                        tr('change_password'),
                        style: const TextStyle(
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
                    decoration: InputDecoration(
                      labelText: tr('current_password'),
                      prefixIcon: const Icon(Icons.lock_outline),
                      border: const OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: newPasswordController,
                    obscureText: true,
                    decoration: InputDecoration(
                      labelText: tr('new_password'),
                      prefixIcon: const Icon(Icons.lock),
                      border: const OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: confirmPasswordController,
                    obscureText: true,
                    decoration: InputDecoration(
                      labelText: tr('confirm_new_password'),
                      prefixIcon: const Icon(Icons.lock),
                      border: const OutlineInputBorder(),
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
                    child: ValueListenableBuilder<bool>(
                      valueListenable: isLoadingNotifier,
                      builder:
                          (context, isLoading, child) => ElevatedButton(
                            onPressed:
                                isLoading
                                    ? null
                                    : () async {
                                      final current =
                                          currentPasswordController.text;
                                      final newPass =
                                          newPasswordController.text;
                                      final confirm =
                                          confirmPasswordController.text;

                                      if (current.isEmpty ||
                                          newPass.isEmpty ||
                                          confirm.isEmpty) {
                                        errorNotifier.value = tr(
                                          'all_fields_required',
                                        );
                                        return;
                                      }

                                      if (newPass != confirm) {
                                        errorNotifier.value = tr(
                                          'new_passwords_do_not_match',
                                        );
                                        return;
                                      }

                                      if (newPass.length < 6) {
                                        errorNotifier.value = tr(
                                          'new_password_min_length',
                                        );
                                        return;
                                      }

                                      isLoadingNotifier.value = true;
                                      errorNotifier.value = null;

                                      try {
                                        final user =
                                            FirebaseAuth.instance.currentUser;
                                        if (user != null &&
                                            user.email != null) {
                                          // Re-authenticate user with current password
                                          final credential =
                                              EmailAuthProvider.credential(
                                                email: user.email!,
                                                password: current,
                                              );
                                          await user
                                              .reauthenticateWithCredential(
                                                credential,
                                              );

                                          // Update password
                                          await user.updatePassword(newPass);

                                          Navigator.pop(context);
                                          ScaffoldMessenger.of(
                                            context,
                                          ).showSnackBar(
                                            SnackBar(
                                              content: Text(
                                                tr(
                                                  'password_changed_successfully',
                                                ),
                                              ),
                                              backgroundColor: Colors.green,
                                            ),
                                          );
                                        }
                                      } on FirebaseAuthException catch (e) {
                                        String errorMessage = tr(
                                          'error_changing_password',
                                        );
                                        if (e.code == 'wrong-password') {
                                          errorMessage = tr(
                                            'current_password_incorrect',
                                          );
                                        } else if (e.code == 'weak-password') {
                                          errorMessage = tr(
                                            'new_password_too_weak',
                                          );
                                        } else if (e.code ==
                                            'requires-recent-login') {
                                          errorMessage = tr(
                                            'please_relogin_change_password',
                                          );
                                        }
                                        errorNotifier.value = errorMessage;
                                      } catch (e) {
                                        errorNotifier.value = tr(
                                          'unexpected_error_occurred',
                                        );
                                      } finally {
                                        isLoadingNotifier.value = false;
                                      }
                                    },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child:
                                isLoading
                                    ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        valueColor:
                                            AlwaysStoppedAnimation<Color>(
                                              Colors.white,
                                            ),
                                      ),
                                    )
                                    : Text(
                                      tr('change_password'),
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                      ),
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
}
