import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../models/listing_model.dart';
import '../providers/location_provider.dart';
import '../providers/location_search_provider.dart';
import '../services/cloudinary_service.dart';
import '../services/database_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';

/// Multi-step form for creating PG/hostel listings.
class PgListingFormScreen extends StatefulWidget {
  const PgListingFormScreen({super.key});

  @override
  State<PgListingFormScreen> createState() => _PgListingFormScreenState();
}

/// Manages draft state, validation, and publishing for PG listings.
class _PgListingFormScreenState extends State<PgListingFormScreen> {
  static const String _draftPrefix = 'pg_listing_draft_';
  static const int _maxImagesPerGroup = 4;
  static const int _maxImageBytes = 10 * 1024 * 1024;

  final PageController _pageController = PageController();
  final ImagePicker _picker = ImagePicker();

  final _propertyName = TextEditingController();
  final _ownerName = TextEditingController();
  final _contactNumber = TextEditingController();
  final _whatsAppNumber = TextEditingController();
  final _city = TextEditingController();
  final _area = TextEditingController();
  final _nearby = TextEditingController();
  final _landmark = TextEditingController();
  final _securityDeposit = TextEditingController();
  final _maintenance = TextEditingController();
  final _visitorRestrictions = TextEditingController();
  final _curfewTiming = TextEditingController();
  final _description = TextEditingController();
  final _bedsAvailable = TextEditingController();

  final List<XFile> _propertyImages = [];
  final List<XFile> _roomImages = [];
  final List<XFile> _washroomImages = [];
  XFile? _videoTour;
  Timer? _draftTimer;

  double? _latitude;
  double? _longitude;
  bool _detectingLocation = false;

  int _step = 0;
  bool _submitting = false;
  bool _immediateMoveIn = true;
  DateTime? _availableFrom;

  String _propertyType = 'Boys PG';
  String _preferredGender = 'Any';
  String _occupantType = 'Both';
  bool _electricityIncluded = true;
  bool _foodIncluded = true;
  bool _brokerage = false;
  bool _smokingAllowed = false;
  bool _drinkingAllowed = false;
  bool _petsAllowed = false;
  final Set<String> _amenities = {'WiFi', 'CCTV'};
  final List<_RoomConfiguration> _roomConfigurations = [];

  final List<String> _requiredErrors = [];

  static const List<String> _propertyTypes = [
    'Boys PG',
    'Girls PG',
    'Co-ed PG',
    'Hostel',
  ];
  static const List<String> _roomTypes = [
    'Single',
    'Double Sharing',
    'Triple Sharing',
    'Dormitory',
  ];
  static const List<String> _furnishedOptions = [
    'Fully Furnished',
    'Semi Furnished',
    'Unfurnished',
  ];
  static const List<String> _genderOptions = ['Male', 'Female', 'Any'];
  static const List<String> _occupantOptions = [
    'Student',
    'Working Professional',
    'Both',
  ];
  static const List<_AmenityItem> _amenityOptions = [
    _AmenityItem('WiFi', Icons.wifi_rounded),
    _AmenityItem('AC', Icons.ac_unit_rounded),
    _AmenityItem('Laundry', Icons.local_laundry_service_rounded),
    _AmenityItem('Food', Icons.restaurant_rounded),
    _AmenityItem('Parking', Icons.local_parking_rounded),
    _AmenityItem('CCTV', Icons.videocam_rounded),
    _AmenityItem('Water Cooler', Icons.water_drop_rounded),
    _AmenityItem('Geyser', Icons.hot_tub_rounded),
    _AmenityItem('Study Table', Icons.desk_rounded),
    _AmenityItem('Lift', Icons.elevator_rounded),
    _AmenityItem('Power Backup', Icons.battery_charging_full_rounded),
    _AmenityItem('Cleaning Service', Icons.cleaning_services_rounded),
  ];

  @override
  void initState() {
    super.initState();
    // Start with one expanded room config for faster entry.
    _roomConfigurations.add(_newRoomConfiguration(expanded: true));
    for (final controller in _textControllers) {
      controller.addListener(_scheduleDraftSave);
    }
    // Restore any saved draft before prefill runs.
    _loadDraft();
    _prefillFromProfile();
  }

  @override
  void dispose() {
    _draftTimer?.cancel();
    _pageController.dispose();
    for (final config in _roomConfigurations) {
      config.dispose();
    }
    for (final controller in _textControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  List<TextEditingController> get _textControllers => [
    _propertyName,
    _ownerName,
    _contactNumber,
    _whatsAppNumber,
    _city,
    _area,
    _nearby,
    _landmark,
    _securityDeposit,
    _maintenance,
    _visitorRestrictions,
    _curfewTiming,
    _description,
    _bedsAvailable,
  ];

  void _scheduleDraftSave() {
    // Debounce draft writes while the user is typing.
    _draftTimer?.cancel();
    _draftTimer = Timer(const Duration(milliseconds: 700), _saveDraft);
  }

  _RoomConfiguration _newRoomConfiguration({bool expanded = false}) {
    final config = _RoomConfiguration(expanded: expanded);
    config.rent.addListener(_scheduleDraftSave);
    config.capacity.addListener(_scheduleDraftSave);
    config.vacantBeds.addListener(_scheduleDraftSave);
    return config;
  }

  void _addRoomConfiguration() {
    // Collapse previous cards and insert a fresh, expanded one.
    setState(() {
      for (final config in _roomConfigurations) {
        config.expanded = false;
      }
      _roomConfigurations.add(_newRoomConfiguration(expanded: true));
    });
    _saveDraft();
  }

  void _deleteRoomConfiguration(int index) {
    // Require at least one configuration to publish a listing.
    if (_roomConfigurations.length == 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Add at least one room configuration')),
      );
      return;
    }
    setState(() {
      final removed = _roomConfigurations.removeAt(index);
      removed.dispose();
    });
    _saveDraft();
  }

  void _toggleRoomConfiguration(int index) {
    setState(() {
      _roomConfigurations[index].expanded =
          !_roomConfigurations[index].expanded;
    });
  }

  void _updateRoomConfiguration(
    int index,
    _RoomConfiguration Function(_RoomConfiguration current) update,
  ) {
    setState(() {
      update(_roomConfigurations[index]);
    });
    _saveDraft();
  }

  void _replaceRoomConfigurations(List<_RoomConfiguration> configs) {
    for (final config in _roomConfigurations) {
      config.dispose();
    }
    _roomConfigurations
      ..clear()
      ..addAll(
        configs.isEmpty ? [_newRoomConfiguration(expanded: true)] : configs,
      );
  }

  Future<void> _loadDraft() async {
    // Restore form data from shared preferences when available.
    final prefs = await SharedPreferences.getInstance();
    if (!(prefs.getBool('${_draftPrefix}exists') ?? false)) {
      return;
    }
    _propertyName.text = prefs.getString('${_draftPrefix}propertyName') ?? '';
    _ownerName.text = prefs.getString('${_draftPrefix}ownerName') ?? '';
    _contactNumber.text = prefs.getString('${_draftPrefix}contactNumber') ?? '';
    _whatsAppNumber.text = prefs.getString('${_draftPrefix}whatsApp') ?? '';
    _city.text = prefs.getString('${_draftPrefix}city') ?? '';
    _area.text = prefs.getString('${_draftPrefix}area') ?? '';
    _nearby.text = prefs.getString('${_draftPrefix}nearby') ?? '';
    _landmark.text = prefs.getString('${_draftPrefix}landmark') ?? '';
    _securityDeposit.text = prefs.getString('${_draftPrefix}deposit') ?? '';
    _maintenance.text = prefs.getString('${_draftPrefix}maintenance') ?? '';
    _visitorRestrictions.text =
        prefs.getString('${_draftPrefix}visitors') ?? '';
    _curfewTiming.text = prefs.getString('${_draftPrefix}curfew') ?? '';
    _description.text = prefs.getString('${_draftPrefix}description') ?? '';
    _bedsAvailable.text = prefs.getString('${_draftPrefix}bedsAvailable') ?? '';
    _latitude = prefs.getDouble('${_draftPrefix}lat');
    _longitude = prefs.getDouble('${_draftPrefix}lon');

    if (!mounted) return;
    final rawConfigs = prefs.getStringList('${_draftPrefix}roomConfigurations');
    if (rawConfigs != null && rawConfigs.isNotEmpty) {
      _replaceRoomConfigurations(
        rawConfigs.map((raw) {
          final data = jsonDecode(raw) as Map<String, dynamic>;
          return _newRoomConfiguration(
              expanded: data['expanded'] as bool? ?? false,
            )
            ..roomType = (data['roomType'] ?? 'Single').toString()
            ..rent.text = (data['rent'] ?? '').toString()
            ..capacity.text = (data['capacity'] ?? '').toString()
            ..vacantBeds.text = (data['vacantBeds'] ?? '').toString()
            ..attachedBathroom = data['attachedBathroom'] as bool? ?? true
            ..hasAc = data['hasAc'] as bool? ?? false
            ..furnished = (data['furnished'] ?? 'Fully Furnished').toString();
        }).toList(),
      );
    }
    setState(() {
      _propertyType =
          prefs.getString('${_draftPrefix}propertyType') ?? _propertyType;
      _preferredGender =
          prefs.getString('${_draftPrefix}preferredGender') ?? _preferredGender;
      _occupantType =
          prefs.getString('${_draftPrefix}occupantType') ?? _occupantType;
      _electricityIncluded =
          prefs.getBool('${_draftPrefix}electricityIncluded') ?? true;
      _foodIncluded = prefs.getBool('${_draftPrefix}foodIncluded') ?? true;
      _brokerage = prefs.getBool('${_draftPrefix}brokerage') ?? false;
      _smokingAllowed = prefs.getBool('${_draftPrefix}smoking') ?? false;
      _drinkingAllowed = prefs.getBool('${_draftPrefix}drinking') ?? false;
      _petsAllowed = prefs.getBool('${_draftPrefix}pets') ?? false;
      _immediateMoveIn = prefs.getBool('${_draftPrefix}immediate') ?? true;
      _amenities
        ..clear()
        ..addAll(
          prefs.getStringList('${_draftPrefix}amenities') ?? ['WiFi', 'CCTV'],
        );
    });
  }

  Future<void> _prefillFromProfile() async {
    // Pull name and phone from user profile when missing.
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return;
    }

    final data = await context.read<DatabaseService>().getUserData(user.uid);
    if (!mounted) {
      return;
    }

    final savedName = (data?['name'] ?? user.displayName ?? '')
        .toString()
        .trim();
    final savedPhone = (data?['phoneNumber'] ?? '').toString().trim();

    setState(() {
      if (_ownerName.text.trim().isEmpty && savedName.isNotEmpty) {
        _ownerName.text = savedName;
      }
      if (_contactNumber.text.trim().isEmpty && savedPhone.isNotEmpty) {
        _contactNumber.text = savedPhone;
      }
      if (_whatsAppNumber.text.trim().isEmpty && savedPhone.isNotEmpty) {
        _whatsAppNumber.text = savedPhone;
      }
    });
  }

  Future<void> _saveDraft() async {
    // Persist current form values for recovery.
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('${_draftPrefix}exists', true);
    await prefs.setString('${_draftPrefix}propertyName', _propertyName.text);
    await prefs.setString('${_draftPrefix}ownerName', _ownerName.text);
    await prefs.setString('${_draftPrefix}contactNumber', _contactNumber.text);
    await prefs.setString('${_draftPrefix}whatsApp', _whatsAppNumber.text);
    await prefs.setString('${_draftPrefix}city', _city.text);
    await prefs.setString('${_draftPrefix}area', _area.text);
    await prefs.setString('${_draftPrefix}nearby', _nearby.text);
    await prefs.setString('${_draftPrefix}landmark', _landmark.text);
    await prefs.setString('${_draftPrefix}deposit', _securityDeposit.text);
    await prefs.setString('${_draftPrefix}maintenance', _maintenance.text);
    await prefs.setString('${_draftPrefix}visitors', _visitorRestrictions.text);
    await prefs.setString('${_draftPrefix}curfew', _curfewTiming.text);
    await prefs.setString('${_draftPrefix}description', _description.text);
    await prefs.setString('${_draftPrefix}bedsAvailable', _bedsAvailable.text);
    if (_latitude != null) await prefs.setDouble('${_draftPrefix}lat', _latitude!);
    if (_longitude != null) await prefs.setDouble('${_draftPrefix}lon', _longitude!);
    await prefs.setString('${_draftPrefix}propertyType', _propertyType);
    await prefs.setString('${_draftPrefix}preferredGender', _preferredGender);
    await prefs.setString('${_draftPrefix}occupantType', _occupantType);
    await prefs.setStringList(
      '${_draftPrefix}roomConfigurations',
      _roomConfigurations.map((config) => jsonEncode(config.toMap())).toList(),
    );
    await prefs.setBool(
      '${_draftPrefix}electricityIncluded',
      _electricityIncluded,
    );
    await prefs.setBool('${_draftPrefix}foodIncluded', _foodIncluded);
    await prefs.setBool('${_draftPrefix}brokerage', _brokerage);
    await prefs.setBool('${_draftPrefix}smoking', _smokingAllowed);
    await prefs.setBool('${_draftPrefix}drinking', _drinkingAllowed);
    await prefs.setBool('${_draftPrefix}pets', _petsAllowed);
    await prefs.setBool('${_draftPrefix}immediate', _immediateMoveIn);
    await prefs.setStringList('${_draftPrefix}amenities', _amenities.toList());
  }

  Future<void> _clearDraft() async {
    // Remove all draft keys after a successful publish.
    final prefs = await SharedPreferences.getInstance();
    for (final key in prefs.getKeys().where(
      (key) => key.startsWith(_draftPrefix),
    )) {
      await prefs.remove(key);
    }
  }

  void _goToStep(int step) {
    // Clamp to available steps and animate the page view.
    final next = step.clamp(0, 3);
    setState(() => _step = next);
    _pageController.animateToPage(
      next,
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
    );
  }

  Future<void> _pickImages(List<XFile> target) async {
    // Enforce per-group limit and file size before adding.
    final messenger = ScaffoldMessenger.of(context);
    final remaining = _maxImagesPerGroup - target.length;
    if (remaining <= 0) {
      messenger.showSnackBar(
        const SnackBar(content: Text('You can upload up to 4 images here')),
      );
      return;
    }
    final images = await _picker.pickMultiImage(
      imageQuality: 82,
      limit: remaining,
    );
    if (images.isEmpty) return;

    final accepted = <XFile>[];
    var rejectedOversize = false;
    for (final image in images.take(remaining)) {
      final size = await image.length();
      if (size > _maxImageBytes) {
        rejectedOversize = true;
        continue;
      }
      accepted.add(image);
    }
    if (!mounted) return;
    setState(() => target.addAll(accepted));
    if (rejectedOversize) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Each image must be 10 MB or smaller')),
      );
    }
  }

  Future<void> _pickVideo() async {
    final video = await _picker.pickVideo(source: ImageSource.gallery);
    if (video == null || !mounted) return;
    setState(() => _videoTour = video);
    _saveDraft();
  }

  Future<List<String>> _uploadImages(String id) async {
    // Upload all selected images to the PG folder.
    final allImages = [..._propertyImages, ..._roomImages, ..._washroomImages];
    if (allImages.isEmpty) return [];

    final cloudinary = context.read<CloudinaryService>();
    final urls = <String>[];
    for (final image in allImages) {
      final bytes = await image.readAsBytes();
      urls.add(
        await cloudinary.uploadImage(
          bytes: Uint8List.fromList(bytes),
          fileName: image.name,
          folder: 'pg/$id',
        ),
      );
    }
    return urls;
  }

  bool _validateAll() {
    // Gather missing required fields to surface in a banner.
    final errors = <String>[];
    void need(TextEditingController controller, String label) {
      if (controller.text.trim().isEmpty) errors.add(label);
    }

    need(_propertyName, 'Property Name');
    need(_ownerName, 'Owner/Manager Name');
    need(_contactNumber, 'Contact Number');
    need(_city, 'City');
    need(_area, 'Area/Locality');
    need(_securityDeposit, 'Security Deposit');
    need(_bedsAvailable, 'Beds Currently Available');
    need(_description, 'Short Description');

    if (int.tryParse(_bedsAvailable.text.trim()) == null) {
      errors.add('Valid Beds Currently Available');
    }
    for (var index = 0; index < _roomConfigurations.length; index++) {
      final config = _roomConfigurations[index];
      final label = 'Room ${index + 1}';
      if (double.tryParse(config.rent.text.trim()) == null) {
        errors.add('$label rent');
      }
      if (int.tryParse(config.capacity.text.trim()) == null) {
        errors.add('$label capacity');
      }
      if (int.tryParse(config.vacantBeds.text.trim()) == null) {
        errors.add('$label vacant beds');
      }
    }

    setState(() {
      _requiredErrors
        ..clear()
        ..addAll(errors);
    });

    if (errors.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Please complete: ${errors.take(3).join(', ')}'),
        ),
      );
      return false;
    }
    return true;
  }

  Future<void> _publish() async {
    // Validate, build the listing payload, and publish.
    if (!_validateAll()) return;

    final user = FirebaseAuth.instance.currentUser;
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    if (user == null) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Sign in to publish PG listing')),
      );
      return;
    }

    setState(() => _submitting = true);
    try {
      final id = const Uuid().v4();
      final db = context.read<DatabaseService>();
      final userData = await db.getUserData(user.uid);
      final imageUrls = await _uploadImages(id);
      final ownerDisplayName = (userData?['name'] ?? user.displayName ?? '')
          .toString()
          .trim();
      final ownerPhotoUrl = (userData?['photoUrl'] ?? user.photoURL ?? '')
          .toString()
          .trim();
      final locationParts = [
        _area.text.trim(),
        _city.text.trim(),
        _landmark.text.trim(),
      ].where((part) => part.isNotEmpty).toList();
      final roomSummaries = _roomConfigurations
          .map((config) => config.summary)
          .where((summary) => summary.isNotEmpty)
          .toList();
      final minRent = _roomConfigurations
          .map((config) => double.tryParse(config.rent.text.trim()) ?? 0)
          .where((rent) => rent > 0)
          .fold<double?>(null, (lowest, rent) {
            if (lowest == null || rent < lowest) return rent;
            return lowest;
          });
      final totalCapacity = _roomConfigurations.fold<int>(0, (sum, config) {
        return sum + (int.tryParse(config.capacity.text.trim()) ?? 0);
      });
      final totalVacantBeds = _roomConfigurations.fold<int>(0, (sum, config) {
        return sum + (int.tryParse(config.vacantBeds.text.trim()) ?? 0);
      });
      final highlights = <String>[
        _propertyType,
        ..._roomConfigurations.map((config) => config.roomType).toSet(),
        _preferredGender,
        _occupantType,
        if (totalVacantBeds > 0) '$totalVacantBeds beds vacant',
        if (_foodIncluded) 'Food Included',
        if (_electricityIncluded) 'Electricity Included',
        ..._amenities,
      ].take(12).toList();
      final description = [
        _description.text.trim(),
        '',
        'Location: ${_area.text.trim()}, ${_city.text.trim()}',
        if (_nearby.text.trim().isNotEmpty) 'Nearby: ${_nearby.text.trim()}',
        'Room configurations:',
        ...roomSummaries.map((summary) => '- $summary'),
        if (totalCapacity > 0) 'Total capacity: $totalCapacity',
        if (totalVacantBeds > 0) 'Vacant beds: $totalVacantBeds',
        'Beds available: ${_bedsAvailable.text.trim()}',
        'Security deposit: Rs ${_securityDeposit.text.trim()}',
        if (_maintenance.text.trim().isNotEmpty)
          'Maintenance: Rs ${_maintenance.text.trim()}',
        'Contact: ${_contactNumber.text.trim()}',
        'Brokerage: ${_brokerage ? 'Yes' : 'No'}',
        'Smoking: ${_smokingAllowed ? 'Allowed' : 'Not allowed'}',
        'Drinking: ${_drinkingAllowed ? 'Allowed' : 'Not allowed'}',
        'Pets: ${_petsAllowed ? 'Allowed' : 'Not allowed'}',
        if (_visitorRestrictions.text.trim().isNotEmpty)
          'Visitor restrictions: ${_visitorRestrictions.text.trim()}',
        if (_curfewTiming.text.trim().isNotEmpty)
          'Curfew: ${_curfewTiming.text.trim()}',
        if (_whatsAppNumber.text.trim().isNotEmpty)
          'WhatsApp: ${_whatsAppNumber.text.trim()}',
        if (_videoTour != null) 'Video tour selected: ${_videoTour!.name}',
      ].join('\n');

      final listing = ListingModel(
        id: id,
        ownerId: user.uid,
        ownerName: _ownerName.text.trim().isEmpty
            ? (ownerDisplayName.isEmpty ? 'PG Owner' : ownerDisplayName)
            : _ownerName.text.trim(),
        ownerPhotoUrl: ownerPhotoUrl,
        title: _propertyName.text.trim(),
        description: description,
        location: locationParts.isEmpty
            ? _city.text.trim()
            : locationParts.join(', '),
        latitude: _latitude,
        longitude: _longitude,
        price: minRent ?? 0,
        type: ListingType.housing,
        propertyType: PropertyType.pg,
        imageUrls: imageUrls,
        highlights: highlights,
        genderPreference: _preferredGender,
        furnishing: _roomConfigurations
            .map((config) => config.furnished)
            .toSet()
            .join(', '),
        availableFrom: _immediateMoveIn
            ? 'Immediate move-in'
            : (_availableFrom == null
                  ? 'Available soon'
                  : '${_availableFrom!.day}/${_availableFrom!.month}/${_availableFrom!.year}'),
        purpose: ListingPurpose.offerProperty,
      );

      await db.createListing(listing);
      await _clearDraft();
      if (!mounted) return;
      messenger.showSnackBar(const SnackBar(content: Text('PG posted and sent to admin for approval. It will be published once approved.')));
      navigator.pop(true);
    } catch (error) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(content: Text('Could not publish: $error')),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _pickAvailableDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _availableFrom ?? now,
      firstDate: now,
      lastDate: now.add(const Duration(days: 365)),
    );
    if (picked == null || !mounted) return;
    setState(() {
      _availableFrom = picked;
      _immediateMoveIn = false;
    });
    _saveDraft();
  }

  Future<void> _detectCurrentLocation() async {
    // Use LocationProvider to resolve current address and coords.
    final locationProvider = context.read<LocationProvider>();
    final messenger = ScaffoldMessenger.of(context);

    setState(() => _detectingLocation = true);
    try {
      await locationProvider.refreshLocation();
      if (!mounted) return;

      final address = locationProvider.address.trim();
      final hasResolvedAddress = address.isNotEmpty &&
          address != 'Locating...' &&
          address != 'Location unavailable';
      
      if (!hasResolvedAddress) {
        messenger.showSnackBar(const SnackBar(content: Text('Could not detect your location')));
        return;
      }

      setState(() {
        _area.text = address; 
        _latitude = locationProvider.latitude;
        _longitude = locationProvider.longitude;
      });
      _saveDraft();
    } catch (error) {
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(content: Text('Could not detect location: $error')));
    } finally {
      if (mounted) setState(() => _detectingLocation = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isCompact = MediaQuery.sizeOf(context).width < 380;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.onSurface,
        elevation: 0,
        title: const Text('List PG or Hostel'),
        actions: [
          TextButton(
            onPressed: _saveDraft,
            child: Text(
              'Save draft',
              style: AppTheme.body(
                fontWeight: FontWeight.w800,
                color: AppColors.primary,
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          _ProgressHeader(step: _step),
          if (_requiredErrors.isNotEmpty)
            _ValidationBanner(errors: _requiredErrors),
          Expanded(
            child: PageView(
              controller: _pageController,
              physics: const NeverScrollableScrollPhysics(),
              onPageChanged: (value) => setState(() => _step = value),
              children: [
                _StepPage(
                  children: [
                    _SectionCard(
                      title: 'Property Basics',
                      icon: Icons.apartment_rounded,
                      children: [
                        _AppField(
                          controller: _propertyName,
                          label: 'Property Name',
                        ),
                        _SelectTile(
                          label: 'Property Type',
                          value: _propertyType,
                          icon: Icons.home_work_rounded,
                          onTap: () => _showPicker(
                            title: 'Property Type',
                            values: _propertyTypes,
                            selected: _propertyType,
                            onSelected: (value) =>
                                setState(() => _propertyType = value),
                          ),
                        ),
                        _AppField(
                          controller: _ownerName,
                          label: 'Owner/Manager Name',
                        ),
                        _AppField(
                          controller: _contactNumber,
                          label: 'Contact Number',
                          keyboardType: TextInputType.phone,
                        ),
                        _AppField(
                          controller: _whatsAppNumber,
                          label: 'WhatsApp Number (optional)',
                          keyboardType: TextInputType.phone,
                        ),
                      ],
                    ),
                    _SectionCard(
                      title: 'Location',
                      icon: Icons.location_on_rounded,
                      children: [
                        _LocationSearchField(
                          controller: _area,
                          isCompact: isCompact,
                          onSelected: (area, city, lat, lon) {
                            _area.text = area;
                            if (city.isNotEmpty) _city.text = city;
                            _latitude = lat;
                            _longitude = lon;
                            _saveDraft();
                          },
                        ),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: OutlinedButton.icon(
                            onPressed: _detectingLocation ? null : _detectCurrentLocation,
                            icon: _detectingLocation
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  )
                                : const Icon(Icons.my_location_rounded, size: 18),
                            label: Text(
                              _detectingLocation
                                  ? 'Detecting location'
                                  : 'Detect current location',
                            ),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.primary,
                              side: BorderSide(
                                color: AppColors.outlineVariant.withValues(alpha: 0.65),
                              ),
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                              textStyle: AppTheme.button(fontSize: 13, color: AppColors.primary),
                            ),
                          ),
                        ),
                        _AppField(controller: _city, label: 'City'),
                        _AppField(
                          controller: _nearby,
                          label: 'Nearby College/Company',
                        ),
                        _MapPreview(
                          label: _area.text.trim().isEmpty
                              ? 'Pin Location on Map'
                              : _area.text.trim(),
                        ),
                        _AppField(controller: _landmark, label: 'Landmark'),
                      ],
                    ),
                  ],
                ),
                _StepPage(
                  children: [
                    _SectionCard(
                      title: 'Room Configurations',
                      icon: Icons.bed_rounded,
                      children: [
                        Text(
                          'Add each room variant with its own rent, capacity, and facilities.',
                          style: AppTheme.body(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppColors.slate500,
                          ),
                        ),
                        ...List.generate(_roomConfigurations.length, (index) {
                          final config = _roomConfigurations[index];
                          return _RoomConfigurationCard(
                            config: config,
                            index: index,
                            onToggle: () => _toggleRoomConfiguration(index),
                            onDelete: () => _deleteRoomConfiguration(index),
                            onPickRoomType: () => _showPicker(
                              title: 'Room Type',
                              values: _roomTypes,
                              selected: config.roomType,
                              onSelected: (value) =>
                                  _updateRoomConfiguration(index, (current) {
                                    current.roomType = value;
                                    return current;
                                  }),
                            ),
                            onPickFurnished: () => _showPicker(
                              title: 'Furnished Status',
                              values: _furnishedOptions,
                              selected: config.furnished,
                              onSelected: (value) =>
                                  _updateRoomConfiguration(index, (current) {
                                    current.furnished = value;
                                    return current;
                                  }),
                            ),
                            onAttachedChanged: (value) =>
                                _updateRoomConfiguration(index, (current) {
                                  current.attachedBathroom = value;
                                  return current;
                                }),
                            onAcChanged: (value) =>
                                _updateRoomConfiguration(index, (current) {
                                  current.hasAc = value;
                                  return current;
                                }),
                          );
                        }),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: _addRoomConfiguration,
                            icon: const Icon(Icons.add_rounded),
                            label: const Text('Add Room Configuration'),
                          ),
                        ),
                      ],
                    ),
                    _SectionCard(
                      title: 'Pricing',
                      icon: Icons.currency_rupee_rounded,
                      children: [
                        _AppField(
                          controller: _securityDeposit,
                          label: 'Security Deposit',
                          prefixText: '₹ ',
                          keyboardType: TextInputType.number,
                        ),
                        _SwitchTile(
                          label: 'Electricity Included?',
                          value: _electricityIncluded,
                          onChanged: (value) =>
                              setState(() => _electricityIncluded = value),
                        ),
                        _SwitchTile(
                          label: 'Food Included?',
                          value: _foodIncluded,
                          onChanged: (value) =>
                              setState(() => _foodIncluded = value),
                        ),
                        _AppField(
                          controller: _maintenance,
                          label: 'Maintenance Charges',
                          prefixText: '₹ ',
                          keyboardType: TextInputType.number,
                        ),
                        _SwitchTile(
                          label: 'Brokerage',
                          value: _brokerage,
                          onChanged: (value) =>
                              setState(() => _brokerage = value),
                        ),
                      ],
                    ),
                  ],
                ),
                _StepPage(
                  children: [
                    _SectionCard(
                      title: 'Amenities',
                      icon: Icons.auto_awesome_rounded,
                      children: [
                        _AmenityGrid(
                          options: _amenityOptions,
                          selected: _amenities,
                          onTap: (value) => setState(() {
                            _amenities.contains(value)
                                ? _amenities.remove(value)
                                : _amenities.add(value);
                          }),
                        ),
                      ],
                    ),
                    _SectionCard(
                      title: 'Rules & Preferences',
                      icon: Icons.rule_rounded,
                      children: [
                        _SelectTile(
                          label: 'Preferred Gender',
                          value: _preferredGender,
                          icon: Icons.transgender_rounded,
                          onTap: () => _showPicker(
                            title: 'Preferred Gender',
                            values: _genderOptions,
                            selected: _preferredGender,
                            onSelected: (value) =>
                                setState(() => _preferredGender = value),
                          ),
                        ),
                        _SelectTile(
                          label: 'Student / Working Professional',
                          value: _occupantType,
                          icon: Icons.groups_rounded,
                          onTap: () => _showPicker(
                            title: 'Preferred Occupants',
                            values: _occupantOptions,
                            selected: _occupantType,
                            onSelected: (value) =>
                                setState(() => _occupantType = value),
                          ),
                        ),
                        _SwitchTile(
                          label: 'Smoking Allowed?',
                          value: _smokingAllowed,
                          onChanged: (value) =>
                              setState(() => _smokingAllowed = value),
                        ),
                        _SwitchTile(
                          label: 'Drinking Allowed?',
                          value: _drinkingAllowed,
                          onChanged: (value) =>
                              setState(() => _drinkingAllowed = value),
                        ),
                        _SwitchTile(
                          label: 'Pets Allowed?',
                          value: _petsAllowed,
                          onChanged: (value) =>
                              setState(() => _petsAllowed = value),
                        ),
                        _AppField(
                          controller: _visitorRestrictions,
                          label: 'Visitor Restrictions',
                        ),
                        _AppField(
                          controller: _curfewTiming,
                          label: 'Curfew Timing',
                        ),
                      ],
                    ),
                  ],
                ),
                _StepPage(
                  children: [
                    _SectionCard(
                      title: 'Photos & Media',
                      icon: Icons.photo_library_rounded,
                      children: [
                        _ImageUploadGroup(
                          title: 'Property Images',
                          images: _propertyImages,
                          onAdd: () => _pickImages(_propertyImages),
                          onRemove: (index) =>
                              setState(() => _propertyImages.removeAt(index)),
                        ),
                        _ImageUploadGroup(
                          title: 'Room Images',
                          images: _roomImages,
                          onAdd: () => _pickImages(_roomImages),
                          onRemove: (index) =>
                              setState(() => _roomImages.removeAt(index)),
                        ),
                        _ImageUploadGroup(
                          title: 'Washroom Images',
                          images: _washroomImages,
                          onAdd: () => _pickImages(_washroomImages),
                          onRemove: (index) =>
                              setState(() => _washroomImages.removeAt(index)),
                        ),
                        _VideoTile(
                          videoName: _videoTour?.name,
                          onTap: _pickVideo,
                          onRemove: () => setState(() => _videoTour = null),
                        ),
                      ],
                    ),
                    _SectionCard(
                      title: 'Description',
                      icon: Icons.description_rounded,
                      children: [
                        _AppField(
                          controller: _description,
                          label: 'Short Description',
                          hint:
                              'Girls PG near XYZ college with WiFi, food, and security.',
                          maxLines: 5,
                        ),
                      ],
                    ),
                    _SectionCard(
                      title: 'Availability',
                      icon: Icons.event_available_rounded,
                      children: [
                        _SwitchTile(
                          label: 'Immediate Move-in',
                          value: _immediateMoveIn,
                          onChanged: (value) =>
                              setState(() => _immediateMoveIn = value),
                        ),
                        _SelectTile(
                          label: 'Available From Date',
                          value: _immediateMoveIn
                              ? 'Immediate'
                              : (_availableFrom == null
                                    ? 'Select date'
                                    : '${_availableFrom!.day}/${_availableFrom!.month}/${_availableFrom!.year}'),
                          icon: Icons.calendar_today_rounded,
                          onTap: _pickAvailableDate,
                        ),
                        _AppField(
                          controller: _bedsAvailable,
                          label: 'Beds Currently Available',
                          keyboardType: TextInputType.number,
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Container(
          padding: EdgeInsets.fromLTRB(
            isCompact ? 12 : 16,
            10,
            isCompact ? 12 : 16,
            14,
          ),
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.06),
                blurRadius: 18,
                offset: const Offset(0, -8),
              ),
            ],
          ),
          child: Row(
            children: [
              if (_step > 0)
                IconButton.filledTonal(
                  onPressed: () => _goToStep(_step - 1),
                  icon: const Icon(Icons.arrow_back_rounded),
                  tooltip: 'Previous',
                ),
              if (_step > 0) SizedBox(width: isCompact ? 8 : 10),
              Expanded(
                child: ElevatedButton(
                  onPressed: _submitting
                      ? null
                      : (_step == 3 ? _publish : () => _goToStep(_step + 1)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.symmetric(
                      vertical: isCompact ? 14 : 16,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: _submitting
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Text(
                          _step == 3 ? 'Publish PG' : 'Continue',
                          style: AppTheme.body(
                            fontSize: isCompact ? 15 : 16,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showPicker({
    required String title,
    required List<String> values,
    required String selected,
    required ValueChanged<String> onSelected,
  }) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) {
        final isCompact = MediaQuery.sizeOf(context).width < 380;

        return SafeArea(
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              isCompact ? 16 : 20,
              8,
              isCompact ? 16 : 20,
              24,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppTheme.headline(fontSize: isCompact ? 19 : 22),
                ),
                SizedBox(height: isCompact ? 10 : 14),
                ...values.map(
                  (value) => ListTile(
                    dense: isCompact,
                    contentPadding: EdgeInsets.zero,
                    title: Text(value),
                    trailing: selected == value
                        ? const Icon(
                            Icons.check_rounded,
                            color: AppColors.primary,
                          )
                        : null,
                    onTap: () {
                      Navigator.pop(context);
                      onSelected(value);
                      _saveDraft();
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _RoomConfigurationCard extends StatelessWidget {
  /// Card for entering and expanding a single room configuration.
  final _RoomConfiguration config;
  final int index;
  final VoidCallback onToggle;
  final VoidCallback onDelete;
  final VoidCallback onPickRoomType;
  final VoidCallback onPickFurnished;
  final ValueChanged<bool> onAttachedChanged;
  final ValueChanged<bool> onAcChanged;

  const _RoomConfigurationCard({
    required this.config,
    required this.index,
    required this.onToggle,
    required this.onDelete,
    required this.onPickRoomType,
    required this.onPickFurnished,
    required this.onAttachedChanged,
    required this.onAcChanged,
  });

  @override
  Widget build(BuildContext context) {
    final isCompact = MediaQuery.sizeOf(context).width < 380;
    final vacant = config.vacantBeds.text.trim().isEmpty
        ? '0'
        : config.vacantBeds.text.trim();
    final rent = config.rent.text.trim().isEmpty
        ? 'Add rent'
        : '₹${config.rent.text.trim()}';

    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOutCubic,
      padding: EdgeInsets.all(isCompact ? 12 : 14),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppColors.outlineVariant.withValues(alpha: 0.24),
        ),
      ),
      child: Column(
        children: [
          InkWell(
            onTap: onToggle,
            borderRadius: BorderRadius.circular(16),
            child: Row(
              children: [
                Container(
                  width: isCompact ? 36 : 42,
                  height: isCompact ? 36 : 42,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(
                    Icons.king_bed_rounded,
                    color: AppColors.primary,
                  ),
                ),
                SizedBox(width: isCompact ? 8 : 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        config.roomType,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTheme.body(
                          fontSize: isCompact ? 14 : 15,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '$rent • $vacant vacant',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTheme.label(
                          fontWeight: FontWeight.w700,
                          color: AppColors.slate500,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: onDelete,
                  icon: const Icon(Icons.delete_outline_rounded),
                  color: AppColors.error,
                  tooltip: 'Delete configuration',
                ),
                Icon(
                  config.expanded
                      ? Icons.keyboard_arrow_up_rounded
                      : Icons.keyboard_arrow_down_rounded,
                ),
              ],
            ),
          ),
          AnimatedCrossFade(
            duration: const Duration(milliseconds: 180),
            crossFadeState: config.expanded
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            firstChild: const SizedBox(width: double.infinity),
            secondChild: Padding(
              padding: EdgeInsets.only(top: isCompact ? 10 : 14),
              child: Column(
                children: [
                  _SelectTile(
                    label: 'Room Type',
                    value: config.roomType,
                    icon: Icons.bed_rounded,
                    onTap: onPickRoomType,
                  ),
                  _AppField(
                    controller: config.rent,
                    label: 'Monthly Rent',
                    prefixText: '₹ ',
                    keyboardType: TextInputType.number,
                  ),
                  _AppField(
                    controller: config.capacity,
                    label: 'Total Capacity',
                    keyboardType: TextInputType.number,
                  ),
                  _AppField(
                    controller: config.vacantBeds,
                    label: 'Vacant Beds',
                    keyboardType: TextInputType.number,
                  ),
                  _SwitchTile(
                    label: 'Attached Bathroom',
                    value: config.attachedBathroom,
                    onChanged: onAttachedChanged,
                  ),
                  _SwitchTile(
                    label: config.hasAc ? 'AC Room' : 'Non-AC Room',
                    value: config.hasAc,
                    onChanged: onAcChanged,
                  ),
                  _SelectTile(
                    label: 'Furnished Status',
                    value: config.furnished,
                    icon: Icons.chair_rounded,
                    onTap: onPickFurnished,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RoomConfiguration {
  /// Mutable room configuration used while drafting the listing.
  String roomType = 'Single';
  String furnished = 'Fully Furnished';
  bool attachedBathroom = true;
  bool hasAc = false;
  bool expanded;
  final TextEditingController rent;
  final TextEditingController capacity;
  final TextEditingController vacantBeds;

  _RoomConfiguration({this.expanded = false})
    : rent = TextEditingController(),
      capacity = TextEditingController(),
      vacantBeds = TextEditingController();

  Map<String, dynamic> toMap() {
    return {
      'roomType': roomType,
      'rent': rent.text,
      'capacity': capacity.text,
      'vacantBeds': vacantBeds.text,
      'attachedBathroom': attachedBathroom,
      'hasAc': hasAc,
      'furnished': furnished,
      'expanded': expanded,
    };
  }

  String get summary {
    final rentLabel = rent.text.trim().isEmpty
        ? 'rent not set'
        : '₹${rent.text.trim()}';
    final capacityLabel = capacity.text.trim().isEmpty
        ? '0'
        : capacity.text.trim();
    final vacantLabel = vacantBeds.text.trim().isEmpty
        ? '0'
        : vacantBeds.text.trim();
    final acLabel = hasAc ? 'AC' : 'Non-AC';
    final bathroomLabel = attachedBathroom ? 'attached bath' : 'common bath';
    return '$roomType -> $rentLabel -> capacity $capacityLabel -> $vacantLabel vacant -> $acLabel, $furnished, $bathroomLabel';
  }

  void dispose() {
    rent.dispose();
    capacity.dispose();
    vacantBeds.dispose();
  }
}

class _ProgressHeader extends StatelessWidget {
  /// Top progress bar showing the current step.
  final int step;

  const _ProgressHeader({required this.step});

  @override
  Widget build(BuildContext context) {
    final isCompact = MediaQuery.sizeOf(context).width < 380;
    final labels = ['Basics', 'Rooms', 'Rules', 'Media'];
    return Container(
      padding: EdgeInsets.fromLTRB(
        isCompact ? 12 : 16,
        0,
        isCompact ? 12 : 16,
        isCompact ? 10 : 14,
      ),
      color: AppColors.background,
      child: Column(
        children: [
          LinearProgressIndicator(
            value: (step + 1) / labels.length,
            minHeight: isCompact ? 5 : 7,
            borderRadius: BorderRadius.circular(999),
            backgroundColor: AppColors.surfaceContainerHighest,
            color: AppColors.primary,
          ),
          SizedBox(height: isCompact ? 8 : 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(labels.length, (index) {
              final active = index == step;
              return Text(
                labels[index],
                style: AppTheme.label(
                  fontSize: isCompact ? 11 : 12,
                  fontWeight: active ? FontWeight.w900 : FontWeight.w600,
                  color: active ? AppColors.primary : AppColors.slate500,
                ),
              );
            }),
          ),
        ],
      ),
    );
  }
}

class _ValidationBanner extends StatelessWidget {
  /// Inline banner showing missing required fields.
  final List<String> errors;

  const _ValidationBanner({required this.errors});

  @override
  Widget build(BuildContext context) {
    final isCompact = MediaQuery.sizeOf(context).width < 380;

    return Container(
      margin: EdgeInsets.fromLTRB(isCompact ? 12 : 16, 0, isCompact ? 12 : 16, 10),
      padding: EdgeInsets.all(isCompact ? 10 : 12),
      decoration: BoxDecoration(
        color: AppColors.errorContainer,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.error_outline_rounded, color: AppColors.error),
          SizedBox(width: isCompact ? 8 : 10),
          Expanded(
            child: Text(
              'Missing: ${errors.take(4).join(', ')}',
              style: AppTheme.body(
                fontWeight: FontWeight.w700,
                color: AppColors.error,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StepPage extends StatelessWidget {
  /// Wrapper that applies consistent padding for each step.
  final List<Widget> children;

  const _StepPage({required this.children});

  @override
  Widget build(BuildContext context) {
    final isCompact = MediaQuery.sizeOf(context).width < 380;

    return ListView(
      padding: EdgeInsets.fromLTRB(
        isCompact ? 12 : 16,
        4,
        isCompact ? 12 : 16,
        24,
      ),
      children: [
        ...children.expand((child) sync* {
          yield child;
          yield SizedBox(height: isCompact ? 12 : 16);
        }),
      ],
    );
  }
}

class _SectionCard extends StatelessWidget {
  /// Card container for grouping fields within a step.
  final String title;
  final IconData icon;
  final List<Widget> children;

  const _SectionCard({
    required this.title,
    required this.icon,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    final isCompact = MediaQuery.sizeOf(context).width < 380;

    return Container(
      padding: EdgeInsets.all(isCompact ? 12 : 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(isCompact ? 18 : 24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: isCompact ? 34 : 40,
                height: isCompact ? 34 : 40,
                decoration: BoxDecoration(
                  color: AppColors.blue50,
                  borderRadius: BorderRadius.circular(isCompact ? 12 : 14),
                ),
                child: Icon(
                  icon,
                  color: AppColors.primary,
                  size: isCompact ? 18 : 21,
                ),
              ),
              SizedBox(width: isCompact ? 8 : 12),
              Expanded(
                child: Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppTheme.headline(fontSize: isCompact ? 17 : 19),
                ),
              ),
            ],
          ),
          SizedBox(height: isCompact ? 12 : 16),
          ...children.expand((child) sync* {
            yield child;
            yield SizedBox(height: isCompact ? 10 : 12);
          }),
        ],
      ),
    );
  }
}

class _AppField extends StatelessWidget {
  /// Text field wrapper with label, hint, and optional prefix.
  final TextEditingController controller;
  final String label;
  final String? hint;
  final String? prefixText;
  final int maxLines;
  final TextInputType? keyboardType;

  const _AppField({
    required this.controller,
    required this.label,
    this.hint,
    this.prefixText,
    this.maxLines = 1,
    this.keyboardType,
  });

  @override
  Widget build(BuildContext context) {
    final isCompact = MediaQuery.sizeOf(context).width < 380;

    return TextField(
      controller: controller,
      maxLines: maxLines,
      keyboardType: keyboardType,
      style: AppTheme.body(fontSize: isCompact ? 14 : 15),
      decoration: InputDecoration(
        isDense: true,
        labelText: label,
        hintText: hint,
        prefixText: prefixText,
        filled: true,
        fillColor: AppColors.surfaceContainerLow,
        contentPadding: EdgeInsets.symmetric(
          horizontal: isCompact ? 12 : 14,
          vertical: isCompact ? 12 : 14,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(isCompact ? 12 : 16),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }
}

class _SelectTile extends StatelessWidget {
  /// Row that opens a bottom-sheet picker.
  final String label;
  final String value;
  final IconData icon;
  final VoidCallback onTap;

  const _SelectTile({
    required this.label,
    required this.value,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isCompact = MediaQuery.sizeOf(context).width < 380;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: EdgeInsets.all(isCompact ? 12 : 14),
        decoration: BoxDecoration(
          color: AppColors.surfaceContainerLow,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Icon(icon, color: AppColors.primary, size: isCompact ? 20 : 24),
            SizedBox(width: isCompact ? 8 : 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: AppTheme.label()),
                  const SizedBox(height: 4),
                  Text(
                    value,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppTheme.body(
                      fontSize: isCompact ? 14 : 15,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.keyboard_arrow_down_rounded),
          ],
        ),
      ),
    );
  }
}

class _SwitchTile extends StatelessWidget {
  /// Toggle row used for boolean settings.
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _SwitchTile({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final isCompact = MediaQuery.sizeOf(context).width < 380;

    return SwitchListTile.adaptive(
      value: value,
      onChanged: onChanged,
      dense: isCompact,
      contentPadding: EdgeInsets.symmetric(horizontal: isCompact ? 0 : 4),
      title: Text(
        label,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: AppTheme.body(
          fontSize: isCompact ? 14 : 15,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _MapPreview extends StatelessWidget {
  /// Simple map preview tile displaying the selected area label.
  final String label;

  const _MapPreview({required this.label});

  @override
  Widget build(BuildContext context) {
    final isCompact = MediaQuery.sizeOf(context).width < 380;

    return Container(
      height: isCompact ? 92 : 112,
      decoration: BoxDecoration(
        color: AppColors.blue50,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.map_rounded, color: AppColors.primary),
            SizedBox(height: isCompact ? 6 : 8),
            Text(
              label,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: AppTheme.body(
                fontSize: isCompact ? 13 : 14,
                fontWeight: FontWeight.w800,
                color: AppColors.primary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AmenityGrid extends StatelessWidget {
  /// Grid of amenity icons with selectable state.
  final List<_AmenityItem> options;
  final Set<String> selected;
  final ValueChanged<String> onTap;

  const _AmenityGrid({
    required this.options,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isCompact = constraints.maxWidth < 360;
        final columns = constraints.maxWidth < 300 ? 2 : 3;

        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: options.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            mainAxisSpacing: isCompact ? 8 : 10,
            crossAxisSpacing: isCompact ? 8 : 10,
            childAspectRatio: columns == 2 ? 1.25 : 0.95,
          ),
          itemBuilder: (context, index) {
            final option = options[index];
            final active = selected.contains(option.label);
            return InkWell(
              onTap: () => onTap(option.label),
              borderRadius: BorderRadius.circular(isCompact ? 14 : 18),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: EdgeInsets.all(isCompact ? 6 : 8),
                decoration: BoxDecoration(
                  color: active
                      ? AppColors.blue50
                      : AppColors.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(isCompact ? 14 : 18),
                  border: Border.all(
                    color: active ? AppColors.primary : Colors.transparent,
                  ),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      option.icon,
                      size: isCompact ? 20 : 24,
                      color: active ? AppColors.primary : AppColors.slate500,
                    ),
                    SizedBox(height: isCompact ? 5 : 8),
                    Text(
                      option.label,
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppTheme.label(
                        fontSize: isCompact ? 11 : 12,
                        color: active
                            ? AppColors.primary
                            : AppColors.onSurfaceVariant,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class _ImageUploadGroup extends StatelessWidget {
  /// Upload group for a specific image category.
  final String title;
  final List<XFile> images;
  final VoidCallback onAdd;
  final ValueChanged<int> onRemove;

  const _ImageUploadGroup({
    required this.title,
    required this.images,
    required this.onAdd,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final isCompact = MediaQuery.sizeOf(context).width < 380;
    final emptyHeight = isCompact ? 72.0 : 88.0;
    final previewSize = isCompact ? 76.0 : 92.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTheme.body(
                  fontSize: isCompact ? 14 : 15,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            TextButton.icon(
              onPressed: onAdd,
              icon: Icon(
                Icons.add_photo_alternate_rounded,
                size: isCompact ? 18 : 20,
              ),
              label: const Text('Upload'),
            ),
          ],
        ),
        if (images.isEmpty)
          Container(
            height: emptyHeight,
            width: double.infinity,
            decoration: BoxDecoration(
              color: AppColors.surfaceContainerLow,
              borderRadius: BorderRadius.circular(18),
            ),
            child: const Center(child: Icon(Icons.image_outlined)),
          )
        else
          SizedBox(
            height: previewSize,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: images.length,
              separatorBuilder: (_, _) => SizedBox(width: isCompact ? 8 : 10),
              itemBuilder: (context, index) {
                return _ImagePreviewTile(
                  image: images[index],
                  size: previewSize,
                  onRemove: () => onRemove(index),
                );
              },
            ),
          ),
      ],
    );
  }
}

class _ImagePreviewTile extends StatelessWidget {
  /// Thumbnail preview for a selected image.
  final XFile image;
  final double size;
  final VoidCallback onRemove;

  const _ImagePreviewTile({
    required this.image,
    required this.size,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: SizedBox(
        width: size,
        height: size,
        child: Stack(
          fit: StackFit.expand,
          children: [
            FutureBuilder<Uint8List>(
              future: image.readAsBytes(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return Container(color: AppColors.surfaceContainerHigh);
                }
                return Image.memory(snapshot.data!, fit: BoxFit.cover);
              },
            ),
            Positioned(
              top: 5,
              right: 5,
              child: GestureDetector(
                onTap: onRemove,
                child: Container(
                  width: 24,
                  height: 24,
                  decoration: const BoxDecoration(
                    color: Colors.black54,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.close_rounded,
                    color: Colors.white,
                    size: 16,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _VideoTile extends StatelessWidget {
  /// Tile for selecting and removing a video tour.
  final String? videoName;
  final VoidCallback onTap;
  final VoidCallback onRemove;

  const _VideoTile({
    required this.videoName,
    required this.onTap,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final hasVideo = videoName != null;
    final isCompact = MediaQuery.sizeOf(context).width < 380;

    return Container(
      padding: EdgeInsets.all(isCompact ? 12 : 14),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          Icon(
            Icons.video_library_rounded,
            color: AppColors.primary,
            size: isCompact ? 20 : 24,
          ),
          SizedBox(width: isCompact ? 8 : 12),
          Expanded(
            child: Text(
              hasVideo ? videoName! : 'Upload Video Tour (optional)',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTheme.body(
                fontSize: isCompact ? 13 : 14,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          if (hasVideo)
            IconButton(
              onPressed: onRemove,
              icon: const Icon(Icons.close_rounded),
            )
          else
            TextButton(onPressed: onTap, child: const Text('Choose')),
        ],
      ),
    );
  }
}

class _AmenityItem {
  /// Icon + label tuple for amenity selection.
  final String label;
  final IconData icon;

  const _AmenityItem(this.label, this.icon);
}

/// Location input with inline search suggestions overlay.
class _LocationSearchField extends StatefulWidget {
  final TextEditingController controller;
  final bool isCompact;
  final void Function(String area, String city, double lat, double lon)? onSelected;

  const _LocationSearchField({
    required this.controller,
    required this.isCompact,
    this.onSelected,
  });

  @override
  State<_LocationSearchField> createState() => _LocationSearchFieldState();
}

class _LocationSearchFieldState extends State<_LocationSearchField> {
  final FocusNode _focusNode = FocusNode();
  final LayerLink _layerLink = LayerLink();
  OverlayEntry? _overlayEntry;
  late LocationSearchProvider _provider;

  @override
  void initState() {
    super.initState();
    _provider = LocationSearchProvider();
    _provider.addListener(_onProviderChanged);
    _focusNode.addListener(_onFocusChanged);
  }

  @override
  void dispose() {
    _hideOverlay();
    _provider.removeListener(_onProviderChanged);
    _provider.dispose();
    _focusNode.removeListener(_onFocusChanged);
    _focusNode.dispose();
    super.dispose();
  }

  void _onProviderChanged() {
    if (_provider.isLoading || _provider.results.isNotEmpty) {
      if (_focusNode.hasFocus) {
        _showOverlay();
        _overlayEntry?.markNeedsBuild();
      }
    } else {
      _hideOverlay();
    }
  }

  void _onFocusChanged() {
    if (_focusNode.hasFocus && (_provider.isLoading || _provider.results.isNotEmpty)) {
      _showOverlay();
    } else if (!_focusNode.hasFocus) {
      Future.delayed(const Duration(milliseconds: 150), () {
        if (mounted) _hideOverlay();
      });
    }
  }

  void _showOverlay() {
    if (_overlayEntry != null) return;
    
    final renderBox = context.findRenderObject() as RenderBox?;
    final width = renderBox?.size.width;

    _overlayEntry = OverlayEntry(
      builder: (context) {
        return Positioned(
          width: width,
          child: CompositedTransformFollower(
            link: _layerLink,
            showWhenUnlinked: false,
            targetAnchor: Alignment.bottomLeft,
            followerAnchor: Alignment.topLeft,
            child: Material(
              color: Colors.transparent,
              child: _buildOverlayContent(),
            ),
          ),
        );
      },
    );
    Overlay.of(context).insert(_overlayEntry!);
  }

  void _hideOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  Widget _buildOverlayContent() {
    if (_provider.isLoading) {
      return Container(
        margin: const EdgeInsets.only(top: 8),
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: AppColors.outlineVariant.withValues(alpha: 0.5),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            )
          ]
        ),
        child: const Center(
          child: SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
          ),
        ),
      );
    }

    if (_provider.results.isNotEmpty) {
      return Container(
        margin: const EdgeInsets.only(top: 8),
        constraints: const BoxConstraints(maxHeight: 240),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: AppColors.outlineVariant.withValues(alpha: 0.5),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            )
          ]
        ),
        child: ListView(
          padding: EdgeInsets.zero,
          shrinkWrap: true,
          children: _provider.results.map((place) {
            final fullName = place['display_name'] ?? '';
            final nameParts = fullName.split(', ');
            final title = nameParts.isNotEmpty ? nameParts.first : fullName;
            final subtitle = nameParts.length > 1 ? nameParts.skip(1).join(', ') : '';

            return ListTile(
              leading: const Icon(Icons.location_on_rounded, color: AppColors.primary),
              title: Text(
                title,
                style: AppTheme.body(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
              ),
              subtitle: subtitle.isNotEmpty
                  ? Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTheme.body(fontSize: 12, color: AppColors.textSecondary),
                    )
                  : null,
              onTap: () {
                final addressDetails = place['address'] as Map<String, dynamic>? ?? {};
                final shortName = place['name'] ??
                    addressDetails['neighbourhood'] ??
                    addressDetails['suburb'] ??
                    addressDetails['city_district'] ??
                    addressDetails['city'] ??
                    addressDetails['town'] ??
                    'Unknown Location';
                
                final city = (addressDetails['city'] ?? 
                              addressDetails['state_district'] ?? 
                              addressDetails['county'] ?? '').toString();
                          
                final lat = double.tryParse(place['lat']?.toString() ?? '') ?? 0.0;
                final lon = double.tryParse(place['lon']?.toString() ?? '') ?? 0.0;

                if (widget.onSelected != null) {
                  widget.onSelected!(shortName, city, lat, lon);
                } else {
                  widget.controller.text = shortName;
                }
                
                _provider.clearSearch();
                _focusNode.unfocus();
              },
            );
          }).toList(),
        ),
      );
    }

    return const SizedBox.shrink();
  }

  @override
  Widget build(BuildContext context) {
    return CompositedTransformTarget(
      link: _layerLink,
      child: TextField(
        focusNode: _focusNode,
        controller: widget.controller,
        onChanged: _provider.onSearchChanged,
        style: AppTheme.body(fontSize: widget.isCompact ? 14 : 15),
        decoration: InputDecoration(
          isDense: true,
          labelText: 'Area / Locality',
          hintText: 'Search locality or area...',
          prefixIcon: const Icon(Icons.location_on_rounded),
          suffixIcon: ValueListenableBuilder<TextEditingValue>(
            valueListenable: widget.controller,
            builder: (context, value, child) {
              if (value.text.isEmpty) return const SizedBox.shrink();
              return IconButton(
                icon: const Icon(Icons.close_rounded, size: 20),
                onPressed: () {
                  widget.controller.clear();
                  _provider.clearSearch();
                },
              );
            },
          ),
          filled: true,
          fillColor: AppColors.surfaceContainerLow,
          contentPadding: EdgeInsets.symmetric(
            horizontal: widget.isCompact ? 12 : 14,
            vertical: widget.isCompact ? 12 : 14,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(widget.isCompact ? 12 : 16),
            borderSide: BorderSide.none,
          ),
        ),
      ),
    );
  }
}
