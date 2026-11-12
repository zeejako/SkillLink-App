// CLIENT CODE - What client sees when they click a provider like Siya Jola
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:url_launcher/url_launcher.dart';

class ProviderProfileScreen extends StatefulWidget {
  final String providerId;
  final double? distanceKm;
  const ProviderProfileScreen({super.key, required this.providerId, this.distanceKm});

  @override
  State<ProviderProfileScreen> createState() => _ProviderProfileScreenState();
}

class _ProviderProfileScreenState extends State<ProviderProfileScreen> {
  String myName = '';
  String myPhone = '';

  @override
  void initState() {
    super.initState();
    _loadMe();
  }

  Future<void> _loadMe() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    final doc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
    final d = doc.data() ?? {};
    if (mounted) setState(() { myName = (d['name'] ?? '').toString(); myPhone = (d['phone'] ?? '').toString(); });
  }

  Future<void> _whatsapp(String phone) async {
    String clean = phone.replaceAll(RegExp(r'[^0-9]'), '');
    if (clean.isEmpty) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Provider has no WhatsApp number saved')));
      return;
    }
    if (clean.startsWith('0')) clean = '27${clean.substring(1)}';
    if (clean.length == 9) clean = '27$clean';
    final uri = Uri.parse('https://wa.me/$clean?text=Hi, I found you on SkillLink and want to book you.');
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not open WhatsApp for $clean')));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('WhatsApp failed: $e')));
    }
  }

  Future<void> _book(Map<String, dynamic> prov) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final uid = user.uid;
    await FirebaseFirestore.instance.collection('bookings').add({
      'clientId': uid,
      'clientName': myName.isNotEmpty ? myName : 'Client',
      'clientPhone': myPhone,
      'providerId': widget.providerId,
      'providerName': prov['name'] ?? 'Provider',
      'skill': prov['mainSkill'] ?? prov['skill'] ?? 'General',
      'jobTitle': prov['mainSkill'] ?? prov['skill'] ?? 'General',
      'price': prov['pricePerHour'] ?? prov['price'] ?? '350',
      'status': 'pending',
      'createdAt': FieldValue.serverTimestamp(),
    });
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Booking request sent! Provider will accept.')));
    Navigator.pop(context);
  }

  String timeAgo(Timestamp? ts) {
    if (ts == null) return '';
    final d = DateTime.now().difference(ts.toDate());
    if (d.inDays > 0) return '${d.inDays}d ago';
    if (d.inHours > 0) return '${d.inHours}h ago';
    if (d.inMinutes > 0) return '${d.inMinutes}m ago';
    return 'Just now';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F4),
      appBar: AppBar(backgroundColor: Colors.white, elevation: 0, leading: IconButton(icon: const Icon(Icons.arrow_back, color: Colors.black), onPressed: () => Navigator.pop(context)), title: const Text('Provider Profile', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold))),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance.collection('users').doc(widget.providerId).snapshots(),
        builder: (context, snap) {
          if (snap.hasError) return Center(child: Text('Error: ${snap.error}'));
          if (snap.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
          if (!snap.hasData || !snap.data!.exists) return const Center(child: Text('Provider not found.'));
          final raw = snap.data!.data();
          final d = (raw is Map<String, dynamic>) ? raw : <String, dynamic>{};
          final name = (d['name'] ?? 'Provider').toString();
          final skill = (d['mainSkill'] ?? d['skill'] ?? 'General').toString();
          final loc = (d['location'] ?? 'South Africa').toString();
          final about = (d['about'] ?? 'No description yet.').toString();
          final price = (d['pricePerHour'] ?? d['price'] ?? '350').toString();
          final avg = ((d['avgRating'] ?? 0) as num).toDouble();
          final count = ((d['reviewCount'] ?? 0) as num).toInt();
          final available = d['isAvailable'] != false;

          return SingleChildScrollView(
            child: Column(children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 25),
                decoration: const BoxDecoration(color: Color(0xFF14B8A6), borderRadius: BorderRadius.only(bottomLeft: Radius.circular(30), bottomRight: Radius.circular(30))),
                child: Column(children: [
                  CircleAvatar(radius: 42, backgroundColor: Colors.white, child: Text(name.isNotEmpty ? name[0].toUpperCase() : 'P', style: const TextStyle(fontSize: 32, color: Color(0xFF14B8A6), fontWeight: FontWeight.bold))),
                  const SizedBox(height: 10),
                  Text(name, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                  Text(skill, style: const TextStyle(color: Colors.white70, fontSize: 14)),
                  const SizedBox(height: 8),
                  Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    const Icon(Icons.star, color: Colors.amber, size: 16),
                    Text(' ${avg.toStringAsFixed(1)} ($count reviews)', style: const TextStyle(color: Colors.white)),
                    if (widget.distanceKm != null && widget.distanceKm! > 0.1) Text(' • ${widget.distanceKm!.toStringAsFixed(1)} km away', style: const TextStyle(color: Colors.white)),
                  ]),
                  const SizedBox(height: 8),
                  Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4), decoration: BoxDecoration(color: available ? Colors.green : Colors.orange, borderRadius: BorderRadius.circular(20)), child: Text(available ? '● AVAILABLE' : '● BUSY', style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold))),
                ]),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Container(padding: const EdgeInsets.all(14), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14)), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [const Icon(Icons.location_on, color: Color(0xFF14B8A6), size: 18), const SizedBox(width: 6), Expanded(child: Text(loc, style: const TextStyle(fontWeight: FontWeight.bold)))]),
                    const SizedBox(height: 8),
                    // NO $ SIGN - was Icons.attach_money, now wallet + rands
                    Row(children: [const Icon(Icons.wallet, color: Colors.green, size: 18), const SizedBox(width: 6), Text('$price rands / hour', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green))]),
                    const SizedBox(height: 12),
                    const Text('About', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                    const SizedBox(height: 4),
                    Text(about, style: const TextStyle(color: Colors.grey, height: 1.4)),
                  ])),
                  const SizedBox(height: 16),
                  // REVIEWS HEADER - shows if provider was rated
                  Row(children: [
                    const Text('Reviews', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    const SizedBox(width: 8),
                    Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3), decoration: BoxDecoration(color: Colors.amber.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(20)), child: Row(children: [const Icon(Icons.star, size: 13, color: Colors.amber), Text(' ${avg.toStringAsFixed(1)} • $count rated', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12))])),
                  ]),
                  const SizedBox(height: 10),
                  // REVIEWS LIST - shows FULL reviews: name + stars + rating + comment, not just count
                  StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance.collection('reviews').where('providerId', isEqualTo: widget.providerId).snapshots(),
                    builder: (c, rsnap) {
                      if (rsnap.hasError) return Container(padding: const EdgeInsets.all(14), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14)), child: Text('Error loading reviews: ${rsnap.error}'));
                      if (!rsnap.hasData) return const Center(child: CircularProgressIndicator());
                      final reviews = rsnap.data!.docs;
                      // Sort newest first
                      reviews.sort((a, b) {
                        final ta = (a.data() as Map)['createdAt'] as Timestamp?;
                        final tb = (b.data() as Map)['createdAt'] as Timestamp?;
                        if (ta == null || tb == null) return 0;
                        return tb.compareTo(ta);
                      });
                      if (reviews.isEmpty) return Container(padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14)), child: const Center(child: Text('No reviews yet. Be the first to rate this provider.', style: TextStyle(color: Colors.grey))));
                      return Column(children: reviews.map((doc) {
                        final r = doc.data() as Map<String, dynamic>;
                        final stars = ((r['rating'] ?? 0) as num).toInt();
                        String clientName = (r['clientName'] ?? '').toString().trim();
                        if (clientName.isEmpty || clientName == 'Client') clientName = 'Client';
                        // Comment can be saved as comment / reviewText / review
                        final comment = ((r['comment'] ?? r['reviewText'] ?? r['review'] ?? '')).toString().trim();
                        return Container(margin: const EdgeInsets.only(bottom: 10), padding: const EdgeInsets.all(14), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14)), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Row(children: [
                            CircleAvatar(radius: 18, backgroundColor: const Color(0xFF14B8A6).withValues(alpha: 0.15), child: Text(clientName.isNotEmpty ? clientName[0].toUpperCase() : 'C', style: const TextStyle(color: Color(0xFF14B8A6), fontWeight: FontWeight.bold))),
                            const SizedBox(width: 10),
                            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Text(clientName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                              Text(timeAgo(r['createdAt'] as Timestamp?), style: const TextStyle(fontSize: 11, color: Colors.grey)),
                            ])),
                            // RATING BADGE - shows the rating number clearly
                            Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), decoration: BoxDecoration(color: Colors.amber.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(20)), child: Row(children: [const Icon(Icons.star, size: 13, color: Colors.amber), Text(' $stars.0 / 5', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12))])),
                          ]),
                          const SizedBox(height: 8),
                          // STARS - visual rating
                          Row(children: List.generate(5, (i) => Icon(i < stars ? Icons.star : Icons.star_border, color: Colors.amber, size: 18))),
                          const SizedBox(height: 6),
                          Text('$stars out of 5 stars', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey)),
                          const SizedBox(height: 6),
                          // COMMENT - full comment, not just count
                          if (comment.isNotEmpty) Container(width: double.infinity, padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: const Color(0xFFF1F5F4), borderRadius: BorderRadius.circular(10)), child: Text('"$comment"', style: const TextStyle(fontSize: 13, height: 1.4))) else const Text('No written comment - stars only.', style: TextStyle(fontSize: 12, color: Colors.grey, fontStyle: FontStyle.italic)),
                        ]));
                      }).toList());
                    },
                  ),
                  const SizedBox(height: 80),
                ]),
              ),
            ]),
          );
        },
      ),
      // NO CALL - Only WhatsApp + Book Now
      bottomSheet: Container(
        padding: const EdgeInsets.all(14),
        color: Colors.white,
        child: Row(children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: () async {
                final doc = await FirebaseFirestore.instance.collection('users').doc(widget.providerId).get();
                final ph = (doc.data()?['phone'] ?? '').toString();
                if (ph.isNotEmpty) {
                  _whatsapp(ph);
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Provider has no phone number')));
                }
              },
              icon: const Icon(Icons.chat, size: 18),
              label: const Text('WhatsApp', maxLines: 1, overflow: TextOverflow.ellipsis),
              style: OutlinedButton.styleFrom(foregroundColor: Colors.green, side: const BorderSide(color: Colors.green), padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8)),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            flex: 2,
            child: ElevatedButton(
              onPressed: () async {
                final doc = await FirebaseFirestore.instance.collection('users').doc(widget.providerId).get();
                await _book(doc.data() ?? {});
              },
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF14B8A6), padding: const EdgeInsets.symmetric(vertical: 14)),
              child: const Text('Book Now', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ),
        ]),
      ),
    );
  }
}