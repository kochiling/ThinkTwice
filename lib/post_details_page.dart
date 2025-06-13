import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:photo_view/photo_view.dart';
import 'package:photo_view/photo_view_gallery.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';

class PostDetailPage extends StatefulWidget {
  final String username;
  final String userProfile;
  final List<String> images;
  final String title;
  final String description;
  final String timestamp;
  final String postId;

  const PostDetailPage({
    Key? key,
    required this.username,
    required this.userProfile,
    required this.images,
    required this.title,
    required this.description,
    required this.timestamp,
    required this.postId,
  }) : super(key: key);

  @override
  State<PostDetailPage> createState() => _PostDetailPageState();
}

class _PostDetailPageState extends State<PostDetailPage> {
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _commentController = TextEditingController();
  bool _showBottomBar = true;

  final database = FirebaseDatabase.instance.ref();
  final user = FirebaseAuth.instance.currentUser!;
  late final String postId;

  int likeCount = 0;
  int saveCount = 0;
  int commentCount = 0;
  bool isLiked = false;
  bool isSaved = false;

  String currentUsername = '';
  String currentUserProfile = '';

  @override
  void initState() {
    super.initState();
    postId = widget.postId;
    _loadUserData();
    _listenLikeCount();
    _listenSaveStatus();
    _listenCommentCount();
    _listenSaveCount();

    _scrollController.addListener(() {
      final direction = _scrollController.position.userScrollDirection;
      if (direction == ScrollDirection.reverse && _showBottomBar) {
        setState(() => _showBottomBar = false);
      } else if (direction == ScrollDirection.forward && !_showBottomBar) {
        setState(() => _showBottomBar = true);
      }
    });
  }

  void _loadUserData() async {
    final snapshot = await database.child('Users/${user.uid}').get();
    if (snapshot.exists) {
      final data = Map<String, dynamic>.from(snapshot.value as Map);
      setState(() {
        currentUsername = data['username'] ?? '';
        currentUserProfile = data['profile_pic'] ?? '';
      });
    }
  }

  void _listenLikeCount() {
    database.child('Posts/$postId/Likes').onValue.listen((event) {
      final likes = event.snapshot.value as Map? ?? {};
      setState(() {
        likeCount = likes.length;
        isLiked = likes.containsKey(user.uid);
      });
    });
  }

  void _listenSaveStatus() {
    database.child('Users/${user.uid}/saved_posts/$postId').onValue.listen((event) {
      setState(() {
        isSaved = event.snapshot.exists;
      });
    });
  }

  void _listenCommentCount() {
    database.child('Posts/$postId/Comments').onValue.listen((event) {
      final data = event.snapshot.value as Map? ?? {};
      int total = 0;
      for (final userComments in data.values) {
        if (userComments is Map) total += userComments.length;
      }
      setState(() => commentCount = total);
    });
  }

  void _listenSaveCount() {
    database.child('Posts/$postId/saveCount').onValue.listen((event) {
      final count = event.snapshot.value;
      setState(() {
        saveCount = (count is int) ? count : 0;
      });
    });
  }

  void _submitComment() async {
    final content = _commentController.text.trim();
    if (content.isEmpty) return;

    final newCommentRef = database.child('Posts/$postId/Comments/${user.uid}').push();
    await newCommentRef.set({
      'comment_id': newCommentRef.key,
      'timestamp': DateTime.now().toString(),
      'content': content,
      'username': currentUsername,
      'user_profile': currentUserProfile,
      'user_id': user.uid,
    });

    _commentController.clear();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _commentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final formattedTime = DateFormat('dd MMM yyyy, hh:mm a')
        .format(DateTime.parse(widget.timestamp));

    return Scaffold(
      resizeToAvoidBottomInset: true,
      body: Stack(
        children: [
          Column(
            children: [
              // AppBar & User Info
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                  child: Row(
                    children: [
                      GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: const Icon(Icons.chevron_left, size: 32),
                      ),
                      const SizedBox(width: 10),
                      CircleAvatar(backgroundImage: NetworkImage(widget.userProfile)),
                      const SizedBox(width: 10),
                      Text(widget.username,
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 16)),
                    ],
                  ),
                ),
              ),

              // Scrollable Details
              Expanded(
                child: SingleChildScrollView(
                  controller: _scrollController,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Images
                      SizedBox(
                        height: 450,
                        child: PhotoViewGallery.builder(
                          itemCount: widget.images.length,
                          builder: (context, index) {
                            return PhotoViewGalleryPageOptions(
                              imageProvider: NetworkImage(widget.images[index]),
                              minScale: PhotoViewComputedScale.contained,
                              maxScale: PhotoViewComputedScale.covered * 2,
                            );
                          },
                          scrollPhysics: const BouncingScrollPhysics(),
                          backgroundDecoration:
                          const BoxDecoration(color: Colors.white),
                        ),
                      ),

                      const SizedBox(height: 12),
                      Text(widget.title,
                          style: const TextStyle(
                              fontSize: 16, fontWeight: FontWeight.bold)),

                      const SizedBox(height: 8),
                      Text(widget.description,
                          style: const TextStyle(fontSize: 14)),

                      const SizedBox(height: 12),
                      Text("Posted on $formattedTime",
                          style: const TextStyle(
                              color: Colors.grey, fontSize: 14)),

                      const Divider(thickness: 1),
                      const SizedBox(height: 10),
                      const Text("Comments",
                          style: TextStyle(
                              fontSize: 18, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),

                      /// ✅ Firebase Comments Display
                      StreamBuilder<DatabaseEvent>(
                        stream: database.child('Posts/$postId/Comments').onValue,
                        builder: (context, snapshot) {
                          if (snapshot.connectionState == ConnectionState.waiting) {
                            return const Center(child: CircularProgressIndicator());
                          }

                          if (!snapshot.hasData || snapshot.data?.snapshot.value == null) {
                            return const Text("No comments yet.");
                          }

                          final commentMap = Map<String, dynamic>.from(
                              snapshot.data!.snapshot.value as Map);

                          final comments = commentMap.entries.expand((entry) {
                            final commentList = Map<String, dynamic>.from(entry.value);
                            return commentList.entries.map((e) => e.value);
                          }).toList();

                          comments.sort((a, b) => DateTime.parse(a['timestamp'])
                              .compareTo(DateTime.parse(b['timestamp'])));

                          return ListView.builder(
                            itemCount: comments.length,
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemBuilder: (context, index) {
                              final c = Map<String, dynamic>.from(comments[index]);
                              final commentTime = DateFormat('dd MMM yyyy, hh:mm a')
                                  .format(DateTime.parse(c['timestamp']));
                              return ListTile(
                                leading: CircleAvatar(
                                    backgroundImage: NetworkImage(c['user_profile'] ?? '')),
                                title: Text(c['username'] ?? '',
                                    style: const TextStyle(fontWeight: FontWeight.bold)),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(c['content'] ?? ''),
                                    Text(commentTime,
                                        style: const TextStyle(fontSize: 12, color: Colors.grey)),
                                  ],
                                ),
                                contentPadding: const EdgeInsets.symmetric(vertical: 4),
                              );
                            },
                          );
                        },
                      ),

                      const SizedBox(height: 100), // Padding for bottom bar
                    ],
                  ),
                ),
              ),
            ],
          ),

          // Bottom Bar
          AnimatedPositioned(
            duration: const Duration(milliseconds: 300),
            bottom: _showBottomBar ? 0 : -100,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: const BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, -2))
                ],
              ),

              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _commentController,
                      decoration: InputDecoration(
                        hintText: "Write a comment...",
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(20)),
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.send),
                    onPressed: _submitComment,
                  ),
                  IconButton(
                    icon: Icon(isLiked ? Icons.favorite : Icons.favorite_border,
                        color: isLiked ? Colors.red : Colors.grey),
                    onPressed: () {
                      final ref = database.child('Posts/$postId/Likes/${user.uid}');
                      isLiked ? ref.remove() : ref.set(true);
                    },
                  ),
                  Text('$likeCount'),
                  IconButton(
                    icon: Icon(isSaved ? Icons.bookmark : Icons.bookmark_border),
                    onPressed: () async {
                      final userRef = database.child('Users/${user.uid}/saved_posts/$postId');
                      final postRef = database.child('Posts/$postId');

                      if (isSaved) {
                        await userRef.remove();
                        await postRef.child('saveCount').runTransaction((value) {
                          final current = (value ?? 1) as int;
                          return Transaction.success(current - 1);
                        });
                      } else {
                        await userRef.set(true);
                        await postRef.child('saveCount').runTransaction((value) {
                          final current = (value ?? 0) as int;
                          return Transaction.success(current + 1);
                        });
                      }
                    },
                  ),
                  Text('$saveCount'),
                  IconButton(
                    icon: const Icon(Icons.comment_outlined),
                    onPressed: () {
                      _scrollController.animateTo(
                        _scrollController.position.maxScrollExtent,
                        duration: const Duration(milliseconds: 500),
                        curve: Curves.easeInOut,
                      );
                    },
                  ),
                  Text('$commentCount'),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
