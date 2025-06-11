import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:thinktwice/add_expenses_page.dart';
import 'package:thinktwice/expenses_details_page.dart';

class GroupDetailsPage extends StatefulWidget {
  final String groupId;
  final String homeCurrency;

  const GroupDetailsPage({
    Key? key,
    required this.groupId,
    required this.homeCurrency,
  }) : super(key: key);

  @override
  State<GroupDetailsPage> createState() => _GroupDetailsPageState();
}

class _GroupDetailsPageState extends State<GroupDetailsPage>
    with SingleTickerProviderStateMixin {
  final _database = FirebaseDatabase.instance;

  late TabController _tabController;
  String groupName = '';
  Map<String, String> memberNames = {}; // userId -> username
  Map<String, double> balances = {}; // userId -> balance
  List<Map<String, dynamic>> expenseHistory = [];

  final Map<String, IconData> categoryIcons = {
    'Food': Icons.fastfood,
    'Cafe': Icons.local_cafe,
    'Transport': Icons.directions_bus,
    'Shopping': Icons.local_mall,
    'Rent': Icons.home,
    'Entertainment': Icons.movie,
    'Accommodation': Icons.hotel,
    'Flight': Icons.flight,
    'Medical': Icons.medical_services,
    'Education': Icons.school,
    'Sports': Icons.sports_soccer,
    'Nightlife': Icons.nightlife,
    'Pet': Icons.pets,
    'Phone/Internet': Icons.phone_android,
    'Bills': Icons.receipt_long,
    'Gifts': Icons.celebration,
    'Donations': Icons.handshake,
    'Others': Icons.more_horiz,
  };

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _fetchGroupInfo();
    _fetchBalancesAndExpenses();
  }

  Future<void> _fetchGroupInfo() async {
    final groupRef = _database.ref('Groups/${widget.groupId}');
    final groupSnap = await groupRef.get();

    if (groupSnap.exists) {
      setState(() {
        groupName = groupSnap.child('groupName').value?.toString() ?? 'Group';
      });

      final membersData =
          groupSnap.child('members').value as Map<dynamic, dynamic>? ?? {};
      for (var entry in membersData.entries) {
        final userId = entry.key;
        final usernameSnap =
        await _database.ref('Users/$userId/username').get();
        final username = usernameSnap.value?.toString() ?? userId;
        memberNames[userId] = username;
      }
      setState(() {});
    }
  }

  void _fetchBalancesAndExpenses() {
    final expensesRef = _database.ref('Groups/${widget.groupId}/expenses');
    expensesRef.onValue.listen((event) {
      final expensesData = event.snapshot.value as Map<dynamic, dynamic>?;

      Map<String, double> tempBalances = {
        for (var userId in memberNames.keys) userId: 0.0,
      };
      List<Map<String, dynamic>> tempExpenses = [];

      if (expensesData != null) {
        expensesData.forEach((key, value) {
          final expense = Map<String, dynamic>.from(value);
          tempExpenses.add(expense);

          final double amount =
              double.tryParse(expense['amount'].toString()) ?? 0.0;
          final String paidBy = expense['paidBy'] ?? '';
          final List<dynamic> splitAmong =
              expense['splitAmong']?.cast<String>() ?? [];
          final bool splitEqually = expense['splitEqually'] ?? true;

          if (splitEqually) {
            double perPerson = amount / (splitAmong.isNotEmpty ? splitAmong.length : 1);
            for (var userId in splitAmong) {
              tempBalances[userId] = (tempBalances[userId] ?? 0.0) - perPerson;
            }
          } else {
            final manualAmounts = expense['manualAmounts'] as Map<dynamic, dynamic>? ?? {};
            manualAmounts.forEach((userId, value) {
              final manualAmount = double.tryParse(value.toString()) ?? 0.0;
              tempBalances[userId] = (tempBalances[userId] ?? 0.0) - manualAmount;
            });
          }

          tempBalances[paidBy] = (tempBalances[paidBy] ?? 0.0) + amount;
        });
      }

      setState(() {
        balances = tempBalances;
        expenseHistory = tempExpenses.reversed.toList();
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFDE2E4),
      appBar: AppBar(
        title: const Text("Group Details"),
        backgroundColor: const Color(0xFFCDB4DB),
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          indicatorColor: Colors.white,
          tabs: const [
            Tab(text: "Overview"),
            Tab(text: "Expenses"),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildOverviewTab(),
          _buildExpensesTab(),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: const Color(0xFF9D4EDD),
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => AddExpensePage(
                groupId: widget.groupId,
                homeCurrency: widget.homeCurrency,

              ),
            ),
          );
        },
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildOverviewTab() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            groupName,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Color(0xFF9D4EDD),
            ),
          ),
          const SizedBox(height: 8),
          Text("Home Currency: ${widget.homeCurrency}", style: const TextStyle(fontSize: 16)),
          const SizedBox(height: 20),
          const Text(
            "Balances:",
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF9D4EDD)),
          ),
          const SizedBox(height: 8),
          ...memberNames.entries.map((entry) {
            final userId = entry.key;
            final name = entry.value;
            final balance = balances[userId] ?? 0.0;
            final formattedBalance =
                "${balance < 0 ? '-' : ''}${widget.homeCurrency} ${balance.abs().toStringAsFixed(2)}";

            return ListTile(
              title: Text(name),
              trailing: Text(
                formattedBalance,
                style: TextStyle(
                  color: balance < 0 ? Colors.red : Colors.green,
                  fontWeight: FontWeight.bold,
                ),
              ),
            );
          }).toList(),
        ],
      ),
    );
  }

  Widget _buildExpensesTab() {
    if (expenseHistory.isEmpty) {
      return const Center(child: Text("No expenses yet."));
    }

    return ListView.builder(
      itemCount: expenseHistory.length,
      itemBuilder: (context, index) {
        final expense = expenseHistory[index];
        final title = expense['title'] ?? 'Untitled';
        final amount = double.tryParse(expense['amount'].toString()) ?? 0.0;
        final paidById = expense['paidBy'] ?? '';
        final paidBy = memberNames[paidById] ?? paidById;
        //final formattedAmount = "${widget.homeCurrency} ${amount.toStringAsFixed(2)}";
        final category = expense['category'] ?? 'Others';
        final icon = categoryIcons[category] ?? Icons.monetization_on_outlined;
        final splitEqually = expense['splitEqually'] ?? true;
        final fromCurrency = expense['fromCurrency'] ?? '';
        final amount_ori = double.tryParse(expense['amount_ori'].toString()) ?? 0.0;
        final formattedAmount = "$fromCurrency ${amount_ori.toStringAsFixed(2)}";

        // Split description logic
        String splitDescription;
        if (splitEqually) {
          final List<dynamic> splitAmong = expense['splitAmong'] ?? [];
          final names = splitAmong.map((id) => memberNames[id] ?? id).join(', ');
          splitDescription = "Split equally among: $names";
        } else {
          final manualAmounts = Map<String, dynamic>.from(expense['manualAmounts'] ?? {});
          final splits = manualAmounts.entries.map((e) {
            final name = memberNames[e.key] ?? e.key;
            final value = double.tryParse(e.value.toString())?.toStringAsFixed(2) ?? '0.00';
            return "$name ($fromCurrency $value)";
          }).join(', ');
          splitDescription = "Split manually: $splits";
        }

        return ListTile(
          leading: Icon(icon, color: Color(0xFF9D4EDD)),
          title: Text(title),
          subtitle: Text("Paid by $paidBy\n$splitDescription"),
          isThreeLine: true,
          trailing: Text(
            formattedAmount,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              color: Color(0xFF9D4EDD),
            ),
          ),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => ExpenseDetailsPage(
                  expense: expense,
                  memberNames: memberNames,
                  homeCurrency: widget.homeCurrency,
                ),
              ),
            );
          },
        );
      },
    );
  }
}
