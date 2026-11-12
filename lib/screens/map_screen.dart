import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import 'provider_profile_screen.dart';

class MapScreen extends StatefulWidget {
  final double? myLat;
  final double? myLng;
  const MapScreen({super.key, this.myLat, this.myLng});
  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  final MapController _controller = MapController();
  List<Marker> _markers = [];
  bool _loading = true;

  static const LatLng _defaultCenter = LatLng(-33.0153, 27.9116);

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

  Future<void> _loadProviders() async {
    final snap = await FirebaseFirestore.instance
        .collection('users')
        .where('isProvider', isEqualTo: true)
        .get();

    List<Marker> markers = [];

    if (widget.myLat != null && widget.myLng != null) {
      markers.add(
        Marker(
          point: LatLng(widget.myLat!, widget.myLng!),
          width: 40,
          height: 40,
          child: const Icon(Icons.location_on,
              color: Color(0xFF14B8A6), size: 40),
        ),
      );
    }

    for (var doc in snap.docs) {
      final d = doc.data();
      double? lat = (d['latitude'] as num?)?.toDouble();
      double? lng = (d['longitude'] as num?)?.toDouble();
      if (lat == null || lng == null) {
        final pc = _cityCoords((d['location'] ?? '').toString());
        if (pc != null) {
          lat = pc['lat'];
          lng = pc['lng'];
        }
      }
      if (lat == null || lng == null) continue;

      double? dist;
      if (widget.myLat != null && widget.myLng != null) {
        dist = Geolocator.distanceBetween(
              widget.myLat!,
              widget.myLng!,
              lat,
              lng,
            ) /
            1000;
      }

      final String providerName = (d['name'] ?? 'Provider').toString();
      final String skill =
          (d['mainSkill'] ?? d['skill'] ?? 'General').toString();

      markers.add(
        Marker(
          point: LatLng(lat, lng),
          width: 40,
          height: 40,
          child: GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ProviderProfileScreen(
                    providerId: doc.id,
                    distanceKm: dist,
                  ),
                ),
              );
            },
            child: const Icon(Icons.location_on,
                color: Colors.orange, size: 40),
          ),
        ),
      );

      // Keep name for tooltip - stored in marker via extra logic if needed
      // Tap still opens profile above
      debugPrint('$providerName - $skill - ${dist?.toStringAsFixed(1)} km');
    }

    if (mounted) {
      setState(() {
        _markers = markers;
        _loading = false;
      });
    }
  }

  @override
  void initState() {
    super.initState();
    _loadProviders();
  }

  @override
  Widget build(BuildContext context) {
    final center = widget.myLat != null && widget.myLng != null
        ? LatLng(widget.myLat!, widget.myLng!)
        : _defaultCenter;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black87),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Providers Near You',
          style: TextStyle(
            color: Color(0xFF14B8A6),
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _controller,
            options: MapOptions(
              initialCenter: center,
              initialZoom: 12,
            ),
            children: [
              TileLayer(
                urlTemplate:
                    'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.example.skill_link',
              ),
              MarkerLayer(markers: _markers),
            ],
          ),
          if (_loading)
            const Center(child: CircularProgressIndicator()),
          Positioned(
            bottom: 16,
            left: 16,
            right: 16,
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 10,
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 12,
                    height: 12,
                    decoration: const BoxDecoration(
                      color: Color(0xFF14B8A6),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  const Text('You', style: TextStyle(fontSize: 12)),
                  const SizedBox(width: 16),
                  Container(
                    width: 12,
                    height: 12,
                    decoration: const BoxDecoration(
                      color: Colors.orange,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  const Text('Providers', style: TextStyle(fontSize: 12)),
                  const SizedBox(width: 16),
                  const Text(
                    'Tap pin to view',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: const Color(0xFF14B8A6),
        onPressed: () {
          _controller.move(center, 13);
        },
        child: const Icon(Icons.my_location, color: Colors.white),
      ),
    );
  }
}