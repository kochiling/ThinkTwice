import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:thinktwice/nagivation_bar.dart';
import 'package:thinktwice/sign_up_page.dart';
import 'auth_service.dart';
import 'package:thinktwice/home_page.dart';
import 'dart:developer';

class LoginPage extends StatefulWidget{
  const LoginPage ({Key? key}): super (key: key);

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage>{

  final _auth = AuthService();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _obscureText = true;
  String? _emailError;
  String? _passwordError;

  @override
  void dispose() {
    super.dispose();
    _email.dispose();
    _password.dispose();
  }

  goToHome(BuildContext context) => Navigator.pushReplacement(
    context,
    //MaterialPageRoute(builder: (context) => HomePage()),
    MaterialPageRoute(builder: (context) => CurveBar()),
  );

  _login() async {
    final user = await _auth.loginUserWithEmailAndPassword(_email.text, _password.text);

    if (user != null) {
      log("User Logged In");
      goToHome(context);
    }
  }

  void _handleLoginIn() {
    setState(() {
      _emailError = _email.text.isEmpty ? 'Email is required' : null;
      _passwordError = _password.text.isEmpty ? 'Password is required' : null;
    });

    if (_emailError == null &&
        _passwordError == null ) {
      print('Sign Up Successful!');
      _login();
    }
  }

  void _showForgotPasswordDialog() {
    final TextEditingController resetEmailController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Reset Password"),
        content: TextField(
          controller: resetEmailController,
          keyboardType: TextInputType.emailAddress,
          decoration: const InputDecoration(
            labelText: "Enter your email",
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () async {
              try {
                await FirebaseAuth.instance.sendPasswordResetEmail(
                  email: resetEmailController.text.trim(),
                );
                Navigator.of(context).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Password reset email sent.")),
                );
              } catch (e) {
                Navigator.of(context).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text("Error: ${e.toString()}")),
                );
              }
            },
            child: const Text("Send"),
          ),
        ],
      ),
    );
  }


  @override
  Widget build (BuildContext context){
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Center(
            child: Column(
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
                   child: Text("Login",
                   style: TextStyle(fontWeight: FontWeight.bold, fontSize: 30, fontFamily: 'ComicSans'),
                   ),
                 ),
                 const SizedBox(height: 10),
                 Padding(
                   padding: const EdgeInsets.all(8.0),
                   child: TextField(
                     controller: _email,
                     decoration: InputDecoration(
                       hintText: "Email",
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
                     keyboardType: TextInputType.emailAddress,
                   ),
                 ),
                 const SizedBox(height: 10),
                 Padding(
                   padding: const EdgeInsets.all(8.0),
                   child: TextField(
                     controller: _password,
                     obscureText: _obscureText,
                     decoration: InputDecoration(
                       hintText: "Password",
                       prefixIcon: const Icon(Icons.lock_outlined, color: Color(0xFFE991AA)),
                       suffixIcon: IconButton(
                         icon: Icon(
                           _obscureText ? Icons.visibility_off : Icons.visibility,
                           color: Colors.grey,
                         ),
                         onPressed: () {
                           setState(() {
                             _obscureText = !_obscureText;
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
                     keyboardType: TextInputType.visiblePassword,
                   ),
                 ),
                 const SizedBox(height: 30),
                 Padding(
                   padding: const EdgeInsets.all(8.0),
                   child: InkWell(
                     onTap: _handleLoginIn,
                     child: Container(
                       height: 60,
                       width: 350,
                       decoration: BoxDecoration(
                         color: Color (0xFFE991AA),
                         borderRadius: BorderRadius.circular(20),
                       ),
                       child: Center(
                         child: Text("Login",
                             style: TextStyle(
                               color: Colors.white,
                               fontSize: 20,
                               fontWeight: FontWeight.bold,
                             )),
                       ),
                     ),
                   ),
                 ),
                 
          
                 Padding(
                   padding: const EdgeInsets.all(8.0),
                   child: Center(
                     child: Wrap(
                       alignment: WrapAlignment.center,
                       children: [
                         const Text(
                           'Does not have an account yet?🤷‍♀️ ',
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
                               MaterialPageRoute(builder: (context) => const SignUpPage()),
                             );
                           },
                           child: const Text(
                             'Sign Up Here👈',
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
                 ),

                 Align(
                   alignment: Alignment.centerRight,
                   child: Padding(
                     padding: const EdgeInsets.only(right: 16.0),
                     child: TextButton(
                       onPressed: _showForgotPasswordDialog,
                       child: const Text(
                         "Forgot Password?",
                         style: TextStyle(color: Colors.blue),
                       ),
                     ),
                   ),
                 ),

               ],
            ),
          ),
        ),
      ),
    );
  }
}
