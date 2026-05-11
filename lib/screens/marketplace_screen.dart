import 'dart:typed_data';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

import '../models/listing_model.dart';
import '../providers/location_provider.dart';
import '../services/cloudinary_service.dart';
import '../services/database_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import 'listing_detail_screen.dart';

class MarketplaceScreen extends StatefulWidget {
  const MarketplaceScreen({super.key});

  @override
  State<MarketplaceScreen> createState() => _MarketplaceScreenState();
}

class _MarketplaceScreenState extends State<MarketplaceScreen> {
  static const List<String> _categories = [
    'All',
    'Furniture',
    'Electronics',
    'Appliances',
    'Books',
    'Kitchen',
    'Cycle/Bike',
    'Fashion',
    'Hostel Essentials',
    'Others',
  ];

  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  List<ListingModel> _items = [];
  Set<String> _savedIds = <String>{};
  String _selectedCategory = 'All';
  String _sortBy = 'Newest';
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadItems());
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadItems() async {
    if (mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }

    try {
      final db = context.read<DatabaseService>();
      final listings = await db.searchListings(
        query: _searchController.text,
        type: ListingType.marketplace,
        propertyType: PropertyType.item,
      );
      final userId = FirebaseAuth.instance.currentUser?.uid;
      final saved = userId == null
          ? <ListingModel>[]
          : await db.getSavedListings(userId);

      if (!mounted) {
        return;
      }
      setState(() {
        _items = _sortItems(_filterByCategory(listings));
        _savedIds = saved.map((listing) => listing.id).toSet();
        _loading = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _error = 'Could not load marketplace items.';
        _loading = false;
      });
    }
  }

  List<ListingModel> _filterByCategory(List<ListingModel> listings) {
    if (_selectedCategory == 'All') {
      return listings;
    }
    return listings.where((listing) {
      return listing.highlights.any(
        (item) => item.toLowerCase() == _selectedCategory.toLowerCase(),
      );
    }).toList();
  }

  List<ListingModel> _sortItems(List<ListingModel> listings) {
    final sorted = [...listings];
    switch (_sortBy) {
      case 'Price low':
        sorted.sort((a, b) => a.price.compareTo(b.price));
        break;
      case 'Price high':
        sorted.sort((a, b) => b.price.compareTo(a.price));
        break;
      case 'Urgent':
        sorted.sort(
          (a, b) => (_isUrgent(b) ? 1 : 0).compareTo(_isUrgent(a) ? 1 : 0),
        );
        break;
      case 'Newest':
      default:
        sorted.sort(
          (a, b) => (b.createdAt ?? DateTime(0)).compareTo(
            a.createdAt ?? DateTime(0),
          ),
        );
    }
    return sorted;
  }

  bool _isUrgent(ListingModel listing) {
    final available = (listing.availableFrom ?? '').toLowerCase();
    return available.contains('today') ||
        available.contains('3 days') ||
        listing.highlights.any(
          (item) => item.toLowerCase().contains('leaving city'),
        );
  }

  Future<void> _toggleSave(String listingId) async {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Sign in to save items')));
      return;
    }

    await context.read<DatabaseService>().toggleSavedListing(
      userId: userId,
      listingId: listingId,
    );
    if (!mounted) {
      return;
    }
    setState(() {
      _savedIds.contains(listingId)
          ? _savedIds.remove(listingId)
          : _savedIds.add(listingId);
    });
  }

  Future<void> _openSellForm() async {
    final posted = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const SellItemScreen()),
    );
    if (posted == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Item posted to marketplace')),
      );
      await _loadItems();
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          0,
          duration: const Duration(milliseconds: 280),
          curve: Curves.easeOutCubic,
        );
      }
    }
  }

  void _openItem(ListingModel listing) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            ListingDetailScreen(listingId: listing.id, seed: listing),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    final isCompact = screenWidth < 380;
    final horizontalPadding = isCompact ? 12.0 : 16.0;
    final sectionGap = isCompact ? 10.0 : 14.0;
    final gridSpacing = isCompact ? 10.0 : 14.0;
    final gridCrossAxisCount = screenWidth < 340 ? 1 : 2;
    final gridAspectRatio = gridCrossAxisCount == 1
        ? 0.92
        : (isCompact ? 0.70 : 0.66);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _loadItems,
          color: AppColors.primary,
          child: CustomScrollView(
            controller: _scrollController,
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(
                    horizontalPadding,
                    12,
                    horizontalPadding,
                    8,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          IconButton(
                            onPressed: () => Navigator.pop(context),
                            icon: const Icon(Icons.arrow_back_rounded),
                            tooltip: 'Back',
                            style: IconButton.styleFrom(
                              backgroundColor: Theme.of(
                                context,
                              ).colorScheme.surfaceContainerLowest,
                              foregroundColor: AppColors.onSurface,
                              shape: RoundedRectangleBorder(
                                borderRadius: AppTheme.radius(18),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Marketplace',
                              style: AppTheme.headline(
                                fontSize: isCompact ? 24 : 28,
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          isCompact
                              ? IconButton.filled(
                                  onPressed: _openSellForm,
                                  icon: const Icon(Icons.add_rounded),
                                  tooltip: 'Sell item',
                                  style: IconButton.styleFrom(
                                    backgroundColor: AppColors.primary,
                                    foregroundColor: AppColors.onPrimary,
                                  ),
                                )
                              : FilledButton.icon(
                                  onPressed: _openSellForm,
                                  icon: const Icon(Icons.add_rounded, size: 18),
                                  label: const Text('Sell'),
                                  style: FilledButton.styleFrom(
                                    backgroundColor: AppColors.primary,
                                    foregroundColor: AppColors.onPrimary,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 14,
                                      vertical: 12,
                                    ),
                                    textStyle: AppTheme.button(fontSize: 14),
                                  ),
                                ),
                        ],
                      ),
                      SizedBox(height: isCompact ? 4 : 6),
                      Text(
                        'Buy and sell items from people nearby',
                        style: AppTheme.body(
                          fontSize: isCompact ? 13 : 14,
                          fontWeight: FontWeight.w500,
                          color: AppColors.onSurfaceVariant,
                        ),
                      ),
                      SizedBox(height: sectionGap),
                      _MarketplaceSearchBar(
                        controller: _searchController,
                        onSubmitted: _loadItems,
                        onChanged: () => setState(() {}),
                        onClear: () {
                          _searchController.clear();
                          _loadItems();
                        },
                        onFilterTap: _showFilterSheet,
                      ),
                      SizedBox(height: sectionGap),
                      _CategoryRail(
                        categories: _categories,
                        selected: _selectedCategory,
                        onSelected: (category) {
                          setState(() => _selectedCategory = category);
                          _loadItems();
                        },
                      ),
                      SizedBox(height: sectionGap),
                      Row(
                        children: [
                          Text(
                            '${_items.length} items',
                            style: AppTheme.body(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: AppColors.slate500,
                            ),
                          ),
                          const Spacer(),
                          _SortDropdown(
                            value: _sortBy,
                            onChanged: (value) {
                              setState(() {
                                _sortBy = value;
                                _items = _sortItems(_items);
                              });
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              if (_loading)
                SliverPadding(
                  padding: EdgeInsets.fromLTRB(
                    horizontalPadding,
                    12,
                    horizontalPadding,
                    24,
                  ),
                  sliver: const SliverToBoxAdapter(
                    child: _MarketplaceSkeleton(),
                  ),
                )
              else if (_error != null)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: _MarketplaceErrorState(
                    message: _error!,
                    onRetry: _loadItems,
                  ),
                )
              else if (_items.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: _MarketplaceEmptyState(onSellTap: _openSellForm),
                )
              else
                SliverPadding(
                  padding: EdgeInsets.fromLTRB(
                    horizontalPadding,
                    12,
                    horizontalPadding,
                    24,
                  ),
                  sliver: SliverGrid.builder(
                    itemCount: _items.length,
                    gridDelegate:
                        SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: gridCrossAxisCount,
                          mainAxisSpacing: gridSpacing,
                          crossAxisSpacing: gridSpacing,
                          childAspectRatio: gridAspectRatio,
                        ),
                    itemBuilder: (context, index) {
                      final item = _items[index];
                      return _MarketplaceItemCard(
                        item: item,
                        saved: _savedIds.contains(item.id),
                        urgent: _isUrgent(item),
                        onTap: () => _openItem(item),
                        onSaveTap: () => _toggleSave(item.id),
                      );
                    },
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _showFilterSheet() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Theme.of(context).colorScheme.surface,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Filters', style: AppTheme.headline(fontSize: 22)),
              const SizedBox(height: 14),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: _categories.map((category) {
                  final selected = category == _selectedCategory;
                  return ChoiceChip(
                    label: Text(category),
                    selected: selected,
                    onSelected: (_) {
                      Navigator.pop(context);
                      setState(() => _selectedCategory = category);
                      _loadItems();
                    },
                  );
                }).toList(),
              ),
            ],
          ),
        );
      },
    );
  }
}

class SellItemScreen extends StatefulWidget {
  const SellItemScreen({super.key});

  @override
  State<SellItemScreen> createState() => _SellItemScreenState();
}

class _SellItemScreenState extends State<SellItemScreen> {
  static const int _maxImages = 5;
  static const int _maxImageBytes = 10 * 1024 * 1024;
  static const List<String> _categories = [
    'Furniture',
    'Electronics',
    'Appliances',
    'Books',
    'Kitchen',
    'Cycle/Bike',
    'Fashion',
    'Hostel Essentials',
    'Others',
  ];
  static const List<String> _conditions = [
    'New',
    'Like New',
    'Good',
    'Used',
    'Needs Repair',
  ];
  static const List<String> _durations = [
    'Less than 1 month',
    '1-3 months',
    '3-6 months',
    '6-12 months',
    '1 year+',
  ];
  static const List<String> _urgencyOptions = [
    'Leaving Today',
    'Within 3 Days',
    'Within 1 Week',
    'Flexible',
  ];

  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _priceController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _locationController = TextEditingController();
  final _picker = ImagePicker();
  final List<XFile> _images = [];

  String _category = 'Furniture';
  String _condition = 'Good';
  String _duration = '3-6 months';
  String _urgency = 'Flexible';
  String _delivery = 'Self Pickup Only';
  String _contact = 'Chat Only';
  bool _negotiable = true;
  bool _submitting = false;
  bool _detectingPickupLocation = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final address = context.read<LocationProvider>().address.trim();
      final hasResolvedAddress = address.isNotEmpty &&
          address != 'Locating...' &&
          address != 'Location unavailable';
      if (hasResolvedAddress && _locationController.text.trim().isEmpty) {
        _locationController.text = address;
      }
    });
  }

  @override
  void dispose() {
    _titleController.dispose();
    _priceController.dispose();
    _descriptionController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  Future<void> _pickImages(ImageSource source) async {
    final messenger = ScaffoldMessenger.of(context);
    final picked = source == ImageSource.camera
        ? await _picker.pickImage(source: source, imageQuality: 82)
        : null;
    final selected = source == ImageSource.camera
        ? (picked == null ? <XFile>[] : [picked])
        : await _picker.pickMultiImage(imageQuality: 82, limit: _maxImages);
    if (selected.isEmpty) {
      return;
    }

    final available = _maxImages - _images.length;
    if (available <= 0) {
      messenger.showSnackBar(
        const SnackBar(content: Text('You can upload up to 5 images')),
      );
      return;
    }

    final accepted = <XFile>[];
    var rejected = false;
    for (final image in selected.take(available)) {
      final size = await image.length();
      if (size > _maxImageBytes) {
        rejected = true;
        continue;
      }
      accepted.add(image);
    }
    if (!mounted) {
      return;
    }
    setState(() => _images.addAll(accepted));
    if (selected.length > available) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Only 5 images can be uploaded')),
      );
    } else if (rejected) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Each image must be 10 MB or smaller')),
      );
    }
  }

  Future<List<String>> _uploadImages(String listingId) async {
    if (_images.isEmpty) {
      return [];
    }
    final cloudinary = context.read<CloudinaryService>();
    final urls = <String>[];
    for (final image in _images) {
      final bytes = await image.readAsBytes();
      final url = await cloudinary.uploadImage(
        bytes: Uint8List.fromList(bytes),
        fileName: image.name,
        folder: 'marketplace/$listingId',
      );
      urls.add(url);
    }
    return urls;
  }

  Future<void> _detectPickupLocation() async {
    final locationProvider = context.read<LocationProvider>();
    final messenger = ScaffoldMessenger.of(context);

    setState(() => _detectingPickupLocation = true);
    try {
      await locationProvider.refreshLocation();
      if (!mounted) {
        return;
      }

      final address = locationProvider.address.trim();
      final hasResolvedAddress = address.isNotEmpty &&
          address != 'Locating...' &&
          address != 'Location unavailable';
      if (!hasResolvedAddress) {
        messenger.showSnackBar(
          const SnackBar(content: Text('Could not detect your location')),
        );
        return;
      }

      setState(() => _locationController.text = address);
    } catch (error) {
      if (!mounted) {
        return;
      }
      messenger.showSnackBar(
        SnackBar(content: Text('Could not detect location: $error')),
      );
    } finally {
      if (mounted) {
        setState(() => _detectingPickupLocation = false);
      }
    }
  }

  Future<void> _submit() async {
    final user = FirebaseAuth.instance.currentUser;
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    if (user == null) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Sign in to post an item')),
      );
      return;
    }
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() => _submitting = true);
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
      final imageUrls = await _uploadImages(id);
      final highlights = <String>[
        _category,
        _condition,
        if (_negotiable) 'Negotiable',
        _delivery,
        _contact,
        if (_urgency != 'Flexible') 'Leaving City',
        _urgency,
        _duration,
      ];

      final listing = ListingModel(
        id: id,
        ownerId: user.uid,
        ownerName: ownerName.isEmpty ? 'Triozy user' : ownerName,
        ownerPhotoUrl: ownerPhotoUrl,
        title: _titleController.text.trim(),
        description: _descriptionController.text.trim(),
        location: _locationController.text.trim(),
        price: double.parse(_priceController.text.trim()),
        type: ListingType.marketplace,
        propertyType: PropertyType.item,
        imageUrls: imageUrls,
        highlights: highlights,
        condition: _condition,
        availableFrom: _urgency,
        purpose: ListingPurpose.marketplaceSell,
      );

      await db.createListing(listing);
      if (!mounted) {
        return;
      }
      navigator.pop(true);
    } catch (error) {
      if (!mounted) {
        return;
      }
      messenger.showSnackBar(
        SnackBar(content: Text('Could not post item: $error')),
      );
    } finally {
      if (mounted) {
        setState(() => _submitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final keyboard = MediaQuery.of(context).viewInsets.bottom;
    final screenWidth = MediaQuery.sizeOf(context).width;
    final isCompact = screenWidth < 380;
    final horizontalPadding = isCompact ? 12.0 : 16.0;
    final sectionGap = isCompact ? 14.0 : 18.0;
    final fieldGap = isCompact ? 10.0 : 14.0;

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.surface,
        foregroundColor: AppColors.onSurface,
        elevation: 0,
        title: const Text('Sell Your Item'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: EdgeInsets.fromLTRB(
            horizontalPadding,
            8,
            horizontalPadding,
            24 + keyboard,
          ),
          children: [
            Text(
              'Moving out? Sell unused items easily.',
              style: AppTheme.body(
                fontSize: isCompact ? 13 : 15,
                fontWeight: FontWeight.w500,
                color: AppColors.onSurfaceVariant,
              ),
            ),
            SizedBox(height: isCompact ? 14 : 20),
            _ImageUploadSection(
              images: _images,
              onCameraTap: () => _pickImages(ImageSource.camera),
              onGalleryTap: () => _pickImages(ImageSource.gallery),
              onRemove: (index) => setState(() => _images.removeAt(index)),
            ),
            SizedBox(height: isCompact ? 16 : 22),
            _FormSection(
              title: 'Item Details',
              child: Column(
                children: [
                  _ModernTextField(
                    controller: _titleController,
                    label: 'Item Title',
                    hint: 'Example: Study Table, Office Chair',
                    validator: (value) => (value ?? '').trim().isEmpty
                        ? 'Enter item title'
                        : null,
                    onChanged: (_) => setState(() {}),
                  ),
                  SizedBox(height: fieldGap),
                  _ModernTextField(
                    controller: _priceController,
                    label: 'Selling Price',
                    hint: '2500',
                    prefixText: '₹ ',
                    keyboardType: TextInputType.number,
                    validator: (value) {
                      final price = double.tryParse((value ?? '').trim());
                      if (price == null || price <= 0) {
                        return 'Enter a valid price';
                      }
                      return null;
                    },
                    onChanged: (_) => setState(() {}),
                  ),
                  SwitchListTile.adaptive(
                    value: _negotiable,
                    onChanged: (value) => setState(() => _negotiable = value),
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      'Negotiable',
                      style: AppTheme.body(fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: sectionGap),
            _FormSection(
              title: 'Category',
              child: _ChipWrap(
                values: _categories,
                selected: _category,
                onSelected: (value) => setState(() => _category = value),
              ),
            ),
            SizedBox(height: sectionGap),
            _FormSection(
              title: 'Condition',
              child: _ChipWrap(
                values: _conditions,
                selected: _condition,
                onSelected: (value) => setState(() => _condition = value),
              ),
            ),
            SizedBox(height: sectionGap),
            _FormSection(
              title: 'More Info',
              child: Column(
                children: [
                  DropdownButtonFormField<String>(
                    initialValue: _duration,
                    decoration: _fieldDecoration('Usage Duration'),
                    items: _durations
                        .map(
                          (item) =>
                              DropdownMenuItem(value: item, child: Text(item)),
                        )
                        .toList(),
                    onChanged: (value) {
                      if (value != null) {
                        setState(() => _duration = value);
                      }
                    },
                  ),
                  SizedBox(height: fieldGap),
                  _ModernTextField(
                    controller: _descriptionController,
                    label: 'Description',
                    hint: 'Add details, reason for selling, defects if any...',
                    maxLines: 5,
                    maxLength: 300,
                    validator: (value) => (value ?? '').trim().isEmpty
                        ? 'Add a description'
                        : null,
                    onChanged: (_) => setState(() {}),
                  ),
                  SizedBox(height: isCompact ? 8 : 10),
                  _ModernTextField(
                    controller: _locationController,
                    label: 'Pickup Location',
                    hint: 'Enter pickup area',
                    prefixIcon: Icons.location_on_rounded,
                    validator: (value) => (value ?? '').trim().isEmpty
                        ? 'Enter pickup location'
                        : null,
                    onChanged: (_) => setState(() {}),
                  ),
                  SizedBox(height: isCompact ? 8 : 10),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: OutlinedButton.icon(
                      onPressed: _detectingPickupLocation
                          ? null
                          : _detectPickupLocation,
                      icon: _detectingPickupLocation
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.my_location_rounded, size: 18),
                      label: Text(
                        _detectingPickupLocation
                            ? 'Detecting location'
                            : 'Detect your location',
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
                ],
              ),
            ),
            SizedBox(height: sectionGap),
            _FormSection(
              title: 'Leaving City / Urgency',
              child: _ChipWrap(
                values: _urgencyOptions,
                selected: _urgency,
                onSelected: (value) => setState(() => _urgency = value),
              ),
            ),
            SizedBox(height: sectionGap),
            _FormSection(
              title: 'Delivery Option',
              child: Column(
                children: [
                  _SelectableOptionRow(
                    label: 'Self Pickup Only',
                    selected: _delivery == 'Self Pickup Only',
                    onTap: () => setState(() => _delivery = 'Self Pickup Only'),
                  ),
                  SizedBox(height: isCompact ? 8 : 10),
                  _SelectableOptionRow(
                    label: 'Can Deliver Nearby',
                    selected: _delivery == 'Can Deliver Nearby',
                    onTap: () =>
                        setState(() => _delivery = 'Can Deliver Nearby'),
                  ),
                ],
              ),
            ),
            SizedBox(height: sectionGap),
            _FormSection(
              title: 'Contact Preference',
              child: SegmentedButton<String>(
                segments: const [
                  ButtonSegment(
                    value: 'Chat Only',
                    label: Text('Chat Only'),
                    icon: Icon(Icons.chat_bubble_rounded),
                  ),
                  ButtonSegment(
                    value: 'Call Allowed',
                    label: Text('Call Allowed'),
                    icon: Icon(Icons.call_rounded),
                  ),
                ],
                selected: {_contact},
                onSelectionChanged: (value) =>
                    setState(() => _contact = value.first),
              ),
            ),
            SizedBox(height: sectionGap),
            _MarketplacePreviewCard(
              title: _titleController.text.trim().isEmpty
                  ? 'Your item title'
                  : _titleController.text.trim(),
              price: _priceController.text.trim().isEmpty
                  ? '₹0'
                  : '₹${_priceController.text.trim()}',
              location: _locationController.text.trim().isEmpty
                  ? 'Pickup location'
                  : _locationController.text.trim(),
              category: _category,
              image: _images.isEmpty ? null : _images.first,
              urgent: _urgency != 'Flexible',
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
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            border: Border(
              top: BorderSide(
                color: AppColors.outlineVariant.withValues(alpha: 0.35),
              ),
            ),
          ),
          child: SizedBox(
            height: isCompact ? 50 : 54,
            child: ElevatedButton(
              onPressed: _submitting ? null : _submit,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
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
                      'Post Item',
                      style: AppTheme.body(
                        fontSize: isCompact ? 15 : 16,
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

  InputDecoration _fieldDecoration(String label) {
    return InputDecoration(
      labelText: label,
      filled: true,
      fillColor: Theme.of(
        context,
      ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide.none,
      ),
    );
  }
}

class _MarketplaceSearchBar extends StatelessWidget {
  final TextEditingController controller;
  final VoidCallback onSubmitted;
  final VoidCallback onChanged;
  final VoidCallback onClear;
  final VoidCallback onFilterTap;

  const _MarketplaceSearchBar({
    required this.controller,
    required this.onSubmitted,
    required this.onChanged,
    required this.onClear,
    required this.onFilterTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: AppTheme.cardDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerLowest,
        radiusValue: 18,
        shadowAlpha: 0.06,
        blur: 18,
        offsetY: 8,
      ),
      child: TextField(
        controller: controller,
        onChanged: (_) => onChanged(),
        onSubmitted: (_) => onSubmitted(),
        decoration: InputDecoration(
          hintText: 'Search chairs, books, cycles...',
          prefixIcon: const Icon(Icons.search_rounded),
          suffixIcon: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (controller.text.isNotEmpty)
                IconButton(
                  onPressed: onClear,
                  icon: const Icon(Icons.close_rounded),
                  tooltip: 'Clear',
                ),
              IconButton(
                onPressed: onFilterTap,
                icon: const Icon(Icons.tune_rounded),
                tooltip: 'Filters',
              ),
            ],
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(18),
            borderSide: BorderSide.none,
          ),
        ),
      ),
    );
  }
}

class _CategoryRail extends StatelessWidget {
  final List<String> categories;
  final String selected;
  final ValueChanged<String> onSelected;

  const _CategoryRail({
    required this.categories,
    required this.selected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 42,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: categories.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final category = categories[index];
          final isSelected = category == selected;
          return ChoiceChip(
            label: Text(category),
            selected: isSelected,
            onSelected: (_) => onSelected(category),
            selectedColor: AppColors.surfaceContainerLowest,
            backgroundColor: AppColors.surfaceContainerHigh,
            side: BorderSide(
              color: isSelected
                  ? AppColors.primary.withValues(alpha: 0.18)
                  : Colors.transparent,
            ),
            labelStyle: AppTheme.label(
              color: isSelected
                  ? AppColors.primary
                  : AppColors.onSurfaceVariant,
              fontWeight: FontWeight.w800,
            ),
          );
        },
      ),
    );
  }
}

class _SortDropdown extends StatelessWidget {
  final String value;
  final ValueChanged<String> onChanged;

  const _SortDropdown({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      onSelected: onChanged,
      itemBuilder: (_) => const [
        PopupMenuItem(value: 'Newest', child: Text('Newest')),
        PopupMenuItem(value: 'Urgent', child: Text('Urgent')),
        PopupMenuItem(value: 'Price low', child: Text('Price low')),
        PopupMenuItem(value: 'Price high', child: Text('Price high')),
      ],
      child: Row(
        children: [
          const Icon(Icons.sort_rounded, size: 18, color: AppColors.slate500),
          const SizedBox(width: 5),
          Text(
            value,
            style: AppTheme.body(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: AppColors.slate500,
            ),
          ),
        ],
      ),
    );
  }
}

class _MarketplaceItemCard extends StatelessWidget {
  final ListingModel item;
  final bool saved;
  final bool urgent;
  final VoidCallback onTap;
  final VoidCallback onSaveTap;

  const _MarketplaceItemCard({
    required this.item,
    required this.saved,
    required this.urgent,
    required this.onTap,
    required this.onSaveTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        decoration: AppTheme.cardDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerLowest,
          radiusValue: 22,
          shadowAlpha: 0.07,
          blur: 20,
          offsetY: 8,
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  item.imageUrls.isEmpty
                      ? Container(
                          color: AppColors.surfaceContainerHigh,
                          child: const Icon(
                            Icons.shopping_bag_outlined,
                            color: AppColors.slate500,
                            size: 42,
                          ),
                        )
                      : CachedNetworkImage(
                          imageUrl: item.imageUrls.first,
                          fit: BoxFit.cover,
                          errorWidget: (_, _, _) =>
                              Container(color: AppColors.surfaceContainerHigh),
                        ),
                  if (urgent)
                    const Positioned(
                      left: 9,
                      bottom: 9,
                      child: _TinyBadge(label: 'Leaving City', urgent: true),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 11, 12, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(
                        child: Text(
                          '₹${item.price.toStringAsFixed(0)}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTheme.headline(fontSize: 20),
                        ),
                      ),
                      const SizedBox(width: 6),
                      SizedBox(
                        width: 28,
                        height: 28,
                        child: IconButton(
                          onPressed: onSaveTap,
                          padding: EdgeInsets.zero,
                          visualDensity: VisualDensity.compact,
                          tooltip: saved
                              ? 'Remove from wishlist'
                              : 'Add to wishlist',
                          icon: Icon(
                            saved
                                ? Icons.favorite_rounded
                                : Icons.favorite_border,
                            size: 18,
                            color: saved
                                ? AppColors.error
                                : AppColors.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 5),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          item.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: AppTheme.body(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            height: 1.2,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        _postedTime(item.createdAt),
                        maxLines: 1,
                        style: AppTheme.label(
                          fontSize: 11,
                          color: AppColors.slate400,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _postedTime(DateTime? date) {
    if (date == null) {
      return 'Just now';
    }
    final diff = DateTime.now().difference(date);
    if (diff.inDays > 0) {
      return '${diff.inDays}d ago';
    }
    if (diff.inHours > 0) {
      return '${diff.inHours}h ago';
    }
    return '${diff.inMinutes.clamp(1, 59)}m ago';
  }
}

class _TinyBadge extends StatelessWidget {
  final String label;
  final bool urgent;

  const _TinyBadge({required this.label, this.urgent = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: urgent
            ? AppColors.error.withValues(alpha: 0.92)
            : AppColors.surfaceContainerLowest.withValues(alpha: 0.92),
        borderRadius: AppTheme.radius(999),
      ),
      child: Text(
        label,
        style: AppTheme.label(
          fontSize: 10,
          fontWeight: FontWeight.w800,
          color: urgent ? Colors.white : AppColors.primary,
        ),
      ),
    );
  }
}

class _ImageUploadSection extends StatelessWidget {
  final List<XFile> images;
  final VoidCallback onCameraTap;
  final VoidCallback onGalleryTap;
  final ValueChanged<int> onRemove;

  const _ImageUploadSection({
    required this.images,
    required this.onCameraTap,
    required this.onGalleryTap,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final isCompact = MediaQuery.sizeOf(context).width < 380;

    return _FormSection(
      title: 'Photos',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: EdgeInsets.all(isCompact ? 14 : 18),
            decoration: BoxDecoration(
              color: AppColors.blue50,
              borderRadius: BorderRadius.circular(isCompact ? 18 : 22),
              border: Border.all(
                color: AppColors.primary.withValues(alpha: 0.12),
              ),
            ),
            child: Column(
              children: [
                const Icon(
                  Icons.add_photo_alternate_rounded,
                  color: AppColors.primary,
                  size: 40,
                ),
                SizedBox(height: isCompact ? 8 : 10),
                Text(
                  'Upload clear photos for faster responses',
                  textAlign: TextAlign.center,
                  style: AppTheme.body(
                    fontSize: isCompact ? 13 : 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary,
                  ),
                ),
                SizedBox(height: isCompact ? 10 : 14),
                if (isCompact)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _ResponsiveActionButton(
                        filled: false,
                        onPressed: onCameraTap,
                        icon: Icons.photo_camera_rounded,
                        label: 'Camera',
                      ),
                      const SizedBox(height: 8),
                      _ResponsiveActionButton(
                        filled: true,
                        onPressed: onGalleryTap,
                        icon: Icons.photo_library_rounded,
                        label: 'Gallery',
                      ),
                    ],
                  )
                else
                  Row(
                    children: [
                      Expanded(
                        child: _ResponsiveActionButton(
                          filled: false,
                          onPressed: onCameraTap,
                          icon: Icons.photo_camera_rounded,
                          label: 'Camera',
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _ResponsiveActionButton(
                          filled: true,
                          onPressed: onGalleryTap,
                          icon: Icons.photo_library_rounded,
                          label: 'Gallery',
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
          if (images.isNotEmpty) ...[
            SizedBox(height: isCompact ? 10 : 14),
            LayoutBuilder(
              builder: (context, constraints) {
                final columns = constraints.maxWidth < 300 ? 2 : 3;
                final gap = isCompact ? 8.0 : 10.0;
                return GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: images.length,
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: columns,
                    crossAxisSpacing: gap,
                    mainAxisSpacing: gap,
                  ),
                  itemBuilder: (context, index) {
                    return _PickedImageTile(
                      image: images[index],
                      onRemove: () => onRemove(index),
                    );
                  },
                );
              },
            ),
          ],
        ],
      ),
    );
  }
}

class _ResponsiveActionButton extends StatelessWidget {
  final bool filled;
  final VoidCallback onPressed;
  final IconData icon;
  final String label;

  const _ResponsiveActionButton({
    required this.filled,
    required this.onPressed,
    required this.icon,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    final button = filled
        ? FilledButton.icon(
            onPressed: onPressed,
            icon: Icon(icon),
            label: Text(label),
          )
        : OutlinedButton.icon(
            onPressed: onPressed,
            icon: Icon(icon),
            label: Text(label),
          );
    return button;
  }
}

class _PickedImageTile extends StatelessWidget {
  final XFile image;
  final VoidCallback onRemove;

  const _PickedImageTile({required this.image, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: Stack(
        fit: StackFit.expand,
        children: [
          FutureBuilder<Uint8List>(
            future: image.readAsBytes(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return Container(
                  color: AppColors.surfaceContainerHigh,
                  child: const Center(
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                );
              }
              return Image.memory(snapshot.data!, fit: BoxFit.cover);
            },
          ),
          Positioned(
            top: 4,
            right: 4,
            child: GestureDetector(
              onTap: onRemove,
              child: Container(
                width: 26,
                height: 26,
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
    );
  }
}

class _FormSection extends StatelessWidget {
  final String title;
  final Widget child;

  const _FormSection({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    final isCompact = MediaQuery.sizeOf(context).width < 380;

    return Container(
      padding: EdgeInsets.all(isCompact ? 12 : 16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(isCompact ? 18 : 22),
        border: Border.all(
          color: AppColors.outlineVariant.withValues(alpha: 0.25),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: AppTheme.headline(fontSize: isCompact ? 16 : 18)),
          SizedBox(height: isCompact ? 10 : 14),
          child,
        ],
      ),
    );
  }
}

class _ModernTextField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String hint;
  final String? prefixText;
  final IconData? prefixIcon;
  final int maxLines;
  final int? maxLength;
  final TextInputType? keyboardType;
  final String? Function(String?)? validator;
  final ValueChanged<String>? onChanged;

  const _ModernTextField({
    required this.controller,
    required this.label,
    required this.hint,
    this.prefixText,
    this.prefixIcon,
    this.maxLines = 1,
    this.maxLength,
    this.keyboardType,
    this.validator,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final isCompact = MediaQuery.sizeOf(context).width < 380;

    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      maxLength: maxLength,
      keyboardType: keyboardType,
      validator: validator,
      onChanged: onChanged,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixText: prefixText,
        prefixIcon: prefixIcon == null ? null : Icon(prefixIcon),
        contentPadding: EdgeInsets.symmetric(
          horizontal: isCompact ? 12 : 16,
          vertical: isCompact ? 12 : 16,
        ),
        filled: true,
        fillColor: Theme.of(
          context,
        ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }
}

class _ChipWrap extends StatelessWidget {
  final List<String> values;
  final String selected;
  final ValueChanged<String> onSelected;

  const _ChipWrap({
    required this.values,
    required this.selected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final isCompact = MediaQuery.sizeOf(context).width < 380;

    return Wrap(
      spacing: isCompact ? 6 : 9,
      runSpacing: isCompact ? 6 : 9,
      children: values.map((value) {
        return ChoiceChip(
          label: Text(value),
          visualDensity: isCompact
              ? VisualDensity.compact
              : VisualDensity.standard,
          selected: selected == value,
          onSelected: (_) => onSelected(value),
        );
      }).toList(),
    );
  }
}

class _SelectableOptionRow extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _SelectableOptionRow({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isCompact = MediaQuery.sizeOf(context).width < 380;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: EdgeInsets.symmetric(
          horizontal: isCompact ? 12 : 14,
          vertical: isCompact ? 11 : 13,
        ),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.blue50
              : Theme.of(
                  context,
                ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected
                ? AppColors.primary
                : AppColors.outlineVariant.withValues(alpha: 0.25),
          ),
        ),
        child: Row(
          children: [
            Icon(
              selected
                  ? Icons.radio_button_checked_rounded
                  : Icons.radio_button_unchecked_rounded,
              color: selected ? AppColors.primary : AppColors.slate500,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTheme.body(
                  fontSize: isCompact ? 13 : 14,
                  fontWeight: FontWeight.w700,
                  color: selected ? AppColors.primary : AppColors.onSurface,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MarketplacePreviewCard extends StatelessWidget {
  final String title;
  final String price;
  final String location;
  final String category;
  final XFile? image;
  final bool urgent;

  const _MarketplacePreviewCard({
    required this.title,
    required this.price,
    required this.location,
    required this.category,
    required this.image,
    required this.urgent,
  });

  @override
  Widget build(BuildContext context) {
    final isCompact = MediaQuery.sizeOf(context).width < 380;
    final imageSize = isCompact ? 82.0 : 96.0;

    return _FormSection(
      title: 'Preview',
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: SizedBox(
              width: imageSize,
              height: imageSize,
              child: image == null
                  ? Container(
                      color: AppColors.surfaceContainerHigh,
                      child: const Icon(Icons.shopping_bag_outlined),
                    )
                  : FutureBuilder<Uint8List>(
                      future: image!.readAsBytes(),
                      builder: (context, snapshot) {
                        if (!snapshot.hasData) {
                          return Container(
                            color: AppColors.surfaceContainerHigh,
                          );
                        }
                        return Image.memory(snapshot.data!, fit: BoxFit.cover);
                      },
                    ),
            ),
          ),
          SizedBox(width: isCompact ? 10 : 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    _TinyBadge(label: category),
                    if (urgent)
                      const _TinyBadge(label: 'Leaving City', urgent: true),
                  ],
                ),
                SizedBox(height: isCompact ? 6 : 8),
                Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
                Text(
                  price,
                  style: AppTheme.headline(fontSize: isCompact ? 17 : 19),
                ),
                const SizedBox(height: 5),
                Text(
                  location,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTheme.label(color: AppColors.slate500),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MarketplaceSkeleton extends StatelessWidget {
  const _MarketplaceSkeleton();

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: 6,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 14,
        crossAxisSpacing: 14,
        childAspectRatio: 0.62,
      ),
      itemBuilder: (_, _) {
        return Container(
          decoration: AppTheme.cardDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerLowest,
            radiusValue: 22,
            shadowAlpha: 0.04,
            blur: 16,
            offsetY: 6,
          ),
        );
      },
    );
  }
}

class _MarketplaceEmptyState extends StatelessWidget {
  final VoidCallback onSellTap;

  const _MarketplaceEmptyState({required this.onSellTap});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 108,
              height: 108,
              decoration: BoxDecoration(
                color: AppColors.secondaryContainer.withValues(alpha: 0.76),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.storefront_rounded,
                size: 52,
                color: AppColors.secondary,
              ),
            ),
            const SizedBox(height: 18),
            Text('No items listed yet', style: AppTheme.headline(fontSize: 22)),
            const SizedBox(height: 8),
            Text(
              'Be the first to list an item for people nearby.',
              textAlign: TextAlign.center,
              style: AppTheme.body(
                color: AppColors.onSurfaceVariant,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: onSellTap,
              icon: const Icon(Icons.add_rounded),
              label: const Text('Sell First Item'),
            ),
          ],
        ),
      ),
    );
  }
}

class _MarketplaceErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _MarketplaceErrorState({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.error_outline_rounded,
              size: 52,
              color: AppColors.tertiary,
            ),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            OutlinedButton(onPressed: onRetry, child: const Text('Try Again')),
          ],
        ),
      ),
    );
  }
}
