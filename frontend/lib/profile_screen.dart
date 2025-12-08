import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'dart:io';
import 'dart:convert';
import 'login_screen.dart'; 

class ProfileScreen extends StatefulWidget {
  @override
  _ProfileScreenState createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final user = FirebaseAuth.instance.currentUser;
  final ImagePicker _picker = ImagePicker();
  bool _isLoading = false;

  final String backendUrl = "https://thievish-deceit-ploy.ngrok-free.dev";

  // Functia de DELOGARE
  Future<void> _logout() async {
    await FirebaseAuth.instance.signOut();
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (context) => LoginScreen()), 
      (Route<dynamic> route) => false
    );
  }

  //Functia stergere avatar
  Future<void> _deleteAvatar(String docId) async {
    if (user == null) return;
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user!.uid)
          .collection('avatars')
          .doc(docId)
          .delete();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Avatar deleted!"), backgroundColor: Colors.redAccent)
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Delete error: $e"), backgroundColor: Colors.red)
      );
    }
  }

  //Functia trimite poza la filtrele de py
  Future<void> _pickAndProcessImage(ImageSource source) async {
    if (user == null) return;
    
    final pickedFile = await _picker.pickImage(source: source);
    if (pickedFile == null) return;

    setState(() => _isLoading = true);
    File file = File(pickedFile.path);

    try {
      var request = http.MultipartRequest('POST', Uri.parse('$backendUrl/process-body/'));
      request.fields['user_id'] = user!.uid;
      request.files.add(await http.MultipartFile.fromPath('file', file.path));

      var streamedResponse = await request.send();
      var response = await http.Response.fromStream(streamedResponse);
      
      var jsonResponse = jsonDecode(response.body);

      if (response.statusCode == 200) {
        String newAvatarUrl = jsonResponse['image_url'];
        
        await FirebaseFirestore.instance.collection('users').doc(user!.uid).collection('avatars').add({
          'url': newAvatarUrl,
          'createdAt': FieldValue.serverTimestamp(),
        });

        await _setMainAvatar(newAvatarUrl);

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Avatar processed and saved successfully!"), backgroundColor: Colors.green)
        );
      } 
      else if (response.statusCode == 400) {
        String serverErrorMessage = jsonResponse['message'] ?? "Invalid image.";
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(serverErrorMessage), 
            backgroundColor: Colors.orange, 
            duration: Duration(seconds: 6),
          )
        );
      } 
      else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Server error (${response.statusCode}): ${jsonResponse['message']}"), backgroundColor: Colors.red)
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("AI server connection error: $e"), backgroundColor: Colors.red)
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // Functia- seteaza avatar ca prinicpal
  Future<void> _setMainAvatar(String imageUrl) async {
    if (user != null) {
      await FirebaseFirestore.instance.collection('users').doc(user!.uid).set(
        {'image_url': imageUrl}, 
        SetOptions(merge: true) 
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (user == null) return Center(child: Text("Not logged in", style: TextStyle(color: Colors.white)));

    return Scaffold(
      backgroundColor: Color(0xFF0D0D1F),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text("MY PROFILE", style: TextStyle(color: Colors.cyanAccent, fontWeight: FontWeight.bold, letterSpacing: 2, fontSize: 16)),
        centerTitle: true,
        actions: [
          IconButton(
            icon: Icon(Icons.logout, color: Colors.redAccent),
            onPressed: _logout,
            tooltip: 'Logout',
          )
        ],
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance.collection('users').doc(user!.uid).snapshots(),
        builder: (context, userSnapshot) {
          String? currentAvatarUrl;
          
          if (userSnapshot.hasData && userSnapshot.data!.data() != null) {
            var userData = userSnapshot.data!.data() as Map<String, dynamic>;
            currentAvatarUrl = userData['image_url'];
          }

          return Stack(
            children: [
              // 1. STRATUL DE BAZĂ (Profilul principal)
              Align(
                alignment: Alignment.topCenter,
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      SizedBox(height: 20),
                      // --- AVATARUL CURENT
                      Container(
                        width: 170, height: 230,
                        decoration: BoxDecoration(
                          color: Color(0xFF1A1A2E),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: Colors.cyanAccent, width: 2),
                          image: (currentAvatarUrl != null && currentAvatarUrl.isNotEmpty)
                              ? DecorationImage(
                                  image: NetworkImage(currentAvatarUrl), 
                                  fit: BoxFit.contain 
                                )
                              : null,
                        ),
                        child: (currentAvatarUrl == null || currentAvatarUrl.isEmpty) 
                            ? Icon(Icons.person_add_alt_1, size: 60, color: Colors.white24)
                            : null,
                      ),
                      SizedBox(height: 15),
                      Text(user!.email ?? "No email", style: TextStyle(color: Colors.white54, fontSize: 16)),
                      SizedBox(height: 30),

                      // --- BUTOANE DE ÎNCARCARE ---
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          _buildActionButton(Icons.camera_alt, "CAMERA", () => _pickAndProcessImage(ImageSource.camera)),
                          _buildActionButton(Icons.photo_library, "GALLERY", () => _pickAndProcessImage(ImageSource.gallery)),
                        ],
                      ),
                      SizedBox(height: 100), 
                    ],
                  ),
                ),
              ),

              // 2. STRATUL GLISANT (Avatar History)
              DraggableScrollableSheet(
                initialChildSize: 0.15, 
                minChildSize: 0.15,     
                maxChildSize: 0.75,     
                builder: (BuildContext context, ScrollController scrollController) {
                  return Container(
                    decoration: BoxDecoration(
                      color: Color(0xFF16162C),
                      borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
                      boxShadow: [
                        BoxShadow(color: Colors.black54, blurRadius: 10, spreadRadius: 2)
                      ],
                    ),
                    child: Column(
                      children: [
                        SizedBox(height: 12),
                        // Indicatorul vizual de tragere
                        Container(
                          width: 50,
                          height: 5,
                          decoration: BoxDecoration(
                            color: Colors.white24,
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        SizedBox(height: 15),
                        Text("AVATAR HISTORY", style: TextStyle(color: Colors.white30, fontWeight: FontWeight.bold, letterSpacing: 2)),
                        SizedBox(height: 10),
                        
                        // Lista 
                        Expanded(
                          child: StreamBuilder<QuerySnapshot>(
                            stream: FirebaseFirestore.instance.collection('users').doc(user!.uid).collection('avatars').orderBy('createdAt', descending: true).snapshots(),
                            builder: (context, snapshot) {
                              if (!snapshot.hasData) return Center(child: CircularProgressIndicator());
                              
                              var docs = snapshot.data!.docs;
                              if (docs.isEmpty) return Center(child: Text("No avatars saved yet.", style: TextStyle(color: Colors.white54)));

                              return GridView.builder(
                                controller: scrollController, 
                                padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: 3, 
                                  crossAxisSpacing: 10, 
                                  mainAxisSpacing: 10,
                                  childAspectRatio: 0.75, 
                                ),
                                itemCount: docs.length,
                                itemBuilder: (context, index) {
                                  var doc = docs[index];
                                  var avatarUrl = doc['url'];
                                  var docId = doc.id; 
                                  
                                  bool isSelected = (avatarUrl == currentAvatarUrl);

                                  return Stack(
                                    children: [
                                      GestureDetector(
                                        onTap: () => _setMainAvatar(avatarUrl), 
                                        child: Container(
                                          decoration: BoxDecoration(
                                            color: Color(0xFF1A1A2E),
                                            borderRadius: BorderRadius.circular(10),
                                            border: Border.all(
                                              color: isSelected ? Colors.greenAccent : Colors.transparent, 
                                              width: 3
                                            ),
                                            image: DecorationImage(
                                              image: NetworkImage(avatarUrl), 
                                              fit: BoxFit.contain 
                                            ),
                                          ),
                                        ),
                                      ),
                                      Positioned(
                                        top: -5,
                                        right: -5,
                                        child: IconButton(
                                          icon: Icon(Icons.cancel, color: Colors.redAccent, size: 22),
                                          onPressed: () {
                                            _deleteAvatar(docId);
                                            if (isSelected) {
                                              _setMainAvatar(""); 
                                            }
                                          },
                                        ),
                                      ),
                                    ],
                                  );
                                },
                              );
                            }
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ],
          );
        }
      ),
    );
  }

  Widget _buildActionButton(IconData icon, String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: _isLoading ? null : onTap,
      child: Container(
        width: 140, padding: EdgeInsets.symmetric(vertical: 15),
        decoration: BoxDecoration(
          color: Color(0xFF1A1A2E), 
          borderRadius: BorderRadius.circular(15), 
          border: Border.all(color: Colors.white10),
        ),
        child: Column(
          children: [
            _isLoading 
              ? SizedBox(height: 28, width: 28, child: CircularProgressIndicator(color: Colors.cyanAccent)) 
              : Icon(icon, color: Colors.cyanAccent, size: 28),
            SizedBox(height: 8),
            Text(label, style: TextStyle(color: Colors.white70, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }
}