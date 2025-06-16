import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:thinktwice/add_expenses_page.dart';
import 'package:thinktwice/category_chart.dart';
import 'package:thinktwice/expenses_details_page.dart';
import 'package:thinktwice/group_drawer.dart';
import 'package:excel/excel.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'package:intl/intl.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:open_file/open_file.dart';

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
  Map<String, double> spentPerPerson = {};
  String? _selectedUserId;
  Map<String, String> memberImages = {};
  List<MapEntry<String, double>> topSpenders = [];


  String groupCode = '';
  String startDate = '';
  String endDate = '';
  int memberCount = 0;

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
    _calculateSpentPerPerson();

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
        final userProfileSnap =
        await _database.ref('Users/$userId/profile_pic').get();
        final userProfile = userProfileSnap.value?.toString() ?? userId;
        memberImages[userId] = userProfile;
      }
      setState(() {
        groupName = groupSnap.child('groupName').value?.toString() ?? 'Group';
        groupCode = groupSnap.child('groupCode').value?.toString() ?? '';
        startDate = groupSnap.child('startDate').value?.toString() ?? '';
        endDate = groupSnap.child('endDate').value?.toString() ?? '';
      });
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

  void _calculateSpentPerPerson() {
    final expensesRef = _database.ref('Groups/${widget.groupId}/expenses');
    expensesRef.onValue.listen((event) {
      final expensesData = event.snapshot.value as Map<dynamic, dynamic>?;

      Map<String, double> tempSpentPerPerson = {
        for (var userId in memberNames.keys) userId: 0.0,
      };

      List<Map<String, dynamic>> tempExpenses = [];

      if (expensesData != null) {
        expensesData.forEach((key, value) {
          final expense = Map<String, dynamic>.from(value);
          tempExpenses.add(expense);

          final double amount = double.tryParse(expense['amount'].toString()) ?? 0.0;
          final List<dynamic> splitAmong = expense['splitAmong']?.cast<String>() ?? [];
          final bool splitEqually = expense['splitEqually'] ?? true;

          if (splitEqually) {
            final int splitCount = splitAmong.length;
            if (splitCount > 0) {
              final double perPersonAmount = amount / splitCount;
              for (final userId in splitAmong) {
                tempSpentPerPerson[userId] = (tempSpentPerPerson[userId] ?? 0.0) + perPersonAmount;
              }
            }
          } else {
            final manualAmounts = expense['manualAmounts'] as Map<dynamic, dynamic>? ?? {};
            manualAmounts.forEach((userId, value) {
              final double manualAmount = double.tryParse(value.toString()) ?? 0.0;
              tempSpentPerPerson[userId] = (tempSpentPerPerson[userId] ?? 0.0) + manualAmount;
            });
          }
        });
      }

      setState(() {
        spentPerPerson = tempSpentPerPerson;
        expenseHistory = tempExpenses.reversed.toList();


      });
    });
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFDE2E4),
      appBar: AppBar(
        title: Text(groupName),
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
      drawer: GroupDrawer(
        groupName: groupName,
        groupCode: groupCode,
        startDate: startDate,
        endDate: endDate,
        homeCurrency: widget.homeCurrency,
        memberCount: memberNames.length,
        onAddMember: _handleAddMember,
        onChangeGroupName: _handleChangeGroupName,
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildOverviewTab(),
          _buildExpensesTab(),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: const Color(0xFFEC98E1),
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
    List<MapEntry<String, double>> topSpenders = spentPerPerson.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
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
            ElevatedButton.icon(
              icon: const Icon(Icons.download),
              label: const Text("Export Expenses to Excel"),
              onPressed: () => _confirmAndExportExcel(context),
            ),
            const SizedBox(height: 20),
            if (spentPerPerson.isNotEmpty)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 20),
                  const Text(
                    "Total Spending (Pie Chart):",
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF9D4EDD)),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 200,
                    child: PieChart(
                      PieChartData(
                        sections: spentPerPerson.entries.map((entry) {
                          final userName = memberNames[entry.key] ?? 'Unknown';
                          final value = entry.value;
                          final total = spentPerPerson.values.fold(0.0, (a, b) => a + b);
                          final percentage = total > 0 ? (value / total) * 100 : 0;
                          final isSelected = _selectedUserId == entry.key;

                          return PieChartSectionData(
                            title: '$userName\n${percentage.toStringAsFixed(1)}%',
                            value: value,
                            color: _getColorForUser(entry.key),
                            radius: isSelected ? 70 : 60, // Enlarge selected
                            titleStyle: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          );
                        }).toList(),
                        pieTouchData: PieTouchData(
                          touchCallback: (event, response) {
                            if (event.isInterestedForInteractions &&
                                response != null &&
                                response.touchedSection != null) {
                              final touchedIndex = response.touchedSection!.touchedSectionIndex;
                              final touchedEntry = spentPerPerson.entries.elementAt(touchedIndex);
                              setState(() {
                                _selectedUserId = touchedEntry.key;
                              });
                            } else {
                              setState(() {
                                _selectedUserId = null;
                              });
                            }
                          },
                        ),
                      ),
                    ),
                  ),
                  if (_selectedUserId != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Text(
                        '${memberNames[_selectedUserId!] ?? "Unknown"} spent: ${widget.homeCurrency} ${spentPerPerson[_selectedUserId!]!.toStringAsFixed(2)}',
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    ),

                  topSpenders.isNotEmpty
                      ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 20),
                      const Text(
                        "Top Spenders (Podium):",
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF9D4EDD),
                        ),
                      ),
                      const SizedBox(height: 12),

                      if (topSpenders.length < 2)
                        const Text(
                          "Not enough data to display full podium.",
                          style: TextStyle(fontSize: 16, color: Colors.black54),
                        ),

                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          if (topSpenders.length > 1)
                            _buildPodiumPlace(
                              place: 2,
                              userId: topSpenders[1].key,
                              amount: topSpenders[1].value,
                              height: 120,
                              color: Colors.grey,
                            ),
                          _buildPodiumPlace(
                            place: 1,
                            userId: topSpenders[0].key,
                            amount: topSpenders[0].value,
                            height: 160,
                            color: Colors.amber,
                          ),
                          if (topSpenders.length > 2)
                            _buildPodiumPlace(
                              place: 3,
                              userId: topSpenders[2].key,
                              amount: topSpenders[2].value,
                              height: 100,
                              color: Colors.brown,
                            ),
                        ],
                      ),
                    ],
                  )
                      : const Padding(
                    padding: EdgeInsets.symmetric(vertical: 20.0),
                    child: Text(
                      "No spending data available for podium display.",
                      style: TextStyle(fontSize: 16, color: Colors.black54),
                    ),
                  ),

                  CategorySpendingChart(groupId: widget.groupId)
                ],
              ),
          ],
        ),
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
        final expense_id = expense['expense_id']??'';

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
                  groupid:widget.groupId,
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

  Future<void> _confirmAndExportExcel(BuildContext context) async {
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: Text("Export to Excel"),
          content: Text("Do you want to export and download the Excel file?"),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: Text("No"),
            ),
            TextButton(
              onPressed: () async {
                Navigator.of(dialogContext).pop(); // Close dialog
                await _exportExpensesToExcel(context);
              },
              child: Text("Yes"),
            ),
          ],
        );
      },
    );
  }

  Future<void> _exportExpensesToExcel(BuildContext context) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final excel = Excel.createExcel();

      /// ===== Sheet 1: Detailed Expenses ===== ///
      final sheet = excel['Expenses'];
      sheet.appendRow([
        "Date", "Time", "Title", "Amount", "From Currency",
        "Paid By", "Split Among", "Split Equally", "Category"
      ]);

      for (var expense in expenseHistory) {
        var rawTimestamp = expense['timestamp'];
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

        String date = DateFormat('yyyy-MM-dd').format(dateTime);
        String time = DateFormat('HH:mm').format(dateTime);

        final title = expense['title'] ?? '';
        final amount = expense['amount_ori'] ?? 0.0;
        final fromCurrency = expense['fromCurrency'] ?? '';
        final paidById = expense['paidBy'] ?? '';
        final paidBy = memberNames[paidById] ?? paidById;
        final category = expense['category'] ?? '';
        final splitEqually = expense['splitEqually'] ?? true;

        String splitAmong = '';
        if (splitEqually) {
          final List<dynamic> splitList = expense['splitAmong'] ?? [];
          splitAmong = splitList.map((id) => memberNames[id] ?? id).join(', ');
        } else {
          final manualAmounts = Map<String, dynamic>.from(expense['manualAmounts'] ?? {});
          splitAmong = manualAmounts.entries.map((e) {
            final name = memberNames[e.key] ?? e.key;
            return "$name ($fromCurrency ${e.value})";
          }).join(', ');
        }

        sheet.appendRow([
          date,
          time,
          title,
          amount.toString(),
          fromCurrency,
          paidBy,
          splitAmong,
          splitEqually ? "Yes" : "No",
          category
        ]);
      }

      /// ===== Sheet 2: Owed Summary ===== ///
      final owedSheet = excel['Owed Summary'];
      owedSheet.appendRow(["Debtor", "Creditor", "Amount", "Currency"]);

      Map<String, Map<String, double>> debtMap = {};
      Map<String, String> currencyMap = {};

      for (var expense in expenseHistory) {
        final fromCurrency = expense['fromCurrency'] ?? '';
        final splitEqually = expense['splitEqually'] ?? true;
        final paidBy = expense['paidBy'] ?? '';
        final amount = (expense['amount'] ?? 0.0).toDouble();

        if (splitEqually) {
          final List<dynamic> splitList = expense['splitAmong'] ?? [];
          final perPerson = amount / splitList.length;

          for (var userId in splitList) {
            if (userId == paidBy) continue;

            debtMap.putIfAbsent(userId, () => {});
            debtMap[userId]![paidBy] = (debtMap[userId]![paidBy] ?? 0) + perPerson;
            currencyMap["${userId}_$paidBy"] = widget.homeCurrency;
          }
        } else {
          final manualAmounts = Map<String, dynamic>.from(expense['manualAmounts'] ?? {});
          manualAmounts.forEach((userId, amt) {
            if (userId == paidBy) return;

            debtMap.putIfAbsent(userId, () => {});
            final value = (amt is num)
                ? amt.toDouble()
                : double.tryParse(amt.toString()) ?? 0.0;

            debtMap[userId]![paidBy] = (debtMap[userId]![paidBy] ?? 0) + value;
            currencyMap["${userId}_$paidBy"] = widget.homeCurrency;
          });
        }
      }

      debtMap.forEach((debtorId, creditors) {
        final debtorName = memberNames[debtorId] ?? debtorId;
        creditors.forEach((creditorId, amt) {
          final creditorName = memberNames[creditorId] ?? creditorId;
          final currency = currencyMap["${debtorId}_$creditorId"] ?? '';
          owedSheet.appendRow([
            debtorName,
            creditorName,
            amt.toStringAsFixed(2),
            currency
          ]);
        });
      });

      /// ===== Save Excel File ===== ///
      final directory = await getExternalStorageDirectory();
      final path = directory?.path ?? '/storage/emulated/0/Download';
      final fileName = '$path/${groupName}_Expenses.xlsx';
      final file = File(fileName);
      await file.writeAsBytes(excel.encode()!);

      Navigator.of(context).pop(); // Close loader

      // Show success dialog
      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: Text("Export Complete"),
          content: Text("Excel file saved to:\n$fileName"),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text("Close"),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                OpenFile.open(file.path);
              },
              child: Text("Open File"),
            ),
          ],
        ),
      );
    } catch (e) {
      Navigator.of(context).pop(); // Close loader
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Failed to export: $e")),
      );
    }
  }

  void _handleAddMember() {
    TextEditingController _emailController = TextEditingController();

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Add Member"),
        content: TextField(
          controller: _emailController,
          decoration: const InputDecoration(labelText: "Enter member's email"),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () async {
              final email = _emailController.text.trim();
              if (email.isNotEmpty) {
                Navigator.pop(context);
                await _findAndAddUserByEmail(email);
              }
            },
            child: const Text("Add"),
          ),
        ],
      ),
    );
  }

  Future<void> _findAndAddUserByEmail(String email) async {
    final userSnapshot = await _database.ref('Users').get();

    bool found = false;

    if (userSnapshot.exists) {
      for (final child in userSnapshot.children) {
        final userData = child.value as Map?;
        if (userData != null && userData['email'] == email) {
          final userId = child.key!;
          await _addUserToGroup(userId);
          found = true;
          break;
        }
      }
    }

    if (!found && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("User not found")),
      );
    }
  }

  Future<void> _addUserToGroup(String userId) async {
    final groupMemberRef = _database.ref('Groups/${widget.groupId}/members/$userId');
    final memberCountRef = _database.ref('Groups/${widget.groupId}/memberCount');

    try {
      // Add the user to the group members
      await groupMemberRef.set(true);

      // Read the current member count and increment by 1
      final memberCountSnapshot = await memberCountRef.get();
      int currentCount = 0;
      if (memberCountSnapshot.exists) {
        currentCount = int.tryParse(memberCountSnapshot.value.toString()) ?? 0;
      }

      // Update the new member count
      await memberCountRef.set(currentCount + 1);

      // Refresh UI
      await _fetchGroupInfo();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Member added successfully")),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Failed to add member: $e")),
        );
      }
    }
  }


  void _handleChangeGroupName() {
    TextEditingController _nameController = TextEditingController(text: groupName);
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Change Group Name"),
        content: TextField(
          controller: _nameController,
          decoration: const InputDecoration(labelText: "New Group Name"),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () async {
              final newName = _nameController.text.trim();
              if (newName.isNotEmpty) {
                await _database.ref('Groups/${widget.groupId}/groupName').set(newName);
                setState(() {
                  groupName = newName;
                });
                Navigator.pop(context);
              }
            },
            child: const Text("Update"),
          ),
        ],
      ),
    );
  }

  Color _getColorForUser(String userId) {
    final colors = [
      Colors.blueAccent,
      Colors.redAccent,
      Colors.green,
      Colors.purple,
      Colors.orange,
      Colors.teal,
      Colors.pink,
      Colors.brown,
    ];
    return colors[memberNames.keys.toList().indexOf(userId) % colors.length];
  }

  Widget _buildPodiumPlace({
    required int place,
    required String userId,
    required double amount,
    required double height,
    required Color color,
  }) {
    final name = memberNames[userId] ?? "Unknown";
    final imageUrl = memberImages[userId];

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Crown above all if 1st place
        if (place == 1)
          const Icon(
            Icons.emoji_events,
            color: Colors.amber,
            size: 30,
          ),
        const SizedBox(height: 4),

        // Profile image
        if (imageUrl != null)
          CircleAvatar(
            backgroundImage: NetworkImage(imageUrl),
            radius: 24,
          ),
        const SizedBox(height: 6),

        // Place number
        Text(
          "#$place",
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        const SizedBox(height: 6),

        // Bar with name
        Container(
          width: 60,
          height: height,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(8),
          ),
          alignment: Alignment.center,
          padding: const EdgeInsets.all(4),
          child: RotatedBox(
            quarterTurns: -1,
            child: Text(
              name,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),

        const SizedBox(height: 6),

        // Spending amount
        Text(
          "${widget.homeCurrency} ${amount.toStringAsFixed(2)}",
          style: const TextStyle(fontSize: 14),
        ),
      ],
    );
  }
}
