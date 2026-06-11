import 'package:flutter/material.dart';
import 'theme/app_theme.dart';
import 'screens/home_screen.dart';
import 'screens/about_screen.dart';
import 'screens/contact_screen.dart';
import 'screens/privacy_screen.dart';
import 'screens/terms_screen.dart';

void main() {
  runApp(const BaharJaaunApp());
}

class BaharJaaunApp extends StatelessWidget {
  const BaharJaaunApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Bahar Jaaun? — Delhi air, told straight',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.theme,
      initialRoute: '/',
      onGenerateRoute: _onGenerateRoute,
    );
  }

  Route<dynamic>? _onGenerateRoute(RouteSettings settings) {
    Widget page;
    switch (settings.name) {
      case '/about':
        page = const AboutScreen();
      case '/contact':
        page = const ContactScreen();
      case '/privacy':
        page = const PrivacyScreen();
      case '/terms':
        page = const TermsScreen();
      default:
        page = const HomeScreen();
    }

    if (settings.name == '/') {
      return PageRouteBuilder(
        settings: settings,
        pageBuilder: (ctx, a1, a2) => page,
        transitionDuration: Duration.zero,
        reverseTransitionDuration: Duration.zero,
      );
    }

    // Info screens: slide up + fade — feels like a native modal
    return PageRouteBuilder(
      settings: settings,
      pageBuilder: (ctx, a1, a2) => page,
      transitionDuration: const Duration(milliseconds: 480),
      reverseTransitionDuration: const Duration(milliseconds: 340),
      transitionsBuilder: (_, animation, secondaryAnimation, child) {
        final slideIn = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutQuart,
          reverseCurve: Curves.easeInQuart,
        );
        final fadeOut = CurvedAnimation(
          parent: secondaryAnimation,
          curve: Curves.easeIn,
        );
        return SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 0.07),
            end: Offset.zero,
          ).animate(slideIn),
          child: FadeTransition(
            opacity: Tween<double>(begin: 0.0, end: 1.0).animate(slideIn),
            child: FadeTransition(
              opacity: Tween<double>(begin: 1.0, end: 0.94).animate(fadeOut),
              child: child,
            ),
          ),
        );
      },
    );
  }
}
