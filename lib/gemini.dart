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
        title: const Text(
          'AI Trip Planner',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        backgroundColor: const Color(0xFFB47EB3),
        centerTitle: true,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          if (!_isLoading && _geminiOutput != null)
            IconButton(
              onPressed: _showSaveDialog,
              icon: const Icon(Icons.bookmark_add, color: Colors.white),
              tooltip: 'Save Trip',
            ),
        ],
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
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Welcome Header
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                margin: const EdgeInsets.only(bottom: 32),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.95),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFFB47EB3).withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.flight_takeoff,
                        size: 40,
                        color: Color(0xFFB47EB3),
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Plan Your Perfect Trip',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFFB47EB3),
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Let AI create the perfect itinerary for your next adventure',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey[600],
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
              // Input fields in a card
              Container(
                width: double.infinity,
                constraints: const BoxConstraints(maxWidth: 600),
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.95),
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.08),
                      blurRadius: 25,
                      offset: const Offset(0, 15),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'Trip Information',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFFB47EB3),
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    _buildModernCard(
                      child: TextField(
                        controller: _destinationController,
                        decoration: const InputDecoration(
                          labelText: 'Destination',
                          prefixIcon: Icon(Icons.location_on, color: Color(0xFFB47EB3)),
                          border: InputBorder.none,
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    _buildModernCard(
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
                    const SizedBox(height: 20),
                    _buildModernCard(
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
                    const SizedBox(height: 20),
                    _buildModernCard(
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
                    const SizedBox(height: 32),
                    Container(
                      width: double.infinity,
                      height: 56,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFFB47EB3), Color(0xFF8C6BB1)],
                          begin: Alignment.centerLeft,
                          end: Alignment.centerRight,
                        ),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFFB47EB3).withOpacity(0.3),
                            blurRadius: 15,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: ElevatedButton.icon(
                        onPressed: _isLoading ? null : _submitTrip,
                        icon: const Icon(Icons.auto_awesome, color: Colors.white, size: 24),
                        label: const Text(
                          'Generate Trip Plan',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          shadowColor: Colors.transparent,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),
              if (_isLoading)
                Container(
                  margin: const EdgeInsets.symmetric(vertical: 40),
                  padding: const EdgeInsets.all(32),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.95),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.08),
                        blurRadius: 20,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: const Color(0xFFB47EB3).withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                        child: const CircularProgressIndicator(
                          color: Color(0xFFB47EB3),
                          strokeWidth: 3,
                        ),
                      ),
                      const SizedBox(height: 24),
                      const Text(
                        'Creating Your Perfect Trip...',
                        style: TextStyle(
                          color: Color(0xFFB47EB3),
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Our AI is crafting a personalized itinerary just for you',
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 14,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              if (!_isLoading && _geminiOutput != null)
                Container(
                  width: double.infinity,
                  constraints: const BoxConstraints(maxWidth: 600),
                  margin: const EdgeInsets.only(top: 32, bottom: 24),
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.98),
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.08),
                        blurRadius: 25,
                        offset: const Offset(0, 15),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: const Color(0xFFB47EB3).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(
                              Icons.travel_explore,
                              color: Color(0xFFB47EB3),
                              size: 24,
                            ),
                          ),
                          const SizedBox(width: 12),
                          const Text(
                            'Your Trip Plan',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFFB47EB3),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFDE2E4).withOpacity(0.3),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: const Color(0xFFB47EB3).withOpacity(0.2),
                          ),
                        ),
                        child: Text(
                          _geminiOutput!,
                          style: const TextStyle(
                            fontSize: 16,
                            color: Color(0xFF2D2D2D),
                            height: 1.6,
                          ),
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

  Widget _buildModernCard({required Widget child}) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.95),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFB47EB3).withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(
          color: const Color(0xFFB47EB3).withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
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
