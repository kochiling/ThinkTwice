import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class ExpenseDetailsPage extends StatefulWidget {
  final String groupid;
  final Map<String, dynamic> expense;
  final Map<String, String> memberNames;
  final String homeCurrency;

  const ExpenseDetailsPage({
    Key? key,
    required this.groupid,
    required this.expense,
    required this.memberNames,
    required this.homeCurrency,
  }) : super(key: key);

  @override
  State<ExpenseDetailsPage> createState() => _ExpenseDetailsPageState();
}

class _ExpenseDetailsPageState extends State<ExpenseDetailsPage> {
  bool isEditing = false;
  late Map<String, TextEditingController> _controllers;
  late TextEditingController _amountOriController;
  late TextEditingController _rateController;
  late String selectedPaidBy;


  @override
  void initState() {
    super.initState();

    selectedPaidBy = widget.expense['paidBy'] ?? '';
    _amountOriController = TextEditingController(
      text: widget.expense['amount_ori'].toString(),
    );
    _rateController = TextEditingController(
      text: widget.expense['rate'].toString(),
    );

    _controllers = {};
    if (!(widget.expense['splitEqually'] ?? true)) {
      final manualAmounts = Map<String, dynamic>.from(widget.expense['manualAmounts'] ?? {});
      manualAmounts.forEach((key, value) {
        _controllers[key] = TextEditingController(text: value.toString());
      });
    }
  }

  @override
  void dispose() {
    _amountOriController.dispose();
    _rateController.dispose();
    _controllers.values.forEach((controller) => controller.dispose());
    super.dispose();
  }

  void _editExpenses() {
    setState(() {
      isEditing = !isEditing;
    });
  }

  void _saveEdits() async {
    final updatedManualAmounts = <String, double>{};
    _controllers.forEach((key, controller) {
      final value = double.tryParse(controller.text.trim());
      if (value != null) {
        updatedManualAmounts[key] = value;
      }
    });

    final updatedAmountOri = double.tryParse(_amountOriController.text.trim()) ?? 0.0;
    final updatedRate = double.tryParse(_rateController.text.trim()) ?? 1.0;
    final updatedAmount = updatedAmountOri * updatedRate;

    final groupId = widget.groupid;
    final expenseId = widget.expense['expense_id']; // Must be saved in Firebase when first created

    if (expenseId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Expense ID is missing')),
      );
      return;
    }

    final expenseRef = FirebaseDatabase.instance
        .ref()
        .child('Groups')
        .child(groupId)
        .child('expenses')
        .child(expenseId);

    final updateData = {
      'paidBy': selectedPaidBy,
      'amount_ori': updatedAmountOri,
      'rate': updatedRate,
      'amount': updatedAmount,
      'manualAmounts': updatedManualAmounts,
    };

    try {
      await expenseRef.update(updateData);

      setState(() {
        isEditing = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Expense updated successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update expense: $e')),
        );
      }
    }
  }

  void _deleteExpense() async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Delete'),
        content: const Text('Are you sure you want to delete this expense?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('No'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Yes'),
          ),
        ],
      ),
    );

    if (shouldDelete == true) {
      try {
        final groupId = widget.groupid;
        final expenseId = widget.expense['expense_id'];
        final expenseRef = FirebaseDatabase.instance
            .ref()
            .child('Groups')
            .child(groupId)
            .child('expenses')
            .child(expenseId);

        await expenseRef.remove();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Expense deleted successfully')),
          );
        }

        Navigator.pop(context); // Go back after deletion
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to delete expense: $e')),
        );
      }
    }
  }


  @override
  Widget build(BuildContext context) {
    final title = widget.expense['title'] ?? 'Untitled';
    final amount = double.tryParse(widget.expense['amount'].toString()) ?? 0.0;
    final amountOri = double.tryParse(widget.expense['amount_ori'].toString()) ?? amount;
    final fromCurrency = widget.expense['fromCurrency'] ?? '';
    final rate = widget.expense['rate'] ?? 1;
    final category = widget.expense['category'] ?? 'Others';
    final paidById = widget.expense['paidBy'] ?? '';
    final paidBy = widget.memberNames[paidById] ?? paidById;
    final splitEqually = widget.expense['splitEqually'] ?? true;
    final rawTimestamp = widget.expense['timestamp'];
    DateTime dateTime;
    if (rawTimestamp is int) {
      dateTime = rawTimestamp < 10000000000
          ? DateTime.fromMillisecondsSinceEpoch(rawTimestamp * 1000)
          : DateTime.fromMillisecondsSinceEpoch(rawTimestamp);
    } else if (rawTimestamp is String) {
      dateTime = DateTime.tryParse(rawTimestamp) ?? DateTime.now();
    } else {
      dateTime = DateTime.now();
    }


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

    final matchedCategory = categories.firstWhere(
          (element) => element['label'] == category,
      orElse: () => {'icon': Icons.monetization_on_outlined},
    );

    final IconData icon = matchedCategory['icon'];

    return SafeArea(
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: Color(0xFFE991AA),
          actions: [
            IconButton(
              icon: Icon(Icons.delete, color: Colors.white),
              onPressed: _deleteExpense,
            ),
            IconButton(
              icon: Icon(isEditing ? Icons.save : Icons.edit, color: Colors.white),
              onPressed: isEditing ? _saveEdits : _editExpenses,
            ),
          ],
        ),
        body: SingleChildScrollView(
          padding: EdgeInsets.zero,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                color: Color(0xFFE991AA),
                padding: EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: Colors.white,
                      radius: 35,
                      child: Icon(icon, color: Color(0xFFEC98E1), size: 40),
                    ),
                    SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: TextStyle(fontSize: 18, color: Colors.white),
                          ),
                          Text(
                            DateFormat('yyyy-MM-dd HH:mm').format(dateTime),
                            style: TextStyle(fontSize: 13, color: Colors.white70),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 20,),
              Container(
                color: Color(0xFFFFFFFF),
                padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 20.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      "Category",
                      style: const TextStyle(fontSize: 15, color: Colors.black),
                    ),
                    Text(
                      category,
                      style: const TextStyle(fontSize: 15, color: Colors.black, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 10,),
              // Paid By Dropdown
              _infoRowWidget(
                "Paid By",
                isEditing
                    ? DropdownButton<String>(
                  value: selectedPaidBy,
                  onChanged: (newValue) {
                    setState(() {
                      selectedPaidBy = newValue!;
                    });
                  },
                  items: widget.memberNames.entries.map((entry) {
                    return DropdownMenuItem(
                      value: entry.key,
                      child: Text(entry.value),
                    );
                  }).toList(),
                )
                    : Text(widget.memberNames[selectedPaidBy] ?? selectedPaidBy),
              ),

// Editable amount_ori
              _infoRowWidget(
                "Amount (original):",
                isEditing
                    ? SizedBox(
                  width: 100,
                  child: TextField(
                    controller: _amountOriController,
                    keyboardType: TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(border: OutlineInputBorder(), isDense: true),
                  ),
                )
                    : Text("$fromCurrency ${amountOri.toStringAsFixed(2)}"),
              ),
              _infoRow("Amount (converted):", "${widget.homeCurrency} ${amount.toStringAsFixed(2)}"),
              // Editable rate
              _infoRowWidget(
                "Rate Used:",
                isEditing
                    ? SizedBox(
                  width: 100,
                  child: TextField(
                    controller: _rateController,
                    keyboardType: TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(border: OutlineInputBorder(), isDense: true),
                  ),
                )
                    : Text("$rate"),
              ),

              SizedBox(height: 10),
              Material(
                elevation: 4,
                shadowColor: Colors.grey.withOpacity(0.3),
                child: Container(
                  color: Colors.white,
                  padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 20.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Split Details:",
                        style: TextStyle(fontSize: 16, color: Colors.black87),
                      ),
                      SizedBox(height: 8),
                      ..._buildSplitDetails(splitEqually, fromCurrency),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Container(
      color: Colors.white,
      padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 20.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: 15, color: Colors.black)),
          Text(value, style: TextStyle(fontSize: 15, color: Colors.black, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _infoRowWidget(String label, Widget valueWidget) {
    return Container(
      color: Colors.white,
      padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 20.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: 15, color: Colors.black)),
          DefaultTextStyle.merge(
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.black),
            child: valueWidget,
          ),
        ],
      ),
    );
  }

  List<Widget> _buildSplitDetails(bool splitEqually, String currency) {
    if (splitEqually) {
      final List<dynamic> splitAmong = widget.expense['splitAmong'] ?? [];
      final share = (double.tryParse(widget.expense['amount_ori'].toString()) ?? 0.0) / splitAmong.length;

      return splitAmong.map((id) {
        final name = widget.memberNames[id] ?? id;
        return _splitRow(name, "$currency ${share.toStringAsFixed(2)}");
      }).toList();
    } else {
      final manualAmounts = Map<String, dynamic>.from(widget.expense['manualAmounts'] ?? {});
      return manualAmounts.entries.map((entry) {
        final name = widget.memberNames[entry.key] ?? entry.key;
        final controller = _controllers[entry.key]!;
        return Row(
          children: [
            Expanded(
              flex: 2,
              child: Text(
                name,
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
              ),
            ),
            Expanded(
              flex: 1,
              child: isEditing
                  ? TextField(
                controller: controller,
                keyboardType: TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  contentPadding: EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                  border: OutlineInputBorder(),
                ),
              )
                  : Text(
                "$currency ${double.tryParse(entry.value.toString())?.toStringAsFixed(2) ?? '0.00'}",
                textAlign: TextAlign.right,
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        );
      }).toList();
    }
  }

  Widget _splitRow(String name, String amount) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Text(
              name,
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(
            flex: 1,
            child: Text(
              amount,
              textAlign: TextAlign.right,
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }
}

