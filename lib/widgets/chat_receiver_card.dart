import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/group_chat_message.dart';

class ChatReceiverCard extends StatelessWidget {
  final GroupChatMessage message;
  const ChatReceiverCard({Key? key, required this.message}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final showDate = now.difference(message.timestamp).inHours >= 24;
    String dateString = DateFormat('yyyy-MM-dd').format(message.timestamp);
    String timeString = _formatTime(message.timestamp);
    return Row(
      mainAxisAlignment: MainAxisAlignment.start,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        // Profile picture outside the chat content
        Padding(
          padding: const EdgeInsets.only(right: 8, left: 6, bottom: 2),
          child: CircleAvatar(
            radius: 16,
            backgroundImage: NetworkImage(message.senderProfile),
          ),
        ),
        Flexible(
          flex: 7,
          child: Container(
            margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFCDB4DB), width: 1),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Username on top, bold
                Text(
                  message.senderName,
                  style: const TextStyle(
                    color: Color(0xFF9D4EDD),
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 4),
                if (message.type == 'image' && message.imageUrl.isNotEmpty)
                  GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => FullScreenImagePage(imageUrl: message.imageUrl),
                        ),
                      );
                    },
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.network(
                        message.imageUrl,
                        width: 180,
                        height: 180,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) => const Icon(Icons.broken_image, size: 60, color: Colors.black26),
                      ),
                    ),
                  )
                else
                  Text(
                    message.text,
                    style: const TextStyle(color: Color(0xFF9D4EDD), fontSize: 16),
                  ),
                const SizedBox(height: 4),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      timeString,
                      style: const TextStyle(color: Colors.black38, fontSize: 10),
                    ),
                    if (showDate) ...[
                      const SizedBox(width: 8),
                      Text(
                        dateString,
                        style: const TextStyle(color: Colors.black38, fontSize: 10),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ),
        const Spacer(),
      ],
    );
  }

  String _formatTime(DateTime time) {
    return "${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}";
  }
}

class FullScreenImagePage extends StatelessWidget {
  final String imageUrl;
  const FullScreenImagePage({Key? key, required this.imageUrl}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
      ),
      body: Center(
        child: InteractiveViewer(
          minScale: 0.5,
          maxScale: 4,
          child: Image.network(
            imageUrl,
            fit: BoxFit.contain,
            errorBuilder: (context, error, stackTrace) => const Icon(Icons.broken_image, size: 80, color: Colors.white54),
          ),
        ),
      ),
    );
  }
}
