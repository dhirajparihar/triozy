import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../models/worker_model.dart';
import '../services/database_service.dart';
import '../services/location_service.dart';
import '../providers/location_provider.dart';
import '../screens/worker_list_screen.dart';
import '../screens/worker_profile_screen.dart';
import '../screens/all_categories_screen.dart';

class HomeScreen extends StatefulWidget {
  final VoidCallback? onSearchTapped;
  const HomeScreen({super.key, this.onSearchTapped});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<WorkerModel> _topWorkers = [];
  bool _loading = true;
  bool _locationUsed = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadWorkers());
  }

  Future<void> _loadWorkers() async {
    final db = context.read<DatabaseService>();
    final locProvider = context.read<LocationProvider>();
    final locService = context.read<LocationService>();

    try {
      // Use shared location if available
      if (locProvider.isAvailable) {
        final nearbyWorkers = await locService.getNearbyWorkers(
          latitude: locProvider.latitude!,
          longitude: locProvider.longitude!,
          radiusKm: 25,
        );
        if (mounted) {
          setState(() {
            _topWorkers = nearbyWorkers.take(5).toList();
            _locationUsed = true;
            _loading = false;
          });
        }
        return;
      }

      // Fallback: get top rated workers without geo
      final workers = await db.getTopWorkers(limit: 5);
      if (mounted) {
        setState(() {
          _topWorkers = workers;
          _locationUsed = false;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _onRefresh() async {
    setState(() {
      _loading = true;
      _topWorkers = [];
    });
    await _loadWorkers();
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _onRefresh,
      color: AppColors.primary,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeroSection(context),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 36, 24, 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildCategoriesSection(context),
                  const SizedBox(height: 36),
                  _buildTopWorkersSection(context),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeroSection(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1E3A8A), Color(0xFF2563EB), Color(0xFF4F46E5)],
        ),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(36)),
      ),
      padding: const EdgeInsets.fromLTRB(24, 52, 24, 40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          RichText(
            text: TextSpan(
              children: [
                TextSpan(
                  text: 'Find expert help\n',
                  style: AppTheme.headline(
                    fontSize: 30,
                    color: Colors.white.withValues(alpha: 0.85),
                    letterSpacing: -1.0,
                  ),
                ),
                TextSpan(
                  text: 'in seconds.',
                  style: AppTheme.headline(
                    fontSize: 30,
                    color: Colors.white,
                    letterSpacing: -1.0,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          GestureDetector(
            onTap: widget.onSearchTapped,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                child: Container(
                  height: 54,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.35),
                      width: 1.2,
                    ),
                  ),
                  child: Row(
                    children: [
                      const SizedBox(width: 16),
                      Icon(Icons.search_rounded,
                          color: Colors.white.withValues(alpha: 0.85), size: 22),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Search for plumbers, electricians...',
                          style: AppTheme.body(
                            fontSize: 15,
                            fontWeight: FontWeight.w400,
                            color: Colors.white.withValues(alpha: 0.7),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 20),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoriesSection(BuildContext context) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                'Categories',
                style: AppTheme.headline(fontSize: 24),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 16),
            GestureDetector(
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const AllCategoriesScreen()),
              ),
              child: Text(
                'View All',
                style: AppTheme.body(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.primary,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
          childAspectRatio: 0.9,
          children: [
            _CategoryCard(
              label: 'Electrician',
              imageUrl:
                  'https://lh3.googleusercontent.com/aida-public/AB6AXuC-eL5ZvDeISt0w2u0DR1osoZqXxH0DKO9YCBmoJAhw0zw5M0nULj0QcNh14z7RzMwC2sPi6Aw5aiepDhxhuKKZnQC-Y51TcineiQIlnhcD_oBbLntDbegJBXAYCB1K0jStkwbU_R9ek97RPWgz0d-2thTAO3CrR2h5Rq08mAZHz0GrsJqJs9CK5ta9Fe2kcH40uAUui3R5q258lfv3hmyDiVPgSiEJn-ebgr4tzXr1qkxamyYlrAqc-VFvw1k5pj7CZX54MfVIXGQ',
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) =>
                      const WorkerListScreen(category: 'Electrician'),
                ),
              ),
            ),
            _CategoryCard(
              label: 'Plumber',
              imageUrl:
                  'https://lh3.googleusercontent.com/aida-public/AB6AXuCHB8HEtlkIngffZC4YxjMghwS577KPR9kJt0uUc07S5Mlm1qkPq2vSuAEn6cJgSZYYjeUbJI_Cvdx1qb8OjdWB86JZmvnlQ1301eq6gBoaDY8XQiGZk5dZjUfZg_X3UOHOgKkSspxgjxZ4bo2c0J-J7B6z5Ud7AS13btPeFC3wsglYjjxjQvw1kw2L0f34nm_nGTFDyvM-KkzyMCufsdX0sOJGBYpuikYwIpW6W_ztX6gRGhTf60sId5Fp74D0JEuqvh_TatgV8os',
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const WorkerListScreen(category: 'Plumber'),
                ),
              ),
            ),
            _CategoryCard(
              label: 'AC Repair',
              imageUrl:
                  'https://lh3.googleusercontent.com/aida-public/AB6AXuCwJdWFNgZs5x6jOIZ_TD3QLZlaYKCr0IFVtFr-Y6js2VvkJvyM2Y4vCVnHNcl2X9uI9DXL0NpyIWgXl2bb0Rv05Yykpxk6ooavynLjBDx-dIahugWk8hDsFiqDkf8ocIn6Pv-AUPAzBAYehZCUa-Q73mbN9x_ZpMIpOxI-aRso0RGCdvpQZCqYaP40WrVLmn2Pbq7zdZXTDgIHaQcZfxBCSl0tk-AYg7n_q9PkfvOhRERWWfby5v6QHS_FLc_g81ixfPBcIiaTPQI',
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const WorkerListScreen(category: 'AC Repair'),
                ),
              ),
            ),
            _CategoryCard(
              label: 'All Services',
              imageUrl: '',
              isAllServices: true,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const AllCategoriesScreen()),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildTopWorkersSection(BuildContext context) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _locationUsed ? 'Pros Near You' : 'Top Pros Near You',
                    style: AppTheme.headline(fontSize: 24),
                  ),
                  if (_locationUsed)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.my_location,
                            size: 12,
                            color: AppColors.secondary,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Within 25 km',
                            style: AppTheme.body(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: AppColors.secondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        if (_loading)
          SizedBox(
            height: 340,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: 3,
              separatorBuilder: (_, _) => const SizedBox(width: 24),
              itemBuilder: (_, _) => _buildSkeletonCard(),
            ),
          )
        else if (_topWorkers.isEmpty)
          SizedBox(
            height: 200,
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.person_search, size: 48, color: AppColors.outlineVariant.withValues(alpha: 0.5)),
                  const SizedBox(height: 12),
                  Text(
                    'No professionals nearby yet',
                    style: AppTheme.body(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.outline),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Try expanding your search area',
                    style: AppTheme.body(fontSize: 13, color: AppColors.outlineVariant),
                  ),
                ],
              ),
            ),
          )
        else
          SizedBox(
            height: 340,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _topWorkers.length,
              separatorBuilder: (_, _) => const SizedBox(width: 24),
              itemBuilder: (context, index) {
                final w = _topWorkers[index];
                return _WorkerCard(
                  data: _WorkerData(
                    name: w.name,
                    role: w.serviceType,
                    rating: w.ratingDisplay,
                    location: w.distanceKm != null
                        ? w.distanceDisplay
                        : '${w.location} • ${w.experience}yr exp',
                    imageUrl: w.photoUrl,
                    available: w.isAvailable,
                  ),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => WorkerProfileScreen(workerId: w.uid),
                    ),
                  ),
                );
              },
            ),
          ),
      ],
    );
  }

}

class _SkeletonBox extends StatelessWidget {
  final double width;
  final double height;
  const _SkeletonBox({required this.width, required this.height});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(8),
      ),
    );
  }
}

Widget _buildSkeletonCard() {
  return Container(
    width: 280,
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: AppColors.outlineVariant.withValues(alpha: 0.15)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          height: 160,
          decoration: BoxDecoration(
            color: AppColors.surfaceContainerHigh,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const [
              _SkeletonBox(width: 140, height: 16),
              SizedBox(height: 8),
              _SkeletonBox(width: 90, height: 12),
              SizedBox(height: 16),
              _SkeletonBox(width: 180, height: 12),
            ],
          ),
        ),
      ],
    ),
  );
}

class _CategoryCard extends StatelessWidget {
  final String label;
  final String imageUrl;
  final VoidCallback onTap;
  final bool isAllServices;

  const _CategoryCard({
    required this.label,
    required this.imageUrl,
    required this.onTap,
    this.isAllServices = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withValues(alpha: 0.10),
              blurRadius: 24,
              offset: const Offset(0, 8),
              spreadRadius: 0,
            ),
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  width: double.infinity,
                  color: AppColors.surfaceContainerHigh,
                  child: isAllServices
                      ? Center(
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(
                                  Icons.grid_view_rounded,
                                  size: 40,
                                  color: AppColors.primary,
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Browse All',
                                  style: AppTheme.body(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.primary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )
                      : Image.network(
                          imageUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) => const Center(
                            child: Icon(
                              Icons.image_not_supported,
                              color: AppColors.outlineVariant,
                            ),
                          ),
                        ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              label,
              style: AppTheme.body(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: AppColors.onSurface,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
          ],
        ),
      ),
    );
  }
}

class _WorkerData {
  final String name;
  final String role;
  final String rating;
  final String location;
  final String imageUrl;
  final bool available;

  _WorkerData({
    required this.name,
    required this.role,
    required this.rating,
    required this.location,
    required this.imageUrl,
    this.available = false,
  });
}

class _WorkerCard extends StatelessWidget {
  final _WorkerData data;
  final VoidCallback onTap;

  const _WorkerCard({required this.data, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 280,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withValues(alpha: 0.10),
              blurRadius: 28,
              offset: const Offset(0, 10),
              spreadRadius: 0,
            ),
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(20),
                  ),
                  child: Image.network(
                    data.imageUrl,
                    height: 160,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => Container(
                      height: 160,
                      decoration: const BoxDecoration(
                        color: AppColors.surfaceContainerHighest,
                        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                      ),
                      child: const Icon(
                        Icons.person,
                        size: 48,
                        color: AppColors.outline,
                      ),
                    ),
                  ),
                ),
                Positioned(
                  top: 16,
                  right: 16,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.9),
                      borderRadius: BorderRadius.circular(9999),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.star,
                          color: AppColors.amber500,
                          size: 14,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          data.rating,
                          style: AppTheme.body(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                data.name,
                                style: AppTheme.body(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                data.role,
                                style: AppTheme.body(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                  color: AppColors.outline,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (data.available)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.secondaryContainer,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              'AVAILABLE',
                              style: GoogleFonts.inter(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: AppColors.onSecondaryFixedVariant,
                                letterSpacing: 0.8,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(
                          Icons.near_me,
                          size: 14,
                          color: AppColors.outlineVariant,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            data.location,
                            style: AppTheme.body(
                              fontSize: 14,
                              color: AppColors.outlineVariant,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.only(top: 12),
                      decoration: const BoxDecoration(
                        border: Border(
                          top: BorderSide(color: AppColors.surfaceContainerLow),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          ElevatedButton(
                            onPressed: onTap,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 20,
                                vertical: 10,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(9999),
                              ),
                              elevation: 0,
                            ),
                            child: Text(
                              'Book Now',
                              style: AppTheme.body(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
