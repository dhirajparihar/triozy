/// Utility class for form validation
class Validators {
  /// Validates Indian mobile phone numbers
  /// 
  /// Requirements:
  /// - Must be exactly 10 digits
  /// - Must start with 6, 7, 8, or 9 (Indian mobile number format)
  /// 
  /// Returns null if valid, or error message if invalid
  static String? validatePhoneNumber(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Phone number is required';
    }

    // Remove any spaces or special characters
    final digitsOnly = value.replaceAll(RegExp(r'[^\d]'), '');

    // Check if it's exactly 10 digits
    if (digitsOnly.length != 10) {
      return 'Please enter a valid mobile number';
    }

    // Check if it starts with 6, 7, 8, or 9 (Indian mobile format)
    final firstDigit = digitsOnly[0];
    if (!['6', '7', '8', '9'].contains(firstDigit)) {
      return 'Please enter a valid mobile number';
    }

    return null;
  }
}