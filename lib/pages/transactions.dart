import 'dart:convert';
import 'dart:ui';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show Colors;
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';

class TransactionsPage extends StatefulWidget {
  final String userId;
  final String email;

  const TransactionsPage({Key? key, required this.userId, required this.email}) : super(key: key);

  @override
  State<TransactionsPage> createState() => _TransactionsPageState();
}

class _TransactionsPageState extends State<TransactionsPage> with SingleTickerProviderStateMixin {
  bool _isLoading = true;
  bool _isRefreshing = false;
  List<dynamic> _transactions = [];
  List<dynamic> _accounts = [];
  final currencyFormatter = NumberFormat.currency(symbol: '₱');
  String _sortOption = 'Newest'; // Default sort option
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  // Available sort options.
  final Map<String, String> sortOptions = {
    'Newest': 'Newest',
    'Oldest': 'Oldest',
    'High to Low': 'High to Low',
    'Low to High': 'Low to High'
  };

  // Transaction type icons and colors
  final Map<String, IconData> _transactionIcons = {
    'transfer': CupertinoIcons.arrow_right_circle_fill,
    'deposit': CupertinoIcons.arrow_down_circle_fill,
    'cash in': CupertinoIcons.arrow_down_circle_fill,
    'cashin': CupertinoIcons.arrow_down_circle_fill,
    'withdrawal': CupertinoIcons.arrow_up_circle_fill,
    'payment': CupertinoIcons.money_dollar_circle_fill,
    'pay bills': CupertinoIcons.doc_text_fill,
    'paybills': CupertinoIcons.doc_text_fill,
  };

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
    _fetchAccountsAndTransactions();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _fetchAccountsAndTransactions() async {
    if (!_isRefreshing) {
      setState(() {
        _isLoading = true;
      });
    }

    await _fetchAccounts();
    await _fetchTransactions();

    if (!_isRefreshing) {
      setState(() {
        _isLoading = false;
      });
      _animationController.forward();
    } else {
      setState(() {
        _isRefreshing = false;
      });
    }
  }

  Future<void> _refreshData() async {
    setState(() {
      _isRefreshing = true;
    });
    await _fetchAccountsAndTransactions();
  }

  Future<void> _fetchAccounts() async {
    try {
      final url = Uri.parse('https://airbank-server.onrender.com/api/accounts');
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final List<dynamic> allAccounts = json.decode(response.body);
        setState(() {
          _accounts = allAccounts.where((acc) => acc['userId'] == widget.userId).toList();
        });
      }
    } catch (e) {
      debugPrint('Error fetching accounts: $e');
    }
  }

  Future<void> _fetchTransactions() async {
    try {
      final url = Uri.parse('https://airbank-server.onrender.com/api/transactions');
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final List<dynamic> allTransactions = json.decode(response.body);
        // Build a list of user account numbers
        List<String> userAccountNumbers =
        _accounts.map((acc) => acc['accountNumber'].toString()).toList();
        // Filter transactions: show those where either the sender or receiver is in the user's accounts.
        final userTransactions = allTransactions.where((tx) {
          final sender = tx['sender']?.toString() ?? '';
          final receiver = tx['receiver']?.toString() ?? '';
          return userAccountNumbers.contains(sender) || userAccountNumbers.contains(receiver) ||
              sender == widget.userId || receiver == widget.userId ||
              sender == 'CASH' || receiver == 'CASH';
        }).toList();
        setState(() {
          _transactions = userTransactions;
          _sortTransactions();
        });
      }
    } catch (e) {
      debugPrint('Error fetching transactions: $e');
    }
  }

  void _sortTransactions() {
    if (_sortOption == 'Newest') {
      _transactions.sort((a, b) {
        DateTime dateA = DateTime.tryParse(a['date']?.toString() ?? '') ?? DateTime.now();
        DateTime dateB = DateTime.tryParse(b['date']?.toString() ?? '') ?? DateTime.now();
        return dateB.compareTo(dateA);
      });
    } else if (_sortOption == 'Oldest') {
      _transactions.sort((a, b) {
        DateTime dateA = DateTime.tryParse(a['date']?.toString() ?? '') ?? DateTime.now();
        DateTime dateB = DateTime.tryParse(b['date']?.toString() ?? '') ?? DateTime.now();
        return dateA.compareTo(dateB);
      });
    } else if (_sortOption == 'High to Low') {
      _transactions.sort((a, b) {
        double amountA = double.tryParse(a['amount']?.toString() ?? '0') ?? 0;
        double amountB = double.tryParse(b['amount']?.toString() ?? '0') ?? 0;
        return amountB.compareTo(amountA);
      });
    } else if (_sortOption == 'Low to High') {
      _transactions.sort((a, b) {
        double amountA = double.tryParse(a['amount']?.toString() ?? '0') ?? 0;
        double amountB = double.tryParse(b['amount']?.toString() ?? '0') ?? 0;
        return amountA.compareTo(amountB);
      });
    }
  }

  // Returns an icon based on the transaction type.
  IconData _getTransactionIcon(String type) {
    final lowerType = type.toLowerCase();
    return _transactionIcons[lowerType] ?? CupertinoIcons.arrow_2_circlepath;
  }

  // Determines the color based on whether the transaction is outgoing (sender is one of user's account numbers).
  Color _getTransactionColor(String sender, String receiver, String type) {
    final tealColor = CupertinoColors.activeBlue;
    final lowerType = type.toLowerCase();

    List<String> userAccountNumbers =
    _accounts.map((acc) => acc['accountNumber'].toString()).toList();

    // For cash in, always show green
    if (lowerType == 'cash in' || lowerType == 'cashin' || lowerType == 'deposit') {
      return CupertinoColors.activeGreen;
    }

    // For pay bills, always show red
    if (lowerType == 'pay bills' || lowerType == 'paybills' || lowerType == 'payment') {
      return CupertinoColors.systemRed;
    }

    // For transfers, check if user is sender or receiver
    if (userAccountNumbers.contains(sender) || sender == widget.userId) {
      return CupertinoColors.systemRed; // Outgoing
    } else {
      return tealColor; // Incoming
    }
  }

  // Format account numbers for display
  String _formatAccountNumber(String accountNumber) {
    if (accountNumber.length < 4) return accountNumber;
    return '••••${accountNumber.substring(accountNumber.length - 4)}';
  }

  // Check if the account belongs to the user
  bool _isUserAccount(String accountNumber) {
    return _accounts.any((acc) => acc['accountNumber'].toString() == accountNumber);
  }

  // Format party name for display
  String _formatPartyName(String party) {
    if (party == 'CASH') {
      return 'Cash';
    } else if (party == widget.userId) {
      return 'You';
    } else if (_isUserAccount(party)) {
      return 'You (${_formatAccountNumber(party)})';
    } else {
      return 'Account ${_formatAccountNumber(party)}';
    }
  }

  @override
  Widget build(BuildContext context) {
    final tealColor = CupertinoColors.activeBlue;
    final darkGrey = CupertinoColors.darkBackgroundGray;

    return CupertinoPageScaffold(
      backgroundColor: CupertinoColors.black,
      navigationBar: CupertinoNavigationBar(
        backgroundColor: CupertinoColors.black.withOpacity(0.8),
        border: Border.all(color: CupertinoColors.black),
        middle: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              CupertinoIcons.list_bullet_below_rectangle,
              color: tealColor,
              size: 20,
            ),
            const SizedBox(width: 8),
            const Text('Transactions'),
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
                'Loading your transactions...',
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
            children: [
              // Header with transaction count
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Transaction History',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: CupertinoColors.white,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: tealColor.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '${_transactions.length} items',
                        style: TextStyle(
                          color: tealColor,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Sorting filter
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: darkGrey,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: CupertinoSlidingSegmentedControl<String>(
                    groupValue: _sortOption,
                    backgroundColor: darkGrey,
                    thumbColor: tealColor,
                    children: sortOptions.map((key, value) {
                      return MapEntry(
                        key,
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                          child: Text(
                            value,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: _sortOption == key
                                  ? CupertinoColors.white
                                  : CupertinoColors.systemGrey,
                            ),
                          ),
                        ),
                      );
                    }),
                    onValueChanged: (value) {
                      if (value != null) {
                        setState(() {
                          _sortOption = value;
                          _sortTransactions();
                        });
                      }
                    },
                  ),
                ),
              ),

              // Transaction list
              Expanded(
                child: _transactions.isEmpty
                    ? _buildEmptyState()
                    : CustomScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  slivers: [
                    CupertinoSliverRefreshControl(
                      onRefresh: _refreshData,
                      builder: (
                          BuildContext context,
                          RefreshIndicatorMode refreshState,
                          double pulledExtent,
                          double refreshTriggerPullDistance,
                          double refreshIndicatorExtent,
                          ) {
                        return Center(
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              const CupertinoActivityIndicator(
                                color: CupertinoColors.white,
                                radius: 14,
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                      sliver: SliverList(
                        delegate: SliverChildBuilderDelegate(
                              (context, index) {
                            final tx = _transactions[index];
                            final type = tx['transactionType'] ?? 'Transaction';
                            final sender = tx['sender']?.toString() ?? '';
                            final receiver = tx['receiver']?.toString() ?? '';
                            final date = tx['date'] != null
                                ? DateTime.tryParse(tx['date'].toString())
                                : DateTime.now();
                            final formattedDate = date != null
                                ? DateFormat('MMM d, yyyy • h:mm a').format(date)
                                : 'Unknown date';
                            final amount = double.tryParse(tx['amount']?.toString() ?? '0') ?? 0.0;
                            final formattedAmount = currencyFormatter.format(amount);
                            final transactionColor = _getTransactionColor(sender, receiver, type);
                            final isOutgoing = transactionColor == CupertinoColors.systemRed;

                            // Group transactions by date
                            final bool showDateHeader = index == 0 ||
                                _shouldShowDateHeader(date, _transactions[index - 1]['date']);

                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (showDateHeader) ...[
                                  Padding(
                                    padding: const EdgeInsets.only(top: 16, bottom: 8),
                                    child: Text(
                                      _formatDateHeader(date),
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                        color: CupertinoColors.systemGrey,
                                      ),
                                    ),
                                  ),
                                ],
                                Container(
                                  margin: const EdgeInsets.only(bottom: 12),
                                  decoration: BoxDecoration(
                                    color: darkGrey,
                                    borderRadius: BorderRadius.circular(16),
                                    boxShadow: [
                                      BoxShadow(
                                        color: CupertinoColors.black.withOpacity(0.2),
                                        blurRadius: 8,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: Padding(
                                    padding: const EdgeInsets.all(16),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        // Transaction header with icon and amount
                                        Row(
                                          children: [
                                            // Transaction icon
                                            Container(
                                              width: 48,
                                              height: 48,
                                              decoration: BoxDecoration(
                                                color: transactionColor.withOpacity(0.15),
                                                borderRadius: BorderRadius.circular(12),
                                              ),
                                              child: Center(
                                                child: Icon(
                                                  _getTransactionIcon(type),
                                                  color: transactionColor,
                                                  size: 24,
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 16),
                                            // Transaction type and date
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    _getTransactionTypeTitle(type),
                                                    style: const TextStyle(
                                                      fontWeight: FontWeight.w600,
                                                      fontSize: 16,
                                                      color: CupertinoColors.white,
                                                    ),
                                                  ),
                                                  const SizedBox(height: 4),
                                                  Text(
                                                    formattedDate,
                                                    style: const TextStyle(
                                                      fontSize: 13,
                                                      color: CupertinoColors.systemGrey,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            // Amount
                                            Text(
                                              isOutgoing ? '-$formattedAmount' : '+$formattedAmount',
                                              style: TextStyle(
                                                fontWeight: FontWeight.w600,
                                                fontSize: 16,
                                                color: transactionColor,
                                              ),
                                            ),
                                          ],
                                        ),

                                        // Divider
                                        Padding(
                                          padding: const EdgeInsets.symmetric(vertical: 12),
                                          child: Container(
                                            height: 1,
                                            color: CupertinoColors.systemGrey.withOpacity(0.2),
                                          ),
                                        ),

                                        // Transaction details - clearly showing sender and receiver
                                        _buildTransactionDetails(type, sender, receiver, isOutgoing),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            );
                          },
                          childCount: _transactions.length,
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
    );
  }

  // Build the transaction details section with clear sender and receiver information
  Widget _buildTransactionDetails(String type, String sender, String receiver, bool isOutgoing) {
    final tealColor = CupertinoColors.activeBlue;
    final lowerType = type.toLowerCase();

    // For Cash In transactions
    if (lowerType == 'cash in' || lowerType == 'cashin' || lowerType == 'deposit') {
      return Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'From',
                  style: TextStyle(
                    fontSize: 12,
                    color: CupertinoColors.systemGrey,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(
                      CupertinoIcons.money_dollar_circle,
                      size: 16,
                      color: CupertinoColors.activeGreen,
                    ),
                    const SizedBox(width: 6),
                    const Text(
                      'Cash Deposit',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: CupertinoColors.white,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Icon(
            CupertinoIcons.arrow_right,
            size: 16,
            color: CupertinoColors.systemGrey,
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                const Text(
                  'To',
                  style: TextStyle(
                    fontSize: 12,
                    color: CupertinoColors.systemGrey,
                  ),
                  textAlign: TextAlign.right,
                ),
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Icon(
                      CupertinoIcons.creditcard,
                      size: 16,
                      color: tealColor,
                    ),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        _formatPartyName(receiver),
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: CupertinoColors.white,
                        ),
                        textAlign: TextAlign.right,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      );
    }

    // For Pay Bills transactions
    if (lowerType == 'pay bills' || lowerType == 'paybills' || lowerType == 'payment') {
      return Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'From',
                  style: TextStyle(
                    fontSize: 12,
                    color: CupertinoColors.systemGrey,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(
                      CupertinoIcons.creditcard,
                      size: 16,
                      color: tealColor,
                    ),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        _formatPartyName(sender),
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: CupertinoColors.white,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Icon(
            CupertinoIcons.arrow_right,
            size: 16,
            color: CupertinoColors.systemGrey,
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                const Text(
                  'To',
                  style: TextStyle(
                    fontSize: 12,
                    color: CupertinoColors.systemGrey,
                  ),
                  textAlign: TextAlign.right,
                ),
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Icon(
                      CupertinoIcons.doc_text,
                      size: 16,
                      color: CupertinoColors.systemRed,
                    ),
                    const SizedBox(width: 6),
                    const Flexible(
                      child: Text(
                        'Bill Payment',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: CupertinoColors.white,
                        ),
                        textAlign: TextAlign.right,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      );
    }

    // For Transfer transactions
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'From',
                style: TextStyle(
                  fontSize: 12,
                  color: CupertinoColors.systemGrey,
                ),
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Icon(
                    CupertinoIcons.person_crop_circle,
                    size: 16,
                    color: isOutgoing ? tealColor : CupertinoColors.systemGrey,
                  ),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      _formatPartyName(sender),
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: isOutgoing ? CupertinoColors.white : CupertinoColors.systemGrey,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        Icon(
          CupertinoIcons.arrow_right,
          size: 16,
          color: CupertinoColors.systemGrey,
        ),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              const Text(
                'To',
                style: TextStyle(
                  fontSize: 12,
                  color: CupertinoColors.systemGrey,
                ),
                textAlign: TextAlign.right,
              ),
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Icon(
                    CupertinoIcons.person_crop_circle,
                    size: 16,
                    color: isOutgoing ? CupertinoColors.systemGrey : tealColor,
                  ),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      _formatPartyName(receiver),
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: isOutgoing ? CupertinoColors.systemGrey : CupertinoColors.white,
                      ),
                      textAlign: TextAlign.right,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  // Get a user-friendly title for the transaction type
  String _getTransactionTypeTitle(String type) {
    final lowerType = type.toLowerCase();

    if (lowerType == 'cash in' || lowerType == 'cashin') {
      return 'Cash Deposit';
    } else if (lowerType == 'deposit') {
      return 'Deposit';
    } else if (lowerType == 'pay bills' || lowerType == 'paybills') {
      return 'Bill Payment';
    } else if (lowerType == 'transfer') {
      return 'Money Transfer';
    } else if (lowerType == 'withdrawal') {
      return 'Withdrawal';
    } else if (lowerType == 'payment') {
      return 'Payment';
    }

    return type;
  }

  bool _shouldShowDateHeader(DateTime? currentDate, dynamic previousDateStr) {
    if (currentDate == null) return true;

    final previousDate = DateTime.tryParse(previousDateStr?.toString() ?? '');
    if (previousDate == null) return true;

    return currentDate.year != previousDate.year ||
        currentDate.month != previousDate.month ||
        currentDate.day != previousDate.day;
  }

  String _formatDateHeader(DateTime? date) {
    if (date == null) return 'Unknown Date';

    final now = DateTime.now();
    final yesterday = DateTime(now.year, now.month, now.day - 1);

    if (date.year == now.year && date.month == now.month && date.day == now.day) {
      return 'Today';
    } else if (date.year == yesterday.year && date.month == yesterday.month && date.day == yesterday.day) {
      return 'Yesterday';
    } else {
      return DateFormat('MMMM d, yyyy').format(date);
    }
  }

  Widget _buildEmptyState() {
    final tealColor = CupertinoColors.activeBlue;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: tealColor.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                CupertinoIcons.list_bullet_below_rectangle,
                size: 48,
                color: tealColor,
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'No Transactions Yet',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: CupertinoColors.white,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              'Your transaction history will appear here once you start making transfers, deposits, or payments.',
              style: TextStyle(
                fontSize: 16,
                color: CupertinoColors.systemGrey,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            GestureDetector(
              onTap: _refreshData,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: tealColor,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      CupertinoIcons.refresh,
                      color: CupertinoColors.white,
                      size: 16,
                    ),
                    SizedBox(width: 8),
                    Text(
                      'Refresh',
                      style: TextStyle(
                        color: CupertinoColors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}