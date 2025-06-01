import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:thinktwice/tips_details.dart';

class TravelTipsPage extends StatefulWidget {
  const TravelTipsPage({Key? key}) : super(key: key);

  @override
  State<TravelTipsPage> createState() => _TravelTipsPageState();
}

class _TravelTipsPageState extends State<TravelTipsPage> {
  final DatabaseReference _dbRef = FirebaseDatabase.instance.ref().child('TripTips');
  List<Map<String, dynamic>> _trips = [];

  @override
  void initState() {
    super.initState();
    _fetchTrips();
  }

  void _fetchTrips() {
    _dbRef.onValue.listen((event) {
      final data = event.snapshot.value as Map<dynamic, dynamic>?;

      if (data != null) {
        final List<Map<String, dynamic>> loadedTrips = [];

        data.forEach((userId, userTrips) {
          if (userTrips is Map) {
            userTrips.forEach((tripId, tripData) {
              loadedTrips.add({
                'tripId': tripId,
                'userId': userId,
                ...Map<String, dynamic>.from(tripData),
              });
            });
          }
        });

        setState(() {
          _trips = loadedTrips;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
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
        backgroundColor: const Color(0xFFF6B1C3), // Light pink
        elevation: 0,
      ),
      body: _trips.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _trips.length,
        itemBuilder: (context, index) {
          final trip = _trips[index];
          return _buildTripCard(trip);
        },
      ),
    );
  }

  Widget _buildTripCard(Map<String, dynamic> trip) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => TripDetailsPage(trip: trip),
          ),
        );
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
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                trip['tipsTitle'] ?? 'No Title',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFFB47EB3), // Soft purple
                ),
              ),
              const SizedBox(height: 8),
              Text(
                trip['destination'] ?? 'Unknown Destination',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF8C6BB1), // Slightly deeper purple
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${trip['startDate']} - ${trip['endDate']}',
                style: const TextStyle(
                  fontSize: 14,
                  color: Colors.grey,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
