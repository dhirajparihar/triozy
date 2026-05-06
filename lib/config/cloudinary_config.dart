class CloudinaryConfig {
  static const String cloudName = String.fromEnvironment(
    'CLOUDINARY_CLOUD_NAME',
  );
  static const String uploadPreset = String.fromEnvironment(
    'CLOUDINARY_UPLOAD_PRESET',
  );
  static const String uploadFolder = String.fromEnvironment(
    'CLOUDINARY_UPLOAD_FOLDER',
    defaultValue: 'triozy',
  );

  static bool get isConfigured =>
      cloudName.trim().isNotEmpty && uploadPreset.trim().isNotEmpty;

  static List<String> get missingKeys {
    final keys = <String>[];
    if (cloudName.trim().isEmpty) {
      keys.add('CLOUDINARY_CLOUD_NAME');
    }
    if (uploadPreset.trim().isEmpty) {
      keys.add('CLOUDINARY_UPLOAD_PRESET');
    }
    return keys;
  }

  static String get setupMessage {
    final missing = missingKeys.join(', ');
    return 'Cloudinary is not configured. Missing: $missing. '
        'Pass them with --dart-define.';
  }

  static String exampleRunCommand({String device = ''}) {
    final target = device.trim().isEmpty ? '' : '-d ${device.trim()} ';
    return 'flutter run $target'
        '--dart-define=CLOUDINARY_CLOUD_NAME=your_cloud_name '
        '--dart-define=CLOUDINARY_UPLOAD_PRESET=your_unsigned_preset '
        '--dart-define=CLOUDINARY_UPLOAD_FOLDER=$uploadFolder';
  }
}
