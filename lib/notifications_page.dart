import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

class NotificationsPage extends StatefulWidget {
  const NotificationsPage({Key? key}) : super(key: key);

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  final _database = FirebaseDatabase.instance;
  List<Map<String, dynamic>> notifications = [];
  bool isLoading = true;
  int unreadCount = 0;

  @override
  void initState() {
    super.initState();
    _fetchNotifications();
    // Check for settled reminders every time the page loads
    Future.delayed(const Duration(milliseconds: 500), () {
      _removeSettledReminders();
    });
  }

  void _fetchNotifications() {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    if (currentUserId == null) return;

    final notificationsRef = _database.ref('Users/$currentUserId/notifications');
    notificationsRef.onValue.listen((event) {
      final notificationsData = event.snapshot.value as Map<dynamic, dynamic>?;
      List<Map<String, dynamic>> tempNotifications = [];

      if (notificationsData != null) {
        notificationsData.forEach((key, value) {
          final notification = Map<String, dynamic>.from(value);
          notification['id'] = key;
          tempNotifications.add(notification);
        });

        // Sort by timestamp, newest first
        tempNotifications.sort((a, b) {
          final aTimestamp = a['timestamp'] ?? 0;
          final bTimestamp = b['timestamp'] ?? 0;
          return bTimestamp.compareTo(aTimestamp);
        });
      }

      setState(() {
        notifications = tempNotifications;
        unreadCount = tempNotifications.where((n) => n['isRead'] != true).length;
        isLoading = false;
      });
    });
  }

  Future<void> _markAsRead(String notificationId) async {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    if (currentUserId == null) return;

    try {
      await _database
          .ref('Users/$currentUserId/notifications/$notificationId/isRead')
          .set(true);
    } catch (e) {
      print("Error marking notification as read: $e");
    }
  }

  Future<void> _deleteNotification(String notificationId) async {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    if (currentUserId == null) return;

    try {
      await _database
          .ref('Users/$currentUserId/notifications/$notificationId')
          .remove();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error deleting notification: $e")),
      );
    }
  }

  String _formatDateTime(int timestamp) {
    final dateTime = DateTime.fromMillisecondsSinceEpoch(timestamp);
    return DateFormat('MMM dd, yyyy HH:mm').format(dateTime);
  }

  Future<void> _removeSettledReminders() async {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    if (currentUserId == null) return;

    // Get all reminder notifications
    final reminderNotifications = notifications.where((n) => n['type'] == 'reminder').toList();
    
    for (var notification in reminderNotifications) {
      final groupId = notification['groupId'];
      final creditorId = notification['creditorId'];
      final amount = notification['amount']?.toDouble() ?? 0.0;
      
      if (groupId != null && creditorId != null) {
        // Check if this debt has been settled
        final settlementsRef = _database.ref('Groups/$groupId/settlement');
        final settlementsSnap = await settlementsRef.get();
        
        if (settlementsSnap.exists) {
          final settlementsData = settlementsSnap.value as Map<dynamic, dynamic>;
          bool isSettled = false;
          
          // Check if there's a settlement that covers this debt
          for (var settlement in settlementsData.values) {
            if (settlement is Map) {
              final settlementMap = Map<String, dynamic>.from(settlement);
              final payer = settlementMap['payer'];
              final payee = settlementMap['payee'];
              final settleAmount = settlementMap['amount']?.toDouble() ?? 0.0;
              
              // If current user paid the creditor an amount >= reminder amount
              if (payer == currentUserId && 
                  payee == creditorId && 
                  settleAmount >= amount) {
                isSettled = true;
                break;
              }
            }
          }
          
          // Remove the notification if settled
          if (isSettled) {
            await _deleteNotification(notification['id']);
          }
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        backgroundColor: const Color(0xfffbe5ec),
        actions: [
          if (notifications.where((n) => n['isRead'] != true).isNotEmpty)
            TextButton(
              onPressed: () async {
                final currentUserId = FirebaseAuth.instance.currentUser?.uid;
                if (currentUserId == null) return;

                for (var notification in notifications) {
                  if (notification['isRead'] != true) {
                    await _markAsRead(notification['id']);
                  }
                }
              },
              child: const Text(
                'Mark All Read',
                style: TextStyle(color: Color(0xFFc96077)),
              ),
            ),
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : notifications.isEmpty
              ? const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.notifications_off,
                        size: 64,
                        color: Colors.grey,
                      ),
                      SizedBox(height: 16),
                      Text(
                        'No notifications yet',
                        style: TextStyle(fontSize: 18, color: Colors.grey),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  itemCount: notifications.length,
                  itemBuilder: (context, index) {
                    final notification = notifications[index];
                    final isRead = notification['isRead'] == true;
                    final type = notification['type'] ?? '';
                    final message = notification['message'] ?? '';
                    final timestamp = notification['timestamp'] ?? 0;
                    final groupName = notification['groupName'] ?? '';

                    IconData icon;
                    Color iconColor;
                    switch (type) {
                      case 'reminder':
                        icon = Icons.notifications;
                        iconColor = Colors.orange;
                        break;
                      default:
                        icon = Icons.info;
                        iconColor = Colors.blue;
                    }

                    return Card(
                      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                      color: isRead ? Colors.white : const Color(0xfffff5f5),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: iconColor.withOpacity(0.2),
                          child: Icon(icon, color: iconColor),
                        ),
                        title: Text(
                          message,
                          style: TextStyle(
                            fontWeight: isRead ? FontWeight.normal : FontWeight.bold,
                          ),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (groupName.isNotEmpty)
                              Text(
                                'Group: $groupName',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Color(0xFFc96077),
                                ),
                              ),
                            Text(
                              _formatDateTime(timestamp),
                              style: const TextStyle(fontSize: 12),
                            ),
                          ],
                        ),
                        trailing: PopupMenuButton<String>(
                          onSelected: (value) async {
                            switch (value) {
                              case 'read':
                                await _markAsRead(notification['id']);
                                break;
                              case 'delete':
                                await _deleteNotification(notification['id']);
                                break;
                            }
                          },
                          itemBuilder: (context) => [
                            if (!isRead)
                              const PopupMenuItem(
                                value: 'read',
                                child: Row(
                                  children: [
                                    Icon(Icons.mark_email_read, size: 20),
                                    SizedBox(width: 8),
                                    Text('Mark as Read'),
                                  ],
                                ),
                              ),
                            const PopupMenuItem(
                              value: 'delete',
                              child: Row(
                                children: [
                                  Icon(Icons.delete, size: 20, color: Colors.red),
                                  SizedBox(width: 8),
                                  Text('Delete', style: TextStyle(color: Colors.red)),
                                ],
                              ),
                            ),
                          ],
                        ),
                        onTap: isRead ? null : () => _markAsRead(notification['id']),
                      ),
                    );
                  },
                ),
    );
  }
}
