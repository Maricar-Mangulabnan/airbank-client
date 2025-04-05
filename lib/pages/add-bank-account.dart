import 'dart:convert';
import 'dart:math'; // For random generation
import 'dart:ui'; // For ImageFilter
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class AddBankAccountPage extends StatefulWidget {
  final String userId;
  const AddBankAccountPage({Key? key, required this.userId}) : super(key: key);

  @override
  State<AddBankAccountPage> createState() => _AddBankAccountPageState();
}

class _AddBankAccountPageState extends State<AddBankAccountPage> {
  // Only fields needed from the user
  final _balanceController = TextEditingController();
  final _expirationController = TextEditingController();

  bool _isLoading = false;
  final String baseUrl = "https://airbank-server.onrender.com";

  // Generates a random 9-character alphanumeric string for accountNumber.
  String _generateAccountNumber() {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    Random rnd = Random();
    return String.fromCharCodes(
      Iterable.generate(9, (_) => chars.codeUnitAt(rnd.nextInt(chars.length))),
    );
  }

  // Generates a random 3-digit number as a string for CCV.
  String _generateCCV() {
    Random rnd = Random();
    int number = rnd.nextInt(900) + 100; // ensures a 3-digit number
    return number.toString();
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

  Future<void> _createBankAccount() async {
    final balanceText = _balanceController.text.trim();
    final expiration = _expirationController.text.trim();

    // Validate inputs.
    if (balanceText.isEmpty || expiration.isEmpty) {
      _showError("Please fill all required fields.");
      return;
    }
    double? balance = double.tryParse(balanceText);
    if (balance == null) {
      _showError("Please enter a valid balance.");
      return;
    }

    // Auto-generate accountNumber and CCV.
    final accountNumber = _generateAccountNumber();
    final ccv = _generateCCV();

    setState(() {
      _isLoading = true;
    });

    try {
      final response = await http.post(
        Uri.parse("$baseUrl/api/accounts"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "userId": widget.userId,
          "accountNumber": accountNumber,
          "balance": balance.toString(),
          "expiration": expiration,
          "ccv": ccv,
        }),
      );

      if (response.statusCode != 201) {
        final errorData = jsonDecode(response.body);
        _showError(errorData['error'] ?? "Failed to create bank account.");
        setState(() {
          _isLoading = false;
        });
        return;
      }

      final accountData = jsonDecode(response.body);
      setState(() {
        _isLoading = false;
      });
      // Display bank account details in a formatted dialog.
      showCupertinoDialog(
        context: context,
        builder: (_) => CupertinoAlertDialog(
          title: const Text("Bank Account Created"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 8),
              Text("Account Number: ${accountData['accountNumber']}"),
              Text("Balance: ${accountData['balance']}"),
              Text("Expiration: ${accountData['expiration']}"),
              Text("CCV: ${accountData['ccv']}"),
            ],
          ),
          actions: [
            CupertinoDialogAction(
              child: const Text("OK"),
              onPressed: () {
                Navigator.pop(context); // Close dialog
                Navigator.pop(context); // Return to previous screen
              },
            )
          ],
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
    _balanceController.dispose();
    _expirationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tealColor = Colors.teal.shade400;
    final darkGrey = Colors.grey.shade900;
    final screenSize = MediaQuery.of(context).size;

    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        middle: const Text("Add Bank Account"),
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
                        'Create Bank Account',
                        weight: FontWeight.w600,
                        size: 22,
                        color: Colors.white,
                      ),
                      const SizedBox(height: 16),
                      // Balance input field.
                      AppText(
                        'Initial Balance',
                        weight: FontWeight.w500,
                        size: 16,
                        color: tealColor,
                      ),
                      const SizedBox(height: 8),
                      InputField(
                        controller: _balanceController,
                        placeholder: 'Enter initial balance',
                        icon: CupertinoIcons.money_dollar,
                        keyboardType: TextInputType.number,
                        tealColor: tealColor,
                        darkGrey: darkGrey,
                      ),
                      const SizedBox(height: 16),
                      // Expiration input field.
                      AppText(
                        'Expiration Date (MM/YY)',
                        weight: FontWeight.w500,
                        size: 16,
                        color: tealColor,
                      ),
                      const SizedBox(height: 8),
                      InputField(
                        controller: _expirationController,
                        placeholder: 'Enter expiration date',
                        icon: CupertinoIcons.calendar,
                        keyboardType: TextInputType.datetime,
                        tealColor: tealColor,
                        darkGrey: darkGrey,
                      ),
                      const SizedBox(height: 20),
                      GestureDetector(
                        onTap: _isLoading ? null : _createBankAccount,
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
                              'Create Bank Account',
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