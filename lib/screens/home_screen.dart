import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/listing_model.dart';
import '../services/database_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../widgets/listing_card.dart';
import 'listing_detail_screen.dart';

class HomeScreen extends StatefulWidget {
  final VoidCallback? onExploreTapped;
  final ValueChanged<PropertyType>? onPropertyTypeSelected;

  const HomeScreen({
    super.key,
    this.onExploreTapped,
    this.onPropertyTypeSelected,
  });

  @override
  State<HomeScreen> createState() => HomeScreenState();
}

class HomeScreenState extends State<HomeScreen> {
  List<ListingModel> _featured = [];
  Set<String> _savedIds = <String>{};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadData());
  }

  Future<void> refreshFromShell() => _loadData();

  Future<void> _loadData() async {
    final db = context.read<DatabaseService>();
    try {
      final featured = await db.getFeaturedListings(limit: 4);
      final userId = FirebaseAuth.instance.currentUser?.uid;
      final saved = userId == null
          ? <ListingModel>[]
          : await db.getSavedListings(userId);

      if (!mounted) {
        return;
      }
      setState(() {
        _featured = featured;
        _savedIds = saved.map((listing) => listing.id).toSet();
        _loading = false;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() => _loading = false);
    }
  }

  Future<void> _toggleSave(String listingId) async {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sign in to save listings')),
      );
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
        builder: (_) => ListingDetailScreen(listingId: listing.id, seed: listing),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _loadData,
      color: AppColors.primary,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 110),
        children: [
          _HeroSection(
            onSearchTap: widget.onExploreTapped,
          ),
          const SizedBox(height: 24),
          _QuickCategoryRow(onPropertyTypeSelected: widget.onPropertyTypeSelected),
          const SizedBox(height: 28),
          _SectionHeader(
            title: 'Featured for your move',
            actionLabel: 'Explore',
            onActionTap: widget.onExploreTapped,
          ),
          const SizedBox(height: 14),
          if (_loading)
            const _HomeLoadingState()
          else
            SizedBox(
              height: 330,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: _featured.length,
                separatorBuilder: (_, _) => const SizedBox(width: 16),
                itemBuilder: (context, index) {
                  final listing = _featured[index];
                  return SizedBox(
                    width: 290,
                    child: ListingCard(
                      listing: listing,
                      onTap: () => _openListing(listing),
                      onSaveTap: () => _toggleSave(listing.id),
                      isSaved: _savedIds.contains(listing.id),
                    ),
                  );
                },
              ),
          ),
          const SizedBox(height: 28),
          const _LivingStrip(),
        ],
      ),
    );
  }
}

class _HeroSection extends StatelessWidget {
  final VoidCallback? onSearchTap;

  const _HeroSection({this.onSearchTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFF6F9FF), Color(0xFFEAF1FF)],
        ),
        borderRadius: BorderRadius.circular(32),
        border: Border.all(color: AppColors.outlineVariant.withValues(alpha: 0.18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Move to a new city without starting from zero.',
            style: AppTheme.headline(fontSize: 30, letterSpacing: -1.0),
          ),
          const SizedBox(height: 10),
          Text(
            'Find a room or PG, discover flatmates, and shop move-in essentials in one calm flow.',
            style: AppTheme.body(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: AppColors.onSurfaceVariant,
              height: 1.6,
            ),
          ),
          const SizedBox(height: 22),
          GestureDetector(
            onTap: onSearchTap,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Row(
                children: [
                  const Icon(Icons.search_rounded, color: AppColors.slate500),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Search rooms, PGs, flatmates or used items',
                      style: AppTheme.body(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: AppColors.slate500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _QuickCategoryRow extends StatelessWidget {
  final ValueChanged<PropertyType>? onPropertyTypeSelected;

  const _QuickCategoryRow({this.onPropertyTypeSelected});

  @override
  Widget build(BuildContext context) {
    final categories = [
      (PropertyType.room, Icons.bed_rounded),
      (PropertyType.flat, Icons.groups_rounded),
      (PropertyType.pg, Icons.apartment_rounded),
      (PropertyType.item, Icons.chair_alt_rounded),
    ];

    return SizedBox(
      height: 146,
      child: Row(
        children: List.generate(categories.length, (index) {
          final entry = categories[index];
          final isLast = index == categories.length - 1;

          return Expanded(
            child: Padding(
              padding: EdgeInsets.only(right: isLast ? 0 : 10),
              child: GestureDetector(
                onTap: () => onPropertyTypeSelected?.call(entry.$1),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      height: 82,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(22),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.04),
                            blurRadius: 18,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      padding: const EdgeInsets.all(14),
                      child: Center(
                        child: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: AppColors.blue50,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Icon(entry.$2, color: AppColors.primary, size: 20),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      entry.$1.label,
                      textAlign: TextAlign.center,
                      style: AppTheme.body(fontSize: 13, fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}

class _LivingStrip extends StatelessWidget {
  const _LivingStrip();

  @override
  Widget build(BuildContext context) {
    final items = const [
      'No brokerage-first browsing',
      'Flatmate-friendly discovery',
      'Marketplace for essentials',
    ];

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: AppColors.outlineVariant.withValues(alpha: 0.18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Built for students and professionals',
            style: AppTheme.headline(fontSize: 20),
          ),
          const SizedBox(height: 14),
          ...items.map((item) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                children: [
                  const Icon(Icons.check_circle_rounded, color: AppColors.primary, size: 18),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      item,
                      style: AppTheme.body(fontSize: 14, fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final String? actionLabel;
  final VoidCallback? onActionTap;

  const _SectionHeader({
    required this.title,
    this.actionLabel,
    this.onActionTap,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(title, style: AppTheme.headline(fontSize: 22)),
        if (actionLabel != null)
          TextButton(
            onPressed: onActionTap,
            child: Text(
              actionLabel!,
              style: AppTheme.body(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: AppColors.primary,
              ),
            ),
          ),
      ],
    );
  }
}

class _HomeLoadingState extends StatelessWidget {
  const _HomeLoadingState();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: List.generate(
        1,
        (_) => Container(
          height: 330,
          margin: const EdgeInsets.only(bottom: 16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
          ),
        ),
      ),
    );
  }
}
