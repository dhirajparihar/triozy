import 'package:flutter/foundation.dart';


// === Session state ===========================================================

/// Tracks lightweight session state that does not live in Firestore.
class SessionService extends ChangeNotifier {
  bool _isGuest = false;

  /// True when the user is browsing as a guest.
  bool get isGuest => _isGuest;

  /// Enables guest mode and notifies listeners once.
  void enterGuestMode() {
    if (_isGuest) return;
    _isGuest = true;
    notifyListeners();
  }

  /// Disables guest mode and notifies listeners once.
  void exitGuestMode() {
    if (!_isGuest) return;
    _isGuest = false;
    notifyListeners();
  }
}
