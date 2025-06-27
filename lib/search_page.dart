import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:thinktwice/post_card.dart';
import 'package:thinktwice/post_detailed_page2.dart';

class SearchPage extends StatefulWidget {
  @override
  _SearchPageState createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  final TextEditingController _searchController = TextEditingController();
  List<Map<String, dynamic>> _results = [];
  bool _loading = false;

  void _searchPosts(String query) async {
    setState(() {
      _loading = true;
      _results = [];
    });
    final snap = await FirebaseDatabase.instance.ref('Posts').get();
    if (snap.exists) {
      final postMap = Map<String, dynamic>.from(snap.value as Map);
      final posts = postMap.entries.map((e) {
        final post = Map<String, dynamic>.from(e.value);
        post['postId'] = e.key;
        return post;
      }).toList();
      final lowerQuery = query.toLowerCase();
      final filtered = posts.where((post) {
        final username = (post['username'] ?? '').toString().toLowerCase();
        final title = (post['title'] ?? '').toString().toLowerCase();
        final desc = (post['description'] ?? '').toString().toLowerCase();
        return username.contains(lowerQuery) || title.contains(lowerQuery) || desc.contains(lowerQuery);
      }).toList();
      setState(() {
        _results = filtered;
        _loading = false;
      });
    } else {
      setState(() {
        _results = [];
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: true,
        title: SizedBox(
          height: 40,
          child: TextField(
            controller: _searchController,
            autofocus: true,
            decoration: InputDecoration(
              hintText: 'Search...',
              contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(20),
                borderSide: const BorderSide(color: Color(0xFFE991AA), width: 1),),
              filled: true,
              fillColor: Colors.white,
              suffixIcon: IconButton(
                icon: const Icon(Icons.search),
                onPressed: () => _searchPosts(_searchController.text),
              ),
            ),
            onSubmitted: _searchPosts,
            textInputAction: TextInputAction.search,
          ),
        ),
        //backgroundColor: Colors.pink[100],
      ),
      body: Padding(
        padding: const EdgeInsets.all(8.0),
        child: LayoutBuilder(
          builder: (context, constraints) => Column(
            children: [
              const SizedBox(height: 8),
              if (_loading)
                const Center(child: CircularProgressIndicator()),
              if (!_loading && _results.isEmpty && _searchController.text.isNotEmpty)
                const Text('No results found.'),
              if (!_loading && _results.isNotEmpty)
                Expanded(
                  child: GridView.builder(
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      crossAxisSpacing: 8,
                      mainAxisSpacing: 8,
                      childAspectRatio: 0.75,
                    ),
                    itemCount: _results.length,
                    itemBuilder: (context, index) {
                      final post = _results[index];
                      final postId = post['postId'] ?? '';
                      final title = post['title'] ?? '';
                      final username = post['username'] ?? '';
                      final userProfile = post['userProfile'] ?? '';
                      final images = List<String>.from(post['images'] ?? []);
                      final firstImage = images.isNotEmpty ? images[0] : '';
                      final likes = Map<String, dynamic>.from(post['Likes'] ?? {});
                      final likeCount = likes.length;
                      return GestureDetector(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => PostDetailPage2(
                                postId: postId,
                                postuserId: post['userId'],
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
                          isLiked: false,
                          likeCount: likeCount,
                          onLike: () {}, // No like in search
                        ),
                      );
                    },
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
