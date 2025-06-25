import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:thinktwice/auth_service.dart';
import 'package:thinktwice/login.dart';
import 'package:thinktwice/my_posts_tab.dart';
import 'package:thinktwice/saved_posts_tab.dart';


class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> with SingleTickerProviderStateMixin {
  final _auth = AuthService();
  late TabController _tabController;
  String username = '';
  String email = '';
  String profilePicUrl = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _fetchUserData();
  }

  Future<void> _fetchUserData() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    final ref = FirebaseDatabase.instance.ref().child('Users').child(uid!);

    final snapshot = await ref.get();
    if (snapshot.exists) {
      final userData = snapshot.value as Map<dynamic, dynamic>;
      setState(() {
        username = userData['username'] ?? 'No Username';
        email = userData['email'] ?? 'No Email';
        profilePicUrl = userData['profile_pic'] ?? '';
      });
    }
  }

  void _logout() async {
    await _auth.signout();
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => const LoginPage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: _logout,
          ),
        ],
        backgroundColor: const Color(0xFFF6B1C3), // Soft pink
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
            decoration: const BoxDecoration(
              color: Color(0x50F6DFEC), // Light pink background
              borderRadius: BorderRadius.vertical(bottom: Radius.circular(20)),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 40,
                  backgroundImage: profilePicUrl.isNotEmpty
                      ? NetworkImage(profilePicUrl)
                      : const AssetImage('assets/default_profile.png') as ImageProvider,
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        username,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFFB47EB3),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        email,
                        style: const TextStyle(
                          fontSize: 16,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          TabBar(
            controller: _tabController,
            labelColor: Color(0xFFB47EB3),
            unselectedLabelColor: Colors.grey,
            indicatorColor: Color(0xFFB47EB3),
            tabs: const [
              Tab(text: 'My Posts'),
              Tab(text: 'Saved Posts'),
            ],
          ),
          Expanded(
            child:TabBarView(
              controller: _tabController,
              children: const [
                MyPostsTab(),
                SavedPostsTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
