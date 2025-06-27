import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:photo_view/photo_view.dart';
import 'package:photo_view/photo_view_gallery.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:thinktwice/nagivation_bar.dart';
import 'edit_post_page.dart';

class PostDetailPage2 extends StatefulWidget {
  final String username;
  final String userProfile;
  final List<String> images;
  final String title;
  final String description;
  final String timestamp;
  final String postId;
  final String? postuserId;

  const PostDetailPage2({
    Key? key,
    required this.username,
    required this.userProfile,
    required this.images,
    required this.title,
    required this.description,
    required this.timestamp,
    required this.postId,
    required this.postuserId,
  }) : super(key: key);

  @override
  State<PostDetailPage2> createState() => _PostDetailPage2State();
}

class _PostDetailPage2State extends State<PostDetailPage2> {
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _commentController = TextEditingController();
  final bool _showBottomBar = true;

  final database = FirebaseDatabase.instance.ref();
  final user = FirebaseAuth.instance.currentUser!;
  late final String postId;

  final FocusNode _commentFocusNode = FocusNode();
  bool _isCommentFocused = false;
  bool _isCommentNotEmpty = false;

  int likeCount = 0;
  int saveCount = 0;
  int commentCount = 0;
  bool isLiked = false;
  bool isSaved = false;

  String currentUsername = '';
  String currentUserProfile = '';

  final Set<String> _expandedReplies = {};

  String? _replyToCommentId;
  String? _replyToUserId;
  String? _replyToUsername;

  int _currentImageIndex = 0;
  late final PageController _imagePageController = PageController();

  @override
  void initState() {
    super.initState();
    postId = widget.postId;
    _imagePageController.addListener(() {
      final newIndex = _imagePageController.page?.round() ?? 0;
      if (newIndex != _currentImageIndex) {
        setState(() {
          _currentImageIndex = newIndex;
        });
      }
    });
    _loadUserData();
    _listenLikeCount();
    _listenSaveStatus();
    _listenCommentCount();
    _listenSaveCount();

    _commentFocusNode.addListener(() {
      setState(() {
        _isCommentFocused = _commentFocusNode.hasFocus;
      });
    });

    _commentController.addListener(() {
      setState(() {
        _isCommentNotEmpty = _commentController.text.trim().isNotEmpty;
      });
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
    if (_replyToCommentId != null && _replyToUserId != null) {
      // Submit as reply
      final ref = database.child('Posts/$postId/Comments/${_replyToUserId!}/${_replyToCommentId!}/replies').push();
      await ref.set({
        'reply_id': ref.key,
        'timestamp': DateTime.now().toString(),
        'content': content,
        'username': currentUsername,
        'user_profile': currentUserProfile,
        'user_id': user.uid,
      });
    } else {
      // Submit as new comment
      final newCommentRef = database.child('Posts/$postId/Comments/${user.uid}').push();
      await newCommentRef.set({
        'comment_id': newCommentRef.key,
        'timestamp': DateTime.now().toString(),
        'content': content,
        'username': currentUsername,
        'user_profile': currentUserProfile,
        'user_id': user.uid,
      });
    }
    _commentController.clear();
    FocusScope.of(context).unfocus();
    setState(() {
      _isCommentFocused = false;
      _replyToCommentId = null;
      _replyToUserId = null;
      _replyToUsername = null;
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _commentController.dispose();
    _imagePageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final formattedTime = DateFormat('dd MMM yyyy, hh:mm a')
        .format(DateTime.parse(widget.timestamp));

    return GestureDetector(
      onTap: () {
        FocusScope.of(context).unfocus(); // ⬅️ Dismiss keyboard
      },
      child: Scaffold(
        backgroundColor: Color(0xffffffff),
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
                        const Spacer(),
                        if (user.uid == widget.postuserId)
                          IconButton(
                            icon: const Icon(Icons.more_vert),
                            onPressed: () {
                              showModalBottomSheet(
                                context: context,
                                shape: const RoundedRectangleBorder(
                                  borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
                                ),
                                builder: (context) {
                                  return Wrap(
                                    children: [
                                      ListTile(
                                        leading: const Icon(Icons.edit),
                                        title: const Text('Edit Post'),
                                        onTap: () async {
                                          Navigator.pop(context);
                                          final updated = await Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder: (_) => EditPostPage(
                                                postId: widget.postId,
                                                initialTitle: widget.title,
                                                initialDescription: widget.description,
                                                username: widget.username,
                                                userProfile: widget.userProfile,
                                                images: widget.images,
                                              ),
                                            ),
                                          );
                                          if (updated == true && mounted) {
                                            setState(() {}); // Refresh UI if post was updated
                                          }
                                        },
                                      ),
                                      ListTile(
                                        leading: const Icon(Icons.delete),
                                        title: const Text('Delete Post'),
                                        onTap: () async {
                                          Navigator.pop(context);
                                          final shouldDelete = await showDialog<bool>(
                                            context: context,
                                            builder: (context) => AlertDialog(
                                              title: const Text('Delete Post'),
                                              content: const Text('Are you sure you want to delete this post?'),
                                              actions: [
                                                TextButton(
                                                  onPressed: () => Navigator.of(context).pop(false),
                                                  child: const Text('Cancel'),
                                                ),
                                                TextButton(
                                                  onPressed: () => Navigator.of(context).pop(true),
                                                  child: const Text('Delete'),
                                                ),
                                              ],
                                            ),
                                          );
                                          if (shouldDelete == true) {
                                            try {
                                              await database.child('Posts/${widget.postId}').remove();
                                              if (mounted) {
                                                ScaffoldMessenger.of(context).showSnackBar(
                                                  SnackBar(content: Text('Delete post')),
                                                );
                                                await Future.delayed(const Duration(milliseconds: 300));
                                                Navigator.of(context).pop();
                                                Navigator.of(context).pushAndRemoveUntil(
                                                  MaterialPageRoute(builder: (context) => const CurveBar(selectedIndex: 0)),
                                                      (route) => false,
                                                );
                                              }
                                            } catch (e) {
                                              if (mounted) {
                                                ScaffoldMessenger.of(context).showSnackBar(
                                                  SnackBar(content: Text('Failed to delete post: $e')),
                                                );
                                              }
                                            }
                                          }
                                        },
                                      ),
                                    ],
                                  );
                                },
                              );
                            },
                          ),
                      ],
                    ),
                  ),
                ),

                // Scrollable Details
                Expanded(
                  child: SingleChildScrollView(
                    controller: _scrollController,
                    padding: const EdgeInsets.fromLTRB(12, 6, 12, 100), // Added bottom space for floating bar
                    keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Images
                        SizedBox(
                          height: 450,
                          child: PhotoViewGallery.builder(
                            pageController: _imagePageController,
                            itemCount: widget.images.length,
                            onPageChanged: (index) {
                              setState(() {
                                _currentImageIndex = index;
                              });
                            },
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
                        if (widget.images.length > 1)
                          Center(
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: List.generate(widget.images.length, (index) {
                                return AnimatedContainer(
                                  duration: const Duration(milliseconds: 200),
                                  margin: const EdgeInsets.symmetric(horizontal: 4),
                                  width: 8,
                                  height: 8,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: _currentImageIndex == index
                                        ? const Color(0xFFC96077) // active dot pink
                                        : const Color(0xFFFBE5EC), // inactive dot light pink
                                    border: Border.all(color: const Color(0xFFC96077), width: 1),
                                  ),
                                );
                              }),
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

                        _buildCommentList(),

                      ],
                    ),
                  ),
                ),
              ],
            ),
            Align(
              alignment: Alignment.bottomCenter,
              child: _buildOriginalBottomBar(),
            ),
            //_isCommentFocused ? _buildCommentBar() : _buildOriginalBottomBar(),
          ],

        ),
      ),
    );
  }

  Widget _buildCommentList() {
    return StreamBuilder<DatabaseEvent>(
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
            final commentId = c['comment_id'];
            final commentTime = DateFormat('dd MMM yyyy, hh:mm a')
                .format(DateTime.parse(c['timestamp']));
            final replies = (c['replies'] as Map?) ?? {}; // handle replies
            final hasReplies = replies.isNotEmpty;
            final isExpanded = _expandedReplies.contains(commentId);

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                GestureDetector(
                  onLongPress: () {
                    if (c['user_id'] == user.uid) {
                      showModalBottomSheet(
                        context: context,
                        shape: const RoundedRectangleBorder(
                          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
                        ),
                        builder: (context) {
                          return Wrap(
                            children: [
                              ListTile(
                                leading: const Icon(Icons.edit),
                                title: const Text('Edit'),
                                onTap: () {
                                  Navigator.pop(context);
                                  _showEditDialog(c);
                                },
                              ),
                              ListTile(
                                leading: const Icon(Icons.delete),
                                title: const Text('Delete'),
                                onTap: () {
                                  Navigator.pop(context);
                                  _deleteComment(c['comment_id'], c['user_id']);
                                },
                              ),
                            ],
                          );
                        },
                      );
                    }
                  },
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(height: 8), // Indent for better alignment
                      Container(
                        margin: const EdgeInsets.only(top: 8, right: 8),
                        child: CircleAvatar(
                          backgroundImage: NetworkImage(c['user_profile'] ?? ''),
                          radius: 16,
                        ),
                      ),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SizedBox(height: 4),
                            Text(
                              c['username'] ?? '',
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 2),
                            Text(c['content'] ?? '', style: const TextStyle(fontSize: 14)),

                            const SizedBox(height: 2),

                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    Text(
                                      commentTime,
                                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                                    ),
                                    const SizedBox(width: 12),
                                    GestureDetector(
                                      onTap: () {
                                        setState(() {
                                          _replyToCommentId = commentId;
                                          _replyToUserId = c['user_id'];
                                          _replyToUsername = c['username'];
                                        });
                                        FocusScope.of(context).requestFocus(_commentFocusNode);
                                      },
                                      child: const Text(
                                        'Reply',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.blue,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                Row(
                                  children: [
                                    _likeIcon(c),
                                    Text(
                                      '${(c['likes'] as Map?)?.length ?? 0}',
                                      style: const TextStyle(fontSize: 12),
                                    ),
                                  ],
                                ),
                              ],
                            ),

                            // Toggle replies section
                            if (hasReplies)
                              TextButton(
                                style: TextButton.styleFrom(
                                  padding: EdgeInsets.zero,
                                  minimumSize: Size(0, 20),
                                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                ),
                                onPressed: () {
                                  setState(() {
                                    if (isExpanded) {
                                      _expandedReplies.remove(commentId);
                                    } else {
                                      _expandedReplies.add(commentId);
                                    }
                                  });
                                },
                                child: Text(
                                  isExpanded
                                      ? 'Hide replies'
                                      : 'View replies (${replies.length})',
                                  style: const TextStyle(fontSize: 12),
                                ),
                              ),
                              SizedBox(height: 8),

                            // Show replies only if expanded
                            if (isExpanded) _buildReplies(c),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 0),
              ],
            );
          },
        );

      },
    );
  }

  Widget _buildOriginalBottomBar() {
    final isCommenting = _commentFocusNode.hasFocus;
    final isReplying = _replyToCommentId != null && _replyToUsername != null;
    return Stack(
      children: [
        AnimatedPositioned(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
          bottom: _showBottomBar ? 0 : -100,
          left: 0,
          right: 0,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: const BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, -2)),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (isReplying)
                  Row(
                    children: [
                      Icon(Icons.reply, color: Color(0xFFC96077), size: 18),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          'Replying to @$_replyToUsername',
                          style: const TextStyle(color: Color(0xFFC96077), fontWeight: FontWeight.w500),
                        ),
                      ),
                      TextButton(
                        onPressed: () {
                          setState(() {
                            _replyToCommentId = null;
                            _replyToUserId = null;
                            _replyToUsername = null;
                          });
                        },
                        child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
                      ),
                    ],
                  ),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _commentController,
                        focusNode: _commentFocusNode,
                        decoration: InputDecoration(
                          hintText: isReplying ? 'Reply to @$_replyToUsername...' : 'Write a comment...',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(20)),
                        ),
                      ),
                    ),
                    if (isCommenting || isReplying)
                      IconButton(
                        icon: const Icon(Icons.send),
                        color: _isCommentNotEmpty ? Colors.blue : Colors.grey,
                        onPressed: _isCommentNotEmpty ? _submitComment : null,
                      )
                    else ...[
                      IconButton(
                        icon: Icon(
                          isLiked ? Icons.favorite : Icons.favorite_border,
                          color: isLiked ? Colors.red : Colors.grey,
                        ),
                        onPressed: () {
                          final ref = database.child('Posts/$postId/Likes/${user.uid}');
                          isLiked ? ref.remove() : ref.set(true);
                        },
                      ),
                      Text('$likeCount'),
                      IconButton(
                        icon: Icon(isSaved ? Icons.star : Icons.star_border,
                          color: isSaved ? Colors.yellow : Colors.grey,),
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
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  void _showEditDialog(Map<String, dynamic> comment) {
    final editController = TextEditingController(text: comment['content']);

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Row(
          children: const [
            Icon(Icons.edit, color: Color(0xFFC96077)),
            SizedBox(width: 8),
            Text("Edit comment", style: TextStyle(color: Color(0xFFC96077), fontWeight: FontWeight.bold)),
          ],
        ),
        content: TextField(
          controller: editController,
          decoration: InputDecoration(
            hintText: 'Edit your comment...',
            filled: true,
            fillColor: Color(0xFFFFFFFF),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Color(0xFF000000)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Color(0xFF000000), width: 2),
            ),
          ),
          maxLines: 3,
        ),
        actionsPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        actions: [
          TextButton(
            child: const Text("Cancel", style: TextStyle(color: Colors.grey)),
            onPressed: () => Navigator.pop(context),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Color(0xFFDCADD5),
              foregroundColor: Colors.black,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text("Save"),
            onPressed: () async {
              final updated = editController.text.trim();
              if (updated.isNotEmpty) {
                await database
                    .child('Posts/$postId/Comments/${comment['user_id']}/${comment['comment_id']}/content')
                    .set(updated);
              }
              Navigator.pop(context);
            },
          ),
        ],
      ),
    );
  }
  void _deleteComment(String commentId, String ownerId) async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Delete'),
        content: const Text('Are you sure you want to delete this comment?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('No'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Yes'),
          ),
        ],
      ),
    );
    if (shouldDelete == true) {
      try {
        final ref = database.child('Posts/$postId/Comments/$ownerId/$commentId');

        await ref.remove();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Comment deleted')),
          );
        }
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to delete comment: $e')),
        );
      }
    }


  }

  Widget _likeIcon(Map<String, dynamic> comment) {
    final likes = comment['likes'] as Map? ?? {};
    final hasLiked = likes.containsKey(user.uid);

    return IconButton(
      icon: Icon(hasLiked ? Icons.favorite : Icons.favorite_border, color: hasLiked ? Colors.red : Colors.grey, size: 18),
      onPressed: () {
        final ref = database.child('Posts/$postId/Comments/${comment['user_id']}/${comment['comment_id']}/likes/${user.uid}');
        hasLiked ? ref.remove() : ref.set(true);
      },
    );
  }

  Widget _buildReplies(Map<String, dynamic> comment) {
    final userId = comment['user_id'];
    final commentId = comment['comment_id'];

    return StreamBuilder<DatabaseEvent>(
      stream: database.child('Posts/$postId/Comments/$userId/$commentId/replies').onValue,
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data?.snapshot.value == null) {
          return const SizedBox(); // no replies
        }

        final replyMap = Map<String, dynamic>.from(snapshot.data!.snapshot.value as Map);
        final replies = replyMap.entries.map((e) {
          return Map<String, dynamic>.from(e.value);
        }).toList();

        replies.sort((a, b) => DateTime.parse(a['timestamp']).compareTo(DateTime.parse(b['timestamp'])));

        return Padding(
          padding: const EdgeInsets.only(left: 2.0, right: 2.0), // more indent for replies
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: replies.map((reply) {
              final replyTime = DateFormat('dd MMM yyyy, hh:mm a')
                  .format(DateTime.parse(reply['timestamp']));
              return Container(
                margin: const EdgeInsets.only(bottom: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(height: 8),
                    Container(
                      margin: const EdgeInsets.only(top: 8, right: 8),
                      child: CircleAvatar(
                        backgroundImage: NetworkImage(reply['user_profile'] ?? ''),
                        radius: 13, // slightly smaller for replies
                      ),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(height: 4),
                          Text(
                            reply['username'] ?? '',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                          ),
                          const SizedBox(height: 2),
                          Text(reply['content'] ?? '', style: const TextStyle(fontSize: 13)),
                          const SizedBox(height: 2),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    replyTime,
                                    style: const TextStyle(fontSize: 11, color: Colors.grey),
                                  ),
                                ],
                              ),
                              // Optionally, add like button for replies here if needed
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        );
      },
    );
  }
}