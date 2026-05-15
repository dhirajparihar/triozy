import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../models/listing_model.dart';
import '../services/database_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import 'listing_detail_screen.dart';
import '../providers/location_search_provider.dart';

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
    WidgetsBinding.instance.addPostFrameCallback((_) => _focusNode.requestFocus());
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _selectLocation(LocationSearchProvider provider, Map<String, dynamic> place) {
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
    final city = (addressDetails['city'] ?? addressDetails['town'] ?? '').toString();

    _controller.text = shortName;
    _focusNode.unfocus();

    final db = context.read<DatabaseService>();
    provider.fetchFeedForLocation(db, lat, lon, city.isNotEmpty ? city : shortName);
  }

  void _openListing(ListingModel listing) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => ListingDetailScreen(listingId: listing.id, seed: listing)),
    );
  }

  @override
  Widget build(BuildContext context) {
    const backgroundColor = Color(0xFFF9FAFB); // Light background to match mockup

    return ChangeNotifierProvider(
      create: (_) => LocationSearchProvider(),
      child: Consumer<LocationSearchProvider>(builder: (context, provider, _) {
        return Scaffold(
          backgroundColor: backgroundColor,
          appBar: AppBar(
            backgroundColor: backgroundColor,
            elevation: 0,
            titleSpacing: 0,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_rounded, color: AppColors.textPrimary),
              onPressed: () => Navigator.pop(context),
            ),
            title: Padding(
              padding: const EdgeInsets.only(right: 16.0),
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      height: 48,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey.shade200),
                        boxShadow: [
                          BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 4, offset: const Offset(0, 2))
                        ]
                      ),
                      child: Row(
                        children: [
                          const SizedBox(width: 12),
                          Icon(Icons.search_rounded, color: Colors.grey.shade500, size: 22),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextField(
                              controller: _controller,
                              focusNode: _focusNode,
                              onChanged: provider.onSearchChanged,
                              decoration: InputDecoration(
                                hintText: 'Search city or locality...',
                                hintStyle: AppTheme.body(fontSize: 15, color: AppColors.textHint),
                                border: InputBorder.none,
                                isDense: true,
                                contentPadding: EdgeInsets.zero,
                              ),
                              style: AppTheme.body(fontSize: 15, fontWeight: FontWeight.w500, color: AppColors.textPrimary),
                            ),
                          ),
                          if (_controller.text.isNotEmpty)
                            IconButton(
                              icon: const Icon(Icons.close_rounded, color: AppColors.textSecondary, size: 20),
                              onPressed: () {
                                _controller.clear();
                                provider.clearSearch();
                                provider.resetFeed();
                                _focusNode.requestFocus();
                              },
                            ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.shade200),
                      boxShadow: [
                        BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 4, offset: const Offset(0, 2))
                      ]
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.tune_rounded, color: AppColors.textPrimary, size: 22),
                      onPressed: () {},
                    ),
                  ),
                ],
              ),
            ),
          ),
          body: _buildBody(provider),
        );
      }),
    );
  }

  Widget _buildBody(LocationSearchProvider provider) {
    if (provider.isLoading) return const Center(child: CircularProgressIndicator(color: AppColors.primary));

    if (provider.showFeed) return _buildFeedView(provider);

    if (provider.results.isNotEmpty) {
      return Container(
        color: Colors.white,
        child: ListView.separated(
          itemCount: provider.results.length,
          separatorBuilder: (context, index) => const Divider(height: 1, color: AppColors.divider),
          itemBuilder: (context, index) {
            final place = provider.results[index];
            final fullName = place['display_name'] ?? '';
            final nameParts = fullName.split(', ');
            final title = nameParts.isNotEmpty ? nameParts.first : fullName;
            final subtitle = nameParts.length > 1 ? nameParts.skip(1).join(', ') : '';

            return ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
              leading: const Icon(Icons.location_on_rounded, color: AppColors.primary),
              title: Text(title, style: AppTheme.body(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
              subtitle: subtitle.isNotEmpty ? Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppTheme.body(fontSize: 13, color: AppColors.textSecondary)) : null,
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
          Icon(Icons.location_city_rounded, size: 64, color: AppColors.textHint.withValues(alpha: 0.3)),
          const SizedBox(height: 12),
          Text(_controller.text.isEmpty ? 'Search for a city or locality' : 'No locations found', style: AppTheme.body(fontSize: 15, color: AppColors.textSecondary)),
        ],
      ),
    );
  }

  Widget _buildFeedView(LocationSearchProvider provider) {
    if (provider.isLoadingFeed) return const Center(child: CircularProgressIndicator(color: AppColors.primary));

    if (provider.feedListings.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.location_off_rounded, size: 56, color: AppColors.textHint.withValues(alpha: 0.4)),
            const SizedBox(height: 16),
            Text('No listings found near', style: AppTheme.body(fontSize: 15, color: AppColors.textSecondary)),
            const SizedBox(height: 4),
            Text(_controller.text, style: AppTheme.body(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
            const SizedBox(height: 20),
            TextButton.icon(onPressed: () {
              _controller.clear();
              provider.resetFeed();
              _focusNode.requestFocus();
            }, icon: const Icon(Icons.search_rounded, size: 18), label: const Text('Search another location'), style: TextButton.styleFrom(foregroundColor: AppColors.primary)),
          ],
        ),
      );
    }

    final pgs = provider.feedListings.where((l) => l.propertyType == PropertyType.pg).toList();
    final rooms = provider.feedListings.where((l) => l.propertyType == PropertyType.room).toList();
    final flatmates = provider.feedListings.where((l) => l.purpose == ListingPurpose.needRoommate || l.isRequirementPost).toList();
    final items = provider.feedListings.where((l) => l.propertyType == PropertyType.item).toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.only(bottom: 40),
      physics: const BouncingScrollPhysics(),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (rooms.isNotEmpty) 
          _buildSection('Rooms', 'Listed by people who have a room and looking for a roommate', Icons.bed_outlined, rooms, (l) => _RoomPgCard(listing: l, onTap: () => _openListing(l))),
        if (flatmates.isNotEmpty) 
          _buildSection('Flatmates', 'People who are searching for a room', Icons.people_alt_outlined, flatmates, (l) => _FlatmateCard(listing: l, onTap: () => _openListing(l))),
        if (pgs.isNotEmpty) 
          _buildSection('PGs', 'Listed by PG owners', Icons.home_work_outlined, pgs, (l) => _RoomPgCard(listing: l, onTap: () => _openListing(l))),
        if (items.isNotEmpty) 
          _buildSection('Marketplace', 'Buy and sell items', Icons.shopping_bag_outlined, items, (l) => _MarketplaceCard(listing: l, onTap: () => _openListing(l))),
          
        if (pgs.isEmpty && rooms.isEmpty && flatmates.isEmpty && items.isEmpty) 
          _buildSection('All Results', 'Listings in this area', Icons.explore_outlined, provider.feedListings, (l) => _RoomPgCard(listing: l, onTap: () => _openListing(l))),
      ]),
    );
  }

  Widget _buildSection(String title, String subtitle, IconData icon, List<ListingModel> listings, Widget Function(ListingModel) itemBuilder) {
    const purpleAccent = Color(0xFF6C63FF);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 32, 20, 16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
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
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(title, style: AppTheme.headline(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
                        Text('View all', style: AppTheme.body(fontSize: 14, fontWeight: FontWeight.w700, color: purpleAccent)),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(subtitle, style: AppTheme.body(fontSize: 13, color: AppColors.textSecondary)),
                  ],
                ),
              ),
            ],
          ),
        ),
        SizedBox(
          height: title == 'Flatmates' ? 260 : (title == 'Marketplace' ? 240 : 280),
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            itemCount: listings.length,
            separatorBuilder: (context, index) => const SizedBox(width: 16),
            itemBuilder: (context, index) => itemBuilder(listings[index]),
          ),
        ),
      ],
    );
  }
}

// ─── Custom UI Cards matching mockup ─────────────────────────────────────────

class _RoomPgCard extends StatelessWidget {
  final ListingModel listing;
  final VoidCallback onTap;

  const _RoomPgCard({required this.listing, required this.onTap});

  @override
  Widget build(BuildContext context) {
    const purpleAccent = Color(0xFF6C63FF);
    final tags = listing.propertyType == PropertyType.pg 
        ? ['Twin Sharing', 'Food Included'] 
        : ['Private Room', 'Attached Bath'];

    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: 240,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Stack(children: [
            Container(
              height: 160,
              width: 240,
              decoration: BoxDecoration(borderRadius: BorderRadius.circular(16), color: Colors.grey.shade200),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: listing.imageUrls.isEmpty
                    ? Icon(Icons.home_work_outlined, color: Colors.grey.shade300, size: 48)
                    : CachedNetworkImage(imageUrl: listing.imageUrls.first, fit: BoxFit.cover),
              ),
            ),
            Positioned(
              top: 12,
              right: 12,
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                child: const Icon(Icons.favorite_border_rounded, size: 18, color: Colors.black87),
              ),
            ),
            Positioned(
              bottom: 12,
              left: 12,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.6), borderRadius: BorderRadius.circular(20)),
                child: Row(children: [
                  const Icon(Icons.location_on, color: Colors.white, size: 12),
                  const SizedBox(width: 4),
                  Text(listing.location.split(',').first, style: AppTheme.body(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.white))
                ]),
              ),
            ),
          ]),
          const SizedBox(height: 12),
          Text(listing.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppTheme.headline(fontSize: 15, fontWeight: FontWeight.w800, color: Colors.black87)),
          const SizedBox(height: 8),
          Row(children: tags.map((t) => Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(color: purpleAccent.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(8)),
              child: Text(t, style: AppTheme.body(fontSize: 11, fontWeight: FontWeight.w700, color: purpleAccent)),
            ),
          )).toList()),
          const SizedBox(height: 10),
          RichText(
            text: TextSpan(
              style: AppTheme.headline(fontSize: 15, fontWeight: FontWeight.w800, color: Colors.black87),
              children: [
                TextSpan(text: listing.priceLabel),
                if (listing.price > 0) TextSpan(text: '/mo', style: AppTheme.body(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.black87)),
                TextSpan(text: ' • Furnished', style: AppTheme.body(fontSize: 13, color: AppColors.textSecondary)),
              ],
            ),
          ),
        ]),
      ),
    );
  }
}

class _FlatmateCard extends StatelessWidget {
  final ListingModel listing;
  final VoidCallback onTap;

  const _FlatmateCard({required this.listing, required this.onTap});

  @override
  Widget build(BuildContext context) {
    const purpleAccent = Color(0xFF6C63FF);
    final req = listing.requirementDetails;
    final budgetText = req != null && (req.minBudget > 0 || req.maxBudget > 0) 
        ? '₹${req.minBudget}${req.maxBudget > 0 && req.minBudget > 0 ? ' - ₹${req.maxBudget}' : (req.maxBudget > 0 ? ' - ₹${req.maxBudget}' : '')}' 
        : listing.priceLabel;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 280,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.shade100),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 10, offset: const Offset(0, 4))],
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Stack(children: [
              CircleAvatar(radius: 26, backgroundColor: Colors.grey.shade200, backgroundImage: listing.ownerPhotoUrl.isNotEmpty ? NetworkImage(listing.ownerPhotoUrl) : null, child: listing.ownerPhotoUrl.isEmpty ? Text(listing.ownerName.isNotEmpty ? listing.ownerName[0] : '?', style: AppTheme.headline(fontSize: 18)) : null),
              Positioned(bottom: 0, right: 0, child: Container(width: 14, height: 14, decoration: BoxDecoration(color: Colors.green, shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 2)))),
            ]),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(listing.ownerName.isNotEmpty ? listing.ownerName : 'Anonymous', maxLines: 1, overflow: TextOverflow.ellipsis, style: AppTheme.headline(fontSize: 15, fontWeight: FontWeight.w800, color: Colors.black87)),
              const SizedBox(height: 2),
              Text('24 • Male', style: AppTheme.body(fontSize: 12, color: AppColors.textSecondary)), // Mocked demographic
              const SizedBox(height: 4),
              Row(children: [
                const Icon(Icons.location_on, size: 12, color: AppColors.textSecondary),
                const SizedBox(width: 4),
                Expanded(child: Text(listing.location, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppTheme.body(fontSize: 12, color: AppColors.textSecondary))),
              ]),
            ])),
          ]),
          const SizedBox(height: 16),
          _buildInfoRow(Icons.person_outline, 'Working Professional'),
          const SizedBox(height: 8),
          _buildInfoRow(Icons.search_rounded, 'Looking for a private room'),
          const SizedBox(height: 8),
          _buildInfoRow(Icons.account_balance_wallet_outlined, 'Budget: $budgetText'),
          const Spacer(),
          Row(children: [
            Expanded(child: TextButton(
              onPressed: onTap,
              style: TextButton.styleFrom(backgroundColor: purpleAccent.withValues(alpha: 0.08), foregroundColor: purpleAccent, padding: const EdgeInsets.symmetric(vertical: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
              child: Text('View Profile', style: AppTheme.body(fontSize: 13, fontWeight: FontWeight.w700)),
            )),
            const SizedBox(width: 12),
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(color: purpleAccent.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(12)),
              child: IconButton(
                icon: const Icon(Icons.chat_bubble_outline_rounded, color: purpleAccent, size: 20),
                onPressed: () {}, // Add chat tap logic if needed
              ),
            ),
          ]),
        ]),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String text) {
    return Row(children: [
      Icon(icon, size: 16, color: AppColors.textSecondary),
      const SizedBox(width: 8),
      Expanded(child: Text(text, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppTheme.body(fontSize: 13, color: Colors.black87))),
    ]);
  }
}

class _MarketplaceCard extends StatelessWidget {
  final ListingModel listing;
  final VoidCallback onTap;
  const _MarketplaceCard({required this.listing, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: 140,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            height: 140,
            width: 140,
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(16), color: Colors.grey.shade100),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: listing.imageUrls.isEmpty
                  ? Icon(Icons.image_outlined, color: Colors.grey.shade400, size: 40)
                  : CachedNetworkImage(imageUrl: listing.imageUrls.first, fit: BoxFit.cover),
            ),
          ),
          const SizedBox(height: 12),
          Text(listing.priceLabel, style: AppTheme.headline(fontSize: 15, fontWeight: FontWeight.w800, color: Colors.black87)),
          const SizedBox(height: 4),
          Text(listing.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppTheme.body(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.black87)),
          const SizedBox(height: 4),
          Row(children: [
            const Icon(Icons.location_on, size: 12, color: AppColors.textSecondary),
            const SizedBox(width: 4),
            Expanded(child: Text(listing.location.split(',').first, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppTheme.body(fontSize: 12, color: AppColors.textSecondary))),
          ]),
        ]),
      ),
    );
  }
}
