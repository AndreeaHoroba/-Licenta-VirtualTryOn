import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; 

class CalendarScreen extends StatefulWidget {
  @override
  _CalendarScreenState createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> with WidgetsBindingObserver {
  final String backendUrl = "https://thievish-deceit-ploy.ngrok-free.dev";
  List<dynamic> _weatherForecast = [];
  bool _isLoading = true;
  String _currentCity = "Timisoara";
  final TextEditingController _cityController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadCalendarData();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _loadCalendarData();
    }
  }

  String _getMonthName(String dateString) {
    List<String> months = ['', 'JANUARY', 'FEBRUARY', 'MARCH', 'APRIL', 'MAY', 'JUNE', 'JULY', 'AUGUST', 'SEPTEMBER', 'OCTOBER', 'NOVEMBER', 'DECEMBER'];
    try {
      int month = int.parse(dateString.split('-')[1]);
      return months[month];
    } catch (e) { return ''; }
  }

  // --- NOU: Funcție ajutătoare pentru generarea a 7 zile dummy ---
  void _generateMockDates() {
    _weatherForecast = [];
    DateTime now = DateTime.now();
    for (int i = 0; i < 7; i++) {
      DateTime day = now.add(Duration(days: i));
      String formattedDate = "${day.year}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}";
      _weatherForecast.add({
        'date': formattedDate,
        'max_temp': '--',
        'condition': 'No Data',
        'icon': 'https://cdn.weatherapi.com/weather/64x64/day/113.png' // Iconiță soare implicită
      });
    }
  }

  // luam vremea - REFĂCUT PENTRU SIGURANȚĂ MAXIMĂ
  Future<void> _loadCalendarData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) { 
      if(mounted) setState(() => _isLoading = false); 
      return; 
    }
    
    // Asigură-te că UI-ul arată load
    if(mounted) setState(() => _isLoading = true);
    
    try {
      print("Sending request to: $backendUrl/get-weather/?city=$_currentCity"); // Debug log
      var weatherRes = await http.get(Uri.parse('$backendUrl/get-weather/?city=$_currentCity'));
      
      if (weatherRes.statusCode == 200) {
        var data = jsonDecode(weatherRes.body);
        if(mounted) {
           setState(() {
             _weatherForecast = data['forecast'];
             if (data['city'] != null) _currentCity = data['city'];
           });
        }
      } else {
        print("API Meteo eroare status: ${weatherRes.statusCode}");
        _generateMockDates(); // Salvăm situația dacă serverul răspunde cu eroare (ex: oraș greșit)
        if(mounted) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Could not find weather for $_currentCity. Using standard dates.")));
        }
      }
    } catch (e) { 
      print("Eroare Critică API Meteo: $e"); 
      _generateMockDates(); // Salvăm situația dacă ngrok-ul e picat
      if(mounted) {
         ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Server connection failed. Using standard dates.")));
      }
    } finally { 
      if(mounted) setState(() => _isLoading = false); 
    }
  }

  Future<void> _deleteOutfit(String date) async {
    final user = FirebaseAuth.instance.currentUser;
    try {
      var res = await http.delete(Uri.parse('$backendUrl/delete-planned-outfit/${user!.uid}/$date'));
      if (res.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Outfit deleted from calendar")));
      }
    } catch (e) { print("Error: $e"); }
  }

  void _showCityDialog() {
    _cityController.text = _currentCity;
    showDialog(
      context: context,
      builder: (c) => AlertDialog(
        backgroundColor: Color(0xFF1A1A2E),
        title: Text("Change Location", style: TextStyle(color: Colors.cyanAccent, fontWeight: FontWeight.bold)),
        content: TextField(
          controller: _cityController,
          style: TextStyle(color: Colors.white),
          decoration: InputDecoration(hintText: "e.g., London, Paris...", hintStyle: TextStyle(color: Colors.white38), prefixIcon: Icon(Icons.location_city, color: Colors.cyanAccent)),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c), child: Text("CANCEL", style: TextStyle(color: Colors.white54))),
          TextButton(
            onPressed: () { 
              if (_cityController.text.trim().isNotEmpty) { 
                Navigator.pop(c); 
                setState(() => _currentCity = _cityController.text.trim()); 
                _loadCalendarData(); 
              } 
            }, 
            child: Text("SEARCH", style: TextStyle(color: Colors.cyanAccent, fontWeight: FontWeight.bold))
          ),
        ],
      ),
    );
  }

  void _showFullImage(String url) {
    showDialog(context: context, builder: (c) => Dialog(backgroundColor: Colors.transparent, child: Stack(alignment: Alignment.topRight, children: [InteractiveViewer(child: ClipRRect(borderRadius: BorderRadius.circular(20), child: Image.network(url, fit: BoxFit.contain))), IconButton(icon: Icon(Icons.close, color: Colors.white, size: 35), onPressed: () => Navigator.pop(c))])));
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      backgroundColor: Color(0xFF0D0D1F),
      appBar: AppBar(
        title: Text("MY SCHEDULE", style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 2, color: Colors.cyanAccent)),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        actions: [
          IconButton(icon: Icon(Icons.refresh, color: Colors.cyanAccent), onPressed: _loadCalendarData),
          IconButton(icon: Icon(Icons.edit_location_alt, color: Colors.cyanAccent), onPressed: _showCityDialog),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 10), 
            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.location_on, color: Colors.white54, size: 16), SizedBox(width: 5), Text(_currentCity.toUpperCase(), style: TextStyle(color: Colors.white70, fontSize: 14, letterSpacing: 1.5, fontWeight: FontWeight.w500))])
          ),
          
          Expanded(
            child: _isLoading 
              ? Center(child: CircularProgressIndicator(color: Colors.cyanAccent)) 
              : _weatherForecast.isEmpty 
                  // Acest bloc nu ar trebui să se mai vadă cu noul fallback, dar este util de lăsat pentru siguranță 
                  ? Center(child: Text("No calendar data available.", style: TextStyle(color: Colors.white54))) 
                  : StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('users')
                      .doc(user!.uid)
                      .collection('planned_outfits')
                      .snapshots(), 
                  builder: (context, snapshot) {
                    
                    Map<String, String> liveOutfits = {};
                    if (snapshot.hasData) {
                      for (var doc in snapshot.data!.docs) {
                        var data = doc.data() as Map<String, dynamic>;
                        String? url = data['outfit_url'] ?? data['image_url'];
                        if (url != null) {
                          liveOutfits[doc.id] = url; 
                        }
                      }
                    }

                    return GridView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 15),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2, 
                        crossAxisSpacing: 15, 
                        mainAxisSpacing: 15,
                        childAspectRatio: 0.45,
                      ),
                      itemCount: _weatherForecast.length,
                      itemBuilder: (context, index) {
                        var day = _weatherForecast[index];
                        String? outfitUrl = liveOutfits[day['date']]; 
                        
                        // scurtam numele lunii 
                        String month = _getMonthName(day['date']);
                        String shortMonth = month.length > 3 ? month.substring(0, 3) : month;
                        String dayNumber = day['date'].split('-').last;

                        return Container(
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.03), 
                            borderRadius: BorderRadius.circular(20), 
                            border: Border.all(color: Colors.white10)
                          ),
                          child: Column(
                            children: [
                              // 1. ZONA DE VREME 
                              Padding(
                                padding: const EdgeInsets.all(10.0),
                                child: Column(
                                  children: [
                                    Text("$dayNumber $shortMonth", style: const TextStyle(color: Colors.cyanAccent, fontWeight: FontWeight.bold, fontSize: 16)),
                                    const SizedBox(height: 5),
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Image.network(day['icon'], height: 28),
                                        const SizedBox(width: 8),
                                        Text("${day['max_temp']}°", style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                                      ],
                                    ),
                                    const SizedBox(height: 3),
                                    Text(day['condition'], style: const TextStyle(color: Colors.white38, fontSize: 10), textAlign: TextAlign.center, maxLines: 1, overflow: TextOverflow.ellipsis),
                                  ],
                                ),
                              ),
                              
                              // 2. ZONA DE IMAGINE 
                              Expanded(
                                child: outfitUrl != null 
                                  ? Stack(
                                      fit: StackFit.expand,
                                      children: [
                                        GestureDetector(
                                          onTap: () => _showFullImage(outfitUrl),
                                          child: ClipRRect(
                                            borderRadius: const BorderRadius.only(bottomLeft: Radius.circular(20), bottomRight: Radius.circular(20)),
                                            child: Image.network(
                                              outfitUrl, 
                                              fit: BoxFit.cover, 
                                              alignment: Alignment.topCenter, 
                                            ),
                                          ),
                                        ),
                                        // Butonul de stergere 
                                        Positioned(
                                          top: 8, right: 8, 
                                          child: GestureDetector(
                                            onTap: () => _deleteOutfit(day['date']), 
                                            child: Container(
                                              padding: const EdgeInsets.all(6), 
                                              decoration: BoxDecoration(color: Colors.redAccent.withOpacity(0.9), shape: BoxShape.circle), 
                                              child: const Icon(Icons.delete_sweep, color: Colors.white, size: 18)
                                            )
                                          )
                                        ),
                                        // Iconita de Zoom 
                                        const Positioned(
                                          bottom: 8, left: 8, 
                                          child: Icon(Icons.zoom_in_map, color: Colors.white54, size: 18)
                                        )
                                      ]
                                    )
                                  : const Center(
                                      child: Padding(
                                        padding: EdgeInsets.all(10),
                                        child: Text("No outfit\nplanned.", style: TextStyle(color: Colors.white12, fontSize: 12, fontStyle: FontStyle.italic), textAlign: TextAlign.center),
                                      )
                                    ),
                              ),
                            ],
                          ),
                        );
                      },
                    );
                  }
              ),
          ),
        ],
      ),
    );
  }
}