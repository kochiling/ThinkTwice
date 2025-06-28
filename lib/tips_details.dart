import 'package:flutter/material.dart';

class TripDetailsPage extends StatelessWidget {
  final Map<String, dynamic> trip;

  const TripDetailsPage({Key? key, required this.trip}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final String title = trip['tipsTitle'] ?? 'No Title';
    final String startDate = trip['startDate'] ?? '-';
    final String endDate = trip['endDate'] ?? '-';
    final String geminiContent = trip['geminiContent'] ?? 'No content available.';
    final String peopleNum = trip['peopleNum'] ?? 'N/A';
    final String destination = trip['destination'] ?? 'Unknown';

    return Scaffold(
      appBar: AppBar(
        title: Text(
          title,
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        backgroundColor: const Color(0xFFB47EB3),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Container(
        color: Colors.white,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Destination
              Container(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    Icon(
                      Icons.location_on,
                      color: const Color(0xFFB47EB3),
                      size: 20,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        destination,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF2D2D2D),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: 16),
              
              // Duration
              Container(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    Icon(
                      Icons.calendar_today,
                      color: const Color(0xFFB47EB3),
                      size: 20,
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Duration',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFFB47EB3),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '$startDate to $endDate',
                          style: const TextStyle(
                            fontSize: 16,
                            color: Color(0xFF495057),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: 12),
              
              // Travelers
              Container(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    Icon(
                      Icons.group,
                      color: const Color(0xFFB47EB3),
                      size: 20,
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Travelers',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFFB47EB3),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '$peopleNum ${int.tryParse(peopleNum) == 1 ? 'Person' : 'People'}',
                          style: const TextStyle(
                            fontSize: 16,
                            color: Color(0xFF495057),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: 16),
              
              // Travel Tips Section
              Container(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.travel_explore,
                          color: const Color(0xFFB47EB3),
                          size: 20,
                        ),
                        const SizedBox(width: 12),
                        const Text(
                          'Trip Itinerary',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFFB47EB3),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8F9FA),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: const Color(0xFFE9ECEF),
                          width: 1,
                        ),
                      ),
                      child: Text(
                        geminiContent,
                        style: const TextStyle(
                          fontSize: 16,
                          height: 1.6,
                          color: Color(0xFF495057),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}
