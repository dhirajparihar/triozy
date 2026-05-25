import 'dart:async';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/listing_model.dart';
import '../models/requirement_model.dart';
import '../services/cloudinary_service.dart';
import '../services/database_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../providers/location_search_provider.dart';


// === Requirement form ========================================================

/// Form for users looking for a room/flat/PG.
class RequirementFormScreen extends StatefulWidget {
  const RequirementFormScreen({super.key});

  @override
  State<RequirementFormScreen> createState() => _RequirementFormScreenState();
}


/// State container for requirement form draft, validation, and submission.
class _RequirementFormScreenState extends State<RequirementFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final ValueNotifier<NeedType> _needTypeNotifier = ValueNotifier(
    NeedType.room,
  );
  final TextEditingController _locationController = TextEditingController();
  double? _latitude;
  double? _longitude;
  double _minBudget = 4000;
  double _maxBudget = 12000;
  String _moveIn = 'Immediately';
  DateTime? _customMoveInDate;
  String _occupancy = 'Any';
  String _gender = 'Any';
  final TextEditingController _descController = TextEditingController();
  final Set<String> _amenities = {};
  final Set<String> _lifestyle = {};
  final Set<String> _contact = {'In-app Chat'};
  final ImagePicker _picker = ImagePicker();
  bool _mobilePublic = true;

  Timer? _autosaveTimer;
  bool _uploadingProfilePhoto = false;
  String _profilePhotoUrl = '';

  @override
  void initState() {
    super.initState();
    // Restore any saved draft and warm up profile photo.
    _loadDraft();
    _loadProfilePhoto();
    // Autosave only after edits to avoid noisy storage writes.
    _descController.addListener(_scheduleAutosave);
    _locationController.addListener(_scheduleAutosave);
  }

  @override
  void dispose() {
    _needTypeNotifier.dispose();
    _autosaveTimer?.cancel();
    _descController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  void _scheduleAutosave() {
    // Debounce draft saving to avoid excessive writes.
    _autosaveTimer?.cancel();
    _autosaveTimer = Timer(const Duration(seconds: 1), _saveDraft);
  }

  Future<void> _loadDraft() async {
    // Lightweight draft restore for description and location fields.
    final prefs = await SharedPreferences.getInstance();
    final hasDraft = prefs.getBool('requirement_draft') ?? false;
    if (!hasDraft) return;
    try {
      _descController.text = prefs.getString('req_desc') ?? '';
      _locationController.text = prefs.getString('req_location') ?? '';
      _latitude = prefs.getDouble('req_lat');
      _longitude = prefs.getDouble('req_lon');
      setState(() {});
    } catch (_) {}
  }

  Future<void> _loadProfilePhoto() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return;
    }

    // Fall back order: auth photo -> Firestore profile fields -> default avatar.
    var photoUrl = (user.photoURL ?? '').trim();
    try {
      // Prefer Firestore photo fields when available.
      final userData = await context.read<DatabaseService>().getUserData(
        user.uid,
      );
      photoUrl = _firstProfilePhotoUrl(userData, fallback: photoUrl);
    } catch (_) {}

    if (photoUrl.isEmpty) {
      photoUrl = _defaultProfileAvatarUrl(user);
    }

    if (!mounted) {
      return;
    }
    setState(() => _profilePhotoUrl = photoUrl);
  }

  Future<void> _pickProfilePhoto() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Sign in to upload photo')));
      return;
    }
    final cloudinaryService = context.read<CloudinaryService>();

    final image = await _picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 512,
      maxHeight: 512,
      imageQuality: 85,
    );
    if (image == null) {
      return;
    }
    if (!mounted) {
      return;
    }

    setState(() => _uploadingProfilePhoto = true);
    try {
      // Upload and persist profile photo to Cloudinary + Firestore.
      final photoUrl = await cloudinaryService.uploadImage(
        bytes: await image.readAsBytes(),
        fileName: image.name,
        folder: 'profile_photos/${user.uid}',
      );
      await _saveProfilePhotoUrl(user, photoUrl);
      if (mounted) {
        setState(() => _profilePhotoUrl = photoUrl);
      }
    } catch (e) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Could not upload photo: $e')));
    } finally {
      if (mounted) {
        setState(() => _uploadingProfilePhoto = false);
      }
    }
  }

  /// Asset paths for bundled avatars.
  static const _kMaleAvatarAsset = 'assets/images/male avtar.png';
  static const _kFemaleAvatarAsset = 'assets/images/female avtar.png';

  Future<void> _chooseAvatar(String avatarKey) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Sign in to choose avatar')));
      return;
    }

    final cloudinaryService = context.read<CloudinaryService>();
    final assetPath = avatarKey == 'female' ? _kFemaleAvatarAsset : _kMaleAvatarAsset;
    final previousPhotoUrl = _profilePhotoUrl;
    
    setState(() {
      _uploadingProfilePhoto = true;
      _profilePhotoUrl = assetPath;
    });

    try {
      final ByteData data = await rootBundle.load(assetPath);
      final Uint8List bytes = data.buffer.asUint8List();

      final remoteUrl = await cloudinaryService.uploadImage(
        bytes: bytes,
        fileName: 'avatar_$avatarKey.png',
        folder: 'profile_photos/${user.uid}',
      );
      
      await _saveProfilePhotoUrl(user, remoteUrl);
      
      if (mounted) {
        setState(() {
          _profilePhotoUrl = remoteUrl;
        });
      }
    } catch (e) {
      if (!mounted) {
        return;
      }
      setState(() => _profilePhotoUrl = previousPhotoUrl);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Could not choose avatar: $e')));
    } finally {
      if (mounted) {
        setState(() => _uploadingProfilePhoto = false);
      }
    }
  }

  Future<void> _saveProfilePhotoUrl(User user, String photoUrl) async {
    await user.updatePhotoURL(photoUrl);
    await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
      'uid': user.uid,
      'photoUrl': photoUrl,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    if (!mounted) {
      return;
    }
  }

  String _avatarUrl(String avatarKey, String userId) {
    return _normalAvatarUrl(seed: 'triozy-$avatarKey-$userId', gender: avatarKey);
  }

  String _firstProfilePhotoUrl(
    Map<String, dynamic>? userData, {
    required String fallback,
  }) {
    final candidates = [
      userData?['photoUrl'],
      userData?['profilePhotoUrl'],
      userData?['profileImageUrl'],
      userData?['avatarUrl'],
      userData?['imageUrl'],
      fallback,
    ];

    for (final value in candidates) {
      final url = (value ?? '').toString().trim();
      if (url.isNotEmpty) {
        return url;
      }
    }

    return '';
  }

  String _defaultProfileAvatarUrl(User user) {
    final seed = [
      user.displayName,
      user.email,
      user.uid,
    ].whereType<String>().firstWhere(
      (value) => value.trim().isNotEmpty,
      orElse: () => user.uid,
    );

    return _normalAvatarUrl(seed: 'triozy-profile-$seed', gender: 'neutral');
  }

  Future<void> _saveDraft() async {
    // Persist draft fields for quick recovery on next open.
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('requirement_draft', true);
    await prefs.setString('req_desc', _descController.text);
    await prefs.setString('req_location', _locationController.text);
    if (_latitude != null) await prefs.setDouble('req_lat', _latitude!);
    if (_longitude != null) await prefs.setDouble('req_lon', _longitude!);
  }

  void _selectPresetMoveIn(String value) {
    setState(() {
      _moveIn = value;
      _customMoveInDate = null;
    });
  }

  Future<void> _selectCustomMoveInDate() async {
    final now = DateTime.now();
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: _customMoveInDate ?? now,
      firstDate: now,
      lastDate: now.add(const Duration(days: 365)),
    );

    if (pickedDate == null || !mounted) {
      return;
    }

    final formatted = _formatDateLabel(pickedDate);
    if (_moveIn == formatted && _customMoveInDate == pickedDate) {
      return;
    }

    setState(() {
      _customMoveInDate = pickedDate;
      _moveIn = formatted;
    });
  }

  String _formatDateLabel(DateTime date) {
    const monthNames = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${date.day} ${monthNames[date.month - 1]} ${date.year}';
  }

  PropertyType _propertyTypeForNeed(NeedType needType) {
    switch (needType) {
      case NeedType.pg:
      case NeedType.hostel:
        return PropertyType.pg;
      case NeedType.flat:
        return PropertyType.flat;
      case NeedType.room:
        return PropertyType.room;
    }
  }

  String _listingTargetLabel(NeedType needType) {
    switch (needType) {
      case NeedType.room:
        return 'room';
      case NeedType.flat:
        return 'flat';
      case NeedType.pg:
        return 'PG';
      case NeedType.hostel:
        return 'hostel';
    }
  }

  String _buildListingTitle(NeedType needType, String location, int maxBudget) {
    // Short, friendly title used in listing cards.
    return 'Looking for a ${_listingTargetLabel(needType)} in $location under Rs $maxBudget';
  }

  List<String> _buildHighlights(NeedType needType) {
    // Compact highlights used in feed cards and quick filters.
    final highlights = <String>['Needs ${needType.label}', _moveIn, _occupancy];

    if (_gender != 'Any') {
      highlights.add(_gender);
    }
    if (_amenities.isNotEmpty) {
      highlights.add(_amenities.first);
    } else if (_lifestyle.isNotEmpty) {
      highlights.add(_lifestyle.first);
    }

    return highlights.take(4).toList();
  }

  RequirementModel _buildRequirement({
    required String id,
    required String userId,
    required NeedType needType,
    required String location,
  }) {
    return RequirementModel(
      id: id,
      userId: userId,
      needType: needType,
      location: location,
      minBudget: _minBudget.toInt(),
      maxBudget: _maxBudget.toInt(),
      moveInWhen: _moveIn,
      occupancy: _occupancy,
      genderPreference: _gender,
      description: _descController.text.trim(),
      amenities: _amenities.toList(),
      lifestyle: _lifestyle.toList(),
      contactMethods: _contact.toList(),
    );
  }

  Future<void> _publish() async {
    // Validate, build a requirement listing, and persist to Firestore.
    if (!_formKey.currentState!.validate()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill all required fields')),
      );
      return;
    }
    if (_maxBudget <= 0 || _minBudget > _maxBudget) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Choose a valid budget range')),
      );
      return;
    }
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Sign in to publish')));
      return;
    }

    try {
      final id = const Uuid().v4();
      final db = context.read<DatabaseService>();
      final userData = await db.getUserData(user.uid);
      final ownerName = (userData?['name'] ?? user.displayName ?? '')
          .toString()
          .trim();
      final ownerPhotoUrl = (userData?['photoUrl'] ?? user.photoURL ?? '')
          .toString()
          .trim();
      final selectedPhotoUrl = _profilePhotoUrl.trim().isNotEmpty
          ? _profilePhotoUrl.trim()
          : ownerPhotoUrl;
      final needType = _needTypeNotifier.value;
      final location = _locationController.text.trim();
      final requirement = _buildRequirement(
        id: id,
        userId: user.uid,
        needType: needType,
        location: location,
      );

      // Build a lightweight listing so the requirement shows in feeds.
      final listing = ListingModel(
        id: id,
        ownerId: user.uid,
        ownerName: ownerName.isEmpty ? 'Triozy user' : ownerName,
        ownerPhotoUrl: selectedPhotoUrl,
        title: _buildListingTitle(needType, location, requirement.maxBudget),
        description: requirement.description,
        location: location,
        latitude: _latitude,
        longitude: _longitude,
        price: requirement.maxBudget.toDouble(),
        type: ListingType.housing,
        propertyType: _propertyTypeForNeed(needType),
        imageUrls: const [],
        highlights: _buildHighlights(needType),
        genderPreference: _gender,
        furnishing: _amenities.contains('Furnished') ? 'Furnished' : null,
        availableFrom: _moveIn,
        purpose: ListingPurpose.needPlace,
        phonePublic: _mobilePublic,
        requirementDetails: requirement,
      );

      await db.createListing(listing);
      // Clear draft after a successful publish.
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('requirement_draft');
      await prefs.remove('req_desc');
      await prefs.remove('req_location');
      await prefs.remove('req_lat');
      await prefs.remove('req_lon');
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Your requirement will be published once approved.')));
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Could not publish: $e')));
    }
  }

  // Helper removed: using inline ChoiceChips directly to minimize rebuild scope.

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    final isCompact = screenWidth < 380;
    final horizontalPadding = isCompact ? 12.0 : 16.0;
    final sectionGap = isCompact ? 14.0 : 18.0;
    final labelGap = isCompact ? 6.0 : 8.0;
    final headingSize = isCompact ? 15.0 : 16.0;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Looking For a Place'),
        backgroundColor: Colors.white,
        foregroundColor: AppColors.onSurface,
        elevation: 0,
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: EdgeInsets.fromLTRB(
            horizontalPadding,
            12,
            horizontalPadding,
            24,
          ),
          children: [
            Text(
              'Post your requirement and connect with owners, flatmates, and PG providers.',
              style: AppTheme.body(
                fontSize: isCompact ? 13 : 14,
                color: AppColors.onSurfaceVariant,
              ),
            ),
            SizedBox(height: sectionGap),
            _ProfilePhotoSection(
              photoUrl: _profilePhotoUrl,
              uploading: _uploadingProfilePhoto,
              onUploadTap: _pickProfilePhoto,
              onAvatarTap: _chooseAvatar,
            ),
            SizedBox(height: sectionGap),
            Text('Need Type', style: AppTheme.headline(fontSize: headingSize)),
            SizedBox(height: labelGap),
            ValueListenableBuilder<NeedType>(
              valueListenable: _needTypeNotifier,
              builder: (_, current, _) {
                return Wrap(
                  spacing: isCompact ? 6 : 10,
                  runSpacing: isCompact ? 6 : 8,
                  children: NeedType.values.map((nt) {
                    final selected = nt == current;
                    return ChoiceChip(
                      label: Text(nt.label),
                      selected: selected,
                      onSelected: (_) => _needTypeNotifier.value = nt,
                    );
                  }).toList(),
                );
              },
            ),
            SizedBox(height: sectionGap),
            Text(
              'Preferred location',
              style: AppTheme.headline(fontSize: headingSize),
            ),
            SizedBox(height: labelGap),
            _LocationSearchField(
              controller: _locationController,
              isCompact: isCompact,
              onSelected: (name, lat, lon) {
                _locationController.text = name;
                _latitude = lat;
                _longitude = lon;
              },
            ),
            SizedBox(height: sectionGap),
            Text(
              'Budget range',
              style: AppTheme.headline(fontSize: headingSize),
            ),
            SizedBox(height: labelGap),
            Wrap(
              spacing: isCompact ? 6 : 8,
              runSpacing: isCompact ? 6 : 10,
              children: [
                _BudgetChoiceChip(
                  label: 'Under \u20B95k',
                  selected: _minBudget == 0 && _maxBudget == 5000,
                  onSelected: () => setState(() {
                    _minBudget = 0;
                    _maxBudget = 5000;
                  }),
                ),
                _BudgetChoiceChip(
                  label: '\u20B95k-\u20B910k',
                  selected: _minBudget == 5000 && _maxBudget == 10000,
                  onSelected: () => setState(() {
                    _minBudget = 5000;
                    _maxBudget = 10000;
                  }),
                ),
                _BudgetChoiceChip(
                  label: '\u20B910k-\u20B915k',
                  selected: _minBudget == 10000 && _maxBudget == 15000,
                  onSelected: () => setState(() {
                    _minBudget = 10000;
                    _maxBudget = 15000;
                  }),
                ),
                _BudgetChoiceChip(
                  label: '\u20B915k+',
                  selected: _minBudget == 15000 && _maxBudget == 50000,
                  onSelected: () => setState(() {
                    _minBudget = 15000;
                    _maxBudget = 50000;
                  }),
                ),
              ],
            ),
            SizedBox(height: sectionGap),
            Text(
              'Move-in date',
              style: AppTheme.headline(fontSize: headingSize),
            ),
            SizedBox(height: labelGap),
            Wrap(
              spacing: isCompact ? 6 : 8,
              runSpacing: isCompact ? 6 : 8,
              children: [
                ChoiceChip(
                  label: const Text('Immediately'),

                  selected:
                      _moveIn == 'Immediately' && _customMoveInDate == null,
                  onSelected: (_) => _selectPresetMoveIn('Immediately'),
                ),
                ChoiceChip(
                  label: const Text('Within 7 days'),

                  selected:
                      _moveIn == 'Within 7 days' && _customMoveInDate == null,
                  onSelected: (_) => _selectPresetMoveIn('Within 7 days'),
                ),
                ChoiceChip(
                  label: const Text('This month'),

                  selected:
                      _moveIn == 'This month' && _customMoveInDate == null,
                  onSelected: (_) => _selectPresetMoveIn('This month'),
                ),
                ChoiceChip(
                  label: Text(
                    _customMoveInDate == null
                        ? 'Select date'
                        : _formatDateLabel(_customMoveInDate!),
                  ),
                  selected: _customMoveInDate != null,
                  onSelected: (_) => _selectCustomMoveInDate(),
                ),
              ],
            ),
            SizedBox(height: sectionGap),
            Text(
              'Occupancy type',
              style: AppTheme.headline(fontSize: headingSize),
            ),
            SizedBox(height: labelGap),
            Wrap(
              spacing: isCompact ? 6 : 8,
              runSpacing: isCompact ? 6 : 8,
              children: [
                ChoiceChip(
                  label: const Text('Single'),
                  selected: _occupancy == 'Single',
                  onSelected: (_) => setState(() => _occupancy = 'Single'),
                ),
                ChoiceChip(
                  label: const Text('Shared'),
                  selected: _occupancy == 'Shared',
                  onSelected: (_) => setState(() => _occupancy = 'Shared'),
                ),
                ChoiceChip(
                  label: const Text('Any'),
                  selected: _occupancy == 'Any',
                  onSelected: (_) => setState(() => _occupancy = 'Any'),
                ),
              ],
            ),
            SizedBox(height: sectionGap),
            Text(
              'Gender preference',
              style: AppTheme.headline(fontSize: headingSize),
            ),
            SizedBox(height: labelGap),
            Wrap(
              spacing: isCompact ? 6 : 8,
              runSpacing: isCompact ? 6 : 8,
              children: [
                ChoiceChip(
                  label: const Text('Male'),
                  selected: _gender == 'Male',
                  onSelected: (_) => setState(() => _gender = 'Male'),
                ),
                ChoiceChip(
                  label: const Text('Female'),
                  selected: _gender == 'Female',
                  onSelected: (_) => setState(() => _gender = 'Female'),
                ),
                ChoiceChip(
                  label: const Text('Any'),
                  selected: _gender == 'Any',
                  onSelected: (_) => setState(() => _gender = 'Any'),
                ),
              ],
            ),
            SizedBox(height: sectionGap),
            _MobileVisibilityCard(
              isPublic: _mobilePublic,
              onChanged: (value) => setState(() => _mobilePublic = value),
            ),
            SizedBox(height: sectionGap),
            Text(
              'Short description',
              style: AppTheme.headline(fontSize: headingSize),
            ),
            SizedBox(height: labelGap),
            TextFormField(
              controller: _descController,
              maxLines: 5,
              decoration: InputDecoration(
                isDense: true,
                hintText:
                    'Need single room near Vijay Nagar. Working professional. Budget 8k.',
                filled: true,
                fillColor: Colors.white,
                contentPadding: EdgeInsets.all(isCompact ? 12 : 14),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
              validator: (v) => (v == null || v.trim().isEmpty)
                  ? 'Add a short description'
                  : null,
            ),
            SizedBox(height: labelGap),
            ValueListenableBuilder<TextEditingValue>(
              valueListenable: _descController,
              builder: (_, value, _) {
                return Row(
                  children: [
                    Text(
                      '${value.text.length}/280',
                      style: AppTheme.label(fontSize: isCompact ? 11 : 12),
                    ),
                  ],
                );
              },
            ),
            SizedBox(height: sectionGap),
            Text(
              'Optional preferences',
              style: AppTheme.headline(fontSize: headingSize),
            ),
            SizedBox(height: labelGap),
            Wrap(
              spacing: isCompact ? 6 : 8,
              runSpacing: isCompact ? 6 : 8,
              children: [
                FilterChip(
                  label: const Text('WiFi'),
                  selected: _amenities.contains('WiFi'),
                  onSelected: (s) => setState(
                    () =>
                        s ? _amenities.add('WiFi') : _amenities.remove('WiFi'),
                  ),
                ),
                FilterChip(
                  label: const Text('AC'),
                  selected: _amenities.contains('AC'),
                  onSelected: (s) => setState(
                    () => s ? _amenities.add('AC') : _amenities.remove('AC'),
                  ),
                ),
                FilterChip(
                  label: const Text('Attached Bathroom'),
                  selected: _amenities.contains('Attached Bathroom'),
                  onSelected: (s) => setState(
                    () => s
                        ? _amenities.add('Attached Bathroom')
                        : _amenities.remove('Attached Bathroom'),
                  ),
                ),
                FilterChip(
                  label: const Text('Parking'),
                  selected: _amenities.contains('Parking'),
                  onSelected: (s) => setState(
                    () => s
                        ? _amenities.add('Parking')
                        : _amenities.remove('Parking'),
                  ),
                ),
                FilterChip(
                  label: const Text('Kitchen'),
                  selected: _amenities.contains('Kitchen'),
                  onSelected: (s) => setState(
                    () => s
                        ? _amenities.add('Kitchen')
                        : _amenities.remove('Kitchen'),
                  ),
                ),
                FilterChip(
                  label: const Text('Furnished'),
                  selected: _amenities.contains('Furnished'),
                  onSelected: (s) => setState(
                    () => s
                        ? _amenities.add('Furnished')
                        : _amenities.remove('Furnished'),
                  ),
                ),
              ],
            ),
            SizedBox(height: labelGap),
            Wrap(
              spacing: isCompact ? 6 : 8,
              runSpacing: isCompact ? 6 : 8,
              children: [
                FilterChip(
                  label: const Text('Non-smoker'),
                  selected: _lifestyle.contains('Non-smoker'),
                  onSelected: (s) => setState(
                    () => s
                        ? _lifestyle.add('Non-smoker')
                        : _lifestyle.remove('Non-smoker'),
                  ),
                ),
                FilterChip(
                  label: const Text('Veg'),
                  selected: _lifestyle.contains('Veg'),
                  onSelected: (s) => setState(
                    () => s ? _lifestyle.add('Veg') : _lifestyle.remove('Veg'),
                  ),
                ),
                FilterChip(
                  label: const Text('Student friendly'),
                  selected: _lifestyle.contains('Student friendly'),
                  onSelected: (s) => setState(
                    () => s
                        ? _lifestyle.add('Student friendly')
                        : _lifestyle.remove('Student friendly'),
                  ),
                ),
                FilterChip(
                  label: const Text('Working professional preferred'),
                  selected: _lifestyle.contains(
                    'Working professional preferred',
                  ),
                  onSelected: (s) => setState(
                    () => s
                        ? _lifestyle.add('Working professional preferred')
                        : _lifestyle.remove('Working professional preferred'),
                  ),
                ),
              ],
            ),
            SizedBox(height: sectionGap),
            Text(
              'Contact preference',
              style: AppTheme.headline(fontSize: headingSize),
            ),
            SizedBox(height: labelGap),
            Wrap(
              spacing: isCompact ? 6 : 8,
              runSpacing: isCompact ? 6 : 8,
              children: [
                FilterChip(
                  label: const Text('In-app Chat'),
                  showCheckmark: false,
                  selected: _contact.contains('In-app Chat'),
                  onSelected: (selected) => setState(
                    () => selected
                        ? _contact.add('In-app Chat')
                        : _contact.remove('In-app Chat'),
                  ),
                ),
                FilterChip(
                  label: const Text('WhatsApp'),
                  showCheckmark: false,
                  selected: _contact.contains('WhatsApp'),
                  onSelected: (selected) => setState(
                    () => selected
                        ? _contact.add('WhatsApp')
                        : _contact.remove('WhatsApp'),
                  ),
                ),
                FilterChip(
                  label: const Text('Call'),
                  showCheckmark: false,
                  selected: _contact.contains('Call'),
                  onSelected: (selected) => setState(
                    () => selected
                        ? _contact.add('Call')
                        : _contact.remove('Call'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      bottomNavigationBar: AnimatedPadding(
        duration: const Duration(milliseconds: 200),
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: SafeArea(
          top: false,
          child: Container(
            padding: EdgeInsets.fromLTRB(
              horizontalPadding,
              10,
              horizontalPadding,
              14,
            ),
            decoration: const BoxDecoration(
              color: AppColors.surfaceContainerLowest,
              border: Border(top: BorderSide(color: AppColors.outlineVariant)),
            ),
            child: SizedBox(
              width: double.infinity,
              height: isCompact ? 50 : 54,
              child: AnimatedBuilder(
                animation: Listenable.merge([_locationController, _descController]),
                builder: (context, _) {
                  final isValid = _locationController.text.trim().isNotEmpty &&
                      _descController.text.trim().isNotEmpty;
                  
                  return ElevatedButton(
                    onPressed: isValid ? _publish : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: AppColors.onPrimary,
                      disabledBackgroundColor: AppColors.surfaceContainerHigh,
                      disabledForegroundColor: AppColors.outline,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      'Publish Requirement',
                      style: AppTheme.body(
                        fontSize: isCompact ? 15 : 16,
                        fontWeight: FontWeight.w800,
                        color: isValid ? AppColors.onPrimary : AppColors.outline,
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _MobileVisibilityCard extends StatelessWidget {
  /// Card for selecting whether to show phone number publicly.
  final bool isPublic;
  final ValueChanged<bool> onChanged;

  const _MobileVisibilityCard({
    required this.isPublic,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isCompact = constraints.maxWidth < 340;

        return Container(
          padding: EdgeInsets.fromLTRB(
            isCompact ? 14 : 16,
            isCompact ? 16 : 18,
            isCompact ? 14 : 16,
            isCompact ? 16 : 18,
          ),
          decoration: BoxDecoration(
            color: AppColors.secondaryContainer,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Make your mobile number visible to other users?',
                style: AppTheme.body(
                  fontSize: isCompact ? 15 : 16,
                  fontWeight: FontWeight.w800,
                  height: 1.25,
                  color: AppColors.onSurface,
                ),
              ),
              SizedBox(height: isCompact ? 14 : 16),
              if (isCompact)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _VisibilityButton(
                      text: 'Yes, public',
                      selected: isPublic,
                      onTap: () => onChanged(true),
                    ),
                    const SizedBox(height: 10),
                    _VisibilityButton(
                      text: 'No, private',
                      selected: !isPublic,
                      onTap: () => onChanged(false),
                    ),
                  ],
                )
              else
                Row(
                  children: [
                    Expanded(
                      child: _VisibilityButton(
                        text: 'Yes, public',
                        selected: isPublic,
                        onTap: () => onChanged(true),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _VisibilityButton(
                        text: 'No, private',
                        selected: !isPublic,
                        onTap: () => onChanged(false),
                      ),
                    ),
                  ],
                ),
              SizedBox(height: isCompact ? 14 : 16),
              Text(
                'Note: If your mobile number is private, others can contact you only through chat.',
                style: AppTheme.body(
                  fontSize: 12,
                  height: 1.35,
                  color: AppColors.onSurfaceVariant,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _VisibilityButton extends StatelessWidget {
  /// Toggle button used in the mobile visibility section.
  final String text;
  final bool selected;
  final VoidCallback onTap;

  const _VisibilityButton({
    required this.text,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isCompact = MediaQuery.sizeOf(context).width < 380;

    return SizedBox(
      height: isCompact ? 46 : 48,
      child: ElevatedButton(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          elevation: 0,
          backgroundColor: selected
              ? AppColors.primary
              : AppColors.surfaceContainerHigh,
          foregroundColor: selected ? AppColors.onPrimary : AppColors.onSurface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
        child: Text(
          text,
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: AppTheme.body(
            fontSize: isCompact ? 13 : 14,
            height: 1.15,
            fontWeight: FontWeight.w700,
            color: selected ? AppColors.onPrimary : AppColors.onSurface,
          ),
        ),
      ),
    );
  }
}

/// Location input with inline search suggestions overlay.
class _LocationSearchField extends StatefulWidget {
  final TextEditingController controller;
  final bool isCompact;
  final void Function(String name, double lat, double lon)? onSelected;

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
          borderRadius: BorderRadius.circular(12),
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
          borderRadius: BorderRadius.circular(12),
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
                          
                          final lat = double.tryParse(place['lat']?.toString() ?? '') ?? 0.0;
                          final lon = double.tryParse(place['lon']?.toString() ?? '') ?? 0.0;

                          if (widget.onSelected != null) {
                            widget.onSelected!(shortName, lat, lon);
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
      child: TextFormField(
        focusNode: _focusNode,
        controller: widget.controller,
        onChanged: _provider.onSearchChanged,
        decoration: InputDecoration(
          isDense: true,
          prefixIcon: const Icon(Icons.place_rounded),
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
          hintText: 'Search locality, college, office area...',
          filled: true,
          fillColor: Colors.white,
          contentPadding: EdgeInsets.symmetric(
            horizontal: widget.isCompact ? 12 : 14,
            vertical: widget.isCompact ? 12 : 14,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
        ),
        validator: (v) =>
            (v == null || v.trim().isEmpty) ? 'Enter a location' : null,
      ),
    );
  }
}

/// Budget chip used in the requirement budget selector.
class _BudgetChoiceChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onSelected;

  const _BudgetChoiceChip({
    required this.label,
    required this.selected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final isCompact = MediaQuery.sizeOf(context).width < 380;

    return ChoiceChip(
      label: Text(label),
      selected: selected,
      labelStyle: AppTheme.label(fontSize: isCompact ? 12 : 13),
      visualDensity: isCompact ? VisualDensity.compact : VisualDensity.standard,
      onSelected: (_) => onSelected(),
    );
  }
}

/// Builds the Dicebear avatar URL based on seed and gender.
String _normalAvatarUrl({required String seed, required String gender}) {
  final isFemale = gender == 'female';
  final isMale = gender == 'male';

  return Uri.https('api.dicebear.com', '/9.x/avataaars/png', {
    'seed': seed,
    'size': '256',
    'radius': '50',
    'backgroundColor': 'dbeafe',
    'accessoriesProbability': '0',
    'facialHairProbability': isMale ? '100' : '0',
    'top': isFemale ? 'longHair' : 'shortHairShortFlat',
    'hairColor': '2c1b18',
    'facialHair': 'beardMedium',
    'facialHairColor': '2c1b18',
    'eyes': 'default',
    'eyebrows': 'default',
    'mouth': 'smile',
    'skinColor': 'edb98a',
    'clothing': isFemale ? 'shirtScoopNeck' : 'shirtVNeck',
    'clothesColor': isFemale ? '614335' : '2563eb',
  }).toString();
}

/// Profile photo upload/selection block for the requirement form.
class _ProfilePhotoSection extends StatelessWidget {
  final String photoUrl;
  final bool uploading;
  final VoidCallback onUploadTap;
  final ValueChanged<String> onAvatarTap;

  const _ProfilePhotoSection({
    required this.photoUrl,
    required this.uploading,
    required this.onUploadTap,
    required this.onAvatarTap,
  });

  @override
  Widget build(BuildContext context) {
    final imageUrl = photoUrl.trim();
    final isCompact = MediaQuery.sizeOf(context).width < 380;
    final avatarRadius = isCompact ? 28.0 : 34.0;
    final avatarIconSize = isCompact ? 28.0 : 34.0;
    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Profile photo',
          style: AppTheme.headline(
            fontSize: isCompact ? 15 : 16,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Upload your photo or choose an avatar.',
          style: AppTheme.body(
            fontSize: isCompact ? 11 : 12,
            fontWeight: FontWeight.w500,
            color: AppColors.onSurfaceVariant,
          ),
        ),
        SizedBox(height: isCompact ? 8 : 10),
        Wrap(
          spacing: isCompact ? 6 : 8,
          runSpacing: isCompact ? 6 : 8,
          children: [
            _ProfilePhotoActionChip(
              icon: Icons.upload_rounded,
              label: 'Upload',
              onTap: uploading ? null : onUploadTap,
            ),
          ],
        ),
        SizedBox(height: isCompact ? 8 : 10),
        Wrap(
          spacing: isCompact ? 10 : 12,
          runSpacing: 8,
          children: [
            _PresetAvatarButton(
              label: 'Female',
              assetPath: 'assets/images/female avtar.png',
              onTap: uploading ? null : () => onAvatarTap('female'),
            ),
            _PresetAvatarButton(
              label: 'Male',
              assetPath: 'assets/images/male avtar.png',
              onTap: uploading ? null : () => onAvatarTap('male'),
            ),
          ],
        ),
      ],
    );

    return Container(
      padding: EdgeInsets.all(isCompact ? 12 : 14),
      decoration: AppTheme.cardDecoration(
        color: Colors.white,
        radiusValue: isCompact ? 16 : 18,
        shadowAlpha: 0.03,
        blur: 14,
        offsetY: 6,
      ),
      child: Flex(
        direction: isCompact ? Axis.vertical : Axis.horizontal,
        crossAxisAlignment:
            isCompact ? CrossAxisAlignment.start : CrossAxisAlignment.center,
        children: [
          Stack(
            alignment: Alignment.center,
            children: [
              CircleAvatar(
                key: ValueKey(imageUrl),
                radius: avatarRadius,
                backgroundColor: AppColors.surfaceContainerLow,
                backgroundImage: imageUrl.isEmpty
                    ? null
                    : imageUrl.startsWith('assets/')
                        ? AssetImage(imageUrl) as ImageProvider
                        : NetworkImage(imageUrl) as ImageProvider,
                child: imageUrl.isEmpty && !uploading
                    ? Icon(
                        Icons.person_rounded,
                        color: AppColors.slate500,
                        size: avatarIconSize,
                      )
                    : null,
              ),
              if (uploading)
                const SizedBox(
                  width: 30,
                  height: 30,
                  child: CircularProgressIndicator(strokeWidth: 2.4),
                ),
            ],
          ),
          SizedBox(width: isCompact ? 0 : 14, height: isCompact ? 10 : 0),
          if (isCompact) content else Expanded(child: content),
        ],
      ),
    );
  }
}

/// Action chip for profile photo actions (upload, etc.).
class _ProfilePhotoActionChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  const _ProfilePhotoActionChip({
    required this.icon,
    required this.label,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isCompact = MediaQuery.sizeOf(context).width < 380;

    return ActionChip(
      avatar: Icon(icon, size: isCompact ? 14 : 16, color: AppColors.primary),
      label: Text(label),
      onPressed: onTap,
      visualDensity: isCompact ? VisualDensity.compact : VisualDensity.standard,
      backgroundColor: AppColors.surfaceContainerLowest,
      side: BorderSide(color: AppColors.outlineVariant.withValues(alpha: 0.42)),
      labelStyle: AppTheme.label(
        fontSize: isCompact ? 11 : 12,
        fontWeight: FontWeight.w700,
        color: AppColors.primary,
      ),
    );
  }
}

/// Selectable preset avatar option.
class _PresetAvatarButton extends StatelessWidget {
  final String label;
  final String assetPath;
  final VoidCallback? onTap;

  const _PresetAvatarButton({
    required this.label,
    required this.assetPath,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isCompact = MediaQuery.sizeOf(context).width < 380;
    final size = isCompact ? 56.0 : 64.0;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFFEEF2FF),
              border: Border.all(
                color: AppColors.primary.withValues(alpha: 0.25),
                width: 2,
              ),
            ),
            clipBehavior: Clip.antiAlias,
            child: Image.asset(
              assetPath,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => const Icon(
                Icons.person_rounded,
                color: AppColors.primary,
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: AppTheme.label(
              fontSize: isCompact ? 10 : 11,
              fontWeight: FontWeight.w700,
              color: AppColors.primary,
            ),
          ),
        ],
      ),
    );
  }
}
