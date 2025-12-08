import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; 
import 'dart:convert';
import 'dart:async'; 

class AiDesignerScreen extends StatefulWidget {
  @override
  _AiDesignerScreenState createState() => _AiDesignerScreenState();
}

class _AiDesignerScreenState extends State<AiDesignerScreen> {
  final TextEditingController _promptController = TextEditingController();
  bool _isGenerating = false;
  String? _generatedImageUrl;

  Future<void> _generateClothes() async {
    if (_promptController.text.isEmpty) return;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Erro !You need to be logged in!")));
      return;
    }

    setState(() {
      _isGenerating = true;
      _generatedImageUrl = null;
    });

    try {
      // 1. LINK NGROK 
      var response = await http.post(
        Uri.parse('https://thievish-deceit-ploy.ngrok-free.dev/create-ai-garment/'),
        body: {
          'user_id': user.uid,
          'description': _promptController.text,
        },
      ).timeout(const Duration(minutes: 5));

      if (response.statusCode == 200) {
        var data = jsonDecode(response.body);
        setState(() {
          _generatedImageUrl = data['image_url']; 
        });
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Design genrated and saved in wardrobe!")));
      } else {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error Server ${response.statusCode}")));
      }
    } on TimeoutException catch (_) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text("Processing may take a minute..."),
        duration: Duration(seconds: 5),
      ));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error connection! Check mobile internet connection!")));
    } finally {
      setState(() => _isGenerating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0D1F),
      appBar: AppBar(
        backgroundColor: Colors.transparent, 
        elevation: 0,
        title: const Text("AI DESIGNER", style: TextStyle(color: Colors.cyanAccent, fontWeight: FontWeight.bold, letterSpacing: 2)),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // --- INPUT TEXT ---
            TextField(
              controller: _promptController,
              style: const TextStyle(color: Colors.white),
              maxLines: 2,
              decoration: InputDecoration(
                hintText: "Ex: A luxury red silk dress, flat lay, high quality...",
                hintStyle: const TextStyle(color: Colors.white30),
                filled: true,
                fillColor: const Color(0xFF1A1A2E),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none),
              ),
            ),
            const SizedBox(height: 20),

            // --- BUTON GENERARE ---
            ElevatedButton(
              onPressed: _isGenerating ? null : _generateClothes,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.cyan, 
                minimumSize: const Size(double.infinity, 55), 
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))
              ),
              child: _isGenerating 
                ? const CircularProgressIndicator(color: Colors.black)
                : const Text("Create a design", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 16)),
            ),
            const SizedBox(height: 40),

            // --- STARE GENERARE ---
            if (_isGenerating)
              const Column(
                children: [
                  CircularProgressIndicator(color: Colors.purpleAccent),
                  SizedBox(height: 20),
                  Text("AI is working...", style: TextStyle(color: Colors.white54)),
                ],
              ),
            
            // --- REZULTAT ---
            if (_generatedImageUrl != null) ...[
              Container(
                height: 350, 
                width: double.infinity,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.cyanAccent, width: 2),
                  image: DecorationImage(image: NetworkImage(_generatedImageUrl!), fit: BoxFit.contain),
                ),
              ),
              const SizedBox(height: 20),
              const Text(" Clothing saved automatically. ", style: TextStyle(color: Colors.white70)),
              const SizedBox(height: 20),
              TextButton.icon(
                onPressed: () => setState(() {
                  _generatedImageUrl = null;
                  _promptController.clear();
                }),
                icon: const Icon(Icons.refresh, color: Colors.cyanAccent),
                label: const Text("New Design", style: TextStyle(color: Colors.cyanAccent)),
              )
            ]
          ],
        ),
      ),
    );
  }
}