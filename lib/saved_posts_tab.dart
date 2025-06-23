import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:thinktwice/post_card.dart';
import 'package:thinktwice/post_detailed_page2.dart';

class SavedPostsTab extends StatefulWidget {
  const SavedPostsTab({Key? key}) : super(key: key);

  @override
  State<SavedPostsTab> createState() => _SavedPostsTabState();
}

class _SavedPostsTabState extends State<SavedPostsTab> {
  String? currentUserId;
  List<Map<String, dynamic>> savedPosts = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      currentUserId = user.uid;
      fetchSavedPosts();
    }
  }

  Future<void> fetchSavedPosts() async {
    final userSavedPostsRef = FirebaseDatabase.instance
        .ref('Users/$currentUserId/saved_posts');

    final savedSnapshot = await userSavedPostsRef.get();

    if (!savedSnapshot.exists) {
      setState(() {
        savedPosts = [];
        isLoading = false;
      });
      return;
    }

    final savedPostIds = Map<String, dynamic>.from(savedSnapshot.value as Map);
    final postList = <Map<String, dynamic>>[];

    for (final entry in savedPostIds.entries) {
      if (entry.value == true) {
        final postId = entry.key;
        final postSnapshot =
        await FirebaseDatabase.instance.ref('Posts/$postId').get();
        if (postSnapshot.exists) {
          final postData =
          Map<String, dynamic>.from(postSnapshot.value as Map);
          postData['postId'] = postId;
          postList.add(postData);
        }
      }
    }

    setState(() {
      savedPosts = postList;
      isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (currentUserId == null) {
      return const Center(child: Text('Not logged in'));
    }

    if (isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (savedPosts.isEmpty) {
      return const Center(child: Text('No saved posts yet!'));
    }

    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: GridView.builder(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 8,
          mainAxisSpacing: 8,
          childAspectRatio: 0.75,
        ),
        itemCount: savedPosts.length,
        itemBuilder: (context, index) {
          final post = savedPosts[index];
          final postId = post['postId'];
          final title = post['title'] ?? '';
          final username = post['username'] ?? '';
          final userProfile = post['userProfile'] ?? '';
          final images = List<String>.from(post['images'] ?? []);
          final firstImage = images.isNotEmpty ? images[0] : '';
          final likes = Map<String, dynamic>.from(post['Likes'] ?? {});
          final isLiked = likes.containsKey(currentUserId);
          final likeCount = likes.length;

          return GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => PostDetailPage2(
                    postId: postId,
                    username: username,
                    userProfile: userProfile,
                    images: images,
                    title: title,
                    description: post['description'] ?? '',
                    timestamp: post['timestamp'] ?? DateTime.now().toIso8601String(),
                  ),
                ),
              );
            },
            child: PostCard(
              postId: postId,
              imageUrl: firstImage,
              title: title,
              userProfile: userProfile,
              username: username,
              isLiked: isLiked,
              likeCount: likeCount,
              onLike: () {
                final postRef = FirebaseDatabase.instance
                    .ref('Posts/$postId/Likes/$currentUserId');
                if (isLiked) {
                  postRef.remove();
                } else {
                  postRef.set(true);
                }
              },
            ),
          );
        },
      ),
    );
  }
}
