import 'dart:io';
import 'dart:ui';
import 'dart:convert';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'dashboard.dart';
import 'signup.dart';

// Custom text widget
class AppText extends StatelessWidget {
  final String text;
  final double size;
  final FontWeight weight;
  final Color? color;

  const AppText(
      this.text, {
        super.key,
        this.size = 14,
        this.weight = FontWeight.normal,
        this.color,
      });

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(fontSize: size, fontWeight: weight, color: color ?? Colors.white),
    );
  }
}

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> with SingleTickerProviderStateMixin {
  bool rememberMe = false;
  bool _obscurePassword = true;
  bool _isLoading = false;

  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeOut,
      ),
    );
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _toggleRememberMe(bool value) {
    setState(() {
      rememberMe = value;
    });
  }

  void _togglePasswordVisibility() {
    setState(() {
      _obscurePassword = !_obscurePassword;
    });
  }

  bool _validateEmail(String email) {
    final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
    return emailRegex.hasMatch(email);
  }

  // Show an error dialog
  void _showError(String message) {
    showCupertinoDialog(
      context: context,
      builder: (_) => BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: CupertinoAlertDialog(
          title: const AppText('Error'),
          content: AppText(message),
          actions: [
            CupertinoDialogAction(
              child: const AppText('OK'),
              onPressed: () => Navigator.pop(context),
            ),
          ],
        ),
      ),
    );
  }

  // Normal sign in: call server, and if "Remember me" is checked, store the credentials + userId
  void _signIn() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    // Basic validations
    if (email.isEmpty) {
      _showError('Please enter your email');
      return;
    }
    if (!_validateEmail(email)) {
      _showError('Please enter a valid email');
      return;
    }
    if (password.isEmpty) {
      _showError('Please enter your password');
      return;
    }

    // Show loading spinner
    setState(() {
      _isLoading = true;
    });

    try {
      final url = Uri.parse('https://airbank-server.onrender.com/api/auth/signin'); // Update if needed
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': email,
          'password': password,
        }),
      );

      // Simulate original 2-second delay
      await Future.delayed(const Duration(seconds: 2));

      setState(() {
        _isLoading = false;
      });

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        // We expect data["user"]["id"], data["user"]["email"]
        final userId = data['user']['id'];
        final userEmail = data['user']['email'];

        // If "Remember me" is checked, store credentials + userId
        if (rememberMe) {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('storedEmail', userEmail);
          await prefs.setString('storedPassword', password);
          await prefs.setString('storedUserId', userId);
        }

        // Pass the userEmail + userId to the DashboardPage
        Navigator.pushReplacement(
          context,
          CupertinoPageRoute(
            builder: (context) => DashboardPage(email: userEmail, userId: userId),
          ),
        );
      } else {
        final errorData = jsonDecode(response.body);
        _showError(errorData['error'] ?? 'Login failed');
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      _showError('Something went wrong: $e');
    }
  }

  // Biometric sign in: retrieve stored credentials + userId and use them
  void _signInWithBiometrics() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      final storedEmail = prefs.getString('storedEmail');
      final storedPassword = prefs.getString('storedPassword');
      final storedUserId = prefs.getString('storedUserId');

      if (storedEmail == null ||
          storedPassword == null ||
          storedUserId == null) {
        setState(() {
          _isLoading = false;
        });
        _showError('No stored credentials. Please sign in and check remember me.');
        return;
      }

      // Simulate biometric delay
      await Future.delayed(const Duration(seconds: 1));
      setState(() {
        _isLoading = false;
      });

      // Navigate to DashboardPage with the stored email + userId
      Navigator.pushReplacement(
        context,
        CupertinoPageRoute(
          builder: (context) => DashboardPage(
            email: storedEmail,
            userId: storedUserId,
          ),
        ),
      );
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      _showError('Something went wrong: $e');
    }
  }

  void _forgotPasswordFlow() {
    final emailController = TextEditingController();
    final otpController = TextEditingController();
    final newPasswordController = TextEditingController();
    String message = '';

    showCupertinoDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (dialogContext, setState) {
          return CupertinoAlertDialog(
            title: const AppText('Forgot Password'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 8),
                // Email input field (manual entry)
                CupertinoTextField(
                  controller: emailController,
                  placeholder: 'Enter your email',
                  keyboardType: TextInputType.emailAddress,
                ),
                const SizedBox(height: 8),
                // OTP input field
                CupertinoTextField(
                  controller: otpController,
                  placeholder: 'OTP Code',
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 8),
                // New password input field
                CupertinoTextField(
                  controller: newPasswordController,
                  placeholder: 'New Password',
                  obscureText: true,
                ),
                if (message.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    message,
                    style: TextStyle(
                      color: message.toLowerCase().contains('success')
                          ? CupertinoColors.activeGreen
                          : CupertinoColors.systemRed,
                    ),
                  ),
                ],
              ],
            ),
            actions: [
              // Send OTP button
              CupertinoDialogAction(
                child: const AppText('Send OTP'),
                onPressed: () async {
                  final email = emailController.text.trim();
                  if (email.isEmpty) {
                    setState(() {
                      message = 'Please enter your email.';
                    });
                    return;
                  }
                  // Optionally, validate the email format if desired.
                  try {
                    final response = await http.post(
                      Uri.parse('https://airbank-server.onrender.com/api/auth/send-otp'),
                      headers: {'Content-Type': 'application/json'},
                      body: jsonEncode({'email': email}),
                    );
                    final jsonResponse = jsonDecode(response.body);
                    if (response.statusCode == 200) {
                      setState(() {
                        message = 'OTP sent to your email.';
                      });
                    } else {
                      setState(() {
                        message = jsonResponse['error'] ?? 'Failed to send OTP.';
                      });
                    }
                  } catch (e) {
                    setState(() {
                      message = 'Server error. Try again later.';
                    });
                  }
                },
              ),
              // Submit button to update the password using OTP
              CupertinoDialogAction(
                child: const AppText('Submit'),
                onPressed: () async {
                  final email = emailController.text.trim();
                  final otp = otpController.text.trim();
                  final newPassword = newPasswordController.text;

                  if (email.isEmpty || otp.isEmpty || newPassword.isEmpty) {
                    setState(() {
                      message = 'Please fill all fields.';
                    });
                    return;
                  }

                  try {
                    final response = await http.post(
                      Uri.parse('https://airbank-server.onrender.com/api/auth/change-password'),
                      headers: {'Content-Type': 'application/json'},
                      body: jsonEncode({
                        'email': email,
                        'otp': otp,
                        'newPassword': newPassword,
                      }),
                    );
                    final jsonResponse = jsonDecode(response.body);
                    if (response.statusCode == 200) {
                      setState(() {
                        message = 'Password changed successfully.';
                      });
                      // Clear stored credentials (if any)
                      final prefs = await SharedPreferences.getInstance();
                      await prefs.remove('storedEmail');
                      await prefs.remove('storedPassword');
                      await prefs.remove('storedUserId');
                      // Delay briefly so the user can read the success message, then close the dialog.
                      Future.delayed(const Duration(seconds: 1), () {
                        Navigator.pop(dialogContext);
                      });
                    } else {
                      setState(() {
                        message = jsonResponse['error'] ?? 'Failed to change password.';
                      });
                    }
                  } catch (e) {
                    setState(() {
                      message = 'Server error. Try again later.';
                    });
                  }
                },
              ),
              CupertinoDialogAction(
                isDestructiveAction: true,
                onPressed: () => Navigator.pop(dialogContext),
                child: const AppText('Cancel'),
              ),
            ],
          );
        },
      ),
    );
  }


  void _showDialog(String title, String message) {
    showCupertinoDialog(
      context: context,
      builder: (_) => CupertinoAlertDialog(
        title: AppText(title),
        content: AppText(message),
        actions: [
          CupertinoDialogAction(
            child: const AppText('OK'),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tealColor = Colors.teal.shade400;
    final darkGrey = Colors.grey.shade900;
    final screenSize = MediaQuery.of(context).size;

    return CupertinoPageScaffold(
      backgroundColor: Colors.black,
      navigationBar: CupertinoNavigationBar(
        backgroundColor: Colors.black.withOpacity(0.8),
        border: Border.all(color: Colors.transparent),
        leading: null,
        middle: null,
        trailing: GestureDetector(
          onTap: () {
            showCupertinoDialog(
              context: context,
              builder: (_) => BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                child: CupertinoAlertDialog(
                  title: const AppText('Feature Coming Soon'),
                  content: const AppText('This feature is under development.'),
                  actions: [
                    CupertinoDialogAction(
                      child: const AppText('OK'),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
            );
          },
          child: Icon(
            CupertinoIcons.settings,
            color: tealColor,
            size: 24,
          ),
        ),
      ),
      child: SafeArea(
        child: Stack(
          children: [
            // Background gradient effect
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    colors: [
                      Colors.black,
                      Colors.black,
                      tealColor.withOpacity(0.05),
                      Colors.black,
                    ],
                    center: Alignment.topCenter,
                    radius: 1.2,
                  ),
                ),
              ),
            ),

            // Subtle pattern overlay
            Positioned.fill(
              child: Opacity(
                opacity: 0.03,
                child: Container(
                  decoration: const BoxDecoration(
                    image: DecorationImage(
                      image: AssetImage('assets/images/pattern.png'),
                      repeat: ImageRepeat.repeat,
                    ),
                  ),
                ),
              ),
            ),

            // Main content
            SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0),
                child: FadeTransition(
                  opacity: _fadeAnimation,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SizedBox(height: screenSize.height * 0.08),

                      // Logo with enhanced glow effect
                      TweenAnimationBuilder(
                        tween: Tween<double>(begin: 0.0, end: 1.0),
                        duration: const Duration(seconds: 1),
                        curve: Curves.easeOut,
                        builder: (context, value, child) {
                          return Transform.scale(
                            scale: 0.8 + (0.2 * value),
                            child: Container(
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: tealColor.withOpacity(0.2 * value),
                                    blurRadius: 30 * value,
                                    spreadRadius: 5 * value,
                                  ),
                                ],
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(28),
                                child: Image.asset(
                                  'assets/icon/icon.png',
                                  width: 130,
                                  height: 130,
                                  fit: BoxFit.cover,
                                ),
                              ),
                            ),
                          );
                        },
                      ),

                      const SizedBox(height: 20),

                      // App name with shimmer effect
                      ShimmerText(
                        text: 'AirBank',
                        baseColor: tealColor,
                        highlightColor: Colors.white,
                        fontSize: 44,
                        fontWeight: FontWeight.w700,
                      ),

                      const SizedBox(height: 12),

                      // Subtitle with staggered animation
                      TweenAnimationBuilder(
                        tween: Tween<double>(begin: 0.0, end: 1.0),
                        duration: const Duration(milliseconds: 800),
                        curve: Curves.easeOut,
                        builder: (context, value, child) {
                          return Opacity(
                            opacity: value,
                            child: Transform.translate(
                              offset: Offset(0, 20 * (1 - value)),
                              child: AppText(
                                'Secure Banking, Simplified',
                                weight: FontWeight.w400,
                                size: 16,
                                color: Colors.grey.shade400,
                              ),
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 8),
                      // Subtitle with staggered animation
                      TweenAnimationBuilder(
                        tween: Tween<double>(begin: 0.0, end: 1.0),
                        duration: const Duration(milliseconds: 800),
                        curve: Curves.easeOut,
                        builder: (context, value, child) {
                          return Opacity(
                            opacity: value,
                            child: Transform.translate(
                              offset: Offset(0, 20 * (1 - value)),
                              child: AppText(
                                'ver 1.0.0',
                                weight: FontWeight.w400,
                                size: 12,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          );
                        },
                      ),
                      SizedBox(height: screenSize.height * 0.06),

                      // Form fields with staggered animations
                      TweenAnimationBuilder(
                        tween: Tween<double>(begin: 0.0, end: 1.0),
                        duration: const Duration(milliseconds: 800),
                        curve: Curves.easeOut,
                        builder: (context, value, child) {
                          return Opacity(
                            opacity: value,
                            child: Transform.translate(
                              offset: Offset(30 * (1 - value), 0),
                              child: child,
                            ),
                          );
                        },
                        child: GlassContainer(
                          borderRadius: 20,
                          blur: 10,
                          opacity: 0.1,
                          border: 1,
                          borderColor: tealColor.withOpacity(0.3),
                          child: Padding(
                            padding: const EdgeInsets.all(20.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                AppText(
                                  'Login',
                                  weight: FontWeight.w600,
                                  size: 20,
                                  color: Colors.white,
                                ),
                                const SizedBox(height: 20),

                                // Email field
                                InputField(
                                  controller: _emailController,
                                  placeholder: 'Email',
                                  icon: CupertinoIcons.mail,
                                  keyboardType: TextInputType.emailAddress,
                                  tealColor: tealColor,
                                  darkGrey: darkGrey,
                                ),

                                const SizedBox(height: 16),

                                // Password field
                                InputField(
                                  controller: _passwordController,
                                  placeholder: 'Password',
                                  icon: CupertinoIcons.lock,
                                  isPassword: true,
                                  obscureText: _obscurePassword,
                                  togglePasswordVisibility: _togglePasswordVisibility,
                                  tealColor: tealColor,
                                  darkGrey: darkGrey,
                                ),

                                const SizedBox(height: 16),

                                // Remember me and forgot password row
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    // Remember me
                                    GestureDetector(
                                      onTap: () => _toggleRememberMe(!rememberMe),
                                      child: Row(
                                        children: [
                                          AnimatedContainer(
                                            duration: const Duration(milliseconds: 200),
                                            width: 20,
                                            height: 20,
                                            decoration: BoxDecoration(
                                              color: rememberMe ? tealColor : Colors.transparent,
                                              borderRadius: BorderRadius.circular(4),
                                              border: Border.all(
                                                color: rememberMe ? tealColor : Colors.grey.shade600,
                                                width: 1.5,
                                              ),
                                            ),
                                            child: rememberMe
                                                ? const Icon(
                                              CupertinoIcons.checkmark,
                                              size: 14,
                                              color: Colors.white,
                                            )
                                                : null,
                                          ),
                                          const SizedBox(width: 8),
                                          AppText(
                                            'Remember me',
                                            size: 14,
                                            color: Colors.grey.shade300,
                                          ),
                                        ],
                                      ),
                                    ),

                                    // Forgot password
                                    CupertinoButton(
                                      padding: EdgeInsets.zero,
                                      onPressed: _forgotPasswordFlow,
                                      child: AppText(
                                        'Forgot Password?',
                                        size: 14,
                                        color: tealColor,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 30),

                      // Sign in button with animation
                      TweenAnimationBuilder(
                        tween: Tween<double>(begin: 0.0, end: 1.0),
                        duration: const Duration(milliseconds: 800),
                        curve: Curves.easeOut,
                        builder: (context, value, child) {
                          return Opacity(
                            opacity: value,
                            child: Transform.translate(
                              offset: Offset(0, 30 * (1 - value)),
                              child: child,
                            ),
                          );
                        },
                        child: GestureDetector(
                          onTap: _isLoading ? null : _signIn,
                          child: Container(
                            width: double.infinity,
                            height: 56,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  tealColor.withOpacity(0.8),
                                  tealColor,
                                  tealColor.withOpacity(0.8),
                                ],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [
                                BoxShadow(
                                  color: tealColor.withOpacity(0.3),
                                  blurRadius: 15,
                                  offset: const Offset(0, 8),
                                ),
                              ],
                            ),
                            child: _isLoading
                                ? const Center(
                              child: CupertinoActivityIndicator(
                                color: Colors.white,
                              ),
                            )
                                : Center(
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const AppText(
                                    'Sign In',
                                    weight: FontWeight.w600,
                                    size: 16,
                                    color: Colors.white,
                                  ),
                                  const SizedBox(width: 8),
                                  Icon(
                                    CupertinoIcons.arrow_right,
                                    color: Colors.white,
                                    size: 18,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 20),

                      // Biometrics button
                      if (Platform.isAndroid || Platform.isIOS)
                        TweenAnimationBuilder(
                          tween: Tween<double>(begin: 0.0, end: 1.0),
                          duration: const Duration(milliseconds: 800),
                          curve: Curves.easeOut,
                          builder: (context, value, child) {
                            return Opacity(
                              opacity: value,
                              child: Transform.translate(
                                offset: Offset(0, 30 * (1 - value)),
                                child: child,
                              ),
                            );
                          },
                          child: GestureDetector(
                            onTap: _isLoading ? null : _signInWithBiometrics,
                            child: Container(
                              width: double.infinity,
                              height: 56,
                              decoration: BoxDecoration(
                                color: Colors.transparent,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: tealColor.withOpacity(0.7),
                                  width: 1.5,
                                ),
                              ),
                              child: _isLoading
                                  ? Center(
                                child: CupertinoActivityIndicator(
                                  color: tealColor,
                                ),
                              )
                                  : Center(
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      CupertinoIcons.person_crop_circle,
                                      color: tealColor,
                                      size: 20,
                                    ),
                                    const SizedBox(width: 8),
                                    const AppText(
                                      'Sign In with Biometrics',
                                      weight: FontWeight.w500,
                                      size: 16,
                                      color: Colors.white,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),

                      const SizedBox(height: 40),

                      // Sign up option with animation
                      TweenAnimationBuilder(
                        tween: Tween<double>(begin: 0.0, end: 1.0),
                        duration: const Duration(milliseconds: 800),
                        curve: Curves.easeOut,
                        builder: (context, value, child) {
                          return Opacity(
                            opacity: value,
                            child: child,
                          );
                        },
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            AppText(
                              'Don\'t have an account? ',
                              size: 14,
                              color: Colors.grey.shade400,
                            ),
                            CupertinoButton(
                              padding: EdgeInsets.zero,
                              child: AppText(
                                'Sign Up',
                                weight: FontWeight.w600,
                                size: 14,
                                color: tealColor,
                              ),
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  CupertinoPageRoute(builder: (context) => const SignupPage()),
                                );
                              },
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}


class GlassContainer extends StatelessWidget {
  final Widget child;
  final double borderRadius;
  final double blur;
  final double opacity;
  final double border;
  final Color borderColor;

  const GlassContainer({
    super.key,
    required this.child,
    this.borderRadius = 20,
    this.blur = 10,
    this.opacity = 0.2,
    this.border = 1.5,
    this.borderColor = Colors.white30,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(borderRadius),
            border: Border.all(
              width: border,
              color: borderColor,
            ),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.white.withOpacity(opacity),
                Colors.white.withOpacity(opacity / 3),
              ],
            ),
          ),
          child: child,
        ),
      ),
    );
  }
}

// ------------------
// InputField
// ------------------
class InputField extends StatelessWidget {
  final TextEditingController controller;
  final String placeholder;
  final IconData icon;
  final TextInputType keyboardType;
  final bool isPassword;
  final bool obscureText;
  final Function? togglePasswordVisibility;
  final Color tealColor;
  final Color darkGrey;

  const InputField({
    super.key,
    required this.controller,
    required this.placeholder,
    required this.icon,
    this.keyboardType = TextInputType.text,
    this.isPassword = false,
    this.obscureText = false,
    this.togglePasswordVisibility,
    required this.tealColor,
    required this.darkGrey,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: darkGrey.withOpacity(0.6),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: CupertinoTextField(
        controller: controller,
        placeholder: placeholder,
        placeholderStyle: TextStyle(color: Colors.grey.shade600),
        keyboardType: keyboardType,
        obscureText: isPassword ? obscureText : false,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        style: const TextStyle(color: CupertinoColors.white),
        prefix: Padding(
          padding: const EdgeInsets.only(left: 16.0),
          child: Icon(
            icon,
            color: tealColor,
            size: 20,
          ),
        ),
        decoration: BoxDecoration(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        suffix: isPassword
            ? Padding(
          padding: const EdgeInsets.only(right: 16.0),
          child: GestureDetector(
            onTap: () => togglePasswordVisibility?.call(),
            child: Icon(
              obscureText
                  ? CupertinoIcons.eye_fill
                  : CupertinoIcons.eye_slash_fill,
              color: tealColor,
              size: 20,
            ),
          ),
        )
            : null,
      ),
    );
  }
}

class ShimmerText extends StatefulWidget {
  final String text;
  final Color baseColor;
  final Color highlightColor;
  final double fontSize;
  final FontWeight fontWeight;

  const ShimmerText({
    super.key,
    required this.text,
    required this.baseColor,
    required this.highlightColor,
    required this.fontSize,
    required this.fontWeight,
  });

  @override
  State<ShimmerText> createState() => _ShimmerTextState();
}

class _ShimmerTextState extends State<ShimmerText> with SingleTickerProviderStateMixin {
  late AnimationController _shimmerController;

  @override
  void initState() {
    super.initState();
    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat();
  }

  @override
  void dispose() {
    _shimmerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _shimmerController,
      builder: (context, child) {
        return ShaderMask(
          blendMode: BlendMode.srcIn,
          shaderCallback: (bounds) {
            return LinearGradient(
              colors: [
                widget.baseColor,
                widget.highlightColor,
                widget.baseColor,
              ],
              stops: const [0.0, 0.5, 1.0],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              transform: _SlidingGradientTransform(
                slidePercent: _shimmerController.value,
              ),
            ).createShader(bounds);
          },
          child: Text(
            widget.text,
            style: TextStyle(
              fontSize: widget.fontSize,
              fontWeight: widget.fontWeight,
            ),
          ),
        );
      },
    );
  }
}

class _SlidingGradientTransform extends GradientTransform {
  const _SlidingGradientTransform({
    required this.slidePercent,
  });

  final double slidePercent;

  @override
  Matrix4? transform(Rect bounds, {TextDirection? textDirection}) {
    return Matrix4.translationValues(bounds.width * slidePercent, 0.0, 0.0);
  }
}