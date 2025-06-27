import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import '../models/group_chat_message.dart';
import 'poll_card.dart';
import 'package:intl/intl.dart';

class PollDetailPage extends StatefulWidget {
  final GroupChatMessage pollMessage;
  final String pollKey;
  final String currentUserId;
  final Future<void> Function(String pollKey, int choiceIndex, Map votes, bool ended) onVote;
  final Future<void> Function(String pollKey) onEndPoll;

  const PollDetailPage({
    Key? key,
    required this.pollMessage,
    required this.pollKey,
    required this.currentUserId,
    required this.onVote,
    required this.onEndPoll,
  }) : super(key: key);

  @override
  State<PollDetailPage> createState() => _PollDetailPageState();
}

class _PollDetailPageState extends State<PollDetailPage> {
  @override
  Widget build(BuildContext context) {
    final groupId = (ModalRoute.of(context)?.settings.arguments as Map?)?['groupId'] ?? '';
    final pollRef = FirebaseDatabase.instance.ref().child('Groups').child(groupId).child('chat').child(widget.pollKey);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Poll Details'),
        backgroundColor: const Color(0xFFF8BBD0), // Pink theme
      ),
      body: StreamBuilder<DatabaseEvent>(
        stream: pollRef.onValue,
        builder: (context, snapshot) {
          if (!snapshot.hasData || snapshot.data?.snapshot.value == null) {
            return const Center(child: CircularProgressIndicator());
          }
          final pollMap = Map<String, dynamic>.from(snapshot.data!.snapshot.value as Map);
          final pollMsg = GroupChatMessage.fromMap(pollMap);
          final ended = pollMsg.ended ?? false;
          final choices = List<String>.from(pollMsg.choices ?? []);
          final votesRaw = pollMsg.votes ?? {};
          Map<String, List<String>> votes = {};
          if (votesRaw is Map) {
            votesRaw.forEach((k, v) {
              if (v is List) {
                votes[k] = List<String>.from(v);
              } else if (v is String && v.isNotEmpty) {
                votes[k] = [v];
              } else {
                votes[k] = [];
              }
            });
          } else if (votesRaw is List) {
            for (var i = 0; i < choices.length; i++) {
              final v = i < votesRaw.length ? votesRaw[i] : [];
              if (v is List) {
                votes['$i'] = List<String>.from(v);
              } else if (v is String && v.isNotEmpty) {
                votes['$i'] = [v];
              } else {
                votes['$i'] = [];
              }
            }
          }
          for (var i = 0; i < choices.length; i++) {
            votes['$i'] ??= [];
          }
          final allVoters = <String>{};
          votes.values.forEach((list) => allVoters.addAll(list));
          final uniqueVotersCount = allVoters.length == 0 ? 1 : allVoters.length;

          return SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 3.0, vertical: 16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Question in a full-width container
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
                    decoration: BoxDecoration(
                      color: Color(0xFFFFFFFF),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      pollMsg.question ?? '',
                      style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFFD81B60)),
                    ),
                  ),
                  const SizedBox(height: 1),
                  // Poll created by ... and date, in a container, text at ends
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                      color: Color(0xFFFFFFFF),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Poll created by ${pollMsg.senderName}',
                          style: const TextStyle(fontSize: 15, color: Color(
                              0xFF000000)),
                        ),
                        Text(
                          DateFormat('yyyy-MM-dd HH:mm').format(pollMsg.timestamp),
                          style: const TextStyle(fontSize: 13, color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                  // Choices, each in its own container
                  ...List.generate(choices.length, (i) {
                    final voters = votes['$i'] ?? [];
                    final percent = (voters.length / uniqueVotersCount * 100);
                    return Container(
                      width: double.infinity,
                      margin: const EdgeInsets.only(bottom: 18),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Color(0xFFF8BBD0), width: 1.2),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.pink.shade50,
                            blurRadius: 2,
                            offset: Offset(0, 1),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            choices[i],
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Color(0xFFD81B60)),
                          ),
                          const SizedBox(height: 8),
                          Stack(
                            children: [
                              Container(
                                height: 18,
                                decoration: BoxDecoration(
                                  color: Colors.pink.shade100,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              FractionallySizedBox(
                                widthFactor: percent / 100,
                                child: Container(
                                  height: 18,
                                  decoration: BoxDecoration(
                                    color: Color(0xFFD81B60),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                              ),
                              Positioned.fill(
                                child: Center(
                                  child: Text(
                                    '${percent.toStringAsFixed(1)}%  •  ${voters.length} vote${voters.length == 1 ? '' : 's'}',
                                    style: const TextStyle(fontSize: 13, color: Colors.white, fontWeight: FontWeight.bold, shadows: [Shadow(blurRadius: 2, color: Colors.black26)]),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Text("Voter(s)",
                            style: const TextStyle( color: Color(0xFF000000)),),
                          const SizedBox(height: 10),
                          if (voters.isNotEmpty)
                            FutureBuilder<DatabaseEvent>(
                              future: FirebaseDatabase.instance.ref('Users').once(),
                              builder: (context, userSnap) {
                                if (!userSnap.hasData || userSnap.data?.snapshot.value == null) {
                                  return const SizedBox();
                                }
                                final usersMap = Map<String, dynamic>.from(userSnap.data!.snapshot.value as Map);
                                final voterWidgets = voters.map((uid) {
                                  final user = usersMap[uid];
                                  final username = (user != null && user['username'] != null) ? user['username'] as String : uid;
                                  final profilePic = (user != null && user['profile_pic'] != null) ? user['profile_pic'] as String : null;
                                  return Padding(
                                    padding: const EdgeInsets.only(right: 10, bottom: 6),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        CircleAvatar(
                                          radius: 16,
                                          backgroundImage: profilePic != null ? NetworkImage(profilePic) : null,
                                          backgroundColor: Colors.pink.shade100,
                                          child: profilePic == null ? Icon(Icons.person, color: Colors.white) : null,
                                        ),
                                        const SizedBox(width: 7),
                                        Text(username, style: const TextStyle(fontWeight: FontWeight.w500, color: Color(0xFFD81B60))),
                                      ],
                                    ),
                                  );
                                }).toList();
                                return Wrap(
                                  spacing: 0,
                                  runSpacing: 0,
                                  children: voterWidgets,
                                );
                              },
                            ),
                        ],
                      ),
                    );
                  }),
                  const SizedBox(height: 18),
                  if (ended)
                    Row(
                      children: const [
                        Icon(Icons.stop_circle, color: Colors.black),
                        SizedBox(width: 8),
                        Text('Poll Ended', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 16)),
                      ],
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
