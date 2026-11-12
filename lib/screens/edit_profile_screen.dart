import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geolocator/geolocator.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});
  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final nameCtrl = TextEditingController();
  final phoneCtrl = TextEditingController();
  final locationCtrl = TextEditingController();
  final skillCtrl = TextEditingController();
  final aboutCtrl = TextEditingController();
  final priceCtrl = TextEditingController();

  bool _loading = true;
  bool _saving = false;
  bool _isProvider = false;
  bool _isAvailable = true;
  double? _lat;
  double? _lng;
  bool _locating = false;

  // Same suburb pins as other files
  Map<String, double>? _cityCoords(String city) {
    final c = city.toLowerCase().trim();
    if (c.contains('southernwood')) return {'lat': -33.0080, 'lng': 27.9030};
    if (c.contains('mdantsane')) return {'lat': -32.9830, 'lng': 27.7400};
    if (c.contains('duncan village') || c.contains('duncan')) {
      return {'lat': -33.0130, 'lng': 27.8860};
    }
    if (c.contains('quigney')) return {'lat': -33.0140, 'lng': 27.9200};
    if (c.contains('vincent')) return {'lat': -32.9960, 'lng': 27.9350};
    if (c.contains('beacon bay')) return {'lat': -32.9810, 'lng': 27.9170};
    if (c.contains('gonubie')) return {'lat': -32.9350, 'lng': 28.0150};
    if (c.contains('amalinda')) return {'lat': -33.0080, 'lng': 27.8600};
    if (c.contains('cambridge')) return {'lat': -33.0150, 'lng': 27.8450};
    if (c.contains('berea')) return {'lat': -33.0050, 'lng': 27.9050};
    if (c.contains('nahoon')) return {'lat': -32.9950, 'lng': 27.9300};
    if (c.contains('east london') || c.contains('buffalo city')) {
      return {'lat': -33.0153, 'lng': 27.9116};
    }
    if (c.contains('cape town')) return {'lat': -33.9249, 'lng': 18.4241};
    if (c.contains('durban')) return {'lat': -29.8587, 'lng': 31.0218};
    if (c.contains('johannesburg') || c.contains('joburg')) {
      return {'lat': -26.2041, 'lng': 28.0473};
    }
    if (c.contains('pretoria')) return {'lat': -25.7479, 'lng': 28.2293};
    if (c.contains('gqeberha') || c.contains('port elizabeth')) {
      return {'lat': -33.9608, 'lng': 25.6022};
    }
    return null;
  }

  Future<void> _load() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get();
    final d = doc.data() ?? {};
    setState(() {
      nameCtrl.text = (d['name'] ?? '').toString();
      phoneCtrl.text = (d['phone'] ?? '').toString();
      locationCtrl.text = (d['location'] ?? '').toString();
      skillCtrl.text = (d['mainSkill'] ?? d['skill'] ?? '').toString();
      aboutCtrl.text = (d['about'] ?? '').toString();
      priceCtrl.text = (d['pricePerHour'] ?? d['price'] ?? '').toString();
      _isProvider = d['isProvider'] == true;
      _isAvailable = d['isAvailable'] != false;
      _lat = (d['latitude'] as num?)?.toDouble();
      _lng = (d['longitude'] as num?)?.toDouble();
      _loading = false;
    });
  }

  Future<void> _useMyLocation() async {
    setState(() => _locating = true);
    try {
      final service = await Geolocator.isLocationServiceEnabled();
      if (!service) throw 'Location is OFF.';
      var p = await Geolocator.checkPermission();
      if (p == LocationPermission.denied) {
        p = await Geolocator.requestPermission();
      }
      if (p == LocationPermission.denied ||
          p == LocationPermission.deniedForever) {
        throw 'Permission denied.';
      }
      final pos = await Geolocator.getCurrentPosition();
      setState(() {
        _lat = pos.latitude;
        _lng = pos.longitude;
        locationCtrl.text = 'Current Location';
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Location picked - remember to Save'),
          backgroundColor: Color(0xFF14B8A6),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    }
    if (mounted) setState(() => _locating = false);
  }

  Future<void> _save() async {
    if (nameCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter your name')),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      final user = FirebaseAuth.instance.currentUser!;
      double? lat = _lat;
      double? lng = _lng;

      // If user typed a suburb, use its pin
      final typed = _cityCoords(locationCtrl.text.trim());
      if (typed != null) {
        lat = typed['lat'];
        lng = typed['lng'];
      }

      final Map<String, dynamic> data = {
        'name': nameCtrl.text.trim(),
        'phone': phoneCtrl.text.trim(),
        'location': locationCtrl.text.trim(),
      };
      if (lat != null) data['latitude'] = lat;
      if (lng != null) data['longitude'] = lng;

      if (_isProvider) {
        data['mainSkill'] = skillCtrl.text.trim();
        data['skill'] = skillCtrl.text.trim();
        data['about'] = aboutCtrl.text.trim();
        data['pricePerHour'] = priceCtrl.text.trim();
        data['price'] = priceCtrl.text.trim();
        data['isAvailable'] = _isAvailable;
      }

      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .update(data);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Profile updated!'),
          backgroundColor: Color(0xFF14B8A6),
        ),
      );
      Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Save failed: $e')),
      );
    }
    if (mounted) setState(() => _saving = false);
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    nameCtrl.dispose();
    phoneCtrl.dispose();
    locationCtrl.dispose();
    skillCtrl.dispose();
    aboutCtrl.dispose();
    priceCtrl.dispose();
    super.dispose();
  }

  Widget _field(
    TextEditingController ctrl,
    String label,
    IconData icon, {
    TextInputType type = TextInputType.text,
    int maxLines = 1,
  }) {
    return TextField(
      controller: ctrl,
      keyboardType: type,
      maxLines: maxLines,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F4),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black87),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Edit Profile',
          style: TextStyle(
            color: Color(0xFF14B8A6),
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            CircleAvatar(
              radius: 36,
              backgroundColor: const Color(0xFF14B8A6),
              child: Text(
                nameCtrl.text.isNotEmpty
                    ? nameCtrl.text[0].toUpperCase()
                    : 'U',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _isProvider ? 'Provider Profile' : 'Client Profile',
              style: const TextStyle(
                color: Colors.grey,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 20),
            _field(nameCtrl, 'Full Name', Icons.person),
            const SizedBox(height: 12),
            _field(
              phoneCtrl,
              'Phone (e.g. 0821234567)',
              Icons.phone,
              type: TextInputType.phone,
            ),
            const SizedBox(height: 12),
            _field(locationCtrl, 'Location / Suburb', Icons.location_on),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _locating ? null : _useMyLocation,
                icon: const Icon(Icons.my_location, size: 18),
                label: Text(
                  _locating ? 'Getting location...' : 'Use My Current Location',
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF14B8A6),
                ),
              ),
            ),
            if (_lat != null && _lng != null)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  'Saved pin: ${_lat!.toStringAsFixed(4)}, ${_lng!.toStringAsFixed(4)}',
                  style: const TextStyle(fontSize: 11, color: Colors.grey),
                ),
              ),
            if (_isProvider) ...[
              const SizedBox(height: 12),
              _field(skillCtrl, 'Skill (e.g. Plumber)', Icons.build),
              const SizedBox(height: 12),
              _field(
                priceCtrl,
                'Price per hour (rands)',
                Icons.attach_money,
                type: TextInputType.number,
              ),
              const SizedBox(height: 12),
              _field(
                aboutCtrl,
                'About / Experience',
                Icons.info_outline,
                maxLines: 3,
              ),
              const SizedBox(height: 12),
              SwitchListTile(
                title: const Text('Available for work'),
                value: _isAvailable,
                activeThumbColor: const Color(0xFF14B8A6),
                onChanged: (v) => setState(() => _isAvailable = v),
              ),
            ],
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _saving ? null : _save,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF14B8A6),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: _saving
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text(
                        'Save Changes',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}