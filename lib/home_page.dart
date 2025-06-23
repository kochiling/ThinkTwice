import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:thinktwice/add_post.dart';
import 'package:thinktwice/post_card.dart';
import 'package:thinktwice/post_detailed_page2.dart';
import 'fetch_data.dart';
import 'insert_page.dart';
import 'package:thinktwice/auth_service.dart';
import 'package:thinktwice/login.dart';
import 'package:thinktwice/travel_tips.dart';
import 'package:thinktwice/gemini.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:thinktwice/post_details_page.dart';
import 'package:thinktwice/post_detailed_page2.dart';

class HomePage extends StatefulWidget{
  const HomePage ({Key? key}): super (key: key);

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {

  String? currentUserId;

  @override
  void initState() {
    super.initState();
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('You must be logged in to use the app.')),
        );
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const LoginPage()));
      });
    } else {
      setState(() {
        currentUserId = user.uid;
      });
    }
  }

  @override
  Widget build (BuildContext context) {
    return SafeArea(
      child: Scaffold(
        appBar: AppBar(
          title: Text("ThinkTwice"),
        ),
        body: StreamBuilder(
      stream: FirebaseDatabase.instance.ref('Posts').onValue,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (!snapshot.hasData || snapshot.data?.snapshot.value == null) {
          return const Center(child: Text('No posts found'));
        }

        final postMap = Map<String, dynamic>.from(snapshot.data!.snapshot.value as Map);
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
              final currentUserId1 = currentUserId; // Replace with your logic
              final isLiked = likes.containsKey(currentUserId1);
              final likeCount = likes.length;
              final postuserId = post['userId'];

              return GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => PostDetailPage2(
                        postId: postId,
                        postuserId: postuserId,
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
                    final postRef = FirebaseDatabase.instance.ref('Posts/$postId/Likes/$currentUserId');
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
    ),

    floatingActionButton: FloatingActionButton(
            onPressed: (){
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (child) => AddPost(),
                ),
              );
            },
            child: const Icon(
                Icons.add
            )
        ),
      
      ),
    );
  }
}

