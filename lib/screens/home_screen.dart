import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'client_home.dart';
import 'provider_dashboard.dart';
import 'login_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const LoginScreen();
    }

    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('users').doc(user.uid).snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        final data = snapshot.data!.data() as Map<String, dynamic>?;
        final role = (data?['role'] ?? 'client').toString().toLowerCase();

        if (role == 'provider') {
          return const ProviderDashboard();
        } else {
          return const ClientHome();
        }
      },
    );
  }
}