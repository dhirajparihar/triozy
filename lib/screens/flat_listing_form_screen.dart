import 'dart:async';
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

class FlatListingFormScreen extends StatefulWidget {
  const FlatListingFormScreen({super.key});

  @override
  State<FlatListingFormScreen> createState() => _FlatListingFormScreenState();
}

class _FlatListingFormScreenState extends State<FlatListingFormScreen> {
  static const String _draftPrefix = 'flat_listing_draft_';
  static const int _maxImages = 10;
  static const int _maxImageBytes = 10 * 1024 * 1024;

  final PageController _pageController = PageController();
  final ImagePicker _picker = ImagePicker();

  final _ownerName = TextEditingController();
  final _contactNumber = TextEditingController();
  final _whatsAppNumber = TextEditingController();
  bool _sameAsContact = false;

  String _furnishingType = 'Fully Furnished';
  String _bhkType = '2BHK';
  bool _isIndependent = false;
  String _preferredTenant = 'Anyone';

  final _city = TextEditingController();
  final _area = TextEditingController();
  double? _latitude;
  double? _longitude;
  bool _detectingLocation = false;

  final _totalRent = TextEditingController();
  final _securityDeposit = TextEditingController();
  bool _maintenanceIncluded = false;
  bool _electricityIncluded = false;

  bool _smokingAllowed = false;
  bool _drinkingAllowed = false;
  bool _petsAllowed = false;
  String _visitorPolicy = 'Allowed';
  String _foodPreference = 'Both';

  final List<XFile> _propertyImages = [];
  XFile? _videoTour;

  final _description = TextEditingController();
  bool _immediateMoveIn = true;
  DateTime? _availableFrom;

  Timer? _draftTimer;
  int _step = 0;
  bool _submitting = false;
  final List<String> _requiredErrors = [];

  static const List<String> _furnishingOptions = [
    'Fully Furnished',
    'Semi Furnished',
    'Unfurnished',
  ];
  static const List<String> _bhkOptions = [
    '1RK',
    '1BHK',
    '2BHK',
    '3BHK',
    '4BHK+',
  ];
  static const List<String> _tenantOptions = ['Male', 'Female', 'Anyone'];
  static const List<String> _visitorOptions = [
    'Allowed',
    'Restricted',
    'Not Allowed',
  ];
  static const List<String> _foodOptions = ['Veg', 'Non-Veg', 'Both'];

  @override
  void initState() {
    super.initState();
    for (final controller in _textControllers) {
      controller.addListener(_scheduleDraftSave);
    }
    _loadDraft();
    _prefillFromProfile();
  }

  @override
  void dispose() {
    _draftTimer?.cancel();
    _pageController.dispose();
    for (final controller in _textControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  List<TextEditingController> get _textControllers => [
    _ownerName,
    _contactNumber,
    _whatsAppNumber,
    _city,
    _area,
    _totalRent,
    _securityDeposit,
    _description,
  ];

  void _scheduleDraftSave() {
    _draftTimer?.cancel();
    _draftTimer = Timer(const Duration(milliseconds: 700), _saveDraft);
  }

  Future<void> _loadDraft() async {
    final prefs = await SharedPreferences.getInstance();
    if (!(prefs.getBool('${_draftPrefix}exists') ?? false)) {
      return;
    }
    _ownerName.text = prefs.getString('${_draftPrefix}ownerName') ?? '';
    _contactNumber.text = prefs.getString('${_draftPrefix}contactNumber') ?? '';
    _whatsAppNumber.text = prefs.getString('${_draftPrefix}whatsApp') ?? '';
    _city.text = prefs.getString('${_draftPrefix}city') ?? '';
    _area.text = prefs.getString('${_draftPrefix}area') ?? '';
    _totalRent.text = prefs.getString('${_draftPrefix}totalRent') ?? '';
    _securityDeposit.text =
        prefs.getString('${_draftPrefix}securityDeposit') ?? '';
    _description.text = prefs.getString('${_draftPrefix}description') ?? '';

    _latitude = prefs.getDouble('${_draftPrefix}lat');
    _longitude = prefs.getDouble('${_draftPrefix}lon');

    setState(() {
      _sameAsContact = prefs.getBool('${_draftPrefix}sameAsContact') ?? false;
      _furnishingType =
          prefs.getString('${_draftPrefix}furnishingType') ?? _furnishingType;
      _bhkType = prefs.getString('${_draftPrefix}bhkType') ?? _bhkType;
      _preferredTenant =
          prefs.getString('${_draftPrefix}preferredTenant') ?? _preferredTenant;
      _isIndependent = prefs.getBool('${_draftPrefix}isIndependent') ?? false;
      _maintenanceIncluded =
          prefs.getBool('${_draftPrefix}maintenanceIncluded') ?? false;
      _electricityIncluded =
          prefs.getBool('${_draftPrefix}electricityIncluded') ?? false;
      _smokingAllowed = prefs.getBool('${_draftPrefix}smokingAllowed') ?? false;
      _drinkingAllowed =
          prefs.getBool('${_draftPrefix}drinkingAllowed') ?? false;
      _petsAllowed = prefs.getBool('${_draftPrefix}petsAllowed') ?? false;
      _visitorPolicy =
          prefs.getString('${_draftPrefix}visitorPolicy') ?? _visitorPolicy;
      _foodPreference =
          prefs.getString('${_draftPrefix}foodPreference') ?? _foodPreference;
      _immediateMoveIn =
          prefs.getBool('${_draftPrefix}immediateMoveIn') ?? true;
    });
  }

  Future<void> _prefillFromProfile() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final data = await context.read<DatabaseService>().getUserData(user.uid);
    if (!mounted) return;

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
        _sameAsContact = true;
      }
    });
  }

  Future<void> _saveDraft() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('${_draftPrefix}exists', true);
    await prefs.setString('${_draftPrefix}ownerName', _ownerName.text);
    await prefs.setString('${_draftPrefix}contactNumber', _contactNumber.text);
    await prefs.setString('${_draftPrefix}whatsApp', _whatsAppNumber.text);
    await prefs.setBool('${_draftPrefix}sameAsContact', _sameAsContact);
    await prefs.setString('${_draftPrefix}furnishingType', _furnishingType);
    await prefs.setString('${_draftPrefix}bhkType', _bhkType);
    await prefs.setString('${_draftPrefix}preferredTenant', _preferredTenant);
    await prefs.setBool('${_draftPrefix}isIndependent', _isIndependent);
    await prefs.setString('${_draftPrefix}city', _city.text);
    await prefs.setString('${_draftPrefix}area', _area.text);
    if (_latitude != null) {
      await prefs.setDouble('${_draftPrefix}lat', _latitude!);
    }
    if (_longitude != null) {
      await prefs.setDouble('${_draftPrefix}lon', _longitude!);
    }
    await prefs.setString('${_draftPrefix}totalRent', _totalRent.text);
    await prefs.setString(
      '${_draftPrefix}securityDeposit',
      _securityDeposit.text,
    );
    await prefs.setBool(
      '${_draftPrefix}maintenanceIncluded',
      _maintenanceIncluded,
    );
    await prefs.setBool(
      '${_draftPrefix}electricityIncluded',
      _electricityIncluded,
    );
    await prefs.setBool('${_draftPrefix}smokingAllowed', _smokingAllowed);
    await prefs.setBool('${_draftPrefix}drinkingAllowed', _drinkingAllowed);
    await prefs.setBool('${_draftPrefix}petsAllowed', _petsAllowed);
    await prefs.setString('${_draftPrefix}visitorPolicy', _visitorPolicy);
    await prefs.setString('${_draftPrefix}foodPreference', _foodPreference);
    await prefs.setString('${_draftPrefix}description', _description.text);
    await prefs.setBool('${_draftPrefix}immediateMoveIn', _immediateMoveIn);
  }

  Future<void> _clearDraft() async {
    final prefs = await SharedPreferences.getInstance();
    for (final key in prefs.getKeys().where(
      (key) => key.startsWith(_draftPrefix),
    )) {
      await prefs.remove(key);
    }
  }

  void _goToStep(int step) {
    final next = step.clamp(0, 2);
    setState(() => _step = next);
    _pageController.animateToPage(
      next,
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
    );
  }

  Future<void> _pickImages() async {
    final messenger = ScaffoldMessenger.of(context);
    final remaining = _maxImages - _propertyImages.length;
    if (remaining <= 0) {
      messenger.showSnackBar(
        const SnackBar(content: Text('You can upload up to 10 images here')),
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
    setState(() => _propertyImages.addAll(accepted));
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

  void _onReorderImages(int oldIndex, int newIndex) {
    setState(() {
      if (oldIndex < newIndex) newIndex -= 1;
      final item = _propertyImages.removeAt(oldIndex);
      _propertyImages.insert(newIndex, item);
    });
    _saveDraft();
  }

  Future<List<String>> _uploadImages(String id) async {
    if (_propertyImages.isEmpty) return [];
    final cloudinary = context.read<CloudinaryService>();
    final urls = <String>[];
    for (final image in _propertyImages) {
      final bytes = await image.readAsBytes();
      urls.add(
        await cloudinary.uploadImage(
          bytes: Uint8List.fromList(bytes),
          fileName: image.name,
          folder: 'flats/$id',
        ),
      );
    }
    return urls;
  }

  bool _validateAll() {
    final errors = <String>[];
    void need(TextEditingController controller, String label) {
      if (controller.text.trim().isEmpty) errors.add(label);
    }

    need(_ownerName, 'Owner Name');
    need(_contactNumber, 'Contact Number');
    need(_city, 'City');
    need(_area, 'Area/Locality');
    need(_totalRent, 'Total Rent');
    need(_securityDeposit, 'Security Deposit');
    need(_description, 'Description');

    if (int.tryParse(_totalRent.text.trim()) == null) {
      errors.add('Valid Total Rent');
    }
    if (_propertyImages.length < 3) {
      errors.add('Minimum 3 Images Required');
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
    if (!_validateAll()) return;

    final user = FirebaseAuth.instance.currentUser;
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    if (user == null) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Sign in to publish flat listing')),
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

      final highlights = <String>[
        _bhkType,
        _furnishingType,
        _preferredTenant != 'Anyone'
            ? 'Prefers $_preferredTenant'
            : 'Any Tenant',
        if (_isIndependent) 'Independent Flat',
        if (_maintenanceIncluded) 'Maintenance Included',
        if (_electricityIncluded) 'Electricity Included',
        if (!_isIndependent) ...[
          _visitorPolicy == 'Allowed'
              ? 'Visitors Allowed'
              : 'Visitors $_visitorPolicy',
          'Food: $_foodPreference',
        ],
      ].take(12).toList();

      final description = [
        _description.text.trim(),
        '',
        'Location: ${_area.text.trim()}, ${_city.text.trim()}',
        'Rent: Rs ${_totalRent.text.trim()}',
        'Security deposit: Rs ${_securityDeposit.text.trim()}',
        'Maintenance: ${_maintenanceIncluded ? 'Included' : 'Not Included'}',
        'Electricity: ${_electricityIncluded ? 'Included' : 'Not Included'}',
        'Contact: ${_contactNumber.text.trim()}',
        if (_whatsAppNumber.text.trim().isNotEmpty)
          'WhatsApp: ${_whatsAppNumber.text.trim()}',
        if (!_isIndependent) ...[
          'Smoking: ${_smokingAllowed ? 'Allowed' : 'Not allowed'}',
          'Drinking: ${_drinkingAllowed ? 'Allowed' : 'Not allowed'}',
          'Pets: ${_petsAllowed ? 'Allowed' : 'Not allowed'}',
        ],
        if (_videoTour != null) 'Video tour selected: ${_videoTour!.name}',
      ].join('\n');

      final listing = ListingModel(
        id: id,
        ownerId: user.uid,
        ownerName: _ownerName.text.trim().isEmpty
            ? (ownerDisplayName.isEmpty ? 'Flat Owner' : ownerDisplayName)
            : _ownerName.text.trim(),
        ownerPhotoUrl: ownerPhotoUrl,
        title: '$_bhkType Flat in ${_area.text.trim()}',
        description: description,
        location: locationParts.isEmpty
            ? _city.text.trim()
            : locationParts.join(', '),
        latitude: _latitude,
        longitude: _longitude,
        price: double.tryParse(_totalRent.text.trim()) ?? 0,
        type: ListingType.housing,
        propertyType: PropertyType.flat,
        imageUrls: imageUrls,
        highlights: highlights,
        genderPreference: _preferredTenant,
        furnishing: _furnishingType,
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
      messenger.showSnackBar(const SnackBar(content: Text('Your listing will be published once approved.')));
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
    final locationProvider = context.read<LocationProvider>();
    final messenger = ScaffoldMessenger.of(context);

    setState(() => _detectingLocation = true);
    try {
      await locationProvider.refreshLocation();
      if (!mounted) return;

      final address = locationProvider.address.trim();
      final hasResolvedAddress =
          address.isNotEmpty &&
          address != 'Locating...' &&
          address != 'Location unavailable';

      if (!hasResolvedAddress) {
        messenger.showSnackBar(
          const SnackBar(content: Text('Could not detect your location')),
        );
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
      messenger.showSnackBar(
        SnackBar(content: Text('Could not detect location: $error')),
      );
    } finally {
      if (mounted) setState(() => _detectingLocation = false);
    }
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

  @override
  Widget build(BuildContext context) {
    final isCompact = MediaQuery.sizeOf(context).width < 380;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.onSurface,
        elevation: 0,
        title: const Text('List Flat / Apartment'),
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
                // Screen 1: Basic Details
                _StepPage(
                  children: [
                    _SectionCard(
                      title: 'Basic Details',
                      icon: Icons.info_outline_rounded,
                      children: [
                        _AppField(controller: _ownerName, label: 'Owner Name'),
                        _AppField(
                          controller: _contactNumber,
                          label: 'Contact Number',
                          keyboardType: TextInputType.phone,
                        ),
                        Row(
                          children: [
                            SizedBox(
                              height: 24,
                              width: 24,
                              child: Checkbox(
                                value: _sameAsContact,
                                activeColor: AppColors.primary,
                                onChanged: (val) {
                                  setState(() {
                                    _sameAsContact = val ?? false;
                                    if (_sameAsContact) {
                                      _whatsAppNumber.text =
                                          _contactNumber.text;
                                    }
                                  });
                                  _saveDraft();
                                },
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Same as contact number',
                              style: AppTheme.body(fontSize: 14),
                            ),
                          ],
                        ),
                        _AppField(
                          controller: _whatsAppNumber,
                          label: 'WhatsApp Number (optional)',
                          keyboardType: TextInputType.phone,
                        ),
                        _SelectTile(
                          label: 'Furnishing Type',
                          value: _furnishingType,
                          icon: Icons.chair_rounded,
                          onTap: () => _showPicker(
                            title: 'Furnishing Type',
                            values: _furnishingOptions,
                            selected: _furnishingType,
                            onSelected: (val) =>
                                setState(() => _furnishingType = val),
                          ),
                        ),
                        _SelectTile(
                          label: 'BHK Type',
                          value: _bhkType,
                          icon: Icons.home_work_rounded,
                          onTap: () => _showPicker(
                            title: 'BHK Type',
                            values: _bhkOptions,
                            selected: _bhkType,
                            onSelected: (val) => setState(() => _bhkType = val),
                          ),
                        ),
                        _SelectTile(
                          label: 'Preferred Tenant Type',
                          value: _preferredTenant,
                          icon: Icons.people_alt_rounded,
                          onTap: () => _showPicker(
                            title: 'Preferred Tenant Type',
                            values: _tenantOptions,
                            selected: _preferredTenant,
                            onSelected: (val) =>
                                setState(() => _preferredTenant = val),
                          ),
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
                            onPressed: _detectingLocation
                                ? null
                                : _detectCurrentLocation,
                            icon: _detectingLocation
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Icon(
                                    Icons.my_location_rounded,
                                    size: 18,
                                  ),
                            label: Text(
                              _detectingLocation
                                  ? 'Detecting location'
                                  : 'Detect current location',
                            ),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.primary,
                              side: BorderSide(
                                color: AppColors.outlineVariant.withValues(
                                  alpha: 0.65,
                                ),
                              ),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 12,
                              ),
                              textStyle: AppTheme.button(
                                fontSize: 13,
                                color: AppColors.primary,
                              ),
                            ),
                          ),
                        ),
                        _AppField(controller: _city, label: 'City'),
                      ],
                    ),
                  ],
                ),
                // Screen 2: Pricing & Rules
                _StepPage(
                  children: [
                    _SectionCard(
                      title: 'Pricing',
                      icon: Icons.currency_rupee_rounded,
                      children: [
                        _AppField(
                          controller: _totalRent,
                          label: 'Total Rent',
                          prefixText: '₹ ',
                          keyboardType: TextInputType.number,
                        ),
                        _AppField(
                          controller: _securityDeposit,
                          label: 'Security Deposit',
                          prefixText: '₹ ',
                          keyboardType: TextInputType.number,
                        ),
                        _SwitchTile(
                          label: 'Maintenance Included?',
                          value: _maintenanceIncluded,
                          onChanged: (val) =>
                              setState(() => _maintenanceIncluded = val),
                        ),
                        _SwitchTile(
                          label: 'Electricity Included?',
                          value: _electricityIncluded,
                          onChanged: (val) =>
                              setState(() => _electricityIncluded = val),
                        ),
                      ],
                    ),
                    _SectionCard(
                      title: 'Rules & Preferences',
                      icon: Icons.rule_rounded,
                      children: [
                        _SwitchTile(
                          label: 'Is it an independent flat?',
                          value: _isIndependent,
                          onChanged: (val) =>
                              setState(() => _isIndependent = val),
                        ),
                        if (!_isIndependent) ...[
                          _SwitchTile(
                            label: 'Smoking Allowed?',
                            value: _smokingAllowed,
                            onChanged: (val) =>
                                setState(() => _smokingAllowed = val),
                          ),
                          _SwitchTile(
                            label: 'Drinking Allowed?',
                            value: _drinkingAllowed,
                            onChanged: (val) =>
                                setState(() => _drinkingAllowed = val),
                          ),
                          _SwitchTile(
                            label: 'Pets Allowed?',
                            value: _petsAllowed,
                            onChanged: (val) =>
                                setState(() => _petsAllowed = val),
                          ),
                          _SelectTile(
                            label: 'Visitor Policy',
                            value: _visitorPolicy,
                            icon: Icons.door_front_door_rounded,
                            onTap: () => _showPicker(
                              title: 'Visitor Policy',
                              values: _visitorOptions,
                              selected: _visitorPolicy,
                              onSelected: (val) =>
                                  setState(() => _visitorPolicy = val),
                            ),
                          ),
                          _SelectTile(
                            label: 'Food Preference',
                            value: _foodPreference,
                            icon: Icons.restaurant_rounded,
                            onTap: () => _showPicker(
                              title: 'Food Preference',
                              values: _foodOptions,
                              selected: _foodPreference,
                              onSelected: (val) =>
                                  setState(() => _foodPreference = val),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
                // Screen 3: Media & Details
                _StepPage(
                  children: [
                    _SectionCard(
                      title: 'Photos & Media',
                      icon: Icons.photo_library_rounded,
                      children: [
                        _DraggableImageUploadGroup(
                          title: 'Property Images (Min 3)',
                          images: _propertyImages,
                          onAdd: _pickImages,
                          onRemove: (index) =>
                              setState(() => _propertyImages.removeAt(index)),
                          onReorder: _onReorderImages,
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
                          label: 'Property Description',
                          hint: 'Describe your flat, nearby places, vibe...',
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
                          onChanged: (val) =>
                              setState(() => _immediateMoveIn = val),
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
                      : (_step == 2 ? _publish : () => _goToStep(_step + 1)),
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
                          _step == 2 ? 'Publish Flat' : 'Continue',
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
}

// -----------------------------------------------------------------------------
// Private Reusable Components (Adapted from PG form context)
// -----------------------------------------------------------------------------

class _ProgressHeader extends StatelessWidget {
  final int step;
  const _ProgressHeader({required this.step});

  @override
  Widget build(BuildContext context) {
    final isCompact = MediaQuery.sizeOf(context).width < 380;
    final labels = ['Basic Details', 'Pricing & Rules', 'Media & Details'];
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
  final List<String> errors;
  const _ValidationBanner({required this.errors});

  @override
  Widget build(BuildContext context) {
    final isCompact = MediaQuery.sizeOf(context).width < 380;
    return Container(
      margin: EdgeInsets.fromLTRB(
        isCompact ? 12 : 16,
        0,
        isCompact ? 12 : 16,
        10,
      ),
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
      children: children.expand((child) sync* {
        yield child;
        yield SizedBox(height: isCompact ? 12 : 16);
      }).toList(),
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

class _DraggableImageUploadGroup extends StatelessWidget {
  final String title;
  final List<XFile> images;
  final VoidCallback onAdd;
  final ValueChanged<int> onRemove;
  final void Function(int oldIndex, int newIndex) onReorder;

  const _DraggableImageUploadGroup({
    required this.title,
    required this.images,
    required this.onAdd,
    required this.onRemove,
    required this.onReorder,
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
            child: Theme(
              data: Theme.of(context).copyWith(canvasColor: Colors.transparent),
              child: ReorderableListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: images.length,
                onReorder: onReorder,
                proxyDecorator: (child, index, animation) {
                  return Material(color: Colors.transparent, child: child);
                },
                itemBuilder: (context, index) {
                  return Container(
                    key: ValueKey(images[index].path),
                    margin: EdgeInsets.only(right: isCompact ? 8 : 10),
                    child: Stack(
                      children: [
                        _ImagePreviewTile(
                          image: images[index],
                          size: previewSize,
                          onRemove: () => onRemove(index),
                        ),
                        if (index == 0)
                          Positioned(
                            bottom: 4,
                            left: 4,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.primary,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                'Cover',
                                style: AppTheme.label(
                                  fontSize: 10,
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
      ],
    );
  }
}

class _ImagePreviewTile extends StatelessWidget {
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

class _LocationSearchField extends StatefulWidget {
  final TextEditingController controller;
  final bool isCompact;
  final void Function(String area, String city, double lat, double lon)?
  onSelected;

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
    if (_focusNode.hasFocus &&
        (_provider.isLoading || _provider.results.isNotEmpty)) {
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
            ),
          ],
        ),
        child: const Center(
          child: SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: AppColors.primary,
            ),
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
            ),
          ],
        ),
        child: ListView(
          padding: EdgeInsets.zero,
          shrinkWrap: true,
          children: _provider.results.map((place) {
            final fullName = place['display_name'] ?? '';
            final nameParts = fullName.split(', ');
            final title = nameParts.isNotEmpty ? nameParts.first : fullName;
            final subtitle = nameParts.length > 1
                ? nameParts.skip(1).join(', ')
                : '';

            return ListTile(
              leading: const Icon(
                Icons.location_on_rounded,
                color: AppColors.primary,
              ),
              title: Text(
                title,
                style: AppTheme.body(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              subtitle: subtitle.isNotEmpty
                  ? Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTheme.body(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    )
                  : null,
              onTap: () {
                final addressDetails =
                    place['address'] as Map<String, dynamic>? ?? {};
                final shortName =
                    place['name'] ??
                    addressDetails['neighbourhood'] ??
                    addressDetails['suburb'] ??
                    addressDetails['city_district'] ??
                    addressDetails['city'] ??
                    addressDetails['town'] ??
                    'Unknown Location';

                final city =
                    (addressDetails['city'] ??
                            addressDetails['state_district'] ??
                            addressDetails['county'] ??
                            '')
                        .toString();
                final lat =
                    double.tryParse(place['lat']?.toString() ?? '') ?? 0.0;
                final lon =
                    double.tryParse(place['lon']?.toString() ?? '') ?? 0.0;

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
