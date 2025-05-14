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

    // Define navigation items based on account type
    List<BottomNavigationBarItem> getNavItems() {
      // Base items for all account types
      final List<BottomNavigationBarItem> baseItems = [
        const BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
        const BottomNavigationBarItem(
            icon: Icon(Icons.search), label: 'Search'),
        const BottomNavigationBarItem(
            icon: Icon(Icons.explore), label: 'Explore'),
        const BottomNavigationBarItem(icon: Icon(Icons.shop), label: 'Shop'),
      ];

      // For influencer and organization accounts, add Collaborations before Profile
      if (_currentUserAccountType.toLowerCase() == 'influencer' ||
          _currentUserAccountType.toLowerCase() == 'organization') {
        return [
          ...baseItems,
          const BottomNavigationBarItem(
              icon: Icon(Icons.handshake), label: 'Campaign'),
          const BottomNavigationBarItem(
              icon: Icon(Icons.person), label: 'Profile'),
        ];
      } else {
        // For personal accounts, just add Profile
        return [
          ...baseItems,
          const BottomNavigationBarItem(
              icon: Icon(Icons.person), label: 'Profile'),
        ];
      }
    }

    return BottomNavigationBar(
      type: BottomNavigationBarType.fixed,
      items: getNavItems(),
      onTap: (index) {
        final bool isBusinessAccount =
            _currentUserAccountType.toLowerCase() == 'influencer' ||
                _currentUserAccountType.toLowerCase() == 'organization';

        // For business accounts with 6 items
        if (isBusinessAccount) {
          switch (index) {
            case 0:
              context.go('/home');
              break;
            case 1:
              context.go('/search');
              break;
            case 2:
              context.go('/explore');
              break;
            case 3:
              context.go('/shop');
              break;
            case 4:
              context.go('/collaborations'); // Extra option
              break;
            case 5:
              context.go('/profile');
              break;
          }
        } else {
          // For personal accounts with 5 items
          switch (index) {
            case 0:
              context.go('/home');
              break;
            case 1:
              context.go('/search');
              break;
            case 2:
              context.go('/explore');
              break;
            case 3:
              context.go('/shop');
              break;
            case 4:
              context.go('/profile');
              break;
          }
        }
      },
      currentIndex: _getCurrentIndex(context),
    );
  }

  // Helper method to determine the current index based on the route
  int _getCurrentIndex(BuildContext context) {
    final location = GoRouterState.of(context).uri.toString();
    final bool isBusinessAccount =
        _currentUserAccountType.toLowerCase() == 'influencer' ||
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
