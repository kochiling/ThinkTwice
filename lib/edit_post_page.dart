import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:photo_view/photo_view.dart';
import 'package:photo_view/photo_view_gallery.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';

import 'package:thinktwice/profile_page.dart';
import 'package:thinktwice/nagivation_bar.dart';

class EditPostPage extends StatefulWidget {
  final String postId;
  final String initialTitle;
  final String initialDescription;
  final String username;
  final String userProfile;
  final List<String> images;

  const EditPostPage({
    Key? key,
    required this.postId,
    required this.initialTitle,
    required this.initialDescription,
    required this.username,
    required this.userProfile,
    required this.images,
  }) : super(key: key);

  @override
  State<EditPostPage> createState() => _EditPostPageState();
}

class _EditPostPageState extends State<EditPostPage> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _titleController;
  late TextEditingController _descController;
  final database = FirebaseDatabase.instance.ref();
  final _picker = ImagePicker();
  bool _loading = false;
  List<String> existingImageUrls = [];
  List<File> newImages = [];

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.initialTitle);
    _descController = TextEditingController(text: widget.initialDescription);
    existingImageUrls = List<String>.from(widget.images);
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    super.dispose();
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
      int availableSlots = 10 - (existingImageUrls.length + newImages.length);
      if (availableSlots <= 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("You can only upload up to 10 images.")),
        );
        return;
      }
      final limitedPickedFiles = pickedFiles.take(availableSlots).toList();
      setState(() {
        newImages.addAll(limitedPickedFiles.map((e) => File(e.path)));
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
        newImages.add(File(pickedFile.path));
      });
    }
  }

  goToProfile(BuildContext context) => Navigator.push(
    context,
    MaterialPageRoute(builder: (context) => const ProfilePage()),
  );

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      // Upload new images
      List<String> allImageUrls = List<String>.from(existingImageUrls);
      for (File image in newImages) {
        final fileName = DateTime.now().millisecondsSinceEpoch.toString();
        final ref = FirebaseStorage.instance.ref().child("PostImages/$fileName.jpg");
        await ref.putFile(image);
        final url = await ref.getDownloadURL();
        allImageUrls.add(url);
      }
      await database.child('Posts/${widget.postId}/title').set(_titleController.text.trim());
      await database.child('Posts/${widget.postId}/description').set(_descController.text.trim());
      await database.child('Posts/${widget.postId}/images').set(allImageUrls);
      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const CurveBar(selectedIndex: 2)),
          (route) => false,
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to update post: $e')),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Widget buildImagePreview() {
    final totalImages = existingImageUrls.length + newImages.length;
    return SizedBox(
      height: 100,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: totalImages < 10 ? totalImages + 1 : totalImages,
        itemBuilder: (context, index) {
          if (index < existingImageUrls.length) {
            final url = existingImageUrls[index];
            return Stack(
              children: [
                Container(
                  margin: EdgeInsets.symmetric(horizontal: 4),
                  width: 100,
                  height: 100,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.network(url, fit: BoxFit.cover),
                  ),
                ),
                Positioned(
                  top: 2,
                  right: 2,
                  child: GestureDetector(
                    onTap: () {
                      setState(() {
                        existingImageUrls.removeAt(index);
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
          } else if (index < totalImages) {
            final image = newImages[index - existingImageUrls.length];
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
                        newImages.removeAt(index - existingImageUrls.length);
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
          } else {
            // Add photo button
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
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Edit Post')),
      body: SingleChildScrollView(
        child: usernameSection(),
      ),
    );
  }

  Widget usernameSection() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(backgroundImage: NetworkImage(widget.userProfile), radius: 25),
                const SizedBox(width: 10),
                Text(widget.username, style: const TextStyle(fontSize: 18)),
              ],
            ),
            const SizedBox(height: 20),
            TextFormField(
              controller: _titleController,
              maxLength: 100,
              decoration: const InputDecoration(hintText: "Title", counterText: ""),
              validator: (v) => v == null || v.trim().isEmpty ? 'Title required' : null,
            ),
            const SizedBox(height: 10),
            TextFormField(
              controller: _descController,
              maxLines: 5,
              decoration: const InputDecoration(hintText: "Description", border: OutlineInputBorder()),
              validator: (v) => v == null || v.trim().isEmpty ? 'Description required' : null,
            ),
            const SizedBox(height: 10),
            buildImagePreview(),
            const SizedBox(height: 30),
            Align(
              alignment: FractionalOffset.bottomCenter,
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _loading ? null : _save,
                  icon: _loading ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.save),
                  label: const Text("Save"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFE991AA),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
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
