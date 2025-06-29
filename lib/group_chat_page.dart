import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';
import 'models/group_chat_message.dart';
import 'widgets/chat_sender_card.dart';
import 'widgets/chat_receiver_card.dart';
import 'package:intl/intl.dart';
import 'widgets/poll_detail_page.dart';
import 'widgets/poll_card.dart';

class GroupChatPage extends StatefulWidget {
  final String groupId;
  final String currentUserId;
  final String currentUsername;
  final String currentUserProfile;

  const GroupChatPage({
    Key? key,
    required this.groupId,
    required this.currentUserId,
    required this.currentUsername,
    required this.currentUserProfile,
  }) : super(key: key);

  @override
  State<GroupChatPage> createState() => _GroupChatPageState();
}

class _GroupChatPageState extends State<GroupChatPage> {
  final TextEditingController _controller = TextEditingController();
  final DatabaseReference _chatRef = FirebaseDatabase.instance.ref();
  final ImagePicker _picker = ImagePicker();
  final ScrollController _scrollController = ScrollController();

  File? _imagePreviewFile;
  bool _isUploading = false;
  String groupName = '';

  void _sendMessage({String? imageUrl}) async {
    final text = _controller.text.trim();
    if ((text.isEmpty && imageUrl == null)) return;
    final msgRef = _chatRef.child('Groups/${widget.groupId}/chat').push();
    await msgRef.set({
      'senderId': widget.currentUserId,
      'senderName': widget.currentUsername,
      'senderProfile': widget.currentUserProfile,
      'type': imageUrl != null ? 'image' : 'text',
      'text': imageUrl != null ? '' : text,
      'imageUrl': imageUrl ?? '',
      'timestamp': DateTime.now().toIso8601String(),
    });
    _controller.clear();
    _scrollToBottom();
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 200), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _pickImage(ImageSource source) async {
    final picked = await _picker.pickImage(source: source, imageQuality: 80);
    if (picked != null) {
      setState(() {
        _imagePreviewFile = File(picked.path);
      });
    }
  }

  Future<void> _uploadAndSendImage() async {
    if (_imagePreviewFile == null) return;
    setState(() {
      _isUploading = true;
    });
    try {
      final storageRef = FirebaseStorage.instance
          .ref()
          .child('group_chats/${widget.groupId}/${DateTime.now().millisecondsSinceEpoch}_${_imagePreviewFile!.path.split('/').last}');
      final uploadTask = await storageRef.putFile(_imagePreviewFile!);
      final downloadUrl = await storageRef.getDownloadURL();
      _sendMessage(imageUrl: downloadUrl);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to upload image: $e')),
      );
    } finally {
      setState(() {
        _isUploading = false;
        _imagePreviewFile = null;
      });
      _scrollToBottom();
    }
  }

  void _cancelImagePreview() {
    setState(() {
      _imagePreviewFile = null;
    });
  }

  void _showPollDialog() {
    final questionController = TextEditingController();
    final List<TextEditingController> choiceControllers = [
      TextEditingController(),
      TextEditingController(),
    ];
    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
              title: Row(
                children: const [
                  Icon(Icons.poll, color: Color(0xFF9D4EDD)),
                  SizedBox(width: 8),
                  Text('Create Poll', style: TextStyle(color: Color(0xFF9D4EDD), fontWeight: FontWeight.bold)),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      controller: questionController,
                      decoration: InputDecoration(
                        labelText: 'Poll Question',
                        labelStyle: TextStyle(color: Color(0xFF9D4EDD)),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Color(0xFF9D4EDD), width: 2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    ...List.generate(choiceControllers.length, (i) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: choiceControllers[i],
                              decoration: InputDecoration(
                                labelText: 'Choice ${i + 1}',
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(color: Color(0xFF9D4EDD), width: 2),
                                ),
                              ),
                            ),
                          ),
                          if (choiceControllers.length > 2)
                            IconButton(
                              icon: const Icon(Icons.remove_circle, color: Colors.red),
                              onPressed: () {
                                setState(() {
                                  choiceControllers.removeAt(i);
                                });
                              },
                            ),
                        ],
                      ),
                    )),
                    if (choiceControllers.length < 5)
                      Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton.icon(
                          icon: const Icon(Icons.add, size: 18, color: Color(0xFF9D4EDD)),
                          label: const Text('Add Choice', style: TextStyle(color: Color(0xFF9D4EDD))),
                          onPressed: () {
                            setState(() {
                              choiceControllers.add(TextEditingController());
                            });
                          },
                        ),
                      ),
                  ],
                ),
              ),
              actionsPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              actions: [
                TextButton(
                  child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
                  onPressed: () => Navigator.pop(context),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Color(0xFF9D4EDD),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: const Text('Send'),
                  onPressed: () {
                    final question = questionController.text.trim();
                    final choices = choiceControllers.map((c) => c.text.trim()).where((c) => c.isNotEmpty).toList();
                    if (question.isEmpty || choices.length < 2) return;
                    _sendPollMessage(question, choices);
                    Navigator.pop(context);
                  },
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _sendPollMessage(String question, List<String> choices) async {
    final msgRef = _chatRef.child('Groups/${widget.groupId}/chat').push();
    // Store votes as a map: { '0': [], '1': [], ... }
    final votesMap = { for (var i = 0; i < choices.length; i++) '$i': [] };
    await msgRef.set({
      'senderId': widget.currentUserId,
      'senderName': widget.currentUsername,
      'senderProfile': widget.currentUserProfile,
      'type': 'poll',
      'question': question,
      'choices': choices,
      'votes': votesMap,
      'ended': false,
      'timestamp': DateTime.now().toIso8601String(),
    });
    _scrollToBottom();
  }

  Future<void> _votePoll(String pollKey, int choiceIndex, Map votes, bool ended) async {
    if (ended) return;
    final userId = widget.currentUserId;
    // Ensure votes is a Map<String, List<String>>
    final newVotes = <String, List<String>>{};
    votes.forEach((k, v) {
      final list = v is List ? List<String>.from(v) : <String>[];
      list.remove(userId);
      newVotes[k] = list;
    });
    newVotes['$choiceIndex'] ??= [];
    newVotes['$choiceIndex']!.add(userId);
    await _chatRef.child('Groups/${widget.groupId}/chat/$pollKey/votes').set(newVotes);
  }

  Future<void> _endPoll(String pollKey) async {
    await _chatRef.child('Groups/${widget.groupId}/chat/$pollKey/ended').set(true);
  }

  Widget _buildPollCard(GroupChatMessage msg, bool isMe, {required String pollKey}) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => PollDetailPage(
              pollMessage: msg,
              pollKey: pollKey,
              currentUserId: widget.currentUserId,
              onVote: (String pollKey, int choiceIndex, Map votes, bool ended) async {
                await _votePoll(pollKey, choiceIndex, votes, ended);
                setState(() {});
              },
              onEndPoll: (String pollKey) async {
                await _endPoll(pollKey);
                setState(() {});
              },
            ),
            settings: RouteSettings(arguments: {'groupId': widget.groupId}),
          ),
        );
      },
      child: PollCard(
        msg: msg,
        isMe: isMe,
        pollKey: pollKey,
        currentUserId: widget.currentUserId,
        onVote: (String pollKey, int choiceIndex, Map votes, bool ended) async {
          await _votePoll(pollKey, choiceIndex, votes, ended);
          setState(() {});
        },
        onEndPoll: (String pollKey) async {
          await _endPoll(pollKey);
          setState(() {});
        },
        showVoters: false,
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    // Debug print for current user info
    debugPrint('GroupChatPage: currentUserId = \\${widget.currentUserId}');
    debugPrint('GroupChatPage: currentUsername = \\${widget.currentUsername}');
    debugPrint('GroupChatPage: currentUserProfile = \\${widget.currentUserProfile}');
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
    _fetchGroupName();
  }

  Future<void> _fetchGroupName() async {
    final groupRef = FirebaseDatabase.instance.ref('Groups/${widget.groupId}/groupName');
    final snap = await groupRef.get();
    if (snap.exists) {
      setState(() {
        groupName = snap.value?.toString() ?? '';
      });
    }
  }

  Future<void> _deleteChatMessage(String messageKey) async {
    try {
      await _chatRef.child('Groups/${widget.groupId}/chat/$messageKey').remove();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Message deleted')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to delete message: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      //backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(groupName.isNotEmpty ? "${groupName}'s Chat Room" : 'Group Chat'),
        backgroundColor: const Color(0xffdcadd5),
      ),
      body: Stack(
        children: [
          Column(
            children: [
              Expanded(
                child: StreamBuilder<DatabaseEvent>(
                  stream: _chatRef.child('Groups/${widget.groupId}/chat').orderByChild('timestamp').onValue,
                  builder: (context, snapshot) {
                    if (!snapshot.hasData || snapshot.data?.snapshot.value == null) {
                      return const Center(child: Text('No messages yet.'));
                    }
                    final chatMap = Map<String, dynamic>.from(snapshot.data!.snapshot.value as Map);
                    final messagesWithKeys = chatMap.entries.map((e) {
                      final msg = GroupChatMessage.fromMap(Map<String, dynamic>.from(e.value));
                      return {'key': e.key, 'msg': msg};
                    }).toList()
                      ..sort((a, b) {
                        final at = (a['msg'] as GroupChatMessage?)?.timestamp;
                        final bt = (b['msg'] as GroupChatMessage?)?.timestamp;
                        if (at == null && bt == null) return 0;
                        if (at == null) return -1;
                        if (bt == null) return 1;
                        return at.compareTo(bt);
                      });
                    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
                    return ListView.builder(
                      controller: _scrollController,
                      reverse: false,
                      itemCount: messagesWithKeys.length,
                      itemBuilder: (context, index) {
                        final item = messagesWithKeys[index];
                        final msg = item['msg'] as GroupChatMessage;
                        final key = item['key'] as String;
                        final isMe = msg.senderId == widget.currentUserId;
                        if (msg.type == 'poll') {
                          return _buildPollCard(msg, isMe, pollKey: key);
                        }
                        return GestureDetector(
                          onLongPress: isMe
                              ? () {
                                  showModalBottomSheet(
                                    context: context,
                                    shape: const RoundedRectangleBorder(
                                      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
                                    ),
                                    builder: (context) {
                                      return Wrap(
                                        children: [
                                          ListTile(
                                            leading: const Icon(Icons.delete, color: Colors.red),
                                            title: const Text('Delete Message'),
                                            onTap: () async {
                                              Navigator.pop(context);
                                              await _deleteChatMessage(key);
                                            },
                                          ),
                                        ],
                                      );
                                    },
                                  );
                                }
                              : null,
                          child: isMe
                              ? ChatSenderCard(message: msg)
                              : ChatReceiverCard(message: msg),
                        );
                      },
                    );
                  },
                ),
              ),
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.only(left: 8, right: 8, top: 2, bottom: 10), // lift up a bit
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      // Plus button with menu
                      PopupMenuButton<int>(
                        icon: const Icon(Icons.add_circle, color: Color(0xFFCDB4DB), size: 32),
                        itemBuilder: (context) => [
                          PopupMenuItem(
                            value: 1,
                            child: Row(
                              children: const [Icon(Icons.poll, color: Color(0xFF9D4EDD)), SizedBox(width: 8), Text('Poll')],
                            ),
                          ),
                          PopupMenuItem(
                            value: 2,
                            child: Row(
                              children: const [Icon(Icons.camera_alt, color: Color(0xFF9D4EDD)), SizedBox(width: 8), Text('Camera')],
                            ),
                          ),
                          PopupMenuItem(
                            value: 3,
                            child: Row(
                              children: const [Icon(Icons.photo, color: Color(0xFF9D4EDD)), SizedBox(width: 8), Text('Gallery')],
                            ),
                          ),
                          // PopupMenuItem(
                          //   value: 4,
                          //   child: Row(
                          //     children: const [Icon(Icons.attach_file, color: Color(0xFF9D4EDD)), SizedBox(width: 8), Text('File')],
                          //   ),
                          // ),
                        ],
                        onSelected: (value) {
                          if (value == 1) {
                            _showPollDialog();
                          } else if (value == 2) {
                            _pickImage(ImageSource.camera);
                          } else if (value == 3) {
                            _pickImage(ImageSource.gallery);
                          }
                        },
                      ),
                      const SizedBox(width: 6),
                      // Multiline, rounded text field
                      Expanded(
                        child: TextField(
                          controller: _controller,
                          minLines: 1,
                          maxLines: 5,
                          decoration: InputDecoration(
                            hintText: 'Type a message...',
                            filled: true,
                            fillColor: Colors.white,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(24),
                              borderSide: const BorderSide(color: Color(0xFFCDB4DB)),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(24),
                              borderSide: const BorderSide(color: Color(0xFFCDB4DB)),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(24),
                              borderSide: const BorderSide(color: Color(0xFF9D4EDD), width: 2),
                            ),
                            isDense: true,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      IconButton(
                        icon: const Icon(Icons.send, color: Color(0xFFCDB4DB)),
                        onPressed: _sendMessage,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          if (_imagePreviewFile != null)
            Container(
              color: Colors.black.withOpacity(0.7),
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Material(
                    borderRadius: BorderRadius.circular(16),
                    clipBehavior: Clip.antiAlias,
                    child: Container(
                      color: Colors.white,
                      width: 320,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Padding(
                            padding: const EdgeInsets.all(12.0),
                            child: Text('Preview Photo', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                          ),
                          Image.file(_imagePreviewFile!, height: 260, fit: BoxFit.contain),
                          const SizedBox(height: 16),
                          if (_isUploading)
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              child: CircularProgressIndicator(color: Color(0xFF9D4EDD)),
                            )
                          else
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                              children: [
                                TextButton.icon(
                                  icon: Icon(Icons.cancel, color: Colors.red),
                                  label: Text('Cancel', style: TextStyle(color: Colors.red)),
                                  onPressed: _cancelImagePreview,
                                ),
                                ElevatedButton.icon(
                                  icon: Icon(Icons.send, color: Colors.white),
                                  label: Text('Send'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Color(0xFF9D4EDD),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                                  ),
                                  onPressed: _uploadAndSendImage,
                                ),
                              ],
                            ),
                          const SizedBox(height: 12),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}