import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';

import 'package:cached_network_image/cached_network_image.dart';

import '../models/listing_model.dart';
import '../services/database_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import 'listing_detail_screen.dart';

class LocationSearchScreen extends StatefulWidget {
  const LocationSearchScreen({super.key});

  @override
  State<LocationSearchScreen> createState() => _LocationSearchScreenState();
}

class _LocationSearchScreenState extends State<LocationSearchScreen> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  
  List<Map<String, dynamic>> _results = [];
  bool _isLoading = false;
  Timer? _debounce;

  bool _showFeed = false;
  bool _isLoadingFeed = false;
  List<ListingModel> _feedListings = [];

  @override
  void initState() {
    super.initState();
    // Automatically focus the text field when the screen opens
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    if (_showFeed) {
      setState(() {
        _showFeed = false;
        _feedListings = [];
      });
    }

    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      _search(query);
    });
  }

  Future<void> _search(String query) async {
    if (query.trim().isEmpty) {
      if (mounted) {
        setState(() {
          _results = [];
          _isLoading = false;
        });
      }
      return;
    }

    setState(() => _isLoading = true);

    try {
      // Using OpenStreetMap Nominatim for free, key-less geocoding
      final url = Uri.parse(
          'https://nominatim.openstreetmap.org/search?q=${Uri.encodeComponent(query)}&format=json&addressdetails=1&limit=8');
      final response =
          await http.get(url, headers: {'User-Agent': 'TriozyApp/1.0'});

      if (response.statusCode == 200) {
        final List data = json.decode(response.body);
        if (mounted) {
          setState(() {
            _results = List<Map<String, dynamic>>.from(data);
            _isLoading = false;
          });
        }
      } else {
        if (mounted) setState(() => _isLoading = false);
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _selectLocation(Map<String, dynamic> place) {
    // Extract a shorter, readable name for display
    final addressDetails = place['address'] as Map<String, dynamic>? ?? {};
    final shortName = addressDetails['neighbourhood'] ??
                      addressDetails['suburb'] ??
                      addressDetails['city_district'] ??
                      addressDetails['city'] ??
                      addressDetails['town'] ??
                      place['name'] ??
                      'Unknown Location';

    // Get lat/lon from Nominatim result
    final lat = double.tryParse(place['lat']?.toString() ?? '') ?? 0.0;
    final lon = double.tryParse(place['lon']?.toString() ?? '') ?? 0.0;

    // Build a readable name for text-fallback matching
    final city = (addressDetails['city'] ?? addressDetails['town'] ?? '').toString();

    _controller.text = shortName;
    _focusNode.unfocus();

    setState(() {
      _results = [];
      _showFeed = true;
      _isLoadingFeed = true;
    });

    _fetchFeedForLocation(lat, lon, city.isNotEmpty ? city : shortName);
  }

  Future<void> _fetchFeedForLocation(double lat, double lon, String locationName) async {
    try {
      final db = context.read<DatabaseService>();
      // Get listings within 10km of the selected coordinates
      final listings = await db.getNearbyListings(
        lat: lat,
        lon: lon,
        radiusKm: 10.0,
        locationName: locationName,
      );
      if (mounted) {
        setState(() {
          _feedListings = listings;
          _isLoadingFeed = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoadingFeed = false);
    }
  }

  void _openListing(ListingModel listing) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ListingDetailScreen(listingId: listing.id, seed: listing),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        titleSpacing: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: AppColors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: Padding(
          padding: const EdgeInsets.only(right: 16.0),
          child: TextField(
            controller: _controller,
            focusNode: _focusNode,
            onChanged: _onSearchChanged,
            decoration: InputDecoration(
              hintText: 'Search city or locality...',
              hintStyle: AppTheme.body(
                fontSize: 15,
                color: AppColors.textHint,
              ),
              border: InputBorder.none,
              suffixIcon: _controller.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.close_rounded, color: AppColors.textSecondary, size: 20),
                      onPressed: () {
                        _controller.clear();
                        _onSearchChanged('');
                      },
                    )
                  : null,
            ),
            style: AppTheme.body(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: AppColors.textPrimary,
            ),
          ),
        ),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    // 1. Loading geocoding results
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator(color: AppColors.primary));
    }

    // 2. Showing the feed after selecting a location
    if (_showFeed) {
      return _buildFeedView();
    }

    // 3. Showing geocoding search results
    if (_results.isNotEmpty) {
      return ListView.separated(
        itemCount: _results.length,
        separatorBuilder: (context, index) => const Divider(height: 1, color: AppColors.divider),
        itemBuilder: (context, index) {
          final place = _results[index];
          final fullName = place['display_name'] ?? '';
          final nameParts = fullName.split(', ');
          final title = nameParts.isNotEmpty ? nameParts.first : fullName;
          final subtitle = nameParts.length > 1 ? nameParts.skip(1).join(', ') : '';

          return ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
            leading: const Icon(Icons.location_on_rounded, color: AppColors.primary),
            title: Text(title, style: AppTheme.body(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
            subtitle: subtitle.isNotEmpty
                ? Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppTheme.body(fontSize: 13, color: AppColors.textSecondary))
                : null,
            onTap: () => _selectLocation(place),
          );
        },
      );
    }

    // 4. Empty / initial state
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.search_rounded, size: 48, color: AppColors.textHint.withValues(alpha: 0.5)),
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

  Widget _buildFeedView() {
    if (_isLoadingFeed) {
      return const Center(child: CircularProgressIndicator(color: AppColors.primary));
    }

    if (_feedListings.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.location_off_rounded, size: 56, color: AppColors.textHint.withValues(alpha: 0.4)),
            const SizedBox(height: 16),
            Text(
              'No listings found near',
              style: AppTheme.body(fontSize: 15, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 4),
            Text(
              _controller.text,
              style: AppTheme.body(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
            ),
            const SizedBox(height: 20),
            TextButton.icon(
              onPressed: () {
                _controller.clear();
                setState(() {
                  _showFeed = false;
                  _feedListings = [];
                });
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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
          child: Row(
            children: [
              const Icon(Icons.location_on_rounded, size: 18, color: AppColors.primary),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  '${_feedListings.length} listing${_feedListings.length == 1 ? '' : 's'} near ${_controller.text}',
                  style: AppTheme.body(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
            itemCount: _feedListings.length,
            separatorBuilder: (context, index) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final listing = _feedListings[index];
              return _LocationFeedCard(
                listing: listing,
                onTap: () => _openListing(listing),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _LocationFeedCard extends StatelessWidget {
  final ListingModel listing;
  final VoidCallback onTap;

  const _LocationFeedCard({required this.listing, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final typeLabel = listing.propertyType == PropertyType.pg
        ? 'PG'
        : listing.propertyType == PropertyType.flat
            ? 'Flatmate'
            : listing.propertyType == PropertyType.room
                ? 'Room'
                : 'Item';

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.black.withValues(alpha: 0.04)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            // Image
            ClipRRect(
              borderRadius: const BorderRadius.horizontal(left: Radius.circular(16)),
              child: SizedBox(
                width: 110,
                height: 110,
                child: listing.imageUrls.isEmpty
                    ? Container(
                        color: AppColors.accentLavender,
                        child: Icon(
                          Icons.home_work_outlined,
                          color: AppColors.primary.withValues(alpha: 0.4),
                          size: 32,
                        ),
                      )
                    : CachedNetworkImage(
                        imageUrl: listing.imageUrls.first,
                        fit: BoxFit.cover,
                        errorWidget: (_, _, _) => Container(
                          color: AppColors.accentLavender,
                          child: Icon(
                            Icons.home_work_outlined,
                            color: AppColors.primary.withValues(alpha: 0.4),
                            size: 32,
                          ),
                        ),
                      ),
              ),
            ),
            // Details
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Type badge
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        gradient: AppColors.primaryGradient,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        typeLabel,
                        style: AppTheme.body(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    // Title
                    Text(
                      listing.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTheme.body(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 4),
                    // Location
                    Row(
                      children: [
                        const Icon(Icons.location_on_rounded, size: 12, color: AppColors.textSecondary),
                        const SizedBox(width: 3),
                        Expanded(
                          child: Text(
                            listing.location,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTheme.body(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    // Price
                    RichText(
                      text: TextSpan(
                        style: AppTheme.headline(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary,
                        ),
                        children: [
                          TextSpan(text: listing.priceLabel),
                          if (listing.price > 0)
                            TextSpan(
                              text: ' /month',
                              style: AppTheme.body(
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                                color: AppColors.textSecondary,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // Arrow
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: Icon(
                Icons.chevron_right_rounded,
                color: AppColors.textHint,
                size: 22,
              ),
            ),
          ],
        ),
      ),
    );
  }
}