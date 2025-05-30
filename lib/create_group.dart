import 'package:flutter/material.dart';
import 'package:thinktwice/group_page.dart';
import 'package:thinktwice/user_model.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:math';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:thinktwice/currency_api.dart';


class CreateGroup extends StatefulWidget {
  const CreateGroup({Key? key}) : super(key: key);

  @override
  State<CreateGroup> createState() => _CreateGroupState();
}

class _CreateGroupState extends State<CreateGroup> {
  int currentStep = 0;

  final TextEditingController nameController = TextEditingController();
  DateTime? selectedDate;
  String? selectedCurrency;
  List<String> selectedMembers = [];
  String? _nameError;

  DateTime? selectedStartDate;
  DateTime? selectedEndDate;

  final TextEditingController _searchController = TextEditingController();
  List<UserModel> _searchResults = [];
  List<String> selectedMemberUIDs = [];
  bool isSearching = false;
  final currentUser = FirebaseAuth.instance.currentUser;

  List<String> currencyCodes = [];

  @override
  void initState() {
    super.initState();
    if (currentUser != null) {
      selectedMemberUIDs.add(currentUser!.uid); // Ensure current user is added
    }
    loadCurrencyList();
  }

  Future<void> loadCurrencyList() async {
    try {
      final codes = await CurrencyApi.getCurrencies();
      setState(() {
        currencyCodes = codes;
        selectedCurrency = codes.contains("MYR") ? "MYR" : codes.first;
      });
    } catch (e) {
      print("Error loading currencies: $e");
    }
  }

  void _searchUsers(String query) async {
    final currentUser = FirebaseAuth.instance.currentUser;
    final ref = FirebaseDatabase.instance.ref().child('Users');
    final snapshot = await ref.once();

    List<UserModel> results = [];

    if (snapshot.snapshot.value != null && currentUser != null) {
      final data = Map<String, dynamic>.from(snapshot.snapshot.value as Map);
      data.forEach((key, value) {
        if (key == currentUser.uid) return;

        final user = UserModel.fromMap(Map<String, dynamic>.from(value), key);
        if (user.name.toLowerCase().contains(query.toLowerCase()) ||
            user.email.toLowerCase().contains(query.toLowerCase())) {
          results.add(user);
        }
      });
    }

    setState(() {
      _searchResults = results;
      isSearching = true;
    });
  }




  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Create Group"),
      ),
      body: IndexedStack(
        index: currentStep,
        children: [
          _buildNameStep(),
          _buildDateStep(),
          _buildCurrencyStep(),
          _buildMemberStep(),
        ],
      ),
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            if (currentStep > 0)
              ElevatedButton(
                onPressed: () {
                  setState(() {
                    currentStep--;
                  });
                },
                child: const Text("Back"),
              )
            else
              const SizedBox(width: 80),

            ElevatedButton(
              onPressed: () {
                if (currentStep < 3) {
                  setState(() {
                    currentStep++;
                  });
                } else {
                  _saveGroupToFirebase();
                }
              },
              child: Text(currentStep == 3 ? "Create" : "Next"),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNameStep() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.only(right: 3.0, left: 3.0, top: 50.0, bottom: 20.0),
            child: const Text("Choose A Group Name",
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 25, fontFamily: 'ComicSans'),),
          ),
          const SizedBox(height: 10),
          Padding(
            padding: const EdgeInsets.only(right: 3.0, left: 3.0, top: 10.0),
            child: TextField(
              controller: nameController,
              maxLength: 99,
              decoration: InputDecoration(
                hintText: 'eg:"Travel to Japan 2025 ✈️"',
                errorText: _nameError,
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: Colors.grey),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: Color(0xFFE991AA), width: 2),
                ),
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 20.0),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDateStep() {
    return Center(
      child: Column(
        children: [
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 3.0, vertical: 22.0),
            child: Text(
              "Pick Your Travel Dates 📆",
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 25, fontFamily: 'ComicSans'),
            ),
          ),
          const Padding(
            padding: EdgeInsets.only(right: 8, left: 8, top: 5 , bottom: 50),
            child: Text(
              "When will your journey start and end?",
              style: TextStyle(fontSize: 15, fontFamily: 'ComicSans'),
            ),
          ),
          _dateBox("Start Date", selectedStartDate, (date) {
            setState(() {
              selectedStartDate = date;
            });
          }),
          const SizedBox(height: 16),
          _dateBox("End Date", selectedEndDate, (date) {
            setState(() {
              selectedEndDate = date;
            });
          }),
        ],
      ),
    );
  }

  Widget _dateBox(String label, DateTime? date, ValueChanged<DateTime> onDateSelected) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: InkWell(
        onTap: () async {
          final pickedDate = await showDatePicker(
            context: context,
            initialDate: date ?? DateTime.now(),
            firstDate: DateTime(2000),
            lastDate: DateTime(2100),
          );
          if (pickedDate != null) {
            onDateSelected(pickedDate);
          }
        },
        child: InputDecorator(
          decoration: InputDecoration(
            labelText: label,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
            filled: true,
            fillColor: Colors.white,
          ),
          child: Text(
            date != null
                ? "${date.day.toString().padLeft(2, '0')}-${date.month.toString().padLeft(2, '0')}-${date.year}"
                : "Select $label",
            style: const TextStyle(fontSize: 16),
          ),
        ),
      ),
    );
  }

  Widget _buildCurrencyStep() {
    return Center(
      child: Column(
        children: [
          const Padding(
            padding: EdgeInsets.only(right: 3, left: 3, top: 50, bottom: 10),
            child: Text(
              "Pick Your Home Currency 💱",
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 25, fontFamily: 'ComicSans'),
            ),
          ),
          const Padding(
            padding: EdgeInsets.only(right: 3, left: 3, bottom: 50),
            child: Text(
              "All amounts will automatically be converted to this currency",
              style: TextStyle(fontSize: 15, fontFamily: 'ComicSans'),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 8, left: 8, bottom: 50),
            child: currencyCodes.isEmpty
                ? CircularProgressIndicator()
                : DropdownButtonFormField<String>(
              value: selectedCurrency,
              decoration: InputDecoration(
                labelText: "Select Currency",
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                filled: true,
                fillColor: Colors.white,
              ),
              items: currencyCodes.map((code) {
                return DropdownMenuItem<String>(
                  value: code,
                  child: Text(code),
                );
              }).toList(),
              onChanged: (value) {
                setState(() {
                  selectedCurrency = value;
                });
              },
            ),
          ),
        ],
      ),
    );
  }

  // Widget _buildCurrencyStep() {
  //   final currencies = {
  //     'AUD': 'Australian Dollar',
  //     'EUR': 'Euro',
  //     'MYR': 'Malaysian Ringgit',
  //     'USD': 'US Dollar',
  //     'JPY': 'Japanese Yen',
  //     'GBP': 'British Pound',
  //     'SGD': 'Singapore Dollar',
  //     'THB': 'Thai Baht',
  //     'INR': 'Indian Rupee',
  //   };
  //   return Center(
  //     child: Column(
  //       children: [
  //         const Padding(
  //           padding: EdgeInsets.only(right: 3, left: 3, top: 50, bottom: 10),
  //           child: Text(
  //             "Pick Your Home Currency 💱",
  //             style: TextStyle(fontWeight: FontWeight.bold, fontSize: 25, fontFamily: 'ComicSans'),
  //           ),
  //         ),
  //         // const Padding(
  //         //   padding: EdgeInsets.only(right: 3, left: 3, top: 10 , bottom: 1),
  //         //   child: Text(
  //         //     "It will be the currency of your bank account",
  //         //     style: TextStyle(fontSize: 15, fontFamily: 'ComicSans'),
  //         //   ),
  //         // ),
  //         const Padding(
  //           padding: EdgeInsets.only(right: 3, left: 3, top: 1 , bottom: 50),
  //           child: Text(
  //             "All amounts will automatically converted to this currency",
  //             style: TextStyle(fontSize: 15, fontFamily: 'ComicSans'),
  //           ),
  //         ),
  //         Padding(
  //           padding: const EdgeInsets.only(right: 8, left: 8, top: 1, bottom: 50),
  //           child: DropdownButtonFormField<String>(
  //             value: selectedCurrency,
  //             decoration: InputDecoration(
  //               labelText: "Select Currency",
  //               border: OutlineInputBorder(
  //                 borderRadius: BorderRadius.circular(10),
  //               ),
  //               filled: true,
  //               fillColor: Colors.white,
  //             ),
  //             items: currencies.entries.map((entry) {
  //               return DropdownMenuItem<String>(
  //                 value: entry.key, // Save only the abbreviation
  //                 child: Text("${entry.value} (${entry.key})"), // Show full name
  //               );
  //             }).toList(),
  //             onChanged: (value) {
  //               setState(() {
  //                 selectedCurrency = value;
  //               });
  //             },
  //           ),
  //         ),
  //       ],
  //     ),
  //   );
  // }

  Widget _buildMemberStep() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          TextField(
            controller: _searchController,
            onChanged: (value) {
              _searchUsers(value.trim()); // Real-time search
            },
            decoration: InputDecoration(
              hintText: 'Search by username or email',
              prefixIcon: const Icon(Icons.search),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
            ),
          ),
          const SizedBox(height: 20),
          Flexible(
            child: isSearching
                ? _searchResults.isEmpty
                ? const Center(child: Text("No users found."))
                : ListView.builder(
              itemCount: _searchResults.length,
              itemBuilder: (context, index) {
                final user = _searchResults[index];
                final isSelected = selectedMemberUIDs.contains(user.id);

                return ListTile(
                  leading: CircleAvatar(
                    backgroundImage: NetworkImage(user.profileImage)
                  ),
                  title: Text(user.name),
                  subtitle: Text(user.email),
                  trailing: Icon(
                    isSelected ? Icons.check_circle : Icons.add_circle_outline,
                    color: isSelected ? Colors.green : null,
                  ),
                  onTap: () {
                    setState(() {
                      if (isSelected) {
                        selectedMemberUIDs.remove(user.id);
                      } else {
                        selectedMemberUIDs.add(user.id);
                      }
                    });
                  },
                );
              },
            )
                : const Center(child: Text("Search for users to add")),
          ),
        ],
      ),
    );
  }

  void _saveGroupToFirebase() async {
    final String groupName = nameController.text.trim();
    final String startDate = selectedStartDate != null
        ? DateFormat('dd-MM-yyyy').format(selectedStartDate!)
        : '';
    final String endDate = selectedEndDate != null
        ? DateFormat('dd-MM-yyyy').format(selectedEndDate!)
        : '';
    final String currency = selectedCurrency ?? '';

    if (groupName.isEmpty || startDate.isEmpty || endDate.isEmpty || currency.isEmpty || selectedMemberUIDs.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill all group details')),
      );
      return;
    }

    final DatabaseReference groupRef = FirebaseDatabase.instance.ref().child('Groups').push();
    final String groupId = groupRef.key!;
    final String groupCode = _generateGroupCode();

    // Build member map: { uid: true }
    Map<String, dynamic> members = {
      for (var uid in selectedMemberUIDs) uid: true,
    };

    final groupData = {
      'groupId': groupId,
      'groupName': groupName,
      'startDate': startDate,
      'endDate': endDate,
      'homeCurrency': currency,
      'members': members,
      'memberCount': selectedMemberUIDs.length,
      'groupCode': groupCode,
      'createdAt': DateTime.now().toIso8601String(),
    };

    await groupRef.set(groupData);

    // Show success dialog with copyable group code
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Group Created'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Share this group code:'),
              const SizedBox(height: 10),
              SelectableText(
                groupCode,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                  color: Colors.blue,
                ),
              ),
              const SizedBox(height: 10),
              ElevatedButton.icon(
                icon: const Icon(Icons.copy),
                label: const Text("Copy Code"),
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: groupCode));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("Group code copied!")),
                  );
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              child: const Text("Close"),
              onPressed: () {
                Navigator.pop(context); // Close the dialog
                Navigator.pop(context, 1); // Pop current group creation page
                // OR Navigator.pushReplacement() if going to a new screen:
                // Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => GroupPage()));
              },
            ),
          ],
        );
      },
    );
  }

  String _generateGroupCode({int length = 6}) {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final rand = Random();
    return List.generate(length, (index) => chars[rand.nextInt(chars.length)]).join();
  }

  goToHome(BuildContext context) => Navigator.pushReplacement(
    context,
    //MaterialPageRoute(builder: (context) => HomePage()),
    MaterialPageRoute(builder: (context) => GroupPage()),
  );

}
