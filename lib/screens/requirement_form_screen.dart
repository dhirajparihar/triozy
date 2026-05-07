import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/listing_model.dart';
import '../models/requirement_model.dart';
import '../services/database_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';

class RequirementFormScreen extends StatefulWidget {
  const RequirementFormScreen({super.key});

  @override
  State<RequirementFormScreen> createState() => _RequirementFormScreenState();
}

class _RequirementFormScreenState extends State<RequirementFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final ValueNotifier<NeedType> _needTypeNotifier = ValueNotifier(
    NeedType.room,
  );
  final TextEditingController _locationController = TextEditingController();
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

  Timer? _autosaveTimer;

  @override
  void initState() {
    super.initState();
    _loadDraft();
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
    _autosaveTimer?.cancel();
    _autosaveTimer = Timer(const Duration(seconds: 1), _saveDraft);
  }

  Future<void> _loadDraft() async {
    final prefs = await SharedPreferences.getInstance();
    final hasDraft = prefs.getBool('requirement_draft') ?? false;
    if (!hasDraft) return;
    try {
      _descController.text = prefs.getString('req_desc') ?? '';
      _locationController.text = prefs.getString('req_location') ?? '';
      setState(() {});
    } catch (_) {}
  }

  Future<void> _saveDraft() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('requirement_draft', true);
    await prefs.setString('req_desc', _descController.text);
    await prefs.setString('req_location', _locationController.text);
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
    return 'Looking for a ${_listingTargetLabel(needType)} in $location under Rs $maxBudget';
  }

  List<String> _buildHighlights(NeedType needType) {
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
    if (!_formKey.currentState!.validate()) return;
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
      final needType = _needTypeNotifier.value;
      final location = _locationController.text.trim();
      final requirement = _buildRequirement(
        id: id,
        userId: user.uid,
        needType: needType,
        location: location,
      );

      final listing = ListingModel(
        id: id,
        ownerId: user.uid,
        ownerName: ownerName.isEmpty ? 'Triozy user' : ownerName,
        ownerPhotoUrl: ownerPhotoUrl,
        title: _buildListingTitle(needType, location, requirement.maxBudget),
        description: requirement.description,
        location: location,
        price: requirement.maxBudget.toDouble(),
        type: ListingType.housing,
        propertyType: _propertyTypeForNeed(needType),
        imageUrls: const [],
        highlights: _buildHighlights(needType),
        genderPreference: _gender,
        furnishing: _amenities.contains('Furnished') ? 'Furnished' : null,
        availableFrom: _moveIn,
        purpose: ListingPurpose.needPlace,
        requirementDetails: requirement,
      );

      await db.createListing(listing);
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('requirement_draft');
      await prefs.remove('req_desc');
      await prefs.remove('req_location');
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Requirement published')));
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
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          children: [
            Text(
              'Post your requirement and connect with owners, flatmates, and PG providers.',
              style: AppTheme.body(
                fontSize: 14,
                color: AppColors.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 18),
            Text('Need Type', style: AppTheme.headline(fontSize: 16)),
            const SizedBox(height: 8),
            ValueListenableBuilder<NeedType>(
              valueListenable: _needTypeNotifier,
              builder: (_, current, _) {
                return Wrap(
                  spacing: 10,
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
            const SizedBox(height: 18),
            Text('Preferred location', style: AppTheme.headline(fontSize: 16)),
            const SizedBox(height: 8),
            TextFormField(
              controller: _locationController,
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.place_rounded),
                hintText: 'Search locality, college, office area...',
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Enter a location' : null,
            ),
            const SizedBox(height: 18),
            Text('Budget range', style: AppTheme.headline(fontSize: 16)),
            const SizedBox(height: 8),
            Row(
              children: [
                Text(
                  'Selected: ₹${_minBudget.toInt()} - ₹${_maxBudget.toInt()}',
                  style: AppTheme.body(fontSize: 14),
                ),
              ],
            ),
            Wrap(
              spacing: 8,
              children: [
                ElevatedButton(
                  onPressed: () => setState(() {
                    _minBudget = 0;
                    _maxBudget = 5000;
                  }),
                  child: const Text('Under ₹5k'),
                ),
                ElevatedButton(
                  onPressed: () => setState(() {
                    _minBudget = 5000;
                    _maxBudget = 10000;
                  }),
                  child: const Text('₹5k–₹10k'),
                ),
                ElevatedButton(
                  onPressed: () => setState(() {
                    _minBudget = 10000;
                    _maxBudget = 15000;
                  }),
                  child: const Text('₹10k–₹15k'),
                ),
                ElevatedButton(
                  onPressed: () => setState(() {
                    _minBudget = 15000;
                    _maxBudget = 50000;
                  }),
                  child: const Text('₹15k+'),
                ),
              ],
            ),
            const SizedBox(height: 18),
            Text('Move-in date', style: AppTheme.headline(fontSize: 16)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
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
            const SizedBox(height: 18),
            Text('Occupancy type', style: AppTheme.headline(fontSize: 16)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
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
            const SizedBox(height: 18),
            Text('Gender preference', style: AppTheme.headline(fontSize: 16)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
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
            const SizedBox(height: 18),
            Text('Short description', style: AppTheme.headline(fontSize: 16)),
            const SizedBox(height: 8),
            TextFormField(
              controller: _descController,
              maxLines: 5,
              decoration: InputDecoration(
                hintText:
                    'Need single room near Vijay Nagar. Working professional. Budget 8k.',
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
              validator: (v) => (v == null || v.trim().isEmpty)
                  ? 'Add a short description'
                  : null,
            ),
            const SizedBox(height: 8),
            ValueListenableBuilder<TextEditingValue>(
              valueListenable: _descController,
              builder: (_, value, _) {
                return Row(
                  children: [
                    Text(
                      '${value.text.length}/280',
                      style: AppTheme.label(fontSize: 12),
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 18),
            Text(
              'Optional preferences',
              style: AppTheme.headline(fontSize: 16),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
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
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
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
            const SizedBox(height: 18),
            Text('Contact preference', style: AppTheme.headline(fontSize: 16)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
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
          child: Container(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            color: Colors.white,
            child: SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: _publish,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  'Publish Requirement',
                  style: AppTheme.body(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
