import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/listing_model.dart';
import '../services/database_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import 'listing_detail_screen.dart';
import 'home_screen.dart';
import '../providers/location_search_provider.dart';
import '../providers/location_provider.dart';
import 'housing_feed_screen.dart';
import 'marketplace_screen.dart';

/// Search screen that resolves a location and shows nearby listings.
class LocationSearchScreen extends StatefulWidget {
  const LocationSearchScreen({super.key});

  @override
  State<LocationSearchScreen> createState() => _LocationSearchScreenState();
}

class _LocationSearchScreenState extends State<LocationSearchScreen> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _focusNode.requestFocus(),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _selectLocation(
    LocationSearchProvider provider,
    Map<String, dynamic> place,
  ) {
    // Resolve the best readable label from the location payload.
    final addressDetails = place['address'] as Map<String, dynamic>? ?? {};
    final shortName =
        place['name'] ??
        addressDetails['neighbourhood'] ??
        addressDetails['suburb'] ??
        addressDetails['city_district'] ??
        addressDetails['city'] ??
        addressDetails['town'] ??
        'Unknown Location';

    final lat = double.tryParse(place['lat']?.toString() ?? '') ?? 0.0;
    final lon = double.tryParse(place['lon']?.toString() ?? '') ?? 0.0;
    final city = (addressDetails['city'] ?? addressDetails['town'] ?? '')
        .toString();

    _controller.text = shortName;
    _focusNode.unfocus();

    final locName = city.isNotEmpty ? city : shortName;
    context.read<LocationProvider>().setLocationData(lat, lon, locName);

    final db = context.read<DatabaseService>();
    provider.fetchFeedForLocation(db, lat, lon, locName);
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
    const backgroundColor = Color(
      0xFFF9FAFB,
    ); // Light background to match mockup

    return ChangeNotifierProvider(
      create: (_) => LocationSearchProvider(),
      child: Consumer<LocationSearchProvider>(
        builder: (context, provider, _) {
          return Scaffold(
            backgroundColor: backgroundColor,
            appBar: AppBar(
              backgroundColor: backgroundColor,
              elevation: 0,
              titleSpacing: 0,
              leading: IconButton(
                icon: const Icon(
                  Icons.arrow_back_rounded,
                  color: AppColors.textPrimary,
                ),
                onPressed: () => Navigator.pop(context),
              ),
              title: Padding(
                padding: const EdgeInsets.only(right: 16.0),
                child: Container(
                  height: 48,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(999),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primary.withValues(alpha: 0.05),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      const SizedBox(width: 16),
                      const Icon(
                        Icons.search_rounded,
                        color: AppColors.textSecondary,
                        size: 22,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextField(
                          controller: _controller,
                          focusNode: _focusNode,
                          onChanged: provider.onSearchChanged,
                          decoration: InputDecoration(
                            hintText: 'Search city or locality...',
                            hintStyle: AppTheme.body(
                              fontSize: 15,
                              color: AppColors.textHint,
                            ),
                            border: InputBorder.none,
                            focusedBorder: InputBorder.none,
                            enabledBorder: InputBorder.none,
                            errorBorder: InputBorder.none,
                            disabledBorder: InputBorder.none,
                            isDense: true,
                            contentPadding: EdgeInsets.zero,
                          ),
                          style: AppTheme.body(
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                      if (_controller.text.isNotEmpty)
                        IconButton(
                          icon: const Icon(
                            Icons.close_rounded,
                            color: AppColors.textSecondary,
                            size: 20,
                          ),
                          onPressed: () {
                            _controller.clear();
                            provider.clearSearch();
                            provider.resetFeed();
                            _focusNode.requestFocus();
                          },
                        ),
                      if (_controller.text.isEmpty) const SizedBox(width: 12),
                    ],
                  ),
                ),
              ),
            ),
            body: _buildBody(provider),
          );
        },
      ),
    );
  }

  /// Chooses between search results, feed results, and empty states.
  Widget _buildBody(LocationSearchProvider provider) {
    if (provider.isLoading)
      return const Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      );

    if (provider.showFeed) return _buildFeedView(provider);

    if (provider.results.isNotEmpty) {
      return Container(
        color: Colors.white,
        child: ListView.separated(
          itemCount: provider.results.length,
          separatorBuilder: (context, index) =>
              const Divider(height: 1, color: AppColors.divider),
          itemBuilder: (context, index) {
            final place = provider.results[index];
            final fullName = place['display_name'] ?? '';
            final nameParts = fullName.split(', ');
            final title = nameParts.isNotEmpty ? nameParts.first : fullName;
            final subtitle = nameParts.length > 1
                ? nameParts.skip(1).join(', ')
                : '';

            return ListTile(
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 20,
                vertical: 4,
              ),
              leading: const Icon(
                Icons.location_on_rounded,
                color: AppColors.primary,
              ),
              title: Text(
                title,
                style: AppTheme.body(
                  fontSize: 15,
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
                        fontSize: 13,
                        color: AppColors.textSecondary,
                      ),
                    )
                  : null,
              onTap: () => _selectLocation(provider, place),
            );
          },
        ),
      );
    }

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.location_city_rounded,
            size: 64,
            color: AppColors.textHint.withValues(alpha: 0.3),
          ),
          const SizedBox(height: 12),
          Text(
            _controller.text.isEmpty
                ? 'Search for a city or locality'
                : 'No locations found',
            style: AppTheme.body(fontSize: 15, color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }

  /// Feed view shown after a location has been selected.
  Widget _buildFeedView(LocationSearchProvider provider) {
    if (provider.isLoadingFeed)
      return const Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      );

    if (provider.feedListings.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.location_off_rounded,
              size: 56,
              color: AppColors.textHint.withValues(alpha: 0.4),
            ),
            const SizedBox(height: 16),
            Text(
              'No listings found near',
              style: AppTheme.body(
                fontSize: 15,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              _controller.text,
              style: AppTheme.body(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 20),
            TextButton.icon(
              onPressed: () {
                _controller.clear();
                provider.resetFeed();
                _focusNode.requestFocus();
              },
              icon: const Icon(Icons.search_rounded, size: 18),
              label: const Text('Search another location'),
              style: TextButton.styleFrom(foregroundColor: AppColors.primary),
            ),
          ],
        ),
      );
    }

    final rooms = provider.feedListings
        .where(
          (l) =>
              l.type == ListingType.housing &&
              l.purpose == ListingPurpose.needRoommate,
        )
        .toList();
    final flatmates = provider.feedListings
        .where((l) => l.type == ListingType.housing && l.isRequirementPost)
        .toList();
    final properties = provider.feedListings
        .where(
          (l) =>
              l.type == ListingType.housing &&
              l.purpose == ListingPurpose.offerProperty,
        )
        .toList();
    final items = provider.feedListings
        .where(
          (l) =>
              l.type == ListingType.marketplace ||
              l.propertyType == PropertyType.item,
        )
        .toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.only(bottom: 40),
      physics: const BouncingScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (rooms.isNotEmpty)
            _buildSection(
              'Rooms',
              Icons.bed_outlined,
              rooms,
              provider,
              (l) => FeaturedListingCard(
                listing: l,
                isSaved: false,
                onTap: () => _openListing(l),
                onSaveTap: () {},
              ),
            ),
          if (flatmates.isNotEmpty)
            _buildSection(
              'Flatmates',
              Icons.people_alt_outlined,
              flatmates,
              provider,
              (l) => FeaturedListingCard(
                listing: l,
                isSaved: false,
                showProfile: true,
                onTap: () => _openListing(l),
                onSaveTap: () {},
              ),
            ),
          if (properties.isNotEmpty)
            _buildSection(
              'Properties',
              Icons.home_work_outlined,
              properties,
              provider,
              (l) => FeaturedListingCard(
                listing: l,
                isSaved: false,
                onTap: () => _openListing(l),
                onSaveTap: () {},
              ),
            ),
          if (items.isNotEmpty)
            _buildSection(
              'Marketplace',
              Icons.shopping_bag_outlined,
              items,
              provider,
              (l) => FeaturedListingCard(
                listing: l,
                isSaved: false,
                onTap: () => _openListing(l),
                onSaveTap: () {},
              ),
            ),

          if (properties.isEmpty &&
              rooms.isEmpty &&
              flatmates.isEmpty &&
              items.isEmpty)
            _buildSection(
              'All Results',
              Icons.explore_outlined,
              provider.feedListings,
              provider,
              (l) => FeaturedListingCard(
                listing: l,
                isSaved: false,
                onTap: () => _openListing(l),
                onSaveTap: () {},
              ),
            ),
        ],
      ),
    );
  }

  void _onSeeAllTapped(String section, LocationSearchProvider provider) {
    final lat = provider.selectedLat;
    final lon = provider.selectedLon;
    final locName = provider.selectedLocationName;

    if (lat != null && lon != null && locName != null) {
      context.read<LocationProvider>().setLocationData(lat, lon, locName);
    }

    if (section == 'Marketplace') {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const MarketplaceScreen()),
      );
      return;
    }

    int tabIndex = 0;
    if (section == 'Rooms') {
      tabIndex = 0;
    } else if (section == 'Flatmates') {
      tabIndex = 1;
    } else if (section == 'Properties') {
      tabIndex = 2;
    } else {
      tabIndex = 0;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => HousingFeedScreen(initialTabIndex: tabIndex),
      ),
    );
  }

  /// Horizontal section wrapper used for each listing category.
  Widget _buildSection(
    String title,
    IconData icon,
    List<ListingModel> listings,
    LocationSearchProvider provider,
    Widget Function(ListingModel) itemBuilder,
  ) {
    const purpleAccent = Color(0xFF6C63FF);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 32, 20, 16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: purpleAccent.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: purpleAccent, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      title,
                      style: AppTheme.headline(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    GestureDetector(
                      onTap: () => _onSeeAllTapped(title, provider),
                      child: Text(
                        'View all',
                        style: AppTheme.body(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: purpleAccent,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        LayoutBuilder(
          builder: (context, constraints) {
            final isCompact = MediaQuery.sizeOf(context).width < 380;
            return SizedBox(
              height: isCompact ? 190 : 210,
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                itemCount: listings.length,
                separatorBuilder: (context, index) =>
                    SizedBox(width: isCompact ? 12 : 14),
                itemBuilder: (context, index) => SizedBox(
                  width: isCompact ? 180 : 200,
                  child: itemBuilder(listings[index]),
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}
