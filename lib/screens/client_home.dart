import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geolocator/geolocator.dart';

import 'provider_profile_screen.dart';
import 'splash_screen.dart';
import 'map_screen.dart';

class ClientHome extends StatefulWidget {
  const ClientHome({super.key});
  @override
  State<ClientHome> createState() => _ClientHomeState();
}

class _ClientHomeState extends State<ClientHome> {
  int currentIndex = 0;
  String searchText = '';
  String selectedSkill = 'All';
  bool nearMeOnly = false;
  bool sortByDistance = false;
  String sortMode = 'topRated'; // topRated, nearest, nearMe
  double? myLat;
  double? myLng;
  String myLocationText = '';
  String myName = '';
  String myPhone = '';
  bool? appDarkMode;

  // NEW: To stop the same notification showing again and again
  final Set<String> _notifiedBookingIds = {};

  final List<String> skills = [
    'All',
    'General',
    'Tech Help',
    'Plumbing',
    'Electrical',
    'Cleaning',
    'Tutoring',
    'Gardening',
    'Painting',
  ];

  @override
  void initState() {
    super.initState();
    _loadMyLocation();
    _loadMe();
    _listenForBookingUpdates();
  }

  // NEW: CLIENT NOTIFICATION - When provider accepts / declines
  void _listenForBookingUpdates() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    FirebaseFirestore.instance
        .collection('bookings')
        .where('clientId', isEqualTo: user.uid)
        .snapshots()
        .listen((snap) {
      if (!mounted) return;
      for (var doc in snap.docs) {
        final d = doc.data();
        final status = (d['status'] ?? '').toString().toLowerCase();
        final key = '${doc.id}_$status';
        if (_notifiedBookingIds.contains(key)) continue;
        if (status == 'approved') {
          _notifiedBookingIds.add(key);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${d['providerName'] ?? 'Provider'} accepted your booking!'),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 4),
            ),
          );
        }
        if (status == 'declined') {
          _notifiedBookingIds.add(key);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${d['providerName'] ?? 'Provider'} declined. Try another provider.'),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 4),
            ),
          );
        }
        if (status == 'completed') {
          _notifiedBookingIds.add(key);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Your job is completed. Please rate your provider!'),
              backgroundColor: Colors.blue,
              duration: Duration(seconds: 4),
            ),
          );
        }
      }
    });
  }

  String _greeting() {
    final h = DateTime.now().hour;
    if (h < 12) return 'Good Morning';
    if (h < 17) return 'Good Afternoon';
    return 'Good Evening';
  }

  IconData _greetingIcon() {
    final h = DateTime.now().hour;
    if (h < 12) return Icons.wb_sunny_outlined;
    if (h < 17) return Icons.wb_sunny;
    return Icons.nightlight_round;
  }

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
    if (c.contains('buffalo city')) return {'lat': -33.0153, 'lng': 27.9116};
    if (c.contains('cape town')) return {'lat': -33.9249, 'lng': 18.4241};
    if (c.contains('mthatha')) return {'lat': -31.5889, 'lng': 28.7844};
    if (c.contains('durban')) return {'lat': -29.8587, 'lng': 31.0218};
    if (c.contains('johannesburg') ||
        c.contains('joburg') ||
        c.contains('jhb')) {
      return {'lat': -26.2041, 'lng': 28.0473};
    }
    if (c.contains('pretoria')) return {'lat': -25.7479, 'lng': 28.2293};
    if (c.contains('gqeberha') || c.contains('port elizabeth')) {
      return {'lat': -33.9608, 'lng': 25.6022};
    }
    if (c.contains('east london')) return {'lat': -33.0153, 'lng': 27.9116};
    if (c.contains('bloemfontein')) return {'lat': -29.0852, 'lng': 26.1596};
    if (c.contains('polokwane')) return {'lat': -23.9045, 'lng': 29.4689};
    if (c.contains('nelspruit') || c.contains('mbombela')) {
      return {'lat': -25.4753, 'lng': 30.9694};
    }
    return null;
  }

  Future<void> _loadMe() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get();
    final d = doc.data() ?? {};
    if (mounted) {
      setState(() {
        myName = (d['name'] ?? '').toString();
        myPhone = (d['phone'] ?? '').toString();
      });
    }
  }

  Future<void> _loadMyLocation() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      final data = doc.data();
      if (data != null) {
        myLocationText = (data['location'] ?? '').toString();
        final coordsFromText = _cityCoords(myLocationText);
        if (coordsFromText != null) {
          final savedLat = (data['latitude'] as num?)?.toDouble();
          final savedLng = (data['longitude'] as num?)?.toDouble();
          bool needsFix = savedLat == null || savedLng == null;
          if (!needsFix) {
            final d =
                Geolocator.distanceBetween(
                  savedLat,
                  savedLng,
                  coordsFromText['lat']!,
                  coordsFromText['lng']!,
                ) /
                1000;
            if (d > 1.0) needsFix = true;
          }
          if (needsFix) {
            myLat = coordsFromText['lat'];
            myLng = coordsFromText['lng'];
            await FirebaseFirestore.instance
                .collection('users')
                .doc(user.uid)
                .update({'latitude': myLat, 'longitude': myLng});
            if (mounted) setState(() {});
            return;
          }
          myLat = savedLat;
          myLng = savedLng;
          if (mounted) setState(() {});
          return;
        }
        if (data['latitude'] != null && data['longitude'] != null) {
          if (mounted) {
            setState(() {
              myLat = (data['latitude'] as num).toDouble();
              myLng = (data['longitude'] as num).toDouble();
            });
          }
          return;
        }
      }
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return;
      LocationPermission p = await Geolocator.checkPermission();
      if (p == LocationPermission.denied) {
        p = await Geolocator.requestPermission();
      }
      if (p == LocationPermission.denied ||
          p == LocationPermission.deniedForever) {
        return;
      }
      Position pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      ).timeout(const Duration(seconds: 10));
      myLat = pos.latitude;
      myLng = pos.longitude;
      await FirebaseFirestore.instance.collection('users').doc(user.uid).update(
        {'latitude': pos.latitude, 'longitude': pos.longitude},
      );
      if (mounted) setState(() {});
    } catch (_) {}
  }

  double? _distanceFor(Map<String, dynamic> data) {
    double? cLat = myLat;
    double? cLng = myLng;
    if (cLat == null || cLng == null) {
      final cc = _cityCoords(myLocationText);
      if (cc != null) {
        cLat = cc['lat'];
        cLng = cc['lng'];
      }
    }
    double? pLat = (data['latitude'] as num?)?.toDouble();
    double? pLng = (data['longitude'] as num?)?.toDouble();
    if (pLat == null || pLng == null) {
      final pc = _cityCoords((data['location'] ?? '').toString());
      if (pc != null) {
        pLat = pc['lat'];
        pLng = pc['lng'];
      }
    }
    if (cLat == null || cLng == null || pLat == null || pLng == null) {
      return null;
    }
    try {
      final km = Geolocator.distanceBetween(cLat, cLng, pLat, pLng) / 1000;
      if (km < 0.1) return 0.5;
      return km;
    } catch (_) {
      return null;
    }
  }

  // FIXED FILTERING - Search any word, Top Rated, Near Me, Nearest
  List<QueryDocumentSnapshot> _applyFilters(List<QueryDocumentSnapshot> docs) {
    if (searchText.isNotEmpty) {
      final q = searchText.toLowerCase().trim();
      docs = docs.where((d) {
        final data = d.data() as Map<String, dynamic>;
        final name = (data['name'] ?? '').toString().toLowerCase();
        final skill = (data['mainSkill'] ?? data['skill'] ?? '')
            .toString()
            .toLowerCase();
        final loc = (data['location'] ?? '').toString().toLowerCase();
        final about = (data['about'] ?? '').toString().toLowerCase();
        final job = (data['jobTitle'] ?? '').toString().toLowerCase();
        String skillsList = '';
        if (data['skills'] is List) {
          skillsList = (data['skills'] as List).join(' ').toLowerCase();
        }
        final allText = '$name $skill $loc $about $job $skillsList';
        final words = q.split(' ');
        final tokens = allText.split(RegExp(r'[^a-z0-9]+'));
        return words.every((w) {
          if (w.isEmpty) return true;
          if (allText.contains(w)) return true;
          for (final token in tokens) {
            if (token.isEmpty) continue;
            if (token.startsWith(w) || w.startsWith(token)) return true;
            if (token.length >= 5 && w.length >= 5) {
              if (token.substring(0, 5) == w.substring(0, 5)) return true;
            }
          }
          return false;
        });
      }).toList();
    }
    if (selectedSkill != 'All') {
      docs = docs.where((d) {
        final data = d.data() as Map<String, dynamic>;
        final skill = (data['mainSkill'] ?? data['skill'] ?? '')
            .toString()
            .toLowerCase();
        final about = (data['about'] ?? '').toString().toLowerCase();
        final q = selectedSkill.toLowerCase();
        return skill.contains(q) || about.contains(q);
      }).toList();
    }
    if (nearMeOnly || sortMode == 'nearMe') {
      docs = docs.where((d) {
        final dist = _distanceFor(d.data() as Map<String, dynamic>);
        return dist != null && dist <= 15;
      }).toList();
    }
    if (nearMeOnly || sortMode == 'nearMe' || sortMode == 'nearest') {
      docs.sort((a, b) {
        final da = _distanceFor(a.data() as Map<String, dynamic>);
        final db = _distanceFor(b.data() as Map<String, dynamic>);
        if (da != null && db != null) return da.compareTo(db);
        if (da != null) return -1;
        if (db != null) return 1;
        return 0;
      });
    } else {
      docs.sort((a, b) {
        final ra = (((a.data() as Map)['avgRating'] ?? 0) as num).toDouble();
        final rb = (((b.data() as Map)['avgRating'] ?? 0) as num).toDouble();
        if (rb != ra) return rb.compareTo(ra);
        final ca = (((a.data() as Map)['reviewCount'] ?? 0) as num).toInt();
        final cb = (((b.data() as Map)['reviewCount'] ?? 0) as num).toInt();
        return cb.compareTo(ca);
      });
    }
    return docs;
  }

  Future<void> _bookProvider(
    String providerId,
    Map<String, dynamic> prov,
  ) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final uid = user.uid;
    await FirebaseFirestore.instance.collection('bookings').add({
      'clientId': uid,
      'clientName': myName.isNotEmpty ? myName : 'Client',
      'clientPhone': myPhone,
      'providerId': providerId,
      'providerName': prov['name'] ?? 'Provider',
      'skill': prov['mainSkill'] ?? prov['skill'] ?? 'General',
      'jobTitle': prov['mainSkill'] ?? prov['skill'] ?? 'General',
      'price': prov['pricePerHour'] ?? prov['price'] ?? '350',
      'status': 'pending',
      'createdAt': FieldValue.serverTimestamp(),
    });
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Booking request sent! Provider will accept.'),
        ),
      );
      setState(() => currentIndex = 1);
    }
  }

  Future<void> _rateBooking(String bookingId, String providerId) async {
    int stars = 5;
    final ctrl = TextEditingController();
    final result = await showDialog<bool>(
      context: context,
      builder: (c) => StatefulBuilder(
        builder: (c2, setDialogState) => AlertDialog(
          title: const Text('Rate Provider'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  5,
                  (i) => IconButton(
                    icon: Icon(
                      i < stars ? Icons.star : Icons.star_border,
                      color: Colors.amber,
                      size: 32,
                    ),
                    onPressed: () => setDialogState(() => stars = i + 1),
                  ),
                ),
              ),
              Text(
                '$stars stars - Tap to change',
                style: const TextStyle(fontSize: 11, color: Colors.grey),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: ctrl,
                maxLines: 3,
                decoration: const InputDecoration(
                  hintText: 'Write a review... e.g. On time, great work',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(c, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(c, true),
              child: const Text('Submit'),
            ),
          ],
        ),
      ),
    );
    if (result == true) {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;
      final uid = user.uid;
      await FirebaseFirestore.instance.collection('reviews').add({
        'clientId': uid,
        'clientName': myName.isNotEmpty ? myName : 'Client',
        'providerId': providerId,
        'bookingId': bookingId,
        'rating': stars,
        'comment': ctrl.text.trim(),
        'createdAt': FieldValue.serverTimestamp(),
      });
      await FirebaseFirestore.instance
          .collection('bookings')
          .doc(bookingId)
          .update({'status': 'rated', 'rating': stars});
      final revs = await FirebaseFirestore.instance
          .collection('reviews')
          .where('providerId', isEqualTo: providerId)
          .get();
      double sum = 0;
      for (var d in revs.docs) {
        sum += ((d.data()['rating'] ?? 0) as num).toDouble();
      }
      double avg = revs.docs.isEmpty ? 0 : sum / revs.docs.length;
      await FirebaseFirestore.instance
          .collection('users')
          .doc(providerId)
          .update({'avgRating': avg, 'reviewCount': revs.docs.length});
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Thanks for rating!')));
      }
    }
  }

  Future<void> _doLogout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Log out?'),
        content: const Text('Are you sure you want to log out?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Log Out', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await FirebaseAuth.instance.signOut();
      if (!mounted) return;
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const SplashScreen()),
        (r) => false,
      );
    }
  }

  void showHelpSupport(Color card, Color text, Color sub) {
    showModalBottomSheet(
      context: context,
      backgroundColor: card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Help & Support',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: text,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Email: support@skilllink.co.za\nPhone: +27 61 234 5678\n\nHow it works:\n1. Find a provider near you\n2. Tap Book - provider accepts\n3. Provider comes and does the job\n4. Rate them after - with stars + comment',
              style: TextStyle(fontSize: 12, color: sub, height: 1.5),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF14B8A6),
                ),
                child: const Text(
                  'Close',
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void showAboutSkillLink(Color card, Color text, Color sub) {
    showModalBottomSheet(
      context: context,
      backgroundColor: card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF14B8A6).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.handshake,
                    color: Color(0xFF14B8A6),
                    size: 24,
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  'About SkillLink',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: text,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'SkillLink connects you with trusted, rated providers in South Africa.\n\n- See real ratings + real comments\n- See distance in km\n- Chat on WhatsApp straight to provider\n- Book in 1 tap\n\nVersion 1.0.0\nDeveloped in South Africa',
              style: TextStyle(fontSize: 13, color: sub, height: 1.5),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF14B8A6),
                ),
                child: const Text(
                  'Got it',
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final systemDark = Theme.of(context).brightness == Brightness.dark;
    final isDark = appDarkMode ?? systemDark;
    final bg = isDark ? const Color(0xFF121212) : const Color(0xFFF1F5F4);
    final card = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final t = isDark ? Colors.white : Colors.black87;
    final sub = isDark ? Colors.grey.shade400 : Colors.grey.shade600;
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: card,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.logout, color: Colors.red),
          onPressed: _doLogout,
          tooltip: 'Logout',
        ),
        title: const Text(
          'SkillLink',
          style: TextStyle(
            color: Color(0xFF14B8A6),
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.map, color: Color(0xFF14B8A6)),
            tooltip: 'Open Map',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => MapScreen(myLat: myLat, myLng: myLng),
              ),
            ),
          ),
          IconButton(
            onPressed: () => setState(() => appDarkMode = !isDark),
            icon: Icon(isDark ? Icons.light_mode : Icons.dark_mode, color: t),
            tooltip: 'Dark Mode',
          ),
          CircleAvatar(
            radius: 16,
            backgroundColor: const Color(0xFF14B8A6),
            child: Text(
              myName.isNotEmpty ? myName[0].toUpperCase() : 'C',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 10),
        ],
      ),
      body: currentIndex == 0
          ? _homeTab(isDark, card, t, sub)
          : currentIndex == 1
          ? _bookingsTab(user.uid, isDark, card, t, sub)
          : _profileTab(user, isDark, card, t, sub),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: currentIndex,
        onTap: (i) => setState(() => currentIndex = i),
        selectedItemColor: const Color(0xFF14B8A6),
        backgroundColor: card,
        unselectedItemColor: sub,
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.book), label: 'My Bookings'),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
        ],
      ),
    );
  }

  Widget _homeTab(bool isDark, Color card, Color t, Color sub) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .where('isProvider', isEqualTo: true)
          .snapshots(),
      builder: (context, snap) {
        if (snap.hasError) {
          return Center(child: Text('Error loading providers: ${snap.error}'));
        }
        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        var docs = _applyFilters(snap.data!.docs);
        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF14B8A6), Color(0xFF0F3D5E)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(
                            _greetingIcon(),
                            color: Colors.white,
                            size: 22,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${_greeting()}, ${myName.isNotEmpty ? myName.split(' ').first : 'there'}',
                                style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                              const Text(
                                'Find trusted providers near you.',
                                style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.location_on,
                            size: 16,
                            color: Color(0xFF14B8A6),
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              myLocationText.isNotEmpty
                                  ? myLocationText
                                  : 'South Africa',
                              style: const TextStyle(fontSize: 12),
                            ),
                          ),
                          GestureDetector(
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) =>
                                    MapScreen(myLat: myLat, myLng: myLng),
                              ),
                            ),
                            child: const Text(
                              'View Map',
                              style: TextStyle(
                                fontSize: 12,
                                color: Color(0xFF14B8A6),
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                onChanged: (v) => setState(() => searchText = v),
                style: TextStyle(color: t),
                decoration: InputDecoration(
                  hintText: 'Search plumber, cleaner, tech help...',
                  hintStyle: TextStyle(color: sub),
                  prefixIcon: Icon(Icons.search, color: sub),
                  filled: true,
                  fillColor: card,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _quickPick(
                      Icons.cleaning_services,
                      'Cleaning',
                      card,
                      t,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _quickPick(Icons.plumbing, 'Plumbing', card, t),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _quickPick(Icons.computer, 'Tech Help', card, t),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: skills
                      .map(
                        (s) => Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: ChoiceChip(
                            label: Text(s),
                            selected: selectedSkill == s,
                            selectedColor: const Color(0xFF14B8A6),
                            labelStyle: TextStyle(
                              color: selectedSkill == s ? Colors.white : t,
                            ),
                            backgroundColor: card,
                            onSelected: (_) =>
                                setState(() => selectedSkill = s),
                          ),
                        ),
                      )
                      .toList(),
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  FilterChip(
                    label: const Text(
                      'Near Me',
                      style: TextStyle(fontSize: 11),
                    ),
                    avatar: const Icon(Icons.location_on, size: 14),
                    selected: sortMode == 'nearMe',
                    selectedColor: const Color(0xFF14B8A6),
                    backgroundColor: card,
                    onSelected: (v) async {
                      if (v && myLat == null) await _loadMyLocation();
                      setState(() {
                        sortMode = 'nearMe';
                        nearMeOnly = true;
                        sortByDistance = true;
                      });
                    },
                  ),
                  const SizedBox(width: 8),
                  FilterChip(
                    label: const Text(
                      'Top Rated',
                      style: TextStyle(fontSize: 11),
                    ),
                    avatar: const Icon(Icons.star, size: 14),
                    selected: sortMode == 'topRated',
                    selectedColor: const Color(0xFF14B8A6),
                    backgroundColor: card,
                    onSelected: (_) => setState(() {
                      sortMode = 'topRated';
                      sortByDistance = false;
                      nearMeOnly = false;
                    }),
                  ),
                  const SizedBox(width: 8),
                  FilterChip(
                    label: const Text(
                      'Nearest',
                      style: TextStyle(fontSize: 11),
                    ),
                    avatar: const Icon(Icons.near_me, size: 14),
                    selected: sortMode == 'nearest',
                    selectedColor: const Color(0xFF14B8A6),
                    backgroundColor: card,
                    onSelected: (_) async {
                      if (myLat == null) await _loadMyLocation();
                      setState(() {
                        sortMode = 'nearest';
                        sortByDistance = true;
                        nearMeOnly = false;
                      });
                    },
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Text(
                'Providers Near You - ${docs.length} found',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: t,
                ),
              ),
              if (nearMeOnly)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    'Showing only providers within 15km',
                    style: TextStyle(fontSize: 11, color: sub),
                  ),
                ),
              const SizedBox(height: 10),
              if (docs.isEmpty)
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: card,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Column(
                    children: [
                      Text(
                        'No providers found for "$selectedSkill"',
                        style: TextStyle(color: sub),
                      ),
                      const SizedBox(height: 10),
                      ElevatedButton(
                        onPressed: () => setState(() {
                          selectedSkill = 'All';
                          searchText = '';
                          nearMeOnly = false;
                          sortByDistance = false;
                          sortMode = 'topRated';
                        }),
                        child: const Text('Show All Providers'),
                      ),
                    ],
                  ),
                )
              else
                Column(
                  children: docs.map((doc) {
                    final d = doc.data() as Map<String, dynamic>;
                    final dist = _distanceFor(d);
                    final avg = ((d['avgRating'] ?? 0) as num).toDouble();
                    final count = ((d['reviewCount'] ?? 0) as num).toInt();
                    final available = d['isAvailable'] != false;
                    final priceText = (d['pricePerHour'] ?? d['price'] ?? '350')
                        .toString();
                    return InkWell(
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ProviderProfileScreen(
                            providerId: doc.id,
                            distanceKm: dist,
                          ),
                        ),
                      ),
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: card,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 26,
                              backgroundColor: const Color(0xFF14B8A6),
                              child: Text(
                                (d['name'] ?? 'P').toString().isNotEmpty
                                    ? (d['name'] as String)[0].toUpperCase()
                                    : 'P',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 20,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          d['name'] ?? 'Provider',
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 15,
                                            color: t,
                                          ),
                                        ),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 6,
                                          vertical: 2,
                                        ),
                                        decoration: BoxDecoration(
                                          color: available
                                              ? Colors.green.withValues(
                                                  alpha: 0.12,
                                                )
                                              : Colors.orange.withValues(
                                                  alpha: 0.12,
                                                ),
                                          borderRadius: BorderRadius.circular(
                                            20,
                                          ),
                                        ),
                                        child: Text(
                                          available ? 'AVAILABLE' : 'BUSY',
                                          style: TextStyle(
                                            fontSize: 9,
                                            fontWeight: FontWeight.bold,
                                            color: available
                                                ? Colors.green
                                                : Colors.orange,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  Text(
                                    '${d['mainSkill'] ?? d['skill'] ?? 'General'} - ${d['location'] ?? ''}',
                                    style: TextStyle(color: sub, fontSize: 12),
                                  ),
                                  const SizedBox(height: 4),
                                  Row(
                                    children: [
                                      const Icon(
                                        Icons.star,
                                        color: Colors.amber,
                                        size: 14,
                                      ),
                                      Text(
                                        ' ${avg.toStringAsFixed(1)} ($count)',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: t,
                                        ),
                                      ),
                                      if (dist != null)
                                        Text(
                                          ' - ${dist.toStringAsFixed(1)} km away',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: sub,
                                          ),
                                        ),
                                    ],
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    '$priceText rands / hour',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: Color(0xFF14B8A6),
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            ElevatedButton(
                              onPressed: () => _bookProvider(doc.id, d),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF14B8A6),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 8,
                                ),
                              ),
                              child: const Text(
                                'Book Now',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _quickPick(IconData icon, String skill, Color card, Color t) {
    final sel = selectedSkill == skill;
    return InkWell(
      onTap: () => setState(() => selectedSkill = sel ? 'All' : skill),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: sel ? const Color(0xFF14B8A6) : card,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              color: sel ? Colors.white : const Color(0xFF14B8A6),
              size: 24,
            ),
            const SizedBox(height: 4),
            Text(
              skill,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: sel ? Colors.white : t,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _bookingsTab(String uid, bool isDark, Color card, Color t, Color sub) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('bookings')
          .where('clientId', isEqualTo: uid)
          .snapshots(),
      builder: (context, snap) {
        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final docs = snap.data!.docs;
        if (docs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.book_outlined, size: 48, color: Colors.grey),
                const SizedBox(height: 10),
                Text('No bookings yet.', style: TextStyle(color: sub)),
                const SizedBox(height: 10),
                ElevatedButton(
                  onPressed: () => setState(() => currentIndex = 0),
                  child: const Text('Find a Provider'),
                ),
              ],
            ),
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: docs.length,
          itemBuilder: (c, i) {
            final d = docs[i].data() as Map<String, dynamic>;
            final st = (d['status'] ?? 'pending').toString();
            final priceText = (d['price'] ?? '').toString();
            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: card,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        d['providerName'] ?? 'Provider',
                        style: TextStyle(fontWeight: FontWeight.bold, color: t),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.blue.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          st.toUpperCase(),
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: Colors.blue,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${d['skill'] ?? ''} - $priceText rands / hour',
                    style: TextStyle(color: sub, fontSize: 12),
                  ),
                  if (st == 'completed')
                    Padding(
                      padding: const EdgeInsets.only(top: 10),
                      child: SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: () => _rateBooking(
                            docs[i].id,
                            (d['providerId'] ?? '').toString(),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.amber,
                          ),
                          child: const Text(
                            'Rate Provider',
                            style: TextStyle(color: Colors.black),
                          ),
                        ),
                      ),
                    ),
                  if (st == 'approved')
                    const Padding(
                      padding: EdgeInsets.only(top: 8),
                      child: Text(
                        'Provider accepted! Contact them to arrange time.',
                        style: TextStyle(fontSize: 12, color: Colors.green),
                      ),
                    ),
                  if (st == 'pending')
                    const Padding(
                      padding: EdgeInsets.only(top: 8),
                      child: Text(
                        'Waiting for provider to accept...',
                        style: TextStyle(fontSize: 12, color: Colors.orange),
                      ),
                    ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _profileTab(User user, bool isDark, Color card, Color t, Color sub) {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .snapshots(),
      builder: (context, snap) {
        if (snap.hasError) {
          return Center(child: Text('Error: ${snap.error}'));
        }
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (!snap.hasData || !snap.data!.exists) {
          return const Center(child: Text('Loading profile...'));
        }
        final raw = snap.data!.data();
        final d = (raw is Map<String, dynamic>) ? raw : <String, dynamic>{};
        final loc = (d['location'] ?? 'Not set').toString();
        final phone = (d['phone'] ?? 'Not set').toString();
        final name = (d['name'] ?? 'Client').toString();
        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              CircleAvatar(
                radius: 42,
                backgroundColor: const Color(0xFF14B8A6),
                child: Text(
                  name.isNotEmpty ? name[0].toUpperCase() : 'C',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 30,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                name,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: t,
                ),
              ),
              Text(user.email ?? '', style: TextStyle(color: sub)),
              const SizedBox(height: 20),
              Container(
                decoration: BoxDecoration(
                  color: card,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: ListTile(
                  title: Text('Location', style: TextStyle(color: t)),
                  subtitle: Text(loc, style: TextStyle(color: sub)),
                  trailing: Icon(Icons.edit, color: sub),
                  onTap: () async {
                    final ctrl = TextEditingController(
                      text: loc == 'Not set' ? '' : loc,
                    );
                    final v = await showDialog<String>(
                      context: context,
                      builder: (c) => AlertDialog(
                        title: const Text('Edit Location'),
                        content: TextField(
                          controller: ctrl,
                          decoration: const InputDecoration(
                            hintText: 'e.g. Southernwood, Mdantsane',
                          ),
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(c),
                            child: const Text('Cancel'),
                          ),
                          ElevatedButton(
                            onPressed: () => Navigator.pop(c, ctrl.text.trim()),
                            child: const Text('Save'),
                          ),
                        ],
                      ),
                    );
                    if (v != null && v.isNotEmpty) {
                      Map<String, dynamic> update = {'location': v};
                      final coords = _cityCoords(v);
                      if (coords != null) {
                        update['latitude'] = coords['lat'];
                        update['longitude'] = coords['lng'];
                      }
                      await FirebaseFirestore.instance
                          .collection('users')
                          .doc(user.uid)
                          .update(update);
                      myLocationText = v;
                      if (coords != null) {
                        myLat = coords['lat'];
                        myLng = coords['lng'];
                      }
                      setState(() {});
                    }
                  },
                ),
              ),
              const SizedBox(height: 10),
              Container(
                decoration: BoxDecoration(
                  color: card,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: ListTile(
                  title: Text('Phone', style: TextStyle(color: t)),
                  subtitle: Text(phone, style: TextStyle(color: sub)),
                ),
              ),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: card,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  children: [
                    ListTile(
                      leading: Icon(Icons.dark_mode, color: sub, size: 20),
                      title: Text(
                        'Dark Mode',
                        style: TextStyle(fontSize: 14, color: t),
                      ),
                      trailing: Switch(
                        value: isDark,
                        activeThumbColor: const Color(0xFF14B8A6),
                        onChanged: (v) => setState(() => appDarkMode = v),
                      ),
                    ),
                    Divider(
                      height: 1,
                      color: isDark
                          ? Colors.grey.shade800
                          : Colors.grey.shade200,
                    ),
                    ListTile(
                      leading: Icon(Icons.help_outline, color: sub, size: 20),
                      title: Text(
                        'Help & Support',
                        style: TextStyle(fontSize: 14, color: t),
                      ),
                      trailing: Icon(
                        Icons.arrow_forward_ios,
                        size: 12,
                        color: sub,
                      ),
                      onTap: () => showHelpSupport(card, t, sub),
                    ),
                    Divider(
                      height: 1,
                      color: isDark
                          ? Colors.grey.shade800
                          : Colors.grey.shade200,
                    ),
                    ListTile(
                      leading: Icon(Icons.info_outline, color: sub, size: 20),
                      title: Text(
                        'About SkillLink',
                        style: TextStyle(fontSize: 14, color: t),
                      ),
                      trailing: Icon(
                        Icons.arrow_forward_ios,
                        size: 12,
                        color: sub,
                      ),
                      onTap: () => showAboutSkillLink(card, t, sub),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () async {
                    await _loadMyLocation();
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Location refreshed')),
                      );
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF14B8A6),
                  ),
                  child: const Text(
                    'Refresh My Location',
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: _doLogout,
                  child: const Text(
                    'Logout',
                    style: TextStyle(color: Colors.red),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}