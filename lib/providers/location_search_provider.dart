import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../models/listing_model.dart';
import '../services/database_service.dart';


// === Location search state ===================================================

/// Manages location search suggestions and nearby feed results.
class LocationSearchProvider extends ChangeNotifier {
  List<Map<String, dynamic>> _results = [];
  /// Search suggestions from geocoding API.
  List<Map<String, dynamic>> get results => _results;

  bool _isLoading = false;
  /// True while loading search suggestions.
  bool get isLoading => _isLoading;

  bool _showFeed = false;
  /// True when showing the nearby feed instead of suggestions.
  bool get showFeed => _showFeed;

  bool _isLoadingFeed = false;
  /// True while loading the nearby feed.
  bool get isLoadingFeed => _isLoadingFeed;

  List<ListingModel> _feedListings = [];
  /// Listings shown when a location is selected.
  List<ListingModel> get feedListings => _feedListings;

  Timer? _debounce;

  /// Handles keystroke changes with a debounce.
  void onSearchChanged(String query) {
    if (_showFeed) {
      _showFeed = false;
      _feedListings = [];
      notifyListeners();
    }

    if (_debounce?.isActive ?? false) {
      _debounce!.cancel();
    }
    _debounce = Timer(const Duration(milliseconds: 500), () {
      _search(query);
    });
  }

  /// Runs a search against the geocoding API.
  Future<void> _search(String query) async {
    if (query.trim().isEmpty) {
      _results = [];
      _isLoading = false;
      notifyListeners();
      return;
    }

    _isLoading = true;
    notifyListeners();

    try {
      // Using OpenStreetMap Nominatim for free, key-less geocoding
      final url = Uri.parse(
          'https://nominatim.openstreetmap.org/search?q=${Uri.encodeComponent(query)}&format=json&addressdetails=1&limit=8');
      final response =
          await http.get(url, headers: {'User-Agent': 'TriozyApp/1.0'});

      if (response.statusCode == 200) {
        final List data = json.decode(response.body);
        _results = List<Map<String, dynamic>>.from(data);
      } else {
        _results = [];
      }
    } catch (e) {
      _results = [];
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Loads a nearby listing feed after a location selection.
  Future<void> fetchFeedForLocation(DatabaseService db, double lat, double lon, String locationName) async {
    _results = [];
    _showFeed = true;
    _isLoadingFeed = true;
    notifyListeners();

    try {
      // Get listings within 10km of the selected coordinates
      final listings = await db.getNearbyListings(
        lat: lat,
        lon: lon,
        radiusKm: 10.0,
        locationName: locationName,
      );
      _feedListings = listings;
    } catch (e) {
      _feedListings = [];
    } finally {
      _isLoadingFeed = false;
      notifyListeners();
    }
  }

  /// Clears search results and cancels any pending search.
  void clearSearch() {
    _results = [];
    _isLoading = false;
    _showFeed = false;
    _feedListings = [];
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    notifyListeners();
  }

  /// Resets the feed state without touching search text.
  void resetFeed() {
    _showFeed = false;
    _feedListings = [];
    notifyListeners();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }
}