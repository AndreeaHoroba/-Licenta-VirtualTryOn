import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; 
import 'main_navigation.dart';

class LoginScreen extends StatefulWidget {
  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _aliasController = TextEditingController(); 
  
  bool _isLoading = false;
  bool _isLoginMode = true; 

  Future<void> _submitAuthForm() async {
    if (_emailController.text.trim().isEmpty || _passwordController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Please complete all the requirements!")));
      return;
    }

    if (!_isLoginMode && _aliasController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Please choose an Alias for your account!")));
      return;
    }

    setState(() => _isLoading = true);

    try {
      if (_isLoginMode) {
        await FirebaseAuth.instance.signInWithEmailAndPassword(
          email: _emailController.text.trim(),
          password: _passwordController.text.trim(),
        );
      } else {
      
        UserCredential userCredential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
          email: _emailController.text.trim(),
          password: _passwordController.text.trim(),
        );

        await FirebaseFirestore.instance
            .collection('users')
            .doc(userCredential.user!.uid)
            .set({
          'alias': _aliasController.text.trim(),
          'email': _emailController.text.trim(),
          'createdAt': FieldValue.serverTimestamp(),
        });
      }

      Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => MainNavigation()));
      
    } on FirebaseAuthException catch (e) {
      String message = "Error.";
      if (e.code == 'user-not-found') message = "No existing account with this username";
      else if (e.code == 'wrong-password') message = "Incorrect password";
      else if (e.code == 'email-already-in-use') message = "Already in-use email";
      
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: ${e.toString()}")));
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  // resetare parola
  Future<void> _resetPassword() async {
    if (_emailController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Enter your email address in the box above to reset!")),
      );
      return;
    }
    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: _emailController.text.trim());
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("The reset link has been sent to your email!")),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Reset error: ${e.toString()}")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        padding: EdgeInsets.all(30),
        width: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF0F0C29), Color(0xFF302B63)],
            begin: Alignment.topCenter,
          ),
        ),
        child: Center(
          child: SingleChildScrollView(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.lock_outline, size: 80, color: Colors.cyanAccent),
                SizedBox(height: 20),
                Text(
                  _isLoginMode ? "WELCOME" : "CREATE ACCOUNT", 
                  style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, letterSpacing: 5, color: Colors.white)
                ),
                SizedBox(height: 40),
                
                // Campul de Alias 
                if (!_isLoginMode) ...[
                  TextField(
                    controller: _aliasController,
                    style: TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: "Alias (e.g., FashionGuru)",
                      hintStyle: TextStyle(color: Colors.white54),
                      filled: true,
                      fillColor: Colors.white10,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none),
                      prefixIcon: Icon(Icons.person, color: Colors.cyanAccent),
                    ),
                  ),
                  SizedBox(height: 15),
                ],

                // Camp Email
                TextField(
                  controller: _emailController,
                  style: TextStyle(color: Colors.white),
                  keyboardType: TextInputType.emailAddress,
                  decoration: InputDecoration(
                    hintText: "Email",
                    hintStyle: TextStyle(color: Colors.white54),
                    filled: true,
                    fillColor: Colors.white10,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none),
                    prefixIcon: Icon(Icons.email, color: Colors.cyanAccent),
                  ),
                ),
                SizedBox(height: 15),

                // Camp Parola
                TextField(
                  controller: _passwordController,
                  obscureText: true,
                  style: TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: "Password",
                    hintStyle: TextStyle(color: Colors.white54),
                    filled: true,
                    fillColor: Colors.white10,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none),
                    prefixIcon: Icon(Icons.vpn_key, color: Colors.cyanAccent),
                  ),
                ),
                SizedBox(height: 30),

                // Buton Principal + Loading Indicator
                _isLoading 
                  ? CircularProgressIndicator(color: Colors.cyanAccent)
                  : Column(
                      children: [
                        ElevatedButton(
                          onPressed: _submitAuthForm,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.cyanAccent,
                            minimumSize: Size(double.infinity, 55),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                          ),
                          child: Text(
                            _isLoginMode ? "LOGIN" : "REGISTER", 
                            style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 16, letterSpacing: 1.5)
                          ),
                        ),
                        
                        // Buton de forgot passw
                        if (_isLoginMode)
                          TextButton(
                            onPressed: _resetPassword,
                            child: Text("Forgot password?", style: TextStyle(color: Colors.cyanAccent.withOpacity(0.7))),
                          ),
                          
                        SizedBox(height: 20),
                        
                        // Butonul schimbare login-register
                        TextButton(
                          onPressed: () {
                            setState(() {
                              _isLoginMode = !_isLoginMode;
                            });
                          },
                          child: Text(
                            _isLoginMode 
                              ? "Don't have an account? Create one here." 
                              : "Already have an account? Login.", 
                            style: TextStyle(color: Colors.white, decoration: TextDecoration.underline),
                          ),
                        ),
                      ],
                    ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}