import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';

class AddExpensePage extends StatefulWidget {
  final String groupId;

  const AddExpensePage({Key? key, required this.groupId}) : super(key: key);

  @override
  State<AddExpensePage> createState() => _AddExpensePageState();
}

class _AddExpensePageState extends State<AddExpensePage> {
  final _auth = FirebaseAuth.instance;
  final _database = FirebaseDatabase.instance;

  String? currentUserId;
  Map<String, String> memberNames = {}; // userId -> userName

  String title = '';
  String amount = '';
  String paidBy = '';
  List<String> selectedUsers = [];

  @override
  void initState() {
    super.initState();
    currentUserId = _auth.currentUser?.uid;
    _loadGroupMembers();
  }

  void _loadGroupMembers() {
    final membersRef = _database.ref('Groups/${widget.groupId}/members');
    membersRef.onValue.listen((event) async {
      final membersData = event.snapshot.value as Map<dynamic, dynamic>?;

      if (membersData == null) return;

      Map<String, String> tempNames = {};
      for (var userId in membersData.keys) {
        final userSnap = await _database.ref('Users/$userId/username').get();
        final username = userSnap.value as String?;
        tempNames[userId] = username ?? userId;
      }

      setState(() {
        memberNames = tempNames;
        paidBy = currentUserId ?? '';
        selectedUsers = memberNames.keys.toList();
      });
    });
  }

  Future<void> _addExpense() async {
    if (title.trim().isEmpty || amount.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Title and amount cannot be empty!")),
      );
      return;
    }

    final expense = {
      'title': title.trim(),
      'amount': double.tryParse(amount) ?? 0,
      'paidBy': paidBy,
      'splitAmong': selectedUsers,
      'timestamp': ServerValue.timestamp,
    };

    await _database
        .ref('Groups/${widget.groupId}/expenses')
        .push()
        .set(expense);

    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFDE2E4), // Light pink
      appBar: AppBar(
        title: const Text("Add Expense"),
        backgroundColor: const Color(0xFFB388EB), // Lighter purple
      ),
      body: memberNames.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : Padding(
        padding: const EdgeInsets.all(20.0),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                decoration: const InputDecoration(
                  labelText: "Title",
                  border: OutlineInputBorder(),
                  filled: true,
                  fillColor: Color(0xFFFAD2E1),
                ),
                onChanged: (val) => title = val,
              ),
              const SizedBox(height: 16),
              TextField(
                decoration: const InputDecoration(
                  labelText: "Amount",
                  border: OutlineInputBorder(),
                  filled: true,
                  fillColor: Color(0xFFFAD2E1),
                ),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                onChanged: (val) {
                  // Only allow valid double inputs (digits and at most one dot)
                  if (val.isEmpty || RegExp(r'^\d*\.?\d*$').hasMatch(val)) {
                    amount = val;
                  }
                },
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: paidBy,
                decoration: const InputDecoration(
                  labelText: "Paid By",
                  border: OutlineInputBorder(),
                  filled: true,
                  fillColor: Color(0xFFFAD2E1),
                ),
                items: memberNames.entries.map((entry) {
                  return DropdownMenuItem(
                    value: entry.key,
                    child: Text(entry.value),
                  );
                }).toList(),
                onChanged: (val) {
                  setState(() {
                    paidBy = val ?? currentUserId!;
                  });
                },
              ),
              const SizedBox(height: 16),
              const Text(
                "Split Among:",
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: Color(0xFFB388EB), // Lighter purple
                ),
              ),
              Column(
                children: memberNames.entries.map((entry) {
                  return CheckboxListTile(
                    title: Text(entry.value),
                    activeColor: const Color(0xFFB388EB),
                    value: selectedUsers.contains(entry.key),
                    onChanged: (val) {
                      setState(() {
                        if (val == true) {
                          selectedUsers.add(entry.key);
                        } else {
                          selectedUsers.remove(entry.key);
                        }
                      });
                    },
                  );
                }).toList(),
              ),
              const SizedBox(height: 20),
              Center(
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFB388EB),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 40, vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                  ),
                  onPressed: _addExpense,
                  child: const Text(
                    "Add Expense",
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
