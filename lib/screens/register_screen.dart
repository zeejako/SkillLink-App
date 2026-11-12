import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});
  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _firstName = TextEditingController();
  final _surname = TextEditingController();
  final _phone = TextEditingController();
  final _email = TextEditingController();
  final _pass = TextEditingController();
  final _confirm = TextEditingController();
  final _locationCtrl = TextEditingController();
  // FIXED: Clear naming - true = Provider, false = Client
  bool _isProvider = false;
  int _step = 1;
  bool _loading = false;

  Map<String, double>? _cityCoords(String city) {
    final c = city.toLowerCase().trim();
    if (c.contains('cape town')) return {'lat': -33.9249, 'lng': 18.4241};
    if (c.contains('mthatha')) return {'lat': -31.5889, 'lng': 28.7844};
    if (c.contains('durban')) return {'lat': -29.8587, 'lng': 31.0218};
    if (c.contains('johannesburg') || c.contains('joburg') || c.contains('jhb')) return {'lat': -26.2041, 'lng': 28.0473};
    if (c.contains('pretoria')) return {'lat': -25.7479, 'lng': 28.2293};
    if (c.contains('gqeberha') || c.contains('port elizabeth')) return {'lat': -33.9608, 'lng': 25.6022};
    if (c.contains('east london')) return {'lat': -33.0153, 'lng': 27.9116};
    if (c.contains('bloemfontein')) return {'lat': -29.0852, 'lng': 26.1596};
    if (c.contains('polokwane')) return {'lat': -23.9045, 'lng': 29.4689};
    if (c.contains('nelspruit') || c.contains('mbombela')) return {'lat': -25.4753, 'lng': 30.9694};
    return null;
  }

  Future<void> _register() async {
    if (_firstName.text.isEmpty || _surname.text.isEmpty || _phone.text.isEmpty || _email.text.isEmpty || _pass.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Fill all fields')));
      return;
    }
    if (_pass.text != _confirm.text) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Passwords do not match')));
      return;
    }
    setState(() => _loading = true);
    try {
      UserCredential cred = await FirebaseAuth.instance.createUserWithEmailAndPassword(email: _email.text.trim(), password: _pass.text.trim());

      double? lat;
      double? lng;
      try {
        bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
        if (serviceEnabled) {
          LocationPermission p = await Geolocator.checkPermission();
          if (p == LocationPermission.denied) p = await Geolocator.requestPermission();
          if (p != LocationPermission.denied && p != LocationPermission.deniedForever) {
            Position pos = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high).timeout(const Duration(seconds: 10));
            lat = pos.latitude;
            lng = pos.longitude;
          }
        }
      } catch (_) {}

      final city = _locationCtrl.text.trim().isEmpty ? 'South Africa' : _locationCtrl.text.trim();
      if (lat == null) {
        final coords = _cityCoords(city);
        if (coords != null) {
          lat = coords['lat'];
          lng = coords['lng'];
        }
      }

      final fullName = '${_firstName.text.trim()} ${_surname.text.trim()}';
      final isProvider = _isProvider;
      await FirebaseFirestore.instance.collection('users').doc(cred.user!.uid).set({
        'name': fullName,
        'firstName': _firstName.text.trim(),
        'surname': _surname.text.trim(),
        'phone': _phone.text.trim(),
        'email': _email.text.trim(),
        'location': city,
        'latitude': lat,
        'longitude': lng,
        'isProvider': isProvider,
        'role': isProvider ? 'provider' : 'client',
        'mainSkill': isProvider ? 'General' : '',
        'skill': isProvider ? 'General' : '',
        'price': '350',
        'pricePerHour': '350',
        'isAvailable': true,
        'avgRating': 0,
        'reviewCount': 0,
        'favorites': [],
        'about': '',
        'photoUrl': '',
        'createdAt': FieldValue.serverTimestamp(),
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Account created as ${isProvider ? 'Provider' : 'Client'}! Please login')));
      Navigator.pushReplacementNamed(context, '/login');
    } on FirebaseAuthException catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message ?? 'Failed'), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Widget _field(TextEditingController c, String hint, IconData icon, {bool obscure = false}) {
    return TextField(controller: c, obscureText: obscure, decoration: InputDecoration(prefixIcon: Icon(icon, color: const Color(0xFF0B2C4A), size: 20), hintText: hint, hintStyle: const TextStyle(color: Colors.grey, fontSize: 13), filled: true, fillColor: const Color(0xFFF8FAFC), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F4),
      appBar: AppBar(backgroundColor: Colors.white, elevation: 0, leading: IconButton(icon: const Icon(Icons.arrow_back, color: Colors.black), onPressed: () => Navigator.pop(context)), title: const Text('Create account', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold))),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(children: [
          Container(width: double.infinity, padding: const EdgeInsets.symmetric(vertical: 26), decoration: const BoxDecoration(gradient: LinearGradient(colors: [Color(0xFF0B2C4A), Color(0xFF0F3D5E), Color(0xFF14B8A6)]), borderRadius: BorderRadius.all(Radius.circular(20))), child: Column(children: [Container(width: 56, height: 56, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14)), child: const Icon(Icons.handshake, size: 30, color: Color(0xFF0B2C4A))), const SizedBox(height: 10), const Text('Join SkillLink', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white)), const Text('Connect. Book. Get it done.', style: TextStyle(color: Colors.white70, fontSize: 12))])),
          const SizedBox(height: 20),
          Row(children: [Text('Step $_step of 2', style: const TextStyle(color: Color(0xFF0B2C4A), fontWeight: FontWeight.bold)), const SizedBox(width: 10), Expanded(child: LinearProgressIndicator(value: _step / 2, color: const Color(0xFF14B8A6), backgroundColor: Colors.grey.shade200))]),
          const SizedBox(height: 16),
          if (_step == 1) ...[
            const Align(alignment: Alignment.centerLeft, child: Text('How will you use SkillLink?', style: TextStyle(fontWeight: FontWeight.bold))),
            const SizedBox(height: 10),
            // FIXED: CLIENT / PROVIDER - NOT Jobseeker / Business
            Container(decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.grey.shade200)), child: Row(children: [
              Expanded(child: GestureDetector(onTap: () => setState(() => _isProvider = false), child: Container(padding: const EdgeInsets.symmetric(vertical: 10), decoration: BoxDecoration(color: !_isProvider ? const Color(0xFFE0F2F1) : Colors.transparent, borderRadius: BorderRadius.circular(20)), child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.person_search, size: 14, color: !_isProvider ? const Color(0xFF0F766E) : Colors.grey), const SizedBox(width: 4), Text('Client', style: TextStyle(fontWeight: FontWeight.bold, color: !_isProvider ? const Color(0xFF0F766E) : Colors.grey))])))),
              Expanded(child: GestureDetector(onTap: () => setState(() => _isProvider = true), child: Container(padding: const EdgeInsets.symmetric(vertical: 10), decoration: BoxDecoration(color: _isProvider ? const Color(0xFFE0F2F1) : Colors.transparent, borderRadius: BorderRadius.circular(20)), child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.handyman, size: 14, color: _isProvider ? const Color(0xFF0F766E) : Colors.grey), const SizedBox(width: 4), Text('Provider', style: TextStyle(fontWeight: FontWeight.bold, color: _isProvider ? const Color(0xFF0F766E) : Colors.grey))])))),
            ])),
            const SizedBox(height: 8),
            Text(_isProvider ? 'I offer a service - clients will find and book me.' : 'I need a service - I will find and book providers.', style: const TextStyle(fontSize: 12, color: Colors.blueGrey)),
            const SizedBox(height: 16),
            _field(_firstName, 'First name', Icons.person_outline),
            const SizedBox(height: 12),
            _field(_surname, 'Surname', Icons.badge_outlined),
            const SizedBox(height: 12),
            _field(_phone, 'South African phone number', Icons.phone_outlined),
            const SizedBox(height: 12),
            _field(_locationCtrl, 'City / Location e.g. Mthatha', Icons.location_on_outlined),
            const SizedBox(height: 20),
            SizedBox(width: double.infinity, child: ElevatedButton(onPressed: () { if (_firstName.text.isEmpty || _surname.text.isEmpty || _phone.text.isEmpty) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Fill step 1'))); return; } setState(() => _step = 2); }, style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0B2C4A), padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))), child: const Text('Continue →', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)))),
          ] else ...[
            const Align(alignment: Alignment.centerLeft, child: Text('Account details', style: TextStyle(fontWeight: FontWeight.bold))),
            const SizedBox(height: 12),
            _field(_email, 'Email address', Icons.email_outlined),
            const SizedBox(height: 12),
            _field(_pass, 'Password', Icons.lock_outline, obscure: true),
            const SizedBox(height: 12),
            _field(_confirm, 'Confirm password', Icons.lock_outline, obscure: true),
            const SizedBox(height: 8),
            Text(_isProvider ? 'You will register as Provider - clients will find and book you.' : 'You will register as Client - you will find and book providers.', style: const TextStyle(fontSize: 12, color: Colors.blueGrey)),
            const SizedBox(height: 20),
            Row(children: [Expanded(child: OutlinedButton(onPressed: () => setState(() => _step = 1), child: const Text('Back'))), const SizedBox(width: 10), Expanded(flex: 2, child: ElevatedButton(onPressed: _loading ? null : _register, style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0B2C4A), padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))), child: _loading ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Text('Create Account', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))))]),
          ],
          const SizedBox(height: 16),
          GestureDetector(onTap: () => Navigator.pushNamed(context, '/login'), child: const Text('Already have account? Login', style: TextStyle(color: Color(0xFF0B2C4A), fontWeight: FontWeight.bold, fontSize: 13))),
        ]),
      ),
    );
  }
}