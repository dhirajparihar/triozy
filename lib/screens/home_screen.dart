import 'dart:async';
import 'dart:ui';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../models/chat_model.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../models/worker_model.dart';
import '../models/mate_model.dart';
import '../providers/chat_provider.dart';
import '../services/database_service.dart';
import '../services/location_service.dart';
import '../providers/location_provider.dart';
import '../screens/worker_list_screen.dart';
import '../screens/worker_profile_screen.dart';
import '../screens/chat_detail_screen.dart';
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
  State<HomeScreen> createState() => HomeScreenState();
}

class HomeScreenState extends State<HomeScreen> {
  List<WorkerModel> _topWorkers = [];
  List<MateModel> _recentMates = [];
  bool _loading = true;
  bool _locationUsed = false;
  String _proximityLabel = 'Within 25 km';
  IconData _proximityIcon = Icons.my_location;

  static const _searchHints = AppCategories.searchHints;
  int _hintIndex = 0;
  late final Timer _hintTimer;

  @override
  void initState() {
    super.initState();
    _hintTimer = Timer.periodic(const Duration(seconds: 2), (_) {
      if (mounted) {
        setState(() => _hintIndex = (_hintIndex + 1) % _searchHints.length);
      }
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
      Future<List<MateModel>> matesFuture;

      List<WorkerModel> workers;
      bool geoUsed = false;
      String proximityLabel = 'Within 25 km';
      IconData proximityIcon = Icons.my_location;

      if (locProvider.isAvailable) {
        final nearbyResult = await locService.getNearbyWorkersWithFallback(
          latitude: locProvider.latitude!,
          longitude: locProvider.longitude!,
          radiusKm: 25,
          limit: 5,
        );
        workers = nearbyResult.workers;
        proximityLabel = nearbyResult.scopeLabel;
        proximityIcon = switch (nearbyResult.scope) {
          WorkerProximityScope.radius => Icons.my_location,
          WorkerProximityScope.city => Icons.location_city,
          WorkerProximityScope.state => Icons.map,
          WorkerProximityScope.none => Icons.star_rounded,
        };
        final locationParts = _extractCityState(locProvider.address);
        matesFuture = db.getNearbyMatesWithFallback(
          latitude: locProvider.latitude!,
          longitude: locProvider.longitude!,
          city: locationParts.$1,
          state: locationParts.$2,
          limit: 8,
          radiusKm: 25,
        );
        geoUsed = true;
      } else {
        workers = await db.getTopWorkers(limit: 5);
        matesFuture = db.getRecentMates(limit: 8);
      }

      final mates = await matesFuture;

      if (mounted) {
        setState(() {
          _topWorkers = workers;
          _recentMates = mates;
          _locationUsed = geoUsed;
          _proximityLabel = proximityLabel;
          _proximityIcon = proximityIcon;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  (String?, String?) _extractCityState(String address) {
    final parts = address
        .split(',')
        .map((p) => p.trim())
        .where((p) => p.isNotEmpty)
        .toList();
    if (parts.isEmpty) return (null, null);

    final city = parts.length >= 2 ? parts[parts.length - 2] : parts.first;
    final state = parts.length >= 2 ? parts.last : null;
    return (city, state);
  }

  Future<void> _onRefresh() async {
    setState(() {
      _loading = true;
      _topWorkers = [];
      _recentMates = [];
    });
    await _loadData();
  }

  Future<void> refreshFromShell() => _onRefresh();

  Future<void> _openContextChat({
    required String otherUserId,
    required ChatType chatType,
    required String referenceId,
    String? otherUserName,
    String? otherUserPhotoUrl,
    String? otherUserLocation,
  }) async {
    final currentUser = FirebaseAuth.instance.currentUser;
    final currentUserId = currentUser?.uid;
    if (currentUserId == null || currentUserId.isEmpty) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please sign in to start chatting')),
      );
      return;
    }
    if (otherUserId == currentUserId) {
      return;
    }

    try {
      final conversationId = await context.read<ChatProvider>().createOrGetChat(
        otherUserId: otherUserId,
        chatType: chatType.value,
        referenceId: referenceId,
        otherUserName: otherUserName,
        otherUserPhotoUrl: otherUserPhotoUrl,
        otherUserLocation: otherUserLocation,
        currentUserName: currentUser?.displayName,
        currentUserPhotoUrl: currentUser?.photoURL,
      );
      if (!mounted) {
        return;
      }
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ChatDetailScreen(conversationId: conversationId),
        ),
      );
    } catch (e) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Unable to open chat: $e')));
    }
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
                      Icon(
                        Icons.search_rounded,
                        color: Colors.white.withValues(alpha: 0.85),
                        size: 22,
                      ),
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
              onTap:
                  widget.onRequestsTapped ??
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
              child: Text(
                'Categories',
                style: AppTheme.headline(fontSize: 22),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
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
              child: Text(
                'See All',
                style: AppTheme.body(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.secondary,
                ),
              ),
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
            height: 178,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: 4,
              separatorBuilder: (context, i) => const SizedBox(width: 12),
              itemBuilder: (context, i) => _buildMateSkeleton(),
            ),
          )
        else
          SizedBox(
            height: 178,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _recentMates.length,
              separatorBuilder: (context, i) => const SizedBox(width: 12),
              itemBuilder: (context, i) => _MatePreviewCard(
                mate: _recentMates[i],
                onTap: widget.onMatesTapped,
                onChatTap: () => _openContextChat(
                  otherUserId: _recentMates[i].userId,
                  chatType: ChatType.mate,
                  referenceId: _recentMates[i].id,
                  otherUserName: _recentMates[i].userName,
                  otherUserPhotoUrl: _recentMates[i].userPhoto,
                  otherUserLocation: _recentMates[i].location,
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildMateSkeleton() {
    return Container(
      width: 190,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 4,
            decoration: const BoxDecoration(
              color: AppColors.surfaceContainerHigh,
              borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    _SkeletonBox(width: 42, height: 42),
                    const SizedBox(width: 10),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _SkeletonBox(width: 90, height: 13),
                        const SizedBox(height: 6),
                        _SkeletonBox(width: 56, height: 18),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                _SkeletonBox(width: 110, height: 11),
                const SizedBox(height: 6),
                _SkeletonBox(width: 140, height: 11),
              ],
            ),
          ),
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
                    Icon(_proximityIcon, size: 12, color: AppColors.secondary),
                    const SizedBox(width: 4),
                    Text(
                      _proximityLabel,
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
        const SizedBox(height: 6),
        Text(
          'Tap a profile to call directly — no booking needed.',
          style: AppTheme.body(fontSize: 13, color: AppColors.slate500),
        ),
        const SizedBox(height: 20),
        if (_loading)
          SizedBox(
            height: 320,
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
                Icon(
                  Icons.person_search,
                  size: 40,
                  color: AppColors.outlineVariant.withValues(alpha: 0.6),
                ),
                const SizedBox(height: 10),
                Text(
                  'No professionals nearby yet',
                  style: AppTheme.body(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: AppColors.outline,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Try posting a request instead',
                  style: AppTheme.body(
                    fontSize: 13,
                    color: AppColors.outlineVariant,
                  ),
                ),
              ],
            ),
          )
        else
          SizedBox(
            height: 320,
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
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => WorkerProfileScreen(workerId: w.uid),
                    ),
                  ),
                  onChat: () => _openContextChat(
                    otherUserId: w.uid,
                    chatType: ChatType.service,
                    referenceId: w.uid,
                    otherUserName: w.name,
                    otherUserPhotoUrl: w.photoUrl,
                    otherUserLocation: w.location,
                  ),
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
  final VoidCallback? onChatTap;

  const _MatePreviewCard({required this.mate, this.onTap, this.onChatTap});

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
        if (mate.description.isNotEmpty) return mate.description;
        final parts = <String>[];
        final b = mate.budget;
        if (b != null && b.trim().isNotEmpty) {
          final formatted = b.trim().startsWith('₹')
              ? b.trim()
              : '₹${b.trim()}';
          parts.add(formatted);
        }
        final g = mate.preferredGender;
        if (g != null && g.isNotEmpty && g != 'Any') parts.add('$g preferred');
        if (parts.isNotEmpty) return parts.join(' · ');
        return mate.location;
      case MateType.helpmate:
        if (mate.helpTypes.isNotEmpty) {
          final label = mate.helpTypes.take(2).join(', ');
          return mate.available ? 'Available · $label' : label;
        }
        return mate.available ? 'Available now' : mate.description;
      case MateType.ridemate:
        if (mate.fromLocation != null && mate.toLocation != null) {
          return '${mate.fromLocation} → ${mate.toLocation}';
        }
        if (mate.departureTime != null && mate.departureTime!.isNotEmpty) {
          return 'Departs ${mate.departureTime}';
        }
        return mate.description.isNotEmpty ? mate.description : mate.location;
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 190,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 14,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: Stack(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Colored top accent strip
                  Container(height: 4, color: _color),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            // Avatar
                            Container(
                              width: 42,
                              height: 42,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: _color.withValues(alpha: 0.08),
                                border: Border.all(
                                  color: _color.withValues(alpha: 0.2),
                                  width: 1.5,
                                ),
                              ),
                              clipBehavior: Clip.antiAlias,
                              child: mate.userPhoto.isNotEmpty
                                  ? Image.network(
                                      mate.userPhoto,
                                      fit: BoxFit.cover,
                                      errorBuilder: (ctx, e, s) =>
                                          Icon(_icon, size: 20, color: _color),
                                    )
                                  : Icon(_icon, size: 20, color: _color),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    mate.userName,
                                    style: AppTheme.headline(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 4),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 7,
                                      vertical: 3,
                                    ),
                                    decoration: BoxDecoration(
                                      color: _color.withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      mate.type.label,
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w700,
                                        color: _color,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Icon(
                              Icons.location_on_outlined,
                              size: 12,
                              color: AppColors.outline,
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                mate.location,
                                style: AppTheme.body(
                                  fontSize: 11,
                                  color: AppColors.outline,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 5),
                        Text(
                          _detail,
                          style: AppTheme.body(
                            fontSize: 11,
                            color: AppColors.onSurfaceVariant,
                            height: 1.35,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              // Chat button overlay
              Positioned(
                bottom: 10,
                right: 10,
                child: GestureDetector(
                  onTap: onChatTap,
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: _color,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: _color.withValues(alpha: 0.3),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.chat_rounded,
                      size: 18,
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
    width: 220,
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          height: 155,
          decoration: const BoxDecoration(
            color: AppColors.surfaceContainerHigh,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const [
              _SkeletonBox(width: 110, height: 15),
              SizedBox(height: 6),
              _SkeletonBox(width: 75, height: 12),
              SizedBox(height: 10),
              _SkeletonBox(width: 140, height: 11),
              SizedBox(height: 12),
              _SkeletonBox(width: double.infinity, height: 38),
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
                        )
                      : Image.network(
                          imageUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (ctx, err, stack) => const Center(
                            child: Icon(
                              Icons.image_not_supported,
                              color: AppColors.outlineVariant,
                            ),
                          ),
                        ),
                ),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              label,
              style: AppTheme.body(fontSize: 14, fontWeight: FontWeight.w700),
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
  final VoidCallback? onChat;

  const _WorkerCard({required this.data, required this.onTap, this.onChat});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 220,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.07),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Photo ──
            Stack(
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(20),
                  ),
                  child: Stack(
                    children: [
                      Image.network(
                        data.imageUrl,
                        height: 155,
                        width: double.infinity,
                        fit: BoxFit.cover,
                        errorBuilder: (ctx, e, s) => Container(
                          height: 155,
                          color: AppColors.surfaceContainerHighest,
                          child: Center(
                            child: Icon(
                              Icons.person,
                              size: 52,
                              color: AppColors.outline.withValues(alpha: 0.4),
                            ),
                          ),
                        ),
                      ),
                      // Bottom gradient
                      Positioned(
                        bottom: 0,
                        left: 0,
                        right: 0,
                        child: Container(
                          height: 60,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.bottomCenter,
                              end: Alignment.topCenter,
                              colors: [
                                Colors.black.withValues(alpha: 0.4),
                                Colors.transparent,
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                // Rating badge
                Positioned(
                  top: 10,
                  right: 10,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 9,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.95),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.1),
                          blurRadius: 6,
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.star_rounded,
                          color: AppColors.amber500,
                          size: 13,
                        ),
                        const SizedBox(width: 3),
                        Text(
                          data.rating,
                          style: AppTheme.body(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                // Available badge
                if (data.available)
                  Positioned(
                    top: 10,
                    left: 10,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.secondary,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 5,
                            height: 5,
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Available',
                            style: AppTheme.body(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
            // ── Info ──
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    data.name,
                    style: AppTheme.headline(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 3),
                  Text(
                    data.role,
                    style: AppTheme.body(
                      fontSize: 12,
                      color: AppColors.onSurfaceVariant,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(
                        Icons.location_on_rounded,
                        size: 12,
                        color: AppColors.outlineVariant,
                      ),
                      const SizedBox(width: 3),
                      Expanded(
                        child: Text(
                          data.location,
                          style: AppTheme.body(
                            fontSize: 11,
                            color: AppColors.outlineVariant,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: onTap,
                          icon: const Icon(Icons.phone_rounded, size: 14),
                          label: const Text('Call'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            textStyle: GoogleFonts.inter(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      if (onChat != null)
                        SizedBox(
                          width: 40,
                          child: ElevatedButton(
                            onPressed: onChat,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.secondary,
                              foregroundColor: Colors.white,
                              elevation: 0,
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: const Icon(Icons.chat_rounded, size: 18),
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
}
