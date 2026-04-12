import 'dart:math';
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geoflutterfire_plus/geoflutterfire_plus.dart';
import 'package:http/http.dart' as http;
import '../models/worker_model.dart';

enum WorkerProximityScope { radius, city, state, none }

class NearbyWorkersResult {
  final List<WorkerModel> workers;
  final WorkerProximityScope scope;
  final String? city;
  final String? state;

  const NearbyWorkersResult({
    required this.workers,
    required this.scope,
    this.city,
    this.state,
  });

  String get scopeLabel {
    switch (scope) {
      case WorkerProximityScope.radius:
        return 'Within 25 km';
      case WorkerProximityScope.city:
        return city == null || city!.isEmpty ? 'In your city' : 'In $city';
      case WorkerProximityScope.state:
        return state == null || state!.isEmpty ? 'In your state' : 'In $state';
      case WorkerProximityScope.none:
        return 'Top rated';
    }
  }
}

class LocationService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // ─── GPS Access ───

  /// Check and request location permissions, then return current position.
  Future<Position> getCurrentPosition() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw Exception('Location services are disabled. Please enable GPS.');
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        throw Exception('Location permission denied.');
      }
    }

    if (permission == LocationPermission.deniedForever) {
      throw Exception(
        'Location permissions are permanently denied. Please enable them in Settings.',
      );
    }

    return await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
      ),
    );
  }

  // ─── Reverse Geocoding ───

  /// Convert lat/lng to a human-readable address string.
  /// Uses the geocoding package first, falls back to Nominatim API for web.
  Future<String> getAddressFromCoordinates(double lat, double lng) async {
    // Try the geocoding package first (works on mobile)
    try {
      final placemarks = await placemarkFromCoordinates(lat, lng);
      if (placemarks.isNotEmpty) {
        final p = placemarks.first;
        final parts = <String>[
          if (p.subLocality?.isNotEmpty == true) p.subLocality!,
          if (p.locality?.isNotEmpty == true) p.locality!,
          if (p.administrativeArea?.isNotEmpty == true) p.administrativeArea!,
        ];
        if (parts.isNotEmpty) return parts.join(', ');
      }
    } catch (_) {
      // geocoding package failed (common on web), fall through to Nominatim
    }

    // Fallback: use free OpenStreetMap Nominatim API
    try {
      final url = Uri.parse(
        'https://nominatim.openstreetmap.org/reverse?format=json&lat=$lat&lon=$lng&zoom=14&addressdetails=1',
      );
      final response = await http.get(url, headers: {
        'User-Agent': 'TriozyApp/1.0',
      });
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final address = data['address'] as Map<String, dynamic>?;
        if (address != null) {
          final parts = <String>[
            if (address['suburb'] != null) address['suburb'],
            if (address['city'] != null)
              address['city']
            else if (address['town'] != null)
              address['town']
            else if (address['village'] != null)
              address['village'],
            if (address['state'] != null) address['state'],
          ];
          if (parts.isNotEmpty) return parts.join(', ');
        }
      }
    } catch (_) {
      // Nominatim also failed
    }

    return 'Unknown location';
  }

  /// Convert a user-entered address (city/area/pincode) to coordinates.
  Future<({double latitude, double longitude})> getCoordinatesFromAddress(
    String address,
  ) async {
    final query = address.trim();
    if (query.isEmpty) {
      throw Exception('Please enter a valid location.');
    }

    try {
      final results = await locationFromAddress(query);
      if (results.isEmpty) {
        throw Exception('No matching location found.');
      }
      final first = results.first;
      return (latitude: first.latitude, longitude: first.longitude);
    } catch (_) {
      throw Exception(
        'Could not find that location. Try city, area, or pincode.',
      );
    }
  }

  // ─── Save Worker Geo Data ───

  /// Save a GeoFirePoint to the worker's Firestore document.
  Future<void> saveWorkerLocation(String uid, double lat, double lng) async {
    final geoFirePoint = GeoFirePoint(GeoPoint(lat, lng));
    final snap = await _firestore
        .collection('workers')
        .where('uid', isEqualTo: uid)
        .limit(1)
        .get();
    if (snap.docs.isEmpty) return;
    await snap.docs.first.reference.set({
      'position': geoFirePoint.data,
      'latitude': lat,
      'longitude': lng,
    }, SetOptions(merge: true));
  }

  // ─── Nearby Workers Query ───

  /// Query workers within [radiusKm] of the given coordinates.
  /// Returns a list of WorkerModel objects sorted by distance.
  Future<List<WorkerModel>> getNearbyWorkers({
    required double latitude,
    required double longitude,
    double radiusKm = 25,
    String? serviceType,
  }) async {
    final center = GeoFirePoint(GeoPoint(latitude, longitude));

    // Normalize service type for filtering
    String? normalizedService;
    if (serviceType != null && serviceType.isNotEmpty && serviceType != 'All Services') {
      normalizedService = serviceType;
      if (normalizedService.endsWith('s') && !normalizedService.endsWith('ss')) {
        normalizedService = normalizedService.substring(0, normalizedService.length - 1);
      }
    }

    final collectionRef = _firestore.collection('workers');

    // Fetch documents within radius using geohash range
    final snapshots = await GeoCollectionReference<Map<String, dynamic>>(
      collectionRef,
    ).fetchWithin(
      center: center,
      radiusInKm: radiusKm,
      field: 'position',
      geopointFrom: (data) {
        final position = data['position'];
        if (position is Map<String, dynamic>) {
          final geopoint = position['geopoint'];
          if (geopoint is GeoPoint) return geopoint;
        }
        // Fallback
        final lat = data['latitude'] as double?;
        final lng = data['longitude'] as double?;
        if (lat != null && lng != null) return GeoPoint(lat, lng);
        return const GeoPoint(0, 0);
      },
    );

    // Convert to WorkerModel and calculate distance
    final workers = <WorkerModel>[];
    for (final doc in snapshots) {
      final data = doc.data();
      if (data == null) continue;
      final worker = WorkerModel.fromMap(data);

      // Apply service type and subscription filters client-side
      if (normalizedService != null) {
        if (!worker.skills.any((s) => s.toLowerCase() == normalizedService!.toLowerCase())) {
          continue;
        }
      }

      if (worker.hasGeoData) {
        worker.distanceKm = _calculateDistance(
          latitude, longitude,
          worker.latitude!, worker.longitude!,
        );
      }
      workers.add(worker);
    }

    // Sort by distance (nearest first)
    workers.sort((a, b) {
      final da = a.distanceKm ?? double.infinity;
      final db = b.distanceKm ?? double.infinity;
      return da.compareTo(db);
    });

    return workers;
  }

  /// Fallback strategy:
  /// 1) Within [radiusKm]
  /// 2) Same city (string match against worker.location)
  /// 3) Same state (string match against worker.location)
  Future<NearbyWorkersResult> getNearbyWorkersWithFallback({
    required double latitude,
    required double longitude,
    double radiusKm = 25,
    int limit = 5,
  }) async {
    final nearby = await getNearbyWorkers(
      latitude: latitude,
      longitude: longitude,
      radiusKm: radiusKm,
    );
    if (nearby.isNotEmpty) {
      return NearbyWorkersResult(
        workers: nearby.take(limit).toList(),
        scope: WorkerProximityScope.radius,
      );
    }

    String? city;
    String? state;
    try {
      final placemarks = await placemarkFromCoordinates(latitude, longitude);
      if (placemarks.isNotEmpty) {
        final p = placemarks.first;
        city = p.locality?.trim();
        if (city == null || city.isEmpty) {
          city = p.subAdministrativeArea?.trim();
        }
        state = p.administrativeArea?.trim();
      }
    } catch (_) {
      // Fall through to top-rated fallback.
    }

    final allSnap = await _firestore
        .collection('workers')
        .where('isAvailable', isEqualTo: true)
        .limit(250)
        .get();

    final allWorkers = allSnap.docs
        .map((doc) => WorkerModel.fromMap(doc.data()))
        .where((w) => w.location.trim().isNotEmpty)
        .toList();

    String normalized(String s) => s.toLowerCase().trim();

    if (city != null && city.isNotEmpty) {
      final cityValue = city;
      final cityMatch = allWorkers
          .where((w) => normalized(w.location).contains(normalized(cityValue)))
          .toList();
      cityMatch.sort((a, b) => b.rating.compareTo(a.rating));
      if (cityMatch.isNotEmpty) {
        return NearbyWorkersResult(
          workers: cityMatch.take(limit).toList(),
          scope: WorkerProximityScope.city,
          city: city,
          state: state,
        );
      }
    }

    if (state != null && state.isNotEmpty) {
      final stateValue = state;
      final stateMatch = allWorkers
          .where((w) => normalized(w.location).contains(normalized(stateValue)))
          .toList();
      stateMatch.sort((a, b) => b.rating.compareTo(a.rating));
      if (stateMatch.isNotEmpty) {
        return NearbyWorkersResult(
          workers: stateMatch.take(limit).toList(),
          scope: WorkerProximityScope.state,
          city: city,
          state: state,
        );
      }
    }

    allWorkers.sort((a, b) => b.rating.compareTo(a.rating));
    return NearbyWorkersResult(
      workers: allWorkers.take(limit).toList(),
      scope: WorkerProximityScope.none,
      city: city,
      state: state,
    );
  }

  /// Haversine formula to calculate distance between two points in km.
  double _calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    const double earthRadiusKm = 6371;
    final dLat = _degToRad(lat2 - lat1);
    final dLon = _degToRad(lon2 - lon1);
    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(_degToRad(lat1)) * cos(_degToRad(lat2)) *
        sin(dLon / 2) * sin(dLon / 2);
    final c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return earthRadiusKm * c;
  }

  double _degToRad(double deg) => deg * (pi / 180);
}
