import 'dart:developer';
import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:thinktwice/login.dart';
import 'package:country_code_picker/country_code_picker.dart';
import 'auth_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:thinktwice/nagivation_bar.dart';
import 'package:image_picker/image_picker.dart';


class SignUpPage extends StatefulWidget{

  const SignUpPage ({Key? key}): super (key: key);

  @override
  State<SignUpPage> createState() => _SignUpPageState();

}

class _SignUpPageState extends State<SignUpPage> {

  final _auth = AuthService();
  bool _isLoading = false;

  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  final _name = TextEditingController();
  final _confirmpassword = TextEditingController();
  String? selectedCountryName;
  String? _errorText;

  String? _nameError;
  String? _emailError;
  String? _passwordError;
  String? _confirmPasswordError;

  File? _imageFile;
  UploadTask? uploadTask;
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _password.addListener(_validatePassword);
  }


  @override
  void dispose() {
    super.dispose();
    _name.dispose();
    _email.dispose();
    _password.dispose();
    _confirmpassword.dispose();
  }

  goToHome(BuildContext context) => Navigator.push(
    context,
    //MaterialPageRoute(builder: (context) => const HomePage()),
    MaterialPageRoute(builder: (context) => CurveBar()),
  );

  void _validatePassword() {
    String password = _password.text;
    List<String> errors = [];

    if (password.length < 6) {
      errors.add("- At least 6 characters");
    }

    if (!RegExp(r'[a-z]').hasMatch(password)) {
      errors.add("- At least one lowercase letter");
    }

    if (!RegExp(r'[A-Z]').hasMatch(password)) {
      errors.add("- At least one uppercase letter");
    }

    if (!RegExp(r'\d').hasMatch(password)) {
      errors.add("- At least one number");
    }

    if (!RegExp(r"[!@#\$&*~^%()\[\]{}<>?.,:;""\\|/_+=-]").hasMatch(password)) {
        errors.add("- At least one special character");
    }

  setState(() {
  _passwordError = errors.isEmpty ? null : "Password should contain:\n${errors.join('\n')}";
  });
}

  void _showImageSourceDialog() {
    showModalBottomSheet(
      context: context,
      builder: (context) => Wrap(
        children: [
          ListTile(
            leading: const Icon(Icons.photo_library),
            title: const Text("Choose from Gallery"),
            onTap: () {
              Navigator.pop(context);
              _pickImage(ImageSource.gallery);
            },
          ),
          ListTile(
            leading: const Icon(Icons.camera_alt),
            title: const Text("Take a Photo"),
            onTap: () {
              Navigator.pop(context);
              _pickImage(ImageSource.camera);
            },
          ),
        ],
      ),
    );
  }

  Future<void> _pickImage(ImageSource source) async {
    final pickedFile = await _picker.pickImage(source: source);

    if (pickedFile != null) {
      setState(() {
        _imageFile = File(pickedFile.path);
      });
    }
  }

  // void _saveImage () async {
  //
  //   final imgDb = FirebaseStorage.instance.ref().child('Profile_Images/${_imageFile?.path}');
  //
  //   uploadTask = imgDb.putFile(_imageFile!);
  //
  //   final snapshot = await uploadTask!.whenComplete(()=>null);
  //
  //   final downloadUrl = await snapshot.ref.getDownloadURL();
  //
  //   log("${downloadUrl}");
  //
  // }

  _signup() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final user = await _auth.createUserWithEmailAndPassword(_email.text, _password.text);
      if (user != null) {
        final uid = FirebaseAuth.instance.currentUser?.uid;
        late DatabaseReference dbref = FirebaseDatabase.instance.ref();

        String imageUrl = 'https://firebasestorage.googleapis.com/v0/b/thinktwice-clzy.firebasestorage.app/o/profile_pic.jpg?alt=media&token=9f2634b8-b271-4f74-923c-36161d2f728a';
        //String imageUrl = 'https://firebasestorage.googleapis.com/v0/b/thinktwice-clzy.firebasestorage.app/o/profile_pic.jpg?alt=media&token=9f2634b8-b271-4f74-923c-36161d2f728a';

        if (_imageFile != null) {
          // Upload image
          final imgRef = FirebaseStorage.instance
              .ref()
              .child('Profile_Images/$uid.jpg'); // Use UID as filename
          uploadTask = imgRef.putFile(_imageFile!);
          final snapshot = await uploadTask!.whenComplete(() => null);
          imageUrl = await snapshot.ref.getDownloadURL();
          log("Custom image uploaded: $imageUrl");
        } else {
          log("No image selected. Using default image.");
        }

        // Save user data
        await dbref.child('Users').child(uid!).set({
          'id': uid,
          'username': _name.text,
          'email': _email.text,
          //'country': selectedCountryName ?? '',
          'country': selectedCountryName?.isNotEmpty == true ? selectedCountryName : 'Malaysia',
          'profile_pic': imageUrl,
        });

        log("User created and data saved successfully");
        goToHome(context);

        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      log("Sign Up Error: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Sign Up Failed: ${e.toString()}")),
      );
    }
  }



// _signup() async {
//     try {
//       final user = await _auth.createUserWithEmailAndPassword(_email.text, _password.text);
//       if (user != null) {
//         final uid = FirebaseAuth.instance.currentUser?.uid;
//
//         // Reference to the Realtime Database
//         late DatabaseReference dbref = FirebaseDatabase.instance.ref();
//
//         // Save user data
//         await dbref.child('Users').child(uid!).set({
//           'id': uid,
//           'username': _name.text,
//           'email': _email.text,
//           'country': selectedCountryName ?? '',
//           'profile_pic': '',
//         });
//
//         log("User created and data saved successfully");
//         log(uid);
//         goToHome(context);
//       }
//     } catch (e) {
//       log("Sign Up Error: $e");
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(content: Text("Sign Up Failed: ${e.toString()}")),
//       );
//     }
//   }


  void _handleSignUp() {
    setState(() {
      _nameError = _name.text.isEmpty ? 'Username is required' : null;
      _emailError = _email.text.isEmpty ? 'Email is required' : null;
      _passwordError = _password.text.isEmpty ? 'Password is required' : null;
      _confirmPasswordError = _confirmpassword.text.isEmpty
          ? 'Confirm Password is required'
          : (_confirmpassword.text != _password.text ? 'Passwords do not match' : null);
    });

    if (_nameError == null &&
        _emailError == null &&
        _passwordError == null &&
        _confirmPasswordError == null && _confirmpassword.text == _password.text ) {
      print('Sign Up Successful!');
      _signup();
    }
  }

  Widget build (BuildContext context){
    return Scaffold(
        backgroundColor: Colors.white,

        body: SafeArea(
            child: SingleChildScrollView(
                child: Center(
                  child: Column(
                    spacing: 5,
                    children: [
                      SizedBox( height: 200, width: 200,
                        child: Padding(
                          padding: const EdgeInsets.all(6.0),
                          child: const Image(image: AssetImage('images/Logo_tt_1.jpg')
                          ),
                        ),
                      ),
                      const Padding(
                        padding: EdgeInsets.all(8.0),
                        child: Text("Sign Up Now",
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 30, fontFamily: 'ComicSans'),
                        ),
                      ),
                      SizedBox(height: 10),
                      GestureDetector(
                        onTap: _showImageSourceDialog,
                        child: CircleAvatar(
                          radius: 40,
                          backgroundImage: _imageFile != null
                              ? FileImage(_imageFile!)
                              : null,
                          child: _imageFile == null
                              ? const Icon(Icons.person_2_rounded, size: 40)
                              : null,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: TextField(
                          controller: _name,
                          decoration: InputDecoration(
                            hintText: "Username",
                            errorText: _nameError,
                            prefixIcon: const Icon(Icons.person_outlined, color: Color(0xFFE991AA)),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(30),
                              borderSide: const BorderSide(color: Colors.grey),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(30),
                              borderSide: const BorderSide(color: Color(0xFFE991AA), width: 2),
                            ),
                            filled: true,
                            fillColor: Colors.white,
                            contentPadding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 20.0),
                          ),
                        ),
                      ),

                      const SizedBox(height: 10),
                      Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: TextField(
                          controller: _email,
                          decoration: InputDecoration(
                            hintText: "Email",
                            errorText: _emailError,
                            prefixIcon: const Icon(Icons.email_outlined, color: Color(0xFFE991AA)),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(30),
                              borderSide: const BorderSide(color: Colors.grey),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(30),
                              borderSide: const BorderSide(color: Color(0xFFE991AA), width: 2),
                            ),
                            filled: true,
                            fillColor: Colors.white,
                            contentPadding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 20.0),
                          ),
                          keyboardType: TextInputType.emailAddress ,
                        ),
                      ),

                      const SizedBox(height: 10),
                      Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: TextField(
                          controller: _password,
                          obscureText: _obscurePassword,
                          decoration: InputDecoration(
                            hintText: "Password",
                            errorText: _passwordError,
                            prefixIcon: const Icon(Icons.lock_outlined, color: Color(0xFFE991AA)),
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscurePassword ? Icons.visibility_off : Icons.visibility,
                                color: Colors.grey,
                              ),
                              onPressed: () {
                                setState(() {
                                  _obscurePassword= !_obscurePassword;
                                });
                              },
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(30),
                              borderSide: const BorderSide(color: Colors.grey),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(30),
                              borderSide: const BorderSide(color: Color(0xFFE991AA), width: 2),
                            ),
                            filled: true,
                            fillColor: Colors.white,
                            contentPadding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 20.0),
                          ),
                        ),
                      ),

                      const SizedBox(height: 10),
                      Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: TextField(
                          controller: _confirmpassword,
                          obscureText: _obscureConfirmPassword,
                          decoration: InputDecoration(
                            hintText: "Confirm Password",
                            errorText: _confirmPasswordError,
                            prefixIcon: const Icon(Icons.lock_outlined, color: Color(0xFFE991AA)),
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscureConfirmPassword ? Icons.visibility_off : Icons.visibility,
                                color: Colors.grey,
                              ),
                              onPressed: () {
                                setState(() {
                                  _obscureConfirmPassword = !_obscureConfirmPassword;
                                });
                              },
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(30),
                              borderSide: const BorderSide(color: Colors.grey),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(30),
                              borderSide: const BorderSide(color: Color(0xFFE991AA), width: 2),
                            ),
                            filled: true,
                            fillColor: Colors.white,
                            contentPadding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 20.0),
                          ),
                          onChanged: (_) {
                            if (_errorText != null) {
                              setState(() {
                                _errorText = null;
                              });
                            }
                          },
                        ),
                      ),


                      const SizedBox(height: 10),
                      Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: Colors.grey, // Choose any color you want for the outline
                              width: 1.0,
                            ),
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          child: CountryCodePicker(
                            onChanged: (value) {
                              selectedCountryName = value.name;
                              log('Selected Country: $selectedCountryName');
                            },
                            initialSelection: 'MY',
                            showCountryOnly: true,
                            showOnlyCountryWhenClosed: true,
                            alignLeft: true,
                            textStyle: const TextStyle(fontSize: 16),
                            flagDecoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(7),
                            ),
                            comparator: (a, b) => a.name?.compareTo(b.name ?? '') ?? 0,
                            onInit: (value) => debugPrint('on init ${value?.name}'),
                            searchDecoration: const InputDecoration(
                              labelText: 'Search country',
                              hintText: 'Enter country name',
                              prefixIcon: Icon(Icons.search),
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 30),
                      InkWell(
                        onTap: _handleSignUp,
                        child: Container(
                          height: 60,
                          width: 350,
                          decoration: BoxDecoration(
                            color: Color (0xFFE991AA),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Center(
                            child: Text("Sign Up",
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                )),
                          ),
                        ),
                      ),

                      Padding(
                        padding: EdgeInsets.only(left: 8.0,top: 30.0,right:8.0, bottom: 100.0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Text(
                              'Already Have an Account? 🙆‍♀️ ',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                                fontFamily: 'ComicSans',
                              ),
                            ),
                            GestureDetector(
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (context) => const LoginPage()),
                                );
                              },
                              child: const Text(
                                'Login Now👈',
                                style: TextStyle(
                                  color: Colors.blue,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                  fontFamily: 'ComicSans',
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (_isLoading)
                        Container(
                          color: Color(0xFFE991AA),
                          child: Center(
                            child: CircularProgressIndicator(),
                          ),
                        ),
                    ],
              ),
            )
        )),
    );
  }
}