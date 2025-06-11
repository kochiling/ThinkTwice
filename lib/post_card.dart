import 'package:flutter/material.dart';

class PostCard extends StatelessWidget {
  final String postId;
  final String imageUrl;
  final String title;
  final String userProfile;
  final String username;
  final bool isLiked;
  final int likeCount;
  final VoidCallback onLike;

  const PostCard({
    Key? key,
    required this.postId,
    required this.imageUrl,
    required this.title,
    required this.userProfile,
    required this.username,
    required this.isLiked,
    required this.likeCount,
    required this.onLike,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(color: Colors.grey, blurRadius: 6),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min, // important!
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (imageUrl.isNotEmpty)
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: ClipRRect(
                borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
                child: Image.network(
                  imageUrl,
                  height: 120,
                  width: double.infinity,
                  fit: BoxFit.cover,
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.only(left:8.0,right: 8.0,top: 5.0,bottom:2.0),
            child: Text(
              title.length > 100 ? title.substring(0, 100) : title,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 5),
            child: Row(
              children: [
                CircleAvatar(backgroundImage: NetworkImage(userProfile), radius: 14),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    username,
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Text('$likeCount', style: const TextStyle(fontSize: 12)),
                IconButton(
                  icon: Icon(
                    isLiked ? Icons.favorite : Icons.favorite_border,
                    color: isLiked ? Colors.red : Colors.grey,
                    size: 18,
                  ),
                  onPressed: onLike,
                )
              ],
            ),
          ),
        ],
      ),

    );
  }
}
