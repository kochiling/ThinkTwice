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
  bool _isLoading = false;
  String? _loginError;
  double _loadingProgress = 0.0;

  // Track failed attempts and lockout expiry (in-memory, per session)
  final Map<String, int> _failedAttempts = {};
  final Map<String, DateTime> _lockoutExpiry = {};
  static const int maxAttempts = 5;
  static const Duration lockoutDuration = Duration(minutes: 10);

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
    final email = _email.text.trim();
    // Check lockout
    if (_lockoutExpiry.containsKey(email)) {
      final expiry = _lockoutExpiry[email]!;
      if (DateTime.now().isBefore(expiry)) {
        setState(() {
          _loginError = 'Too many failed attempts. Please try again after \\${expiry.difference(DateTime.now()).inMinutes + 1} minutes.';
        });
        return;
      } else {
        _lockoutExpiry.remove(email);
        _failedAttempts[email] = 0;
      }
    }
    setState(() {
      _isLoading = true;
      _loginError = null;
      _loadingProgress = 0.0;
    });
    void updateProgress(double value) {
      setState(() {
        _loadingProgress = value.clamp(0.0, 1.0);
      });
    }
    try {
      // Simulate loading progress for login
      updateProgress(0.2);
      await Future.delayed(const Duration(milliseconds: 200));
      final user = await _auth.loginUserWithEmailAndPassword(email, _password.text);
      updateProgress(0.7);
      await Future.delayed(const Duration(milliseconds: 200));
      if (user != null) {
        log("User Logged In");
        _failedAttempts[email] = 0;
        updateProgress(1.0);
        await Future.delayed(const Duration(milliseconds: 300));
        goToHome(context);
      } else {
        _failedAttempts[email] = (_failedAttempts[email] ?? 0) + 1;
        if (_failedAttempts[email]! >= maxAttempts) {
          _lockoutExpiry[email] = DateTime.now().add(lockoutDuration);
          setState(() {
            _loginError = 'Too many failed attempts. Please try again after \\${lockoutDuration.inMinutes} minutes.';
          });
        } else {
          setState(() {
            _loginError = 'Invalid email or password.';
          });
        }
      }
    } catch (e) {
      _failedAttempts[email] = (_failedAttempts[email] ?? 0) + 1;
      if (_failedAttempts[email]! >= maxAttempts) {
        _lockoutExpiry[email] = DateTime.now().add(lockoutDuration);
        setState(() {
          _loginError = 'Too many failed attempts. Please try again after \\${lockoutDuration.inMinutes} minutes.';
        });
      } else {
        setState(() {
          _loginError = 'Invalid email or password.';
        });
      }
    } finally {
      setState(() {
        _isLoading = false;
        _loadingProgress = 0.0;
      });
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
        child: Stack(
          children: [
            SingleChildScrollView(
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
                    const SizedBox(height: 10),
                    if (_loginError != null)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8.0),
                        child: Text(
                          _loginError!,
                          style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
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
            if (_isLoading)
              Container(
                color: Colors.black.withOpacity(0.3),
                child: Center(
                  child: SizedBox(
                    width: 300,
                    child: Stack(
                      alignment: Alignment.topLeft,
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(top: 60.0),
                          child: LinearProgressIndicator(
                            value: _loadingProgress,
                            minHeight: 16,
                            backgroundColor: Colors.white,
                            color: Color(0xFFE991AA),
                          ),
                        ),
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
      ),
    );
  }
}
