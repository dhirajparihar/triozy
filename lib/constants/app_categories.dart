/// Single source of truth for all service categories across the app.
/// Update this list to add/remove categories everywhere at once.
abstract final class AppCategories {
  static const List<String> all = [
    // Home Maintenance
    'Electrician',
    'Plumber',
    'AC Repair',
    'Painter',
    'Carpenter',
    'Tile Worker',
    'Cleaning',
    'Maid',
    'Security',
    'Gardening',
    'Water Supplier',
    // Transport & Logistics
    'Ridemate',
    'Car Taxi',
    'Auto',
    'Mechanic',
    'Personal Driver',
    // Personal & Lifestyle
    'Babysitter',
    'Tailor',
    'Home Salon',
    'Makeup Artist',
    'Roommate',
    'Helpmate',
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
    'Painter',
    'Carpenter',
    'Water Supplier',
    'Makeup Artist',
    'Cleaning',
    'Maid',
    'Security',
    'Gardening',
    'Mechanic',
    'Babysitter',
    'Tailor',
    'Home Salon',
    'Personal Driver',
    'Ridemate',
    'Roommate',
    'RO Service',
    'Core Cutting',
    'Property',
    'Tile Worker',
  ];

  /// Categories list for request/worker forms — includes 'Other' as last option.
  static const List<String> withOther = [...all, 'Other'];
}
