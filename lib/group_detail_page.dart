import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:thinktwice/add_expenses_page.dart';
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(groupName),
        backgroundColor: const Color(0xfffbe5ec),
        bottom: TabBar(
          controller: _tabController,
          labelColor: Color(0xFFc96077),
          unselectedLabelColor: Color(0xFFc96077).withOpacity(0.5),
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
        child: const Icon(Icons.add),
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
            memberNames.entries.firstWhere((e) => e.value == payerName).key;
        final payeeId =
            memberNames.entries.firstWhere((e) => e.value == payeeName).key;

        suggestionCards.add(
          Card(
            margin: const EdgeInsets.symmetric(vertical: 8),
            elevation: 2,
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
                          style: const TextStyle(fontSize: 15, color: Color(0xFFc96077)),
                        ),
                      ],
                    ),
                  ),
                  ElevatedButton(
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
            ElevatedButton.icon(
              icon: const Icon(Icons.download),
              label: const Text("Export Expenses to Excel"),
              onPressed: () => _confirmAndExportExcel(context),
            ),
            ElevatedButton.icon(
              icon: const Icon(Icons.download),
              label: const Text("Export Expenses to PDF"),
              onPressed: () => _confirmAndExportPDF(context),
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

}
