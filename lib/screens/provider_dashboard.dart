import 'dart:io';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:geolocator/geolocator.dart';

import 'splash_screen.dart';

// FIX 1: Renamed from ProviderDashboard -> ProviderDashboardScreen
// So Splash + Login can find it. Nothing else changed.
class ProviderDashboard extends StatefulWidget {
  const ProviderDashboard({super.key});
  @override
  State<ProviderDashboard> createState() =>
      _ProviderDashboardState();
}

class _ProviderDashboardState extends State<ProviderDashboard> {
  int currentIndex = 0;
  String leadFilter = 'All';
  bool? appDarkMode;
  bool isAvailable = true;

  @override
  void initState() {
    super.initState();
    _loadAvailability();
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
    if (c.contains('johannesburg') || c.contains('joburg') || c.contains('jhb')) {
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

  Future<void> _saveMyLocation() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final uid = user.uid;
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .get();
      final data = doc.data() ?? {};
      final coordsFromText = _cityCoords((data['location'] ?? '').toString());
      if (coordsFromText != null) {
        final savedLat = (data['latitude'] as num?)?.toDouble();
        final savedLng = (data['longitude'] as num?)?.toDouble();
        bool needsFix = savedLat == null || savedLng == null;
        if (!needsFix) {
          final d = Geolocator.distanceBetween(
                savedLat,
                savedLng,
                coordsFromText['lat']!,
                coordsFromText['lng']!,
              ) /
              1000;
          if (d > 1.0) needsFix = true;
        }
        if (needsFix) {
          await FirebaseFirestore.instance.collection('users').doc(uid).update({
            'latitude': coordsFromText['lat'],
            'longitude': coordsFromText['lng'],
          });
          return;
        }
        return;
      }
      if (data['latitude'] != null && data['longitude'] != null) return;
      double? lat;
      double? lng;
      try {
        bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
        if (serviceEnabled) {
          LocationPermission perm = await Geolocator.checkPermission();
          if (perm == LocationPermission.denied) {
            perm = await Geolocator.requestPermission();
          }
          if (perm != LocationPermission.denied &&
              perm != LocationPermission.deniedForever) {
            Position pos = await Geolocator.getCurrentPosition(
              desiredAccuracy: LocationAccuracy.high,
            ).timeout(const Duration(seconds: 10));
            lat = pos.latitude;
            lng = pos.longitude;
          }
        }
      } catch (_) {}
      if (lat != null) {
        await FirebaseFirestore.instance.collection('users').doc(uid).update({
          'latitude': lat,
          'longitude': lng,
        });
      }
    } catch (_) {}
  }

  Future<void> _loadAvailability() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final uid = user.uid;
    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .get();
    if (doc.exists && mounted) {
      final data = doc.data() ?? {};
      setState(() => isAvailable = data['isAvailable'] != false);
      if (data['isProvider'] != true) {
        await FirebaseFirestore.instance.collection('users').doc(uid).update({
          'isProvider': true,
          'role': 'provider',
        });
      }
    }
    await _saveMyLocation();
  }

  Future<void> _toggleAvailability(bool val) async {
    setState(() => isAvailable = val);
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final uid = user.uid;
    Map<String, dynamic> update = {'isAvailable': val};
    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .get();
    final coords = _cityCoords((doc.data()?['location'] ?? '').toString());
    if (coords != null) {
      update['latitude'] = coords['lat'];
      update['longitude'] = coords['lng'];
    } else if (val == true) {
      try {
        LocationPermission perm = await Geolocator.checkPermission();
        if (perm == LocationPermission.denied) {
          perm = await Geolocator.requestPermission();
        }
        if (perm != LocationPermission.deniedForever &&
            perm != LocationPermission.denied) {
          Position pos = await Geolocator.getCurrentPosition(
            desiredAccuracy: LocationAccuracy.high,
          ).timeout(const Duration(seconds: 10));
          update['latitude'] = pos.latitude;
          update['longitude'] = pos.longitude;
        }
      } catch (_) {}
    }
    await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .update(update);
  }

  ImageProvider? getPhotoImage(String? url) {
    if (url == null || url.isEmpty) return null;
    if (url.startsWith('data:image')) {
      try {
        return MemoryImage(base64Decode(url.split(',').last));
      } catch (_) {
        return null;
      }
    }
    return NetworkImage(url);
  }

  Future<void> _uploadBase64Image(XFile image) async {
    try {
      final bytes = await File(image.path).readAsBytes();
      final base64Image = base64Encode(bytes);
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;
      await FirebaseFirestore.instance.collection('users').doc(user.uid).update(
        {'photoUrl': 'data:image/jpeg;base64,$base64Image'},
      );
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Profile photo updated')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Upload failed: $e')));
      }
    }
  }

  Future<void> _pickAndUploadPhoto() async {
    final picker = ImagePicker();
    final XFile? image = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 50,
    );
    if (image == null) return;
    await _uploadBase64Image(image);
  }

  Future<void> _showPhotoOptions() async {
    showModalBottomSheet(
      context: context,
      builder: (_) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('From Gallery'),
              onTap: () {
                Navigator.pop(context);
                _pickAndUploadPhoto();
              },
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('From Camera'),
              onTap: () async {
                Navigator.pop(context);
                final picker = ImagePicker();
                final XFile? image = await picker.pickImage(
                  source: ImageSource.camera,
                  imageQuality: 50,
                );
                if (image == null) return;
                await _uploadBase64Image(image);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> callNumber(String phone) async {
    final uri = Uri.parse('tel:$phone');
    if (await canLaunchUrl(uri)) await launchUrl(uri);
  }

  Future<void> whatsApp(String phone) async {
    final clean = phone.replaceAll(RegExp(r'[^0-9]'), '');
    final uri = Uri.parse('https://wa.me/$clean');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> updateStatus(String id, String s) async {
    await FirebaseFirestore.instance.collection('bookings').doc(id).update({
      'status': s,
    });
  }

  Future<void> editField(String k, String l, String cur) async {
    final ctrl = TextEditingController(text: cur == 'Not set' ? '' : cur);
    final v = await showDialog<String>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text('Edit $l'),
        content: TextField(
          controller: ctrl,
          maxLines: k == 'about' ? 4 : 1,
          keyboardType: k == 'pricePerHour'
              ? TextInputType.number
              : TextInputType.text,
          decoration: InputDecoration(
            hintText: l,
            prefixText: k == 'pricePerHour' ? 'R ' : null,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(c, ctrl.text.trim()),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF14B8A6),
            ),
            child: const Text('Save', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (v != null && v.isNotEmpty) {
      Map<String, dynamic> update = {k: v};
      if (k == 'location') {
        final coords = _cityCoords(v);
        if (coords != null) {
          update['latitude'] = coords['lat'];
          update['longitude'] = coords['lng'];
        }
      }
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .update(update);
    }
  }

  String timeAgo(Timestamp? ts) {
    if (ts == null) return '';
    final d = DateTime.now().difference(ts.toDate());
    if (d.inDays > 0) return '${d.inDays}d ago';
    if (d.inHours > 0) return '${d.inHours}h ago';
    if (d.inMinutes > 0) return '${d.inMinutes}m ago';
    return 'Just now';
  }

  void showHelpSupport(bool isDark, Color card, Color text, Color sub) {
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
              'Email: support@skilllink.co.za\nPhone: +27 61 234 5678\n\nHow it works:\n1. Client books you at YOUR price\n2. You Accept\n3. Mark as Completed when done\n4. Client rates you',
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

  void showAboutSkillLink(bool isDark, Color card, Color text, Color sub) {
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
              'SkillLink connects skilled providers with clients in South Africa.\n\n• You set your own price per hour\n• Clients find you by skill & location\n• Secure bookings & ratings\n\nVersion 1.0.0\nMade with ❤️ in South Africa',
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

  Map<String, dynamic> _safeUserData(DocumentSnapshot? snap) {
    if (snap == null || !snap.exists) return {};
    final raw = snap.data();
    if (raw is Map<String, dynamic>) return raw;
    return {};
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

    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .snapshots(),
      builder: (cUser, snapUser) {
        final userData = _safeUserData(snapUser.data);
        final double userAvg = ((userData['avgRating'] ?? 0) as num).toDouble();
        final int userReviewCount = ((userData['reviewCount'] ?? 0) as num)
            .toInt();

        return StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('bookings')
              .where('providerId', isEqualTo: user.uid)
              .snapshots(),
          builder: (c, snap) {
            final all = snap.data?.docs ?? [];
            final pend = all
                .where(
                  (d) =>
                      (d.data() as Map)['status']?.toString().toLowerCase() ==
                      'pending',
                )
                .toList();
            final rated = all
                .where(
                  (d) =>
                      (d.data() as Map)['status']?.toString().toLowerCase() ==
                      'rated',
                )
                .toList();
            double avg = userAvg;
            if (avg == 0 && rated.isNotEmpty) {
              double sum = 0;
              for (var d in rated) {
                sum += (((d.data() as Map)['rating'] ?? 0) as num).toDouble();
              }
              avg = sum / rated.length;
            }
            List<QueryDocumentSnapshot> filt = all;
            if (leadFilter != 'All') {
              filt = all
                  .where(
                    (d) =>
                        ((d.data() as Map)['status'] ?? '')
                            .toString()
                            .toLowerCase() ==
                        leadFilter.toLowerCase(),
                  )
                  .toList();
            }
            List<QueryDocumentSnapshot> recent = List.from(all);
            recent.sort((a, b) {
              final ta = (a.data() as Map)['createdAt'] as Timestamp?;
              final tb = (b.data() as Map)['createdAt'] as Timestamp?;
              if (ta == null || tb == null) return 0;
              return tb.compareTo(ta);
            });
            final recent3 = recent.take(5).toList();

            Widget homeTab = Container(
              color: bg,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            InkWell(
                              onTap: _doLogout,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 8,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.red.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: Colors.red.withValues(alpha: 0.3),
                                  ),
                                ),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.logout_rounded,
                                      color: Colors.red,
                                      size: 18,
                                    ),
                                    SizedBox(width: 5),
                                    Text(
                                      'Logout',
                                      style: TextStyle(
                                        color: Colors.red,
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Text(
                              'Dashboard',
                              style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                                color: t,
                              ),
                            ),
                          ],
                        ),
                        Row(
                          children: [
                            IconButton(
                              onPressed: () => setState(
                                () =>
                                    appDarkMode = !(appDarkMode ?? systemDark),
                              ),
                              icon: Icon(
                                isDark ? Icons.sunny : Icons.dark_mode,
                                color: t,
                              ),
                            ),
                            Stack(
                              children: [
                                IconButton(
                                  onPressed: () =>
                                      setState(() => currentIndex = 1),
                                  icon: Icon(
                                    Icons.notifications_none,
                                    color: t,
                                    size: 26,
                                  ),
                                ),
                                if (pend.isNotEmpty)
                                  Positioned(
                                    right: 6,
                                    top: 6,
                                    child: Container(
                                      padding: const EdgeInsets.all(4),
                                      decoration: const BoxDecoration(
                                        color: Colors.red,
                                        shape: BoxShape.circle,
                                      ),
                                      child: Text(
                                        '${pend.length}',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(width: 4),
                            StreamBuilder<DocumentSnapshot>(
                              stream: FirebaseFirestore.instance
                                  .collection('users')
                                  .doc(user.uid)
                                  .snapshots(),
                              builder: (c2, s) {
                                final photo =
                                    _safeUserData(s.data)['photoUrl']
                                        as String?;
                                if (photo != null && photo.isNotEmpty) {
                                  return CircleAvatar(
                                    radius: 18,
                                    backgroundImage: getPhotoImage(photo),
                                  );
                                }
                                return CircleAvatar(
                                  radius: 18,
                                  backgroundColor: const Color(0xFF14B8A6),
                                  child: Text(
                                    (user.email ?? 'S')[0].toUpperCase(),
                                    style: const TextStyle(color: Colors.white),
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: isAvailable
                            ? Colors.green.shade50
                            : Colors.orange.shade50,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isAvailable ? Colors.green : Colors.orange,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            isAvailable
                                ? Icons.check_circle
                                : Icons.pause_circle,
                            color: isAvailable ? Colors.green : Colors.orange,
                            size: 28,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  isAvailable
                                      ? 'You are AVAILABLE'
                                      : 'You are BUSY',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                    color: t,
                                  ),
                                ),
                                Text(
                                  isAvailable
                                      ? 'Clients can find and book you'
                                      : 'Clients will see you as BUSY',
                                  style: TextStyle(fontSize: 12, color: sub),
                                ),
                              ],
                            ),
                          ),
                          Switch(
                            value: isAvailable,
                            activeThumbColor: Colors.green,
                            onChanged: _toggleAvailability,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFF14B8A6),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Total Jobs',
                                  style: TextStyle(
                                    color: Colors.white70,
                                    fontSize: 12,
                                  ),
                                ),
                                Text(
                                  '${all.length} jobs',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 22,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Text(
                                  userReviewCount > 0
                                      ? '${avg.toStringAsFixed(1)} ★ average rating ($userReviewCount reviews)'
                                      : 'No reviews yet',
                                  style: const TextStyle(
                                    color: Colors.white70,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const Icon(
                            Icons.account_balance_wallet,
                            color: Colors.white,
                            size: 32,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Recent Clients',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            color: t,
                          ),
                        ),
                        if (all.isNotEmpty)
                          InkWell(
                            onTap: () => setState(() => currentIndex = 1),
                            child: const Text(
                              'View all >',
                              style: TextStyle(
                                fontSize: 12,
                                color: Color(0xFF14B8A6),
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    if (all.isEmpty)
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: card,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Center(
                          child: Text(
                            'No clients yet.',
                            style: TextStyle(color: sub, fontSize: 12),
                          ),
                        ),
                      )
                    else
                      Column(
                        children: recent3.map((doc) {
                          final d = doc.data() as Map<String, dynamic>;
                          final st = (d['status'] ?? 'pending')
                              .toString()
                              .toLowerCase();
                          Color sc = st == 'pending'
                              ? Colors.orange
                              : st == 'approved'
                              ? Colors.green
                              : st == 'completed'
                              ? Colors.blue
                              : st == 'rated'
                              ? Colors.purple
                              : Colors.red;
                          return Container(
                            margin: const EdgeInsets.only(bottom: 10),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: card,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              children: [
                                CircleAvatar(
                                  radius: 20,
                                  backgroundColor: const Color(0xFF14B8A6)
                                      .withValues(alpha: 0.15),
                                  child: Text(
                                    (d['clientName'] ?? 'C')
                                            .toString()
                                            .isNotEmpty
                                        ? (d['clientName'] as String)[0]
                                              .toUpperCase()
                                        : 'C',
                                    style: const TextStyle(
                                      color: Color(0xFF14B8A6),
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        d['clientName'] ?? 'Client',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: t,
                                        ),
                                      ),
                                      Text(
                                        '${d['jobTitle'] ?? d['skill'] ?? ''} • ${timeAgo(d['createdAt'] as Timestamp?)}',
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: sub,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: sc.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Text(
                                    st.toUpperCase(),
                                    style: TextStyle(
                                      fontSize: 9,
                                      fontWeight: FontWeight.bold,
                                      color: sc,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                      ),
                  ],
                ),
              ),
            );

            Widget leadsTab = Container(
              color: bg,
              child: Column(
                children: [
                  const SizedBox(height: 12),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    child: Row(
                      children:
                          [
                            'All',
                            'Pending',
                            'Approved',
                            'Completed',
                            'Rated',
                          ].map((f) {
                            bool sel = leadFilter == f;
                            int cnt = f == 'All'
                                ? all.length
                                : all
                                      .where(
                                        (d) =>
                                            ((d.data() as Map)['status'] ?? '')
                                                .toString()
                                                .toLowerCase() ==
                                            f.toLowerCase(),
                                      )
                                      .length;
                            return Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: FilterChip(
                                label: Text(
                                  '$f ($cnt)',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: sel ? Colors.white : t,
                                  ),
                                ),
                                selected: sel,
                                onSelected: (_) =>
                                    setState(() => leadFilter = f),
                                backgroundColor: card,
                                selectedColor: const Color(0xFF14B8A6),
                              ),
                            );
                          }).toList(),
                    ),
                  ),
                  Expanded(
                    child: filt.isEmpty
                        ? Center(
                            child: Text(
                              'No $leadFilter leads yet',
                              style: TextStyle(color: sub),
                            ),
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.all(14),
                            itemCount: filt.length,
                            itemBuilder: (c, i) {
                              final d = filt[i].data() as Map<String, dynamic>;
                              final st = (d['status'] ?? 'pending').toString();
                              return Container(
                                margin: const EdgeInsets.only(bottom: 10),
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: card,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          d['clientName'] ?? 'Client',
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            color: t,
                                          ),
                                        ),
                                        Text(
                                          timeAgo(d['createdAt'] as Timestamp?),
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: sub,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      '${d['jobTitle'] ?? ''} • ${d['skill'] ?? ''}',
                                      style: TextStyle(
                                        color: sub,
                                        fontSize: 12,
                                      ),
                                    ),
                                    Text(
                                      'R${d['price'] ?? ''} / hour',
                                      style: const TextStyle(
                                        color: Colors.green,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    if (st == 'pending')
                                      Row(
                                        children: [
                                          Expanded(
                                            child: OutlinedButton(
                                              onPressed: () => updateStatus(
                                                filt[i].id,
                                                'declined',
                                              ),
                                              child: const Text('Decline'),
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: ElevatedButton(
                                              onPressed: () => updateStatus(
                                                filt[i].id,
                                                'approved',
                                              ),
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor:
                                                    const Color(0xFF14B8A6),
                                              ),
                                              child: const Text('Accept',
                                                  style: TextStyle(
                                                      color: Colors.white)),
                                            ),
                                          ),
                                        ],
                                      ),
                                    if (st == 'approved')
                                      Row(
                                        children: [
                                          Expanded(
                                            child: ElevatedButton.icon(
                                              onPressed: () => callNumber(
                                                (d['clientPhone'] ?? '')
                                                    .toString(),
                                              ),
                                              icon: const Icon(
                                                Icons.phone,
                                                size: 14,
                                              ),
                                              label: const Text(
                                                'Call',
                                                style: TextStyle(fontSize: 12),
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: ElevatedButton.icon(
                                              onPressed: () => whatsApp(
                                                (d['clientPhone'] ?? '')
                                                    .toString(),
                                              ),
                                              icon: const Icon(
                                                Icons.chat,
                                                size: 14,
                                              ),
                                              label: const Text(
                                                'WhatsApp',
                                                style: TextStyle(fontSize: 12),
                                              ),
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor: Colors.green,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: ElevatedButton(
                                              onPressed: () => updateStatus(
                                                filt[i].id,
                                                'completed',
                                              ),
                                              child: const Text(
                                                'Done',
                                                style: TextStyle(fontSize: 12),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    if (st == 'completed')
                                      Text(
                                        'Waiting for client rating...',
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: sub,
                                          fontStyle: FontStyle.italic,
                                        ),
                                      ),
                                  ],
                                ),
                              );
                            },
                          ),
                  ),
                ],
              ),
            );

            Widget reviewsTab = Container(
              color: bg,
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('reviews')
                    .where('providerId', isEqualTo: user.uid)
                    .snapshots(),
                builder: (cRev, snapRev) {
                  if (!snapRev.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  var reviewDocs = snapRev.data!.docs;
                  reviewDocs.sort((a, b) {
                    final ta = (a.data() as Map)['createdAt'] as Timestamp?;
                    final tb = (b.data() as Map)['createdAt'] as Timestamp?;
                    if (ta == null || tb == null) return 0;
                    return tb.compareTo(ta);
                  });
                  double realAvg = 0;
                  if (reviewDocs.isNotEmpty) {
                    double sum = 0;
                    for (var d in reviewDocs) {
                      sum += (((d.data() as Map)['rating'] ?? 0) as num)
                          .toDouble();
                    }
                    realAvg = sum / reviewDocs.length;
                  }
                  int realCount = reviewDocs.length;
                  return SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(18),
                          decoration: BoxDecoration(
                            color: card,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Column(
                            children: [
                              Text(
                                realAvg.toStringAsFixed(1),
                                style: TextStyle(
                                  fontSize: 48,
                                  fontWeight: FontWeight.w800,
                                  color: t,
                                ),
                              ),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: List.generate(
                                  5,
                                  (i) => Icon(
                                    i < realAvg.round()
                                        ? Icons.star
                                        : Icons.star_border,
                                    color: Colors.amber,
                                    size: 20,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                realCount == 0
                                    ? 'No reviews yet'
                                    : '$realCount reviews • ${all.length} jobs done',
                                style: TextStyle(color: sub, fontSize: 12),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 18),
                        Text(
                          'All Reviews ($realCount)',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: t,
                          ),
                        ),
                        const SizedBox(height: 12),
                        if (reviewDocs.isEmpty)
                          Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: card,
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Center(
                              child: Text(
                                'No reviews yet. Complete a job and ask client to rate you.',
                                style: TextStyle(color: sub),
                              ),
                            ),
                          )
                        else
                          Column(
                            children: reviewDocs.map((doc) {
                              final d = doc.data() as Map<String, dynamic>;
                              final stars = ((d['rating'] ?? 0) as num).toInt();
                              final reviewText =
                                  (d['comment'] ??
                                          d['reviewText'] ??
                                          d['review'] ??
                                          '')
                                      .toString()
                                      .trim();
                              final clientId = (d['clientId'] ?? '').toString();
                              final savedClientName =
                                  (d['clientName'] as String?)?.trim();
                              final ts = d['createdAt'] as Timestamp?;
                              return FutureBuilder<DocumentSnapshot>(
                                future: clientId.isNotEmpty
                                    ? FirebaseFirestore.instance
                                          .collection('users')
                                          .doc(clientId)
                                          .get()
                                    : null,
                                builder: (ctx, snapClient) {
                                  String clientName = 'Client';
                                  if (savedClientName != null &&
                                      savedClientName.isNotEmpty &&
                                      savedClientName != userData['name']) {
                                    clientName = savedClientName;
                                  } else if (snapClient.hasData &&
                                      snapClient.data!.exists) {
                                    final cData = _safeUserData(
                                      snapClient.data,
                                    );
                                    clientName =
                                        (cData['name'] ??
                                                cData['firstName'] ??
                                                'Client')
                                            .toString();
                                  }
                                  if (clientName == (userData['name'] ?? '')) {
                                    clientName = 'Client';
                                  }
                                  return Container(
                                    margin: const EdgeInsets.only(bottom: 12),
                                    padding: const EdgeInsets.all(14),
                                    decoration: BoxDecoration(
                                      color: card,
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            CircleAvatar(
                                              radius: 18,
                                              backgroundColor: const Color(
                                                0xFF14B8A6,
                                              ).withValues(alpha: 0.15),
                                              child: Text(
                                                clientName.isNotEmpty
                                                    ? clientName[0]
                                                          .toUpperCase()
                                                    : 'C',
                                                style: const TextStyle(
                                                  color: Color(0xFF14B8A6),
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 10),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    clientName,
                                                    style: TextStyle(
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      color: t,
                                                    ),
                                                  ),
                                                  Text(
                                                    timeAgo(ts),
                                                    style: TextStyle(
                                                      fontSize: 11,
                                                      color: sub,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 8,
                                                    vertical: 4,
                                                  ),
                                              decoration: BoxDecoration(
                                                color: Colors.amber.withValues(
                                                  alpha: 0.2,
                                                ),
                                                borderRadius:
                                                    BorderRadius.circular(20),
                                              ),
                                              child: Row(
                                                children: [
                                                  const Icon(
                                                    Icons.star,
                                                    size: 12,
                                                    color: Colors.amber,
                                                  ),
                                                  Text(
                                                    ' $stars.0',
                                                    style: const TextStyle(
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      fontSize: 12,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 8),
                                        Row(
                                          children: List.generate(
                                            5,
                                            (i) => Icon(
                                              i < stars
                                                  ? Icons.star
                                                  : Icons.star_border,
                                              color: Colors.amber,
                                              size: 16,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        if (reviewText.isNotEmpty)
                                          Text(
                                            '"$reviewText"',
                                            style: TextStyle(
                                              fontSize: 13,
                                              height: 1.4,
                                              color: t,
                                            ),
                                          )
                                        else
                                          Text(
                                            'No written review — $stars stars only.',
                                            style: TextStyle(
                                              fontSize: 12,
                                              height: 1.4,
                                              color: sub,
                                              fontStyle: FontStyle.italic,
                                            ),
                                          ),
                                      ],
                                    ),
                                  );
                                },
                              );
                            }).toList(),
                          ),
                      ],
                    ),
                  );
                },
              ),
            );

            Widget profileTab = StreamBuilder<DocumentSnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('users')
                  .doc(user.uid)
                  .snapshots(),
              builder: (c, su) {
                final u = _safeUserData(su.data);
                final n = (u['name'] ?? 'Provider').toString();
                final e = (u['email'] ?? user.email ?? '').toString();
                final loc = (u['location'] ?? 'Not set').toString();
                final ph = (u['phone'] ?? 'Not set').toString();
                final sk = (u['mainSkill'] ?? 'Not set').toString();
                final ab = (u['about'] ?? 'Not set').toString();
                final photoUrl = u['photoUrl'] as String?;
                final pph = (u['pricePerHour'] ?? u['price'] ?? 'Not set')
                    .toString();
                return Container(
                  color: bg,
                  child: SingleChildScrollView(
                    child: Column(
                      children: [
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.fromLTRB(20, 50, 20, 25),
                          decoration: const BoxDecoration(
                            color: Color(0xFF14B8A6),
                            borderRadius: BorderRadius.only(
                              bottomLeft: Radius.circular(30),
                              bottomRight: Radius.circular(30),
                            ),
                          ),
                          child: Column(
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text(
                                    'Profile',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  InkWell(
                                    onTap: _doLogout,
                                    child: const Icon(
                                      Icons.logout,
                                      color: Colors.white70,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 18),
                              Stack(
                                children: [
                                  CircleAvatar(
                                    radius: 42,
                                    backgroundColor: Colors.white,
                                    backgroundImage:
                                        photoUrl != null && photoUrl.isNotEmpty
                                        ? getPhotoImage(photoUrl)
                                        : null,
                                    child: photoUrl == null || photoUrl.isEmpty
                                        ? Text(
                                            n.isNotEmpty
                                                ? n[0].toUpperCase()
                                                : 'P',
                                            style: const TextStyle(
                                              fontSize: 36,
                                              color: Color(0xFF14B8A6),
                                              fontWeight: FontWeight.bold,
                                            ),
                                          )
                                        : null,
                                  ),
                                  Positioned(
                                    bottom: 0,
                                    right: 0,
                                    child: InkWell(
                                      onTap: _showPhotoOptions,
                                      child: Container(
                                        padding: const EdgeInsets.all(6),
                                        decoration: const BoxDecoration(
                                          color: Colors.white,
                                          shape: BoxShape.circle,
                                        ),
                                        child: const Icon(
                                          Icons.camera_alt,
                                          size: 16,
                                          color: Color(0xFF14B8A6),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              Text(
                                n,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 17,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                e,
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 12,
                                ),
                              ),
                              const SizedBox(height: 10),
                              Text(
                                userReviewCount > 0
                                    ? '${avg.toStringAsFixed(1)} ($userReviewCount reviews)'
                                    : 'New provider • No reviews yet',
                                style: const TextStyle(color: Colors.white),
                              ),
                              const SizedBox(height: 10),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: isAvailable
                                      ? Colors.green
                                      : Colors.orange,
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  isAvailable ? '● AVAILABLE' : '● BUSY',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            children: [
                              Container(
                                decoration: BoxDecoration(
                                  color: card,
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: ListTile(
                                  title: Text(
                                    'Location',
                                    style: TextStyle(color: t),
                                  ),
                                  subtitle: Text(loc),
                                  trailing: Icon(Icons.edit, color: sub),
                                  onTap: () =>
                                      editField('location', 'Location', loc),
                                ),
                              ),
                              const SizedBox(height: 10),
                              Container(
                                decoration: BoxDecoration(
                                  color: card,
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: ListTile(
                                  title: Text(
                                    'Phone',
                                    style: TextStyle(color: t),
                                  ),
                                  subtitle: Text(ph),
                                  trailing: Icon(Icons.edit, color: sub),
                                  onTap: () => editField('phone', 'Phone', ph),
                                ),
                              ),
                              const SizedBox(height: 10),
                              Container(
                                decoration: BoxDecoration(
                                  color: card,
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: ListTile(
                                  title: Text(
                                    'Main Skill',
                                    style: TextStyle(color: t),
                                  ),
                                  subtitle: Text(sk),
                                  trailing: Icon(Icons.edit, color: sub),
                                  onTap: () =>
                                      editField('mainSkill', 'Main Skill', sk),
                                ),
                              ),
                              const SizedBox(height: 10),
                              Container(
                                decoration: BoxDecoration(
                                  color: card,
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: ListTile(
                                  title: Text(
                                    'About',
                                    style: TextStyle(color: t),
                                  ),
                                  subtitle: Text(ab),
                                  trailing: Icon(Icons.edit, color: sub),
                                  onTap: () => editField('about', 'About', ab),
                                ),
                              ),
                              const SizedBox(height: 10),
                              Container(
                                decoration: BoxDecoration(
                                  color: card,
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: ListTile(
                                  title: Text(
                                    'Price Per Hour',
                                    style: TextStyle(color: t),
                                  ),
                                  subtitle: Text('R $pph'),
                                  trailing: Icon(Icons.edit, color: sub),
                                  onTap: () => editField(
                                    'pricePerHour',
                                    'Price Per Hour',
                                    pph,
                                  ),
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
                                      leading: Icon(
                                        Icons.dark_mode,
                                        color: sub,
                                        size: 20,
                                      ),
                                      title: Text(
                                        'Dark Mode',
                                        style: TextStyle(
                                          fontSize: 14,
                                          color: t,
                                        ),
                                      ),
                                      trailing: Switch(
                                        value: isDark,
                                        activeThumbColor: const Color(0xFF14B8A6),
                                        onChanged: (v) =>
                                            setState(() => appDarkMode = v),
                                      ),
                                    ),
                                    Divider(
                                      height: 1,
                                      color: isDark
                                          ? Colors.grey.shade800
                                          : Colors.grey.shade200,
                                    ),
                                    ListTile(
                                      leading: Icon(
                                        Icons.help_outline,
                                        color: sub,
                                        size: 20,
                                      ),
                                      title: Text(
                                        'Help & Support',
                                        style: TextStyle(
                                          fontSize: 14,
                                          color: t,
                                        ),
                                      ),
                                      trailing: Icon(
                                        Icons.arrow_forward_ios,
                                        size: 12,
                                        color: sub,
                                      ),
                                      onTap: () =>
                                          showHelpSupport(isDark, card, t, sub),
                                    ),
                                    Divider(
                                      height: 1,
                                      color: isDark
                                          ? Colors.grey.shade800
                                          : Colors.grey.shade200,
                                    ),
                                    ListTile(
                                      leading: Icon(
                                        Icons.info_outline,
                                        color: sub,
                                        size: 20,
                                      ),
                                      title: Text(
                                        'About SkillLink',
                                        style: TextStyle(
                                          fontSize: 14,
                                          color: t,
                                        ),
                                      ),
                                      trailing: Icon(
                                        Icons.arrow_forward_ios,
                                        size: 12,
                                        color: sub,
                                      ),
                                      onTap: () => showAboutSkillLink(
                                        isDark,
                                        card,
                                        t,
                                        sub,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            );

            return Scaffold(
              backgroundColor: bg,
              body: currentIndex == 0
                  ? homeTab
                  : currentIndex == 1
                  ? leadsTab
                  : currentIndex == 2
                  ? reviewsTab
                  : profileTab,
              bottomNavigationBar: BottomNavigationBar(
                currentIndex: currentIndex,
                onTap: (i) => setState(() => currentIndex = i),
                selectedItemColor: const Color(0xFF14B8A6),
                backgroundColor: card,
                unselectedItemColor: sub,
                type: BottomNavigationBarType.fixed,
                items: const [
                  BottomNavigationBarItem(
                    icon: Icon(Icons.home),
                    label: 'Home',
                  ),
                  BottomNavigationBarItem(
                    icon: Icon(Icons.people),
                    label: 'Leads',
                  ),
                  BottomNavigationBarItem(
                    icon: Icon(Icons.star),
                    label: 'Reviews',
                  ),
                  BottomNavigationBarItem(
                    icon: Icon(Icons.person),
                    label: 'Profile',
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}