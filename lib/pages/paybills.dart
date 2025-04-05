import 'dart:convert';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show Colors, Card, ListTile;
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';

class PayBillsPage extends StatefulWidget {
  final String userId;
  final String email;
  final List<dynamic> accounts;

  const PayBillsPage({
    super.key,
    required this.userId,
    required this.email,
    required this.accounts,
  });

  @override
  State<PayBillsPage> createState() => _PayBillsPageState();
}

class _PayBillsPageState extends State<PayBillsPage> with SingleTickerProviderStateMixin {
  List<dynamic> _bills = [];
  dynamic _selectedBill;
  dynamic _selectedAccount;
  final TextEditingController _amountController = TextEditingController();
  bool _isLoading = true;
  bool _isProcessing = false;
  String? _error;
  String? _success;

  // Animation controller
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  // Currency formatter
  final currencyFormatter = NumberFormat.currency(symbol: '₱');

  // Maintain a list of favorite bill IDs.
  List<String> _favoriteBills = [];

  // Define teal500 color
  final Color teal500 = const Color(0xFF009688);

  @override
  void initState() {
    super.initState();

    // Initialize animation controller
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

    // Set default selected account
    final userAccounts = widget.accounts.where((acc) => acc['userId'] == widget.userId).toList();
    if (userAccounts.isNotEmpty) {
      _selectedAccount = userAccounts[0];
    }

    _fetchBills();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _fetchBills() async {
    try {
      final billsUrl = Uri.parse('https://airbank-server.onrender.com/api/bills');
      final userUrl = Uri.parse('https://airbank-server.onrender.com/api/users/${widget.userId}');

      final responses = await Future.wait([
        http.get(billsUrl),
        http.get(userUrl),
      ]);

      final billsResponse = responses[0];
      final userResponse = responses[1];

      if (billsResponse.statusCode == 200 && userResponse.statusCode == 200) {
        final List<dynamic> allBills = json.decode(billsResponse.body);
        final dynamic userData = json.decode(userResponse.body);

        setState(() {
          _bills = allBills;
          // Ensure we parse favorites correctly (assume it's stored under 'favorites' key)
          _favoriteBills = List<String>.from(userData['favorites'] ?? []);
        });
      } else {
        setState(() {
          _error = 'Error fetching bills or user data.';
        });
      }
    } catch (e) {
      setState(() {
        _error = 'Error fetching data: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
      _animationController.forward();
    }
  }

  Future<void> _toggleBillFavorite(dynamic bill) async {
    final billId = bill['id'].toString();

    setState(() {
      _isProcessing = true;
      _error = null;
      _success = null;
    });

    try {
      if (_favoriteBills.contains(billId)) {
        _favoriteBills.remove(billId);
      } else {
        _favoriteBills.add(billId);
      }

      // Update user favorites on server.
      final url = Uri.parse('https://airbank-server.onrender.com/api/users/${widget.userId}');
      final response = await http.put(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'favorites': _favoriteBills,
        }),
      );

      if (response.statusCode != 200) {
        setState(() {
          _error = 'Failed to update favorites.';
        });
      } else {
        setState(() {
          _success = _favoriteBills.contains(billId)
              ? '${bill['name']} added to favorites.'
              : '${bill['name']} removed from favorites.';
        });

        // Clear success message after 3 seconds
        Future.delayed(const Duration(seconds: 3), () {
          if (mounted) {
            setState(() {
              _success = null;
            });
          }
        });
      }
    } catch (e) {
      setState(() {
        _error = 'Server error when updating favorites: $e';
      });
    } finally {
      setState(() {
        _isProcessing = false;
      });
    }
  }

  Future<void> _payBill() async {
    if (_selectedBill == null || _selectedAccount == null || _amountController.text.isEmpty) {
      setState(() {
        _error = 'Please select a bill, an account, and enter amount.';
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

    final accountBalance = double.tryParse(_selectedAccount['balance'].toString()) ?? 0;
    if (accountBalance < amount) {
      setState(() {
        _error = 'Insufficient balance.';
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
      // 1) Create transaction "PAYBILL" (amount as string with 2 decimals)
      final txUrl = Uri.parse('https://airbank-server.onrender.com/api/transactions');
      final txRes = await http.post(
        txUrl,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'sender': _selectedAccount['accountNumber'],
          'receiver': _selectedBill['name'],
          'amount': amount.toStringAsFixed(2),
          'transactionType': 'PAYBILL',
        }),
      );

      if (txRes.statusCode == 201) {
        // 2) Update account balance
        final newBalance = accountBalance - amount;
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
          // Update local account balance
          setState(() {
            _selectedAccount['balance'] = newBalance.toStringAsFixed(2);
            final index = widget.accounts.indexWhere((acc) => acc['id'] == _selectedAccount['id']);
            if (index != -1) {
              widget.accounts[index]['balance'] = newBalance.toStringAsFixed(2);
            }
            _success = 'Payment of ${currencyFormatter.format(amount)} to ${_selectedBill['name']} was successful.';
            _amountController.clear();
            _selectedBill = null; // Reset selected bill
          });
        } else {
          setState(() {
            _error = 'Bill paid, but failed to update account balance.';
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

    // User's own accounts for paying.
    final userAccounts = widget.accounts.where((acc) => acc['userId'] == widget.userId).toList();

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
              CupertinoIcons.money_rubl_circle_fill,
              color: teal500,
              size: 20,
            ),
            const SizedBox(width: 8),
            const Text('Pay Bills'),
          ],
        ),
      ),
      child: SafeArea(
        child: _isLoading && !_isProcessing
            ? Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CupertinoActivityIndicator(
                radius: 16,
              ),
              const SizedBox(height: 16),
              Text(
                'Loading bills...',
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
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Text(
                  'Pay Your Bills',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: CupertinoColors.white,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Manage and pay your bills easily',
                  style: TextStyle(
                    fontSize: 16,
                    color: CupertinoColors.systemGrey,
                  ),
                ),

                const SizedBox(height: 30),

                // Source account section
                Text(
                  'From Account',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: CupertinoColors.white,
                  ),
                ),

                const SizedBox(height: 16),

                // Source account cards
                if (userAccounts.isEmpty)
                  _buildEmptyState(
                    icon: CupertinoIcons.creditcard,
                    title: 'No Accounts Found',
                    message: 'You don\'t have any bank accounts to pay from.',
                  )
                else
                  SizedBox(
                    height: 160,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: userAccounts.length,
                      itemBuilder: (context, index) {
                        final acc = userAccounts[index];
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
                                                CupertinoIcons.money_rubl_circle_fill,
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
                                            'Available Balance',
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

                // Bills section
                Text(
                  'Select a Bill',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: CupertinoColors.white,
                  ),
                ),

                const SizedBox(height: 16),

                // Bills grid
                if (_bills.isEmpty)
                  _buildEmptyState(
                    icon: CupertinoIcons.doc_text,
                    title: 'No Bills Found',
                    message: 'You don\'t have any bills to pay at the moment.',
                  )
                else
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      childAspectRatio: 0.85,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                    ),
                    itemCount: _bills.length,
                    itemBuilder: (context, index) {
                      final bill = _bills[index];
                      final isSelected = _selectedBill != null && bill['id'] == _selectedBill['id'];
                      final isFavorite = _favoriteBills.contains(bill['id'].toString());

                      return GestureDetector(
                        onTap: () {
                          setState(() {
                            _selectedBill = bill;
                          });
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          decoration: BoxDecoration(
                            color: isSelected ? teal500.withOpacity(0.2) : darkGrey,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: isSelected ? teal500 : CupertinoColors.systemGrey4.withOpacity(0.3),
                              width: 1,
                            ),
                          ),
                          child: Stack(
                            children: [
                              // Selection indicator
                              if (isSelected)
                                Positioned(
                                  top: 8,
                                  right: 8,
                                  child: Container(
                                    padding: const EdgeInsets.all(4),
                                    decoration: BoxDecoration(
                                      color: teal500,
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(
                                      CupertinoIcons.checkmark_alt,
                                      color: CupertinoColors.white,
                                      size: 10,
                                    ),
                                  ),
                                ),

                              // Favorite button
                              Positioned(
                                top: 8,
                                left: 8,
                                child: GestureDetector(
                                  onTap: () => _toggleBillFavorite(bill),
                                  child: Container(
                                    padding: const EdgeInsets.all(6),
                                    decoration: BoxDecoration(
                                      color: darkGrey.withOpacity(0.7),
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(
                                      isFavorite ? CupertinoIcons.star_fill : CupertinoIcons.star,
                                      color: Colors.teal.shade500,
                                      size: 14,
                                    ),
                                  ),
                                ),
                              ),

                              // Bill content
                              Padding(
                                padding: const EdgeInsets.all(16),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    // Bill logo
                                    Container(
                                      width: 60,
                                      height: 60,
                                      decoration: BoxDecoration(
                                        color: teal500.withOpacity(0.1),
                                        shape: BoxShape.circle,
                                      ),
                                      child: bill['imgUrl'] != null
                                          ? ClipRRect(
                                        borderRadius: BorderRadius.circular(30),
                                        child: Image.network(
                                          bill['imgUrl'],
                                          width: 60,
                                          height: 60,
                                          fit: BoxFit.cover,
                                          errorBuilder: (context, error, stackTrace) {
                                            return Icon(
                                              CupertinoIcons.doc_text_fill,
                                              color: teal500,
                                              size: 30,
                                            );
                                          },
                                        ),
                                      )
                                          : Icon(
                                        CupertinoIcons.doc_text_fill,
                                        color: teal500,
                                        size: 30,
                                      ),
                                    ),
                                    const SizedBox(height: 16),

                                    // Bill name
                                    Text(
                                      bill['name'],
                                      style: TextStyle(
                                        color: isSelected ? teal500 : CupertinoColors.white,
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                      ),
                                      textAlign: TextAlign.center,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),

                                    const SizedBox(height: 8),

                                    // Bill type or description
                                    Text(
                                      bill['type'] ?? 'Utility',
                                      style: TextStyle(
                                        color: CupertinoColors.systemGrey,
                                        fontSize: 12,
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
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
                    placeholder: 'Amount to pay',
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
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildQuickAmountButton('500'),
                    _buildQuickAmountButton('1000'),
                    _buildQuickAmountButton('2000'),
                    _buildQuickAmountButton('10000'),
                  ],
                ),

                const SizedBox(height: 30),

                // Information text
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: darkGrey,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        CupertinoIcons.info_circle,
                        color: teal500,
                        size: 20,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Payment Information',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: CupertinoColors.white,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              '• Select a bill from the grid above\n• Favorite bills for quick access\n• Payments are typically processed within 24 hours',
                              style: TextStyle(
                                fontSize: 13,
                                color: CupertinoColors.systemGrey,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                // Pay button
                GestureDetector(
                  onTap: _isProcessing ? null : _payBill,
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
                            CupertinoIcons.arrow_right_circle,
                            color: CupertinoColors.white,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          const Text(
                            'Pay Bill',
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
                      color: CupertinoColors.activeGreen.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: CupertinoColors.activeGreen.withOpacity(0.3),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          CupertinoIcons.check_mark_circled,
                          color: CupertinoColors.activeGreen,
                          size: 20,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            _success!,
                            style: TextStyle(
                              fontSize: 14,
                              color: CupertinoColors.activeGreen,
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