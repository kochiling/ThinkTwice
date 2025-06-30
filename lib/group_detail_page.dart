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
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:thinktwice/group_chat_page.dart';
import 'package:thinktwice/notifications_page.dart';
import 'package:thinktwice/notification_icon_with_badge.dart';

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
  List<Map<String, dynamic>> settlementHistory = [];

  List<String> _generateSettlementSuggestions(
      Map<String, Map<String, double>> debtMap,
      Map<String, String> memberNames,
      String currency,
      ) {
    Map<String, double> netBalance = {};

    debtMap.forEach((debtor, creditors) {
      creditors.forEach((creditor, amount) {
        netBalance[debtor] = (netBalance[debtor] ?? 0) - amount;
        netBalance[creditor] = (netBalance[creditor] ?? 0) + amount;
      });
    });

    final debtors = <String>[];
    final creditors = <String>[];

    netBalance.forEach((user, balance) {
      if (balance < -0.01) debtors.add(user);
      if (balance > 0.01) creditors.add(user);
    });

    List<String> suggestions = [];

    int i = 0, j = 0;
    while (i < debtors.length && j < creditors.length) {
      final d = debtors[i];
      final c = creditors[j];
      final dAmt = -netBalance[d]!;
      final cAmt = netBalance[c]!;

      final pay = dAmt < cAmt ? dAmt : cAmt;
      suggestions.add("${memberNames[d] ?? d} pays ${memberNames[c] ?? c} $currency ${pay.toStringAsFixed(2)}");

      netBalance[d] = netBalance[d]! + pay;
      netBalance[c] = netBalance[c]! - pay;

      if (netBalance[d]!.abs() < 0.01) i++;
      if (netBalance[c]!.abs() < 0.01) j++;
    }

    return suggestions;
  }
  Map<String, double> spentPerPerson = {};
  String? _selectedUserId;
  Map<String, String> memberImages = {};
  List<MapEntry<String, double>> topSpenders = [];
  List<Map<String, dynamic>> reminders = [];


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
    _fetchBalancesExpensesAndSettlements();
    _calculateSpentPerPerson();
    _fetchReminders();

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

  void _fetchBalancesExpensesAndSettlements() async {
    final expensesRef = _database.ref('Groups/${widget.groupId}/expenses');
    final settlementRef = _database.ref('Groups/${widget.groupId}/settlement');

    expensesRef.onValue.listen((event) async {
      final expensesData = event.snapshot.value as Map<dynamic, dynamic>?;
      List<Map<String, dynamic>> tempExpenses = [];
      Map<String, double> tempBalances = {
        for (var userId in memberNames.keys) userId: 0.0,
      };
      //List<Map<String, dynamic>> tempExpenses = [];


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

      // Fetch settlements and update balances
      final settlementSnap = await settlementRef.get();
      List<Map<String, dynamic>> tempSettlements = [];
      if (settlementSnap.exists) {
        final settlementsData = settlementSnap.value as Map<dynamic, dynamic>?;
        if (settlementsData != null) {
          settlementsData.forEach((key, value) {
            final settlement = Map<String, dynamic>.from(value);
            tempSettlements.add(settlement);
            final double amount = double.tryParse(settlement['amount'].toString()) ?? 0.0;
            final String payer = settlement['payer'] ?? '';
            final String payee = settlement['payee'] ?? '';
            // payer pays payee, so payer's balance increases, payee's decreases
            tempBalances[payer] = (tempBalances[payer] ?? 0.0) + amount;
            tempBalances[payee] = (tempBalances[payee] ?? 0.0) - amount;
          });
        }
      }

      setState(() {
        balances = tempBalances;
        expenseHistory = tempExpenses.reversed.toList();
        settlementHistory = tempSettlements;
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
    });  }

  void _fetchReminders() {
    final remindersRef = _database.ref('Groups/${widget.groupId}/reminders');
    remindersRef.onValue.listen((event) {
      final remindersData = event.snapshot.value as Map<dynamic, dynamic>?;
      List<Map<String, dynamic>> tempReminders = [];
      
      if (remindersData != null) {
        remindersData.forEach((key, value) {
          final reminder = Map<String, dynamic>.from(value);
          reminder['id'] = key;
          tempReminders.add(reminder);
        });
        
        // Sort by timestamp, newest first
        tempReminders.sort((a, b) {
          final aTimestamp = a['timestamp'] ?? 0;
          final bTimestamp = b['timestamp'] ?? 0;
          return bTimestamp.compareTo(aTimestamp);
        });
      }
      
      setState(() {
        reminders = tempReminders;
      });
    });
  }

  Future<void> _sendReminder(String debtorId, String creditorId, double amount, String currency) async {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    if (currentUserId == null) return;

    // Only allow creditor to send reminder
    if (currentUserId != creditorId) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("You can only send reminders for money owed to you"),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    try {
      final reminder = {
        'debtorId': debtorId,
        'creditorId': creditorId,
        'amount': amount,
        'currency': currency,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
        'message': 'Reminder: You owe ${memberNames[creditorId]} $currency ${amount.toStringAsFixed(2)}',
        'isRead': false,
        'groupId': widget.groupId,
      };

      await _database.ref('Groups/${widget.groupId}/reminders').push().set(reminder);
      
      // Also add to debtor's personal notifications
      await _database.ref('Users/$debtorId/notifications').push().set({
        'type': 'reminder',
        'groupId': widget.groupId,
        'groupName': groupName,
        'creditorId': creditorId,
        'creditorName': memberNames[creditorId],
        'amount': amount,
        'currency': currency,
        'message': 'Reminder: You owe ${memberNames[creditorId]} $currency ${amount.toStringAsFixed(2)} in $groupName',
        'timestamp': DateTime.now().millisecondsSinceEpoch,
        'isRead': false,
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Reminder sent to ${memberNames[debtorId]}"),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Failed to send reminder: $e"),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(groupName),
        backgroundColor: const Color(0xfffbe5ec),
        //backgroundColor: const Color(0xFFCDB4DB),
        actions: [
          NotificationIconWithBadge(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const NotificationsPage(),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.chat_bubble_outline),
            tooltip: 'Group Chat',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => GroupChatPage(
                    groupId: widget.groupId,
                    currentUserId: FirebaseAuth.instance.currentUser!.uid,
                    currentUsername: memberNames[FirebaseAuth.instance.currentUser!.uid] ?? 'You',
                    currentUserProfile: memberImages[FirebaseAuth.instance.currentUser!.uid] ?? '',
                  ),
                ),
              );
            },
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: Color(0xFFc96077),
          unselectedLabelColor: Color(0xFFc96077).withOpacity(0.7),
          indicatorColor: Color(0xFFc96077),
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
        onExitGroup: _handleExitGroup,
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildOverviewTab(),
          _buildExpensesTab(),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: const Color(0xfffbe5ec),
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
        child: const Icon(Icons.add, color: Color(0xff000000),),
      ),
    );
  }

  Future<void> _confirmAndExportPDF(BuildContext context) async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        build: (context) {
          List<pw.Widget> content = [];

          // ===== GROUP NAME ON TOP =====
          content.add(
            pw.Center(
              child: pw.Text(
                groupName,
                style: pw.TextStyle(
                  fontSize: 16, // slightly larger for group title
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
            ),
          );

          content.add(pw.SizedBox(height: 10));

          // ===== EXPENSES SECTION =====
          content.add(pw.Text("Expenses", style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)));
          content.add(
            pw.Table.fromTextArray(
              cellStyle: pw.TextStyle(fontSize: 9),
              headerStyle: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
              headers: ["Date", "Time", "Title", "Amount", "Currency", "Paid By", "Split Among", "Split", "Category"],
              data: expenseHistory.map((expense) {
                DateTime dateTime;
                var rawTimestamp = expense['timestamp'];

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

                return [
                  date,
                  time,
                  expense['title'] ?? '',
                  amount.toString(),
                  fromCurrency,
                  paidBy,
                  splitAmong,
                  splitEqually ? "Equally" : "Manually",
                  category
                ];
              }).toList(),
            ),
          );

          // ===== OWED SUMMARY SECTION =====
          content.add(pw.SizedBox(height: 20));
          content.add(pw.Text("Owed Summary", style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)));

          List<List<pw.Widget>> owedData = [];
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

          // Prepare owed summary with status (all possible pairs)
          Set<String> allDebtors = {};
          Set<String> allCreditors = {};
          debtMap.forEach((debtor, creditors) {
            allDebtors.add(debtor);
            allCreditors.addAll(creditors.keys);
          });
          // Add all settlements as well
          for (var settlement in settlementHistory) {
            allDebtors.add(settlement['payer']);
            allCreditors.add(settlement['payee']);
          }

          for (var debtorId in allDebtors) {
            for (var creditorId in allCreditors) {
              if (debtorId == creditorId) continue;
              final debtorName = memberNames[debtorId] ?? debtorId;
              final creditorName = memberNames[creditorId] ?? creditorId;
              final currency = currencyMap["${debtorId}_$creditorId"] ?? widget.homeCurrency;
              double amt = debtMap[debtorId]?[creditorId] ?? 0.0;
              // Check if there is a settlement for this pair
              bool isSettled = false;
              for (var settlement in settlementHistory) {
                if (settlement['payer'] == debtorId && settlement['payee'] == creditorId) {
                  double settleAmt = double.tryParse(settlement['amount'].toString()) ?? 0.0;
                  if ((amt - settleAmt).abs() < 0.01 || amt == 0.0) {
                    isSettled = true;
                    break;
                  }
                }
              }
              String statusText = isSettled ? "Done" : "Unsettled";
              final statusWidget = pw.Text(
                statusText,
                style: pw.TextStyle(
                  color: isSettled ? PdfColor.fromInt(0xFF4CAF50) : PdfColor.fromInt(0xFFF44336),
                  fontWeight: pw.FontWeight.bold,
                ),
              );
              if (amt > 0.01 || isSettled) {
                owedData.add([
                  pw.Text(debtorName),
                  pw.Text(creditorName),
                  pw.Text(amt.toStringAsFixed(2)),
                  pw.Text(currency),
                  statusWidget,
                ]);
              }
            }
          }

          content.add(
            pw.Table(
              border: pw.TableBorder.all(),
              children: [
                pw.TableRow(
                  children: [
                    pw.Text("Debtor", style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
                    pw.Text("Creditor", style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
                    pw.Text("Amount", style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
                    pw.Text("Currency", style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
                    pw.Text("Status", style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
                  ],
                ),
                ...owedData.map((row) => pw.TableRow(children: row)),
              ],
            ),
          );

          return content;
        },
      ),
    );

    final output = await getExternalStorageDirectory();
    final file = File("${output!.path}/${groupName}_Expenses.pdf");
    await file.writeAsBytes(await pdf.save());

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text("Export Complete"),
        content: Text("PDF file saved to:\n${file.path}"),
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
  }

  Widget _buildOverviewTab() {
    List<MapEntry<String, double>> topSpenders = spentPerPerson.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    Map<String, Map<String, double>> debtMap = {};
    Map<String, String> currencyMap = {};

    List<Map<String, dynamic>> nonSettlementExpenses =
        expenseHistory.where((e) => e['settlement'] != true).toList();

    for (var expense in nonSettlementExpenses) {
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
          currencyMap["${userId}_$paidBy"] = fromCurrency;
        }
      } else {
        final manualAmounts = Map<String, dynamic>.from(expense['manualAmounts'] ?? {});
        manualAmounts.forEach((userId, amt) {
          if (userId == paidBy) return;
          debtMap.putIfAbsent(userId, () => {});
          final value = (amt is num) ? amt.toDouble() : double.tryParse(amt.toString()) ?? 0.0;
          debtMap[userId]![paidBy] = (debtMap[userId]![paidBy] ?? 0) + value;
          currencyMap["${userId}_$paidBy"] = fromCurrency;
        });
      }
    }

    // Remove debts that have been settled
    for (var settlement in settlementHistory) {
      final payer = settlement['payer'];
      final payee = settlement['payee'];
      final amount = double.tryParse(settlement['amount'].toString()) ?? 0.0;
      if (debtMap[payer] != null && debtMap[payer]![payee] != null) {
        debtMap[payer]![payee] = (debtMap[payer]![payee]! - amount).clamp(0, double.infinity);
        if (debtMap[payer]![payee]! <= 0.01) {
          debtMap[payer]!.remove(payee);
        }
      }
    }

    Map<String, double> netBalance = {};
    debtMap.forEach((debtor, creditors) {
      creditors.forEach((creditor, amount) {
        netBalance[debtor] = (netBalance[debtor] ?? 0) - amount;
        netBalance[creditor] = (netBalance[creditor] ?? 0) + amount;
      });
    });

    memberNames.forEach((userId, _) {
      balances[userId] = netBalance[userId] ?? 0.0;
    });

    List<String> suggestions =
        _generateSettlementSuggestions(debtMap, memberNames, widget.homeCurrency);

    // Redesigned settlement suggestions as vertical cards, no profile icon
    List<Widget> suggestionCards = [];
    for (var s in suggestions) {
      final match = RegExp(r"(.+?) pays (.+?) ([A-Z]{2,4}) (\d+(\.\d+)?)").firstMatch(s);
      if (match != null) {
        final payerName = match.group(1) ?? '';
        final payeeName = match.group(2) ?? '';
        final currency = match.group(3) ?? '';
        final amountStr = match.group(4) ?? '';
        final amount = double.tryParse(amountStr) ?? 0.0;

        final payerId =
            memberNames.entries.firstWhere(
              (e) => e.value == payerName,
              orElse: () => MapEntry(payerName, payerName),
            ).key;
        final payeeId =
            memberNames.entries.firstWhere(
              (e) => e.value == payeeName,
              orElse: () => MapEntry(payeeName, payeeName),
            ).key;

        suggestionCards.add(
          Card(
            margin: const EdgeInsets.symmetric(vertical: 8),
            elevation: 2,
            color: Color(0xffffffff),
            shape: new RoundedRectangleBorder(
                side: new BorderSide(color: Colors.black12, width: 0.5),
                borderRadius: BorderRadius.circular(8.0)),
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              child: Row(
                children: [
                  // Removed CircleAvatar
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "$payerName → $payeeName",
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          "$currency $amountStr",
                          style: const TextStyle(fontSize: 15, color: Color(0xFFc96077),fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                  // Reminder button (only show if current user is the creditor)
                  if (FirebaseAuth.instance.currentUser?.uid == payeeId) ...[
                    IconButton(
                      icon: const Icon(Icons.notifications, color: Colors.orange),
                      onPressed: () async {
                        await _sendReminder(payerId, payeeId, amount, currency);
                      },
                      tooltip: "Send Reminder",
                    ),
                    const SizedBox(width: 8),
                  ],
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Color(0xfffbe5ec), // Button background color
                      foregroundColor: Colors.black87,
                      //side: BorderSide(color: Color(0x74ec98e1), width: 2), // Border color and width// Text (and icon) color
                    ),
                    onPressed: () async {
                      bool confirmed = await showDialog(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          title: const Text("Confirm Settlement"),
                          content: Text("Are you sure $payerName paid $payeeName $currency $amountStr?"),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(ctx, false),
                              child: const Text("Cancel"),
                            ),
                            TextButton(
                              onPressed: () => Navigator.pop(ctx, true),
                              child: const Text("OK"),
                            ),
                          ],
                        ),
                      );
                      if (!confirmed) return;
                      final newSettlement = {
                        'payer': payerId,
                        'payee': payeeId,
                        'amount': amount,
                        'currency': currency,
                        'timestamp': DateTime.now().millisecondsSinceEpoch,
                      };
                      final groupRef = FirebaseDatabase.instance
                          .ref('Groups/${widget.groupId}');
                      await groupRef.child('settlement').push().set(newSettlement);
                      
                      // Remove related reminder notifications
                      await _removeRelatedReminders(payerId, payeeId, amount);
                      
                      await _fetchExpensesAndSetState();
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text("Settlement recorded successfully"),
                          backgroundColor: Colors.green,
                        ),
                      );
                    },
                    child: const Text("Done"),
                  ),
                ],
              ),
            ),
          ),
        );
      }
    }

    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Balances:",
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF9D4EDD),
              ),
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
            const SizedBox(height: 16),
            if (suggestionCards.isNotEmpty) ...[
              const Text(
                "Settle Up Suggestions:",
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF9D4EDD), // Match Balances title color
                ),
              ),
              const SizedBox(height: 8),
              ...suggestionCards,
            ],
            const SizedBox(height: 16),
            // Reminders section
            if (reminders.isNotEmpty) ...[
              const Text(
                "Recent Reminders:",
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF9D4EDD),
                ),
              ),
              const SizedBox(height: 8),
              ...reminders.take(3).map((reminder) {
                final debtorName = memberNames[reminder['debtorId']] ?? 'Unknown';
                final creditorName = memberNames[reminder['creditorId']] ?? 'Unknown';
                final amount = reminder['amount']?.toStringAsFixed(2) ?? '0.00';
                final currency = reminder['currency'] ?? '';
                final timestamp = reminder['timestamp'] ?? 0;
                final date = DateTime.fromMillisecondsSinceEpoch(timestamp);
                final timeAgo = _formatTimeAgo(date);
                
                return Card(
                  margin: const EdgeInsets.symmetric(vertical: 4),
                  child: ListTile(
                    leading: const Icon(Icons.notifications, color: Colors.orange),
                    title: Text("$creditorName reminded $debtorName"),
                    subtitle: Text("$currency $amount • $timeAgo"),
                    dense: true,
                  ),
                );
              }).toList(),
              const SizedBox(height: 8),
            ],
            const SizedBox(height: 16),
            ElevatedButton.icon(
              icon: const Icon(Icons.download),
              label: const Text("Export Expenses to Excel"),
              onPressed: () => _confirmAndExportExcel(context),
              // style: ElevatedButton.styleFrom(
              //   //backgroundColor: Colors.transparent,
              //   foregroundColor: Colors.white,
              //   //shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              // ),
            ),
            ElevatedButton.icon(
              icon: const Icon(Icons.download),
              label: const Text("Export Expenses to PDF"),
              onPressed: () => _confirmAndExportPDF(context),
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
          leading: Icon(icon, color: Color(0xFFF184E3)),
          title: Text(title),
          subtitle: Text("Paid by $paidBy\n$splitDescription"),
          isThreeLine: true,
          trailing: Text(
            formattedAmount,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              color: Color(0xFFEC98E1),
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

  Future<void> _fetchExpensesAndSetState() async {
    try {
      final snapshot = await FirebaseDatabase.instance
          .ref('Groups/${widget.groupId}/expenses')
          .get();
      final settlementSnap = await FirebaseDatabase.instance
          .ref('Groups/${widget.groupId}/settlement')
          .get();

      List<Map<String, dynamic>> updatedExpenses = [];
      if (snapshot.exists) {
        final data = snapshot.value as Map<dynamic, dynamic>;
        data.forEach((key, value) {
          if (value is Map<dynamic, dynamic>) {
            updatedExpenses.add(Map<String, dynamic>.from(value));
          }
        });
        updatedExpenses.sort((a, b) {
          final aTimestamp = a['timestamp'] ?? 0;
          final bTimestamp = b['timestamp'] ?? 0;
          return aTimestamp.compareTo(bTimestamp);
        });
      }
      List<Map<String, dynamic>> updatedSettlements = [];
      if (settlementSnap.exists) {
        final data = settlementSnap.value as Map<dynamic, dynamic>;
        data.forEach((key, value) {
          if (value is Map<dynamic, dynamic>) {
            updatedSettlements.add(Map<String, dynamic>.from(value));
          }
        });
      }
      setState(() {
        expenseHistory = updatedExpenses;
        settlementHistory = updatedSettlements;
      });
    } catch (e) {
      print("Error fetching expenses/settlements: $e");
      setState(() {
        expenseHistory = [];
        settlementHistory = [];
      });
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

  Future<void> _removeRelatedReminders(String payerId, String payeeId, double settlementAmount) async {
    try {
      // Remove from debtor's personal notifications
      final debtorNotificationsRef = _database.ref('Users/$payerId/notifications');
      final debtorNotificationsSnap = await debtorNotificationsRef.get();
      
      if (debtorNotificationsSnap.exists) {
        final notificationsData = debtorNotificationsSnap.value as Map<dynamic, dynamic>;
        for (var entry in notificationsData.entries) {
          final notificationKey = entry.key;
          final notification = Map<String, dynamic>.from(entry.value);
          
          // Check if this is a reminder from the creditor about this debt
          if (notification['type'] == 'reminder' &&
              notification['creditorId'] == payeeId &&
              notification['groupId'] == widget.groupId) {
            final reminderAmount = notification['amount']?.toDouble() ?? 0.0;
            
            // Remove if settlement covers the reminder amount
            if (settlementAmount >= reminderAmount) {
              await debtorNotificationsRef.child(notificationKey).remove();
            }
          }
        }
      }
      
      // Remove from group reminders
      final groupRemindersRef = _database.ref('Groups/${widget.groupId}/reminders');
      final groupRemindersSnap = await groupRemindersRef.get();
      
      if (groupRemindersSnap.exists) {
        final remindersData = groupRemindersSnap.value as Map<dynamic, dynamic>;
        for (var entry in remindersData.entries) {
          final reminderKey = entry.key;
          final reminder = Map<String, dynamic>.from(entry.value);
          
          if (reminder['debtorId'] == payerId &&
              reminder['creditorId'] == payeeId) {
            final reminderAmount = reminder['amount']?.toDouble() ?? 0.0;
            
            // Remove if settlement covers the reminder amount
            if (settlementAmount >= reminderAmount) {
              await groupRemindersRef.child(reminderKey).remove();
            }
          }
        }
      }
    } catch (e) {
      print("Error removing related reminders: $e");
    }
  }

  String _formatTimeAgo(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);
    
    if (difference.inDays > 0) {
      return '${difference.inDays}d ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m ago';
    } else {
      return 'Just now';
    }
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

  void _handleExitGroup() async {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    if (currentUserId == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Exit Group'),
        content: const Text('Are you sure you want to exit this group?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Yes'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      final groupRef = _database.ref('Groups/${widget.groupId}');
      final memberRef = groupRef.child('members/$currentUserId');
      final memberCountRef = groupRef.child('memberCount');
      // Remove user from members
      await memberRef.remove();
      // Decrement memberCount
      final memberCountSnap = await memberCountRef.get();
      int memberCount = 0;
      if (memberCountSnap.exists) {
        memberCount = int.tryParse(memberCountSnap.value.toString()) ?? 0;
      }
      await memberCountRef.set(memberCount > 0 ? memberCount - 1 : 0);
      if (mounted) {
        Navigator.of(context).pop(); // Close drawer
        Navigator.of(context).pop(); // Go back to previous screen
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('You have exited the group.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to exit group: $e')),
        );
      }
    }
  }
}