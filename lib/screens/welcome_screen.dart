import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/app_state_service.dart';

class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen>
    with TickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;
  
  @override
  void initState() {
    super.initState();
    
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));
    
    _scaleAnimation = Tween<double>(
      begin: 0.8,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.elasticOut,
    ));
    
    _animationController.forward();
  }
  
  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      duration: const Duration(milliseconds: 600),
      tween: Tween(begin: 0.0, end: 1.0),
      builder: (context, value, child) {
        return Opacity(
          opacity: value,
          child: Transform.scale(
            scale: 0.9 + (0.1 * value),
            child: Scaffold(
              backgroundColor: Colors.purple, // Purple background for production fleet test
              body: GestureDetector(
        onTap: () {
          context.read<AppStateService>().skipWelcome();
        },
        child: Container(
          width: double.infinity,
          height: double.infinity,
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.purple, // Purple background for production test
                Colors.deepPurple, // Purple accent for gradient
                Colors.purple, // Purple background for production test
              ],
            ),
          ),
          child: AnimatedBuilder(
            animation: _animationController,
            builder: (context, child) {
              return FadeTransition(
                opacity: _fadeAnimation,
                child: ScaleTransition(
                  scale: _scaleAnimation,
                  child: Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Logo
                        Container(
                          height: 150,
                          width: 300,
                          margin: const EdgeInsets.only(bottom: 30),
                          child: Image.asset(
                            'assets/images/logo.png',
                            fit: BoxFit.contain,
                          ),
                        ),
                        const SizedBox(height: 40),
                        const Text(
                          'Xoş Gəlmisiniz',
                          style: TextStyle(
                            fontFamily: 'Poppins',
                            color: Color(0xFFffc107), // Yellow accent
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 30),
                        const Text(
                          'Səyahətinizdən zövq alın',
                          style: TextStyle(
                            fontFamily: 'Poppins',
                            color: Color(0xFFf5f5f5),
                            fontSize: 18,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 20),
                        const Text(
                          'Xəbərlər, hava proqnozu və yeniliklərdən xəbərdar olun',
                          style: TextStyle(
                            fontFamily: 'Poppins',
                            color: Color(0xFFf5f5f5),
                            fontSize: 16,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 15),
                        const Text(
                          'Maraqlı reklamları izləyin və eksklüziv təkliflərdən yararlanın',
                          style: TextStyle(
                            fontFamily: 'Poppins',
                            color: Color(0xFFf5f5f5),
                            fontSize: 16,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 15),
                        const Text(
                          '↑ Səyahət məlumatlarını asanlıqla izləyin',
                          style: TextStyle(
                            fontFamily: 'Poppins',
                            color: Color(0xFFf5f5f5),
                            fontSize: 16,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 15),
                        const Text(
                          'Fikrinizi paylaşın və bizi daha da yaxşılaşdırmağa kömək edin',
                          style: TextStyle(
                            fontFamily: 'Poppins',
                            color: Color(0xFFf5f5f5),
                            fontSize: 16,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 15),
                        const Text(
                          '+Arxayın olun, rahat oturun və ən yaxşı səyahət təcrübəsinin dadını çıxarın',
                          style: TextStyle(
                            fontFamily: 'Poppins',
                            color: Color(0xFFf5f5f5),
                            fontSize: 16,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 40),
                        const Text(
                          'Ekrana toxun',
                          style: TextStyle(
                            fontFamily: 'Poppins',
                            color: Color(0xFFffc107), // Yellow accent
                            fontSize: 18,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
              ),
            ),
          ),
        );
      },
    );
  }
}