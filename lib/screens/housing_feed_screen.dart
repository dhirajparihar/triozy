import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/listing_model.dart';
import '../providers/location_provider.dart';
import '../services/database_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../widgets/listing_card.dart';
import 'listing_detail_screen.dart';
import '../providers/chat_provider.dart';
import '../models/chat_model.dart';
import 'chat_detail_screen.dart';

class HousingFeedScreen extends StatelessWidget {
  final int initialTabIndex;

  const HousingFeedScreen({super.key, this.initialTabIndex = 0})
    : assert(initialTabIndex >= 0 && initialTabIndex < 3);

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    final isCompact = screenWidth < 380;
    final horizontalPadding = isCompact ? 12.0 : 16.0;
    final headerSize = isCompact ? 20.0 : 24.0;
    final tabFontSize = isCompact ? 13.0 : 14.0;

    return DefaultTabController(
      length: 3,
      initialIndex: initialTabIndex,
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: SafeArea(
          child: Column(
            children: [
              // Custom AppBar
              Padding(
                padding: EdgeInsets.fromLTRB(horizontalPadding, 12, horizontalPadding, 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _IconBtn(
                      icon: Icons.arrow_back_rounded,
                      onTap: () => Navigator.pop(context),
                      padding: isCompact ? 8 : 10,
                      size: isCompact ? 18 : 20,
                    ),
                    Text(
                      'Housing',
                      style: AppTheme.headline(fontSize: headerSize, fontWeight: FontWeight.w800, color: AppColors.inverseSurface),
                    ),
                    SizedBox(width: isCompact ? 34 : 40),
                  ],
                ),
              ),
              
              // TabBar inside a pill
              Container(
                margin: EdgeInsets.symmetric(horizontal: horizontalPadding, vertical: isCompact ? 6 : 8),
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: AppColors.surfaceContainerLowest,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: TabBar(
                  indicator: BoxDecoration(
                    color: const Color(0xFFF6F5FF), // AppColors.surfaceContainerLow
                    borderRadius: BorderRadius.circular(12),
                  ),
                  labelColor: AppColors.primary,
                  unselectedLabelColor: AppColors.textSecondary,
                  indicatorSize: TabBarIndicatorSize.tab,
                  dividerColor: Colors.transparent,
                  labelStyle: AppTheme.body(fontSize: tabFontSize, fontWeight: FontWeight.w700),
                  tabs: const [
                    Tab(text: 'Rooms'),
                    Tab(text: 'Flatmates'),
                    Tab(text: 'Properties'),
                  ],
                ),
              ),
              
              
              // TabBarView
              Expanded(
                child: const TabBarView(
                  children: [
                    _HousingTab(
                      propertyTypes: [PropertyType.room],
                      filters: ['Male', 'Female', 'Furnished', 'Unfurnished'],
                    ),
                    _HousingTab(
                      purpose: ListingPurpose.needRoommate,
                      includeRoomRequirements: true,
                      filters: ['Male', 'Female'],
                    ),
                    _HousingTab(
                      propertyTypes: [PropertyType.pg, PropertyType.flat],
                      purpose: ListingPurpose.offerProperty,
                      filters: ['Flat', 'PG/Hostel', '1 BHK', '2 BHK', 'Furnished'],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _IconBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final Color color;
  final double padding;
  final double size;

  const _IconBtn({
    required this.icon,
    required this.onTap,
    this.color = AppColors.textPrimary,
    this.padding = 10,
    this.size = 20,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.all(padding),
        decoration: BoxDecoration(
          color: AppColors.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Icon(icon, size: size, color: color),
      ),
    );
  }
}

class _HousingTab extends StatefulWidget {
  final List<PropertyType>? propertyTypes;
  final ListingPurpose? purpose;
  final bool includeRoomRequirements;
  final List<String> filters;

  const _HousingTab({
    this.propertyTypes,
    this.purpose,
    this.includeRoomRequirements = false,
    this.filters = const [],
  });

  @override
  State<_HousingTab> createState() => _HousingTabState();
}

class _HousingTabState extends State<_HousingTab> {
  List<ListingModel> _allListings = [];
  List<ListingModel> _listings = [];
  Set<String> _savedIds = <String>{};
  bool _loading = true;
  String? _selectedFilter;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _handleRefresh() async {
    final locProvider = context.read<LocationProvider>();
    await locProvider.forceRefetchLocation();
    await _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final db = context.read<DatabaseService>();
    final locProvider = context.read<LocationProvider>();

    if (!locProvider.isAvailable && !locProvider.hasError) {
      await locProvider.fetchLocation();
    }

    final listings = await db.searchListings(
      type: ListingType.housing,
      lat: locProvider.latitude,
      lon: locProvider.longitude,
      locationName: locProvider.address,
    );
    final userId = FirebaseAuth.instance.currentUser?.uid;
    final saved = userId == null
        ? <ListingModel>[]
        : await db.getSavedListings(userId);

    if (!mounted) {
      return;
    }

    setState(() {
      _allListings = listings.where(_matchesTabType).toList()
        ..sort(
          (a, b) => (b.createdAt ?? DateTime(0)).compareTo(
            a.createdAt ?? DateTime(0),
          ),
        );
      _savedIds = saved.map((listing) => listing.id).toSet();
      _loading = false;
      _applyFilter();
    });
  }

  bool _matchesTabType(ListingModel listing) {
    if (widget.includeRoomRequirements) {
      return listing.isRequirementPost ||
          (listing.purpose == ListingPurpose.needRoommate &&
              listing.propertyType == PropertyType.flat);
    }
    if (!widget.includeRoomRequirements && listing.isRequirementPost) {
      return false;
    }
    if (widget.propertyTypes != null &&
        !widget.propertyTypes!.contains(listing.propertyType)) {
      return false;
    }
    if (widget.purpose != null && listing.purpose != widget.purpose) {
      return false;
    }
    return true;
  }

  void _applyFilter() {
    if (_selectedFilter == null) {
      _listings = List.from(_allListings);
      return;
    }
    _listings = _allListings.where((listing) {
      final f = _selectedFilter!;
      if (f == 'Male') {
        return _matchesGender(listing, 'male') || _matchesGender(listing, 'boys');
      } else if (f == 'Female') {
        return _matchesGender(listing, 'female') || _matchesGender(listing, 'girls');
      } else if (f == 'Furnished') {
        return listing.furnishing?.toLowerCase() == 'furnished' || listing.highlights.any((h) => h.toLowerCase() == 'furnished');
      } else if (f == 'Unfurnished') {
        return listing.furnishing?.toLowerCase() == 'unfurnished' || listing.highlights.any((h) => h.toLowerCase() == 'unfurnished');
      } else if (f == 'Flat') {
        return listing.propertyType == PropertyType.flat;
      } else if (f == 'PG/Hostel') {
        return listing.propertyType == PropertyType.pg;
      } else if (f == '1 BHK') {
        return listing.highlights.any((h) => h.contains('1 BHK'));
      } else if (f == '2 BHK') {
        return listing.highlights.any((h) => h.contains('2 BHK'));
      }
      return true;
    }).toList();
  }

  bool _matchesGender(ListingModel listing, String target) {
    if (listing.genderPreference?.toLowerCase() == target) return true;
    if (listing.requirementDetails?.genderPreference.toLowerCase() == target) return true;
    if (listing.highlights.any((h) => h.toLowerCase().contains(target))) return true;
    return false;
  }

  Future<void> _toggleSave(String listingId) async {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Sign in to save listings')));
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
      if (_savedIds.contains(listingId)) {
        _savedIds.remove(listingId);
      } else {
        _savedIds.add(listingId);
      }
    });
  }

  void _openListing(ListingModel listing) {
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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.filters.isNotEmpty)
          Container(
            height: 50,
            width: double.infinity,
            padding: const EdgeInsets.only(bottom: 12),
            child: ListView.separated(
              padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              itemCount: widget.filters.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final filter = widget.filters[index];
                final isSelected = _selectedFilter == filter;
                return FilterChip(
                  label: Text(filter),
                  selected: isSelected,
                  onSelected: (selected) {
                    setState(() {
                      _selectedFilter = selected ? filter : null;
                      _applyFilter();
                    });
                  },
                  showCheckmark: false,
                  selectedColor: AppColors.primaryContainer,
                  labelStyle: AppTheme.label(
                    color: isSelected ? AppColors.onPrimaryContainer : AppColors.onSurfaceVariant,
                    fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                  ),
                  backgroundColor: Colors.white,
                  side: BorderSide(
                    color: isSelected ? AppColors.primaryContainer : AppColors.outlineVariant,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(999),
                  ),
                );
              },
            ),
          ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: _handleRefresh,
            color: AppColors.primary,
            child: ListView(
              padding: EdgeInsets.fromLTRB(horizontalPadding, 4, horizontalPadding, 24),
              children: [
                if (_loading)
                  const _HousingLoadingState()
                else if (_listings.isEmpty)
                  _HousingEmptyState(
                    propertyTypes: widget.propertyTypes,
                    purpose: widget.purpose,
                    includeRoomRequirements: widget.includeRoomRequirements,
                  )
                else
                  ..._listings.map((listing) {
                    return Padding(
                      padding: EdgeInsets.only(bottom: isCompact ? 12 : 16),
                      child: widget.includeRoomRequirements
                          ? _FlatmateFeedCard(
                              listing: listing,
                              onTap: () => _openListing(listing),
                            )
                          : ListingCard(
                              listing: listing,
                              compact: true,
                              onTap: () => _openListing(listing),
                              onSaveTap: () => _toggleSave(listing.id),
                              isSaved: _savedIds.contains(listing.id),
                            ),
                    );
                  }),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _FlatmateFeedCard extends StatefulWidget {
  final ListingModel listing;
  final VoidCallback onTap;

  const _FlatmateFeedCard({super.key, required this.listing, required this.onTap});

  @override
  State<_FlatmateFeedCard> createState() => _FlatmateFeedCardState();
}

class _FlatmateFeedCardState extends State<_FlatmateFeedCard> {
  String? _ownerPhone;

  @override
  void initState() {
    super.initState();
    _loadOwnerPhone();
  }

  Future<void> _loadOwnerPhone() async {
    if (widget.listing.phonePublic != true) return;
    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.listing.ownerId)
          .get();
      if (!mounted) return;
      final phone = userDoc.data()?['phoneNumber'] as String?;
      if (phone != null && phone.isNotEmpty) {
        setState(() => _ownerPhone = phone);
      }
    } catch (_) {}
  }

  Future<void> _launchPhone() async {
    if (_ownerPhone == null) return;
    final uri = Uri.parse('tel:$_ownerPhone');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _startChat() async {
    final listing = widget.listing;
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sign in to contact the listing owner')),
      );
      return;
    }
    if (currentUser.uid == listing.ownerId) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('This is your listing')),
      );
      return;
    }

    try {
      final conversationId = await context.read<ChatProvider>().createOrGetChat(
        otherUserId: listing.ownerId,
        chatType: listing.isMarketplacePost
            ? ChatType.marketplace.value
            : ChatType.listing.value,
        referenceId: listing.id,
        listingTitle: listing.title,
        otherUserName: listing.ownerName,
        otherUserPhotoUrl: listing.ownerPhotoUrl,
        currentUserName: currentUser.displayName,
        currentUserPhotoUrl: currentUser.photoURL,
      );

      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ChatDetailScreen(conversationId: conversationId),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not open chat: $error')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final listing = widget.listing;
    final onTap = widget.onTap;
    final screenWidth = MediaQuery.sizeOf(context).width;
    final isCompact = screenWidth < 380;
    final imageSize = isCompact ? 116.0 : 132.0;
    final cardRadius = BorderRadius.circular(12);
    final displayName = _displayName;
    final location = listing.location.trim();
    final rentLabel = _rentLabel;
    final lookingFor = _lookingForLabel;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: cardRadius,
        onTap: onTap,
        child: Ink(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: cardRadius,
            border: Border.all(color: const Color(0xFFEDEDED)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.06),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            children: [
              IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SizedBox(
                      width: imageSize,
                      child: ClipRRect(
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(12),
                        ),
                        child: AspectRatio(
                          aspectRatio: 1,
                          child: _FlatmatePhoto(listing: listing),
                        ),
                      ),
                    ),
                    Expanded(
                      child: Padding(
                        padding: EdgeInsets.fromLTRB(
                          isCompact ? 10 : 12,
                          isCompact ? 10 : 14,
                          isCompact ? 8 : 10,
                          isCompact ? 8 : 10,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            if (displayName.isNotEmpty) ...[
                              Text(
                                displayName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: AppTheme.headline(
                                  fontSize: isCompact ? 14 : 16,
                                  fontWeight: FontWeight.w700,
                                  color: const Color(0xFF3F3F3F),
                                ),
                              ),
                              const SizedBox(height: 6),
                            ],
                            if (location.isNotEmpty) ...[
                              _FlatmateInfoLine(
                                icon: Icons.location_on_rounded,
                                text: location,
                                fontSize: isCompact ? 11 : 12,
                              ),
                              const SizedBox(height: 5),
                            ],
                            if (rentLabel.isNotEmpty) ...[
                              _FlatmateInfoLine(
                                icon: Icons.currency_rupee_rounded,
                                text: rentLabel,
                                fontSize: isCompact ? 11 : 12,
                              ),
                              const SizedBox(height: 5),
                            ],
                            if (lookingFor.isNotEmpty)
                              _FlatmateInfoLine(
                                icon: Icons.person_rounded,
                                text: lookingFor,
                                fontSize: isCompact ? 11 : 12,
                              ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1, color: Color(0xFFEDEDED)),
              SizedBox(
                height: isCompact ? 42 : 46,
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: isCompact ? 10 : 12),
                  child: Row(
                    children: [
                      if (_bottomLabel.isNotEmpty)
                        Expanded(
                          child: Text(
                            _bottomLabel,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTheme.body(
                              fontSize: isCompact ? 11 : 12,
                              fontWeight: FontWeight.w500,
                              color: const Color(0xFF8E8E8E),
                            ),
                          ),
                        )
                      else
                        const Spacer(),
                      if (_ownerPhone != null) ...[
                        _FlatmateActionButton(
                          icon: Icons.phone_rounded,
                          enabled: true,
                          onTap: _launchPhone,
                        ),
                        SizedBox(width: isCompact ? 10 : 14),
                      ],
                      _FlatmateActionButton(
                        icon: Icons.chat_bubble_rounded,
                        enabled: true,
                        onTap: _startChat,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String get _displayName {
    final ownerName = widget.listing.ownerName.trim();
    if (ownerName.isNotEmpty) {
      return ownerName;
    }
    return widget.listing.title.trim();
  }

  String get _rentLabel {
    final requirement = widget.listing.requirementDetails;
    if (requirement != null) {
      if (requirement.minBudget > 0 && requirement.maxBudget > 0) {
        return '${_formatAmount(requirement.minBudget)} - ${_formatAmount(requirement.maxBudget)} Rent';
      }
      if (requirement.maxBudget > 0) {
        return '${_formatAmount(requirement.maxBudget)} Rent';
      }
      if (requirement.minBudget > 0) {
        return '${_formatAmount(requirement.minBudget)} Rent';
      }
    }
    if (widget.listing.price <= 0) {
      return '';
    }
    return '${_formatAmount(widget.listing.price.round())} Rent';
  }

  String get _lookingForLabel {
    final value = (widget.listing.genderPreference ?? widget.listing.requirementDetails?.genderPreference ?? '').trim();
    if (value.isEmpty) {
      return '';
    }
    return 'Looking for $value';
  }

  String get _bottomLabel {
    final availableFrom = (widget.listing.availableFrom ?? '').trim();
    if (availableFrom.isNotEmpty) {
      return availableFrom;
    }
    final moveInWhen = widget.listing.requirementDetails?.moveInWhen.trim() ?? '';
    return moveInWhen;
  }

  String _formatAmount(int amount) {
    final raw = amount.toString();
    final buffer = StringBuffer();
    for (var i = 0; i < raw.length; i++) {
      final remaining = raw.length - i;
      buffer.write(raw[i]);
      if (remaining > 1 && remaining % 2 == 0) {
        buffer.write(',');
      }
    }
    return buffer.toString();
  }
}

class _FlatmatePhoto extends StatelessWidget {
  final ListingModel listing;

  const _FlatmatePhoto({required this.listing});

  @override
  Widget build(BuildContext context) {
    final photoUrl = listing.ownerPhotoUrl.trim().isNotEmpty
        ? listing.ownerPhotoUrl.trim()
        : (listing.imageUrls.isNotEmpty ? listing.imageUrls.first.trim() : '');

    if (photoUrl.isNotEmpty) {
      if (photoUrl.startsWith('assets/')) {
        return Image.asset(
          photoUrl,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _fallback(),
        );
      }
      return CachedNetworkImage(
        imageUrl: photoUrl,
        fit: BoxFit.cover,
        errorWidget: (_, _, _) => _fallback(),
      );
    }
    return _fallback();
  }

  Widget _fallback() {
    final initial = listing.ownerName.trim().isNotEmpty
        ? listing.ownerName.trim()[0].toUpperCase()
        : '';
    return Container(
      color: const Color(0xFFF6F2EE),
      alignment: Alignment.center,
      child: initial.isEmpty
          ? const Icon(Icons.person_rounded, size: 48, color: Color(0xFFB0B0B0))
          : Text(
              initial,
              style: AppTheme.headline(
                fontSize: 36,
                fontWeight: FontWeight.w800,
                color: AppColors.primary,
              ),
            ),
    );
  }
}

class _FlatmateInfoLine extends StatelessWidget {
  final IconData icon;
  final String text;
  final double fontSize;

  const _FlatmateInfoLine({
    required this.icon,
    required this.text,
    required this.fontSize,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: fontSize + 5, color: AppColors.primary),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTheme.body(
              fontSize: fontSize,
              fontWeight: FontWeight.w500,
              color: const Color(0xFF8E8E8E),
            ),
          ),
        ),
      ],
    );
  }
}

class _FlatmateActionButton extends StatelessWidget {
  final IconData icon;
  final bool enabled;
  final VoidCallback? onTap;

  const _FlatmateActionButton({
    required this.icon,
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      customBorder: const CircleBorder(),
      onTap: enabled ? onTap : null,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: const Color(0xFFF8F8F8),
          shape: BoxShape.circle,
        ),
        child: Icon(
          icon,
          size: 20,
          color: enabled ? AppColors.primary : AppColors.outline,
        ),
      ),
    );
  }
}

class _HousingLoadingState extends StatelessWidget {
  const _HousingLoadingState();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 330,
      decoration: AppTheme.cardDecoration(
        color: AppColors.surfaceContainerLowest,
        radiusValue: 24,
        shadowAlpha: 0.05,
        blur: 18,
        offsetY: 8,
      ),
    );
  }
}

class _HousingEmptyState extends StatelessWidget {
  final List<PropertyType>? propertyTypes;
  final ListingPurpose? purpose;
  final bool includeRoomRequirements;

  const _HousingEmptyState({
    this.propertyTypes,
    this.purpose,
    this.includeRoomRequirements = false,
  });

  @override
  Widget build(BuildContext context) {
    IconData icon = Icons.home_work_rounded;
    String title = 'No housing listings yet';
    String subtitle = 'Listings will show up here once they are posted.';

    if (purpose == ListingPurpose.needRoommate) {
      icon = Icons.groups_rounded;
      if (includeRoomRequirements) {
        title = 'No flatmate or room needs yet';
        subtitle = 'People looking for rooms or flatmates will appear here.';
      } else {
        title = 'No flatmate posts yet';
        subtitle = 'This tab will fill up once people start looking for flatmates.';
      }
    } else if (propertyTypes != null) {
      if (propertyTypes!.contains(PropertyType.pg) && propertyTypes!.contains(PropertyType.flat)) {
        icon = Icons.apartment_rounded;
        title = 'No properties yet';
        subtitle = 'Flats, PGs, and hostel listings from owners will show up here.';
      } else if (propertyTypes!.contains(PropertyType.room)) {
        icon = Icons.meeting_room_rounded;
        title = 'No rooms yet';
        subtitle = 'Fresh room listings will appear here as soon as they are posted.';
      } else if (propertyTypes!.contains(PropertyType.pg)) {
        icon = Icons.apartment_rounded;
        title = 'No PGs yet';
        subtitle = 'PG and hostel listings from owners will show up here.';
      }
    }

    final screenWidth = MediaQuery.sizeOf(context).width;
    final isCompact = screenWidth < 380;

    return Container(
      padding: EdgeInsets.all(isCompact ? 16 : 20),
      decoration: AppTheme.cardDecoration(
        color: AppColors.surfaceContainerLowest,
        radiusValue: 24,
        shadowAlpha: 0.05,
        blur: 18,
        offsetY: 8,
      ),
      child: Column(
        children: [
          Container(
            width: isCompact ? 48 : 56,
            height: isCompact ? 48 : 56,
            decoration: BoxDecoration(
              color: AppColors.primaryContainer,
              borderRadius: AppTheme.radius(16),
            ),
            child: Icon(icon, color: AppColors.onPrimaryContainer, size: isCompact ? 24 : 28),
          ),
          SizedBox(height: isCompact ? 12 : 14),
          Text(title, style: AppTheme.headline(fontSize: isCompact ? 18 : 20)),
          SizedBox(height: isCompact ? 4 : 6),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: AppTheme.body(
              fontSize: isCompact ? 13 : 14,
              fontWeight: FontWeight.w500,
              color: AppColors.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
