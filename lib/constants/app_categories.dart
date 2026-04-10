/// Single source of truth for all service categories across the app.
/// Update this list to add/remove categories everywhere at once.
abstract final class AppCategories {
  static const List<String> all = [
    // Home Maintenance
    'Electrician',
    'Plumber',
    'AC Repair',
    'Solar Services',
    'Painter',
    'Carpenter',
    'Tile Worker',
    'Cleaning',
    'Cook',
    'Security',
    'Gardening',
    'Water Supplier',
    // Transport & Logistics
    'Car Taxi',
    'Auto',
    'Mechanic',
    'Personal Driver',
    // Personal & Lifestyle
    'Babysitter',
    'Tailor',
    'Home Salon',
    'Makeup Artist',
    'Tiffin Service',
    'Emergency Medical',
    'Rental Rooms',
    'Core Cutting',
    'Property',
    'RO Service',
  ];

  /// Categories shown as search hints on the home screen (most popular first).
  static const List<String> searchHints = [
    'Electrician',
    'Plumber',
    'AC Repair',
    'Solar Services',
    'Painter',
    'Carpenter',
    'Water Supplier',
    'Makeup Artist',
    'Tiffin Service',
    'Emergency Medical',
    'Cleaning',
    'Cook',
    'Security',
    'Gardening',
    'Mechanic',
    'Babysitter',
    'Tailor',
    'Home Salon',
    'Personal Driver',
    'RO Service',
    'Core Cutting',
    'Property',
    'Tile Worker',
  ];

  /// Categories list for request/worker forms — includes 'Other' as last option.
  static const List<String> withOther = [...all, 'Other'];
}
