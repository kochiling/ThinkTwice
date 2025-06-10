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
  bool splitEqually = true;
  Map<String, String> manualAmounts = {}; // userId -> amount string

  String selectedCategory = '';
  String otherCategory = '';

  final List<Map<String, dynamic>> categories = [
    {'icon': Icons.fastfood, 'label': 'Food'},
    {'icon': Icons.local_cafe, 'label': 'Cafe'},
    {'icon': Icons.directions_bus, 'label': 'Transport'},
    {'icon': Icons.local_mall, 'label': 'Shopping'},
    {'icon': Icons.home, 'label': 'Rent'},
    {'icon': Icons.movie, 'label': 'Entertainment'},
    {'icon': Icons.hotel, 'label': 'Accommodation'},
    {'icon': Icons.flight, 'label': 'Flight'},
    {'icon': Icons.medical_services, 'label': 'Medical'},
    {'icon': Icons.school, 'label': 'Education'},
    {'icon': Icons.sports_soccer, 'label': 'Sports'},
    {'icon': Icons.nightlife, 'label': 'Nightlife'},
    {'icon': Icons.pets, 'label': 'Pet'},
    {'icon': Icons.phone_android, 'label': 'Phone/Internet'},
    {'icon': Icons.receipt_long, 'label': 'Bills'},
    {'icon': Icons.celebration, 'label': 'Gifts'},
    {'icon': Icons.handshake, 'label': 'Donations'},
    {'icon': Icons.more_horiz, 'label': 'Others'},
  ];


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

    if (selectedCategory.isEmpty || (selectedCategory == 'Others' && otherCategory.trim().isEmpty)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please select or enter a category.")),
      );
      return;
    }

    double? totalAmount = double.tryParse(amount);
    if (totalAmount == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Invalid total amount.")),
      );
      return;
    }

    if (!splitEqually) {
      double manualTotal = 0;
      for (String userId in selectedUsers) {
        double? userAmount = double.tryParse(manualAmounts[userId] ?? '');
        if (userAmount == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Invalid amount for \${memberNames[userId] ?? userId}")),
          );
          return;
        }
        manualTotal += userAmount;
      }

      if ((manualTotal - totalAmount).abs() > 0.01) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Manual amounts must add up to correct total")),
        );
        return;
      }
    }

    final expense = {
      'title': title.trim(),
      'amount': totalAmount,
      'paidBy': paidBy,
      'splitAmong': selectedUsers,
      'splitEqually': splitEqually,
      'manualAmounts': splitEqually ? null : manualAmounts,
      'timestamp': ServerValue.timestamp,
      'category': selectedCategory == 'Others' ? otherCategory.trim() : selectedCategory,
    };

    await _database.ref('Groups/${widget.groupId}/expenses').push().set(expense);

    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFDE2E4),
      appBar: AppBar(
        title: const Text("Add Expense"),
        backgroundColor: const Color(0xFFB388EB),
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
                  if (val.isEmpty || RegExp(r'^\d*\.?\d*$').hasMatch(val)) {
                    amount = val;
                  }
                },
              ),
              const SizedBox(height: 16),
              const Text("Category:", style: TextStyle(fontWeight: FontWeight.bold)),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: categories.map((cat) {
                  final label = cat['label'] as String;
                  final icon = cat['icon'] as IconData;
                  final isSelected = selectedCategory == label;
                  return GestureDetector(
                    onTap: () {
                      setState(() {
                        selectedCategory = label;
                        otherCategory = '';
                      });
                    },
                    child: Column(
                      children: [
                        CircleAvatar(
                          backgroundColor: isSelected ? Color(0xFFB388EB) : Colors.grey[300],
                          child: Icon(icon, color: Colors.white),
                        ),
                        const SizedBox(height: 4),
                        Text(label),
                      ],
                    ),
                  );
                }).toList(),
              ),
              if (selectedCategory == 'Others')
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: TextField(
                    decoration: const InputDecoration(
                      labelText: "Enter category",
                      border: OutlineInputBorder(),
                      filled: true,
                      fillColor: Color(0xFFFAD2E1),
                    ),
                    onChanged: (val) => otherCategory = val,
                  ),
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
              Row(
                children: [
                  const Text("Split Type:", style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Row(
                      children: [
                        Radio<bool>(
                          value: true,
                          groupValue: splitEqually,
                          onChanged: (val) => setState(() => splitEqually = val!),
                        ),
                        const Text("Equally"),
                        Radio<bool>(
                          value: false,
                          groupValue: splitEqually,
                          onChanged: (val) => setState(() => splitEqually = val!),
                        ),
                        const Text("Manually"),
                      ],
                    ),
                  )
                ],
              ),
              const SizedBox(height: 10),
              const Text(
                "Split Among:",
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: Color(0xFFB388EB),
                ),
              ),
              Column(
                children: memberNames.entries.map((entry) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      CheckboxListTile(
                        title: Text(entry.value),
                        activeColor: const Color(0xFFB388EB),
                        value: selectedUsers.contains(entry.key),
                        onChanged: (val) {
                          setState(() {
                            if (val == true) {
                              selectedUsers.add(entry.key);
                            } else {
                              selectedUsers.remove(entry.key);
                              manualAmounts.remove(entry.key);
                            }
                          });
                        },
                      ),
                      if (!splitEqually && selectedUsers.contains(entry.key))
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 5),
                          child: TextField(
                            decoration: InputDecoration(
                              labelText: "\${entry.value}'s share",
                              border: const OutlineInputBorder(),
                              filled: true,
                              fillColor: const Color(0xFFFAD2E1),
                            ),
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            onChanged: (val) {
                              setState(() {
                                manualAmounts[entry.key] = val;
                              });
                            },
                          ),
                        )
                    ],
                  );
                }).toList(),
              ),
              const SizedBox(height: 20),
              Center(
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFB388EB),
                    padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 12),
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