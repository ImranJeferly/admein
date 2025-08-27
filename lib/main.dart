import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'services/app_state_service.dart';
import 'services/update_service.dart';
import 'screens/auth_screen.dart';
import 'screens/welcome_screen.dart';
import 'screens/ad_display_screen.dart';
import 'screens/non_ad_content_screen.dart';
import 'screens/qr_display_screen.dart';
import 'screens/logo_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const AdmeinApp());
}

class AdmeinApp extends StatelessWidget {
  const AdmeinApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (context) => AppStateService(),
      child: MaterialApp(
        title: '',
        theme: ThemeData(
          primarySwatch: Colors.blue,
          scaffoldBackgroundColor: const Color(0xFF2a2e6a), // New background color
          fontFamily: 'Poppins',
          colorScheme: const ColorScheme.dark(
            primary: Color(0xFF2a2e6a), // Background blue
            secondary: Color(0xFFffc107), // Yellow accent
            surface: Color(0xFF2a2e6a), // Background surface
            onPrimary: Color(0xFFf5f5f5), // White text
            onSecondary: Color(0xFF2a2e6a), // Blue text on yellow
            onSurface: Color(0xFFf5f5f5), // White text on surface
          ),
          appBarTheme: const AppBarTheme(
            backgroundColor: Color(0xFF2a2e6a),
            foregroundColor: Color(0xFFf5f5f5),
            elevation: 0,
          ),
          cardTheme: const CardThemeData(
            color: Color(0xFF2a2e6a),
            elevation: 8,
          ),
          elevatedButtonTheme: ElevatedButtonThemeData(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFffc107),
              foregroundColor: const Color(0xFF2a2e6a),
            ),
          ),
          textTheme: const TextTheme(
            displayLarge: TextStyle(fontFamily: 'Poppins', color: Color(0xFFf5f5f5)),
            displayMedium: TextStyle(fontFamily: 'Poppins', color: Color(0xFFf5f5f5)),
            displaySmall: TextStyle(fontFamily: 'Poppins', color: Color(0xFFf5f5f5)),
            headlineLarge: TextStyle(fontFamily: 'Poppins', color: Color(0xFFf5f5f5)),
            headlineMedium: TextStyle(fontFamily: 'Poppins', color: Color(0xFFf5f5f5)),
            headlineSmall: TextStyle(fontFamily: 'Poppins', color: Color(0xFFf5f5f5)),
            titleLarge: TextStyle(fontFamily: 'Poppins', color: Color(0xFFf5f5f5)),
            titleMedium: TextStyle(fontFamily: 'Poppins', color: Color(0xFFf5f5f5)),
            titleSmall: TextStyle(fontFamily: 'Poppins', color: Color(0xFFf5f5f5)),
            bodyLarge: TextStyle(fontFamily: 'Poppins', color: Color(0xFFf5f5f5)),
            bodyMedium: TextStyle(fontFamily: 'Poppins', color: Color(0xFFf5f5f5)),
            bodySmall: TextStyle(fontFamily: 'Poppins', color: Color(0xFFf5f5f5)),
            labelLarge: TextStyle(fontFamily: 'Poppins', color: Color(0xFFf5f5f5)),
            labelMedium: TextStyle(fontFamily: 'Poppins', color: Color(0xFFf5f5f5)),
            labelSmall: TextStyle(fontFamily: 'Poppins', color: Color(0xFFf5f5f5)),
          ),
        ),
        home: const MainScreen(),
        debugShowCheckedModeBanner: false,
      ),
    );
  }
}

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  @override
  void initState() {
    super.initState();
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    final appState = context.read<AppStateService>();
    await appState.initialize();
    
    // Check for app updates after initialization
    if (mounted) {
      UpdateService.checkForUpdates(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AppStateService>(
      builder: (context, appState, child) {
        return AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          switchInCurve: Curves.easeOutCubic,
          switchOutCurve: Curves.easeInCubic,
          transitionBuilder: (Widget child, Animation<double> animation) {
            return AnimatedBuilder(
              animation: animation,
              child: child,
              builder: (context, child) {
                return ClipPath(
                  clipper: CircularRevealClipper(
                    fraction: animation.value,
                  ),
                  child: child!,
                );
              },
            );
          },
          child: Container(
            key: ValueKey(appState.currentState),
            child: _getScreenWidget(appState.currentState),
          ),
        );
      },
    );
  }

  Widget _getScreenWidget(AppState currentState) {
    switch (currentState) {
      case AppState.authentication:
        return const AuthScreen();
      case AppState.welcome:
        return const WelcomeScreen();
      case AppState.adDisplay:
        return const AdDisplayScreen();
      case AppState.nonAdContent:
        return const NonAdContentScreen();
      case AppState.qrDisplay:
        return const QrDisplayScreen();
      case AppState.logoScreen:
        return const LogoScreen();
      case AppState.ratingScreen:
        return const NonAdContentScreen();
    }
  }
}

class CircularRevealClipper extends CustomClipper<Path> {
  final double fraction;

  CircularRevealClipper({required this.fraction});

  @override
  Path getClip(Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final maxRadius = size.longestSide;
    final radius = maxRadius * fraction;
    
    return Path()
      ..addOval(Rect.fromCircle(center: center, radius: radius));
  }

  @override
  bool shouldReclip(CustomClipper<Path> oldClipper) => true;
}