import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:thinktwice/add_expenses_page.dart';

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

class _GroupDetailsPageState extends State<GroupDetailsPage> {
  final _database = FirebaseDatabase.instance;

  String groupName = '';
  Map<String, String> memberNames = {}; // userId -> username
  Map<String, double> balances = {}; // userId -> balance

  @override
  void initState() {
    super.initState();
    _fetchGroupInfo();
    _fetchBalances();
  }

  Future<void> _fetchGroupInfo() async {
    final groupRef = _database.ref('Groups/${widget.groupId}');
    final groupSnap = await groupRef.get();

    if (groupSnap.exists) {
      setState(() {
        groupName = groupSnap.child('groupName').value?.toString() ?? 'Group';
      });

      final membersData = groupSnap.child('members').value as Map<dynamic, dynamic>? ?? {};
      for (var entry in membersData.entries) {
        final userId = entry.key;
        final usernameSnap = await _database.ref('Users/$userId/username').get();
        final username = usernameSnap.value?.toString() ?? userId;
        memberNames[userId] = username;
      }
      setState(() {}); // Refresh UI after fetching usernames
    }
  }

  void _fetchBalances() {
    final expensesRef = _database.ref('Groups/${widget.groupId}/expenses');
    expensesRef.onValue.listen((event) {
      final expensesData = event.snapshot.value as Map<dynamic, dynamic>?;

      Map<String, double> tempBalances = {};
      for (var userId in memberNames.keys) {
        tempBalances[userId] = 0.0;
      }

      if (expensesData != null) {
        expensesData.forEach((key, value) {
          final expense = Map<String, dynamic>.from(value);
          final double amount = double.tryParse(expense['amount'].toString()) ?? 0.0;
          final String paidBy = expense['paidBy'] ?? '';
          final List<dynamic> splitAmong = expense['splitAmong']?.cast<String>() ?? [];

          double perPerson = amount / (splitAmong.isNotEmpty ? splitAmong.length : 1);

          for (var userId in splitAmong) {
            tempBalances[userId] = (tempBalances[userId] ?? 0.0) - perPerson;
          }

          tempBalances[paidBy] = (tempBalances[paidBy] ?? 0.0) + amount;
        });
      }

      setState(() {
        balances = tempBalances;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFDE2E4), // light pink
      appBar: AppBar(
        title: const Text("Group Details"),
        backgroundColor: const Color(0xFFCDB4DB), // light purple
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                groupName,
                style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF9D4EDD)),
              ),
              const SizedBox(height: 8),
              Text(
                "Home Currency: ${widget.homeCurrency}",
                style: const TextStyle(fontSize: 16),
              ),
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
                final formattedBalance = "${balance < 0 ? '-' : ''}${widget.homeCurrency} ${balance.abs().toStringAsFixed(2)}";

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
        ),
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: const Color(0xFF9D4EDD),
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => AddExpensePage(groupId: widget.groupId),
            ),
          );
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}
