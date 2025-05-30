import 'package:flutter/material.dart';

class GroupDetailsPage extends StatelessWidget {
  final String groupId;
  final String homeCurrency;

  const GroupDetailsPage({
    Key? key,
    required this.groupId,
    required this.homeCurrency,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Group Details")),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Group ID: $groupId", style: TextStyle(fontSize: 16)),
            SizedBox(height: 8),
            Text("Home Currency: $homeCurrency", style: TextStyle(fontSize: 16)),
            // You can fetch more group data here using groupId
          ],
        ),
      ),
    );
  }
}
