import 'dart:convert';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show Colors;
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';

class TransferPage extends StatefulWidget {
  final String userId;
  final String email;
  final List<dynamic> accounts; // User's own accounts

  const TransferPage({
    super.key,
    required this.userId,
    required this.email,
    required this.accounts,
  });

  @override
  State<TransferPage> createState() => _TransferPageState();
}

class _TransferPageState extends State<TransferPage> with SingleTickerProviderStateMixin {
  // Local copy of user's source accounts.
  List<dynamic> _userAccounts = [];
  dynamic _sourceAccount;
  // Controller for target account input.
  final TextEditingController _targetAccountController = TextEditingController();
  // Controller for transfer amount.
  final TextEditingController _amountController = TextEditingController();
  bool _isLoading = false;
  bool _isProcessing = false;
  String? _error;
  String? _success;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  final currencyFormatter = NumberFormat.currency(symbol: '₱');

  // List to hold target favorites (each is a bank account object).
  List<dynamic> _targetFavorites = [];
  bool _isFetchingFavorites = true;

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

    // Filter accounts owned by the user.
    _userAccounts = widget.accounts.where((acc) => acc['userId'] == widget.userId).toList();
    if (_userAccounts.isNotEmpty) {
      _sourceAccount = _userAccounts[0];
    }

    // Fetch target favorites from the server.
    _fetchTargetFavorites();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _targetAccountController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  // Fetch user's target favorites from server.
  Future<void> _fetchTargetFavorites() async {
    setState(() {
      _isFetchingFavorites = true;
    });

    try {
      final userUrl = Uri.parse('https://airbank-server.onrender.com/api/users/${widget.userId}');
      final res = await http.get(userUrl);
      if (res.statusCode == 200) {
        final userData = jsonDecode(res.body);
        // Assume favorites is a JSON array of bank account IDs.
        final List favoriteIds = userData['favorites'] ?? [];
        List<dynamic> favorites = [];
        for (var favId in favoriteIds) {
          // Fetch each favorite's details using its id.
          final accUrl = Uri.parse('https://airbank-server.onrender.com/api/accounts/$favId');
          final accRes = await http.get(accUrl);
          if (accRes.statusCode == 200) {
            favorites.add(jsonDecode(accRes.body));
          }
        }
        setState(() {
          _targetFavorites = favorites;
        });
      }
    } catch (e) {
      // Silently handle error
    } finally {
      setState(() {
        _isFetchingFavorites = false;
      });
      _animationController.forward();
    }
  }

  // Adds the target account (from the text field) to favorites.
  Future<void> _addFavoriteTarget() async {
    final accountNum = _targetAccountController.text.trim();
    if (accountNum.isEmpty) {
      setState(() {
        _error = 'Please enter an account number to add as favorite.';
        _success = null;
      });
      return;
    }

    setState(() {
      _isProcessing = true;
      _error = null;
      _success = null;
    });

    try {
      // Look up the account by account number.
      final targetUrl = Uri.parse(
          'https://airbank-server.onrender.com/api/accounts/account-number/$accountNum'
      );
      final targetRes = await http.get(targetUrl);
      if (targetRes.statusCode != 200) {
        setState(() {
          _error = 'Cannot add favorite: target account not found.';
          _isProcessing = false;
        });
        return;
      }
      final targetAccount = jsonDecode(targetRes.body);
      // Check if already in favorites.
      bool alreadyExists = _targetFavorites.any((acc) => acc['id'] == targetAccount['id']);
      if (!alreadyExists) {
        setState(() {
          _targetFavorites.add(targetAccount);
        });
        // Update favorites on the server.
        List<String> favIds = _targetFavorites.map((acc) => acc['id'].toString()).toList();
        final userUrl = Uri.parse('https://airbank-server.onrender.com/api/users/${widget.userId}');
        final res = await http.put(
          userUrl,
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'favorites': favIds}),
        );
        if (res.statusCode != 200) {
          setState(() {
            _error = 'Failed to update favorites on server.';
          });
        } else {
          setState(() {
            _success = 'Account added to favorites successfully.';
          });
        }
      } else {
        setState(() {
          _error = 'This account is already in your favorites.';
        });
      }
    } catch (e) {
      setState(() {
        _error = 'Server error: $e';
      });
    } finally {
      setState(() {
        _isProcessing = false;
      });
    }
  }

  Future<void> _transfer() async {
    if (_sourceAccount == null ||
        _targetAccountController.text.isEmpty ||
        _amountController.text.isEmpty) {
      setState(() {
        _error = 'Please select a source account, enter a target account number, and an amount.';
        _success = null;
      });
      return;
    }

    // Prevent transferring to the same account.
    if (_sourceAccount['accountNumber'].toString() == _targetAccountController.text.trim()) {
      setState(() {
        _error = 'Cannot transfer to the same account.';
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

    final sourceBalance = double.tryParse(_sourceAccount['balance'].toString()) ?? 0;
    if (sourceBalance < amount) {
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
      // Look up target account by account number via the new endpoint.
      final accountNum = _targetAccountController.text.trim();
      final targetUrl = Uri.parse(
          'https://airbank-server.onrender.com/api/accounts/account-number/$accountNum'
      );
      final targetRes = await http.get(targetUrl);

      if (targetRes.statusCode != 200) {
        setState(() {
          _error = 'Target account not found. Please check the account number.';
          _isLoading = false;
          _isProcessing = false;
        });
        return;
      }

      final targetAccount = jsonDecode(targetRes.body);
      if (targetAccount == null) {
        setState(() {
          _error = 'Target account not found.';
          _isLoading = false;
          _isProcessing = false;
        });
        return;
      }

      // Create a "TRANSFER" transaction.
      final txUrl = Uri.parse('https://airbank-server.onrender.com/api/transactions');
      final txRes = await http.post(
        txUrl,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'sender': _sourceAccount['accountNumber'],
          'receiver': targetAccount['accountNumber'],

          'amount': amount.toStringAsFixed(2),
          'transactionType': 'TRANSFER',
        }),
      );

      if (txRes.statusCode == 201) {
        // Update source account balance.
        final sourceNewBalance = sourceBalance - amount;
        final sourceUrl = Uri.parse(
          'https://airbank-server.onrender.com/api/accounts/${_sourceAccount['id']}',
        );
        final sourceRes = await http.put(
          sourceUrl,
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'accountNumber': _sourceAccount['accountNumber'].toString(),
            'balance': sourceNewBalance.toStringAsFixed(2),
            'expiration': _sourceAccount['expiration']?.toString() ?? '',
            'ccv': _sourceAccount['ccv']?.toString() ?? '',
          }),
        );

        // Update target account balance.
        final targetBalance = double.tryParse(targetAccount['balance'].toString()) ?? 0;
        final targetNewBalance = targetBalance + amount;
        final targetUpdateUrl = Uri.parse(
          'https://airbank-server.onrender.com/api/accounts/${targetAccount['id']}',
        );
        final targetUpdateRes = await http.put(
          targetUpdateUrl,
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'accountNumber': targetAccount['accountNumber'].toString(),
            'balance': targetNewBalance.toStringAsFixed(2),
            'expiration': targetAccount['expiration']?.toString() ?? '',
            'ccv': targetAccount['ccv']?.toString() ?? '',
          }),
        );

        if (sourceRes.statusCode == 200 && targetUpdateRes.statusCode == 200) {
          // Update local source account balance.
          setState(() {
            _sourceAccount['balance'] = sourceNewBalance.toStringAsFixed(2);
            final index = _userAccounts.indexWhere((acc) => acc['id'] == _sourceAccount['id']);
            if (index != -1) {
              _userAccounts[index]['balance'] = sourceNewBalance.toStringAsFixed(2);
            }
            _success = 'Transfer successful. ${currencyFormatter.format(amount)} sent to account ${targetAccount['accountNumber']}.';
            _amountController.clear();
          });
        } else {
          setState(() {
            _error = 'Partial success. Please verify account balances.';
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
              CupertinoIcons.arrow_right_arrow_left_circle_fill,
              color: teal500,
              size: 20,
            ),
            const SizedBox(width: 8),
            const Text('Transfer'),
          ],
        ),
      ),
      child: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            // Add extra padding at the bottom based on the keyboard's viewInsets.
            final bottomPadding = 20.0 + MediaQuery.of(context).viewInsets.bottom;
            return SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(20, 20, 20, bottomPadding),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: IntrinsicHeight(
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
                          'Processing your transfer...',
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
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Header
                        Text(
                          'Transfer Money',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: CupertinoColors.white,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Send money to another account',
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
                        if (_userAccounts.isEmpty)
                          _buildEmptyState(
                            icon: CupertinoIcons.creditcard,
                            title: 'No Accounts Found',
                            message: 'You don\'t have any bank accounts to transfer from.',
                          )
                        else
                          SizedBox(
                            height: 160,
                            child: ListView.builder(
                              scrollDirection: Axis.horizontal,
                              itemCount: _userAccounts.length,
                              itemBuilder: (context, index) {
                                final acc = _userAccounts[index];
                                final isActive = _sourceAccount != null && acc['id'] == _sourceAccount['id'];
                                final balance = double.tryParse(acc['balance'].toString()) ?? 0.0;
                                final formattedBalance = currencyFormatter.format(balance);
                                final accountNumber = acc['accountNumber']?.toString() ?? '';
                                return GestureDetector(
                                  onTap: () {
                                    setState(() {
                                      _sourceAccount = acc;
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
                                        color: isActive ? teal500 : CupertinoColors.systemGrey4,
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
                        // Target account section
                        Text(
                          'To Account',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: CupertinoColors.white,
                          ),
                        ),
                        const SizedBox(height: 16),
                        // Target account input
                        Container(
                          decoration: BoxDecoration(
                            color: darkGrey,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: CupertinoColors.systemGrey4.withOpacity(0.3),
                              width: 1,
                            ),
                          ),
                          child: Column(
                            children: [
                              CupertinoTextField(
                                controller: _targetAccountController,
                                placeholder: 'Enter recipient account number',
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
                                    CupertinoIcons.person_crop_circle,
                                    color: teal500,
                                    size: 20,
                                  ),
                                ),
                                decoration: const BoxDecoration(
                                  color: Colors.transparent,
                                ),
                              ),
                              Container(
                                width: double.infinity,
                                decoration: BoxDecoration(
                                  border: Border(
                                    top: BorderSide(
                                      color: CupertinoColors.systemGrey4.withOpacity(0.3),
                                      width: 1,
                                    ),
                                  ),
                                ),
                                child: CupertinoButton(
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                  onPressed: _isProcessing ? null : _addFavoriteTarget,
                                  child: _isProcessing && _success == null && _error == null
                                      ? const CupertinoActivityIndicator(
                                    radius: 10,
                                  )
                                      : Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        CupertinoIcons.star,
                                        color: Colors.teal,
                                        size: 18,
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        'Add to Favorites',
                                        style: TextStyle(
                                          fontSize: 14,
                                          color: teal500,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        // Favorites section
                        if (_targetFavorites.isNotEmpty || _isFetchingFavorites) ...[
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Favorite Recipients',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: CupertinoColors.white,
                                ),
                              ),
                              if (!_isFetchingFavorites)
                                Text(
                                  'Tap to select',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: teal500,
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          if (_isFetchingFavorites)
                            const Center(
                              child: Padding(
                                padding: EdgeInsets.symmetric(vertical: 20),
                                child: CupertinoActivityIndicator(),
                              ),
                            )
                          else
                            SizedBox(
                              height: 100,
                              child: ListView.builder(
                                scrollDirection: Axis.horizontal,
                                itemCount: _targetFavorites.length,
                                itemBuilder: (context, index) {
                                  final fav = _targetFavorites[index];
                                  final isSelected = _targetAccountController.text == fav['accountNumber'].toString();
                                  final accountNumber = fav['accountNumber']?.toString() ?? '';
                                  final email = fav['user'] != null ? (fav['user']['email'] ?? 'Unknown') : 'Unknown';
                                  return GestureDetector(
                                    onTap: () {
                                      setState(() {
                                        _targetAccountController.text = accountNumber;
                                      });
                                    },
                                    child: Container(
                                      width: 150,
                                      margin: const EdgeInsets.only(right: 12),
                                      decoration: BoxDecoration(
                                        color: isSelected ? teal500.withOpacity(0.2) : darkGrey,
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(
                                          color: isSelected ? teal500 : CupertinoColors.systemGrey4.withOpacity(0.3),
                                          width: 1,
                                        ),
                                      ),
                                      child: Stack(
                                        children: [
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
                                          Padding(
                                            padding: const EdgeInsets.all(1),
                                            child: Column(
                                              mainAxisAlignment: MainAxisAlignment.center,
                                              children: [
                                                Container(
                                                  padding: const EdgeInsets.all(8),
                                                  decoration: BoxDecoration(
                                                    color: teal500.withOpacity(0.1),
                                                    shape: BoxShape.circle,
                                                  ),
                                                  child: Icon(
                                                    CupertinoIcons.person_crop_circle_fill,
                                                    color: teal500,
                                                    size: 20,
                                                  ),
                                                ),
                                                const SizedBox(height: 8),
                                                Text(
                                                  _formatCardNumber(accountNumber),
                                                  style: TextStyle(
                                                    color: isSelected ? teal500 : CupertinoColors.white,
                                                    fontSize: 14,
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                                  textAlign: TextAlign.center,
                                                ),
                                                const SizedBox(height: 4),
                                                Text(
                                                  email,
                                                  style: TextStyle(
                                                    color: CupertinoColors.systemGrey,
                                                    fontSize: 12,
                                                  ),
                                                  maxLines: 1,
                                                  overflow: TextOverflow.ellipsis,
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
                            ),
                        ],
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
                            placeholder: 'Amount to transfer',
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
                              _buildQuickAmountButton('100000'),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),
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
                                      'Transfer Information',
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                        color: CupertinoColors.white,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      '• Double-check the account number before confirming\n• Transfers are typically processed immediately\n• Save frequent recipients as favorites for quick access',
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
                        // Transfer button
                        GestureDetector(
                          onTap: _isProcessing ? null : _transfer,
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
                                    'Transfer Money',
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
          },
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