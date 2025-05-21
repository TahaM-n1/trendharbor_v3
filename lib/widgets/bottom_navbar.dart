// lib/widgets/bottom_navbar.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

class BottomNavBar extends StatefulWidget {
  const BottomNavBar({super.key});

  @override
  State<BottomNavBar> createState() => _BottomNavBarState();
}

class _BottomNavBarState extends State<BottomNavBar> {
  String _currentUserAccountType = 'personal'; // Default
  bool _isLoading = true;
  
  @override
  void initState() {
    super.initState();
    _loadCurrentUserAccountType();
  }
  
  Future<void> _loadCurrentUserAccountType() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final accountType = prefs.getString('accountType') ?? 'personal';
      
      if (mounted) {
        setState(() {
          _currentUserAccountType = accountType;
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error loading user account type: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const SizedBox(height: 0); // Return empty widget while loading
    }
    
    final currentIndex = _getCurrentIndex(context);
    final isBusinessAccount = _currentUserAccountType.toLowerCase() == 'influencer' || 
                             _currentUserAccountType.toLowerCase() == 'organization';
                             
    // Define navigation items with their icons, labels and routes
    final List<Map<String, dynamic>> navItems = [
      {'icon': Icons.home_outlined, 'activeIcon': Icons.home, 'label': 'Home', 'route': '/home'},
      {'icon': Icons.search_outlined, 'activeIcon': Icons.search, 'label': 'Search', 'route': '/search'},
      {'icon': Icons.explore_outlined, 'activeIcon': Icons.explore, 'label': 'Explore', 'route': '/explore'},
      {'icon': Icons.shopping_bag_outlined, 'activeIcon': Icons.shopping_bag, 'label': 'Shop', 'route': '/shop'},
    ];
    
    // Add business-specific items
    if (isBusinessAccount) {
      navItems.add({
        'icon': Icons.handshake_outlined, 
        'activeIcon': Icons.handshake, 
        'label': 'Collabs', 
        'route': '/collaborations'
      });
    }
    
    // Add profile for all users
    navItems.add({
      'icon': Icons.person_outline, 
      'activeIcon': Icons.person, 
      'label': 'Profile', 
      'route': '/profile'
    });
    
    // Build the custom floating navbar
    return Container(
      height: 80,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 600), // Limit width on large screens
          child: PhysicalModel(
            color: Colors.transparent,
            elevation: 8,
            borderRadius: BorderRadius.circular(30),
            shadowColor: Colors.black.withOpacity(0.3),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(30),
                boxShadow: [
                  BoxShadow(
                    color: Colors.blue.withOpacity(0.1),
                    blurRadius: 20,
                    offset: const Offset(0, 5),
                    spreadRadius: 1,
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: List.generate(
                  navItems.length,
                  (index) => _buildNavItem(
                    context: context,
                    icon: navItems[index]['icon'],
                    activeIcon: navItems[index]['activeIcon'],
                    label: navItems[index]['label'],
                    route: navItems[index]['route'],
                    isActive: index == currentIndex,
                    onTap: () => context.go(navItems[index]['route']),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
  
  // Helper method to build each nav item
  Widget _buildNavItem({
    required BuildContext context,
    required IconData icon,
    required IconData activeIcon,
    required String label,
    required String route,
    required bool isActive,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      splashColor: Colors.transparent,
      highlightColor: Colors.transparent,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: EdgeInsets.symmetric(
          horizontal: isActive ? 12 : 8,
          vertical: 6,
        ),
        decoration: BoxDecoration(
          color: isActive ? Colors.blue.shade50 : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isActive ? activeIcon : icon,
              size: 22,
              color: isActive ? Colors.blue.shade700 : Colors.grey.shade700,
            ),
            if (isActive) ...[
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  color: Colors.blue.shade700,
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
  
  // Helper method to determine the current index based on the route
  int _getCurrentIndex(BuildContext context) {
    final location = GoRouterState.of(context).uri.toString();
    final bool isBusinessAccount = _currentUserAccountType.toLowerCase() == 'influencer' || 
                                   _currentUserAccountType.toLowerCase() == 'organization';
    
    // Common routes for all user types
    if (location.startsWith('/home')) return 0;
    if (location.startsWith('/search')) return 1;
    if (location.startsWith('/explore')) return 2;
    if (location.startsWith('/shop')) return 3;
    
    // Special routes
    if (isBusinessAccount) {
      if (location.startsWith('/collaborations')) return 4;
      if (location.startsWith('/profile')) return 5;
    } else {
      if (location.startsWith('/profile')) return 4;
    }
    
    return 0; // Default to Home tab
  }
}