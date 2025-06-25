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
  late bool ended;
  late int numChoices;
  late List<String> choices;
  late String senderName;
  late String senderProfile;
  late DateTime timestamp;
  late dynamic votesData;
  late String question;

  @override
  void initState() {
    super.initState();
    _extractFields();
  }

  @override
  void didUpdateWidget(covariant PollCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    _extractFields();
  }

  void _extractFields() {
    // Extract all needed fields from widget.msg for local use
    ended = widget.msg.ended ?? false;
    numChoices = (widget.msg.choices ?? []).length;
    choices = List<String>.from(widget.msg.choices ?? []);
    senderName = widget.msg.senderName;
    senderProfile = widget.msg.senderProfile;
    timestamp = widget.msg.timestamp;
    votesData = widget.msg.votes;
    question = widget.msg.question ?? '';
  }

  @override
  Widget build(BuildContext context) {
    List<List<String>> votesList;
    if (votesData is List) {
      final rawList = (votesData as List?)?.map((v) => v == null ? <String>[] : List<String>.from(v)).toList() ?? <List<String>>[];
      votesList = List.generate(numChoices, (i) => i < rawList.length ? rawList[i] : <String>[]);
    } else if (votesData is Map) {
      final map = Map<String, dynamic>.from(votesData as Map);
      votesList = List.generate(
        numChoices,
        (i) => List<String>.from(map['$i'] ?? []),
      );
    } else {
      votesList = List.generate(numChoices, (i) => <String>[]);
    }
    final totalVotes = votesList.fold<int>(0, (sum, v) => sum + v.length);
    final userVotedIndex = votesList.indexWhere((v) => v.contains(widget.currentUserId));
    return Row(
      mainAxisAlignment: widget.isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (!widget.isMe)
          Padding(
            padding: const EdgeInsets.only(right: 8, left: 6, bottom: 2),
            child: CircleAvatar(radius: 16, backgroundImage: NetworkImage(senderProfile)),
          ),
        Flexible(
          flex: 7,
          child: Container(
            margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: widget.isMe ? const Color(0xFFCDB4DB) : Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: widget.isMe ? null : Border.all(color: const Color(0xFFCDB4DB)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  senderName,
                  style: TextStyle(
                    color: widget.isMe ? Colors.white : const Color(0xFF9D4EDD),
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  question,
                  style: TextStyle(
                    color: widget.isMe ? Colors.white : const Color(0xFF9D4EDD),
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  DateFormat('yyyy-MM-dd HH:mm').format(timestamp),
                  style: TextStyle(
                    color: widget.isMe ? Colors.white70 : Colors.black38,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 8),
                ...List.generate(choices.length, (i) {
                  final choice = choices[i];
                  final choiceVotes = votesList.length > i ? votesList[i].length : 0;
                  final percent = totalVotes > 0 ? (choiceVotes / totalVotes * 100).toStringAsFixed(0) : '0';
                  final voted = userVotedIndex == i;
                  // Debug log for percent and vote count
                  // ignore: avoid_print
                  print('[PollCard] Choice: $choice | Votes: $choiceVotes | Percent: $percent% | Voted: $voted | User: ${widget.currentUserId} | VotesList: ${votesList[i]}');
                  return Container(
                    margin: const EdgeInsets.symmetric(vertical: 2),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: voted
                          ? Colors.deepPurple.withOpacity(0.18)
                          : (widget.isMe ? Colors.white24 : const Color(0xFFF3E8FF)),
                      borderRadius: BorderRadius.circular(10),
                      border: voted ? Border.all(color: Colors.deepPurple, width: 2) : null,
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: (!ended && userVotedIndex == -1)
                                ? () async {
                                    Map<String, dynamic> votesMap;
                                    if (votesData is Map) {
                                      votesMap = Map<String, dynamic>.from(votesData as Map);
                                    } else if (votesData is List) {
                                      final rawList = (votesData as List?)?.map((v) => v == null ? <String>[] : List<String>.from(v)).toList() ?? <List<String>>[];
                                      votesMap = { for (var j = 0; j < numChoices; j++) '$j': j < rawList.length ? rawList[j] : <String>[] };
                                    } else {
                                      votesMap = { for (var j = 0; j < numChoices; j++) '$j': <String>[] };
                                    }
                                    // Debug: print the votesMap before voting
                                    print('[PollCard] onTap votesMap: ' + votesMap.toString());
                                    await widget.onVote(widget.pollKey!, i, votesMap, ended);
                                    setState(() {}); // Rebuild after voting
                                  }
                                : null,
                            child: Text(
                              choice,
                              style: TextStyle(
                                color: voted ? Colors.deepPurple : (widget.isMe ? Colors.white : const Color(0xFF9D4EDD)),
                                fontSize: 15,
                                fontWeight: voted ? FontWeight.bold : FontWeight.normal,
                              ),
                            ),
                          ),
                        ),
                        Text('$choiceVotes', style: TextStyle(fontSize: 13, color: Colors.grey[700], fontWeight: FontWeight.bold)),
                        const SizedBox(width: 4),
                        Text('($percent%)', style: TextStyle(fontSize: 12, color: Colors.grey[500])),
                        if (choiceVotes > 0)
                          GestureDetector(
                            onTap: () async {
                              final userIds = votesList.length > i ? votesList[i] : [];
                              if (userIds.isEmpty) return;
                              final usersSnap = await FirebaseDatabase.instance.ref().child('Users').once();
                              final usersMap = usersSnap.snapshot.value != null
                                  ? Map<String, dynamic>.from(usersSnap.snapshot.value as Map)
                                  : <String, dynamic>{};
                              final voters = userIds.map((uid) {
                                final user = usersMap[uid];
                                if (user != null && user['username'] != null) {
                                  return user['username'] as String;
                                }
                                return uid;
                              }).toList();
                              showDialog(
                                context: context,
                                builder: (context) => AlertDialog(
                                  title: Text('Voters'),
                                  content: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: voters.isEmpty
                                        ? [const Text('No votes yet.')]
                                        : voters.map((v) => Text(v)).toList(),
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
                            child: const Padding(
                              padding: EdgeInsets.only(left: 6),
                              child: Icon(Icons.info_outline, size: 16, color: Colors.deepPurple),
                            ),
                          ),
                      ],
                    ),
                  );
                }),
                Padding(
                  padding: const EdgeInsets.only(top: 8.0),
                  child: Text(
                    'Total voters: $totalVotes',
                    style: TextStyle(fontSize: 13, color: Colors.deepPurple, fontWeight: FontWeight.w600),
                  ),
                ),
                const SizedBox(height: 8),
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
                    child: Text('Poll Ended', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                  ),
              ],
            ),
          ),
        ),
        if (widget.isMe)
          Padding(
            padding: const EdgeInsets.only(left: 6, right: 8, bottom: 2),
            child: CircleAvatar(radius: 16, backgroundImage: NetworkImage(senderProfile)),
          ),
      ],
    );
  }
}

// import 'package:flutter/material.dart';
// import 'package:firebase_database/firebase_database.dart';
// import 'package:intl/intl.dart';
// import '../models/group_chat_message.dart';

// class PollCard extends StatelessWidget {
//   final GroupChatMessage msg;
//   final bool isMe;
//   final String? pollKey;
//   final String currentUserId;
//   final Future<void> Function(String pollKey, int choiceIndex, Map votes, bool ended) onVote;
//   final Future<void> Function(String pollKey) onEndPoll;
//   final bool showVoters;

//   const PollCard({
//     Key? key,
//     required this.msg,
//     required this.isMe,
//     required this.pollKey,
//     required this.currentUserId,
//     required this.onVote,
//     required this.onEndPoll,
//     this.showVoters = false,
//   }) : super(key: key);

//   @override
//   Widget build(BuildContext context) {
//     final ended = msg.ended ?? false;
//     // Support both Map and List for votes, always pad to match choices length
//     int numChoices = (msg.choices ?? []).length;
//     List<List<String>> votesList;
//     if (msg.votes is List) {
//       final rawList = (msg.votes as List?)?.map((v) => v == null ? <String>[] : List<String>.from(v)).toList() ?? <List<String>>[];
//       // Pad with empty lists if needed
//       votesList = List.generate(numChoices, (i) => i < rawList.length ? rawList[i] : <String>[]);
//     } else if (msg.votes is Map) {
//       final map = Map<String, dynamic>.from(msg.votes as Map);
//       votesList = List.generate(
//         numChoices,
//         (i) => List<String>.from(map['$i'] ?? []),
//       );
//     } else {
//       votesList = List.generate(numChoices, (i) => <String>[]);
//     }
//     final totalVotes = votesList.fold<int>(0, (sum, v) => sum + v.length);
//     final userVotedIndex = votesList.indexWhere((v) => v.contains(currentUserId));
//     return Row(
//       mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
//       crossAxisAlignment: CrossAxisAlignment.start,
//       children: [
//         if (!isMe)
//           Padding(
//             padding: const EdgeInsets.only(right: 8, left: 6, bottom: 2),
//             child: CircleAvatar(radius: 16, backgroundImage: NetworkImage(msg.senderProfile)),
//           ),
//         Flexible(
//           flex: 7,
//           child: Container(
//             margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
//             padding: const EdgeInsets.all(14),
//             decoration: BoxDecoration(
//               color: isMe ? const Color(0xFFCDB4DB) : Colors.white,
//               borderRadius: BorderRadius.circular(16),
//               border: isMe ? null : Border.all(color: const Color(0xFFCDB4DB)),
//             ),
//             child: Column(
//               crossAxisAlignment: CrossAxisAlignment.start,
//               children: [
//                 Text(
//                   msg.senderName,
//                   style: TextStyle(
//                     color: isMe ? Colors.white : const Color(0xFF9D4EDD),
//                     fontWeight: FontWeight.bold,
//                     fontSize: 14,
//                   ),
//                 ),
//                 const SizedBox(height: 8),
//                 Text(
//                   msg.question ?? '',
//                   style: TextStyle(
//                     color: isMe ? Colors.white : const Color(0xFF9D4EDD),
//                     fontWeight: FontWeight.w600,
//                     fontSize: 16,
//                   ),
//                 ),
//                 const SizedBox(height: 4),
//                 Text(
//                   DateFormat('yyyy-MM-dd HH:mm').format(msg.timestamp),
//                   style: TextStyle(
//                     color: isMe ? Colors.white70 : Colors.black38,
//                     fontSize: 12,
//                   ),
//                 ),
//                 const SizedBox(height: 8),
//                 ...List.generate((msg.choices ?? []).length, (i) {
//                   final choice = msg.choices![i];
//                   final choiceVotes = votesList.length > i ? votesList[i].length : 0;
//                   final percent = totalVotes > 0 ? (choiceVotes / totalVotes * 100).toStringAsFixed(0) : '0';
//                   final voted = userVotedIndex == i;
//                   // Debug log for percent and vote count
//                   // ignore: avoid_print
//                   print('[PollCard] Choice: $choice | Votes: $choiceVotes | Percent: $percent% | Voted: $voted | User: $currentUserId | VotesList: ${votesList[i]}');
//                   return Container(
//                     margin: const EdgeInsets.symmetric(vertical: 2),
//                     padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
//                     decoration: BoxDecoration(
//                       color: voted
//                           ? Colors.deepPurple.withOpacity(0.18)
//                           : (isMe ? Colors.white24 : const Color(0xFFF3E8FF)),
//                       borderRadius: BorderRadius.circular(10),
//                       border: voted ? Border.all(color: Colors.deepPurple, width: 2) : null,
//                     ),
//                     child: Row(
//                       children: [
//                         Expanded(
//                           child: GestureDetector(
//                             behavior: HitTestBehavior.opaque,
//                             onTap: (!ended && userVotedIndex == -1)
//                                 ? () async {
//                                     // Always use the latest votes map for voting
//                                     Map<String, dynamic> votesMap;
//                                     if (msg.votes is Map) {
//                                       votesMap = Map<String, dynamic>.from(msg.votes as Map);
//                                     } else if (msg.votes is List) {
//                                       // Convert list to map for voting
//                                       final rawList = (msg.votes as List?)?.map((v) => v == null ? <String>[] : List<String>.from(v)).toList() ?? <List<String>>[];
//                                       votesMap = { for (var i = 0; i < rawList.length; i++) '$i': rawList[i] };
//                                     } else {
//                                       votesMap = {};
//                                     }
//                                     await onVote(pollKey!, i, votesMap, ended);
//                                     (context as Element).markNeedsBuild();
//                                   }
//                                 : null,
//                             child: Text(
//                               choice,
//                               style: TextStyle(
//                                 color: voted ? Colors.deepPurple : (isMe ? Colors.white : const Color(0xFF9D4EDD)),
//                                 fontSize: 15,
//                                 fontWeight: voted ? FontWeight.bold : FontWeight.normal,
//                               ),
//                             ),
