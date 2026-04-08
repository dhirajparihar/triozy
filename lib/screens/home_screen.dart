import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../models/worker_model.dart';
import '../models/mate_model.dart';
import '../services/database_service.dart';
import '../services/location_service.dart';
import '../providers/location_provider.dart';
import '../screens/worker_list_screen.dart';
import '../screens/worker_profile_screen.dart';
import '../screens/all_categories_screen.dart';
import '../screens/add_request_screen.dart';
import '../constants/app_categories.dart';

class HomeScreen extends StatefulWidget {
  final VoidCallback? onSearchTapped;
  final VoidCallback? onRequestsTapped;
  final VoidCallback? onMatesTapped;

  const HomeScreen({
    super.key,
    this.onSearchTapped,
    this.onRequestsTapped,
    this.onMatesTapped,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<WorkerModel> _topWorkers = [];
  List<MateModel> _recentMates = [];
  bool _loading = true;
  bool _locationUsed = false;

  static const _searchHints = AppCategories.searchHints;
  int _hintIndex = 0;
  late final Timer _hintTimer;

  @override
  void initState() {
    super.initState();
    _hintTimer = Timer.periodic(const Duration(seconds: 2), (_) {
      if (mounted) setState(() => _hintIndex = (_hintIndex + 1) % _searchHints.length);
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadData());
  }

  @override
  void dispose() {
    _hintTimer.cancel();
    super.dispose();
  }

  Future<void> _loadData() async {
    final db = context.read<DatabaseService>();
    final locProvider = context.read<LocationProvider>();
    final locService = context.read<LocationService>();

    try {
      final matesFuture = db.getRecentMates(limit: 8);

      List<WorkerModel> workers;
      bool geoUsed = false;

      if (locProvider.isAvailable) {
        workers = await locService.getNearbyWorkers(
          latitude: locProvider.latitude!,
          longitude: locProvider.longitude!,
          radiusKm: 25,
        );
        workers = workers.take(5).toList();
        geoUsed = true;
      } else {
        workers = await db.getTopWorkers(limit: 5);
      }

      final mates = await matesFuture;

      if (mounted) {
        setState(() {
          _topWorkers = workers;
          _recentMates = mates;
          _locationUsed = geoUsed;
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
      _recentMates = [];
    });
    await _loadData();
  }

  @override
  Widget build(BuildContext context) {
    final locProvider = context.watch<LocationProvider>();

    if (locProvider.isAvailable && !_locationUsed && !_loading) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _loadData());
    }

    return RefreshIndicator(
      onRefresh: _onRefresh,
      color: AppColors.primary,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeroSection(context),
            _buildPillarStrip(context),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 32, 24, 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildCategoriesSection(context),
                  const SizedBox(height: 36),
                  if (_recentMates.isNotEmpty || _loading) ...[
                    _buildMatesSection(context),
                    const SizedBox(height: 36),
                  ],
                  _buildTopWorkersSection(context),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Hero ──────────────────────────────────────────────────────────────────────

  Widget _buildHeroSection(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF0D2B6E), Color(0xFF1A56C8), Color(0xFF1E3A8A)],
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
                  text: 'Your local network,\n',
                  style: AppTheme.headline(
                    fontSize: 30,
                    color: Colors.white.withValues(alpha: 0.9),
                    letterSpacing: -1.0,
                  ),
                ),
                TextSpan(
                  text: 'for everything.',
                  style: AppTheme.headline(
                    fontSize: 30,
                    color: Colors.white,
                    letterSpacing: -1.0,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Find services, post requests, or connect with a mate — all near you.',
            style: AppTheme.body(
              fontSize: 14,
              color: Colors.white.withValues(alpha: 0.7),
              height: 1.5,
            ),
          ),
          const SizedBox(height: 20),
          // Search bar
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
                        child: Row(
                          children: [
                            Text(
                              'Search for ',
                              style: AppTheme.body(
                                fontSize: 15,
                                color: Colors.white.withValues(alpha: 0.7),
                              ),
                            ),
                            Flexible(
                              child: Text(
                                _searchHints[_hintIndex],
                                style: AppTheme.body(
                                  fontSize: 15,
                                  color: Colors.white.withValues(alpha: 0.7),
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
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

  // ── 3-Pillar Strip ────────────────────────────────────────────────────────────

  Widget _buildPillarStrip(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
      child: Row(
        children: [
          Expanded(
            child: _PillarCard(
              icon: Icons.handyman_rounded,
              label: 'Services',
              sub: 'Find local pros',
              startColor: const Color(0xFF1A56C8),
              endColor: const Color(0xFF0D2B6E),
              onTap: widget.onSearchTapped,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _PillarCard(
              icon: Icons.post_add_rounded,
              label: 'Requests',
              sub: 'Post a job',
              startColor: AppColors.tertiary,
              endColor: const Color(0xFF6B2D00),
              onTap: widget.onRequestsTapped ??
                  () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const AddRequestScreen()),
                      ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _PillarCard(
              icon: Icons.people_alt_rounded,
              label: 'Mates',
              sub: 'Connect locally',
              startColor: AppColors.secondary,
              endColor: const Color(0xFF003D18),
              onTap: widget.onMatesTapped,
            ),
          ),
        ],
      ),
    );
  }

  // ── Categories ────────────────────────────────────────────────────────────────

  Widget _buildCategoriesSection(BuildContext context) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text('Categories', style: AppTheme.headline(fontSize: 22),
                  maxLines: 1, overflow: TextOverflow.ellipsis),
            ),
            GestureDetector(
              onTap: () => Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const AllCategoriesScreen())),
              child: Text('View All',
                  style: AppTheme.body(
                      fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.primary)),
            ),
          ],
        ),
        const SizedBox(height: 20),
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
              onTap: () => Navigator.push(context, MaterialPageRoute(
                  builder: (_) => const WorkerListScreen(category: 'Electrician'))),
            ),
            _CategoryCard(
              label: 'Plumber',
              imageUrl:
                  'https://lh3.googleusercontent.com/aida-public/AB6AXuCHB8HEtlkIngffZC4YxjMghwS577KPR9kJt0uUc07S5Mlm1qkPq2vSuAEn6cJgSZYYjeUbJI_Cvdx1qb8OjdWB86JZmvnlQ1301eq6gBoaDY8XQiGZk5dZjUfZg_X3UOHOgKkSspxgjxZ4bo2c0J-J7B6z5Ud7AS13btPeFC3wsglYjjxjQvw1kw2L0f34nm_nGTFDyvM-KkzyMCufsdX0sOJGBYpuikYwIpW6W_ztX6gRGhTf60sId5Fp74D0JEuqvh_TatgV8os',
              onTap: () => Navigator.push(context, MaterialPageRoute(
                  builder: (_) => const WorkerListScreen(category: 'Plumber'))),
            ),
            _CategoryCard(
              label: 'AC Repair',
              imageUrl:
                  'https://lh3.googleusercontent.com/aida-public/AB6AXuCwJdWFNgZs5x6jOIZ_TD3QLZlaYKCr0IFVtFr-Y6js2VvkJvyM2Y4vCVnHNcl2X9uI9DXL0NpyIWgXl2bb0Rv05Yykpxk6ooavynLjBDx-dIahugWk8hDsFiqDkf8ocIn6Pv-AUPAzBAYehZCUa-Q73mbN9x_ZpMIpOxI-aRso0RGCdvpQZCqYaP40WrVLmn2Pbq7zdZXTDgIHaQcZfxBCSl0tk-AYg7n_q9PkfvOhRERWWfby5v6QHS_FLc_g81ixfPBcIiaTPQI',
              onTap: () => Navigator.push(context, MaterialPageRoute(
                  builder: (_) => const WorkerListScreen(category: 'AC Repair'))),
            ),
            _CategoryCard(
              label: 'All Services',
              imageUrl: '',
              isAllServices: true,
              onTap: () => Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const AllCategoriesScreen())),
            ),
          ],
        ),
      ],
    );
  }

  // ── Mates Section ─────────────────────────────────────────────────────────────

  Widget _buildMatesSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Mates Near You', style: AppTheme.headline(fontSize: 22)),
            GestureDetector(
              onTap: widget.onMatesTapped,
              child: Text('See All',
                  style: AppTheme.body(
                      fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.secondary)),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          'Roommates, Helpmates & Ridematch nearby',
          style: AppTheme.body(fontSize: 13, color: AppColors.slate500),
        ),
        const SizedBox(height: 16),
        if (_loading)
          SizedBox(
            height: 120,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: 4,
              separatorBuilder: (context, i) => const SizedBox(width: 12),
              itemBuilder: (context, i) => _buildMateSkeleton(),
            ),
          )
        else
          SizedBox(
            height: 120,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _recentMates.length,
              separatorBuilder: (context, i) => const SizedBox(width: 12),
              itemBuilder: (context, i) => _MatePreviewCard(
                mate: _recentMates[i],
                onTap: widget.onMatesTapped,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildMateSkeleton() {
    return Container(
      width: 160,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            _SkeletonBox(width: 32, height: 32),
            const SizedBox(width: 8),
            _SkeletonBox(width: 80, height: 13),
          ]),
          const SizedBox(height: 10),
          _SkeletonBox(width: 100, height: 11),
          const SizedBox(height: 6),
          _SkeletonBox(width: 70, height: 11),
        ],
      ),
    );
  }

  // ── Top Workers ───────────────────────────────────────────────────────────────

  Widget _buildTopWorkersSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _locationUsed ? 'Pros Near You' : 'Top Pros',
              style: AppTheme.headline(fontSize: 22),
            ),
            if (_locationUsed)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Row(
                  children: [
                    const Icon(Icons.my_location, size: 12, color: AppColors.secondary),
                    const SizedBox(width: 4),
                    Text('Within 25 km',
                        style: AppTheme.body(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppColors.secondary)),
                  ],
                ),
              ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          'Tap a profile to call directly — no booking needed.',
          style: AppTheme.body(fontSize: 13, color: AppColors.slate500),
        ),
        const SizedBox(height: 20),
        if (_loading)
          SizedBox(
            height: 300,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: 3,
              separatorBuilder: (context, i) => const SizedBox(width: 20),
              itemBuilder: (context, i) => _buildSkeletonCard(),
            ),
          )
        else if (_topWorkers.isEmpty)
          Container(
            height: 160,
            width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.person_search, size: 40,
                    color: AppColors.outlineVariant.withValues(alpha: 0.6)),
                const SizedBox(height: 10),
                Text('No professionals nearby yet',
                    style: AppTheme.body(fontSize: 15, fontWeight: FontWeight.w600,
                        color: AppColors.outline)),
                const SizedBox(height: 4),
                Text('Try posting a request instead',
                    style: AppTheme.body(fontSize: 13, color: AppColors.outlineVariant)),
              ],
            ),
          )
        else
          SizedBox(
            height: 300,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _topWorkers.length,
              separatorBuilder: (context, i) => const SizedBox(width: 20),
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
                  onTap: () => Navigator.push(context, MaterialPageRoute(
                      builder: (_) => WorkerProfileScreen(workerId: w.uid))),
                );
              },
            ),
          ),
      ],
    );
  }
}

// ── Pillar Card ────────────────────────────────────────────────────────────────

class _PillarCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String sub;
  final Color startColor;
  final Color endColor;
  final VoidCallback? onTap;

  const _PillarCard({
    required this.icon,
    required this.label,
    required this.sub,
    required this.startColor,
    required this.endColor,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [startColor, endColor],
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: startColor.withValues(alpha: 0.3),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, size: 20, color: Colors.white),
            ),
            const SizedBox(height: 10),
            Text(
              label,
              style: GoogleFonts.manrope(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              sub,
              style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: Colors.white.withValues(alpha: 0.75),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Mate Preview Card ──────────────────────────────────────────────────────────

class _MatePreviewCard extends StatelessWidget {
  final MateModel mate;
  final VoidCallback? onTap;

  const _MatePreviewCard({required this.mate, this.onTap});

  static const _typeColors = {
    MateType.roommate: AppColors.primary,
    MateType.helpmate: AppColors.secondary,
    MateType.ridemate: AppColors.tertiary,
  };

  static const _typeIcons = {
    MateType.roommate: Icons.people_alt_rounded,
    MateType.helpmate: Icons.handshake_rounded,
    MateType.ridemate: Icons.directions_bike_rounded,
  };

  Color get _color => _typeColors[mate.type]!;
  IconData get _icon => _typeIcons[mate.type]!;

  String get _detail {
    switch (mate.type) {
      case MateType.roommate:
        return mate.budget ?? mate.location;
      case MateType.helpmate:
        return mate.available ? 'Available now' : mate.location;
      case MateType.ridemate:
        if (mate.fromLocation != null && mate.toLocation != null) {
          return '${mate.fromLocation} → ${mate.toLocation}';
        }
        return mate.location;
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 170,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                // Avatar
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.surfaceContainerHigh,
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: mate.userPhoto.isNotEmpty
                      ? Image.network(mate.userPhoto, fit: BoxFit.cover,
                          errorBuilder: (ctx, err, stack) => Icon(_icon, size: 18, color: _color))
                      : Icon(_icon, size: 18, color: _color),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    mate.userName,
                    style: AppTheme.body(fontSize: 13, fontWeight: FontWeight.w700),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            // Type badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
              decoration: BoxDecoration(
                color: _color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                mate.type.label,
                style: AppTheme.label(fontSize: 10, color: _color),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              _detail,
              style: AppTheme.label(fontSize: 11, color: AppColors.slate500),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

// ── Skeleton ───────────────────────────────────────────────────────────────────

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
    width: 240,
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          height: 140,
          decoration: const BoxDecoration(
            color: AppColors.surfaceContainerHigh,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const [
              _SkeletonBox(width: 120, height: 14),
              SizedBox(height: 8),
              _SkeletonBox(width: 80, height: 11),
              SizedBox(height: 16),
              _SkeletonBox(width: 160, height: 11),
            ],
          ),
        ),
      ],
    ),
  );
}

// ── Category Card ──────────────────────────────────────────────────────────────

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
              color: AppColors.primary.withValues(alpha: 0.08),
              blurRadius: 20,
              offset: const Offset(0, 6),
            ),
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
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
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.grid_view_rounded, size: 40, color: AppColors.primary),
                              const SizedBox(height: 4),
                              Text('Browse All',
                                  style: AppTheme.body(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.primary)),
                            ],
                          ),
                        )
                      : Image.network(imageUrl, fit: BoxFit.cover,
                          errorBuilder: (ctx, err, stack) => const Center(
                            child: Icon(Icons.image_not_supported, color: AppColors.outlineVariant),
                          )),
                ),
              ),
            ),
            const SizedBox(height: 10),
            Text(label,
                style: AppTheme.body(fontSize: 14, fontWeight: FontWeight.w700),
                maxLines: 1,
                overflow: TextOverflow.ellipsis),
            const SizedBox(height: 4),
          ],
        ),
      ),
    );
  }
}

// ── Worker Card ────────────────────────────────────────────────────────────────

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
        width: 240,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withValues(alpha: 0.08),
              blurRadius: 24,
              offset: const Offset(0, 8),
            ),
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Photo
            Stack(
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                  child: Image.network(
                    data.imageUrl,
                    height: 140,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    errorBuilder: (ctx, err, stack) => Container(
                      height: 140,
                      color: AppColors.surfaceContainerHighest,
                      child: const Icon(Icons.person, size: 48, color: AppColors.outline),
                    ),
                  ),
                ),
                // Rating badge
                Positioned(
                  top: 12,
                  right: 12,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.92),
                      borderRadius: BorderRadius.circular(9999),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.star_rounded, color: AppColors.amber500, size: 13),
                        const SizedBox(width: 3),
                        Text(data.rating,
                            style: AppTheme.body(fontSize: 13, fontWeight: FontWeight.w700)),
                      ],
                    ),
                  ),
                ),
                // Available badge
                if (data.available)
                  Positioned(
                    top: 12,
                    left: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.secondary,
                        borderRadius: BorderRadius.circular(9999),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 6, height: 6,
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle, color: Colors.white),
                          ),
                          const SizedBox(width: 4),
                          Text('Available',
                              style: GoogleFonts.inter(
                                  fontSize: 10, fontWeight: FontWeight.w700,
                                  color: Colors.white)),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
            // Info
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(data.name,
                      style: AppTheme.body(fontSize: 16, fontWeight: FontWeight.w700),
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 2),
                  Text(data.role,
                      style: AppTheme.body(fontSize: 13, color: AppColors.outline),
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      const Icon(Icons.location_on_rounded, size: 13, color: AppColors.outlineVariant),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(data.location,
                            style: AppTheme.body(fontSize: 12, color: AppColors.outlineVariant),
                            overflow: TextOverflow.ellipsis),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // CTA — reflects direct call model
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: onTap,
                      icon: const Icon(Icons.phone_rounded, size: 14),
                      label: const Text('View & Call'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        textStyle: GoogleFonts.inter(
                            fontSize: 13, fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
