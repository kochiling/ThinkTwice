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

  bool _agreedToTerms = false;
  String? _termsError;

  double _loadingProgress = 0.0;

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
      _loadingProgress = 0.0;
    });

    void updateProgress(double value) {
      setState(() {
        _loadingProgress = value.clamp(0.0, 1.0);
      });
    }

    try {
      final user = await _auth.createUserWithEmailAndPassword(_email.text, _password.text);
      updateProgress(0.2);
      if (user != null) {
        final uid = FirebaseAuth.instance.currentUser?.uid;
        late DatabaseReference dbref = FirebaseDatabase.instance.ref();

        String imageUrl = 'https://firebasestorage.googleapis.com/v0/b/thinktwice-clzy.firebasestorage.app/o/profile_pic3.jpg?alt=media&token=0cd568e8-6b1f-4233-a285-2d598cca8db9';

        if (_imageFile != null) {
          final imgRef = FirebaseStorage.instance
              .ref()
              .child('Profile_Images/$uid.jpg');
          uploadTask = imgRef.putFile(_imageFile!);
          uploadTask!.snapshotEvents.listen((event) {
            if (event.totalBytes > 0) {
              updateProgress(0.2 + 0.5 * (event.bytesTransferred / event.totalBytes));
            }
          });
          final snapshot = await uploadTask!.whenComplete(() => null);
          imageUrl = await snapshot.ref.getDownloadURL();
          log("Custom image uploaded: $imageUrl");
        } else {
          log("No image selected. Using default image.");
        }
        updateProgress(0.8);
        await dbref.child('Users').child(uid!).set({
          'id': uid,
          'username': _name.text,
          'email': _email.text,
          'country': selectedCountryName?.isNotEmpty == true ? selectedCountryName : 'Malaysia',
          'profile_pic': imageUrl,
        });
        updateProgress(1.0);
        log("User created and data saved successfully");
        await Future.delayed(const Duration(milliseconds: 400));
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => CurveBar(selectedIndex: 0)),
          (Route<dynamic> route) => false,
        );
      }
    } catch (e) {
      log("Sign Up Error: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Sign Up Failed: "+e.toString())),
      );
    } finally {
      setState(() {
        _isLoading = false;
        _loadingProgress = 0.0;
      });
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
      _termsError = !_agreedToTerms ? 'You must agree to the terms and conditions' : null;
    });

    if (_nameError == null &&
        _emailError == null &&
        _passwordError == null &&
        _confirmPasswordError == null &&
        _agreedToTerms &&
        _confirmpassword.text == _password.text ) {
      print('Sign Up Successful!');
      _signup();
    }
  }

  Widget build (BuildContext context){
    return Scaffold(
        backgroundColor: Colors.white,
        body: Stack(
          children: [
            SafeArea(
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

                      const SizedBox(height: 10),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8.0),
                        child: Row(
                          children: [
                            Checkbox(
                              value: _agreedToTerms,
                              activeColor: Color(0xFFE991AA),
                              onChanged: (value) {
                                setState(() {
                                  _agreedToTerms = value ?? false;
                                  if (_agreedToTerms) _termsError = null;
                                });
                              },
                            ),
                            Expanded(
                              child: GestureDetector(
                                onTap: () {
                                  setState(() {
                                    _agreedToTerms = !_agreedToTerms;
                                    if (_agreedToTerms) _termsError = null;
                                  });
                                },
                                child: const Text(
                                  'I agree to the Terms and Conditions',
                                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (_termsError != null)
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 2.0),
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              _termsError!,
                              style: TextStyle(color: Colors.red, fontSize: 13),
                            ),
                          ),
                        ),
                      const SizedBox(height: 30),
                      InkWell(
                        onTap: _agreedToTerms ? _handleSignUp : null,
                        child: Container(
                          height: 60,
                          width: 350,
                          decoration: BoxDecoration(
                            color: _agreedToTerms ? Color (0xFFE991AA) : Colors.grey,
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
                    ],
                  ),
                ),
              ),
            ),
            if (_isLoading)
              Container(
                color: Colors.black.withOpacity(0.3),
                child: Center(
                  child: SizedBox(
                    width: 300,
                    child: Stack(
                      alignment: Alignment.topLeft,
                      children: [
                        // Loading bar
                        Padding(
                          padding: const EdgeInsets.only(top: 60.0),
                          child: LinearProgressIndicator(
                            value: _loadingProgress,
                            minHeight: 16,
                            backgroundColor: Colors.white,
                            color: Color(0xFFE991AA),
                          ),
                        ),
                        // Moving image
                        AnimatedPositioned(
                          duration: const Duration(milliseconds: 100),
                          left: (_loadingProgress * 260).clamp(0.0, 260.0),
                          top: 0,
                          child: SizedBox(
                            width: 40,
                            height: 40,
                            child: ClipOval(
                              child: Image.asset(
                                'images/profile_pic4.jpg',
                                fit: BoxFit.cover,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
    );
  }
}