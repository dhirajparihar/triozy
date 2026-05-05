import 'dart:convert';

import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;

class LocationService {
  Future<Position> getCurrentPosition() async {
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

    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw Exception('Location services are disabled. Please enable GPS.');
    }

    return Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
    );
  }

  Future<String> getAddressFromCoordinates(double lat, double lng) async {
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
    } catch (_) {}

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
    } catch (_) {}

    return 'Unknown location';
  }

  Future<({double latitude, double longitude})> getCoordinatesFromAddress(
    String address,
  ) async {
    final query = address.trim();
    if (query.isEmpty) {
      throw Exception('Please enter a valid location.');
    }

    final attempts = <String>{
      query,
      query.replaceAll(',', ' '),
      query.replaceAll(RegExp(r'\s+'), ' '),
    };

    for (final attempt in attempts) {
      try {
        final results = await locationFromAddress(attempt.trim());
        if (results.isNotEmpty) {
          final first = results.first;
          return (latitude: first.latitude, longitude: first.longitude);
        }
      } catch (_) {}
    }

    try {
      final url = Uri.parse(
        'https://nominatim.openstreetmap.org/search?format=json&q=${Uri.encodeQueryComponent(query)}&limit=1&addressdetails=1',
      );
      final response = await http.get(url, headers: {
        'User-Agent': 'TriozyApp/1.0',
      });
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data is List && data.isNotEmpty) {
          final item = data.first as Map<String, dynamic>;
          final lat = double.tryParse('${item['lat'] ?? ''}');
          final lon = double.tryParse('${item['lon'] ?? ''}');
          if (lat != null && lon != null) {
            return (latitude: lat, longitude: lon);
          }
        }
      }
    } catch (_) {}

    throw Exception(
      'Could not find that location. Try city, area, state, or pincode.',
    );
  }
}
