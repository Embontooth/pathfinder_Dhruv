import 'package:flutter/material.dart';

class BottomNavbar extends StatelessWidget {
  int currentIndex;
  // final Function(int) onTap;

  BottomNavbar({super.key, this.currentIndex = 0});

  @override
  Widget build(BuildContext context) {
    return BottomNavigationBar(
      currentIndex: currentIndex,
      onTap: (index) {
        currentIndex = index;
      },
      type: BottomNavigationBarType.fixed,
      selectedItemColor: Theme.of(context).primaryColor,
      unselectedItemColor: Colors.blue,
      items: const [
        BottomNavigationBarItem(
          icon: Icon(Icons.home),
          label: 'Home',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.map_outlined),
          label: 'Explore',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.event),
          label: 'Events',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.edit),
          label: 'Create Event',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.person_3),
          label: 'Profile',
        ),
      ],
    );
  }
}
