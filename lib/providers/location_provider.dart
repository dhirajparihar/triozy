import 'package:flutter/foundation.dart';
import '../services/location_service.dart';


// === Location state ==========================================================

/// Manages device location state and user-entered overrides.
class LocationProvider extends ChangeNotifier {
  final LocationService _locationService;

  LocationProvider(this._locationService);

  double? _latitude;
  double? _longitude;
  String _address = 'Locating...';
  bool _isLoading = false;
  bool _hasError = false;
  String? _errorMessage;

  /// Current latitude (if available).
  double? get latitude => _latitude;
  /// Current longitude (if available).
  double? get longitude => _longitude;
  /// Resolved address text.
  String get address => _address;
  /// True while fetching or resolving location.
  bool get isLoading => _isLoading;
  /// True when a lat/lon has been resolved.
  bool get isAvailable => _latitude != null && _longitude != null;
  /// True when the last attempt failed.
  bool get hasError => _hasError;
  /// Error message for the last failure.
  String? get errorMessage => _errorMessage;

  Future<void>? _fetchFuture;

  /// Fetch current GPS position and reverse-geocode the address.
<<<<<<< Updated upstream
  /// Safe to call multiple times — waits for the ongoing fetch if already loading.
  Future<void> fetchLocation() {
    if (isAvailable) return Future.value();
    if (_fetchFuture != null) return _fetchFuture!;
=======
  /// Safe to call multiple times — skips if already loaded or loading.
  Future<void> fetchLocation() async {
    if (_fetchFuture != null) {
      return _fetchFuture;
    }
    if (isAvailable) return; // already have a location
>>>>>>> Stashed changes

    _isLoading = true;
    _hasError = false;
    _errorMessage = null;
    notifyListeners();

<<<<<<< Updated upstream
    _fetchFuture = _performFetch();
    return _fetchFuture!;
  }

  Future<void> _performFetch() async {
=======
    _fetchFuture = _doFetchLocation();
    try {
      await _fetchFuture;
    } finally {
      _fetchFuture = null;
    }
  }

  /// Force a fresh GPS location fetch, overriding any custom location.
  Future<void> forceRefetchLocation() async {
    _latitude = null;
    _longitude = null;
    _address = 'Locating...';
    notifyListeners();
    return fetchLocation();
  }

  Future<void> _doFetchLocation() async {
>>>>>>> Stashed changes
    try {
      final position = await _locationService.getCurrentPosition();
      _latitude = position.latitude;
      _longitude = position.longitude;

      final addr = await _locationService.getAddressFromCoordinates(
        _latitude!,
        _longitude!,
      );
      _address = addr;
    } catch (e) {
      _hasError = true;
      _errorMessage = e.toString();
      _address = 'Location unavailable';
    } finally {
      _isLoading = false;
      _fetchFuture = null;
      notifyListeners();
    }
  }

  /// Force-refresh the location even if one was already fetched.
  Future<void> refreshLocation() async {
    _latitude = null;
    _longitude = null;
    _address = 'Locating...';
    _hasError = false;
    _isLoading = false;
    _fetchFuture = null; // Clear any ongoing fetch so we start a new one
    notifyListeners();
    await fetchLocation();
  }

  /// Manually override location data without geocoding.
  void setLocationData(double lat, double lon, String addressLabel) {
    _latitude = lat;
    _longitude = lon;
    _address = addressLabel;
    _hasError = false;
    _errorMessage = null;
    notifyListeners();
  }

  /// Manually set location from user-entered address/city text.
  Future<void> setLocationFromAddress(String input) async {
    final query = input.trim();
    if (query.isEmpty) {
      throw Exception('Please enter a location.');
    }

    _isLoading = true;
    _hasError = false;
    _errorMessage = null;
    notifyListeners();

    try {
      final coordinates = await _locationService.getCoordinatesFromAddress(query);
      _latitude = coordinates.latitude;
      _longitude = coordinates.longitude;

      final resolved = await _locationService.getAddressFromCoordinates(
        _latitude!,
        _longitude!,
      );
      _address = resolved == 'Unknown location' ? query : resolved;
    } catch (e) {
      _hasError = true;
      _errorMessage = e.toString();
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
