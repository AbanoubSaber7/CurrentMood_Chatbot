import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'login_screen.dart';
import 'detection_screen.dart';

class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  Future<void> _handleStartNavigation(BuildContext context) async {
    // Check login state when the user presses the start button
    SharedPreferences prefs = await SharedPreferences.getInstance();
    bool isLoggedIn = prefs.getBool('isLoggedIn') ?? false;
    String? userName = prefs.getString('user_name');

    if (!context.mounted) return;

    if (isLoggedIn) {
      // If logged in, navigate to Detection
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => DetectionScreen(userName: userName ?? "User"),
        ),
      );
    } else {
      // If not logged in, navigate to Login
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const LoginScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFFBECEB), Color(0xFFEDB1AA)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
            child: Column(
              children: [
                const Spacer(),
                Flexible(
                  flex: 6,
                  child: Image.asset(
                    'assets/app_logo.png',
                    fit: BoxFit.contain,
                    semanticLabel: 'Current Mood - Track Your Feelings',
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  'A gentle space to check in with yourself.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Color(0xFF563B42),
                    fontSize: 16,
                    height: 1.4,
                  ),
                ),
                const Spacer(),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => _handleStartNavigation(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFC04F4C),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 17),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                      elevation: 3,
                    ),
                    child: const Text(
                      'GET STARTED',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
