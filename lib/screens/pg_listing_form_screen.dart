import 'dart:async';
import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../models/listing_model.dart';
import '../services/cloudinary_service.dart';
import '../services/database_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../utils/validators.dart';

class PgListingFormScreen extends StatefulWidget {
  const PgListingFormScreen({super.key});

  @override
  State<PgListingFormScreen> createState() => _PgListingFormScreenState();
}

class _PgListingFormScreenState extends State<PgListingFormScreen> {
  static const String _draftPrefix = 'pg_listing_draft_';
  static const int _maxImagesPerGroup = 4;
  static const int _maxImageBytes = 10 * 1024 * 1024;

  final ImagePicker _picker = ImagePicker();

  final _propertyName = TextEditingController();
  final _ownerName = TextEditingController();
  final _contactNumber = TextEditingController();
  final _city = TextEditingController();
  final _area = TextEditingController();
  final _nearby = TextEditingController();
  final _securityDeposit = TextEditingController();
  final _description = TextEditingController();
  final _bedsAvailable = TextEditingController();

  final List<XFile> _propertyImages = [];
  final List<_RoomConfiguration> _roomConfigurations = [];
  final Set<String> _amenities = {'WiFi', 'CCTV'};
  final List<String> _requiredErrors = [];

  Timer? _draftTimer;

  bool _submitting = false;
  bool _immediateMoveIn = true;
  DateTime? _availableFrom;

  String _propertyType = 'Boys PG';
  String _preferredGender = 'Any';
  String _occupantType = 'Both';
  bool _electricityIncluded = true;
  bool _foodIncluded = true;

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
    _roomConfigurations.add(_newRoomConfiguration(expanded: true));
    for (final controller in _textControllers) {
      controller.addListener(_scheduleDraftSave);
    }
    _loadDraft();
    _prefillFromProfile();
  }

  @override
  void dispose() {
    _draftTimer?.cancel();
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
    _city,
    _area,
    _nearby,
    _securityDeposit,
    _description,
    _bedsAvailable,
  ];

  void _scheduleDraftSave() {
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
    setState(() {
      for (final config in _roomConfigurations) {
        config.expanded = false;
      }
      _roomConfigurations.add(_newRoomConfiguration(expanded: true));
    });
    _saveDraft();
  }

  void _deleteRoomConfiguration(int index) {
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
    final prefs = await SharedPreferences.getInstance();
    if (!(prefs.getBool('${_draftPrefix}exists') ?? false)) {
      return;
    }

    _propertyName.text = prefs.getString('${_draftPrefix}propertyName') ?? '';
    _ownerName.text = prefs.getString('${_draftPrefix}ownerName') ?? '';
    _contactNumber.text = prefs.getString('${_draftPrefix}contactNumber') ?? '';
    _city.text = prefs.getString('${_draftPrefix}city') ?? '';
    _area.text = prefs.getString('${_draftPrefix}area') ?? '';
    _nearby.text = prefs.getString('${_draftPrefix}nearby') ?? '';
    _securityDeposit.text = prefs.getString('${_draftPrefix}deposit') ?? '';
    _description.text = prefs.getString('${_draftPrefix}description') ?? '';
    _bedsAvailable.text = prefs.getString('${_draftPrefix}bedsAvailable') ?? '';

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

    if (!mounted) {
      return;
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
      _immediateMoveIn = prefs.getBool('${_draftPrefix}immediate') ?? true;
      _amenities
        ..clear()
        ..addAll(
          prefs.getStringList('${_draftPrefix}amenities') ?? ['WiFi', 'CCTV'],
        );
    });
  }

  Future<void> _prefillFromProfile() async {
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
    });
  }

  Future<void> _saveDraft() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('${_draftPrefix}exists', true);
    await prefs.setString('${_draftPrefix}propertyName', _propertyName.text);
    await prefs.setString('${_draftPrefix}ownerName', _ownerName.text);
    await prefs.setString('${_draftPrefix}contactNumber', _contactNumber.text);
    await prefs.setString('${_draftPrefix}city', _city.text);
    await prefs.setString('${_draftPrefix}area', _area.text);
    await prefs.setString('${_draftPrefix}nearby', _nearby.text);
    await prefs.setString('${_draftPrefix}deposit', _securityDeposit.text);
    await prefs.setString('${_draftPrefix}description', _description.text);
    await prefs.setString('${_draftPrefix}bedsAvailable', _bedsAvailable.text);
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
    await prefs.setBool('${_draftPrefix}immediate', _immediateMoveIn);
    await prefs.setStringList('${_draftPrefix}amenities', _amenities.toList());
  }

  Future<void> _clearDraft() async {
    final prefs = await SharedPreferences.getInstance();
    for (final key in prefs.getKeys().where(
      (key) => key.startsWith(_draftPrefix),
    )) {
      await prefs.remove(key);
    }
  }

  Future<void> _pickImages(List<XFile> target) async {
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
    if (images.isEmpty) {
      return;
    }

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

    if (!mounted) {
      return;
    }

    setState(() => target.addAll(accepted));
    _saveDraft();

    if (rejectedOversize) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Each image must be 10 MB or smaller')),
      );
    }
  }

  Future<List<String>> _uploadImages(String id) async {
    if (_propertyImages.isEmpty) {
      return [];
    }

    final cloudinary = context.read<CloudinaryService>();
    final urls = <String>[];
    for (final image in _propertyImages) {
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
    final errors = <String>[];

    void need(TextEditingController controller, String label) {
      if (controller.text.trim().isEmpty) {
        errors.add(label);
      }
    }

    need(_propertyName, 'Property Name');
    need(_contactNumber, 'Contact Number');
    need(_city, 'City');
    need(_area, 'Area/Locality');
    need(_description, 'Description');
    need(_securityDeposit, 'Security Deposit');
    need(_bedsAvailable, 'Beds Currently Available');

    if (Validators.validatePhoneNumber(_contactNumber.text) != null) {
      errors.add('Valid Contact Number');
    }
    if (_description.text.trim().length < 24) {
      errors.add('Detailed Description');
    }
    if (double.tryParse(_securityDeposit.text.trim()) == null) {
      errors.add('Valid Security Deposit');
    }

    final bedsAvailable = int.tryParse(_bedsAvailable.text.trim());
    if (bedsAvailable == null || bedsAvailable < 0) {
      errors.add('Valid Beds Currently Available');
    }

    for (var index = 0; index < _roomConfigurations.length; index++) {
      final config = _roomConfigurations[index];
      final label = 'Room ${index + 1}';
      final rent = double.tryParse(config.rent.text.trim());
      final capacity = int.tryParse(config.capacity.text.trim());
      final vacantBeds = int.tryParse(config.vacantBeds.text.trim());

      if (rent == null || rent <= 0) {
        errors.add('$label rent');
      }
      if (capacity == null || capacity <= 0) {
        errors.add('$label capacity');
      }
      if (vacantBeds == null || vacantBeds < 0) {
        errors.add('$label vacant beds');
      } else if (capacity != null && vacantBeds > capacity) {
        errors.add('$label vacant beds <= capacity');
      }
    }

    if (_propertyImages.isEmpty) {
      errors.add('At least 1 photo');
    }

    if (!_immediateMoveIn && _availableFrom == null) {
      errors.add('Available From Date');
    }

    setState(() {
      _requiredErrors
        ..clear()
        ..addAll(errors.toSet());
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
    if (!_validateAll()) {
      return;
    }

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
      ].where((part) => part.isNotEmpty).toList();
      final roomSummaries = _roomConfigurations
          .map((config) => config.summary)
          .where((summary) => summary.isNotEmpty)
          .toList();
      final minRent = _roomConfigurations
          .map((config) => double.tryParse(config.rent.text.trim()) ?? 0)
          .where((rent) => rent > 0)
          .fold<double?>(null, (lowest, rent) {
            if (lowest == null || rent < lowest) {
              return rent;
            }
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
        if (_nearby.text.trim().isNotEmpty) 'Nearby: ${_nearby.text.trim()}',
        'Room configurations:',
        ...roomSummaries.map((summary) => '- $summary'),
        if (totalCapacity > 0) 'Total capacity: $totalCapacity',
        if (totalVacantBeds > 0) 'Vacant beds: $totalVacantBeds',
        'Beds available: ${_bedsAvailable.text.trim()}',
        'Security deposit: Rs ${_securityDeposit.text.trim()}',
        'Contact: ${_contactNumber.text.trim()}',
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

      if (!mounted) {
        return;
      }
      messenger.showSnackBar(const SnackBar(content: Text('PG published')));
      navigator.pop(true);
    } catch (error) {
      if (!mounted) {
        return;
      }
      messenger.showSnackBar(
        SnackBar(content: Text('Could not publish: $error')),
      );
    } finally {
      if (mounted) {
        setState(() => _submitting = false);
      }
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
    if (picked == null || !mounted) {
      return;
    }
    setState(() {
      _availableFrom = picked;
      _immediateMoveIn = false;
    });
    _saveDraft();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: AppColors.onSurface,
        title: const Text('List PG / Hostel'),
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
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Post your PG listing',
              style: AppTheme.headline(fontSize: 28),
            ),
            const SizedBox(height: 10),
            Text(
              'Use the same simple flow as the other listing forms: add photos, key details, room options, and publish.',
              style: AppTheme.body(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: AppColors.onSurfaceVariant,
                height: 1.6,
              ),
            ),
            if (_requiredErrors.isNotEmpty) ...[
              const SizedBox(height: 16),
              _ValidationBanner(errors: _requiredErrors),
            ],
            const SizedBox(height: 22),
            _sectionTitle('Photos'),
            const SizedBox(height: 12),
            _SectionCard(
              title: 'Listing Photos',
              icon: Icons.photo_library_rounded,
              children: [
                Text(
                  'Add a few clear photos of the property. At least one image is required.',
                  style: AppTheme.body(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.slate500,
                  ),
                ),
                _ImageUploadGroup(
                  title: 'Photos',
                  images: _propertyImages,
                  onAdd: () => _pickImages(_propertyImages),
                  onRemove: (index) =>
                      setState(() => _propertyImages.removeAt(index)),
                ),
              ],
            ),
            const SizedBox(height: 22),
            _sectionTitle('Details'),
            const SizedBox(height: 12),
            _SectionCard(
              title: 'Basic Information',
              icon: Icons.apartment_rounded,
              children: [
                _AppField(
                  controller: _propertyName,
                  label: 'Property Name',
                  hint: 'Om Boys PG',
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
                  controller: _contactNumber,
                  label: 'Contact Number',
                  hint: '10-digit mobile number',
                  keyboardType: TextInputType.phone,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(10),
                  ],
                ),
                _AppField(
                  controller: _description,
                  label: 'Description',
                  hint:
                      'Girls PG near XYZ college with WiFi, food, and security.',
                  maxLines: 5,
                  helperText:
                      'Mention who it suits, what is included, and the strongest selling point.',
                ),
              ],
            ),
            const SizedBox(height: 16),
            _SectionCard(
              title: 'Location',
              icon: Icons.location_on_rounded,
              children: [
                _AppField(controller: _city, label: 'City', hint: 'Indore'),
                _AppField(
                  controller: _area,
                  label: 'Area/Locality',
                  hint: 'Vijay Nagar',
                ),
                _AppField(
                  controller: _nearby,
                  label: 'Nearby landmark (optional)',
                  hint: 'IIT Indore, TCS, Metro station',
                ),
              ],
            ),
            const SizedBox(height: 22),
            _sectionTitle('Rooms & Pricing'),
            const SizedBox(height: 12),
            _SectionCard(
              title: 'Room Configurations',
              icon: Icons.bed_rounded,
              children: [
                Text(
                  'Add each room option with its own rent, capacity, vacant beds, furnishing, and washroom setup.',
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
                _AppField(
                  controller: _securityDeposit,
                  label: 'Security Deposit',
                  hint: '5000',
                  prefixText: 'Rs ',
                  keyboardType: TextInputType.number,
                ),
                _AppField(
                  controller: _bedsAvailable,
                  label: 'Beds Currently Available',
                  hint: '6',
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
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
                  onChanged: (value) => setState(() => _foodIncluded = value),
                ),
              ],
            ),
            const SizedBox(height: 22),
            _sectionTitle('Preferences'),
            const SizedBox(height: 12),
            _SectionCard(
              title: 'Amenities & Preferences',
              icon: Icons.tune_rounded,
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
              ],
            ),
            const SizedBox(height: 22),
            _sectionTitle('Availability'),
            const SizedBox(height: 12),
            _SectionCard(
              title: 'Move-in Details',
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
              ],
            ),
            const SizedBox(height: 26),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _submitting ? null : _publish,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                ),
                child: _submitting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Text(
                        'Publish listing',
                        style: AppTheme.body(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionTitle(String label) {
    return Text(label, style: AppTheme.headline(fontSize: 22));
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
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AppTheme.headline(fontSize: 22)),
                const SizedBox(height: 14),
                ...values.map(
                  (value) => ListTile(
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

class _ValidationBanner extends StatelessWidget {
  final List<String> errors;

  const _ValidationBanner({required this.errors});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.errorContainer,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.error_outline_rounded, color: AppColors.error),
          const SizedBox(width: 10),
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

class _SectionCard extends StatelessWidget {
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
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
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
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.blue50,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: AppColors.primary, size: 21),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(title, style: AppTheme.headline(fontSize: 19)),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...children.expand((child) sync* {
            yield child;
            yield const SizedBox(height: 12);
          }),
        ],
      ),
    );
  }
}

class _AppField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String? hint;
  final String? helperText;
  final String? prefixText;
  final int maxLines;
  final TextInputType? keyboardType;
  final List<TextInputFormatter>? inputFormatters;

  const _AppField({
    required this.controller,
    required this.label,
    this.hint,
    this.helperText,
    this.prefixText,
    this.maxLines = 1,
    this.keyboardType,
    this.inputFormatters,
  });

  @override
  Widget build(BuildContext context) {
    List<TextInputFormatter>? resolvedFormatters = inputFormatters;
    if (resolvedFormatters == null) {
      if (keyboardType == TextInputType.number) {
        resolvedFormatters = [FilteringTextInputFormatter.digitsOnly];
      } else if (keyboardType == TextInputType.phone) {
        resolvedFormatters = [
          FilteringTextInputFormatter.digitsOnly,
          LengthLimitingTextInputFormatter(10),
        ];
      }
    }

    return TextField(
      controller: controller,
      maxLines: maxLines,
      keyboardType: keyboardType,
      inputFormatters: resolvedFormatters,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        helperText: helperText,
        prefixText: prefixText,
        filled: true,
        fillColor: AppColors.surfaceContainerLow,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }
}

class _SelectTile extends StatelessWidget {
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
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.surfaceContainerLow,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Icon(icon, color: AppColors.primary),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: AppTheme.label()),
                  const SizedBox(height: 5),
                  Text(
                    value,
                    style: AppTheme.body(fontWeight: FontWeight.w800),
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
    return SwitchListTile.adaptive(
      value: value,
      onChanged: onChanged,
      contentPadding: const EdgeInsets.symmetric(horizontal: 4),
      title: Text(label, style: AppTheme.body(fontWeight: FontWeight.w700)),
    );
  }
}

class _AmenityGrid extends StatelessWidget {
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
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: options.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        childAspectRatio: 0.9,
      ),
      itemBuilder: (context, index) {
        final option = options[index];
        final active = selected.contains(option.label);
        return InkWell(
          onTap: () => onTap(option.label),
          borderRadius: BorderRadius.circular(18),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: active ? AppColors.blue50 : AppColors.surfaceContainerLow,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: active ? AppColors.primary : Colors.transparent,
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  option.icon,
                  color: active ? AppColors.primary : AppColors.slate500,
                ),
                const SizedBox(height: 8),
                Text(
                  option.label,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppTheme.label(
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
  }
}

class _ImageUploadGroup extends StatelessWidget {
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                title,
                style: AppTheme.body(fontWeight: FontWeight.w800),
              ),
            ),
            TextButton.icon(
              onPressed: onAdd,
              icon: const Icon(Icons.add_photo_alternate_rounded),
              label: const Text('Upload'),
            ),
          ],
        ),
        if (images.isEmpty)
          Container(
            height: 88,
            width: double.infinity,
            decoration: BoxDecoration(
              color: AppColors.surfaceContainerLow,
              borderRadius: BorderRadius.circular(18),
            ),
            child: const Center(child: Icon(Icons.image_outlined)),
          )
        else
          SizedBox(
            height: 92,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: images.length,
              separatorBuilder: (_, _) => const SizedBox(width: 10),
              itemBuilder: (context, index) {
                return _ImagePreviewTile(
                  image: images[index],
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
  final XFile image;
  final VoidCallback onRemove;

  const _ImagePreviewTile({required this.image, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: SizedBox(
        width: 92,
        height: 92,
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

class _RoomConfigurationCard extends StatelessWidget {
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
    final vacant = config.vacantBeds.text.trim().isEmpty
        ? '0'
        : config.vacantBeds.text.trim();
    final rent = config.rent.text.trim().isEmpty
        ? 'Add rent'
        : 'Rs ${config.rent.text.trim()}';

    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOutCubic,
      padding: const EdgeInsets.all(14),
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
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(
                    Icons.king_bed_rounded,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        config.roomType,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTheme.body(
                          fontSize: 15,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 4),
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
              padding: const EdgeInsets.only(top: 14),
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
                    prefixText: 'Rs ',
                    keyboardType: TextInputType.number,
                    hint: '6500',
                  ),
                  _AppField(
                    controller: config.capacity,
                    label: 'Total Capacity',
                    keyboardType: TextInputType.number,
                    hint: '3',
                  ),
                  _AppField(
                    controller: config.vacantBeds,
                    label: 'Vacant Beds',
                    keyboardType: TextInputType.number,
                    hint: '1',
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
        : 'Rs ${rent.text.trim()}';
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

class _AmenityItem {
  final String label;
  final IconData icon;

  const _AmenityItem(this.label, this.icon);
}
