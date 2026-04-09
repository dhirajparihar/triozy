import 'package:flutter/foundation.dart';

class SessionService extends ChangeNotifier {
  bool _isGuest = false;

  bool get isGuest => _isGuest;

  void enterGuestMode() {
    if (_isGuest) return;
    _isGuest = true;
    notifyListeners();
  }

  void exitGuestMode() {
    if (!_isGuest) return;
    _isGuest = false;
    notifyListeners();
  }
}
