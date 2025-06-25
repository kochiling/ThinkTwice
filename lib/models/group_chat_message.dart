class GroupChatMessage {
  final String senderId;
  final String senderName;
  final String senderProfile;
  final String text;
  final String imageUrl;
  final String type; // 'text' or 'image'
  final DateTime timestamp;
  final String? question;
  final List<String>? choices;
  final List<List<String>>? votes;
  final bool? ended;

  GroupChatMessage({
    required this.senderId,
    required this.senderName,
    required this.senderProfile,
    required this.text,
    required this.imageUrl,
    required this.type,
    required this.timestamp,
    this.question,
    this.choices,
    this.votes,
    this.ended,
  });

  factory GroupChatMessage.fromMap(Map<String, dynamic> map) {
    return GroupChatMessage(
      senderId: map['senderId'] ?? '',
      senderName: map['senderName'] ?? '',
      senderProfile: map['senderProfile'] ?? '',
      text: map['text'] ?? '',
      imageUrl: map['imageUrl'] ?? '',
      type: map['type'] ?? 'text',
      timestamp: DateTime.tryParse(map['timestamp'] ?? '') ?? DateTime.now(),
      question: map['question'],
      choices: (map['choices'] as List?)?.map((e) => e.toString()).toList() ?? <String>[],
      votes: (map['votes'] is List)
          ? (map['votes'] as List?)?.map((v) => v == null ? <String>[] : List<String>.from(v)).toList() ?? <List<String>>[]
          : (map['votes'] is Map)
              ? List.generate(
                  (map['choices'] as List?)?.length ?? 0,
                  (i) => List<String>.from((map['votes'] as Map)['$i'] ?? []),
                )
              : <List<String>>[],
      ended: map['ended'] ?? false,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'senderId': senderId,
      'senderName': senderName,
      'senderProfile': senderProfile,
      'text': text,
      'imageUrl': imageUrl,
      'type': type,
      'timestamp': timestamp.toIso8601String(),
      'question': question,
      'choices': choices,
      'votes': votes,
      'ended': ended,
    };
  }
}
