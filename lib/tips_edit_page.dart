import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class TipsEditPage extends StatefulWidget {
  final Map<String, dynamic> trip;

  const TipsEditPage({Key? key, required this.trip}) : super(key: key);

  @override
  State<TipsEditPage> createState() => _TipsEditPageState();
}

class _TipsEditPageState extends State<TipsEditPage> {
  final DatabaseReference _dbRef = FirebaseDatabase.instance.ref().child('TripTips');
  
  late TextEditingController _destinationController;
  late TextEditingController _peopleController;
  late TextEditingController _contentController;
  
  String _tripTitle = '';
  DateTime? _startDate;
  DateTime? _endDate;
  bool _isLoading = false;
  bool _isGenerating = false;
  bool _hasUnsavedChanges = false;

  @override
  void initState() {
    super.initState();
    _initializeControllers();
  }

  void _initializeControllers() {
    _tripTitle = widget.trip['tipsTitle'] ?? 'Untitled Trip';
    _destinationController = TextEditingController(text: widget.trip['destination'] ?? '');
    _peopleController = TextEditingController(text: widget.trip['peopleNum'] ?? '');
    _contentController = TextEditingController(text: widget.trip['geminiContent'] ?? '');

    // Add listeners to detect changes
    _destinationController.addListener(_onFieldChanged);
    _peopleController.addListener(_onFieldChanged);

    // Parse dates
    try {
      if (widget.trip['startDate'] != null) {
        _startDate = DateFormat('dd MMM yyyy').parse(widget.trip['startDate']);
      }
      if (widget.trip['endDate'] != null) {
        _endDate = DateFormat('dd MMM yyyy').parse(widget.trip['endDate']);
      }
    } catch (e) {
      print('Error parsing dates: $e');
    }
  }

  void _onFieldChanged() {
    setState(() {
      _hasUnsavedChanges = true;
    });
  }

  @override
  void dispose() {
    _destinationController.dispose();
    _peopleController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Edit Trip',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        backgroundColor: const Color(0xFFF6B1C3),
        elevation: 0,
        actions: [
          IconButton(
            onPressed: (_isLoading || _isGenerating) ? null : _generateNewContent,
            icon: const Icon(Icons.auto_awesome, color: Colors.white),
            tooltip: 'Regenerate with Gemini',
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
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              // Trip Title Display (Non-editable)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.95),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black12,
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Text(
                      _tripTitle,
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFFB47EB3),
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Trip Details',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey,
                      ),
                    ),
                  ],
                ),
              ),
              _buildInputCard(
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
              _buildInputCard(
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
              _buildInputCard(
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
              const SizedBox(height: 16),
              _buildInputCard(
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
              const SizedBox(height: 16),
              _buildInputCard(
                child: TextField(
                  controller: _contentController,
                  maxLines: 6,
                  readOnly: true,
                  decoration: const InputDecoration(
                    labelText: 'Generated Trip Content (Read-only)',
                    prefixIcon: Icon(Icons.description, color: Color(0xFFB47EB3)),
                    border: InputBorder.none,
                    alignLabelWithHint: true,
                    helperText: 'This content is generated by AI. Use the regenerate button to update.',
                  ),
                  style: const TextStyle(color: Color(0xFF666666)),
                ),
              ),
              const SizedBox(height: 24),
              if (_hasUnsavedChanges && !_isGenerating)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Colors.orange.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.orange.withOpacity(0.5)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.warning, color: Colors.orange, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'You have unsaved changes. Please regenerate content before saving.',
                          style: TextStyle(
                            color: Colors.orange.shade800,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              if (_isGenerating)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: Column(
                    children: [
                      CircularProgressIndicator(color: Color(0xFFB47EB3)),
                      SizedBox(height: 8),
                      Text(
                        'Generating new content with Gemini...',
                        style: TextStyle(color: Color(0xFFB47EB3)),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 16),
              // Single Save Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: (_isLoading || _isGenerating || _hasUnsavedChanges) ? null : _saveChanges,
                  icon: const Icon(Icons.save, color: Colors.white),
                  label: Text(_hasUnsavedChanges ? 'Regenerate Content First' : 'Save Changes'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _hasUnsavedChanges ? Colors.grey : const Color(0xFFB47EB3),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15),
                    ),
                    textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInputCard({required Widget child}) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 4,
      shadowColor: Colors.black26,
      color: Colors.white.withOpacity(0.95),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: child,
      ),
    );
  }

  void _pickDate({required bool isStartDate}) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: (isStartDate ? _startDate : _endDate) ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );

    if (picked != null) {
      setState(() {
        if (isStartDate) {
          _startDate = picked;
        } else {
          _endDate = picked;
        }
        _hasUnsavedChanges = true; // Mark as having unsaved changes
      });
    }
  }

  void _saveChanges() async {
    if (_hasUnsavedChanges) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please regenerate content first before saving changes.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    if (_destinationController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Destination cannot be empty')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final userId = widget.trip['userId'];
      final tripId = widget.trip['tripId'];

      if (userId != null && tripId != null) {
        final updatedData = {
          'tipsTitle': _tripTitle, // Keep original title
          'destination': _destinationController.text.trim(),
          'peopleNum': _peopleController.text.trim(),
          'startDate': _startDate != null ? DateFormat('dd MMM yyyy').format(_startDate!) : '',
          'endDate': _endDate != null ? DateFormat('dd MMM yyyy').format(_endDate!) : '',
          'geminiContent': _contentController.text.trim(),
        };

        await _dbRef.child(userId).child(tripId).update(updatedData);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Trip updated successfully!')),
          );
          Navigator.pop(context);
        }
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error updating trip: $error')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _generateNewContent() async {
    final destination = _destinationController.text.trim();
    final people = _peopleController.text.trim();

    if (destination.isEmpty || people.isEmpty || _startDate == null || _endDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill in all fields before regenerating content')),
      );
      return;
    }

    setState(() {
      _isGenerating = true;
    });

    try {
      const apiKey = 'AIzaSyCfY4jm-SgkhGUVzzcoGfawkjYrc0I-D4s'; // Replace with your actual API key

      final url =
          'https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash:generateContent?key=$apiKey';

      final prompt = '''
Plan a trip to $destination for $people people from ${DateFormat('dd MMM yyyy').format(_startDate!)} to ${DateFormat('dd MMM yyyy').format(_endDate!)}. Include sightseeing, food, and activities.
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
          _contentController.text = text;
          _isGenerating = false;
          _hasUnsavedChanges = false; // Reset unsaved changes flag
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Content regenerated successfully!')),
        );
      } else {
        setState(() {
          _contentController.text = 'Error: ${response.body}';
          _isGenerating = false;
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _contentController.text = 'Error generating content: $error';
          _isGenerating = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error generating content: $error')),
        );
      }
    }
  }
}
