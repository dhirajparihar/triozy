import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../constants/app_categories.dart';
import '../models/chat_model.dart';
import '../models/mate_model.dart';
import '../models/worker_model.dart';
import '../providers/chat_provider.dart';
import '../providers/location_provider.dart';
import '../screens/add_request_screen.dart';
import '../screens/all_categories_screen.dart';
import '../screens/chat_detail_screen.dart';
import '../screens/worker_list_screen.dart';
import '../screens/worker_profile_screen.dart';
import '../services/database_service.dart';
import '../services/location_service.dart';
import '../theme/app_colors.dart';

class ScreenUtil {
  static bool isMobile(BuildContext context) =>
      MediaQuery.of(context).size.width < 600;

  static bool isTablet(BuildContext context) =>
      MediaQuery.of(context).size.width >= 600 &&
      MediaQuery.of(context).size.width < 1024;

  static bool isDesktop(BuildContext context) =>
      MediaQuery.of(context).size.width >= 1024;
}

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

  static const List<_HomeCategoryItem> _categories = [
    _HomeCategoryItem(
      label: 'Electrician',
      category: 'Electrician',
      imageUrl:
          'https://lh3.googleusercontent.com/aida-public/AB6AXuC-eL5ZvDeISt0w2u0DR1osoZqXxH0DKO9YCBmoJAhw0zw5M0nULj0QcNh14z7RzMwC2sPi6Aw5aiepDhxhuKKZnQC-Y51TcineiQIlnhcD_oBbLntDbegJBXAYCB1K0jStkwbU_R9ek97RPWgz0d-2thTAO3CrR2h5Rq08mAZHz0GrsJqJs9CK5ta9Fe2kcH40uAUui3R5q258lfv3hmyDiVPgSiEJn-ebgr4tzXr1qkxamyYlrAqc-VFvw1k5pj7CZX54MfVIXGQ',
    ),
    _HomeCategoryItem(
      label: 'Plumber',
      category: 'Plumber',
      imageUrl:
          'https://lh3.googleusercontent.com/aida-public/AB6AXuCHB8HEtlkIngffZC4YxjMghwS577KPR9kJt0uUc07S5Mlm1qkPq2vSuAEn6cJgSZYYjeUbJI_Cvdx1qb8OjdWB86JZmvnlQ1301eq6gBoaDY8XQiGZk5dZjUfZg_X3UOHOgKkSspxgjxZ4bo2c0J-J7B6z5Ud7AS13btPeFC3wsglYjjxjQvw1kw2L0f34nm_nGTFDyvM-KkzyMCufsdX0sOJGBYpuikYwIpW6W_ztX6gRGhTf60sId5Fp74D0JEuqvh_TatgV8os',
    ),
    _HomeCategoryItem(
      label: 'AC Repair',
      category: 'AC Repair',
      imageUrl:
          'https://lh3.googleusercontent.com/aida-public/AB6AXuCwJdWFNgZs5x6jOIZ_TD3QLZlaYKCr0IFVtFr-Y6js2VvkJvyM2Y4vCVnHNcl2X9uI9DXL0NpyIWgXl2bb0Rv05Yykpxk6ooavynLjBDx-dIahugWk8hDsFiqDkf8ocIn6Pv-AUPAzBAYehZCUa-Q73mbN9x_ZpMIpOxI-aRso0RGCdvpQZCqYaP40WrVLmn2Pbq7zdZXTDgIHaQcZfxBCSl0tk-AYg7n_q9PkfvOhRERWWfby5v6QHS_FLc_g81ixfPBcIiaTPQI',
    ),
    _HomeCategoryItem(
      label: 'Home Cleaning',
      category: 'Cleaning',
      imageUrl:
          'https://lh3.googleusercontent.com/aida-public/AB6AXuDPwfwKoxuNUrUCIA5XaU6YkT1mDUGRkcKWD3ZthjMw8S7TCAeOYmCc7vzIfvCu0rTOokppQ_iqrL3SaHZlcosZGQnzmxdtSLQYtC9IdFsia3ag5zbh4mcRmTrxFOxbaf4p2HhoZADeMClp1aKzPM9mG29Uw205KnC76EhPzP9_PAWC5Ja1PPwG44gWFyiRUJvSZ0WE7J7G6udOV6jkVaCU7YPag_gMf8Ay5Y5Y42HDS8oOKs4iO3VKIBNe-H3VwA46BnLoKurHUy4',
    ),
  ];

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
    } catch (_) {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  (String?, String?) _extractCityState(String address) {
    final parts = address
        .split(',')
        .map((part) => part.trim())
        .where((part) => part.isNotEmpty)
        .toList();
    if (parts.isEmpty) {
      return (null, null);
    }

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

  Future<void> _launchPhone(String phone) async {
    final cleaned = phone.trim();
    if (cleaned.isEmpty) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Phone number is not available')),
      );
      return;
    }

    final uri = Uri.parse('tel:$cleaned');
    final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!launched && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open the dialer')),
      );
    }
  }

  void _showComingSoon(String feature) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('$feature is coming soon')));
  }

  void _openWorkerProfile(WorkerModel worker) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => WorkerProfileScreen(workerId: worker.uid),
      ),
    );
  }

  void _openCategory(String category) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => WorkerListScreen(category: category)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final locProvider = context.watch<LocationProvider>();

    if (locProvider.isAvailable && !_locationUsed && !_loading) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _loadData());
    }

    final width = MediaQuery.of(context).size.width;
    final horizontalPadding = width < 600 ? 16.0 : 32.0;

    return RefreshIndicator(
  onRefresh: _onRefresh,
  color: AppColors.primary,
  child: SingleChildScrollView(
    physics: const AlwaysScrollableScrollPhysics(
      parent: BouncingScrollPhysics(),
    ),
    padding: EdgeInsets.only(
      left: horizontalPadding,
      right: horizontalPadding,
      top: MediaQuery.of(context).padding.top,
      bottom: 16,
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildHeroSection(context),
        const SizedBox(height: 54),
        _buildQuickActions(context),
        const SizedBox(height: 28),
        _buildCategoriesSection(context),
        if (_recentMates.isNotEmpty || _loading) ...[
          const SizedBox(height: 30),
          _buildMatesSection(context),
        ],
        const SizedBox(height: 30),
        _buildTopWorkersSection(context),
      ],
    ),
  ),
);
  }

  Widget _buildHeroSection(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final scale = (width / 400).clamp(0.75, 1.2);
        final isCompact = width < 340;
        final outerPadding = isCompact ? 18.0 : 24.0;
        final heroHeight = (240 * scale).clamp(200.0, 260.0);
        final titleSize = (24 * scale).clamp(18.0, 32.0);
        final bodySize = (12.5 * scale).clamp(11.0, 14.0);
        final illustrationWidth = (160 * scale).clamp(120.0, 220.0);
        final searchInset = isCompact ? 6.0 : 10.0;

        return Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              width: double.infinity,
              padding: EdgeInsets.fromLTRB(
                outerPadding,
                isCompact ? 20 : 24,
                outerPadding,
                isCompact ? 24 : 28,
              ),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(36),
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF80A7FB), Color(0xFFC8B4FF)],
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF7DA5FF).withValues(alpha: 0.18),
                    blurRadius: 30,
                    offset: const Offset(0, 12),
                  ),
                ],
              ),
              child: SizedBox(
                height: heroHeight,
                child: Stack(
                  children: [
                    Positioned(
                      top: -36,
                      left: -18,
                      child: _GlowOrb(
                        size: 130,
                        color: Colors.white.withValues(alpha: 0.18),
                      ),
                    ),
                    Positioned(
                      top: 68,
                      right: -18,
                      child: _GlowOrb(
                        size: 118,
                        color: Colors.white.withValues(alpha: 0.14),
                      ),
                    ),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(
                          child: Padding(
                            padding: EdgeInsets.only(
                              top: isCompact ? 14 : 18,
                              bottom: 20,
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                RichText(
                                  text: TextSpan(
                                    children: [
                                      TextSpan(
                                        text: 'Your local network,\n',
                                        style: GoogleFonts.manrope(
                                          fontSize: titleSize,
                                          height: 1.05,
                                          fontWeight: FontWeight.w800,
                                          color: Colors.white,
                                          letterSpacing: -1.2,
                                        ),
                                      ),
                                      TextSpan(
                                        text: 'for everything.',
                                        style: GoogleFonts.manrope(
                                          fontSize: titleSize,
                                          height: 1.05,
                                          fontWeight: FontWeight.w900,
                                          color: const Color(0xFF243C98),
                                          letterSpacing: -1.2,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  'Find services, post requests,\nor connect with a mate -\nall near you.',
                                  maxLines: 3,
                                  overflow: TextOverflow.ellipsis,
                                  style: GoogleFonts.inter(
                                    fontSize: bodySize,
                                    height: 1.6,
                                    fontWeight: FontWeight.w500,
                                    color: const Color(0xFF2E385A),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        SizedBox(
                          width: illustrationWidth,
                          child: Stack(
                            clipBehavior: Clip.none,
                            children: [
                              Positioned.fill(
                                child: IgnorePointer(
                                  child: CustomPaint(
                                    painter: _HeroTrailPainter(),
                                  ),
                                ),
                              ),
                              Positioned(
                                right: isCompact ? -8 : -2,
                                bottom: -4,
                                child: Transform.scale(
                                  scale: isCompact ? 0.72 : 0.84,
                                  alignment: Alignment.bottomRight,
                                  child: const _HeroIllustration(),
                                ),
                              ),
                              Positioned(
                                top: isCompact ? 44 : 38,
                                left: isCompact ? 14 : 14,
                                child: _HeroBadge(
                                  icon: Icons.electric_scooter_rounded,
                                  background: Colors.white.withValues(
                                    alpha: 0.88,
                                  ),
                                  iconColor: const Color(0xFF6376E8),
                                ),
                              ),
                              Positioned(
                                top: isCompact ? 18 : 12,
                                left: isCompact ? 58 : 80,
                                child: _HeroPinBadge(isCompact: isCompact),
                              ),
                              Positioned(
                                top: isCompact ? 44 : 40,
                                right: isCompact ? 0 : 4,
                                child: _HeroBadge(
                                  icon: Icons.handyman_rounded,
                                  background: Colors.white.withValues(
                                    alpha: 0.88,
                                  ),
                                  iconColor: const Color(0xFF6376E8),
                                ),
                              ),
                              Positioned(
                                left: isCompact ? 8 : 12,
                                bottom: isCompact ? 66 : 72,
                                child: _HeroBadge(
                                  icon: Icons.groups_rounded,
                                  background: Colors.white.withValues(
                                    alpha: 0.88,
                                  ),
                                  iconColor: const Color(0xFFF08A53),
                                ),
                              ),
                              Positioned(
                                right: isCompact ? 0 : 2,
                                bottom: isCompact ? 44 : 48,
                                child: _HeroBadge(
                                  icon: Icons.home_rounded,
                                  background: Colors.white.withValues(
                                    alpha: 0.88,
                                  ),
                                  iconColor: const Color(0xFF8A67E5),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            Positioned(
              left: outerPadding + searchInset,
              right: outerPadding + searchInset,
              bottom: -28,
              child: GestureDetector(
                onTap: widget.onSearchTapped,
                child: Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: isCompact ? 16 : 20,
                    vertical: isCompact ? 15 : 17,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(999),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF263E98).withValues(alpha: 0.10),
                        blurRadius: 26,
                        offset: const Offset(0, 10),
                      ),
                    ],
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.92),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.search_rounded,
                        color: AppColors.primary,
                        size: isCompact ? 25 : 29,
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: RichText(
                          text: TextSpan(
                            style: GoogleFonts.inter(
                              fontSize: isCompact ? 14.5 : 16,
                              color: const Color(0xFF6B7280),
                            ),
                            children: [
                              const TextSpan(text: 'Search for '),
                              TextSpan(
                                text: _searchHints[_hintIndex],
                                style: GoogleFonts.inter(
                                  fontSize: isCompact ? 14.5 : 16,
                                  fontWeight: FontWeight.w700,
                                  color: const Color(0xFF1F2937),
                                ),
                              ),
                            ],
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildQuickActions(BuildContext context) {
    final isMobile = ScreenUtil.isMobile(context);
    final cardWidth = isMobile ? 120.0 : 260.0;

    return SizedBox(
      height: 160,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.only(right: 10),
        itemCount: 4,
        separatorBuilder: (_, __) => const SizedBox(width: 16),
        itemBuilder: (context, index) {
          return SizedBox(
            width: cardWidth,
            child: [
              _QuickActionCard(
                title: 'Services',
                subtitle: 'Find pros',
                icon: Icons.handyman_rounded,
                tint: const Color(0xFFEFF5FF),
                accent: AppColors.primary,
                onTap: widget.onSearchTapped,
              ),
              _QuickActionCard(
                title: 'Requests',
                subtitle: 'Post a job',
                icon: Icons.assignment_rounded,
                tint: const Color(0xFFFFF3EC),
                accent: const Color(0xFFF97316),
                onTap: widget.onRequestsTapped ??
                    () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const AddRequestScreen(),
                          ),
                        ),
              ),
              _QuickActionCard(
                title: 'Mates',
                subtitle: 'Find roommates',
                icon: Icons.group_rounded,
                tint: const Color(0xFFF1FBF3),
                accent: const Color(0xFF2F9E44),
                onTap: widget.onMatesTapped,
              ),
              _QuickActionCard(
                title: 'Rides',
                subtitle: 'Book or share',
                icon: Icons.directions_car_filled_rounded,
                tint: const Color(0xFFF7F1FF),
                accent: const Color(0xFF8B5CF6),
                onTap: () => _showComingSoon('Rides'),
              ),
            ][index],
          );
        },
      ),
    );
  }

  Widget _buildCategoriesSection(BuildContext context) {
    final isMobile = ScreenUtil.isMobile(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionHeader(
          title: 'Top Categories',
          actionLabel: 'View All',
          onActionTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const AllCategoriesScreen()),
          ),
        ),
        const SizedBox(height: 16),
        if (isMobile)
          SizedBox(
            height: 126,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.only(right: 24),
              itemCount: _categories.length + 1,
              separatorBuilder: (_, _) => const SizedBox(width: 18),
              itemBuilder: (context, index) {
                if (index == _categories.length) {
                  return _CategoryCircle(
                    label: 'All Services',
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const AllCategoriesScreen(),
                      ),
                    ),
                    isAllServices: true,
                  );
                }

                final item = _categories[index];
                return _CategoryCircle(
                  label: item.label,
                  imageUrl: item.imageUrl,
                  onTap: () => _openCategory(item.category),
                );
              },
            ),
          )
        else
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _categories.length + 1,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 4,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              childAspectRatio: 1,
            ),
            itemBuilder: (context, index) {
              if (index == _categories.length) {
                return _CategoryCircle(
                  label: 'All Services',
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const AllCategoriesScreen(),
                    ),
                  ),
                  isAllServices: true,
                );
              }

              final item = _categories[index];
              return _CategoryCircle(
                label: item.label,
                imageUrl: item.imageUrl,
                onTap: () => _openCategory(item.category),
              );
            },
          ),
      ],
    );
  }

  Widget _buildMatesSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionHeader(
          title: 'Mates Near You',
          subtitle: 'Roommates, Helpmates & Ridematch nearby',
          actionLabel: 'See All',
          onActionTap: widget.onMatesTapped,
        ),
        const SizedBox(height: 16),
        SizedBox(
          height: 174,
          child: _loading
              ? ListView.separated(
                  scrollDirection: Axis.horizontal,
                  physics: const ClampingScrollPhysics(),
                  padding: const EdgeInsets.only(right: 16),
                  itemCount: 3,
                  separatorBuilder: (_, _) => const SizedBox(width: 14),
                  itemBuilder: (_, _) => const _MateCardSkeleton(),
                )
              : ListView.separated(
                  scrollDirection: Axis.horizontal,
                  physics: const ClampingScrollPhysics(),
                  padding: const EdgeInsets.only(right: 16),
                  itemCount: _recentMates.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 14),
                  itemBuilder: (context, index) {
                    final mate = _recentMates[index];
                    return _MatePreviewCard(
                      mate: mate,
                      onTap: widget.onMatesTapped,
                      onChatTap: () => _openContextChat(
                        otherUserId: mate.userId,
                        chatType: ChatType.mate,
                        referenceId: mate.id,
                        otherUserName: mate.userName,
                        otherUserPhotoUrl: mate.userPhoto,
                        otherUserLocation: mate.location,
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildTopWorkersSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionHeader(
          title: _locationUsed ? 'Pros Near You' : 'Pros For You',
          actionLabel: 'See All',
          onActionTap: widget.onSearchTapped,
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: const Color(0xFFEFFAF2),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(_proximityIcon, size: 14, color: AppColors.secondary),
              const SizedBox(width: 6),
              Text(
                _proximityLabel,
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppColors.secondary,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        if (_loading)
          SizedBox(
            height: 166,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              physics: const ClampingScrollPhysics(),
              padding: const EdgeInsets.only(right: 16),
              itemCount: 3,
              separatorBuilder: (_, _) => const SizedBox(width: 14),
              itemBuilder: (_, _) => const _WorkerCardSkeleton(),
            ),
          )
        else if (_topWorkers.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 26),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(26),
              border: Border.all(
                color: AppColors.outlineVariant.withValues(alpha: 0.35),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Column(
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: AppColors.blue50,
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: const Icon(
                    Icons.person_search_rounded,
                    color: AppColors.primary,
                    size: 28,
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  'No professionals nearby yet',
                  style: GoogleFonts.manrope(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: AppColors.onSurface,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Try changing your location or post a request instead.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    height: 1.5,
                    color: AppColors.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          )
        else
          SizedBox(
            height: 166,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              physics: const ClampingScrollPhysics(),
              padding: const EdgeInsets.only(right: 16),
              itemCount: _topWorkers.length,
              separatorBuilder: (_, _) => const SizedBox(width: 14),
              itemBuilder: (context, index) {
                final worker = _topWorkers[index];
                return _WorkerCard(
                  data: _WorkerData(
                    name: worker.name,
                    role: worker.serviceType.isEmpty
                        ? 'Service professional'
                        : worker.serviceType,
                    rating: worker.ratingDisplay,
                    location: worker.distanceDisplay,
                    imageUrl: worker.photoUrl,
                    available: worker.isAvailable,
                  ),
                  onTap: () => _openWorkerProfile(worker),
                  onCallTap: () => _launchPhone(worker.phone),
                  onChatTap: () => _openContextChat(
                    otherUserId: worker.uid,
                    chatType: ChatType.service,
                    referenceId: worker.uid,
                    otherUserName: worker.name,
                    otherUserPhotoUrl: worker.photoUrl,
                    otherUserLocation: worker.location,
                  ),
                );
              },
            ),
          ),
      ],
    );
  }
}

double cardWidth(BuildContext context) {
  final width = MediaQuery.of(context).size.width;

  if (width > 1000) return 320;
  if (width > 600) return 260;
  return width * 0.75;
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final String actionLabel;
  final VoidCallback? onActionTap;

  const _SectionHeader({
    required this.title,
    required this.actionLabel,
    this.subtitle,
    this.onActionTap,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                title,
                style: GoogleFonts.manrope(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: AppColors.onSurface,
                  letterSpacing: -0.4,
                ),
              ),
            ),
            GestureDetector(
              onTap: onActionTap,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    actionLabel,
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(width: 4),
                  const Icon(
                    Icons.arrow_forward_ios_rounded,
                    size: 14,
                    color: AppColors.primary,
                  ),
                ],
              ),
            ),
          ],
        ),
        if (subtitle != null) ...[
          const SizedBox(height: 4),
          Text(
            subtitle!,
            style: GoogleFonts.inter(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: AppColors.slate500,
            ),
          ),
        ],
      ],
    );
  }
}

class _QuickActionCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color tint;
  final Color accent;
  final VoidCallback? onTap;

  const _QuickActionCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.tint,
    required this.accent,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 164,
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
        decoration: BoxDecoration(
          color: tint,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: accent.withValues(alpha: 0.10)),
          boxShadow: [
            BoxShadow(
              color: accent.withValues(alpha: 0.08),
              blurRadius: 16,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: accent.withValues(alpha: 0.10),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Icon(icon, color: accent, size: 22),
            ),
            const Spacer(),
            Text(
              title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.manrope(
                fontSize: 13,
                height: 1.1,
                fontWeight: FontWeight.w800,
                color: AppColors.onSurface,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.inter(
                fontSize: 11,
                height: 1.3,
                fontWeight: FontWeight.w500,
                color: AppColors.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.bottomRight,
              child: Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  border: Border.all(color: accent.withValues(alpha: 0.18)),
                ),
                child: Icon(
                  Icons.arrow_forward_rounded,
                  color: accent,
                  size: 17,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CategoryCircle extends StatelessWidget {
  final String label;
  final String? imageUrl;
  final VoidCallback onTap;
  final bool isAllServices;

  const _CategoryCircle({
    required this.label,
    required this.onTap,
    this.imageUrl,
    this.isAllServices = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: 82,
        child: Column(
          children: [
            Container(
              width: 76,
              height: 76,
              decoration: BoxDecoration(
                color: isAllServices ? const Color(0xFFF8FAFC) : Colors.white,
                shape: BoxShape.circle,
                border: Border.all(
                  color: AppColors.outlineVariant.withValues(alpha: 0.26),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 14,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              clipBehavior: Clip.antiAlias,
              child: isAllServices
                  ? const Center(
                      child: Icon(
                        Icons.more_horiz_rounded,
                        color: AppColors.slate400,
                        size: 30,
                      ),
                    )
                  : Image.network(
                      imageUrl!,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => const Center(
                        child: Icon(
                          Icons.image_not_supported_outlined,
                          color: AppColors.outlineVariant,
                        ),
                      ),
                    ),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 12,
                height: 1.2,
                fontWeight: FontWeight.w600,
                color: AppColors.onSurface,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

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
        if (mate.budget != null && mate.budget!.trim().isNotEmpty) {
          final value = mate.budget!.trim();
          return value.startsWith('Rs')
              ? '$value / month'
              : 'Rs $value / month';
        }
        if (mate.description.isNotEmpty) {
          return mate.description;
        }
        return 'Looking nearby';
      case MateType.helpmate:
        if (mate.helpTypes.isNotEmpty) {
          return mate.helpTypes.take(2).join(' / ');
        }
        return mate.available ? 'Available now' : 'Unavailable';
      case MateType.ridemate:
        if (mate.fromLocation != null && mate.toLocation != null) {
          return '${mate.fromLocation} -> ${mate.toLocation}';
        }
        if (mate.departureTime != null && mate.departureTime!.isNotEmpty) {
          return 'Departs ${mate.departureTime}';
        }
        return mate.description.isNotEmpty ? mate.description : 'Ride details';
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: cardWidth(context),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: _color.withValues(alpha: 0.16), width: 1.2),
          boxShadow: [
            BoxShadow(
              color: _color.withValues(alpha: 0.08),
              blurRadius: 18,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Stack(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _color.withValues(alpha: 0.10),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: mate.userPhoto.isNotEmpty
                          ? Image.network(
                              mate.userPhoto,
                              fit: BoxFit.cover,
                              errorBuilder: (_, _, _) =>
                                  Icon(_icon, color: _color, size: 24),
                            )
                          : Icon(_icon, color: _color, size: 24),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(right: 48),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              mate.userName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.manrope(
                                fontSize: 17,
                                fontWeight: FontWeight.w800,
                                color: AppColors.onSurface,
                              ),
                            ),
                            const SizedBox(height: 5),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 5,
                              ),
                              decoration: BoxDecoration(
                                color: _color.withValues(alpha: 0.10),
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text(
                                mate.type.label,
                                style: GoogleFonts.inter(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: _color,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    const Icon(
                      Icons.location_on_outlined,
                      size: 15,
                      color: AppColors.slate400,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        mate.location.isEmpty
                            ? 'Location not available'
                            : mate.location,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.inter(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w500,
                          color: AppColors.slate500,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  _detail,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    height: 1.4,
                    fontWeight: FontWeight.w700,
                    color: mate.type == MateType.roommate
                        ? AppColors.secondary
                        : AppColors.onSurfaceVariant,
                  ),
                ),
              ],
            ),
            Positioned(
              right: 0,
              bottom: 0,
              child: _ChatActionButton(onTap: onChatTap),
            ),
          ],
        ),
      ),
    );
  }
}

class _WorkerCard extends StatelessWidget {
  final _WorkerData data;
  final VoidCallback onTap;
  final VoidCallback onCallTap;
  final VoidCallback? onChatTap;

  const _WorkerCard({
    required this.data,
    required this.onTap,
    required this.onCallTap,
    this.onChatTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: cardWidth(context),
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
        decoration: BoxDecoration(
          color: const Color(0xFFFBFCFE),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: AppColors.outlineVariant.withValues(alpha: 0.24),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    color: AppColors.surfaceContainerHigh,
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: data.imageUrl.isEmpty
                      ? const Icon(
                          Icons.person_rounded,
                          color: AppColors.outline,
                          size: 28,
                        )
                      : Image.network(
                          data.imageUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) => const Icon(
                            Icons.person_rounded,
                            color: AppColors.outline,
                            size: 28,
                          ),
                        ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (data.available)
                        Row(
                          children: [
                            Container(
                              width: 8,
                              height: 8,
                              decoration: const BoxDecoration(
                                color: AppColors.secondary,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'Available',
                              style: GoogleFonts.inter(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w700,
                                color: AppColors.secondary,
                              ),
                            ),
                          ],
                        ),
                      if (data.available) const SizedBox(height: 5),
                      Text(
                        data.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.manrope(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          color: AppColors.onSurface,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        data.role,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: AppColors.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Row(
                        children: [
                          const Icon(
                            Icons.location_on_outlined,
                            size: 13,
                            color: AppColors.slate400,
                          ),
                          const SizedBox(width: 5),
                          Expanded(
                            child: Text(
                              data.location,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: AppColors.slate500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(
                      color: AppColors.outlineVariant.withValues(alpha: 0.24),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.star_rounded,
                        size: 13,
                        color: AppColors.amber500,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        data.rating,
                        style: GoogleFonts.inter(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w800,
                          color: AppColors.onSurface,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const Spacer(),
            Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 40,
                    child: ElevatedButton.icon(
                      onPressed: onCallTap,
                      icon: const Icon(Icons.call_rounded, size: 17),
                      label: const Text('Call'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        textStyle: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                if (onChatTap != null)
                  SizedBox(
                    width: 40,
                    height: 40,
                    child: _ChatActionButton(onTap: onChatTap),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _MateCardSkeleton extends StatelessWidget {
  const _MateCardSkeleton();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 268,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: const [
          Row(
            children: [
              _SkeletonBox(width: 56, height: 56, radius: 28),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _SkeletonBox(width: 118, height: 16),
                    SizedBox(height: 8),
                    _SkeletonBox(width: 74, height: 22, radius: 11),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: 18),
          _SkeletonBox(width: 160, height: 14),
          SizedBox(height: 10),
          _SkeletonBox(width: 116, height: 16),
        ],
      ),
    );
  }
}

class _WorkerCardSkeleton extends StatelessWidget {
  const _WorkerCardSkeleton();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 262,
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        children: const [
          Row(
            children: [
              _SkeletonBox(width: 56, height: 56, radius: 16),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _SkeletonBox(width: 58, height: 12),
                    SizedBox(height: 8),
                    _SkeletonBox(width: 120, height: 16),
                    SizedBox(height: 6),
                    _SkeletonBox(width: 92, height: 13),
                  ],
                ),
              ),
              _SkeletonBox(width: 44, height: 26, radius: 13),
            ],
          ),
          Spacer(),
          Row(
            children: [
              Expanded(
                child: _SkeletonBox(
                  width: double.infinity,
                  height: 40,
                  radius: 16,
                ),
              ),
              SizedBox(width: 10),
              _SkeletonBox(width: 40, height: 40, radius: 20),
            ],
          ),
        ],
      ),
    );
  }
}

class _SkeletonBox extends StatelessWidget {
  final double width;
  final double height;
  final double radius;

  const _SkeletonBox({
    required this.width,
    required this.height,
    this.radius = 8,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }
}

class _HeroIllustration extends StatelessWidget {
  const _HeroIllustration();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 220,
      height: 214,
      child: CustomPaint(painter: _HeroScenePainter()),
    );
  }
}

class _HeroScenePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final buildingPaint = Paint()
      ..color = const Color(0xFF768FEF).withValues(alpha: 0.18);
    final detailPaint = Paint()..color = Colors.white.withValues(alpha: 0.22);
    final purpleLeafPaint = Paint()
      ..color = const Color(0xFF8F7AEB).withValues(alpha: 0.30);
    final blueLeafPaint = Paint()
      ..color = const Color(0xFF6D83EA).withValues(alpha: 0.20);

    final buildings = [
      Rect.fromLTWH(size.width * 0.36, size.height * 0.42, 16, 70),
      Rect.fromLTWH(size.width * 0.48, size.height * 0.34, 22, 86),
      Rect.fromLTWH(size.width * 0.62, size.height * 0.28, 24, 98),
      Rect.fromLTWH(size.width * 0.76, size.height * 0.38, 18, 78),
    ];
    for (final rect in buildings) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, const Radius.circular(8)),
        buildingPaint,
      );
      for (double y = rect.top + 10; y < rect.bottom - 8; y += 14) {
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(rect.left + 5, y, 4, 6),
            const Radius.circular(2),
          ),
          detailPaint,
        );
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(rect.left + rect.width - 9, y, 4, 6),
            const Radius.circular(2),
          ),
          detailPaint,
        );
      }
    }

    canvas.drawOval(
      Rect.fromLTWH(size.width * 0.08, size.height * 0.74, 20, 68),
      blueLeafPaint,
    );
    canvas.drawOval(
      Rect.fromLTWH(size.width * 0.90, size.height * 0.62, 18, 78),
      purpleLeafPaint,
    );
    canvas.drawOval(
      Rect.fromLTWH(size.width * 0.86, size.height * 0.68, 12, 60),
      purpleLeafPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _HeroBadge extends StatelessWidget {
  final IconData icon;
  final Color background;
  final Color iconColor;

  const _HeroBadge({
    required this.icon,
    required this.background,
    this.iconColor = Colors.white,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(
        color: background,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white.withValues(alpha: 0.35)),
        boxShadow: [
          BoxShadow(
            color: Colors.white.withValues(alpha: 0.18),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Icon(icon, size: 20, color: iconColor),
    );
  }
}

class _HeroPinBadge extends StatelessWidget {
  final bool isCompact;

  const _HeroPinBadge({required this.isCompact});

  @override
  Widget build(BuildContext context) {
    final size = isCompact ? 82.0 : 94.0;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: const Color(0xFF6372EA),
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF6372EA).withValues(alpha: 0.24),
            blurRadius: 22,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Icon(
        Icons.location_on_rounded,
        color: Colors.white,
        size: isCompact ? 42 : 50,
      ),
    );
  }
}

class _HeroTrailPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.42)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6;

    final pathOne = Path()
      ..moveTo(size.width * 0.24, size.height * 0.30)
      ..quadraticBezierTo(
        size.width * 0.50,
        size.height * 0.10,
        size.width * 0.82,
        size.height * 0.26,
      );
    final pathTwo = Path()
      ..moveTo(size.width * 0.18, size.height * 0.72)
      ..quadraticBezierTo(
        size.width * 0.42,
        size.height * 0.40,
        size.width * 0.72,
        size.height * 0.62,
      );

    _drawDashedPath(canvas, pathOne, paint);
    _drawDashedPath(canvas, pathTwo, paint);

    final cloudPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.28)
      ..style = PaintingStyle.fill;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(size.width * 0.24, size.height * 0.06, 34, 10),
        const Radius.circular(8),
      ),
      cloudPaint,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(size.width * 0.80, size.height * 0.14, 32, 10),
        const Radius.circular(8),
      ),
      cloudPaint,
    );
  }

  void _drawDashedPath(Canvas canvas, Path path, Paint paint) {
    for (final metric in path.computeMetrics()) {
      double distance = 0;
      while (distance < metric.length) {
        final next = distance + 7;
        canvas.drawPath(metric.extractPath(distance, next), paint);
        distance += 11;
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _GlowOrb extends StatelessWidget {
  final double size;
  final Color color;

  const _GlowOrb({required this.size, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(colors: [color, Colors.transparent]),
      ),
    );
  }
}

class _HomeCategoryItem {
  final String label;
  final String category;
  final String imageUrl;

  const _HomeCategoryItem({
    required this.label,
    required this.category,
    required this.imageUrl,
  });
}

class _WorkerData {
  final String name;
  final String role;
  final String rating;
  final String location;
  final String imageUrl;
  final bool available;

  const _WorkerData({
    required this.name,
    required this.role,
    required this.rating,
    required this.location,
    required this.imageUrl,
    required this.available,
  });
}

class _ChatActionButton extends StatelessWidget {
  final VoidCallback? onTap;

  const _ChatActionButton({this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color: AppColors.primary,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withValues(alpha: 0.22),
              blurRadius: 12,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: const Icon(
          Icons.chat_bubble_rounded,
          color: Colors.white,
          size: 18,
        ),
      ),
    );
  }
}
