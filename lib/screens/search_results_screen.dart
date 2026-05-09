import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/listing_model.dart';
import '../services/database_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../widgets/listing_card.dart';
import 'listing_detail_screen.dart';
import 'post_listing_screen.dart';

class SearchResultsScreen extends StatefulWidget {
  final PropertyType? initialPropertyType;
  final String? initialQuery;
  final ListingType? lockedType;
  final String title;
  final String? subtitle;
  final String? searchHint;
  final bool showCreateListingButton;
  final PropertyType? createListingPropertyType;
  final ListingPurpose? createListingPurpose;

  const SearchResultsScreen({
    super.key,
    this.initialPropertyType,
    this.initialQuery,
    this.lockedType,
    this.title = 'Explore',
    this.subtitle,
    this.searchHint,
    this.showCreateListingButton = false,
    this.createListingPropertyType,
    this.createListingPurpose,
  });

  @override
  State<SearchResultsScreen> createState() => SearchResultsScreenState();
}

class SearchResultsScreenState extends State<SearchResultsScreen> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();

  List<ListingModel> _results = [];
  Set<String> _savedIds = <String>{};
  ListingType _selectedType = ListingType.housing;
  PropertyType? _selectedPropertyType;
  double? _maxBudget;
  String _sortBy = 'Recently Added';
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    if (widget.lockedType != null) {
      _selectedType = widget.lockedType!;
    }
    if (widget.initialPropertyType != null) {
      _selectedPropertyType = widget.initialPropertyType;
      _selectedType = widget.initialPropertyType!.listingType;
    }
    if (widget.initialQuery != null) {
      _searchController.text = widget.initialQuery!;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (widget.initialQuery != null && widget.initialQuery!.isEmpty) {
        _searchFocusNode.requestFocus();
      }
      _loadListings();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  void focusAndSearch(String query) {
    _searchController.text = query;
    _searchFocusNode.requestFocus();
    _loadListings();
  }

  void applyQuickPropertyType(PropertyType propertyType) {
    setState(() {
      _selectedPropertyType = propertyType;
      _selectedType = propertyType.listingType;
    });
    _loadListings();
  }

  Future<void> _loadListings() async {
    setState(() => _loading = true);

    final db = context.read<DatabaseService>();
    final listings = await db.searchListings(
      query: _searchController.text,
      type: _selectedType,
      propertyType: _selectedPropertyType,
      maxPrice: _maxBudget,
    );
    final userId = FirebaseAuth.instance.currentUser?.uid;
    final savedListings = userId == null
        ? <ListingModel>[]
        : await db.getSavedListings(userId);

    if (!mounted) {
      return;
    }

    setState(() {
      _results = _sortResults(listings);
      _savedIds = savedListings.map((listing) => listing.id).toSet();
      _loading = false;
    });
  }

  List<ListingModel> _sortResults(List<ListingModel> listings) {
    final sorted = [...listings];
    switch (_sortBy) {
      case 'Price: Low to High':
        sorted.sort((a, b) => a.price.compareTo(b.price));
        break;
      case 'Price: High to Low':
        sorted.sort((a, b) => b.price.compareTo(a.price));
        break;
      case 'Featured':
        sorted.sort(
          (a, b) => (b.isFeatured ? 1 : 0).compareTo(a.isFeatured ? 1 : 0),
        );
        break;
      case 'Recently Added':
      default:
        sorted.sort(
          (a, b) => (b.createdAt ?? DateTime(0)).compareTo(
            a.createdAt ?? DateTime(0),
          ),
        );
        break;
    }
    return sorted;
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

  Future<void> _openPostListing() async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => PostListingScreen(
          initialPropertyType: widget.createListingPropertyType,
          initialPurpose: widget.createListingPurpose,
        ),
      ),
    );
    if (result == true && mounted) {
      _loadListings();
    }
  }

  @override
  Widget build(BuildContext context) {
    final subtitle = widget.subtitle?.trim() ?? '';

    return Scaffold(
      backgroundColor: AppColors.background,
      floatingActionButton: widget.showCreateListingButton
          ? FloatingActionButton.extended(
              onPressed: _openPostListing,
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              icon: const Icon(Icons.add_rounded),
              label: Text(
                'List item',
                style: AppTheme.body(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
            )
          : null,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(widget.title, style: AppTheme.headline(fontSize: 28)),
                  if (subtitle.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      subtitle,
                      style: AppTheme.body(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: AppColors.onSurfaceVariant,
                        height: 1.5,
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  _buildSearchBar(),
                  if (widget.lockedType == null) ...[
                    const SizedBox(height: 14),
                    _buildTypeTabs(),
                  ],
                  const SizedBox(height: 12),
                  _buildFilterRow(),
                ],
              ),
            ),
            Expanded(
              child: RefreshIndicator(
                onRefresh: _loadListings,
                color: AppColors.primary,
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 110),
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '${_results.length} listings',
                          style: AppTheme.body(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppColors.slate500,
                          ),
                        ),
                        _SortMenu(
                          currentValue: _sortBy,
                          onSelected: (value) {
                            setState(() {
                              _sortBy = value;
                              _results = _sortResults(_results);
                            });
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    if (_loading)
                      const _ExploreLoadingState()
                    else if (_results.isEmpty)
                      _EmptyState(
                        title: _selectedType == ListingType.marketplace
                            ? 'No marketplace items yet'
                            : 'No listings found',
                        subtitle: _selectedType == ListingType.marketplace
                            ? 'Used furniture, appliances, and move-in essentials will appear here once people list them.'
                            : 'Try another area, category, or budget.',
                        icon: _selectedType == ListingType.marketplace
                            ? Icons.shopping_bag_outlined
                            : Icons.inbox_outlined,
                      )
                    else
                      ..._results.map((listing) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 16),
                          child: ListingCard(
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
        ),
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      decoration: AppTheme.cardDecoration(
        color: AppColors.surfaceContainerLowest,
        radiusValue: 18,
        shadowAlpha: 0.06,
        blur: 18,
        offsetY: 8,
      ),
      child: TextField(
        controller: _searchController,
        focusNode: _searchFocusNode,
        decoration: InputDecoration(
          hintText:
              widget.searchHint ??
              'Search by title, area, college, company or item',
          prefixIcon: const Icon(Icons.search_rounded),
          suffixIcon: _searchController.text.isEmpty
              ? null
              : IconButton(
                  onPressed: () {
                    _searchController.clear();
                    _loadListings();
                  },
                  icon: const Icon(Icons.close_rounded),
                ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(18),
            borderSide: BorderSide.none,
          ),
        ),
        onChanged: (_) => setState(() {}),
        onSubmitted: (_) => _loadListings(),
      ),
    );
  }

  Widget _buildTypeTabs() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerHigh,
        borderRadius: AppTheme.radius(18),
      ),
      child: Row(
        children: ListingType.values.map((type) {
          final selected = _selectedType == type;
          return Expanded(
            child: GestureDetector(
              onTap: () {
                setState(() {
                  _selectedType = type;
                  if (_selectedPropertyType != null &&
                      _selectedPropertyType!.listingType != type) {
                    _selectedPropertyType = null;
                  }
                });
                _loadListings();
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: selected
                      ? AppColors.surfaceContainerLowest
                      : Colors.transparent,
                  borderRadius: AppTheme.radius(14),
                ),
                child: Center(
                  child: Text(
                    type.label,
                    style: AppTheme.body(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: selected
                          ? AppColors.primary
                          : AppColors.onSurfaceVariant,
                    ),
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildFilterRow() {
    final propertyTypes = PropertyType.values
        .where((propertyType) => propertyType.listingType == _selectedType)
        .toList();
    final showPropertyTypeFilters = widget.lockedType == null
        ? propertyTypes.isNotEmpty
        : propertyTypes.length > 1;

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          if (showPropertyTypeFilters)
            ...propertyTypes.map((propertyType) {
              final selected = _selectedPropertyType == propertyType;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: FilterChip(
                  selected: selected,
                  label: Text(propertyType.label),
                  onSelected: (_) {
                    setState(() {
                      _selectedPropertyType = selected ? null : propertyType;
                    });
                    _loadListings();
                  },
                  selectedColor: AppColors.secondaryContainer.withValues(
                    alpha: 0.75,
                  ),
                  labelStyle: AppTheme.label(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: selected
                        ? AppColors.primary
                        : AppColors.onSurfaceVariant,
                  ),
                  side: BorderSide(
                    color: AppColors.outlineVariant.withValues(alpha: 0.25),
                  ),
                ),
              );
            }),
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilterChip(
              selected: _maxBudget != null,
              label: Text(
                _maxBudget == null
                    ? 'Budget'
                    : 'Under Rs ${_maxBudget!.toInt()}',
              ),
              onSelected: (_) => _showBudgetSheet(),
              selectedColor: AppColors.secondaryContainer.withValues(
                alpha: 0.75,
              ),
              labelStyle: AppTheme.label(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: _maxBudget != null
                    ? AppColors.primary
                    : AppColors.onSurfaceVariant,
              ),
              side: BorderSide(
                color: AppColors.outlineVariant.withValues(alpha: 0.25),
              ),
            ),
          ),
          if (_selectedPropertyType != null || _maxBudget != null)
            TextButton(
              onPressed: () {
                setState(() {
                  _selectedPropertyType = null;
                  _maxBudget = null;
                });
                _loadListings();
              },
              child: Text(
                'Clear',
                style: AppTheme.body(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primary,
                ),
              ),
            ),
        ],
      ),
    );
  }

  void _showBudgetSheet() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.surfaceContainerLowest,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        final options = _selectedType == ListingType.housing
            ? <double>[8000, 12000, 18000, 25000]
            : <double>[3000, 6000, 10000, 20000];
        return Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Choose max budget', style: AppTheme.headline(fontSize: 20)),
              const SizedBox(height: 16),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: options.map((value) {
                  final selected = _maxBudget == value;
                  return ChoiceChip(
                    label: Text('Rs ${value.toInt()}'),
                    selected: selected,
                    onSelected: (_) {
                      setState(() => _maxBudget = selected ? null : value);
                      Navigator.pop(context);
                      _loadListings();
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

class _SortMenu extends StatelessWidget {
  final String currentValue;
  final ValueChanged<String> onSelected;

  const _SortMenu({required this.currentValue, required this.onSelected});

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      onSelected: onSelected,
      itemBuilder: (context) => const [
        PopupMenuItem(value: 'Recently Added', child: Text('Recently Added')),
        PopupMenuItem(value: 'Featured', child: Text('Featured')),
        PopupMenuItem(
          value: 'Price: Low to High',
          child: Text('Price: Low to High'),
        ),
        PopupMenuItem(
          value: 'Price: High to Low',
          child: Text('Price: High to Low'),
        ),
      ],
      child: Row(
        children: [
          Text(
            currentValue,
            style: AppTheme.body(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.slate500,
            ),
          ),
          const Icon(
            Icons.keyboard_arrow_down_rounded,
            color: AppColors.slate500,
          ),
        ],
      ),
    );
  }
}

class _ExploreLoadingState extends StatelessWidget {
  const _ExploreLoadingState();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: List.generate(
        3,
        (_) => Container(
          height: 280,
          margin: const EdgeInsets.only(bottom: 16),
          decoration: AppTheme.cardDecoration(
            color: AppColors.surfaceContainerLowest,
            radiusValue: 24,
            shadowAlpha: 0.04,
            blur: 18,
            offsetY: 8,
          ),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;

  const _EmptyState({
    this.title = 'No listings found',
    this.subtitle = 'Try another area, category, or budget.',
    this.icon = Icons.inbox_outlined,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: AppTheme.cardDecoration(
        color: AppColors.surfaceContainerLowest,
        radiusValue: 24,
        shadowAlpha: 0.05,
        blur: 18,
        offsetY: 8,
      ),
      child: Column(
        children: [
          Icon(icon, size: 40, color: AppColors.slate400),
          const SizedBox(height: 12),
          Text(title, style: AppTheme.headline(fontSize: 20)),
          const SizedBox(height: 8),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: AppTheme.body(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: AppColors.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
