import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'login_page.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

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
  bool _acceptedTerms = false;

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

    if (!_acceptedTerms) {
      _showErrorDialog('Please accept the Terms and Conditions to continue.');
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
              'Account created successfully! Your account is now pending admin approval. You will receive an email notification once your account is approved. Please use the login page to check your account status.',
              style: TextStyle(fontSize: 16),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  Navigator.pushAndRemoveUntil(
                    context,
                    MaterialPageRoute(builder: (context) => const LoginPage()),
                    (route) => false,
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

  void _showTermsAndConditions() {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: Row(
              children: [
                Icon(Icons.description, color: Colors.green, size: 24),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Terms and Conditions',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'MangoSense Terms of Service',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Last Updated: November 16, 2025\n',
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                  _buildTermsSection(
                    '1. Acceptance of Terms',
                    'By registering for and using MangoSense, you agree to be bound by these Terms and Conditions. If you do not agree to these terms, please do not use this application.',
                  ),
                  _buildTermsSection(
                    '2. Service Description',
                    'MangoSense is an agricultural technology application designed to assist farmers in detecting and identifying mango plant diseases using artificial intelligence and machine learning technology. The application provides diagnostic suggestions based on image analysis.',
                  ),
                  _buildTermsSection(
                    '3. User Account and Registration',
                    '• You must provide accurate and complete information during registration.\n'
                        '• You are responsible for maintaining the confidentiality of your account credentials.\n'
                        '• Your account is subject to admin approval before activation.',
                  ),
                  _buildTermsSection(
                    '4. Use of Service',
                    '• The application is intended for agricultural and educational purposes only.\n'
                        '• Disease detection results are advisory and should not replace professional agricultural consultation.\n'
                        '• You agree to use the service in compliance with all applicable laws and regulations.\n'
                        '• You will not misuse, abuse, or attempt to manipulate the service.',
                  ),
                  _buildTermsSection(
                    '5. Data Privacy and Collection',
                    '• We collect personal information including name, address, phone number, and email for account management.\n'
                        '• Images uploaded for disease detection may be stored and analyzed.\n'
                        '• Your data will be handled in accordance with applicable data privacy laws.\n'
                        '• We will not share your personal information with third parties without consent, except as required by law.',
                  ),
                  _buildTermsSection(
                    '6. Disclaimer of Warranties',
                    '• MangoSense is provided "as is" without warranties of any kind.\n'
                        '• We do not guarantee 100% accuracy in disease detection.\n'
                        '• Results should be verified by qualified agricultural professionals.\n'
                        '• We are not liable for crop losses or damages resulting from reliance on app recommendations.',
                  ),
                  _buildTermsSection(
                    '7. Limitation of Liability',
                    'MangoSense, its developers, and administrators shall not be liable for any indirect, incidental, special, or consequential damages arising from the use or inability to use this service.',
                  ),
                  _buildTermsSection(
                    '8. Intellectual Property',
                    'All content, features, and functionality of MangoSense are owned by the application developers and are protected by copyright and intellectual property laws.',
                  ),
                  _buildTermsSection(
                    '9. Account Termination',
                    'We reserve the right to suspend or terminate accounts that violate these terms or engage in fraudulent, abusive, or illegal activities.',
                  ),
                  _buildTermsSection(
                    '10. Changes to Terms',
                    'We reserve the right to modify these Terms and Conditions at any time. Continued use of the service after changes constitutes acceptance of modified terms.',
                  ),
                  _buildTermsSection(
                    '11. Contact Information',
                    'For questions, concerns, or support regarding these terms or the MangoSense service, please contact us through the application support channels.',
                  ),
                  SizedBox(height: 12),
                  Container(
                    padding: EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.green.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.green.withOpacity(0.3)),
                    ),
                    child: Text(
                      'By clicking "I Accept," you acknowledge that you have read, understood, and agree to be bound by these Terms and Conditions.',
                      style: TextStyle(
                        fontSize: 13,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text('Close', style: TextStyle(color: Colors.grey[600])),
              ),
              ElevatedButton(
                onPressed: () {
                  setState(() {
                    _acceptedTerms = true;
                  });
                  Navigator.of(context).pop();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: Text('I Accept', style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
    );
  }

  Widget _buildTermsSection(String title, String content) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
          ),
          SizedBox(height: 4),
          Text(content, style: TextStyle(fontSize: 13, height: 1.4)),
        ],
      ),
    );
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
            padding: const EdgeInsets.symmetric(
              horizontal: 20.0,
              vertical: 16.0,
            ),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 16),
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
                          padding: const EdgeInsets.all(6),
                          child: Image.asset(
                            'assets/applogo_header.png',
                            width: 56,
                            height: 56,
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
                  const SizedBox(height: 20),
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
                  const SizedBox(height: 20),
                  // Form Fields
                  _buildTextField(
                    label: 'Full Name',
                    controller: _fullNameController,
                    prefixIcon: Icons.person,
                    validator: _validateFullName,
                    keyboardType: TextInputType.name,
                  ),
                  const SizedBox(height: 12),
                  _buildTextField(
                    label: 'Address',
                    controller: _addressController,
                    prefixIcon: Icons.home,
                    validator: _validateAddress,
                    keyboardType: TextInputType.streetAddress,
                  ),
                  const SizedBox(height: 12),
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
                  const SizedBox(height: 12),
                  _buildTextField(
                    label: 'Email',
                    controller: _emailController,
                    prefixIcon: Icons.email,
                    validator: _validateEmail,
                    keyboardType: TextInputType.emailAddress,
                  ),
                  const SizedBox(height: 12),
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
                  const SizedBox(height: 12),
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
                  const SizedBox(height: 12),
                  // Terms and Conditions Checkbox
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Checkbox(
                        value: _acceptedTerms,
                        onChanged: (value) {
                          setState(() {
                            _acceptedTerms = value ?? false;
                          });
                        },
                        activeColor: Colors.white,
                        checkColor: Colors.green,
                        side: BorderSide(color: Colors.white70, width: 2),
                      ),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.only(top: 12.0),
                          child: GestureDetector(
                            onTap: _showTermsAndConditions,
                            child: RichText(
                              text: TextSpan(
                                style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: 14,
                                ),
                                children: [
                                  TextSpan(text: 'I agree to the '),
                                  TextSpan(
                                    text: 'Terms and Conditions',
                                    style: TextStyle(
                                      color: Colors.yellow,
                                      fontWeight: FontWeight.bold,
                                      decoration: TextDecoration.underline,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  // Register Button
                  SizedBox(
                    width: double.infinity,
                    height: 52,
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
                          Navigator.pushAndRemoveUntil(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const LoginPage(),
                            ),
                            (route) => false,
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
