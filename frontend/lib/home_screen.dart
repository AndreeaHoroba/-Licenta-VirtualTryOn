import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:typed_data';

class HomeScreen extends StatefulWidget {
  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _isLoading = false;
  Uint8List? _resultImageBytes; 
  Map<String, dynamic> _currentSelectedOutfit = {}; 
  final TextEditingController _chatController = TextEditingController();

  bool _isPerfumeLoading = false;
  final ValueNotifier<List<Map<String, dynamic>>> _chatNotifier = ValueNotifier([
    {'text': "Hi! I can help you choose the perfect outfit based on the weather or event.", 'isUser': false}
  ]);
  int _unreadMessages = 0;
  bool _isChatOpen = false;

  // ngrok url
  final String backendUrl = "https://thievish-deceit-ploy.ngrok-free.dev";

  // GENERARE OUTFIT 
  Future<void> sendToAI() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    setState(() { _isLoading = true; _resultImageBytes = null; });

    try {
      // Luam imaginea omului
      var userDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      String? avatarUrl = userDoc.data()?['image_url'];

      // Luam hainele selectate
      var draftDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).collection('outfit_draft').doc('current').get();
      _currentSelectedOutfit = draftDoc.exists ? draftDoc.data() as Map<String, dynamic> : {};

      if (avatarUrl == null || _currentSelectedOutfit.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Choose an avatar and clothes from the wardrobe!")));
        setState(() => _isLoading = false);
        return;
      }

      var request = http.MultipartRequest('POST', Uri.parse('$backendUrl/try-on-outfit/'));
      var avatarReq = await http.get(Uri.parse(avatarUrl));
      request.files.add(http.MultipartFile.fromBytes('body_image', avatarReq.bodyBytes, filename: 'person.png'));

      if (_currentSelectedOutfit.containsKey('TOP')) {
        var topReq = await http.get(Uri.parse(_currentSelectedOutfit['TOP']));
        request.files.add(http.MultipartFile.fromBytes('top_image', topReq.bodyBytes, filename: 'top.png'));
      }
      if (_currentSelectedOutfit.containsKey('PANTS')) {
        var bottomReq = await http.get(Uri.parse(_currentSelectedOutfit['PANTS']));
        request.files.add(http.MultipartFile.fromBytes('bottom_image', bottomReq.bodyBytes, filename: 'bottom.png'));
      }
      if (_currentSelectedOutfit.containsKey('DRESS')) {
        var dressReq = await http.get(Uri.parse(_currentSelectedOutfit['DRESS']));
        request.files.add(http.MultipartFile.fromBytes('dress_image', dressReq.bodyBytes, filename: 'dress.png'));
      }
      var response = await request.send();
      if (response.statusCode == 200) {
        var bytes = await response.stream.toBytes();
        setState(() { _resultImageBytes = bytes; });
      } else {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Server error: ${response.statusCode}")));
      }
    } catch (e) { 
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Backend connection error!")));
    } finally { 
      setState(() => _isLoading = false); 
    }
  }

  // RECOMANDARE PARFUM 
  Future<void> _recommendPerfume() async {
    if (_resultImageBytes == null || _isPerfumeLoading) return;
    
    setState(() => _isPerfumeLoading = true);
    
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("🔍 Analyzing outfit for perfume..."), duration: Duration(seconds: 2), backgroundColor: Colors.black54)
    );

    try {
      var request = http.MultipartRequest('POST', Uri.parse('$backendUrl/recommend-perfume/'));
      request.files.add(http.MultipartFile.fromBytes('file', _resultImageBytes!, filename: 'outfit.png'));
      
      var response = await request.send();
      var respData = await response.stream.bytesToString();
      var data = jsonDecode(respData);

      setState(() => _isPerfumeLoading = false);

      _showPerfumeResultCard(data['recommendation']['brand'], data['recommendation']['name'], data['recommendation']['reason']);
    } catch (e) { 
      setState(() => _isPerfumeLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Error recommending perfume.")));
    }
  }

  //CHENAR PENTRU PARFUM
  void _showPerfumeResultCard(String brand, String name, String reason) {
    showDialog(
      context: context,
      builder: (c) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: const LinearGradient(colors: [Color(0xFF24243E), Color(0xFF0F0C29)]),
            borderRadius: BorderRadius.circular(25),
            border: Border.all(color: Colors.cyanAccent.withOpacity(0.5)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.water_drop, color: Colors.cyanAccent, size: 50),
              const SizedBox(height: 10),
              Text(brand.toUpperCase(), style: const TextStyle(color: Colors.white54, fontSize: 12, letterSpacing: 2)),
              Text(name, style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
              const Divider(color: Colors.white24, height: 30),
              Text(reason, style: const TextStyle(color: Colors.white70, fontSize: 14, height: 1.5), textAlign: TextAlign.center),
              const SizedBox(height: 20),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.cyanAccent, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))),
                onPressed: () => Navigator.pop(c),
                child: const Text("LOVE IT", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
              )
            ],
          ),
        ),
      )
    );
  }

  // CHATBOT STYLIST
  void _openChatBot() {
    setState(() { _isChatOpen = true; _unreadMessages = 0; }); 

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1A1A2E),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(25))),
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
          child: Container(
            height: 500,
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                Container(width: 50, height: 5, decoration: BoxDecoration(color: Colors.white10, borderRadius: BorderRadius.circular(10))),
                const SizedBox(height: 15),
                const Text("👗 AI STYLIST CHAT", style: TextStyle(color: Colors.cyanAccent, fontWeight: FontWeight.bold, letterSpacing: 1.5)),
                const SizedBox(height: 15),
                
                Expanded(
                  child: ValueListenableBuilder<List<Map<String, dynamic>>>(
                    valueListenable: _chatNotifier,
                    builder: (context, messages, child) {
                      return ListView.builder(
                        itemCount: messages.length,
                        itemBuilder: (context, index) {
                          final msg = messages[index];
                          final isUser = msg['isUser'];
                          return Align(
                            alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
                            child: Container(
                              margin: const EdgeInsets.symmetric(vertical: 6),
                              padding: const EdgeInsets.all(12),
                              constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
                              decoration: BoxDecoration(
                                color: isUser ? Colors.cyan.withOpacity(0.2) : Colors.white.withOpacity(0.1),
                                borderRadius: BorderRadius.only(
                                  topLeft: const Radius.circular(15), topRight: const Radius.circular(15),
                                  bottomLeft: Radius.circular(isUser ? 15 : 0), bottomRight: Radius.circular(isUser ? 0 : 15),
                                ),
                              ),
                              child: Text(msg['text'], style: const TextStyle(color: Colors.white, fontSize: 14)),
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),

                const SizedBox(height: 10),
                TextField(
                  controller: _chatController,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: "What should I wear to college today?",
                    hintStyle: const TextStyle(color: Colors.white24),
                    filled: true, fillColor: Colors.white.withOpacity(0.05),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none),
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.send, color: Colors.cyanAccent),
                      onPressed: () {
                        if (_chatController.text.trim().isEmpty) return;
                        _askStylist(_chatController.text);
                        _chatController.clear(); 
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    ).whenComplete(() {
      setState(() { _isChatOpen = false; }); 
    });
  }

void _askStylist(String question) {
    final user = FirebaseAuth.instance.currentUser;
    
    String currentOutfitContext = "Nothing selected";
    if (_currentSelectedOutfit.isNotEmpty) {
      // Extract the selected categories (e.g., TOP, PANTS)
      currentOutfitContext = "I am currently wearing pieces from these categories: ${_currentSelectedOutfit.keys.join(', ')}";
    }

    // Add the message instantly to the chat list
    final currentList = List<Map<String, dynamic>>.from(_chatNotifier.value);
    currentList.add({'text': question, 'isUser': true});
    _chatNotifier.value = currentList; 

    // Background HTTP request 
    http.post(
      Uri.parse('$backendUrl/chat-stylist/'),
      body: {
        'user_id': user!.uid, 
        'question': question, 
        'city': 'Timisoara',
        'current_outfit': currentOutfitContext
      },
    ).then((response) {
      if (response.statusCode == 200) {
        var data = jsonDecode(response.body);
        
        final newList = List<Map<String, dynamic>>.from(_chatNotifier.value);
        newList.add({'text': data['reply'], 'isUser': false});
        _chatNotifier.value = newList;

        if (!_isChatOpen) {
          setState(() { _unreadMessages++; });
        }
      }
    }).catchError((e) {
      final newList = List<Map<String, dynamic>>.from(_chatNotifier.value);
      newList.add({'text': "Connection error.", 'isUser': false});
      _chatNotifier.value = newList;
    });
  }

  //PLANIFICARE CALENDAR 
  Future<void> _saveToCalendar() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || _resultImageBytes == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Generate an outfit first!")));
      return;
    }

    DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime(2027),
      builder: (context, child) => Theme(data: ThemeData.dark(), child: child!),
    );

    if (picked != null) {
      String dateStr = picked.toIso8601String().split('T')[0];

      showDialog(
        context: context, 
        barrierDismissible: false, 
        builder: (c) => const Center(child: CircularProgressIndicator(color: Colors.cyanAccent))
      );

      try {
        var uploadReq = http.MultipartRequest('POST', Uri.parse('$backendUrl/save-outfit/'));
        uploadReq.fields['user_id'] = user.uid;
        uploadReq.files.add(http.MultipartFile.fromBytes('file', _resultImageBytes!, filename: 'outfit.png'));
        
        var uploadResp = await uploadReq.send();
        var uploadData = jsonDecode(await uploadResp.stream.bytesToString());
        String outfitUrl = uploadData['image_url'];

        var planResp = await http.post(
          Uri.parse('$backendUrl/plan-outfit/'),
          body: {
            'user_id': user.uid,
            'date': dateStr,
            'image_url': outfitUrl,
          },
        );

        Navigator.pop(context);

        if (planResp.statusCode == 200) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Outfit planned successfully!")));
        } else {
          throw Exception("Planning error");
        }
      } catch (e) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
      }
    }
  }

  // UNDRESS 
  void _undress() async {
    final user = FirebaseAuth.instance.currentUser;
    setState(() {
      _resultImageBytes = null;
      _currentSelectedOutfit = {};
    });
    await FirebaseFirestore.instance.collection('users').doc(user!.uid).collection('outfit_draft').doc('current').delete();
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Outfit reset.")));
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      extendBodyBehindAppBar: true,
      
      floatingActionButtonLocation: FloatingActionButtonLocation.startTop, 
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(top: 40.0, left: 10.0), 
        child: FloatingActionButton(
          shape: const CircleBorder(), 
          backgroundColor: Colors.cyanAccent,
          onPressed: _openChatBot,
          child: Badge(
            isLabelVisible: _unreadMessages > 0, 
            label: Text('$_unreadMessages'), 
            backgroundColor: Colors.redAccent,
            child: const Icon(Icons.chat_bubble, color: Colors.black),
          ),
        ),
      ),
      
      body: Container(
        width: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF0F0C29), Color(0xFF302B63), Color(0xFF24243E)],
          ),
        ),
        child: user == null 
            ? const Center(child: Text("Please log in to continue.", style: TextStyle(color: Colors.white)))
            : Column(
                children: [
                  const SizedBox(height: 100),
                  
                  // CHENARUL PRINCIPAL (EXTINS)
                  Expanded(
                    flex: 6,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        Container(
                          margin: const EdgeInsets.symmetric(horizontal: 25), 
                          width: double.infinity,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(30),
                            border: Border.all(color: Colors.cyanAccent.withOpacity(0.3), width: 2),
                            color: Colors.white.withOpacity(0.05),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(30),
                            child: Center(
                              child: _isLoading 
                                ? const Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      CircularProgressIndicator(color: Colors.cyanAccent),
                                      SizedBox(height: 10),
                                      Text("AI is generating...", style: TextStyle(color: Colors.white54, fontSize: 12)),
                                    ],
                                  )
                                : (_resultImageBytes != null 
                                    ? Image.memory(_resultImageBytes!, fit: BoxFit.contain) 
                                    : StreamBuilder<DocumentSnapshot>(
                                        stream: FirebaseFirestore.instance.collection('users').doc(user.uid).snapshots(),
                                        builder: (context, snapshot) {
                                          String? url = (snapshot.hasData && snapshot.data!.exists) 
                                              ? (snapshot.data!.data() as Map<String, dynamic>)['image_url'] : null;
                                          return url != null 
                                              ? Image.network(url, fit: BoxFit.contain) 
                                              : const Icon(Icons.person, size: 100, color: Colors.white10);
                                        },
                                      )),
                            ),
                          ),
                        ),
                        // Geanta pusa in colt
                        if (_currentSelectedOutfit.containsKey('BAG') && _resultImageBytes != null)
                          Positioned(
                            bottom: 20,
                            right: 40,
                            child: Container(
                              height: 90, width: 90,
                              decoration: BoxDecoration(
                                image: DecorationImage(image: NetworkImage(_currentSelectedOutfit['BAG']), fit: BoxFit.contain),
                              ),
                            ),
                          ),

                        // BARA LATERALA DREAPTA CU BUTOANE
                        if (_resultImageBytes != null && !_isLoading)
                          Positioned(
                            right: 15,
                            top: 40, 
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 8),
                              decoration: BoxDecoration(
                                color: Colors.black.withOpacity(0.6),
                                borderRadius: BorderRadius.circular(30),
                                border: Border.all(color: Colors.white10)
                              ),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  _isPerfumeLoading 
                                      ? const Padding(
                                          padding: EdgeInsets.only(bottom: 25),
                                          child: SizedBox(width: 22, height: 22, child: CircularProgressIndicator(color: Colors.cyanAccent, strokeWidth: 2)),
                                        )
                                      : _actionIcon(Icons.opacity, "Scent", _recommendPerfume),
                                  
                                  const SizedBox(height: 25),
                                  _actionIcon(Icons.calendar_month, "Plan", _saveToCalendar),
                                  
                                  const SizedBox(height: 25),
                                  _actionIcon(Icons.layers_clear, "Reset", _undress),
                                ],
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),

                  // CARUSEL HAINE SELECTATE
                  const Padding(
                    padding: EdgeInsets.only(top: 20, bottom: 5),
                    child: Text("SELECTED ITEMS", style: TextStyle(color: Colors.white38, fontSize: 10, letterSpacing: 2, fontWeight: FontWeight.bold)),
                  ),
                  
                  Container(
                    height: 90, 
                    child: StreamBuilder<DocumentSnapshot>(
                      stream: FirebaseFirestore.instance.collection('users').doc(user.uid).collection('outfit_draft').doc('current').snapshots(),
                      builder: (context, snapshot) {
                        if (!snapshot.hasData || !snapshot.data!.exists) {
                          return const Center(child: Text("No items selected", style: TextStyle(color: Colors.white12, fontSize: 12)));
                        }
                        var outfit = snapshot.data!.data() as Map<String, dynamic>;
                        _currentSelectedOutfit = outfit; 
                        
                        return ListView.builder(
                          scrollDirection: Axis.horizontal,
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          itemCount: outfit.length,
                          itemBuilder: (context, index) {
                            String category = outfit.keys.elementAt(index);
                            String img = outfit.values.elementAt(index);
                            return Container(
                              margin: const EdgeInsets.only(right: 12),
                              width: 75,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(15),
                                border: Border.all(color: Colors.greenAccent.withOpacity(0.5), width: 2),
                                image: DecorationImage(image: NetworkImage(img), fit: BoxFit.cover),
                              ),
                              child: Align(
                                alignment: Alignment.bottomCenter,
                                child: Container(
                                  width: double.infinity, color: Colors.black54,
                                  child: Text(category, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold)),
                                ),
                              ),
                            );
                          },
                        );
                      },
                    ),
                  ),

                  // BUTON GENERARE (Elegant si compact)
                  Padding(
                    padding: const EdgeInsets.only(top: 15, bottom: 25),
                    child: GestureDetector(
                      onTap: _isLoading ? null : sendToAI,
                      child: Container(
                        height: 50, 
                        width: 250, 
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(25),
                          boxShadow: [BoxShadow(color: Colors.cyanAccent.withOpacity(0.2), blurRadius: 10, spreadRadius: 1)],
                          gradient: _isLoading 
                            ? const LinearGradient(colors: [Colors.grey, Colors.black26])
                            : const LinearGradient(colors: [Colors.cyanAccent, Colors.blueAccent]),
                        ),
                        child: Center(
                          child: Text(
                            _isLoading ? "PROCESSING..." : "GENERATE OUTFIT", 
                            style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 14, letterSpacing: 1.2)
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  // Buton minimalist pentru bara laterala
  Widget _actionIcon(IconData icon, String label, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Column(
        children: [
          Icon(icon, color: Colors.cyanAccent, size: 24),
          const SizedBox(height: 3),
          Text(label, style: const TextStyle(color: Colors.white70, fontSize: 9, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}