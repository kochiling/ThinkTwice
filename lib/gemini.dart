import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:thinktwice/travel_tips.dart';

class GeminiPage extends StatefulWidget {
  const GeminiPage({Key? key}) : super(key: key);

  @override
  State<GeminiPage> createState() => _GeminiPageState();
}

class _GeminiPageState extends State<GeminiPage> {
  final TextEditingController _destinationController = TextEditingController();
  final TextEditingController _peopleController = TextEditingController();
  DateTime? _startDate;
  DateTime? _endDate;
  String? _geminiOutput;
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Gemini Trip Planner'),
        backgroundColor: Color(0xFFF6B1C3),
        centerTitle: true,
        elevation: 0,
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFFDE2E4), Color(0xFFB47EB3)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Input fields in a card (now at the top)
              Container(
                width: double.infinity,
                constraints: const BoxConstraints(maxWidth: 500),
                padding: const EdgeInsets.all(20),
                margin: const EdgeInsets.symmetric(horizontal: 0),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.95),
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black12,
                      blurRadius: 16,
                      offset: Offset(0, 8),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildCard(
                      child: TextField(
                        controller: _destinationController,
                        decoration: const InputDecoration(
                          labelText: 'Destination',
                          prefixIcon: Icon(Icons.location_on, color: Color(0xFFB47EB3)),
                          border: InputBorder.none,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    _buildCard(
                      child: TextField(
                        controller: _peopleController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Number of People',
                          prefixIcon: Icon(Icons.group, color: Color(0xFFB47EB3)),
                          border: InputBorder.none,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    _buildCard(
                      child: ListTile(
                        title: Text(
                          _startDate == null
                              ? 'Select Start Date'
                              : DateFormat('dd MMM yyyy').format(_startDate!),
                          style: const TextStyle(color: Color(0xFFB47EB3)),
                        ),
                        leading: const Icon(Icons.calendar_today, color: Color(0xFFB47EB3)),
                        onTap: () => _pickDate(isStartDate: true),
                      ),
                    ),
                    const SizedBox(height: 12),
                    _buildCard(
                      child: ListTile(
                        title: Text(
                          _endDate == null
                              ? 'Select End Date'
                              : DateFormat('dd MMM yyyy').format(_endDate!),
                          style: const TextStyle(color: Color(0xFFB47EB3)),
                        ),
                        leading: const Icon(Icons.calendar_today, color: Color(0xFFB47EB3)),
                        onTap: () => _pickDate(isStartDate: false),
                      ),
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton.icon(
                      onPressed: _isLoading ? null : _submitTrip,
                      icon: const Icon(Icons.flight_takeoff, color: Color(0xFFB47EB3)),
                      label: const Text('Plan My Trip'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Color(0xFFF6B1C3),
                        foregroundColor: Color(0xFFB47EB3),
                        padding: const EdgeInsets.symmetric(vertical: 15),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(15),
                        ),
                        textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        elevation: 2,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),
              if (_isLoading)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 32),
                  child: Column(
                    children: const [
                      CircularProgressIndicator(color: Color(0xFFB47EB3)),
                      SizedBox(height: 16),
                      Text('Generating your trip plan...', style: TextStyle(color: Color(0xFFB47EB3), fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              if (!_isLoading && _geminiOutput != null)
                Container(
                  width: double.infinity,
                  constraints: const BoxConstraints(maxWidth: 500),
                  margin: const EdgeInsets.only(bottom: 24),
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.98),
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black12,
                        blurRadius: 18,
                        offset: Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        _geminiOutput!,
                        style: const TextStyle(fontSize: 16, color: Color(0xFFB47EB3)),
                      ),
                      const SizedBox(height: 24),
                      ElevatedButton.icon(
                        onPressed: _showSaveDialog,
                        icon: const Icon(Icons.save, color: Colors.white),
                        label: const Text('Save Trip'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Color(0xFFB47EB3),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(15),
                          ),
                          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                          elevation: 2,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCard({required Widget child}) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      elevation: 5,
      shadowColor: Colors.black45,
      color: Colors.white.withOpacity(0.9),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: child,
      ),
    );
  }

  void _pickDate({required bool isStartDate}) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(days: 1)),
      firstDate: DateTime.now(),
      lastDate: DateTime(2100),
    );

    if (picked != null) {
      setState(() {
        if (isStartDate) {
          _startDate = picked;
        } else {
          _endDate = picked;
        }
      });
    }
  }

  void _submitTrip() {
    final destination = _destinationController.text.trim();
    final people = _peopleController.text.trim();
    final start = _startDate;
    final end = _endDate;

    if (destination.isEmpty || people.isEmpty || start == null || end == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill in all fields')),
      );
      return;
    }

    // Call the Gemini API
    _callGeminiAPI(destination, people, start, end);
  }

  Future<void> _callGeminiAPI(
      String destination, String people, DateTime start, DateTime end) async {
    setState(() {
      _isLoading = true;
      _geminiOutput = null;
    });
    const apiKey = 'AIzaSyCfY4jm-SgkhGUVzzcoGfawkjYrc0I-D4s'; // Replace with your actual API key

    final url =
        'https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash:generateContent?key=$apiKey';

    final prompt = '''
Plan a trip to $destination for $people people from ${DateFormat('dd MMM yyyy').format(start)} to ${DateFormat('dd MMM yyyy').format(end)}. Include sightseeing, food, and activities.
''';

    final response = await http.post(
      Uri.parse(url),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'contents': [
          {'parts': [{'text': prompt}]}
        ]
      }),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final text = data['candidates'][0]['content']['parts'][0]['text'];

      setState(() {
        _geminiOutput = text;
        _isLoading = false;
      });
    } else {
      setState(() {
        _geminiOutput = 'Error: {response.body}';
        _isLoading = false;
      });
    }
  }

  void _showSaveDialog() {
    final TextEditingController _titleController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Save Trip'),
        content: TextField(
          controller: _titleController,
          decoration: const InputDecoration(
            labelText: 'Trip Name',
            hintText: 'Enter a name for this trip',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
            },
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final tripName = _titleController.text.trim();
              if (tripName.isNotEmpty) {
                _saveTripToFirebase(tripName);
                Navigator.pop(context);

                // Navigate to TravelTipsPage after saving
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const TravelTipsPage()),
                );
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _saveTripToFirebase(String tripName) {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      // If the user is not logged in, show a message
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You must be logged in to save a trip.')),
      );
      return;
    }

    // Get the current user's UID
    final uid = user.uid;

    // Reference the user's node in the database
    final dbRef = FirebaseDatabase.instance.ref().child('TripTips').child(uid);

    final tripData = {
      'tipsTitle': tripName,
      'destination': _destinationController.text.trim(),
      'peopleNum': _peopleController.text.trim(),
      'startDate': DateFormat('dd MMM yyyy').format(_startDate!),
      'endDate': DateFormat('dd MMM yyyy').format(_endDate!),
      'geminiContent': _geminiOutput,
    };

    // Save the trip under the user's UID
    dbRef.push().set(tripData).then((_) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Trip saved successfully!')),
      );
    }).catchError((error) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error saving trip: $error')),
      );
    });
  }
}
