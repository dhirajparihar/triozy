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
    final images = await _picker.pickMultiImage(
      imageQuality: 82,
      limit: _maxImageCount,
    );
    if (images.isEmpty) {
      return;
    }

    final accepted = <XFile>[];
    var rejectedOversize = false;
    for (final image in images.take(_maxImageCount)) {
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
    setState(() {
      _pickedImages
        ..clear()
        ..addAll(accepted);
    });

    if (images.length > _maxImageCount) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Only 3 images can be uploaded')),
      );
    } else if (rejectedOversize) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Each image must be 10 MB or smaller')),
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
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        bottom: false,
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(24, 22, 24, 28),
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Add your Room Details',
                          style: AppTheme.headline(
                            fontSize: 28,
                            fontWeight: FontWeight.w800,
                            color: const Color(0xFF3F4145),
                            letterSpacing: 0,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          'so that other users can contact you',
                          style: AppTheme.body(
                            fontSize: 18,
                            color: const Color(0xFF8A8A8A),
                            letterSpacing: 0,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded),
                    iconSize: 42,
                    color: const Color(0xFFA5A5A5),
                    tooltip: 'Close',
                  ),
                ],
              ),
              const SizedBox(height: 48),
              _FieldLabel('Your Location'),
              const SizedBox(height: 22),
              _UnderlineTextField(
                controller: _locationController,
                hintText: 'Enter your location...',
                prefix: const Icon(
                  Icons.location_on,
                  size: 34,
                  color: Color(0xFF414141),
                ),
                suffix: _locationController.text.isEmpty
                    ? null
                    : IconButton(
                        onPressed: () =>
                            setState(() => _locationController.clear()),
                        icon: const Icon(Icons.close_rounded),
                        iconSize: 34,
                        color: const Color(0xFF898989),
                        tooltip: 'Clear location',
                      ),
                onChanged: (_) => setState(() {}),
                validator: (value) {
                  if ((value ?? '').trim().isEmpty) {
                    return 'Enter your location';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 46),
              _FieldLabel('Rent per Person'),
              const SizedBox(height: 22),
              _UnderlineTextField(
                controller: _rentController,
                keyboardType: TextInputType.number,
                prefix: Text(
                  '₹',
                  style: AppTheme.body(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF3F4145),
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
              const SizedBox(height: 42),
              _FieldLabel('Upload 3 Images'),
              const SizedBox(height: 22),
              Text(
                '*Each image size should not exceeds 10\nMB',
                style: AppTheme.body(
                  fontSize: 24,
                  height: 1.22,
                  color: Colors.black,
                ),
              ),
              const SizedBox(height: 26),
              _ImagePickerGrid(images: _pickedImages, onTap: _pickImages),
              const SizedBox(height: 46),
              _DropdownLine(
                label: 'Occupancy per room',
                value: _occupancy,
                values: const ['Single', 'Double', 'Triple'],
                onChanged: (value) => setState(() => _occupancy = value),
              ),
              const SizedBox(height: 48),
              _DropdownLine(
                label: 'Looking for',
                value: _lookingFor,
                values: const ['Male', 'Female', 'Any'],
                onChanged: (value) => setState(() => _lookingFor = value),
              ),
              const SizedBox(height: 58),
              _FieldLabel('Choose highlights for your property'),
              const SizedBox(height: 26),
              Wrap(
                spacing: 16,
                runSpacing: 16,
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
              const SizedBox(height: 58),
              _FieldLabel('Amenities'),
              const SizedBox(height: 32),
              _AmenitiesGrid(
                options: _amenityOptions,
                selected: _selectedAmenities,
                onTap: (label) => setState(() {
                  _selectedAmenities.contains(label)
                      ? _selectedAmenities.remove(label)
                      : _selectedAmenities.add(label);
                }),
              ),
              const SizedBox(height: 58),
              _MobileVisibilityCard(
                isPublic: _mobilePublic,
                onChanged: (value) => setState(() => _mobilePublic = value),
              ),
              const SizedBox(height: 58),
              _FieldLabel('Description'),
              const SizedBox(height: 24),
              TextFormField(
                controller: _descriptionController,
                maxLines: 3,
                minLines: 1,
                style: AppTheme.body(
                  fontSize: 21,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF3F4145),
                ),
                decoration: const InputDecoration(
                  border: UnderlineInputBorder(
                    borderSide: BorderSide(color: Color(0xFFE9E9E9)),
                  ),
                  enabledBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: Color(0xFFE9E9E9)),
                  ),
                  focusedBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: AppColors.primary),
                  ),
                  contentPadding: EdgeInsets.zero,
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
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Container(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 18),
          decoration: const BoxDecoration(
            color: Colors.white,
            border: Border(top: BorderSide(color: Color(0xFFE9E9E9))),
          ),
          child: SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton(
              onPressed: _submitting ? null : _submit,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1EBB72),
                foregroundColor: Colors.white,
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
                        color: Colors.white,
                      ),
                    )
                  : Text(
                      'Add Room Details',
                      style: AppTheme.body(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
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
    return Text(
      text,
      style: AppTheme.body(
        fontSize: 19,
        color: const Color(0xFF171A20),
        letterSpacing: 0,
      ),
    );
  }
}

class _UnderlineTextField extends StatelessWidget {
  final TextEditingController controller;
  final Widget? prefix;
  final Widget? suffix;
  final String? hintText;
  final TextInputType? keyboardType;
  final ValueChanged<String>? onChanged;
  final String? Function(String?)? validator;

  const _UnderlineTextField({
    required this.controller,
    this.prefix,
    this.suffix,
    this.hintText,
    this.keyboardType,
    this.onChanged,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      onChanged: onChanged,
      validator: validator,
      style: AppTheme.body(
        fontSize: 22,
        fontWeight: FontWeight.w800,
        color: const Color(0xFF3F4145),
      ),
      decoration: InputDecoration(
        hintText: hintText,
        hintStyle: AppTheme.body(
          fontSize: 20,
          height: 1.1,
          fontWeight: FontWeight.w800,
          color: const Color(0xFFB9B9B9),
        ),
        prefixIcon: prefix == null
            ? null
            : Padding(padding: const EdgeInsets.only(right: 18), child: prefix),
        prefixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 44),
        suffixIcon: suffix,
        contentPadding: const EdgeInsets.only(bottom: 18),
        border: const UnderlineInputBorder(
          borderSide: BorderSide(color: Color(0xFFE9E9E9)),
        ),
        enabledBorder: const UnderlineInputBorder(
          borderSide: BorderSide(color: Color(0xFFE9E9E9)),
        ),
        focusedBorder: const UnderlineInputBorder(
          borderSide: BorderSide(color: Color(0xFF1C9A99), width: 2),
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
        final gap = constraints.maxWidth < 420 ? 12.0 : 14.0;
        final cellWidth = (constraints.maxWidth - gap) / 2;
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: cellWidth,
              height: cellWidth * 1.34,
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
                    height: (cellWidth * 1.34 - gap) / 2,
                    child: _ImageSlot(
                      image: images.length > 1 ? images[1] : null,
                      onTap: onTap,
                    ),
                  ),
                  SizedBox(height: gap),
                  SizedBox(
                    height: (cellWidth * 1.34 - gap) / 2,
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
          color: const Color(0xFFE9EEF1),
          child: image == null
              ? const Center(
                  child: Icon(
                    Icons.add_photo_alternate_outlined,
                    size: 68,
                    color: Color(0xFFB9BEC2),
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _FieldLabel(label),
        const SizedBox(height: 18),
        DropdownButtonFormField<String>(
          initialValue: value,
          isExpanded: true,
          icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 32),
          decoration: const InputDecoration(
            border: UnderlineInputBorder(
              borderSide: BorderSide(color: Color(0xFFE9E9E9)),
            ),
            enabledBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: Color(0xFFE9E9E9)),
            ),
            focusedBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: AppColors.primary),
            ),
            contentPadding: EdgeInsets.only(bottom: 18),
          ),
          style: AppTheme.body(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: const Color(0xFF3F4145),
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
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 17),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFFDFF4E9) : const Color(0xFFF0F0F0),
          borderRadius: BorderRadius.circular(34),
          border: selected
              ? Border.all(color: const Color(0xFF1EBB72), width: 1.4)
              : null,
        ),
        child: Text(
          label,
          style: AppTheme.body(
            fontSize: 16,
            color: selected ? const Color(0xFF147A4C) : const Color(0xFF808080),
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
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: options.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisSpacing: 34,
        crossAxisSpacing: 22,
        childAspectRatio: 0.72,
      ),
      itemBuilder: (context, index) {
        final option = options[index];
        final isSelected = selected.contains(option.label);
        return GestureDetector(
          onTap: () => onTap(option.label),
          child: Column(
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                width: 86,
                height: 86,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFFFFF6EC),
                  border: isSelected
                      ? Border.all(color: const Color(0xFF1EBB72), width: 3)
                      : null,
                ),
                child: Icon(
                  option.icon,
                  size: 50,
                  color: isSelected
                      ? const Color(0xFF1EBB72)
                      : const Color(0xFF707377),
                ),
              ),
              const SizedBox(height: 13),
              Text(
                option.label,
                textAlign: TextAlign.center,
                style: AppTheme.body(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  height: 1.15,
                  color: const Color(0xFF202226),
                ),
              ),
            ],
          ),
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
    return Container(
      padding: const EdgeInsets.fromLTRB(22, 30, 22, 28),
      decoration: BoxDecoration(
        color: const Color(0xFFEDFFF5),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Do you want to make your mobile number visible to\nother user?',
            style: AppTheme.body(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              height: 1.25,
              color: const Color(0xFF3F4145),
            ),
          ),
          const SizedBox(height: 36),
          Row(
            children: [
              Expanded(
                child: _VisibilityButton(
                  text: 'Yes! make it public',
                  selected: isPublic,
                  onTap: () => onChanged(true),
                ),
              ),
              const SizedBox(width: 24),
              Expanded(
                child: _VisibilityButton(
                  text: 'No! make it private',
                  selected: !isPublic,
                  onTap: () => onChanged(false),
                ),
              ),
            ],
          ),
          const SizedBox(height: 34),
          Text(
            'Note: If your mobile number is private, others can contact you only',
            style: AppTheme.body(fontSize: 14, color: Colors.black),
          ),
          const SizedBox(height: 18),
          Text(
            'through chat.',
            style: AppTheme.body(fontSize: 14, color: Colors.black),
          ),
        ],
      ),
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
    return SizedBox(
      height: 78,
      child: ElevatedButton(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          elevation: 0,
          backgroundColor: selected
              ? const Color(0xFF1EBB72)
              : const Color(0xFFE4E5EA),
          foregroundColor: selected ? Colors.white : Colors.black,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: AppTheme.body(
            fontSize: 16,
            height: 1.15,
            fontWeight: FontWeight.w500,
            color: selected ? Colors.white : Colors.black,
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
