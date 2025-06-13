import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_database/ui/firebase_animated_list.dart';
import 'package:flutter/material.dart';
import 'update_record.dart';

class FetchData extends StatefulWidget {
  const FetchData({Key? key}) : super(key: key);

  @override
  State<FetchData> createState() => _FetchDataState();
}

class _FetchDataState extends State<FetchData> {

  Query dbRef = FirebaseDatabase.instance.ref().child('Students');
  DatabaseReference reference = FirebaseDatabase.instance.ref().child('Students');

  Widget listItem({required Map student}) {
    return Container(
      margin: const EdgeInsets.all(10),
      padding: const EdgeInsets.all(10),
      height: 140,
      color: Colors.amberAccent,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            student['name'],
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w400),
          ),
          const SizedBox(
            height: 5,
          ),
          Text(
            student['age'],
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w400),
          ),
          const SizedBox(
            height: 5,
          ),
          Text(
            student['salary'],
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w400),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              GestureDetector(
                onTap: () {
                  Navigator.push(context, MaterialPageRoute(builder: (_) => UpdateRecord(studentKey: student['key'])));
                },
                child: Row(
                  children: [
                    Icon(
                      Icons.edit,
                      color: Theme.of(context).primaryColor,
                    ),
                  ],
                ),
              ),
              const SizedBox(
                width: 6,
              ),
              GestureDetector(
                onTap: () {
                  reference.child(student['key']).remove();
                },
                child: Row(
                  children: [
                    Icon(
                      Icons.delete,
                      color: Colors.red[700],
                    ),
                  ],
                ),
              ),
            ],
          )
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          title: const Text('Fetching data'),
        ),
        body: Container(
          height: double.infinity,
          child: FirebaseAnimatedList(
            query: dbRef,
            itemBuilder: (BuildContext context, DataSnapshot snapshot, Animation<double> animation, int index) {

              Map student = snapshot.value as Map;
              student['key'] = snapshot.key;

              return listItem(student: student);

            },
          ),
        )
    );
  }
}

// Future<void> _exportExpensesToExcel() async {
//
//   final excel = Excel.createExcel();
//   final sheet = excel['Expenses'];
//
//   // Add header row
//   sheet.appendRow([
//     "Date", "Time", "Title", "Amount", "From Currency", "Paid By", "Split Among", "Split Equally", "Category"
//   ]);
//
//   for (var expense in expenseHistory) {
//     var rawTimestamp = expense['timestamp']; // or however you're accessing it
//     DateTime dateTime;
//
//     if (rawTimestamp is int) {
//       // Detect whether the timestamp is in seconds or milliseconds
//       if (rawTimestamp < 10000000000) {
//         // likely in seconds
//         dateTime = DateTime.fromMillisecondsSinceEpoch(rawTimestamp * 1000);
//       } else {
//         // likely in milliseconds
//         dateTime = DateTime.fromMillisecondsSinceEpoch(rawTimestamp);
//       }
//     } else if (rawTimestamp is String) {
//       dateTime = DateTime.tryParse(rawTimestamp) ?? DateTime.now();
//     } else {
//       dateTime = DateTime.now(); // fallback
//     }
//     String date = DateFormat('yyyy-MM-dd').format(dateTime);
//     String time = DateFormat('HH:mm').format(dateTime);
//
//     final title = expense['title'] ?? '';
//     final amount = expense['amount_ori'] ?? 0.0;
//     final fromCurrency = expense['fromCurrency'] ?? '';
//     final paidById = expense['paidBy'] ?? '';
//     final paidBy = memberNames[paidById] ?? paidById;
//     final category = expense['category'] ?? '';
//     final splitEqually = expense['splitEqually'] ?? true;
//     String splitAmong = '';
//
//     if (splitEqually) {
//       final List<dynamic> splitList = expense['splitAmong'] ?? [];
//       splitAmong = splitList.map((id) => memberNames[id] ?? id).join(', ');
//     } else {
//       final manualAmounts = Map<String, dynamic>.from(expense['manualAmounts'] ?? {});
//       splitAmong = manualAmounts.entries.map((e) {
//         final name = memberNames[e.key] ?? e.key;
//         final value = e.value.toString();
//         return "$name ($fromCurrency $value)";
//       }).join(', ');
//     }
//
//     sheet.appendRow([
//       date,
//       time,
//       title,
//       amount.toString(),
//       fromCurrency,
//       paidBy,
//       splitAmong,
//       splitEqually ? "Yes" : "No",
//       category
//     ]);
//   }
//
//   final directory = await getExternalStorageDirectory();
//   final path = directory!.path;
//   final fileName = '$path/${groupName}_Expenses.xlsx';
//   final fileBytes = excel.encode();
//   final file = File(fileName);
//   await file.writeAsBytes(fileBytes!);
//
//
//   ScaffoldMessenger.of(context).showSnackBar(
//     SnackBar(content: Text("Expenses exported to $fileName")),
//   );
// }

// import 'package:flutter/material.dart';
//
// class ExpenseDetailsPage extends StatefulWidget {
//   final Map<String, dynamic> expense;
//   final Map<String, String> memberNames;
//   final String homeCurrency;
//
//   const ExpenseDetailsPage({
//     Key? key,
//     required this.expense,
//     required this.memberNames,
//     required this.homeCurrency,
//   }) : super(key: key);
//
//   @override
//   State<ExpenseDetailsPage> createState() => _ExpenseDetailsPageState();
// }
//
// class _ExpenseDetailsPageState extends State<ExpenseDetailsPage> {
//   @override
//   Widget build(BuildContext context) {
//     final title = widget.expense['title'] ?? 'Untitled';
//     final amount = double.tryParse(widget.expense['amount'].toString()) ?? 0.0;
//     final amountOri = double.tryParse(widget.expense['amount_ori'].toString()) ?? amount;
//     final fromCurrency = widget.expense['fromCurrency'] ?? '';
//     final rate = widget.expense['rate'] ?? 1;
//     final category = widget.expense['category'] ?? 'Others';
//     final paidById = widget.expense['paidBy'] ?? '';
//     final paidBy = widget.memberNames[paidById] ?? paidById;
//     final splitEqually = widget.expense['splitEqually'] ?? true;
//
//     String splitDetails;
//     if (splitEqually) {
//       final List<dynamic> splitAmong = widget.expense['splitAmong'] ?? [];
//       splitDetails = splitAmong.map((id) {
//         final name = widget.memberNames[id] ?? id;
//         final share = (amountOri / splitAmong.length).toStringAsFixed(2);
//         return "$name: $fromCurrency $share";
//       }).join('\n');
//     } else {
//       final manualAmounts = Map<String, dynamic>.from(widget.expense['manualAmounts_ori'] ?? {});
//       splitDetails = manualAmounts.entries.map((e) {
//         final name = widget.memberNames[e.key] ?? e.key;
//         final value = double.tryParse(e.value.toString())?.toStringAsFixed(2) ?? '0.00';
//         return "$name: $fromCurrency $value";
//       }).join('\n');
//     }
//
//     final List<Map<String, dynamic>> categories = [
//       {'icon': Icons.fastfood, 'label': 'Food'},
//       {'icon': Icons.local_cafe, 'label': 'Cafe'},
//       {'icon': Icons.directions_bus, 'label': 'Transport'},
//       {'icon': Icons.local_mall, 'label': 'Shopping'},
//       {'icon': Icons.home, 'label': 'Rent'},
//       {'icon': Icons.movie, 'label': 'Entertainment'},
//       {'icon': Icons.hotel, 'label': 'Accommodation'},
//       {'icon': Icons.flight, 'label': 'Flight'},
//       {'icon': Icons.medical_services, 'label': 'Medical'},
//       {'icon': Icons.school, 'label': 'Education'},
//       {'icon': Icons.sports_soccer, 'label': 'Sports'},
//       {'icon': Icons.nightlife, 'label': 'Nightlife'},
//       {'icon': Icons.pets, 'label': 'Pet'},
//       {'icon': Icons.phone_android, 'label': 'Phone/Internet'},
//       {'icon': Icons.receipt_long, 'label': 'Bills'},
//       {'icon': Icons.celebration, 'label': 'Gifts'},
//       {'icon': Icons.handshake, 'label': 'Donations'},
//       {'icon': Icons.more_horiz, 'label': 'Others'},
//     ];
//
//     final matchedCategory = categories.firstWhere(
//           (element) => element['label'] == category,
//       orElse: () => {'icon': Icons.monetization_on_outlined}, // default
//     );
//
//     final IconData icon = matchedCategory['icon'];
//
//     void editExpenses(){
//
//
//     }
//
//     return SafeArea(
//       child: Scaffold(
//         appBar: AppBar(
//           actions: [
//             TextButton.icon(
//               onPressed: editExpenses,
//               icon: Icon(Icons.edit, color: Color(0xFFFFFFFF)),
//               label: Text("Edit", style: TextStyle(color: Color(0xFFFFFFFF))),
//             )
//           ],
//           backgroundColor: Color(0xFFE991AA),
//         ),
//         body: SingleChildScrollView(
//           child: Padding(
//             padding: const EdgeInsets.only(left: 0, right: 0),
//             child: Column(
//               crossAxisAlignment: CrossAxisAlignment.start,
//               children: [
//                 Container(
//                   color: Color(0xFFE991AA),
//                   padding: EdgeInsets.only(left: 16.0, right: 16.0, bottom: 16),// Set background color for the Row
//                   child: Row(
//                     children: [
//                       CircleAvatar(
//                         backgroundColor: Color(0xFFFFFFFF),
//                         radius: 35,
//                         child: Icon(icon, color: Color(0xFFEC98E1),
//                         size: 40,),
//                       ),
//                       SizedBox(width: 10),
//                       Text(
//                         title,
//                         style: const TextStyle(fontSize: 18, color: Colors.white), // Text color to white
//                       ),
//                     ],
//                   ),
//                 ),
//                 SizedBox(height: 20,),
//                 Container(
//                   color: Color(0xFFFFFFFF),
//                   padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 20.0),
//                   child: Row(
//                     mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                     children: [
//                       Text(
//                         "Category",
//                         style: const TextStyle(fontSize: 15, color: Colors.black),
//                       ),
//                       Text(
//                         category,
//                         style: const TextStyle(fontSize: 15, color: Colors.black, fontWeight: FontWeight.bold),
//                       ),
//                     ],
//                   ),
//                 ),
//
//                 SizedBox(height: 20,),
//                 Container(
//                   color: Color(0xFFFFFFFF),
//                   padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 20.0),
//                   child: Row(
//                     mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                     children: [
//                       Text(
//                         "Paid By",
//                         style: const TextStyle(fontSize: 15, color: Colors.black),
//                       ),
//                       Text(
//                         paidBy,
//                         style: const TextStyle(fontSize: 15, color: Colors.black,fontWeight: FontWeight.bold),
//                       ),
//                     ],
//                   ),
//                 ),
//                 SizedBox(height: 1,),
//                 Container(
//                   color: Color(0xFFFFFFFF),
//                   padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 20.0),
//                   child: Row(
//                     mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                     children: [
//                       Text(
//                         "Amount (original):",
//                         style: const TextStyle(fontSize: 15, color: Colors.black),
//                       ),
//                       Text(
//                         "$fromCurrency ${amountOri.toStringAsFixed(2)}",
//                         style: const TextStyle(fontSize: 15, color: Colors.black,fontWeight: FontWeight.bold),
//                       ),
//                     ],
//                   ),
//                 ),
//                 SizedBox(height: 1,),
//                 Container(
//                   color: Color(0xFFFFFFFF),
//                   padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 20.0),
//                   child: Row(
//                     mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                     children: [
//                       Text(
//                         "Amount (converted):",
//                         style: const TextStyle(fontSize: 15, color: Colors.black),
//                       ),
//                       Text(
//                         "${widget.homeCurrency} ${amount.toStringAsFixed(2)}",
//                         style: const TextStyle(fontSize: 15, color: Colors.black,fontWeight: FontWeight.bold),
//                       ),
//                     ],
//                   ),
//                 ),
//                 SizedBox(height: 1,),
//                 Container(
//                   color: Color(0xFFFFFFFF),
//                   padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 20.0),
//                   child: Row(
//                     mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                     children: [
//                       Text(
//                         "Rate Used:",
//                         style: const TextStyle(fontSize: 15, color: Colors.black),
//                       ),
//                       Text(
//                         "$rate",
//                         style: const TextStyle(fontSize: 15, color: Colors.black,fontWeight: FontWeight.bold),
//                       ),
//                     ],
//                   ),
//                 ),
//
//                 SizedBox(height: 10),
//                 Material(
//                   elevation: 4,
//                   shadowColor: Colors.grey,
//                   child: Container(
//                     color: Colors.white,
//                     padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 20.0),
//                     child: Column(
//                       crossAxisAlignment: CrossAxisAlignment.start,
//                       children: [
//                         Text(
//                           "Split Details:",
//                           style: TextStyle(
//                             fontSize: 16,
//                             color: Colors.black87,
//                           ),
//                         ),
//                         SizedBox(height: 8),
//
//                         ...splitDetails.split('\n').map((line) {
//                           final parts = line.split(':');
//                           final name = parts.first.trim();
//                           final amount = parts.length > 1 ? parts.last.trim() : '';
//
//                           return Padding(
//                             padding: const EdgeInsets.symmetric(vertical: 4.0),
//                             child: Row(
//                               children: [
//                                 Expanded(
//                                   flex: 2,
//                                   child: Text(
//                                     name,
//                                     style: TextStyle(
//                                       fontSize: 15,
//                                       color: Colors.black,
//                                       fontWeight: FontWeight.bold,
//                                     ),
//                                   ),
//                                 ),
//                                 Expanded(
//                                   flex: 1,
//                                   child: Text(
//                                     amount,
//                                     textAlign: TextAlign.right,
//                                     style: TextStyle(
//                                       fontSize: 15,
//                                       color: Colors.black,
//                                       fontWeight: FontWeight.bold,
//                                     ),
//                                   ),
//                                 ),
//                               ],
//                             ),
//                           );
//                         }),
//                       ],
//                     ),
//                   ),
//                 ),
//               ],
//             ),
//           ),
//         ),
//       ),
//     );
//   }
// }