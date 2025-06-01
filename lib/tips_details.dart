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
        title: Text(title),
        backgroundColor: const Color(0xFFF6B1C3), // Light pink
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Title
            Text(
              title,
              style: const TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: Color(0xFFB47EB3), // Soft purple
              ),
            ),
            const SizedBox(height: 12),

            // Destination
            Text(
              destination,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w500,
                color: Color(0xFF8C6BB1), // Slightly deeper purple
              ),
            ),
            const SizedBox(height: 16),

            // Dates
            Text(
              'Dates: $startDate - $endDate',
              style: const TextStyle(
                fontSize: 18,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 10),

            // People
            Text(
              'People: $peopleNum',
              style: const TextStyle(
                fontSize: 18,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 30),

            // Section Title
            const Text(
              'Travel Tips',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Color(0xFFB47EB3),
              ),
            ),
            const SizedBox(height: 12),

            // Content Box
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFFDE2E4), // Soft pink background
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(
                geminiContent,
                style: const TextStyle(fontSize: 16, height: 1.5),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
