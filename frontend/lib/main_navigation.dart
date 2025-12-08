import 'package:flutter/material.dart';
import 'home_screen.dart';
import 'wardrobe_screen.dart';
import 'profile_screen.dart';
import 'calendar_screen.dart'; 

class MainNavigation extends StatefulWidget {
  @override
  _MainNavigationState createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation> {
  int _selectedIndex = 0;

  final List<Widget> _pages = [
    HomeScreen(),
    WardrobeScreen(),
    CalendarScreen(),
    ProfileScreen(),
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _selectedIndex,
        children: _pages,
      ),
      bottomNavigationBar: Theme(
        data: Theme.of(context).copyWith(
          canvasColor: Color(0xFF16162D),
        ),
        child: BottomNavigationBar(
          currentIndex: _selectedIndex,
          onTap: _onItemTapped,
          selectedItemColor: Colors.cyanAccent,
          unselectedItemColor: Colors.white24,
          showUnselectedLabels: true,
          type: BottomNavigationBarType.fixed,
          items: const [
            BottomNavigationBarItem(icon: Icon(Icons.home_filled), label: 'Home'),
            BottomNavigationBarItem(icon: Icon(Icons.checkroom), label: 'Wardrobe'),
            BottomNavigationBarItem(icon: Icon(Icons.calendar_month), label: 'Calendar'),
            BottomNavigationBarItem(
              icon: Icon(Icons.person),
              label: 'Profile',
            ),
          ],
        ),
      ),
    );
  }
}