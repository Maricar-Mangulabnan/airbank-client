import 'dart:convert';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show Colors;
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';

import 'cashin.dart';
import 'paybills.dart';
import 'profile.dart';
import 'transfer.dart';
import 'transactions.dart';
import 'add-bank-account.dart';

class DashboardPage extends StatefulWidget {
  final String email;
  final String userId;

  const DashboardPage({super.key, required this.email, required this.userId});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> with SingleTickerProviderStateMixin {
  bool _isLoading = true;
  String _greeting = '';
  List<dynamic> _accounts = [];
  List<dynamic> _transactions = [];
  dynamic _activeAccount;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  final currencyFormatter = NumberFormat.currency(symbol: '₱');
  final dateFormatter = DateFormat('MM/yy');
  bool _isRefreshing = false;
  final ScrollController _scrollController = ScrollController();

  // Define teal500 color
  final Color teal500 = const Color(0xFF009688);

  @override
  void initState() {
    super.initState();
    _setGreeting();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
    );
    _fetchBankAccounts();
    _fetchTransactions();
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _setGreeting() {
    final hour = DateTime.now().hour;
    String greeting;
    if (hour < 12) {
      greeting = 'Good Morning';
    } else if (hour < 17) {
      greeting = 'Good Afternoon';
    } else {
      greeting = 'Good Evening';
    }
    final name = widget.email.split('@').first;
    final capitalizedName = name.isNotEmpty ? '${name[0].toUpperCase()}${name.substring(1)}' : '';
    _greeting = '$greeting, $capitalizedName';
  }

  Future<void> _fetchBankAccounts() async {
    try {
      final url = Uri.parse('https://airbank-server.onrender.com/api/accounts');
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final List<dynamic> allAccounts = json.decode(response.body);
        final userAccounts = allAccounts.where((acc) => acc['userId'] == widget.userId).toList();
        setState(() {
          _accounts = userAccounts;
          if (_accounts.isNotEmpty) {
            _activeAccount = _accounts[0];
          }
        });
        // Fetch transactions after accounts have been loaded
        await _fetchTransactions();
      }
    } catch (e) {
      debugPrint('Error fetching accounts: $e');
    }
    setState(() {
      _isLoading = false;
      _isRefreshing = false;
    });
  }


  Future<void> _fetchTransactions() async {
    try {
      final url = Uri.parse('https://airbank-server.onrender.com/api/transactions');
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final List<dynamic> allTransactions = json.decode(response.body);
        List<String> userAccountNumbers = _accounts.map((acc) => acc['accountNumber'].toString()).toList();
        final userTransactions = allTransactions.where((tx) {
          return userAccountNumbers.contains(tx['sender']) || userAccountNumbers.contains(tx['receiver']);
        }).toList();
        setState(() {
          // Reverse to show the most recent transactions first
          _transactions = userTransactions.reversed.toList();
        });
      }
    } catch (e) {
      debugPrint('Error fetching transactions: $e');
    }
  }

  void _refreshData() async {
    setState(() {
      _isRefreshing = true;
    });
    await _fetchBankAccounts();
    await _fetchTransactions();
  }

  // Return only the latest 10 transactions.
  List<dynamic> get _recentTransactions {
    if (_transactions.length <= 10) return _transactions;
    return _transactions.take(10).toList();
  }

  String _getTransactionIcon(String type) {
    switch (type.toLowerCase()) {
      case 'transfer':
        return '↗️';
      case 'deposit':
      case 'cash in':
        return '⬇️';
      case 'withdrawal':
        return '⬆️';
      case 'payment':
      case 'pay bills':
        return '💸';
      default:
        return '💱';
    }
  }

  // Determines if a transaction is outgoing by comparing the sender to the active account's account number.
  bool _isOutgoing(String sender) {
    if (_activeAccount == null) return false;
    return sender == _activeAccount['accountNumber'];
  }

  // Returns a color based on whether the transaction is outgoing.
  Color _getTransactionColor(String type, String sender) {
    return _isOutgoing(sender) ? CupertinoColors.systemRed : Colors.teal;
  }

  String _formatCardNumber(String number) {
    if (number.length < 4) return number;
    return '••••${number.substring(number.length - 4)}';
  }

  Widget _buildEmptyState({required IconData icon, required String title, required String message}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 30, horizontal: 20),
      decoration: BoxDecoration(
        color: CupertinoColors.darkBackgroundGray,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Icon(icon, size: 48, color: teal500.withOpacity(0.7)),
          const SizedBox(height: 16),
          Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: CupertinoColors.white)),
          const SizedBox(height: 8),
          Text(message, textAlign: TextAlign.center, style: const TextStyle(fontSize: 14, color: CupertinoColors.systemGrey)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final darkGrey = CupertinoColors.darkBackgroundGray;
    final screenSize = MediaQuery.of(context).size;

    return CupertinoPageScaffold(
      backgroundColor: CupertinoColors.black,
      navigationBar: CupertinoNavigationBar(
        backgroundColor: CupertinoColors.black.withOpacity(0.8),
        border: Border.all(color: CupertinoColors.black),
        middle: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(CupertinoIcons.money_dollar_circle_fill, color: teal500, size: 22),
            const SizedBox(width: 8),
            const Text('AirBank', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          ],
        ),
        trailing: GestureDetector(
          onTap: () {
            Navigator.push(context, CupertinoPageRoute(builder: (_) => ProfilePage(email: widget.email)))
                .then((_) => _refreshData());
          },
          child: Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: teal500, width: 1.5),
            ),
            child: Icon(CupertinoIcons.person, color: teal500, size: 20),
          ),
        ),
      ),
      child: _isLoading
          ? Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CupertinoActivityIndicator(radius: 16),
            const SizedBox(height: 16),
            Text('Loading your finances...', style: TextStyle(color: CupertinoColors.systemGrey, fontSize: 16)),
          ],
        ),
      )
          : SafeArea(
        child: NotificationListener<ScrollNotification>(
          onNotification: (notification) {
            if (notification is ScrollStartNotification) {
              if (_scrollController.position.pixels <= -100 && !_isRefreshing) {
                _refreshData();
              }
            }
            return false;
          },
          child: SingleChildScrollView(
            controller: _scrollController,
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 16),
                  // Greeting and date
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(_greeting,
                              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: CupertinoColors.white)),
                          const SizedBox(height: 4),
                          Text(DateFormat('EEEE, MMMM d, yyyy').format(DateTime.now()),
                              style: const TextStyle(fontSize: 14, color: CupertinoColors.systemGrey)),
                        ],
                      ),
                      _isRefreshing
                          ? const CupertinoActivityIndicator()
                          : GestureDetector(
                        onTap: _refreshData,
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: darkGrey,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(CupertinoIcons.refresh, color: teal500, size: 20),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  // Bank Accounts Section with Card UI and Add Account Icon
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Your Accounts',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: CupertinoColors.white)),
                      Row(
                        children: [
                          GestureDetector(
                            onTap: () {
                              Navigator.push(
                                context,
                                CupertinoPageRoute(builder: (_) => AddBankAccountPage(userId: widget.userId)),
                              ).then((_) => _refreshData());
                            },
                            child: Icon(CupertinoIcons.add, color: teal500, size: 24),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  if (_accounts.isEmpty)
                    _buildEmptyState(
                      icon: CupertinoIcons.creditcard,
                      title: 'No Accounts Found',
                      message: 'You don\'t have any bank accounts yet.',
                    )
                  else
                    SizedBox(
                      height: 200,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: _accounts.length,
                        itemBuilder: (context, index) {
                          final acc = _accounts[index];
                          final isActive = _activeAccount != null && acc['id'] == _activeAccount['id'];
                          final balance = double.tryParse(acc['balance'].toString()) ?? 0.0;
                          final formattedBalance = currencyFormatter.format(balance);
                          final expiration = acc['expiration']?.toString() ?? 'MM/YY';
                          final ccv = acc['ccv']?.toString() ?? '***';
                          final accountNumber = acc['accountNumber']?.toString() ?? '';
                          return GestureDetector(
                            onTap: () {
                              setState(() {
                                _activeAccount = acc;
                              });
                            },
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 300),
                              margin: const EdgeInsets.only(right: 16, bottom: 8),
                              width: screenSize.width * 0.75,
                              decoration: BoxDecoration(
                                color: isActive ? teal500 : darkGrey,
                                borderRadius: BorderRadius.circular(20),
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
                                  Positioned(
                                    right: -20,
                                    bottom: -20,
                                    child: Opacity(
                                      opacity: 0.1,
                                      child: Icon(CupertinoIcons.creditcard_fill, size: 150, color: CupertinoColors.white),
                                    ),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.all(20),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            Row(
                                              children: [
                                                Icon(
                                                  CupertinoIcons.money_dollar_circle_fill,
                                                  color: isActive ? CupertinoColors.white : teal500,
                                                  size: 24,
                                                ),
                                                const SizedBox(width: 8),
                                                Text('AirBank',
                                                    style: TextStyle(
                                                      color: isActive ? CupertinoColors.white : CupertinoColors.white,
                                                      fontWeight: FontWeight.bold,
                                                      fontSize: 16,
                                                    )),
                                              ],
                                            ),
                                            Icon(
                                              CupertinoIcons.wifi,
                                              color: isActive ? CupertinoColors.white : CupertinoColors.white,
                                              size: 20,
                                            ),
                                          ],
                                        ),
                                        Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text('Current Balance',
                                                style: TextStyle(
                                                  color: isActive ? CupertinoColors.white.withOpacity(0.7) : CupertinoColors.systemGrey,
                                                  fontSize: 12,
                                                )),
                                            const SizedBox(height: 4),
                                            Text(formattedBalance,
                                                style: const TextStyle(
                                                  color: CupertinoColors.white,
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 24,
                                                )),
                                          ],
                                        ),
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            Text(_formatCardNumber(accountNumber),
                                                style: const TextStyle(
                                                  color: CupertinoColors.white,
                                                  fontSize: 14,
                                                  letterSpacing: 2,
                                                )),
                                            Column(
                                              crossAxisAlignment: CrossAxisAlignment.end,
                                              children: [
                                                Text('EXP: $expiration',
                                                    style: TextStyle(
                                                      color: isActive ? CupertinoColors.white.withOpacity(0.7) : CupertinoColors.systemGrey,
                                                      fontSize: 12,
                                                    )),
                                                Text('CCV: $ccv',
                                                    style: TextStyle(
                                                      color: isActive ? CupertinoColors.white.withOpacity(0.7) : CupertinoColors.systemGrey,
                                                      fontSize: 12,
                                                    )),
                                              ],
                                            ),
                                          ],
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
                  const SizedBox(height: 24),
                  // Quick Actions
                  const Text(
                    'Quick Actions',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: CupertinoColors.white,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildActionButton(
                        icon: CupertinoIcons.add_circled,
                        label: 'Cash In',
                        color: Colors.teal,
                        onTap: () {
                          Navigator.push(
                            context,
                            CupertinoPageRoute(
                              builder: (context) => CashInPage(
                                userId: widget.userId,
                                email: widget.email,
                                accounts: _accounts,
                              ),
                            ),
                          ).then((_) => _refreshData());
                        },
                      ),
                      _buildActionButton(
                        icon: CupertinoIcons.shuffle_medium,
                        label: 'Transfer',
                        color: teal500,
                        onTap: () {
                          Navigator.push(
                            context,
                            CupertinoPageRoute(
                              builder: (context) => TransferPage(
                                userId: widget.userId,
                                email: widget.email,
                                accounts: _accounts,
                              ),
                            ),
                          ).then((_) => _refreshData());
                        },
                      ),
                      _buildActionButton(
                        icon: CupertinoIcons.money_rubl_circle,
                        label: 'Pay Bills',
                        color: teal500,
                        onTap: () {
                          Navigator.push(
                            context,
                            CupertinoPageRoute(
                              builder: (context) => PayBillsPage(
                                userId: widget.userId,
                                email: widget.email,
                                accounts: _accounts,
                              ),
                            ),
                          ).then((_) => _refreshData());
                        },
                      ),
                      _buildActionButton(
                        icon: CupertinoIcons.chart_bar_alt_fill,
                        label: 'Analytics',
                        color: teal500,
                        onTap: () {
                          showCupertinoDialog(
                            context: context,
                            builder: (_) => CupertinoAlertDialog(
                              title: const Text('Coming Soon'),
                              content: const Text('Analytics feature will be available in the next update.'),
                              actions: [
                                CupertinoDialogAction(
                                  child: const Text('OK'),
                                  onPressed: () => Navigator.pop(context),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  // Recent Transactions Section (latest 10 transactions with full details)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Recent Transactions',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: CupertinoColors.white,
                        ),
                      ),
                      Row(
                        children: [
                          GestureDetector(
                            onTap: () {
                              Navigator.push(
                                context,
                                CupertinoPageRoute(builder: (_) => TransactionsPage(userId: widget.userId, email: widget.email)),
                              );
                            },
                            child: Text(
                              'See all',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: Colors.teal,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  if (_activeAccount == null)
                    _buildEmptyState(
                      icon: CupertinoIcons.creditcard,
                      title: 'No Account Selected',
                      message: 'Please select a bank account to view transactions.',
                    )
                  else if (_recentTransactions.isEmpty)
                    _buildEmptyState(
                      icon: CupertinoIcons.arrow_2_circlepath,
                      title: 'No Transactions',
                      message: 'You haven\'t made any transactions yet.',
                    )
                  else
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _recentTransactions.length,
                      itemBuilder: (context, index) {
                        final tx = _recentTransactions[index];
                        final type = tx['transactionType'] ?? 'Transaction';
                        final sender = tx['sender']?.toString() ?? '';
                        final receiver = tx['receiver']?.toString() ?? '';
                        final date = tx['date'] != null
                            ? DateTime.tryParse(tx['date'].toString())
                            : DateTime.now();
                        final formattedDate = date != null
                            ? DateFormat('MMM d, h:mm a').format(date)
                            : 'Unknown date';
                        final amount = double.tryParse(tx['amount'].toString()) ?? 0.0;
                        final formattedAmount = currencyFormatter.format(amount);
                        final isOutgoing = _activeAccount != null && (sender == _activeAccount['accountNumber']);

                        return Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          decoration: BoxDecoration(
                            color: darkGrey,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  type,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 16,
                                    color: CupertinoColors.white,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text('Sender: $sender',
                                    style: const TextStyle(fontSize: 13, color: CupertinoColors.systemGrey)),
                                const SizedBox(height: 4),
                                Text('Receiver: $receiver',
                                    style: const TextStyle(fontSize: 13, color: CupertinoColors.systemGrey)),
                                const SizedBox(height: 4),
                                Text(
                                  formattedDate,
                                  style: const TextStyle(fontSize: 12, color: CupertinoColors.systemGrey4),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  isOutgoing ? '-$formattedAmount' : '+$formattedAmount',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 16,
                                    color: _getTransactionColor(type, sender),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  const SizedBox(height: 30),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildActionButton({required IconData icon, required String label, required Color color, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: color.withOpacity(0.2),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: color.withOpacity(0.5), width: 1.5),
            ),
            child: Icon(icon, color: color, size: 28),
          ),
          const SizedBox(height: 8),
          Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: CupertinoColors.white)),
        ],
      ),
    );
  }
}