import 'dart:convert';
import 'dart:ui';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show Colors;
import 'package:http/http.dart' as http;
import 'login.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ProfilePage extends StatefulWidget {
  final String email;
  const ProfilePage({super.key, required this.email});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> with SingleTickerProviderStateMixin {
  bool _isLoading = false;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  // Define teal500 color
  final Color teal500 = const Color(0xFF009688);

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
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
    super.dispose();
  }

  void _signOut(BuildContext context) async {
    setState(() {
      _isLoading = true;
    });

    // Clear stored preferences
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('email');
    await prefs.remove('password');

    // Small delay to show loading state
    await Future.delayed(const Duration(milliseconds: 500));

    setState(() {
      _isLoading = false;
    });

    Navigator.of(context, rootNavigator: true).pushAndRemoveUntil(
      CupertinoPageRoute(builder: (_) => const LoginPage()),
          (route) => false,
    );
  }

  void _changePassword(BuildContext context) {
    final otpController = TextEditingController();
    final newPasswordController = TextEditingController();
    final confirmPasswordController = TextEditingController();
    String otpMessage = '';
    bool isOtpSent = false;
    bool isPasswordVisible = false;
    bool isConfirmPasswordVisible = false;
    bool isSubmitting = false;

    final parentContext = context;

    showCupertinoModalPopup(
      context: context,
      filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
      builder: (_) => StatefulBuilder(
        builder: (dialogContext, setState) {
          return Container(
            height: MediaQuery.of(context).size.height * 0.85,
            padding: const EdgeInsets.only(top: 20),
            decoration: BoxDecoration(
              color: CupertinoColors.black,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(
                            CupertinoIcons.lock_shield,
                            color: teal500,
                            size: 24,
                          ),
                          const SizedBox(width: 10),
                          const Text(
                            'Change Password',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: CupertinoColors.white,
                            ),
                          ),
                        ],
                      ),
                      GestureDetector(
                        onTap: () => Navigator.pop(dialogContext),
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: CupertinoColors.darkBackgroundGray,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            CupertinoIcons.xmark,
                            color: CupertinoColors.systemGrey,
                            size: 16,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildFormLabel('Email'),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                          decoration: BoxDecoration(
                            color: CupertinoColors.darkBackgroundGray,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: CupertinoColors.systemGrey4.withOpacity(0.3),
                              width: 1,
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                CupertinoIcons.mail,
                                color: teal500,
                                size: 20,
                              ),
                              const SizedBox(width: 12),
                              Text(
                                widget.email,
                                style: const TextStyle(
                                  color: CupertinoColors.white,
                                  fontSize: 16,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            _buildFormLabel('OTP Code'),
                            CupertinoButton(
                              padding: EdgeInsets.zero,
                              minSize: 0,
                              onPressed: isSubmitting
                                  ? null
                                  : () async {
                                setState(() {
                                  otpMessage = 'Sending OTP...';
                                });
                                try {
                                  final response = await http.post(
                                    Uri.parse('https://airbank-server.onrender.com/api/auth/send-otp'),
                                    headers: {'Content-Type': 'application/json'},
                                    body: jsonEncode({'email': widget.email}),
                                  );
                                  final jsonResponse = jsonDecode(response.body);
                                  if (response.statusCode == 200) {
                                    setState(() {
                                      otpMessage = 'OTP sent to your email.';
                                      isOtpSent = true;
                                    });
                                  } else {
                                    setState(() {
                                      otpMessage = jsonResponse['error'] ?? 'Failed to send OTP.';
                                    });
                                  }
                                } catch (e) {
                                  setState(() {
                                    otpMessage = 'Server error. Try again later.';
                                  });
                                }
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  color: teal500.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      isOtpSent ? CupertinoIcons.refresh : CupertinoIcons.envelope,
                                      color: teal500,
                                      size: 14,
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      isOtpSent ? 'Resend OTP' : 'Send OTP',
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: teal500,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Container(
                          decoration: BoxDecoration(
                            color: CupertinoColors.darkBackgroundGray,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: CupertinoColors.systemGrey4.withOpacity(0.3),
                              width: 1,
                            ),
                          ),
                          child: CupertinoTextField(
                            controller: otpController,
                            placeholder: 'Enter 6-digit code',
                            keyboardType: TextInputType.number,
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                            placeholderStyle: const TextStyle(
                              color: CupertinoColors.systemGrey,
                              fontSize: 16,
                            ),
                            style: const TextStyle(
                              color: CupertinoColors.white,
                              fontSize: 16,
                            ),
                            prefix: Padding(
                              padding: const EdgeInsets.only(left: 12),
                              child: Icon(
                                CupertinoIcons.number,
                                color: teal500,
                                size: 20,
                              ),
                            ),
                            decoration: const BoxDecoration(
                              color: Colors.transparent,
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        _buildFormLabel('New Password'),
                        const SizedBox(height: 8),
                        Container(
                          decoration: BoxDecoration(
                            color: CupertinoColors.darkBackgroundGray,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: CupertinoColors.systemGrey4.withOpacity(0.3),
                              width: 1,
                            ),
                          ),
                          child: CupertinoTextField(
                            controller: newPasswordController,
                            placeholder: 'Enter new password',
                            obscureText: !isPasswordVisible,
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                            placeholderStyle: const TextStyle(
                              color: CupertinoColors.systemGrey,
                              fontSize: 16,
                            ),
                            style: const TextStyle(
                              color: CupertinoColors.white,
                              fontSize: 16,
                            ),
                            prefix: Padding(
                              padding: const EdgeInsets.only(left: 12),
                              child: Icon(
                                CupertinoIcons.lock,
                                color: teal500,
                                size: 20,
                              ),
                            ),
                            suffix: GestureDetector(
                              onTap: () {
                                setState(() {
                                  isPasswordVisible = !isPasswordVisible;
                                });
                              },
                              child: Padding(
                                padding: const EdgeInsets.only(right: 12),
                                child: Icon(
                                  isPasswordVisible ? CupertinoIcons.eye_slash_fill : CupertinoIcons.eye_fill,
                                  color: CupertinoColors.systemGrey,
                                  size: 18,
                                ),
                              ),
                            ),
                            decoration: const BoxDecoration(
                              color: Colors.transparent,
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        _buildFormLabel('Confirm Password'),
                        const SizedBox(height: 8),
                        Container(
                          decoration: BoxDecoration(
                            color: CupertinoColors.darkBackgroundGray,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: CupertinoColors.systemGrey4.withOpacity(0.3),
                              width: 1,
                            ),
                          ),
                          child: CupertinoTextField(
                            controller: confirmPasswordController,
                            placeholder: 'Confirm new password',
                            obscureText: !isConfirmPasswordVisible,
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                            placeholderStyle: const TextStyle(
                              color: CupertinoColors.systemGrey,
                              fontSize: 16,
                            ),
                            style: const TextStyle(
                              color: CupertinoColors.white,
                              fontSize: 16,
                            ),
                            prefix: Padding(
                              padding: const EdgeInsets.only(left: 12),
                              child: Icon(
                                CupertinoIcons.lock_shield,
                                color: teal500,
                                size: 20,
                              ),
                            ),
                            suffix: GestureDetector(
                              onTap: () {
                                setState(() {
                                  isConfirmPasswordVisible = !isConfirmPasswordVisible;
                                });
                              },
                              child: Padding(
                                padding: const EdgeInsets.only(right: 12),
                                child: Icon(
                                  isConfirmPasswordVisible ? CupertinoIcons.eye_slash_fill : CupertinoIcons.eye_fill,
                                  color: CupertinoColors.systemGrey,
                                  size: 18,
                                ),
                              ),
                            ),
                            decoration: const BoxDecoration(
                              color: Colors.transparent,
                            ),
                          ),
                        ),
                        if (otpMessage.isNotEmpty) ...[
                          const SizedBox(height: 16),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            decoration: BoxDecoration(
                              color: otpMessage.toLowerCase().contains('success') || otpMessage.contains('sent')
                                  ? CupertinoColors.activeGreen.withOpacity(0.1)
                                  : CupertinoColors.systemRed.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: otpMessage.toLowerCase().contains('success') || otpMessage.contains('sent')
                                    ? CupertinoColors.activeGreen.withOpacity(0.3)
                                    : CupertinoColors.systemRed.withOpacity(0.3),
                                width: 1,
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  otpMessage.toLowerCase().contains('success') || otpMessage.contains('sent')
                                      ? CupertinoIcons.check_mark_circled
                                      : CupertinoIcons.exclamationmark_circle,
                                  color: otpMessage.toLowerCase().contains('success') || otpMessage.contains('sent')
                                      ? CupertinoColors.activeGreen
                                      : CupertinoColors.systemRed,
                                  size: 20,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    otpMessage,
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: otpMessage.toLowerCase().contains('success') || otpMessage.contains('sent')
                                          ? CupertinoColors.activeGreen
                                          : CupertinoColors.systemRed,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                        const SizedBox(height: 30),
                      ],
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: CupertinoColors.black,
                    boxShadow: [
                      BoxShadow(
                        color: CupertinoColors.black.withOpacity(0.5),
                        blurRadius: 10,
                        offset: const Offset(0, -5),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        flex: 2,
                        child: GestureDetector(
                          onTap: isSubmitting ? null : () => Navigator.pop(dialogContext),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            decoration: BoxDecoration(
                              color: CupertinoColors.darkBackgroundGray,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Center(
                              child: Text(
                                'Cancel',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: CupertinoColors.white,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 3,
                        child: GestureDetector(
                          onTap: isSubmitting
                              ? null
                              : () async {
                            final otp = otpController.text.trim();
                            final newPassword = newPasswordController.text;
                            final confirmPassword = confirmPasswordController.text;

                            if (otp.isEmpty) {
                              setState(() {
                                otpMessage = 'Please enter the OTP code.';
                              });
                              return;
                            }
                            if (newPassword.isEmpty) {
                              setState(() {
                                otpMessage = 'Please enter a new password.';
                              });
                              return;
                            }
                            if (newPassword != confirmPassword) {
                              setState(() {
                                otpMessage = 'Passwords do not match.';
                              });
                              return;
                            }
                            if (newPassword.length < 6) {
                              setState(() {
                                otpMessage = 'Password must be at least 6 characters.';
                              });
                              return;
                            }

                            setState(() {
                              otpMessage = 'Changing password...';
                              isSubmitting = true;
                            });

                            try {
                              final response = await http.post(
                                Uri.parse('https://airbank-server.onrender.com/api/auth/change-password'),
                                headers: {'Content-Type': 'application/json'},
                                body: jsonEncode({
                                  'email': widget.email,
                                  'otp': otp,
                                  'newPassword': newPassword,
                                }),
                              );
                              final jsonResponse = jsonDecode(response.body);
                              if (response.statusCode == 200) {
                                setState(() {
                                  otpMessage = 'Password changed successfully.';
                                });
                                final prefs = await SharedPreferences.getInstance();
                                await prefs.remove('email');
                                await prefs.remove('password');
                                Future.delayed(const Duration(seconds: 1), () {
                                  Navigator.pop(dialogContext);
                                  _signOut(parentContext);
                                });
                              } else {
                                setState(() {
                                  otpMessage = jsonResponse['error'] ?? 'Failed to change password.';
                                  isSubmitting = false;
                                });
                              }
                            } catch (e) {
                              setState(() {
                                otpMessage = 'Server error. Try again later.';
                                isSubmitting = false;
                              });
                            }
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            decoration: BoxDecoration(
                              color: teal500,
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: [
                                BoxShadow(
                                  color: teal500.withOpacity(0.3),
                                  blurRadius: 8,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Center(
                              child: isSubmitting
                                  ? const CupertinoActivityIndicator(
                                color: CupertinoColors.white,
                              )
                                  : const Text(
                                'Change Password',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: CupertinoColors.white,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  // New: shows modal with member names
  void _showMembersModal() {
    showCupertinoModalPopup(
      context: context,
      filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
      builder: (BuildContext context) {
        return CupertinoActionSheet(
          title: const Text(
            'Members',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          message: const Text('Here are the names of the 5 members:'),
          actions: [
            _buildMemberAction('Janzen Laurence Decano'),
            _buildMemberAction('Aero Kenn Dela Pena'),
            _buildMemberAction('Riane Gamboa'),
            _buildMemberAction('Maricar Mangulabnan'),
            _buildMemberAction('Jhoncarlo Mariano'),
          ],
          cancelButton: CupertinoActionSheetAction(
            isDefaultAction: true,
            child: const Text('Close'),
            onPressed: () => Navigator.pop(context),
          ),
        );
      },
    );
  }

  // Helper to build each member row
  CupertinoActionSheetAction _buildMemberAction(String name) {
    return CupertinoActionSheetAction(
      onPressed: () {}, // no-op
      child: Text(
        name,
        style: const TextStyle(color: CupertinoColors.white),
      ),
    );
  }

  void _showComingSoonDialog(String feature) {
    showCupertinoDialog(
      context: context,
      builder: (_) => CupertinoAlertDialog(
        title: const Text('Coming Soon'),
        content: Text('The $feature feature will be available in a future update.'),
        actions: [
          CupertinoDialogAction(
            child: const Text('OK'),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }

  Widget _buildFormLabel(String label) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 4),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: CupertinoColors.white,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final darkGrey = CupertinoColors.darkBackgroundGray;
    final name = widget.email.split('@').first;
    final capitalizedName = name.isNotEmpty
        ? '${name[0].toUpperCase()}${name.substring(1)}'
        : '';

    return CupertinoPageScaffold(
      backgroundColor: CupertinoColors.black,
      navigationBar: CupertinoNavigationBar(
        backgroundColor: CupertinoColors.black.withOpacity(0.8),
        border: Border.all(color: CupertinoColors.black),
        middle: const Text('Profile'),
        leading: CupertinoNavigationBarBackButton(
          color: teal500,
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      child: SafeArea(
        child: _isLoading
            ? Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CupertinoActivityIndicator(radius: 16),
              const SizedBox(height: 16),
              Text(
                'Signing out...',
                style: TextStyle(
                  color: CupertinoColors.systemGrey,
                  fontSize: 16,
                ),
              ),
            ],
          ),
        )
            : SingleChildScrollView(
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 20),

                  // Profile header
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: darkGrey,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 70,
                          height: 70,
                          decoration: BoxDecoration(
                            color: teal500.withOpacity(0.2),
                            shape: BoxShape.circle,
                            border: Border.all(color: teal500, width: 2),
                          ),
                          child: Center(
                            child: Text(
                              capitalizedName.isNotEmpty
                                  ? capitalizedName[0].toUpperCase()
                                  : 'U',
                              style: TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.bold,
                                color: teal500,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 20),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                capitalizedName,
                                style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: CupertinoColors.white,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                widget.email,
                                style: const TextStyle(
                                  fontSize: 14,
                                  color: CupertinoColors.systemGrey,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: teal500.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  'Standard Account',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: teal500,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        GestureDetector(
                          onTap: () => _showComingSoonDialog('profile editing'),
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: darkGrey.withOpacity(0.8),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              CupertinoIcons.pencil,
                              color: teal500,
                              size: 18,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Account settings section
                  const Text(
                    'Account Settings',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: CupertinoColors.white,
                    ),
                  ),
                  const SizedBox(height: 16),

                  _buildSettingsItem(
                    icon: CupertinoIcons.lock,
                    title: 'Change Password',
                    color: teal500,
                    onTap: () => _changePassword(context),
                  ),

                  _buildSettingsItem(
                    icon: CupertinoIcons.bell,
                    title: 'Notifications',
                    color: teal500,
                    onTap: () => _showComingSoonDialog('notifications'),
                  ),

                  _buildSettingsItem(
                    icon: CupertinoIcons.creditcard,
                    title: 'Payment Methods',
                    color: teal500,
                    onTap: () => _showComingSoonDialog('payment methods'),
                  ),

                  // ←–– New Info item
                  _buildSettingsItem(
                    icon: CupertinoIcons.info_circle,
                    title: 'Info',
                    color: teal500,
                    onTap: _showMembersModal,
                  ),

                  const SizedBox(height: 24),

                  // Preferences section
                  const Text(
                    'Preferences',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: CupertinoColors.white,
                    ),
                  ),
                  const SizedBox(height: 16),

                  _buildSettingsItem(
                    icon: CupertinoIcons.money_dollar_circle,
                    title: 'Currency',
                    color: teal500,
                    subtitle: 'PHP',
                    onTap: () => _showComingSoonDialog('currency selection'),
                  ),

                  const SizedBox(height: 24),

                  // Support section
                  const Text(
                    'Support',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: CupertinoColors.white,
                    ),
                  ),
                  const SizedBox(height: 16),

                  _buildSettingsItem(
                    icon: CupertinoIcons.chat_bubble_text,
                    title: 'Contact Support',
                    color: teal500,
                    onTap: () => _showComingSoonDialog('support chat'),
                  ),

                  _buildSettingsItem(
                    icon: CupertinoIcons.doc_text,
                    title: 'Terms & Conditions',
                    color: teal500,
                    onTap: () => _showComingSoonDialog('terms and conditions'),
                  ),

                  const SizedBox(height: 24),

                  // Sign out button
                  GestureDetector(
                    onTap: () => _signOut(context),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      decoration: BoxDecoration(
                        color: Colors.grey.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Colors.grey.withOpacity(0.3),
                          width: 1,
                        ),
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            CupertinoIcons.square_arrow_right,
                            color: Colors.teal,
                            size: 20,
                          ),
                          SizedBox(width: 8),
                          Text(
                            'Sign Out',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 30),

                  // App version
                  Center(
                    child: Text(
                      'AirBank v1.0.0',
                      style: TextStyle(
                        fontSize: 12,
                        color: CupertinoColors.systemGrey.withOpacity(0.7),
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSettingsItem({
    required IconData icon,
    required String title,
    required Color color,
    String? subtitle,
    bool hasToggle = false,
    bool toggleValue = false,
    Function(bool)? onToggleChanged,
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: hasToggle ? null : onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: CupertinoColors.darkBackgroundGray,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: color.withOpacity(0.2),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: CupertinoColors.white,
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 13,
                        color: CupertinoColors.systemGrey,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            hasToggle
                ? CupertinoSwitch(
              value: toggleValue,
              onChanged: onToggleChanged,
              activeTrackColor: color,
            )
                : Icon(
              CupertinoIcons.chevron_right,
              color: CupertinoColors.systemGrey,
              size: 18,
            ),
          ],
        ),
      ),
    );
  }
}
