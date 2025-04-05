import 'dart:convert';
import 'dart:ui'; // For ImageFilter
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dashboard.dart'; // Ensure this page exists in your project

class SignupPage extends StatefulWidget {
  const SignupPage({Key? key}) : super(key: key);

  @override
  State<SignupPage> createState() => _SignupPageState();
}

class _SignupPageState extends State<SignupPage> {
  // Controllers for user details
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _numberController = TextEditingController();

  bool _isLoading = false;
  final String baseUrl = "https://airbank-server.onrender.com";

  bool _validateEmail(String email) {
    final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
    return emailRegex.hasMatch(email);
  }

  void _showError(String message) {
    showCupertinoDialog(
      context: context,
      builder: (_) => CupertinoAlertDialog(
        title: const Text("Error"),
        content: Text(message),
        actions: [
          CupertinoDialogAction(
            child: const Text("OK"),
            onPressed: () => Navigator.pop(context),
          )
        ],
      ),
    );
  }

  Future<void> _signUp() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    final number = _numberController.text.trim();

    // Basic validations
    if (email.isEmpty || password.isEmpty || number.isEmpty) {
      _showError("Please fill all required fields.");
      return;
    }
    if (!_validateEmail(email)) {
      _showError("Please enter a valid email.");
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // Create User (pass favorites as an empty array)
      final userResponse = await http.post(
        Uri.parse("$baseUrl/api/users"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "email": email,
          "password": password,
          "number": number,
          "favorites": [],
        }),
      );

      if (userResponse.statusCode != 201) {
        final errorData = jsonDecode(userResponse.body);
        _showError(errorData['error'] ?? "Failed to create user.");
        setState(() {
          _isLoading = false;
        });
        return;
      }

      final userData = jsonDecode(userResponse.body);
      final String userId = userData['id'];

      // User account created successfully, navigate to Dashboard
      setState(() {
        _isLoading = false;
      });
      Navigator.pushReplacement(
        context,
        CupertinoPageRoute(
          builder: (context) => DashboardPage(email: email, userId: userId),
        ),
      );
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      _showError("Something went wrong: $e");
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _numberController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tealColor = Colors.teal.shade400;
    final darkGrey = Colors.grey.shade900;
    final screenSize = MediaQuery.of(context).size;

    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        middle: const Text("Sign Up"),
        backgroundColor: Colors.black.withOpacity(0.8),
      ),
      backgroundColor: Colors.black,
      child: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
          child: Column(
            children: [
              SizedBox(height: screenSize.height * 0.05),
              // Form Container with a glass effect
              GlassContainer(
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
                        'Create Account',
                        weight: FontWeight.w600,
                        size: 22,
                        color: Colors.white,
                      ),
                      const SizedBox(height: 16),
                      // User Information Section
                      AppText(
                        'User Information',
                        weight: FontWeight.w500,
                        size: 16,
                        color: tealColor,
                      ),
                      const SizedBox(height: 12),
                      InputField(
                        controller: _emailController,
                        placeholder: 'Email',
                        icon: CupertinoIcons.mail,
                        keyboardType: TextInputType.emailAddress,
                        tealColor: tealColor,
                        darkGrey: darkGrey,
                      ),
                      const SizedBox(height: 12),
                      InputField(
                        controller: _passwordController,
                        placeholder: 'Password',
                        icon: CupertinoIcons.lock,
                        isPassword: true,
                        obscureText: true,
                        tealColor: tealColor,
                        darkGrey: darkGrey,
                      ),
                      const SizedBox(height: 12),
                      InputField(
                        controller: _numberController,
                        placeholder: 'Phone Number',
                        icon: CupertinoIcons.phone,
                        keyboardType: TextInputType.phone,
                        tealColor: tealColor,
                        darkGrey: darkGrey,
                      ),
                      const SizedBox(height: 20),
                      // Sign Up Button
                      GestureDetector(
                        onTap: _isLoading ? null : _signUp,
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
                          child: Center(
                            child: _isLoading
                                ? const CupertinoActivityIndicator(color: Colors.white)
                                : AppText(
                              'Sign Up',
                              weight: FontWeight.w600,
                              size: 18,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
              // Option to go back to Login if the user already has an account
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  AppText(
                    "Already have an account? ",
                    size: 14,
                    color: Colors.grey.shade400,
                  ),
                  CupertinoButton(
                    padding: EdgeInsets.zero,
                    onPressed: () {
                      Navigator.pop(context);
                    },
                    child: AppText(
                      'Sign In',
                      weight: FontWeight.w600,
                      size: 14,
                      color: tealColor,
                    ),
                  )
                ],
              )
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------
// Reusable Widgets (AppText, GlassContainer, InputField)
// ---------------------------------------------------------------------

class AppText extends StatelessWidget {
  final String text;
  final double size;
  final FontWeight weight;
  final Color? color;
  const AppText(
      this.text, {
        Key? key,
        this.size = 14,
        this.weight = FontWeight.normal,
        this.color,
      }) : super(key: key);
  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(fontSize: size, fontWeight: weight, color: color ?? Colors.white),
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
    Key? key,
    required this.child,
    this.borderRadius = 20,
    this.blur = 10,
    this.opacity = 0.2,
    this.border = 1.5,
    this.borderColor = Colors.white30,
  }) : super(key: key);
  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(borderRadius),
            border: Border.all(width: border, color: borderColor),
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
    Key? key,
    required this.controller,
    required this.placeholder,
    required this.icon,
    this.keyboardType = TextInputType.text,
    this.isPassword = false,
    this.obscureText = false,
    this.togglePasswordVisibility,
    required this.tealColor,
    required this.darkGrey,
  }) : super(key: key);
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
          )
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
              obscureText ? CupertinoIcons.eye_fill : CupertinoIcons.eye_slash_fill,
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