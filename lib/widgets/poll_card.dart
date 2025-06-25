import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:intl/intl.dart';
import '../models/group_chat_message.dart';

class PollCard extends StatefulWidget {
  final GroupChatMessage msg;
  final bool isMe;
  final String? pollKey;
  final String currentUserId;
  final Future<void> Function(String pollKey, int choiceIndex, Map votes, bool ended) onVote;
  final Future<void> Function(String pollKey) onEndPoll;
  final bool showVoters;

  const PollCard({
    Key? key,
    required this.msg,
    required this.isMe,
    required this.pollKey,
    required this.currentUserId,
    required this.onVote,
    required this.onEndPoll,
    this.showVoters = false,
  }) : super(key: key);

  @override
  State<PollCard> createState() => _PollCardState();
}

class _PollCardState extends State<PollCard> {
  bool _loadingVoters = false;
  Map<String, String> _usernames = {};

  Future<void> _fetchUsernames(List<String> userIds) async {
    setState(() => _loadingVoters = true);
    final usersSnap = await FirebaseDatabase.instance.ref().child('Users').once();
    final usersMap = usersSnap.snapshot.value != null
        ? Map<String, dynamic>.from(usersSnap.snapshot.value as Map)
        : <String, dynamic>{};
    final names = <String, String>{};
    for (final uid in userIds) {
      final user = usersMap[uid];
      if (user != null && user['username'] != null) {
        names[uid] = user['username'] as String;
      } else {
        names[uid] = uid;
      }
    }
    setState(() {
      _usernames = names;
      _loadingVoters = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final ended = widget.msg.ended ?? false;
    final numChoices = (widget.msg.choices ?? []).length;
    final List<String> choices = List<String>.from(widget.msg.choices ?? []);
    final votesRaw = widget.msg.votes ?? {};
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
      for (var i = 0; i < numChoices; i++) {
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
    for (var i = 0; i < numChoices; i++) {
      votes['$i'] ??= [];
    }
    // Unique voters for accurate percentage
    final allVoters = <String>{};
    votes.values.forEach((list) => allVoters.addAll(list));
    final uniqueVotersCount = allVoters.length == 0 ? 1 : allVoters.length;
    // User's selected choices
    List<int> userChoices = [];
    votes.forEach((k, v) {
      if (v.contains(widget.currentUserId)) userChoices.add(int.parse(k));
    });

    return Stack(
      children: [
        Card(
          margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 55),
          elevation: 2,
          color: widget.isMe ? const Color(0xFFCDB4DB) : Colors.white, // Purple if sender, white if not
          child: Padding(
            padding: const EdgeInsets.all(12.0),
            child: Column(
              crossAxisAlignment: widget.isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                // Profile name (top, indented)
                Align(
                  alignment: widget.isMe ? Alignment.centerRight : Alignment.centerLeft,
                  child: Padding(
                    padding: widget.isMe
                        ? const EdgeInsets.only(right: 2.0)
                        : const EdgeInsets.only(left: 2.0),
                    child: Text(
                      widget.msg.senderName,
                      style: TextStyle(fontWeight: FontWeight.bold, color: widget.isMe ? Colors.white : Colors.black),
                    ),
                  ),
                ),
                const SizedBox(height: 2),
                // Question
                Align(
                  alignment: widget.isMe ? Alignment.centerRight : Alignment.centerLeft,
                  child: Text(
                    widget.msg.question ?? '',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: widget.isMe ? Colors.white : Colors.black),
                  ),
                ),
                const SizedBox(height: 10),
                ...List.generate(choices.length, (i) {
                  final voters = votes['$i'] ?? [];
                  final percent = (voters.length / uniqueVotersCount * 100).toStringAsFixed(1);
                  final isSelected = voters.contains(widget.currentUserId);
                  return InkWell(
                    onTap: ended
                        ? null
                        : () async {
                            // Toggle vote for multi-vote (WhatsApp style)
                            Map<String, List<String>> votesMap = {};
                            votes.forEach((k, v) => votesMap[k] = List<String>.from(v));
                            final userVotes = votesMap['$i'] ?? [];
                            if (userVotes.contains(widget.currentUserId)) {
                              userVotes.remove(widget.currentUserId);
                            } else {
                              userVotes.add(widget.currentUserId);
                            }
                            votesMap['$i'] = userVotes;
                            await widget.onVote(widget.pollKey!, i, votesMap, ended);
                            setState(() {});
                          },
                    child: Container(
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? (widget.isMe ? Color(0xFFDED4ED) : Colors.deepPurple.shade100)
                            : (widget.isMe ? Colors.grey.shade100 : Colors.grey.shade100),
                        borderRadius: BorderRadius.circular(10),
                        border: isSelected ? Border.all(color: Colors.deepPurple, width: 2) : null,
                      ),
                      child: ListTile(
                        title: Text(
                          choices[i],
                          style: TextStyle(
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                            color: widget.isMe ? Colors.black : Colors.black,
                          ),
                        ),
                        subtitle: Row(
                          children: [
                            Text('$percent%', style: TextStyle(fontSize: 13, color: widget.isMe ? Colors.blueGrey : Colors.deepPurple)),
                            const SizedBox(width: 10),
                            Text('${voters.length} vote${voters.length == 1 ? '' : 's'}', style: TextStyle(fontSize: 13, color: widget.isMe ? Colors.blueGrey : Colors.black)),
                            if (widget.showVoters && voters.isNotEmpty)
                              IconButton(
                                icon: Icon(Icons.info_outline, size: 18, color: widget.isMe ? Colors.blueGrey : Colors.deepPurple),
                                onPressed: () async {
                                  await _fetchUsernames(voters);
                                  showDialog(
                                    context: context,
                                    builder: (context) => AlertDialog(
                                      title: const Text('Voters'),
                                      content: _loadingVoters
                                          ? const CircularProgressIndicator()
                                          : Column(
                                              mainAxisSize: MainAxisSize.min,
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: voters.map((uid) => Text(_usernames[uid] ?? uid)).toList(),
                                            ),
                                      actions: [
                                        TextButton(
                                          child: const Text('Close'),
                                          onPressed: () => Navigator.pop(context),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                          ],
                        ),
                      ),
                    ),
                  );
                }),
                const SizedBox(height: 10),
                if (widget.isMe && !ended)
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton.icon(
                      icon: const Icon(Icons.stop_circle, color: Colors.red),
                      label: const Text('End Poll', style: TextStyle(color: Colors.red)),
                      onPressed: widget.pollKey != null ? () => widget.onEndPoll(widget.pollKey!) : null,
                    ),
                  ),
                if (ended)
                  Align(
                    alignment: Alignment.centerRight,
                    child: Text('Poll Ended', style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold)),
                  ),
                // Date at the bottom (right or left)
                Padding(
                  padding: widget.isMe
                      ? const EdgeInsets.only(top: 8.0, right: 2.0)
                      : const EdgeInsets.only(top: 8.0, left: 2.0),
                  child: Align(
                    alignment: widget.isMe ? Alignment.centerRight : Alignment.centerLeft,
                    child: Text(
                      DateFormat('yyyy-MM-dd HH:mm').format(widget.msg.timestamp),
                      style: TextStyle(fontSize: 12, color: widget.isMe ? Colors.white70 : Colors.grey),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        // Profile image at the bottom (right or left)
        Positioned(
          bottom: 8,
          right: widget.isMe ? 8 : null,
          left: widget.isMe ? null : 8,
          child: CircleAvatar(
            radius: 20,
            backgroundImage: NetworkImage(widget.msg.senderProfile),
            backgroundColor: Colors.grey.shade200,
          ),
        ),
      ],
    );
  }
}