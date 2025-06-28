import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';

class NotificationIconWithBadge extends StatefulWidget {
  final VoidCallback onPressed;

  const NotificationIconWithBadge({
    Key? key,
    required this.onPressed,
  }) : super(key: key);

  @override
  State<NotificationIconWithBadge> createState() => _NotificationIconWithBadgeState();
}

class _NotificationIconWithBadgeState extends State<NotificationIconWithBadge> {
  final _database = FirebaseDatabase.instance;
  int unreadCount = 0;

  @override
  void initState() {
    super.initState();
    _listenToNotifications();
  }

  void _listenToNotifications() {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    if (currentUserId == null) return;

    final notificationsRef = _database.ref('Users/$currentUserId/notifications');
    notificationsRef.onValue.listen((event) {
      final notificationsData = event.snapshot.value as Map<dynamic, dynamic>?;
      int count = 0;

      if (notificationsData != null) {
        notificationsData.forEach((key, value) {
          if (value is Map && value['isRead'] != true) {
            count++;
          }
        });
      }

      setState(() {
        unreadCount = count;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        IconButton(
          icon: const Icon(Icons.notifications_outlined),
          tooltip: 'Notifications',
          onPressed: widget.onPressed,
        ),
        if (unreadCount > 0)
          Positioned(
            right: 8,
            top: 8,
            child: Container(
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                color: Colors.red,
                borderRadius: BorderRadius.circular(10),
              ),
              constraints: const BoxConstraints(
                minWidth: 16,
                minHeight: 16,
              ),
              child: Text(
                unreadCount > 99 ? '99+' : unreadCount.toString(),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
      ],
    );
  }
}
