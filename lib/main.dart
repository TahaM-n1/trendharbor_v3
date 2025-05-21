import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:trendharbor_v2/screens/campaign_screen.dart';
import 'screens/create_post_screen.dart';
import 'screens/forget_password_screen.dart';
import 'screens/login_screen.dart';
import 'screens/post_detail_screen.dart';
import 'screens/signup_screen.dart';
import 'screens/home_screen.dart';
import 'screens/explore_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/profile_settings_screen.dart';
import 'screens/search_screen.dart';
import 'screens/shop_screen.dart';
import 'screens/direct_messages_screen.dart';
import 'screens/chat_screen.dart';
import 'services/user_service.dart';
import 'services/chat_service.dart';
import 'screens/collaborations_screen.dart';
import 'screens/change_password_screen.dart';
import 'screens/product_detail_screen.dart';
import 'screens/cart_screen.dart';
import 'screens/add_product_screen.dart';

import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => UserService()),
        ChangeNotifierProvider(create: (_) => ChatService()),
        // Your other providers
      ],
      child: MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  MyApp({super.key});

  final GoRouter router = GoRouter(
    routes: [
      GoRoute(path: '/', builder: (context, state) => const LoginScreen()),
      GoRoute(
          path: '/signup', builder: (context, state) => const RegisterScreen()),
      GoRoute(
          path: '/forget-password',
          builder: (context, state) => const ForgetPasswordScreen()),
      GoRoute(path: '/home', builder: (context, state) => const HomeScreen()),
      GoRoute(
          path: '/explore', builder: (context, state) => const ExploreScreen()),
      GoRoute(
          path: '/profile', builder: (context, state) => const ProfileScreen()),
      // Add route to view other users' profiles
      GoRoute(
        path: '/profile/:userId',
        builder: (context, state) {
          final userId = state.pathParameters['userId']!;
          return ProfileScreen(userId: userId);
        },
      ),
      GoRoute(
          path: '/profile-settings',
          builder: (context, state) => const ProfileSettingsScreen()),
      GoRoute(
          path: '/change-password',
          builder: (context, state) => const ChangePasswordScreen()),
      GoRoute(
          path: '/search', builder: (context, state) => const SearchScreen()),
      GoRoute(path: '/shop', builder: (context, state) => const ShopScreen()),
      GoRoute(
          path: '/direct-messages',
          builder: (context, state) => const DirectMessagesScreen()),
      GoRoute(
        path: '/chat/:chatId',
        builder: (context, state) {
          final chatId = state.pathParameters['chatId']!;
          return ChatScreen(chatId: chatId);
        },
      ),

      GoRoute(
        path: '/collaborations',
        builder: (context, state) => const CampaignsScreen(),
      ),

      GoRoute(
        path: '/create-post',
        builder: (context, state) => const CreatePostScreen(),
      ),

      GoRoute(
        path: '/post/:postId',
        builder: (context, state) => PostDetailScreen(
          postId: state.pathParameters['postId']!,
        ),
      ),

      GoRoute(
        path: '/product/:productId',
        builder: (context, state) {
          final productId = state.pathParameters['productId']!;
          return ProductDetailScreen(productId: productId);
        },
      ),
      GoRoute(
        path: '/cart',
        builder: (context, state) => const CartScreen(),
      ),

      GoRoute(
        path: '/add-product',
        builder: (context, state) => const AddProductScreen(),
      ),
    ],
  );

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      debugShowCheckedModeBanner: false,
      routerConfig: router,
      theme: ThemeData(
        primarySwatch: Colors.pink,
        scaffoldBackgroundColor: Colors.white,
        appBarTheme: const AppBarTheme(
          color: Colors.white,
          elevation: 0,
          iconTheme: IconThemeData(color: Colors.black),
          titleTextStyle: TextStyle(
            color: Colors.black,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}
