import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';

class AddPost extends StatefulWidget {
  const AddPost({Key? key}) : super(key: key);

  @override
  State<AddPost> createState() => _AddPostState();
}

class _AddPostState extends State<AddPost> {
  final _auth = FirebaseAuth.instance;
  final _dbRef = FirebaseDatabase.instance.ref();
  final _picker = ImagePicker();

  String? username;
  String? profileUrl;
  String? userId;

  final titleController = TextEditingController();
  final descriptionController = TextEditingController();
  List<File> selectedImages = [];

  @override
  void initState() {
    super.initState();
    fetchUserData();
  }

  Future<void> fetchUserData() async {
    final user = _auth.currentUser;
    if (user != null) {
      userId = user.uid;
      final userSnap = await _dbRef.child("Users").child(userId!).get();
      if (userSnap.exists) {
        final userData = Map<String, dynamic>.from(userSnap.value as Map);
        setState(() {
          username = userData["username"];
          profileUrl = userData["profile_pic"];
        });
      }
    }
  }

  Future<void> showImageSourceActionSheet() async {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: Icon(Icons.photo_library),
              title: Text('Pick from Gallery'),
              onTap: () {
                Navigator.pop(context);
                pickImagesFromGallery();
              },
            ),
            ListTile(
              leading: Icon(Icons.camera_alt),
              title: Text('Take a Photo'),
              onTap: () {
                Navigator.pop(context);
                captureImageFromCamera();
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> pickImagesFromGallery() async {
    final pickedFiles = await _picker.pickMultiImage();
    if (pickedFiles != null && pickedFiles.isNotEmpty) {
      int availableSlots = 10 - selectedImages.length;
      if (availableSlots <= 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("You can only upload up to 10 images.")),
        );
        return;
      }

      final limitedPickedFiles = pickedFiles.take(availableSlots).toList();

      setState(() {
        selectedImages.addAll(limitedPickedFiles.map((e) => File(e.path)));
      });

      if (pickedFiles.length > availableSlots) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Only $availableSlots images can be added.")),
        );
      }
    }
  }


  Future<void> captureImageFromCamera() async {
    final pickedFile = await _picker.pickImage(source: ImageSource.camera);
    if (pickedFile != null) {
      setState(() {
        selectedImages.add(File(pickedFile.path));
      });
    }
  }

  Future<void> uploadPost() async {
    if (titleController.text.isEmpty || descriptionController.text.isEmpty || selectedImages.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Please complete all fields and select images")),
      );
      return;
    }

    final postRef = _dbRef.child("Posts").push();
    final String postId = postRef.key!;
    List<String> imageUrls = [];

    for (File image in selectedImages) {
      final fileName = DateTime.now().millisecondsSinceEpoch.toString();
      final ref = FirebaseStorage.instance.ref().child("PostImages/$fileName.jpg");
      await ref.putFile(image);
      final url = await ref.getDownloadURL();
      imageUrls.add(url);
    }

    await postRef.set({
      "postId": postId,
      "userId": userId,
      "username": username,
      "userProfile": profileUrl,
      "title": titleController.text,
      "description": descriptionController.text,
      "images": imageUrls,
      "timestamp": DateTime.now().toString(),
    });

    Navigator.pop(context);
  }

  Widget buildImagePreview() {
    return SizedBox(
      height: 100,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: selectedImages.length < 10
            ? selectedImages.length + 1
            : selectedImages.length,
        itemBuilder: (context, index) {
          // Show add photo box only if images are fewer than 10
          if (index == selectedImages.length && selectedImages.length < 10) {
            return GestureDetector(
              onTap: showImageSourceActionSheet,
              child: Container(
                width: 100,
                height: 100,
                margin: EdgeInsets.symmetric(horizontal: 4),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey),
                  borderRadius: BorderRadius.circular(8),
                  color: Colors.grey[200],
                ),
                child: Center(
                  child: Icon(Icons.add, size: 30, color: Colors.grey[700]),
                ),
              ),
            );
          }

          final image = selectedImages[index];
          return Stack(
            children: [
              Container(
                margin: EdgeInsets.symmetric(horizontal: 4),
                width: 100,
                height: 100,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.file(image, fit: BoxFit.cover),
                ),
              ),
              Positioned(
                top: 2,
                right: 2,
                child: GestureDetector(
                  onTap: () {
                    setState(() {
                      selectedImages.removeAt(index);
                    });
                  },
                  child: CircleAvatar(
                    radius: 12,
                    backgroundColor: Colors.black54,
                    child: Icon(Icons.close, size: 16, color: Colors.white),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Create Post"),
        // actions: [
        //   TextButton.icon(
        //     onPressed: uploadPost,
        //     icon: Icon(Icons.send, color: Color(0xFFE991AA)),
        //     label: Text("Post", style: TextStyle(color: Color(0xFFE991AA))),
        //   )
        // ],
      ),
      body: username == null
          ? Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundImage:
                  profileUrl != null ? NetworkImage(profileUrl!) : null,
                  radius: 25,
                  child: profileUrl == null ? Icon(Icons.person) : null,
                ),
                SizedBox(width: 10),
                Text(username ?? "User", style: TextStyle(fontSize: 18)),
              ],
            ),
            SizedBox(height: 20),
            TextField(
              controller: titleController,
              maxLength: 100,
              decoration: InputDecoration(
                hintText: "Title",
                counterText: "",
              ),
            ),
            SizedBox(height: 10),
            TextField(
              controller: descriptionController,
              maxLines: 5,
              decoration: InputDecoration(
               hintText: "Description",
                border: OutlineInputBorder(),
              ),
            ),
            SizedBox(height: 10),
            buildImagePreview(),
            SizedBox(height: 30),
            /// Bottom Post Button
            Align(
              alignment: FractionalOffset.bottomCenter,
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: uploadPost,
                  icon: Icon(Icons.send),
                  label: Text("Post"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Color(0xFFE991AA),
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
