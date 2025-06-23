import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:thinktwice/post_card.dart';
import 'package:thinktwice/post_detailed_page2.dart';

class MyPostsTab extends StatefulWidget {
  const MyPostsTab({Key? key}) : super(key: key);

  @override
  State<MyPostsTab> createState() => _MyPostsTabState();
}

class _MyPostsTabState extends State<MyPostsTab> {
  String? currentUserId;

  @override
  void initState() {
    super.initState();
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      currentUserId = user.uid;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (currentUserId == null) {
      return const Center(child: Text('Not logged in'));
    }

    return StreamBuilder(
      stream: FirebaseDatabase.instance
          .ref('Posts')
          .orderByChild('userId')
          .equalTo(currentUserId)
          .onValue,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (!snapshot.hasData || snapshot.data?.snapshot.value == null) {
          return const Center(child: Text('No posts yet!'));
        }

        final postMap =
        Map<String, dynamic>.from(snapshot.data!.snapshot.value as Map);
        final posts = postMap.entries.toList();

        return Padding(
          padding: const EdgeInsets.all(8.0),
          child: GridView.builder(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
              childAspectRatio: 0.75,
            ),
            itemCount: posts.length,
            itemBuilder: (context, index) {
              final postId = posts[index].key;
              final post = Map<String, dynamic>.from(posts[index].value);
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
      },
    );
  }
}
