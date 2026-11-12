import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'client_home.dart';
import 'provider_dashboard.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});
  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(seconds: 3), _goNext);
  }

  void _goNext() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      bool isProvider = false;
      try {
        final doc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();
        if (doc.exists) {
          final d = doc.data()!;
          final role = (d['role'] as String?)?.toLowerCase() ?? '';
          if (d['isProvider'] == true || role == 'provider') isProvider = true;
        }
      } catch (_) {}
      if (!mounted) return;
      if (isProvider) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const ProviderDashboard()),
        );
      } else {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const ClientHome()),
        );
      }
    } else {
      if (!mounted) return;
      Navigator.pushReplacementNamed(context, '/login');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        // NEW PROFESSIONAL COLOUR: Deep Navy -> Teal
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF0B2C4A), // Deep Navy - top
              Color(0xFF0F3D5E), // Professional Blue - middle
              Color(0xFF14B8A6), // Teal - bottom accent
            ],
          ),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 110,
                height: 110,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.25),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: const Center(
                  child: Icon(
                    Icons.handshake,
                    size: 60,
                    color: Color(0xFF0B2C4A),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'SkillLink',
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 8),
              // NEW TAGLINE - NUMBER 3
              const Text(
                'Connect. Book. Get it done.',
                style: TextStyle(
                  fontSize: 15,
                  color: Colors.white,
                  fontWeight: FontWeight.w500,
                  letterSpacing: 0.3,
                ),
              ),
              const SizedBox(height: 30),
              const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
