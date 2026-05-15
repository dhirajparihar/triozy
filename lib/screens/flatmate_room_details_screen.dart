import 'dart:typed_data';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

import '../models/listing_model.dart';
import '../services/cloudinary_service.dart';
import '../services/database_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../providers/location_search_provider.dart';

class FlatmateRoomDetailsScreen extends StatefulWidget {
  const FlatmateRoomDetailsScreen({super.key});

  @override
  State<FlatmateRoomDetailsScreen> createState() =>
      _FlatmateRoomDetailsScreenState();
}

class _FlatmateRoomDetailsScreenState extends State<FlatmateRoomDetailsScreen> {
  static const int _maxImageCount = 3;
  static const int _maxImageBytes = 10 * 1024 * 1024;

  final _formKey = GlobalKey<FormState>();
  final _locationController = TextEditingController();
  final _rentController = TextEditingController(text: '5000');
  final _descriptionController = TextEditingController(
    text: 'I am looking for roommates for my room.',
  );
  final _picker = ImagePicker();
  final List<XFile> _pickedImages = [];
  final Set<String> _selectedHighlights = {};
  final Set<String> _selectedAmenities = {};
  double? _latitude;
  double? _longitude;

  String _occupancy = 'Single';
  String _lookingFor = 'Male';
  bool _mobilePublic = true;
  bool _submitting = false;

  static const List<String> _highlightOptions = [
    'Attached washroom',
    'Market nearby',
    'Attached balcony',
    'Close to metro station',
    'Public transport nearby',
    'Gated society',
    'No Restriction',
    'Newly built',
    'Separate washrooms',
    'House keeping',
    'Gym nearby',
    'Park nearby',
  ];

  static const List<_AmenityOption> _amenityOptions = [
    _AmenityOption('TV', Icons.tv_rounded),
    _AmenityOption('Fridge', Icons.kitchen_rounded),
    _AmenityOption('Kitchen', Icons.restaurant_rounded),
    _AmenityOption('Wifi', Icons.wifi_rounded),
    _AmenityOption('Machine', Icons.local_laundry_service_rounded),
    _AmenityOption('AC', Icons.ac_unit_rounded),
    _AmenityOption('Power Backup', Icons.battery_charging_full_rounded),
    _AmenityOption('Cook', Icons.room_service_rounded),
    _AmenityOption('Parking', Icons.local_parking_rounded),
  ];

  @override
  void dispose() {
    _locationController.dispose();
    _rentController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _pickImages() async {
    final messenger = ScaffoldMessenger.of(context);
    final remainingSlots = _maxImageCount - _pickedImages.length;
    if (remainingSlots <= 0) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Only 3 images can be uploaded')),
      );
      return;
    }

    final images = await _picker.pickMultiImage(
      imageQuality: 82,
      limit: remainingSlots,
    );
    if (images.isEmpty) {
      return;
    }

    final accepted = <XFile>[];
    final existingPaths = _pickedImages.map((image) => image.path).toSet();
    var rejectedOversize = false;
    var rejectedDuplicate = false;
    for (final image in images.take(remainingSlots)) {
      final size = await image.length();
      if (size > _maxImageBytes) {
        rejectedOversize = true;
        continue;
      }
      if (existingPaths.contains(image.path)) {
        rejectedDuplicate = true;
        continue;
      }
      accepted.add(image);
      existingPaths.add(image.path);
    }

    if (!mounted) {
      return;
    }
    setState(() {
      _pickedImages.addAll(accepted);
    });

    if (images.length > remainingSlots || _pickedImages.length >= _maxImageCount) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Only 3 images can be uploaded')),
      );
    } else if (rejectedOversize) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Each image must be 10 MB or smaller')),
      );
    } else if (rejectedDuplicate) {
      messenger.showSnackBar(
        const SnackBar(content: Text('This image is already selected')),
      );
    }
  }

  Future<List<String>> _uploadImages(String listingId) async {
    if (_pickedImages.isEmpty) {
      return [];
    }

    final cloudinary = context.read<CloudinaryService>();
    final urls = <String>[];
    for (final image in _pickedImages) {
      final bytes = await image.readAsBytes();
      final url = await cloudinary.uploadImage(
        bytes: Uint8List.fromList(bytes),
        fileName: image.name,
        folder: 'listings/$listingId',
      );
      urls.add(url);
    }
    return urls;
  }

  List<String> _buildHighlights() {
    return <String>[
      _occupancy,
      'Looking for $_lookingFor',
      ..._selectedHighlights,
      ..._selectedAmenities,
      _mobilePublic ? 'Mobile public' : 'Chat only',
    ].take(8).toList();
  }

  Future<void> _submit() async {
    final user = FirebaseAuth.instance.currentUser;
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    if (user == null) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Sign in to add room details')),
      );
      return;
    }
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() => _submitting = true);
    try {
      final listingId = const Uuid().v4();
      final database = context.read<DatabaseService>();
      final userData = await database.getUserData(user.uid);
      final ownerName = (userData?['name'] ?? user.displayName ?? '')
          .toString()
          .trim();
      final ownerPhotoUrl = (userData?['photoUrl'] ?? user.photoURL ?? '')
          .toString()
          .trim();
      final location = _locationController.text.trim();
      final rent = double.parse(_rentController.text.trim());
      final imageUrls = await _uploadImages(listingId);

      final listing = ListingModel(
        id: listingId,
        ownerId: user.uid,
        ownerName: ownerName.isEmpty ? 'Triozy user' : ownerName,
        ownerPhotoUrl: ownerPhotoUrl,
        title: 'Roommate needed in $location',
        description: _descriptionController.text.trim(),
        location: location,
        latitude: _latitude,
        longitude: _longitude,
        price: rent,
        type: ListingType.housing,
        propertyType: PropertyType.room,
        imageUrls: imageUrls,
        highlights: _buildHighlights(),
        genderPreference: _lookingFor,
        furnishing: _selectedAmenities.isEmpty ? null : 'With amenities',
        availableFrom: 'Available now',
        purpose: ListingPurpose.needRoommate,
      );

      await database.createListing(listing);
      if (!mounted) {
        return;
      }
      messenger.showSnackBar(
        const SnackBar(content: Text('Room details added')),
      );
      navigator.pop(true);
    } catch (e) {
      if (!mounted) {
        return;
      }
      messenger.showSnackBar(
        SnackBar(content: Text('Could not add room details: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _submitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    final isCompact = screenWidth < 380;
    final horizontalPadding = isCompact ? 14.0 : 16.0;
    final sectionGap = isCompact ? 28.0 : 34.0;
    final labelGap = isCompact ? 10.0 : 12.0;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Add Room Details'),
        backgroundColor: AppColors.background,
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
            28,
          ),
          children: [
              Text(
                'Share your room details so compatible flatmates can contact you.',
                style: AppTheme.body(
                  fontSize: 14,
                  color: AppColors.onSurfaceVariant,
                ),
              ),
              SizedBox(height: sectionGap * 0.55),
              _FieldLabel('Your Location'),
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
              _FieldLabel('Rent per Person'),
              SizedBox(height: labelGap),
              _UnderlineTextField(
                controller: _rentController,
                keyboardType: TextInputType.number,
                prefix: Text(
                  '₹',
                  style: AppTheme.body(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: AppColors.onSurface,
                ),
                ),
                validator: (value) {
                  final rent = double.tryParse((value ?? '').trim());
                  if (rent == null || rent <= 0) {
                    return 'Enter a valid rent';
                  }
                  return null;
                },
              ),
              SizedBox(height: sectionGap),
              _FieldLabel('Upload 3 Images'),
              SizedBox(height: labelGap),
              Text(
                '*Each image size should not exceed 10 MB',
                style: AppTheme.body(
                  fontSize: 13,
                  height: 1.35,
                  color: AppColors.onSurfaceVariant,
                ),
              ),
              SizedBox(height: labelGap + 4),
              _ImagePickerGrid(images: _pickedImages, onTap: _pickImages),
              SizedBox(height: sectionGap),
              _DropdownLine(
                label: 'Occupancy per room',
                value: _occupancy,
                values: const ['Single', 'Double', 'Triple'],
                onChanged: (value) => setState(() => _occupancy = value),
              ),
              SizedBox(height: sectionGap),
              _DropdownLine(
                label: 'Looking for',
                value: _lookingFor,
                values: const ['Male', 'Female', 'Any'],
                onChanged: (value) => setState(() => _lookingFor = value),
              ),
              SizedBox(height: sectionGap),
              _FieldLabel('Choose highlights for your property'),
              SizedBox(height: labelGap + 4),
              Wrap(
                spacing: isCompact ? 8 : 10,
                runSpacing: isCompact ? 8 : 10,
                children: _highlightOptions.map((highlight) {
                  final selected = _selectedHighlights.contains(highlight);
                  return _PillChoice(
                    label: highlight,
                    selected: selected,
                    onTap: () => setState(() {
                      selected
                          ? _selectedHighlights.remove(highlight)
                          : _selectedHighlights.add(highlight);
                    }),
                  );
                }).toList(),
              ),
              SizedBox(height: sectionGap),
              _FieldLabel('Amenities'),
              SizedBox(height: labelGap + 4),
              _AmenitiesGrid(
                options: _amenityOptions,
                selected: _selectedAmenities,
                onTap: (label) => setState(() {
                  _selectedAmenities.contains(label)
                      ? _selectedAmenities.remove(label)
                      : _selectedAmenities.add(label);
                }),
              ),
              SizedBox(height: sectionGap),
              _MobileVisibilityCard(
                isPublic: _mobilePublic,
                onChanged: (value) => setState(() => _mobilePublic = value),
              ),
              SizedBox(height: sectionGap),
              _FieldLabel('Description'),
              SizedBox(height: labelGap),
              TextFormField(
                controller: _descriptionController,
                maxLines: 3,
                minLines: 1,
                style: AppTheme.body(
                  fontSize: isCompact ? 17 : 18,
                  fontWeight: FontWeight.w700,
                  color: AppColors.onSurface,
                ),
                decoration: const InputDecoration(
                  border: UnderlineInputBorder(
                    borderSide: BorderSide(color: AppColors.outlineVariant),
                  ),
                  enabledBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: AppColors.outlineVariant),
                  ),
                  focusedBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: AppColors.primary),
                  ),
                  contentPadding: EdgeInsets.only(bottom: 10),
                ),
                validator: (value) {
                  if ((value ?? '').trim().isEmpty) {
                    return 'Add a description';
                  }
                  return null;
                },
              ),
            ],
          ),
      ),
      bottomNavigationBar: SafeArea(
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
            child: ElevatedButton(
              onPressed: _submitting ? null : _submit,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: AppColors.onPrimary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: _submitting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.onPrimary,
                      ),
                    )
                  : Text(
                      'Add Room Details',
                      style: AppTheme.body(
                        fontSize: isCompact ? 15 : 16,
                        fontWeight: FontWeight.w800,
                        color: AppColors.onPrimary,
                      ),
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  final String text;

  const _FieldLabel(this.text);

  @override
  Widget build(BuildContext context) {
    final isCompact = MediaQuery.sizeOf(context).width < 380;

    return Text(
      text,
      style: AppTheme.body(
        fontSize: isCompact ? 16 : 17,
        fontWeight: FontWeight.w700,
        color: AppColors.onSurface,
        letterSpacing: 0,
      ),
    );
  }
}

class _UnderlineTextField extends StatelessWidget {
  final TextEditingController controller;
  final Widget? prefix;
  final TextInputType? keyboardType;
  final String? Function(String?)? validator;

  const _UnderlineTextField({
    required this.controller,
    this.prefix,
    this.keyboardType,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    final isCompact = MediaQuery.sizeOf(context).width < 380;

    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      validator: validator,
      style: AppTheme.body(
        fontSize: isCompact ? 17 : 18,
        fontWeight: FontWeight.w700,
        color: AppColors.onSurface,
      ),
      decoration: InputDecoration(
        isDense: true,
        hintStyle: AppTheme.body(
          fontSize: isCompact ? 15 : 16,
          height: 1.1,
          fontWeight: FontWeight.w600,
          color: AppColors.slate400,
        ),
        prefixIcon: prefix == null
            ? null
            : Padding(padding: const EdgeInsets.only(right: 12), child: prefix),
        prefixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 32),
        contentPadding: const EdgeInsets.only(bottom: 2),
        border: const UnderlineInputBorder(
          borderSide: BorderSide(color: AppColors.outlineVariant),
        ),
        enabledBorder: const UnderlineInputBorder(
          borderSide: BorderSide(color: AppColors.outlineVariant),
        ),
        focusedBorder: const UnderlineInputBorder(
          borderSide: BorderSide(color: AppColors.primary, width: 2),
        ),
      ),
    );
  }
}

class _ImagePickerGrid extends StatelessWidget {
  final List<XFile> images;
  final VoidCallback onTap;

  const _ImagePickerGrid({required this.images, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isCompact = constraints.maxWidth < 360;
        final gap = isCompact ? 8.0 : 10.0;
        final cellWidth = (constraints.maxWidth - gap) / 2;
        final gridHeight = cellWidth * (isCompact ? 1.14 : 1.22);
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: cellWidth,
              height: gridHeight,
              child: _ImageSlot(
                image: images.isNotEmpty ? images[0] : null,
                onTap: onTap,
              ),
            ),
            SizedBox(width: gap),
            SizedBox(
              width: cellWidth,
              child: Column(
                children: [
                  SizedBox(
                    height: (gridHeight - gap) / 2,
                    child: _ImageSlot(
                      image: images.length > 1 ? images[1] : null,
                      onTap: onTap,
                    ),
                  ),
                  SizedBox(height: gap),
                  SizedBox(
                    height: (gridHeight - gap) / 2,
                    child: _ImageSlot(
                      image: images.length > 2 ? images[2] : null,
                      onTap: onTap,
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

class _ImageSlot extends StatelessWidget {
  final XFile? image;
  final VoidCallback onTap;

  const _ImageSlot({required this.image, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Container(
          color: AppColors.surfaceContainerHigh,
          child: image == null
              ? const Center(
                  child: Icon(
                    Icons.add_photo_alternate_outlined,
                    size: 42,
                    color: AppColors.slate400,
                  ),
                )
              : FutureBuilder<Uint8List>(
                  future: image!.readAsBytes(),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) {
                      return const Center(
                        child: CircularProgressIndicator(strokeWidth: 2),
                      );
                    }
                    return Image.memory(
                      snapshot.data!,
                      width: double.infinity,
                      height: double.infinity,
                      fit: BoxFit.cover,
                    );
                  },
                ),
        ),
      ),
    );
  }
}

class _DropdownLine extends StatelessWidget {
  final String label;
  final String value;
  final List<String> values;
  final ValueChanged<String> onChanged;

  const _DropdownLine({
    required this.label,
    required this.value,
    required this.values,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final isCompact = MediaQuery.sizeOf(context).width < 380;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _FieldLabel(label),
        SizedBox(height: isCompact ? 10 : 12),
        DropdownButtonFormField<String>(
          initialValue: value,
          isExpanded: true,
          icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 24),
          decoration: const InputDecoration(
            border: UnderlineInputBorder(
              borderSide: BorderSide(color: AppColors.outlineVariant),
            ),
            enabledBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: AppColors.outlineVariant),
            ),
            focusedBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: AppColors.primary),
            ),
            contentPadding: EdgeInsets.only(bottom: 12),
          ),
          style: AppTheme.body(
            fontSize: isCompact ? 16 : 17,
            fontWeight: FontWeight.w700,
            color: AppColors.onSurface,
          ),
          items: values
              .map((item) => DropdownMenuItem(value: item, child: Text(item)))
              .toList(),
          onChanged: (selected) {
            if (selected != null) {
              onChanged(selected);
            }
          },
        ),
      ],
    );
  }
}

class _PillChoice extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _PillChoice({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isCompact = MediaQuery.sizeOf(context).width < 380;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: EdgeInsets.symmetric(
          horizontal: isCompact ? 14 : 16,
          vertical: isCompact ? 10 : 11,
        ),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.secondaryContainer
              : AppColors.surfaceContainerLow,
          borderRadius: BorderRadius.circular(22),
          border: selected
              ? Border.all(color: AppColors.secondary, width: 1.4)
              : null,
        ),
        child: Text(
          label,
          style: AppTheme.body(
            fontSize: isCompact ? 13 : 14,
            color: selected
                ? AppColors.onSecondaryContainer
                : AppColors.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}

class _AmenitiesGrid extends StatelessWidget {
  final List<_AmenityOption> options;
  final Set<String> selected;
  final ValueChanged<String> onTap;

  const _AmenitiesGrid({
    required this.options,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isCompact = constraints.maxWidth < 360;
        final crossAxisCount = constraints.maxWidth < 320 ? 2 : 3;
        final circleSize = isCompact ? 58.0 : 64.0;

        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: options.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            mainAxisSpacing: isCompact ? 18 : 22,
            crossAxisSpacing: isCompact ? 10 : 14,
            childAspectRatio: crossAxisCount == 2 ? 1.1 : 0.88,
          ),
          itemBuilder: (context, index) {
            final option = options[index];
            final isSelected = selected.contains(option.label);
            return GestureDetector(
              onTap: () => onTap(option.label),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 160),
                    width: circleSize,
                    height: circleSize,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.tertiaryContainer,
                      border: isSelected
                          ? Border.all(
                              color: AppColors.secondary,
                              width: 2.4,
                            )
                          : null,
                    ),
                    child: Icon(
                      option.icon,
                      size: isCompact ? 28 : 32,
                      color: isSelected
                          ? AppColors.secondary
                          : AppColors.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    option.label,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppTheme.body(
                      fontSize: isCompact ? 12 : 13,
                      fontWeight: FontWeight.w500,
                      height: 1.15,
                      color: AppColors.onSurface,
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

class _MobileVisibilityCard extends StatelessWidget {
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

class _AmenityOption {
  final String label;
  final IconData icon;

  const _AmenityOption(this.label, this.icon);
}

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
                final shortName = addressDetails['neighbourhood'] ??
                    addressDetails['suburb'] ??
                    addressDetails['city_district'] ??
                    addressDetails['city'] ??
                    addressDetails['town'] ??
                    place['name'] ??
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
        style: AppTheme.body(
          fontSize: widget.isCompact ? 17 : 18,
          fontWeight: FontWeight.w700,
          color: AppColors.onSurface,
        ),
        decoration: InputDecoration(
          isDense: true,
          hintText: 'Enter your location...',
          hintStyle: AppTheme.body(
            fontSize: widget.isCompact ? 15 : 16,
            height: 1.1,
            fontWeight: FontWeight.w600,
            color: AppColors.slate400,
          ),
          prefixIcon: const Padding(
            padding: EdgeInsets.only(right: 12),
            child: Icon(
              Icons.location_on,
              size: 24,
              color: AppColors.onSurface,
            ),
          ),
          prefixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 32),
          suffixIcon: ValueListenableBuilder<TextEditingValue>(
            valueListenable: widget.controller,
            builder: (context, value, child) {
              if (value.text.isEmpty) return const SizedBox.shrink();
              return IconButton(
                icon: const Icon(Icons.close_rounded),
                iconSize: 22,
                color: AppColors.onSurfaceVariant,
                tooltip: 'Clear location',
                onPressed: () {
                  widget.controller.clear();
                  _provider.clearSearch();
                },
              );
            },
          ),
          contentPadding: const EdgeInsets.only(bottom: 2),
          border: const UnderlineInputBorder(
            borderSide: BorderSide(color: AppColors.outlineVariant),
          ),
          enabledBorder: const UnderlineInputBorder(
            borderSide: BorderSide(color: AppColors.outlineVariant),
          ),
          focusedBorder: const UnderlineInputBorder(
            borderSide: BorderSide(color: AppColors.primary, width: 2),
          ),
        ),
        validator: (value) {
          if ((value ?? '').trim().isEmpty) {
            return 'Enter your location';
          }
          return null;
        },
      ),
    );
  }
}
