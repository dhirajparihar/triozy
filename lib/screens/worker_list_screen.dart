import 'package:flutter/material.dart';
import 'dart:ui';
import 'package:provider/provider.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../models/worker_model.dart';
import '../services/database_service.dart';
import '../services/location_service.dart';
import '../providers/location_provider.dart';
import '../screens/worker_profile_screen.dart';

class WorkerListScreen extends StatefulWidget {
  final String category;

  const WorkerListScreen({super.key, required this.category});

  @override
  State<WorkerListScreen> createState() => _WorkerListScreenState();
}

class _WorkerListScreenState extends State<WorkerListScreen> {
  List<WorkerModel> _workers = [];
  bool _loading = true;
  double? _userLat;
  double? _userLng;
  String _activeFilter = 'Filters';

  @override
  void initState() {
    super.initState();
    _loadWorkers();
  }

  Future<void> _loadWorkers() async {
    final db = context.read<DatabaseService>();
    final locProvider = context.read<LocationProvider>();
    final locService = context.read<LocationService>();

    try {
      // Use shared location if available
      _userLat = locProvider.latitude;
      _userLng = locProvider.longitude;

      List<WorkerModel> workers;

      if (_userLat != null && _userLng != null) {
        workers = await locService.getNearbyWorkers(
          latitude: _userLat!,
          longitude: _userLng!,
          radiusKm: 25,
          serviceType: widget.category,
        );
      } else {
        workers = await db.getWorkersByCategory(widget.category);
      }

      if (mounted) {
        setState(() {
          _workers = workers;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _applyFilter(String filter) {
    setState(() {
      _activeFilter = filter;
      switch (filter) {
        case 'Nearest':
          _workers.sort((a, b) {
            final da = a.distanceKm ?? double.infinity;
            final db = b.distanceKm ?? double.infinity;
            return da.compareTo(db);
          });
          break;
        case 'Highest Rated':
          _workers.sort((a, b) => b.rating.compareTo(a.rating));
          break;
        case 'Available Now':
          final available = _workers.where((w) => w.isAvailable).toList();
          final unavailable = _workers.where((w) => !w.isAvailable).toList();
          _workers = [...available, ...unavailable];
          break;
        default:
          // Default: sort by rating
          _workers.sort((a, b) => b.rating.compareTo(a.rating));
          break;
      }
    });
  }

  Future<void> _onRefresh() async {
    setState(() {
      _loading = true;
      _workers = [];
    });
    await _loadWorkers();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: RefreshIndicator(
        onRefresh: _onRefresh,
        color: AppColors.primary,
        child: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(child: _buildAppBar(context)),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildBreadcrumb(),
                  const SizedBox(height: 8),
                  Text(
                    'Expert ${widget.category}',
                    style: AppTheme.headline(
                      fontSize: 36,
                      letterSpacing: -1.0,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Text(
                        '${_workers.length} professionals available',
                        style: AppTheme.body(
                          fontSize: 14,
                          color: AppColors.onSurfaceVariant,
                        ),
                      ),
                      if (_userLat != null) ...[
                        const SizedBox(width: 4),
                        const Icon(
                          Icons.my_location,
                          size: 12,
                          color: AppColors.secondary,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'within 25 km',
                          style: AppTheme.body(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: AppColors.secondary,
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 32),
                  _buildFilterChips(),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
          if (_loading)
            const SliverToBoxAdapter(
              child: SizedBox(
                height: 200,
                child: Center(
                  child: CircularProgressIndicator(
                    color: AppColors.primary,
                  ),
                ),
              ),
            )
          else if (_workers.isEmpty)
            SliverToBoxAdapter(
              child: SizedBox(
                height: 200,
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.person_search, size: 48, color: AppColors.outlineVariant.withValues(alpha: 0.5)),
                      const SizedBox(height: 12),
                      Text(
                        'No professionals found',
                        style: AppTheme.body(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.outline),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Try a different category or location',
                        style: AppTheme.body(fontSize: 13, color: AppColors.outlineVariant),
                      ),
                    ],
                  ),
                ),
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate((context, index) {
                  final w = _workers[index];
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 32),
                    child: _WorkerListCard(
                      data: _WData(
                        w.name,
                        w.serviceType,
                        w.ratingDisplay,
                        w.experienceDisplay,
                        w.distanceKm != null
                            ? w.distanceDisplay
                            : w.location,
                        w.description,
                        w.photoUrl,
                      ),
                      onCall: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              WorkerProfileScreen(workerId: w.uid),
                        ),
                      ),
                    ),
                  );
                }, childCount: _workers.length),
              ),
            ),
          const SliverToBoxAdapter(child: SizedBox(height: 40)),
        ],
      ),
      ),
    );
  }

  Widget _buildAppBar(BuildContext context) {
    return ClipRRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          padding: EdgeInsets.only(
            top: MediaQuery.of(context).padding.top,
            left: 16,
            right: 24,
          ),
          height: MediaQuery.of(context).padding.top + 64,
          decoration: BoxDecoration(
            color: const Color(0xFFF1F5F9).withValues(alpha: 0.8),
          ),
          child: Row(
            children: [
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.arrow_back_ios_new,
                    color: AppColors.onSurface,
                    size: 20,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'Triozy',
                style: AppTheme.headline(
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                  color: AppColors.blue700,
                  letterSpacing: -1.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBreadcrumb() {
    return Row(
      children: [
        Text(
          'Services',
          style: AppTheme.label(
            fontSize: 12,
            color: AppColors.onSurfaceVariant,
          ),
        ),
        const Icon(
          Icons.chevron_right,
          size: 14,
          color: AppColors.onSurfaceVariant,
        ),
        Text(
          widget.category,
          style: AppTheme.label(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: AppColors.primary,
          ),
        ),
      ],
    );
  }

  Widget _buildFilterChips() {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        _chip(
          'Filters',
          Icons.tune,
          _activeFilter == 'Filters',
          () => _applyFilter('Filters'),
        ),
        _chip(
          'Highest Rated',
          null,
          _activeFilter == 'Highest Rated',
          () => _applyFilter('Highest Rated'),
        ),
        _chip(
          'Nearest',
          null,
          _activeFilter == 'Nearest',
          () => _applyFilter('Nearest'),
        ),
        _chip(
          'Available Now',
          null,
          _activeFilter == 'Available Now',
          () => _applyFilter('Available Now'),
        ),
      ],
    );
  }

  Widget _chip(
    String label,
    IconData? icon,
    bool selected,
    VoidCallback onTap,
  ) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.primary
              : Colors.white,
          borderRadius: BorderRadius.circular(9999),
          border: selected
              ? null
              : Border.all(
                  color: AppColors.outlineVariant.withValues(alpha: 0.3),
                ),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.2),
                    blurRadius: 8,
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(
                icon,
                size: 18,
                color: selected
                    ? AppColors.onPrimary
                    : AppColors.onSurfaceVariant,
              ),
              const SizedBox(width: 8),
            ],
            Text(
              label,
              style: AppTheme.body(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: selected
                    ? AppColors.onPrimary
                    : AppColors.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }

}

class _WData {
  final String name, role, rating, experience, distance, description, imageUrl;
  _WData(
    this.name,
    this.role,
    this.rating,
    this.experience,
    this.distance,
    this.description,
    this.imageUrl,
  );
}

class _WorkerListCard extends StatelessWidget {
  final _WData data;
  final VoidCallback onCall;

  const _WorkerListCard({required this.data, required this.onCall});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.network(
                  data.imageUrl,
                  width: 96,
                  height: 96,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => Container(
                    width: 96,
                    height: 96,
                    color: AppColors.surfaceContainer,
                    child: const Icon(
                      Icons.person,
                      size: 36,
                      color: AppColors.outline,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 24),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            data.name,
                            style: AppTheme.headline(fontSize: 22),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.secondaryContainer.withValues(
                              alpha: 0.3,
                            ),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.star,
                                size: 16,
                                color: AppColors.secondary,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                data.rating,
                                style: AppTheme.body(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.secondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      data.role,
                      style: AppTheme.body(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: AppColors.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        const Icon(
                          Icons.history,
                          size: 18,
                          color: AppColors.onSurfaceVariant,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          data.experience,
                          style: AppTheme.body(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: AppColors.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(width: 16),
                        const Icon(
                          Icons.near_me,
                          size: 18,
                          color: AppColors.onSurfaceVariant,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            data.distance,
                            style: AppTheme.body(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: AppColors.onSurfaceVariant,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.surfaceContainerLow,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              data.description,
              style: AppTheme.body(
                fontSize: 14,
                color: AppColors.onSurfaceVariant,
              ),
            ),
          ),
          const SizedBox(height: 32),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              ElevatedButton.icon(
                onPressed: onCall,
                icon: const Icon(Icons.call, size: 20),
                label: Text(
                  'Call',
                  style: AppTheme.body(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: AppColors.onSecondary,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.secondary,
                  foregroundColor: AppColors.onSecondary,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 40,
                    vertical: 16,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 4,
                  shadowColor: AppColors.secondary.withValues(alpha: 0.2),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
