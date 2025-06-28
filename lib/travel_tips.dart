import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:thinktwice/tips_details.dart';
import 'package:thinktwice/gemini.dart';
import 'package:thinktwice/tips_edit_page.dart';

class TravelTipsPage extends StatefulWidget {
  const TravelTipsPage({Key? key}) : super(key: key);

  @override
  State<TravelTipsPage> createState() => _TravelTipsPageState();
}

class _TravelTipsPageState extends State<TravelTipsPage> {
  final DatabaseReference _dbRef = FirebaseDatabase.instance.ref().child('TripTips');
  List<Map<String, dynamic>> _trips = [];
  List<Map<String, dynamic>> _filteredTrips = [];
  final TextEditingController _searchController = TextEditingController();
  User? _currentUser;

  @override
  void initState() {
    super.initState();
    _currentUser = FirebaseAuth.instance.currentUser;
    _fetchTrips();
    _searchController.addListener(_filterTrips);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _fetchTrips() {
    // Check if user is logged in
    if (_currentUser == null) {
      setState(() {
        _trips = [];
        _filteredTrips = [];
      });
      return;
    }

    // Only fetch trips for the current user
    _dbRef.child(_currentUser!.uid).onValue.listen((event) {
      final data = event.snapshot.value as Map<dynamic, dynamic>?;

      if (data != null) {
        final List<Map<String, dynamic>> loadedTrips = [];

        data.forEach((tripId, tripData) {
          loadedTrips.add({
            'tripId': tripId,
            'userId': _currentUser!.uid,
            ...Map<String, dynamic>.from(tripData),
          });
        });

        setState(() {
          _trips = loadedTrips;
          _filteredTrips = loadedTrips; // Initialize filtered list
        });
      } else {
        setState(() {
          _trips = [];
          _filteredTrips = [];
        });
      }
    });
  }

  void _filterTrips() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      _filteredTrips = _trips.where((trip) {
        final title = trip['tipsTitle']?.toString().toLowerCase() ?? '';
        final destination = trip['destination']?.toString().toLowerCase() ?? '';
        final startDate = trip['startDate']?.toString().toLowerCase() ?? '';
        final endDate = trip['endDate']?.toString().toLowerCase() ?? '';
        final content = trip['content']?.toString().toLowerCase() ?? '';
        final tips = trip['tips']?.toString().toLowerCase() ?? '';
        final budget = trip['budget']?.toString().toLowerCase() ?? '';
        final notes = trip['notes']?.toString().toLowerCase() ?? '';
        
        return title.contains(query) || 
               destination.contains(query) || 
               startDate.contains(query) || 
               endDate.contains(query) || 
               content.contains(query) || 
               tips.contains(query) || 
               budget.contains(query) || 
               notes.contains(query);
      }).toList();
    });
  }

  void _deleteTrip(Map<String, dynamic> trip) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Delete Trip'),
          content: Text('Are you sure you want to delete "${trip['tipsTitle']}"?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                _confirmDelete(trip);
              },
              child: const Text('Delete'),
              style: TextButton.styleFrom(foregroundColor: Colors.red),
            ),
          ],
        );
      },
    );
  }

  void _confirmDelete(Map<String, dynamic> trip) {
    final userId = trip['userId'];
    final tripId = trip['tripId'];
    
    if (userId != null && tripId != null) {
      _dbRef.child(userId).child(tripId).remove().then((_) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Trip deleted successfully')),
        );
      }).catchError((error) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to delete trip: $error')),
        );
      });
    }
  }

  void _showEditDialog(Map<String, dynamic> trip) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Edit Trip'),
          content: Text('What would you like to do with "${trip['tipsTitle']}"?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => TipsEditPage(trip: trip),
                  ),
                );
              },
              child: const Text('Edit'),
              style: TextButton.styleFrom(foregroundColor: const Color(0xFFB47EB3)),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    // Check if user is logged in
    if (_currentUser == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text(
            'Travel Tips',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          backgroundColor: const Color(0xFFF6B1C3),
          elevation: 0,
        ),
        body: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.account_circle,
                size: 64,
                color: Color(0xFFB47EB3),
              ),
              SizedBox(height: 16),
              Text(
                'Please log in to view your trips',
                style: TextStyle(
                  fontSize: 18,
                  color: Color(0xFFB47EB3),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Travel Tips',
          // style: TextStyle(
          //   fontSize: 22,
          //   fontWeight: FontWeight.bold,
          //   color: Colors.white,
          // ),
        ),
        //backgroundColor: const Color(0xFFF6B1C3), // Light pink
        elevation: 0,
      ),
      body: _trips.isEmpty
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.flight_takeoff,
                    size: 64,
                    color: Color(0xFFB47EB3),
                  ),
                  SizedBox(height: 16),
                  Text(
                    'No trips found',
                    style: TextStyle(
                      fontSize: 18,
                      color: Color(0xFFB47EB3),
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Create your first trip using the chat button below!',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            )
          : Column(
              children: [
                // Search Box
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'Search trips by any information...',
                      prefixIcon: const Icon(Icons.search, color: Color(0xFFB47EB3)),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Color(0xFFB47EB3)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Color(0xFFB47EB3), width: 2),
                      ),
                      filled: true,
                      fillColor: const Color(0xFFFDE2E4).withOpacity(0.3),
                    ),
                  ),
                ),
                // Trip List
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _filteredTrips.length,
                    itemBuilder: (context, index) {
                      final trip = _filteredTrips[index];
                      return Center(
                        child: Container(
                          width: double.infinity,
                          constraints: const BoxConstraints(maxWidth: 600),
                          child: _buildTripCard(trip),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 60.0),
        child: FloatingActionButton(
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const GeminiPage()),
            );
          },
          child: const Icon(Icons.chat),
        ),
      ),
    );
  }

  Widget _buildTripCard(Map<String, dynamic> trip) {
    return Dismissible(
      key: Key('${trip['userId']}_${trip['tripId']}'),
      direction: DismissDirection.endToStart,
      background: Container(
        margin: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: Colors.red,
          borderRadius: BorderRadius.circular(16),
        ),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        child: const Icon(
          Icons.delete,
          color: Colors.white,
          size: 30,
        ),
      ),
      confirmDismiss: (direction) async {
        _deleteTrip(trip);
        return false; // Prevent auto-dismiss since we handle it in confirmation
      },
      child: GestureDetector(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => TripDetailsPage(trip: trip),
            ),
          );
        },
        onLongPress: () {
          _showEditDialog(trip);
        },
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: const Color(0xFFFDE2E4), // Light pastel pink
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFB47EB3).withOpacity(0.2), // Light purple shadow
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  trip['tipsTitle'] ?? 'No Title',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFFB47EB3), // Soft purple
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
                const SizedBox(height: 8),
                Text(
                  trip['destination'] ?? 'Unknown Destination',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF8C6BB1), // Slightly deeper purple
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
                const SizedBox(height: 4),
                Text(
                  '${trip['startDate']} - ${trip['endDate']}',
                  style: const TextStyle(
                    fontSize: 14,
                    color: Colors.grey,
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
