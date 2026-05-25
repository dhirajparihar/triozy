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


// === Post listing form =======================================================

/// Form for creating a housing or marketplace listing.
class PostListingScreen extends StatefulWidget {
  final PropertyType? initialPropertyType;
  final ListingPurpose? initialPurpose;

  const PostListingScreen({
    super.key,
    this.initialPropertyType,
    this.initialPurpose,
  });

  @override
  State<PostListingScreen> createState() => _PostListingScreenState();
}

class _PostListingScreenState extends State<PostListingScreen> {
  static const int _maxImageCount = 3;

  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _locationController = TextEditingController();
  final _priceController = TextEditingController();
  final _highlightsController = TextEditingController();

  final ImagePicker _picker = ImagePicker();
  final List<XFile> _pickedImages = [];
  PropertyType _selectedPropertyType = PropertyType.room;
  ListingPurpose _selectedPurpose = ListingPurpose.offerProperty;
  String? _genderPreference;
  String? _condition;
  String? _furnishing;
  bool _submitting = false;

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _locationController.dispose();
    _priceController.dispose();
    _highlightsController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Apply deep-link defaults when navigating from a specific flow.
      if (widget.initialPropertyType != null || widget.initialPurpose != null) {
        setState(() {
          _selectedPropertyType =
              widget.initialPropertyType ?? _selectedPropertyType;
          _selectedPurpose =
              widget.initialPurpose ??
              (_selectedPropertyType == PropertyType.item
                  ? ListingPurpose.marketplaceSell
                  : _selectedPurpose);
        });
      }
    });
  }

  ListingPurpose get _resolvedPurpose {
    // Marketplace items always resolve to marketplace sell.
    if (_selectedPropertyType == PropertyType.item) {
      return ListingPurpose.marketplaceSell;
    }
    return _selectedPurpose == ListingPurpose.marketplaceSell
        ? ListingPurpose.offerProperty
        : _selectedPurpose;
  }

  List<PropertyType> get _availablePropertyTypes {
    // Flatmate flow excludes PG and item types.
    if (_selectedPurpose == ListingPurpose.needRoommate) {
      return const [PropertyType.room, PropertyType.flat];
    }
    return PropertyType.values;
  }

  Future<void> _pickImages() async {
    final messenger = ScaffoldMessenger.of(context);
    final images = await _picker.pickMultiImage(
      imageQuality: 80,
      limit: _maxImageCount,
    );
    if (images.isEmpty) {
      return;
    }
    setState(
      () => _pickedImages
        ..clear()
        ..addAll(images.take(_maxImageCount)),
    );

    if (images.length > _maxImageCount && mounted) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Only 3 images can be uploaded')),
      );
    }
  }

  Future<List<String>> _uploadImages(String listingId) async {
    // Upload sequentially to keep ordering stable.
    if (_pickedImages.isEmpty) {
      return [];
    }

    final cloudinary = context.read<CloudinaryService>();
    final urls = <String>[];
    for (var index = 0; index < _pickedImages.length; index++) {
      final bytes = await _pickedImages[index].readAsBytes();
      final url = await cloudinary.uploadImage(
        bytes: Uint8List.fromList(bytes),
        fileName: _pickedImages[index].name,
        folder: 'listings/$listingId',
      );
      urls.add(url);
    }
    return urls;
  }

  Future<void> _submit() async {
    // Validate and persist the new listing.
    final user = FirebaseAuth.instance.currentUser;
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final database = context.read<DatabaseService>();
    if (user == null) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Sign in to post a listing')),
      );
      return;
    }
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() => _submitting = true);
    final listingId = const Uuid().v4();

    try {
      final imageUrls = await _uploadImages(listingId);
      final listing = ListingModel(
        id: listingId,
        ownerId: user.uid,
        ownerName: (user.displayName ?? '').trim().isEmpty
            ? 'Triozy User'
            : user.displayName!.trim(),
        ownerPhotoUrl: user.photoURL ?? '',
        title: _titleController.text.trim(),
        description: _descriptionController.text.trim(),
        location: _locationController.text.trim(),
        price: double.parse(_priceController.text.trim()),
        type: _selectedPropertyType.listingType,
        propertyType: _selectedPropertyType,
        imageUrls: imageUrls,
        highlights: _highlightsController.text
            .split(',')
            .map((item) => item.trim())
            .where((item) => item.isNotEmpty)
            .take(4)
            .toList(),
        genderPreference: _genderPreference,
        condition: _condition,
        furnishing: _furnishing,
        availableFrom: 'Available now',
        purpose: _resolvedPurpose,
        isFeatured: false,
      );

      await database.createListing(listing);

      if (!mounted) {
        return;
      }
      messenger.showSnackBar(const SnackBar(content: Text('Your listing will be published once approved.')));
      navigator.pop(true);
    } catch (e) {
      if (!mounted) {
        return;
      }
      messenger.showSnackBar(
        SnackBar(content: Text('Could not post listing: $e')),
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
      appBar: AppBar(
        title: const Text('Post listing'),
        backgroundColor: Colors.white,
        foregroundColor: AppColors.onSurface,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _sectionTitle('Photos'),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: _pickImages,
                icon: const Icon(Icons.add_a_photo_outlined),
                label: Text(
                  _pickedImages.isEmpty
                      ? 'Upload up to 3 images'
                      : 'Change images',
                  style: AppTheme.body(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (_pickedImages.isNotEmpty) ...[
                const SizedBox(height: 12),
                SizedBox(
                  height: 86,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: _pickedImages.length,
                    separatorBuilder: (_, _) => const SizedBox(width: 10),
                    itemBuilder: (context, index) {
                      return FutureBuilder<Uint8List>(
                        future: _pickedImages[index].readAsBytes(),
                        builder: (context, snapshot) {
                          if (!snapshot.hasData) {
                            return Container(
                              width: 86,
                              height: 86,
                              decoration: BoxDecoration(
                                color: AppColors.surfaceContainerHigh,
                                borderRadius: BorderRadius.circular(16),
                              ),
                            );
                          }
                          return ClipRRect(
                            borderRadius: BorderRadius.circular(16),
                            child: Image.memory(
                              snapshot.data!,
                              width: 86,
                              height: 86,
                              fit: BoxFit.cover,
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
              const SizedBox(height: 22),
              _sectionTitle('Details'),
              const SizedBox(height: 12),
              _AppField(
                controller: _titleController,
                label: 'Title',
                hint: 'Private room near metro',
              ),
              const SizedBox(height: 12),
              _AppField(
                controller: _descriptionController,
                label: 'Description',
                hint: 'Tell people what makes this listing useful',
                maxLines: 4,
              ),
              const SizedBox(height: 12),
              _AppField(
                controller: _priceController,
                label: 'Price',
                hint: '12000',
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<PropertyType>(
                initialValue: _selectedPropertyType,
                decoration: _inputDecoration('Property type'),
                items: _availablePropertyTypes.map((propertyType) {
                  return DropdownMenuItem(
                    value: propertyType,
                    child: Text(propertyType.label),
                  );
                }).toList(),
                onChanged: (value) {
                  if (value == null) {
                    return;
                  }
                  setState(() {
                    _selectedPropertyType = value;
                    _selectedPurpose = value == PropertyType.item
                        ? ListingPurpose.marketplaceSell
                        : _selectedPurpose == ListingPurpose.marketplaceSell
                        ? ListingPurpose.offerProperty
                        : _selectedPurpose;
                  });
                },
              ),
              const SizedBox(height: 12),
              _AppField(
                controller: _locationController,
                label: 'Location',
                hint: 'Koramangala, Bengaluru',
              ),
              const SizedBox(height: 12),
              _AppField(
                controller: _highlightsController,
                label: 'Highlights',
                hint: 'Wi-Fi, Furnished, Balcony',
              ),
              const SizedBox(height: 18),
              if (_selectedPropertyType.listingType == ListingType.housing) ...[
                DropdownButtonFormField<String>(
                  initialValue: _genderPreference,
                  decoration: _inputDecoration('Gender preference'),
                  items: const ['Any', 'Male', 'Female'].map((value) {
                    return DropdownMenuItem(value: value, child: Text(value));
                  }).toList(),
                  onChanged: (value) =>
                      setState(() => _genderPreference = value),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: _furnishing,
                  decoration: _inputDecoration('Furnishing'),
                  items:
                      const [
                        'Fully furnished',
                        'Semi furnished',
                        'Unfurnished',
                      ].map((value) {
                        return DropdownMenuItem(
                          value: value,
                          child: Text(value),
                        );
                      }).toList(),
                  onChanged: (value) => setState(() => _furnishing = value),
                ),
              ] else ...[
                DropdownButtonFormField<String>(
                  initialValue: _condition,
                  decoration: _inputDecoration('Condition'),
                  items: const ['Used - Like New', 'Used - Good', 'Used - Fair']
                      .map((value) {
                        return DropdownMenuItem(
                          value: value,
                          child: Text(value),
                        );
                      })
                      .toList(),
                  onChanged: (value) => setState(() => _condition = value),
                ),
              ],
              const SizedBox(height: 26),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _submitting ? null : _submit,
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
      ),
    );
  }

  InputDecoration _inputDecoration(String label) {
    return InputDecoration(
      labelText: label,
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: BorderSide.none,
      ),
    );
  }

  Widget _sectionTitle(String label) {
    return Text(label, style: AppTheme.headline(fontSize: 22));
  }
}

/// Simple text field wrapper used in the post-listing form.
class _AppField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String hint;
  final int maxLines;
  final TextInputType? keyboardType;

  const _AppField({
    required this.controller,
    required this.label,
    required this.hint,
    this.maxLines = 1,
    this.keyboardType,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      keyboardType: keyboardType,
      validator: (value) {
        if ((value ?? '').trim().isEmpty) {
          return 'Required';
        }
        return null;
      },
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }
}
