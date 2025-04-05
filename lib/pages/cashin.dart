import 'dart:convert';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show Colors;
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';

class CashInPage extends StatefulWidget {
  final String userId;
  final String email;
  final List<dynamic> accounts;

  const CashInPage({
    super.key,
    required this.userId,
    required this.email,
    required this.accounts,
  });

  @override
  State<CashInPage> createState() => _CashInPageState();
}

class _CashInPageState extends State<CashInPage> with SingleTickerProviderStateMixin {
  dynamic _selectedAccount;
  final TextEditingController _amountController = TextEditingController();
  bool _isLoading = false;
  String? _error;
  String? _success;
  final currencyFormatter = NumberFormat.currency(symbol: '₱');
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  bool _isProcessing = false;

  // Define teal500 color
  final Color teal500 = const Color(0xFF009688);

  @override
  void initState() {
    super.initState();
    // Automatically select the first account if available.
    if (widget.accounts.isNotEmpty) {
      _selectedAccount = widget.accounts[0];
    }

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
    _amountController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _cashIn() async {
    if (_selectedAccount == null || _amountController.text.isEmpty) {
      setState(() {
        _error = 'Please select an account and enter amount.';
        _success = null;
      });
      return;
    }

    final amount = double.tryParse(_amountController.text);
    if (amount == null || amount <= 0) {
      setState(() {
        _error = 'Please enter a valid amount.';
        _success = null;
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _isProcessing = true;
      _error = null;
      _success = null;
    });

    try {
      // 1) Create a "CASHIN" transaction. Send amount as string with 2 decimals.
      final transactionUrl = Uri.parse('https://airbank-server.onrender.com/api/transactions');
      final txRes = await http.post(
        transactionUrl,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'sender': 'CASH',
          'receiver':  _selectedAccount['accountNumber'],
          'amount': amount.toStringAsFixed(2),
          'transactionType': 'CASHIN',
        }),
      );

      if (txRes.statusCode == 201) {
        // 2) Update the selected account's balance.
        final double currentBalance = double.tryParse(_selectedAccount['balance'].toString()) ?? 0;
        final double newBalance = currentBalance + amount;
        final accountUrl = Uri.parse(
          'https://airbank-server.onrender.com/api/accounts/${_selectedAccount['id']}',
        );

        final accountRes = await http.put(
          accountUrl,
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'accountNumber': _selectedAccount['accountNumber'].toString(),
            'balance': newBalance.toStringAsFixed(2),
            'expiration': _selectedAccount['expiration']?.toString() ?? '',
            'ccv': _selectedAccount['ccv']?.toString() ?? '',
          }),
        );

        if (accountRes.statusCode == 200) {
          // Update the local account balance so the UI displays 2 decimals.
          setState(() {
            _selectedAccount['balance'] = newBalance.toStringAsFixed(2);
            _success = 'Cash In successful.\nNew Balance: ${currencyFormatter.format(newBalance)}';
            _amountController.clear();
          });
        } else {
          setState(() {
            _error = 'Cash In was successful, but failed to update account balance.';
          });
        }
      } else {
        final err = jsonDecode(txRes.body);
        setState(() {
          _error = 'Failed to create transaction: ${err['error'] ?? 'Error'}';
        });
      }
    } catch (e) {
      setState(() {
        _error = 'Server error: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;

        // Add a small delay before hiding the processing indicator
        Future.delayed(const Duration(milliseconds: 500), () {
          if (mounted) {
            setState(() {
              _isProcessing = false;
            });
          }
        });
      });
    }
  }

  String _formatCardNumber(String number) {
    if (number.length < 4) return number;
    return '••••${number.substring(number.length - 4)}';
  }

  @override
  Widget build(BuildContext context) {
    final darkGrey = CupertinoColors.darkBackgroundGray;

    return CupertinoPageScaffold(
      backgroundColor: CupertinoColors.black,
      navigationBar: CupertinoNavigationBar(
        backgroundColor: CupertinoColors.black.withOpacity(0.8),
        border: Border.all(color: CupertinoColors.black),
        leading: CupertinoNavigationBarBackButton(
          color: teal500,
          onPressed: () => Navigator.of(context).pop(),
        ),
        middle: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              CupertinoIcons.arrow_down_circle_fill,
              color: teal500,
              size: 20,
            ),
            const SizedBox(width: 8),
            const Text('Cash In'),
          ],
        ),
      ),
      child: SafeArea(
        child: _isLoading
            ? Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CupertinoActivityIndicator(
                radius: 16,
              ),
              const SizedBox(height: 16),
              Text(
                'Processing your deposit...',
                style: TextStyle(
                  color: CupertinoColors.systemGrey,
                  fontSize: 16,
                ),
              ),
            ],
          ),
        )
            : FadeTransition(
          opacity: _fadeAnimation,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Text(
                  'Deposit Money',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: CupertinoColors.white,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Add funds to your selected account',
                  style: TextStyle(
                    fontSize: 16,
                    color: CupertinoColors.systemGrey,
                  ),
                ),

                const SizedBox(height: 30),

                // Account selector section
                Text(
                  'Select Account',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: CupertinoColors.white,
                  ),
                ),

                const SizedBox(height: 16),

                // Account cards
                if (widget.accounts.isEmpty)
                  _buildEmptyState(
                    icon: CupertinoIcons.creditcard,
                    title: 'No Accounts Found',
                    message: 'You don\'t have any bank accounts to deposit to.',
                  )
                else
                  SizedBox(
                    height: 160,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: widget.accounts.length,
                      itemBuilder: (context, index) {
                        final acc = widget.accounts[index];
                        final isActive = _selectedAccount != null && acc['id'] == _selectedAccount['id'];
                        final balance = double.tryParse(acc['balance'].toString()) ?? 0.0;
                        final formattedBalance = currencyFormatter.format(balance);
                        final accountNumber = acc['accountNumber']?.toString() ?? '';

                        return GestureDetector(
                          onTap: () {
                            setState(() {
                              _selectedAccount = acc;
                            });
                          },
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 300),
                            margin: const EdgeInsets.only(right: 16, bottom: 8),
                            width: MediaQuery.of(context).size.width * 0.75,
                            decoration: BoxDecoration(
                              color: isActive ? teal500 : darkGrey,
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [
                                BoxShadow(
                                  color: CupertinoColors.black.withOpacity(0.3),
                                  blurRadius: 10,
                                  offset: const Offset(0, 5),
                                ),
                              ],
                              border: Border.all(
                                color: isActive
                                    ? teal500
                                    : CupertinoColors.systemGrey4,
                                width: 1,
                              ),
                            ),
                            child: Stack(
                              children: [
                                // Card background pattern
                                Positioned(
                                  right: -20,
                                  bottom: -20,
                                  child: Opacity(
                                    opacity: 0.1,
                                    child: Icon(
                                      CupertinoIcons.creditcard_fill,
                                      size: 120,
                                      color: CupertinoColors.white,
                                    ),
                                  ),
                                ),

                                // Card content
                                Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      // Bank logo and chip
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Row(
                                            children: [
                                              Icon(
                                                CupertinoIcons.money_dollar_circle_fill,
                                                color: isActive ? CupertinoColors.white : teal500,
                                                size: 20,
                                              ),
                                              const SizedBox(width: 8),
                                              Text(
                                                'AirBank',
                                                style: TextStyle(
                                                  color: isActive ? CupertinoColors.white : CupertinoColors.white,
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 14,
                                                ),
                                              ),
                                            ],
                                          ),
                                          Icon(
                                            CupertinoIcons.wifi,
                                            color: isActive ? CupertinoColors.white : CupertinoColors.white,
                                            size: 16,
                                          ),
                                        ],
                                      ),

                                      // Balance
                                      Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'Current Balance',
                                            style: TextStyle(
                                              color: isActive ? CupertinoColors.white.withOpacity(0.7) : CupertinoColors.systemGrey,
                                              fontSize: 12,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            formattedBalance,
                                            style: const TextStyle(
                                              color: CupertinoColors.white,
                                              fontWeight: FontWeight.bold,
                                              fontSize: 20,
                                            ),
                                          ),
                                        ],
                                      ),

                                      // Card details
                                      Text(
                                        _formatCardNumber(accountNumber),
                                        style: const TextStyle(
                                          color: CupertinoColors.white,
                                          fontSize: 14,
                                          letterSpacing: 2,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),

                                // Selection indicator
                                if (isActive)
                                  Positioned(
                                    top: 8,
                                    right: 8,
                                    child: Container(
                                      padding: const EdgeInsets.all(4),
                                      decoration: BoxDecoration(
                                        color: CupertinoColors.white,
                                        shape: BoxShape.circle,
                                      ),
                                      child: Icon(
                                        CupertinoIcons.checkmark_alt,
                                        color: teal500,
                                        size: 12,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),

                const SizedBox(height: 30),

                // Amount input section
                Text(
                  'Enter Amount',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: CupertinoColors.white,
                  ),
                ),

                const SizedBox(height: 16),

                Container(
                  decoration: BoxDecoration(
                    color: darkGrey,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: CupertinoColors.systemGrey4.withOpacity(0.3),
                      width: 1,
                    ),
                  ),
                  child: CupertinoTextField(
                    controller: _amountController,
                    placeholder: 'Amount to deposit',
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
                    ],
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
                        CupertinoIcons.money_rubl,
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

                // Quick amount buttons
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildQuickAmountButton('500'),
                      const SizedBox(width: 8),
                      _buildQuickAmountButton('1000'),
                      const SizedBox(width: 8),
                      _buildQuickAmountButton('2000'),
                      const SizedBox(width: 8),
                      _buildQuickAmountButton('5000'),
                      const SizedBox(width: 8),
                      _buildQuickAmountButton('10000'),
                    ],
                  ),
                ),

                const SizedBox(height: 40),

                // Information text
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: darkGrey,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        CupertinoIcons.info_circle,
                        color: teal500,
                        size: 20,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Funds will be immediately available in your account after deposit.',
                          style: TextStyle(
                            fontSize: 14,
                            color: CupertinoColors.systemGrey,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),
                // Confirm button
                GestureDetector(
                  onTap: _isProcessing ? null : _cashIn,
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 16),
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
                      child: _isProcessing
                          ? const CupertinoActivityIndicator(
                        color: CupertinoColors.white,
                      )
                          : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            CupertinoIcons.arrow_down_circle,
                            color: CupertinoColors.white,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          const Text(
                            'Deposit Funds',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: CupertinoColors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 20),

                // Error message
                if (_error != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: CupertinoColors.systemRed.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: CupertinoColors.systemRed.withOpacity(0.3),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          CupertinoIcons.exclamationmark_circle,
                          color: CupertinoColors.systemRed,
                          size: 20,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            _error!,
                            style: TextStyle(
                              fontSize: 14,
                              color: CupertinoColors.systemRed,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                // Success message
                if (_success != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: Colors.teal.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Colors.teal.withOpacity(0.3),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          CupertinoIcons.check_mark_circled,
                          color: Colors.teal,
                          size: 20,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            _success!,
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.teal,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),



              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildQuickAmountButton(String amount) {
    return GestureDetector(
      onTap: () {
        setState(() {
          _amountController.text = amount;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: teal500.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: teal500.withOpacity(0.3),
            width: 1,
          ),
        ),
        child: Text(
          '₱$amount',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: teal500,
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState({
    required IconData icon,
    required String title,
    required String message,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 30, horizontal: 20),
      decoration: BoxDecoration(
        color: CupertinoColors.darkBackgroundGray,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Icon(
            icon,
            size: 48,
            color: teal500.withOpacity(0.7),
          ),
          const SizedBox(height: 16),
          Text(
            title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: CupertinoColors.white,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 14,
              color: CupertinoColors.systemGrey,
            ),
          ),
        ],
      ),
    );
  }
}