import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'dart:io';
import 'dart:convert'; 

class WardrobeScreen extends StatefulWidget {
  @override
  _WardrobeScreenState createState() => _WardrobeScreenState();
}

class _WardrobeScreenState extends State<WardrobeScreen> {
  String selectedCategory = 'TOPS';
  final List<String> categories = ['TOPS', 'BOTTOMS', 'DRESSES', 'BAGS']; 
  
  final Map<String, String> dbTranslator = {
    'TOPS': 'TOP',
    'BOTTOMS': 'PANTS',
    'DRESSES': 'DRESS',
    'BAGS': 'BAG'
  };

  bool _isUploading = false;
  bool _isAiDesignerExpanded = false;
  final TextEditingController _promptController = TextEditingController();

  // url ngrok
  final String backendUrl = "https://thievish-deceit-ploy.ngrok-free.dev";

  @override
  void dispose() {
    _promptController.dispose();
    super.dispose();
  }

  Future<void> _generateWithAIDesigner(String prompt) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || prompt.isEmpty) return;

    FocusScope.of(context).unfocus(); 
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: Color(0xFF1A1A2E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: Colors.cyanAccent),
            SizedBox(height: 20),
            Text("AI Designer is creating your garment...", 
                 style: TextStyle(color: Colors.white70, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
            SizedBox(height: 10),
            Text("This process takes about 30-60 seconds", 
                 style: TextStyle(color: Colors.white38, fontSize: 11)),
          ],
        ),
      ),
    );

    try {
      var response = await http.post(
        Uri.parse('$backendUrl/create-ai-garment/'),
        body: {
          'user_id': user.uid,
          'description': prompt,
        },
      ).timeout(const Duration(seconds: 120));

      Navigator.pop(context); 
      if (response.statusCode == 200) {
        setState(() {
          _promptController.clear();
          _isAiDesignerExpanded = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Success! Garment added to your wardrobe ✨"), backgroundColor: Colors.green)
        );
      } else {
        throw Exception("Server Error");
      }
    } catch (e) {
      if (Navigator.canPop(context)) {
        Navigator.pop(context);
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: Ensure the GPU server is active! ($e)"), backgroundColor: Colors.red)
      );
    }
  }

  Widget _buildAIDesignerCard() {
    return GestureDetector(
      onTap: () {
        setState(() {
          _isAiDesignerExpanded = !_isAiDesignerExpanded;
        });
      },
      child: AnimatedContainer(
        duration: Duration(milliseconds: 300),
        curve: Curves.easeInOut,
        margin: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        padding: EdgeInsets.all(_isAiDesignerExpanded ? 20 : 15),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.purple.withOpacity(0.2), Colors.blue.withOpacity(0.2)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.cyanAccent.withOpacity(0.3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(Icons.auto_awesome, color: Colors.cyanAccent, size: 20),
                    SizedBox(width: 10),
                    Text("AI DESIGNER", 
                         style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, letterSpacing: 2, fontSize: 14)),
                  ],
                ),
                Icon(
                  _isAiDesignerExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                  color: Colors.cyanAccent,
                )
              ],
            ),
            if (_isAiDesignerExpanded) ...[
              SizedBox(height: 15),
              TextField(
                controller: _promptController,
                style: TextStyle(color: Colors.white, fontSize: 13),
                decoration: InputDecoration(
                  hintText: "Describe your dream item (e.g., Red silk dress)",
                  hintStyle: TextStyle(color: Colors.white24),
                  filled: true,
                  fillColor: Colors.black26,
                  contentPadding: EdgeInsets.symmetric(horizontal: 15, vertical: 12),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none),
                ),
              ),
              SizedBox(height: 12),
              ElevatedButton(
                onPressed: () => _generateWithAIDesigner(_promptController.text),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.cyanAccent,
                  minimumSize: Size(double.infinity, 45),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                  elevation: 5,
                ),
                child: Text("GENERATE & ADD", 
                           style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 12)),
              ),
            ]
          ],
        ),
      ),
    );
  }

  // --- EXISTING LOGIC ---
  Future<void> _toggleSelection(String category, String imageUrl) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    
    var docRef = FirebaseFirestore.instance.collection('users').doc(user.uid).collection('outfit_draft').doc('current');
    var snapshot = await docRef.get();
    
    Map<String, dynamic> data = snapshot.exists ? snapshot.data() as Map<String, dynamic> : {};
    
    if (data[category] == imageUrl) {
      data.remove(category);
    } else {
      data[category] = imageUrl;
      if (category == 'DRESS') {
        data.remove('TOP');
        data.remove('PANTS');
      } else if (category == 'TOP' || category == 'PANTS') {
        data.remove('DRESS');
      }
    }
    await docRef.set(data);
  }

  Future<void> _pickAndProcessImage(ImageSource source) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: source);

    if (pickedFile != null) {
      setState(() => _isUploading = true);
      File file = File(pickedFile.path);

      try {
        var request = http.MultipartRequest('POST', Uri.parse('$backendUrl/segment-clothing/'));
        request.fields['user_id'] = user.uid;
        request.files.add(await http.MultipartFile.fromPath('file', file.path));

        var response = await request.send();
        if (response.statusCode == 200) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Garment successfully processed & saved!"), backgroundColor: Colors.green));
        } else {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Failed to process garment."), backgroundColor: Colors.red));
        }
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Connection error"), backgroundColor: Colors.red));
      } finally {
        setState(() => _isUploading = false);
      }
    }
  }

  void _showAddGarmentModal() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Color(0xFF1A1A2E),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 30),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              // OPTIUNEA CAMERA
              GestureDetector(
                onTap: () {
                  Navigator.pop(context); 
                  _pickAndProcessImage(ImageSource.camera); 
                },
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircleAvatar(radius: 35, backgroundColor: Colors.purpleAccent.withOpacity(0.8), child: Icon(Icons.camera_alt, color: Colors.white, size: 30)),
                    SizedBox(height: 10),
                    Text("Take Photo", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
              // OPTIUNEA GALERIE
              GestureDetector(
                onTap: () {
                  Navigator.pop(context); 
                  _pickAndProcessImage(ImageSource.gallery); 
                },
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircleAvatar(radius: 35, backgroundColor: Colors.cyan.withOpacity(0.8), child: Icon(Icons.photo_library, color: Colors.white, size: 30)),
                    SizedBox(height: 10),
                    Text("Gallery", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _deleteClothing(String docId) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      await FirebaseFirestore.instance.collection('users').doc(user.uid).collection('wardrobe').doc(docId).delete();
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      backgroundColor: Color(0xFF0D0D1F),
      body: Column(
        children: [
          SizedBox(height: 50), 
          Text("MY CLOSET", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, letterSpacing: 3, color: Colors.white30)),
          
          _buildAIDesignerCard(),

          // Category Selector
          Wrap(
            spacing: 10, runSpacing: 10, alignment: WrapAlignment.center,
            children: categories.map((cat) {
              bool isSelected = selectedCategory == cat;
              return GestureDetector(
                onTap: () => setState(() => selectedCategory = cat),
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 15, vertical: 8),
                  decoration: BoxDecoration(
                    color: isSelected ? Colors.cyan.withOpacity(0.1) : Colors.transparent,
                    border: Border.all(color: isSelected ? Colors.cyanAccent : Colors.white10, width: 2),
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: Text(cat, style: TextStyle(color: isSelected ? Colors.cyanAccent : Colors.white24, fontWeight: FontWeight.bold, fontSize: 12)),
                ),
              );
            }).toList(),
          ),
          SizedBox(height: 10),

          // Clothes Grid
          Expanded(
            child: user == null 
              ? Center(child: Text("You must be logged in.", style: TextStyle(color: Colors.white24)))
              : StreamBuilder<DocumentSnapshot>(
                  stream: FirebaseFirestore.instance.collection('users').doc(user.uid).collection('outfit_draft').doc('current').snapshots(),
                  builder: (context, draftSnapshot) {
                    Map<String, dynamic> selectedOutfit = {};
                    if (draftSnapshot.hasData && draftSnapshot.data!.exists) {
                      selectedOutfit = draftSnapshot.data!.data() as Map<String, dynamic>;
                    }

                    return StreamBuilder<QuerySnapshot>(
                      stream: FirebaseFirestore.instance.collection('users').doc(user.uid).collection('wardrobe')
                          .where('category', isEqualTo: dbTranslator[selectedCategory]).snapshots(),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState == ConnectionState.waiting) return Center(child: CircularProgressIndicator());
                        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) 
                          return Center(child: Text("No items saved in this category.", style: TextStyle(color: Colors.white12)));

                        return GridView.builder(
                          padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, crossAxisSpacing: 15, mainAxisSpacing: 15, childAspectRatio: 0.75),
                          itemCount: snapshot.data!.docs.length,
                          itemBuilder: (context, index) {
                            var doc = snapshot.data!.docs[index];
                            var data = doc.data() as Map<String, dynamic>;
                            String imageUrl = data.containsKey('image_url') ? data['image_url'] : '';
                            
                            String dbCat = dbTranslator[selectedCategory]!;
                            bool isSelected = selectedOutfit[dbCat] == imageUrl;

                            return GestureDetector(
                              onTap: () => _toggleSelection(dbCat, imageUrl),
                              child: Stack(
                                children: [
                                  Container(
                                    decoration: BoxDecoration(
                                      color: Color(0xFF1A1A2E), 
                                      borderRadius: BorderRadius.circular(20), 
                                      border: Border.all(color: isSelected ? Colors.greenAccent : Colors.white10, width: isSelected ? 4 : 1),
                                      image: imageUrl.isNotEmpty ? DecorationImage(image: NetworkImage(imageUrl), fit: BoxFit.cover) : null,
                                    ),
                                  ),
                                  Positioned(
                                    top: 5, right: 5,
                                    child: GestureDetector(
                                      onTap: () => _deleteClothing(doc.id),
                                      child: Container(
                                        padding: EdgeInsets.all(5),
                                        decoration: BoxDecoration(color: Colors.redAccent.withOpacity(0.8), shape: BoxShape.circle),
                                        child: Icon(Icons.delete, color: Colors.white, size: 18),
                                      ),
                                    ),
                                  ),
                                  if (isSelected) 
                                    Positioned(
                                      bottom: 10, right: 10,
                                      child: Container(
                                        padding: EdgeInsets.all(5),
                                        decoration: BoxDecoration(color: Colors.greenAccent, shape: BoxShape.circle),
                                        child: Icon(Icons.check, color: Colors.black, size: 18),
                                      ),
                                    )
                                ],
                              ),
                            );
                          },
                        );
                      },
                    );
                  }
                ),
          ),

         Padding(
            padding: EdgeInsets.only(bottom: 25, top: 10),
            child: _isUploading 
              ? CircularProgressIndicator(color: Colors.purpleAccent) 
              : SizedBox(
                  width: 160, // Lățime fixă și mult mai compactă
                  height: 45, // Înălțime redusă
                  child: ElevatedButton.icon(
                    onPressed: _showAddGarmentModal,
                    icon: Icon(Icons.add_circle_outline, color: Colors.white, size: 20), // Iconiță ajustată
                    label: Text("ADD ITEM", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)), // Font puțin mai mic
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.purpleAccent.withOpacity(0.8),
                      padding: EdgeInsets.zero, // Eliminăm padding-ul ca să respecte dimensiunea SizedBox-ului
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
                      elevation: 5,
                    ),
                  ),
                ),
          ),
        ],
      ),
    );
  }
}