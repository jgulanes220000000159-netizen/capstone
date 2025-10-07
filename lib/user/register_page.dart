import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'login_page.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({Key? key}) : super(key: key);

  @override
  _RegisterPageState createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final _formKey = GlobalKey<FormState>();
  final _fullNameController = TextEditingController();
  final _addressController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  final GoogleSignIn _googleSignIn = GoogleSignIn();

  // Password strength tracking
  String _passwordStrength = '';
  Color _passwordStrengthColor = Colors.grey;

  // Password strength calculation
  void _calculatePasswordStrength(String password) {
    bool hasLength = password.length >= 8;
    bool hasUppercase = password.contains(RegExp(r'[A-Z]'));
    bool hasLowercase = password.contains(RegExp(r'[a-z]'));
    bool hasNumber = password.contains(RegExp(r'[0-9]'));
    bool hasSpecialChar = password.contains(RegExp(r'[!@#$%^&*(),.?":{}|<>]'));

    setState(() {
      // Check if all required criteria are met (length, uppercase, lowercase, number)
      bool meetsRequirements =
          hasLength && hasUppercase && hasLowercase && hasNumber;

      if (!hasLength || (!hasUppercase && !hasLowercase && !hasNumber)) {
        _passwordStrength = 'Weak';
        _passwordStrengthColor = Colors.red;
      } else if (!meetsRequirements) {
        _passwordStrength = 'Medium';
        _passwordStrengthColor = Colors.orange;
      } else {
        // All requirements met, check if it has special characters for bonus
        _passwordStrength = hasSpecialChar ? 'Strong' : 'Good';
        _passwordStrengthColor =
            hasSpecialChar ? Colors.green : Colors.lightGreen;
      }
    });
  }

  // Form validation
  String? _validateFullName(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Please enter your full name';
    }
    if (value.trim().length < 2) {
      return 'Name must be at least 2 characters';
    }
    return null;
  }

  String? _validateAddress(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Please enter your address';
    }
    if (value.trim().length < 5) {
      return 'Please enter a complete address';
    }
    return null;
  }

  String? _validatePhone(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Please enter your phone number';
    }
    // Philippine phone number validation: 09XXXXXXXXX (11 digits starting with 09)
    final phoneRegex = RegExp(r'^09\d{9}$');
    String cleanNumber = value.replaceAll(RegExp(r'[\s\-\(\)]'), '');
    if (!phoneRegex.hasMatch(cleanNumber)) {
      return 'Please enter a valid Philippine mobile number (09XXXXXXXXX)';
    }
    return null;
  }

  String? _validateEmail(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Please enter your email';
    }
    final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
    if (!emailRegex.hasMatch(value)) {
      return 'Please enter a valid email address';
    }
    return null;
  }

  String? _validatePassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Please enter a password';
    }
    if (value.length < 8) {
      return 'Password must be at least 8 characters';
    }
    if (!value.contains(RegExp(r'[A-Z]'))) {
      return 'Password must contain at least one uppercase letter';
    }
    if (!value.contains(RegExp(r'[a-z]'))) {
      return 'Password must contain at least one lowercase letter';
    }
    if (!value.contains(RegExp(r'[0-9]'))) {
      return 'Password must contain at least one number';
    }
    return null;
  }

  String? _validateConfirmPassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Please confirm your password';
    }
    if (value != _passwordController.text) {
      return 'Passwords do not match';
    }
    return null;
  }

  void _handleRegister() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // Create user with Firebase Auth
      UserCredential userCredential = await FirebaseAuth.instance
          .createUserWithEmailAndPassword(
            email: _emailController.text.trim(),
            password: _passwordController.text.trim(),
          );
      final user = userCredential.user;
      if (user != null) {
        // Save user profile to Firestore
        await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
          'userId': user.uid,
          'fullName': _fullNameController.text.trim(),
          'address': _addressController.text.trim(),
          'phoneNumber': _phoneController.text.trim(),
          'email': _emailController.text.trim(),
          'role': 'farmer',
          'status': 'pending',
          'imageProfile': '',
          'createdAt': DateTime.now(),
        });
      }
      setState(() {
        _isLoading = false;
      });

      // Show success dialog
      _showSuccessDialog();
    } on FirebaseAuthException catch (e) {
      setState(() {
        _isLoading = false;
      });
      String message = 'Registration failed.';
      if (e.code == 'email-already-in-use') {
        message = 'Email already in use. Please use a different email.';
      } else if (e.code == 'weak-password') {
        message = 'Password is too weak. Please choose a stronger password.';
      } else if (e.code == 'invalid-email') {
        message = 'Please enter a valid email address.';
      } else if (e.code == 'operation-not-allowed') {
        message = 'Email/password accounts are not enabled.';
      }
      _showErrorDialog(message);
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      _showErrorDialog('An unexpected error occurred. Please try again.');
    }
  }

  void _showSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder:
          (context) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.green, size: 28),
                SizedBox(width: 12),
                Text('Success!', style: TextStyle(color: Colors.green)),
              ],
            ),
            content: Text(
              'Account created successfully! Awaiting admin approval. You will receive an email notification once your account is approved.',
              style: TextStyle(fontSize: 16),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(builder: (context) => const LoginPage()),
                  );
                },
                child: Text(
                  'Continue to Login',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
    );
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: Row(
              children: [
                Icon(Icons.error, color: Colors.red, size: 28),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Registration Failed',
                    style: TextStyle(color: Colors.red),
                  ),
                ),
              ],
            ),
            content: SingleChildScrollView(
              child: Text(message, style: TextStyle(fontSize: 16)),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text(
                  'OK',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
    );
  }

  // Google Sign-In for registration
  Future<void> _handleGoogleSignUp() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        setState(() {
          _isLoading = false;
        });
        return;
      }

      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final UserCredential userCredential = await FirebaseAuth.instance
          .signInWithCredential(credential);
      final user = userCredential.user;

      if (user != null) {
        // Check if user already exists
        DocumentSnapshot userDoc =
            await FirebaseFirestore.instance
                .collection('users')
                .doc(user.uid)
                .get();

        if (!userDoc.exists) {
          // Create new user profile
          await FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .set({
                'userId': user.uid,
                'fullName': user.displayName ?? 'Google User',
                'address': '',
                'phoneNumber': user.phoneNumber ?? '',
                'email': user.email ?? '',
                'role': 'farmer',
                'status': 'active', // Google users are auto-approved
                'imageProfile': user.photoURL ?? '',
                'createdAt': DateTime.now(),
              });
        }

        setState(() {
          _isLoading = false;
        });

        _showSuccessDialog();
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      _showErrorDialog('Google Sign-Up failed. Please try again.');
    }
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _addressController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Widget _buildTextField({
    required String label,
    required TextEditingController controller,
    bool isPassword = false,
    bool? obscureText,
    Widget? suffixIcon,
    IconData? prefixIcon,
    String? Function(String?)? validator,
    TextInputType? keyboardType,
    List<TextInputFormatter>? inputFormatters,
    void Function(String)? onChanged,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: isPassword ? (obscureText ?? true) : false,
      style: const TextStyle(color: Colors.white),
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      onChanged: onChanged,
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.white70),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.white70),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.white),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.red),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.red),
        ),
        prefixIcon:
            prefixIcon != null ? Icon(prefixIcon, color: Colors.white70) : null,
        suffixIcon: suffixIcon,
        errorStyle: const TextStyle(color: Colors.redAccent),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.green,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 20),
                  // Logo and App Name
                  Center(
                    child: Column(
                      children: [
                        Container(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.1),
                                blurRadius: 10,
                                offset: const Offset(0, 5),
                              ),
                            ],
                          ),
                          padding: const EdgeInsets.all(12),
                          child: Image.asset(
                            'assets/logo.png',
                            width: 60,
                            height: 60,
                          ),
                        ),
                        const SizedBox(height: 16),
                        const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              'Mango',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 28,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              'Sense',
                              style: TextStyle(
                                color: Colors.yellow,
                                fontSize: 28,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 30),
                  // Sign Up Text
                  const Text(
                    'Sign Up!',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Text(
                    'Create an account, it\'s free',
                    style: TextStyle(color: Colors.white70, fontSize: 16),
                  ),
                  const SizedBox(height: 30),
                  // Form Fields
                  _buildTextField(
                    label: 'Full Name',
                    controller: _fullNameController,
                    prefixIcon: Icons.person,
                    validator: _validateFullName,
                    keyboardType: TextInputType.name,
                  ),
                  const SizedBox(height: 16),
                  _buildTextField(
                    label: 'Address',
                    controller: _addressController,
                    prefixIcon: Icons.home,
                    validator: _validateAddress,
                    keyboardType: TextInputType.streetAddress,
                  ),
                  const SizedBox(height: 16),
                  _buildTextField(
                    label: 'Phone Number',
                    controller: _phoneController,
                    prefixIcon: Icons.phone,
                    validator: _validatePhone,
                    keyboardType: TextInputType.phone,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(15),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _buildTextField(
                    label: 'Email',
                    controller: _emailController,
                    prefixIcon: Icons.email,
                    validator: _validateEmail,
                    keyboardType: TextInputType.emailAddress,
                  ),
                  const SizedBox(height: 16),
                  _buildTextField(
                    label: 'Password',
                    controller: _passwordController,
                    isPassword: true,
                    obscureText: _obscurePassword,
                    validator: _validatePassword,
                    onChanged: _calculatePasswordStrength,
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscurePassword
                            ? Icons.visibility_off
                            : Icons.visibility,
                        color: Colors.white70,
                      ),
                      onPressed: () {
                        setState(() {
                          _obscurePassword = !_obscurePassword;
                        });
                      },
                    ),
                    prefixIcon: Icons.lock,
                  ),
                  // Password Strength Indicator
                  if (_passwordController.text.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Text(
                          'Password Strength: ',
                          style: TextStyle(color: Colors.white70, fontSize: 12),
                        ),
                        Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(
                              color: _passwordStrengthColor,
                              width: 1,
                            ),
                          ),
                          child: Text(
                            _passwordStrength,
                            style: TextStyle(
                              color: _passwordStrengthColor,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Container(
                      height: 6,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(3),
                        border: Border.all(color: Colors.white30, width: 1),
                      ),
                      child: LinearProgressIndicator(
                        value:
                            _passwordStrength == 'Weak'
                                ? 0.3
                                : _passwordStrength == 'Medium'
                                ? 0.6
                                : 1.0,
                        backgroundColor: Colors.white24,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          _passwordStrengthColor,
                        ),
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  _buildTextField(
                    label: 'Confirm Password',
                    controller: _confirmPasswordController,
                    isPassword: true,
                    obscureText: _obscureConfirmPassword,
                    validator: _validateConfirmPassword,
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscureConfirmPassword
                            ? Icons.visibility_off
                            : Icons.visibility,
                        color: Colors.white70,
                      ),
                      onPressed: () {
                        setState(() {
                          _obscureConfirmPassword = !_obscureConfirmPassword;
                        });
                      },
                    ),
                    prefixIcon: Icons.lock_outline,
                  ),
                  const SizedBox(height: 20),
                  const SizedBox(height: 30),
                  // Register Button
                  SizedBox(
                    width: double.infinity,
                    height: 55,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _handleRegister,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 2,
                      ),
                      child:
                          _isLoading
                              ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    Colors.green,
                                  ),
                                ),
                              )
                              : const Text(
                                'Create Account',
                                style: TextStyle(
                                  color: Colors.green,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Divider
                  Row(
                    children: [
                      Expanded(child: Divider(color: Colors.white70)),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Text(
                          'OR',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      Expanded(child: Divider(color: Colors.white70)),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // Google Sign-Up Button
                  SizedBox(
                    width: double.infinity,
                    height: 55,
                    child: ElevatedButton.icon(
                      onPressed: _isLoading ? null : _handleGoogleSignUp,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: Colors.green,
                        elevation: 2,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      icon: Image.asset(
                        'assets/google-icon-1.png',
                        width: 24,
                        height: 24,
                      ),
                      label:
                          _isLoading
                              ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    Colors.green,
                                  ),
                                ),
                              )
                              : const Text(
                                'Continue with Google',
                                style: TextStyle(
                                  color: Colors.green,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  // Login Link
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text(
                        'Already have an account? ',
                        style: TextStyle(color: Colors.white70),
                      ),
                      TextButton(
                        onPressed: () {
                          Navigator.pushReplacement(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const LoginPage(),
                            ),
                          );
                        },
                        child: const Text(
                          'Sign In',
                          style: TextStyle(
                            color: Colors.yellow,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
