import 'package:flutter/foundation.dart';
import '../services/location_service.dart';

class LocationProvider extends ChangeNotifier {
  final LocationService _locationService;

  LocationProvider(this._locationService);

  double? _latitude;
  double? _longitude;
  String _address = 'Locating...';
  bool _isLoading = false;
  bool _hasError = false;
  String? _errorMessage;

  double? get latitude => _latitude;
  double? get longitude => _longitude;
  String get address => _address;
  bool get isLoading => _isLoading;
  bool get isAvailable => _latitude != null && _longitude != null;
  bool get hasError => _hasError;
  String? get errorMessage => _errorMessage;

  /// Fetch current GPS position and reverse-geocode the address.
  /// Safe to call multiple times — skips if already loaded or loading.
  Future<void> fetchLocation() async {
    if (_isLoading) return;
    if (isAvailable) return; // already have a location

    _isLoading = true;
    _hasError = false;
    _errorMessage = null;
    notifyListeners();

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
    notifyListeners();
    await fetchLocation();
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
