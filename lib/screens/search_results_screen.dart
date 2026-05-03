import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../models/worker_model.dart';
import '../models/chat_model.dart';
import '../providers/chat_provider.dart';
import '../services/database_service.dart';
import '../screens/worker_profile_screen.dart';
import '../screens/chat_detail_screen.dart';
import '../constants/app_categories.dart';

class SearchResultsScreen extends StatefulWidget {
  const SearchResultsScreen({super.key});

  @override
  State<SearchResultsScreen> createState() => SearchResultsScreenState();
}

class SearchResultsScreenState extends State<SearchResultsScreen> {
  late final DatabaseService _db;
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  List<WorkerModel> _allWorkers = [];
  List<WorkerModel> _results = [];
  bool _loading = true;

  // Filter state
  String? _selectedServiceType;
  String? _selectedArea;
  bool _availableOnly = false;
  double? _minRating;
  String _sortBy = 'Best Match';

  final List<String> _serviceTypes = AppCategories.all;

  final List<String> _areas = [
    'Indore',
    'Bhopal',
    'Ujjain',
    'Dewas',
    'Lucknow',
    'Delhi',
    'Mumbai',
    'Bangalore',
    'Pune',
  ];

  @override
  void initState() {
    super.initState();
    _db = context.read<DatabaseService>();
    _loadAll();
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
    if (query.trim().isNotEmpty) {
      _search(query.trim());
    }
  }

  Future<void> _loadAll() async {
    try {
      final workers = await _db.getAllWorkers();
      if (mounted) {
        setState(() {
          _allWorkers = workers;
          _applyFilters();
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _search(String query) async {
    setState(() => _loading = true);
    try {
      final workers = await _db.searchWorkers(query);
      if (mounted) {
        setState(() {
          _allWorkers = workers;
          _applyFilters();
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _applyFilters() {
    var filtered = List<WorkerModel>.from(_allWorkers);

    // Service Type filter
    if (_selectedServiceType != null) {
      filtered = filtered.where((w) {
        return w.serviceType.toLowerCase() ==
                _selectedServiceType!.toLowerCase() ||
            w.skills.any(
              (s) => s.toLowerCase() == _selectedServiceType!.toLowerCase(),
            );
      }).toList();
    }

    // Area filter
    if (_selectedArea != null) {
      filtered = filtered.where((w) {
        return w.location.toLowerCase().contains(_selectedArea!.toLowerCase());
      }).toList();
    }

    // Availability filter
    if (_availableOnly) {
      filtered = filtered.where((w) => w.available).toList();
    }
    if (_minRating != null) {
      filtered = filtered.where((w) => w.rating >= _minRating!).toList();
    }

    // Sort
    switch (_sortBy) {
      case 'Rating':
        filtered.sort((a, b) => b.rating.compareTo(a.rating));
        break;
      case 'Name':
        filtered.sort((a, b) => a.name.compareTo(b.name));
        break;
      case 'Best Match':
      default:
        filtered.sort((a, b) {
          final ratingDiff = b.rating.compareTo(a.rating);
          if (ratingDiff != 0) return ratingDiff;
          return b.totalJobs.compareTo(a.totalJobs);
        });
    }

    _results = filtered;
  }

  void _showAreaFilter() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.background,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(24),
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.7,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.outlineVariant,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text('Select Area', style: AppTheme.headline(fontSize: 20)),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _filterOption(ctx, 'All Areas', _selectedArea == null, () {
                    setState(() {
                      _selectedArea = null;
                      _applyFilters();
                    });
                    Navigator.pop(ctx);
                  }),
                  ..._areas.map(
                    (area) =>
                        _filterOption(ctx, area, _selectedArea == area, () {
                          setState(() {
                            _selectedArea = area;
                            _applyFilters();
                          });
                          Navigator.pop(ctx);
                        }),
                  ),
                ],
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  void _showServiceTypeFilter() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.background,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.7,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 20),
                  decoration: BoxDecoration(
                    color: AppColors.outlineVariant,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Text('Service Type', style: AppTheme.headline(fontSize: 20)),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _filterOption(ctx, 'All', _selectedServiceType == null, () {
                    setState(() {
                      _selectedServiceType = null;
                      _applyFilters();
                    });
                    Navigator.pop(ctx);
                  }),
                  ..._serviceTypes.map(
                    (s) => _filterOption(ctx, s, _selectedServiceType == s, () {
                      setState(() {
                        _selectedServiceType = s;
                        _applyFilters();
                      });
                      Navigator.pop(ctx);
                    }),
                  ),
                ],
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  void _showSortOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.background,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.outlineVariant,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text('Sort By', style: AppTheme.headline(fontSize: 20)),
            const SizedBox(height: 16),
            ...['Best Match', 'Rating', 'Name'].map(
              (option) => ListTile(
                title: Text(
                  option,
                  style: AppTheme.body(
                    fontSize: 16,
                    fontWeight: _sortBy == option
                        ? FontWeight.w700
                        : FontWeight.w500,
                    color: _sortBy == option
                        ? AppColors.primary
                        : AppColors.onSurface,
                  ),
                ),
                trailing: _sortBy == option
                    ? const Icon(
                        Icons.check_circle,
                        color: AppColors.primary,
                        size: 22,
                      )
                    : null,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                onTap: () {
                  setState(() {
                    _sortBy = option;
                    _applyFilters();
                  });
                  Navigator.pop(ctx);
                },
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _filterOption(
    BuildContext ctx,
    String label,
    bool selected,
    VoidCallback onTap,
  ) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary : AppColors.surfaceContainerLow,
          borderRadius: BorderRadius.circular(9999),
        ),
        child: Text(
          label,
          style: AppTheme.body(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: selected ? Colors.white : AppColors.onSurface,
          ),
        ),
      ),
    );
  }

  Future<void> _onRefresh() async {
    if (_searchController.text.isNotEmpty) {
      await _search(_searchController.text);
    } else {
      await _loadAll();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Sticky search bar + filters
        Container(
          color: AppColors.background,
          padding: const EdgeInsets.fromLTRB(20, 6, 20, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSearchBar(),
              const SizedBox(height: 6),
              _buildFilterChips(),
              const SizedBox(height: 8),
            ],
          ),
        ),
        // Scrollable results
        Expanded(
          child: RefreshIndicator(
            onRefresh: _onRefresh,
            color: AppColors.primary,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 96),
              children: [
                _buildHeader(),
                const SizedBox(height: 8),
                _buildResultsCount(),
                const SizedBox(height: 8),
                _buildResultsList(context),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildHeader() {
    return Text(
      'Find your service',
      style: AppTheme.headline(fontSize: 24, letterSpacing: -0.6),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      height: 50,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.outlineVariant.withValues(alpha: 0.25),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          const SizedBox(width: 16),
          const Icon(Icons.search_rounded, color: AppColors.outline, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              controller: _searchController,
              focusNode: _searchFocusNode,
              style: AppTheme.body(fontSize: 15),
              decoration: InputDecoration(
                hintText: 'Search services...',
                hintStyle: AppTheme.body(
                  fontSize: 15,
                  color: AppColors.slate400,
                ),
                border: InputBorder.none,
              ),
              onChanged: (v) {
                if (v.trim().isEmpty) {
                  _loadAll();
                } else {
                  _search(v);
                }
              },
            ),
          ),
          if (_searchController.text.isNotEmpty)
            GestureDetector(
              onTap: () {
                _searchController.clear();
                _loadAll();
              },
              child: const Padding(
                padding: EdgeInsets.all(12),
                child: Icon(Icons.close, color: AppColors.outline, size: 20),
              ),
            )
          else
            const SizedBox(width: 12),
        ],
      ),
    );
  }

  Widget _buildFilterChips() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          GestureDetector(
            onTap: _showServiceTypeFilter,
            child: _buildChip(
              Icons.construction,
              _selectedServiceType ?? 'Service Type',
              _selectedServiceType != null,
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: _showAreaFilter,
            child: _buildChip(
              Icons.map,
              _selectedArea ?? 'Area',
              _selectedArea != null,
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: () {
              setState(() {
                _minRating = _minRating == null ? 4.5 : null;
                _applyFilters();
              });
            },
            child: _buildChip(
              Icons.star_rounded,
              _minRating == null ? 'Rating' : '4.5+',
              _minRating != null,
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: () {
              setState(() {
                _availableOnly = !_availableOnly;
                _applyFilters();
              });
            },
            child: _buildChip(
              Icons.calendar_today,
              'Availability',
              _availableOnly,
            ),
          ),
          const SizedBox(width: 12),
          // Clear filters
          if (_selectedServiceType != null ||
              _selectedArea != null ||
              _availableOnly ||
              _minRating != null)
            GestureDetector(
              onTap: () {
                setState(() {
                  _selectedServiceType = null;
                  _selectedArea = null;
                  _availableOnly = false;
                  _minRating = null;
                  _applyFilters();
                });
              },
              child: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppColors.error.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.clear,
                  color: AppColors.error,
                  size: 20,
                ),
              ),
            )
          else
            Container(
              width: 44,
              height: 44,
              decoration: const BoxDecoration(
                color: AppColors.surfaceContainerLow,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.tune,
                color: AppColors.onSurfaceVariant,
                size: 20,
              ),
            ),
          const SizedBox(width: 8),
        ],
      ),
    );
  }

  Widget _buildChip(IconData icon, String label, bool selected) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: selected ? AppColors.primary : Colors.white,
        borderRadius: BorderRadius.circular(9999),
        border: Border.all(
          color: selected
              ? AppColors.primary
              : AppColors.outlineVariant.withValues(alpha: 0.5),
        ),
        boxShadow: selected
            ? [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.25),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ]
            : null,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 16,
            color: selected ? AppColors.onPrimary : AppColors.onSurfaceVariant,
          ),
          const SizedBox(width: 8),
          Text(
            label,
            style: AppTheme.label(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: selected
                  ? AppColors.onPrimary
                  : AppColors.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResultsCount() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          '${_results.length} professionals',
          style: AppTheme.body(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: AppColors.slate500,
          ),
        ),
        GestureDetector(
          onTap: _showSortOptions,
          child: Row(
            children: [
              Text(
                _sortBy,
                style: AppTheme.body(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: AppColors.slate500,
                ),
              ),
              const Icon(
                Icons.keyboard_arrow_down,
                size: 16,
                color: AppColors.slate500,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildResultsList(BuildContext context) {
    if (_loading) {
      return Column(
        children: List.generate(
          4,
          (i) => Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: AppColors.surfaceContainerHigh,
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        height: 12,
                        width: 120,
                        decoration: BoxDecoration(
                          color: AppColors.surfaceContainerHigh,
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        height: 10,
                        width: 80,
                        decoration: BoxDecoration(
                          color: AppColors.surfaceContainerHigh,
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Container(
                        height: 28,
                        width: 94,
                        decoration: BoxDecoration(
                          color: AppColors.surfaceContainerHigh,
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }
    if (_results.isEmpty) {
      return SizedBox(
        height: 200,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.search_off, size: 48, color: AppColors.outlineVariant),
              const SizedBox(height: 12),
              Text(
                'No results found',
                style: AppTheme.body(fontSize: 16, color: AppColors.outline),
              ),
              if (_selectedServiceType != null || _availableOnly)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: GestureDetector(
                    onTap: () {
                      setState(() {
                        _selectedServiceType = null;
                        _availableOnly = false;
                        _applyFilters();
                      });
                    },
                    child: Text(
                      'Clear filters',
                      style: AppTheme.body(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      );
    }
    return Column(
      children: _results.map((w) {
        final sw = _SearchWorker(
          name: w.name,
          role: w.serviceType,
          rating: w.ratingDisplay,
          imageUrl: w.photoUrl,
          distance: w.distanceKm != null ? w.distanceDisplay : w.location,
          available: w.available,
          verified: w.rating >= 4.8,
          uid: w.uid,
        );
        return Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: _SearchResultCard(worker: sw, accentColor: AppColors.primary),
        );
      }).toList(),
    );
  }
}

class _SearchWorker {
  final String name, role, rating, imageUrl, uid;
  final String distance;
  final bool verified;
  final bool available;

  _SearchWorker({
    required this.name,
    required this.role,
    required this.rating,
    required this.imageUrl,
    required this.distance,
    required this.available,
    this.verified = false,
    this.uid = '',
  });
}

class _SearchResultCard extends StatefulWidget {
  final _SearchWorker worker;
  final Color accentColor;

  const _SearchResultCard({required this.worker, required this.accentColor});

  @override
  State<_SearchResultCard> createState() => _SearchResultCardState();
}

class _SearchResultCardState extends State<_SearchResultCard> {
  bool _pressed = false;

  String _getInitials(String name) {
    final parts = name.trim().split(' ');
    if (parts.length >= 2) return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    return parts[0].isNotEmpty ? parts[0][0].toUpperCase() : '?';
  }

  @override
  Widget build(BuildContext context) {
    final worker = widget.worker;
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapCancel: () => setState(() => _pressed = false),
      onTapUp: (_) => setState(() => _pressed = false),
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => WorkerProfileScreen(workerId: worker.uid),
        ),
      ),
      child: AnimatedScale(
        scale: _pressed ? 0.985 : 1,
        duration: const Duration(milliseconds: 140),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.06),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: worker.imageUrl.isNotEmpty
                        ? Image.network(
                            worker.imageUrl,
                            width: 64,
                            height: 64,
                            fit: BoxFit.cover,
                            errorBuilder: (_, _, _) => _avatarFallback(),
                          )
                        : _avatarFallback(),
                  ),
                  if (worker.available)
                    Positioned(
                      left: -2,
                      bottom: -2,
                      child: Container(
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(
                          color: AppColors.secondary,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            worker.name,
                            style: AppTheme.headline(
                              fontSize: 17,
                              fontWeight: FontWeight.w800,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Row(
                          children: [
                            const Icon(
                              Icons.star_rounded,
                              size: 15,
                              color: AppColors.amber500,
                            ),
                            const SizedBox(width: 2),
                            Text(
                              worker.rating,
                              style: AppTheme.body(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.blue50,
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            worker.role,
                            style: AppTheme.label(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: AppColors.primary,
                            ),
                          ),
                        ),
                        if (worker.verified)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.secondary.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              'Top Rated',
                              style: AppTheme.label(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w700,
                                color: AppColors.secondary,
                              ),
                            ),
                          ),
                        if (worker.available)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.secondary.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.circle,
                                  size: 7,
                                  color: AppColors.secondary,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  'Available',
                                  style: AppTheme.label(
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.secondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(
                          Icons.location_on_rounded,
                          size: 14,
                          color: AppColors.slate400,
                        ),
                        const SizedBox(width: 2),
                        Expanded(
                          child: Text(
                            worker.distance,
                            style: AppTheme.body(
                              fontSize: 12,
                              color: AppColors.slate500,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Align(
                      alignment: Alignment.centerRight,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if ((FirebaseAuth.instance.currentUser?.uid ?? '') !=
                                  worker.uid &&
                              (FirebaseAuth.instance.currentUser?.uid ?? '')
                                  .isNotEmpty)
                            SizedBox(
                              height: 34,
                              width: 40,
                              child: ElevatedButton(
                                onPressed: () async {
                                  try {
                                    final conversationId = await context
                                        .read<ChatProvider>()
                                        .createOrGetChat(
                                          otherUserId: worker.uid,
                                          chatType: ChatType.service.value,
                                          referenceId: worker.uid,
                                          otherUserName: worker.name,
                                          otherUserPhotoUrl: worker.imageUrl,
                                          currentUserName: FirebaseAuth
                                              .instance
                                              .currentUser
                                              ?.displayName,
                                          currentUserPhotoUrl: FirebaseAuth
                                              .instance
                                              .currentUser
                                              ?.photoURL,
                                        );
                                    if (!context.mounted) return;
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => ChatDetailScreen(
                                          conversationId: conversationId,
                                        ),
                                      ),
                                    );
                                  } catch (e) {
                                    if (!context.mounted) return;
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          'Unable to open chat: $e',
                                        ),
                                      ),
                                    );
                                  }
                                },
                                style: ElevatedButton.styleFrom(
                                  elevation: 0,
                                  backgroundColor: AppColors.secondary,
                                  foregroundColor: Colors.white,
                                  padding: EdgeInsets.zero,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                ),
                                child: const Icon(
                                  Icons.chat_rounded,
                                  size: 16,
                                ),
                              ),
                            ),
                          if ((FirebaseAuth.instance.currentUser?.uid ?? '') !=
                                  worker.uid &&
                              (FirebaseAuth.instance.currentUser?.uid ?? '')
                                  .isNotEmpty)
                            const SizedBox(width: 8),
                          SizedBox(
                            height: 34,
                            child: ElevatedButton(
                              onPressed: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) =>
                                      WorkerProfileScreen(workerId: worker.uid),
                                ),
                              ),
                              style: ElevatedButton.styleFrom(
                                elevation: 0,
                                backgroundColor: widget.accentColor,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                textStyle: AppTheme.label(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                ),
                              ),
                              child: const Text('Book Now'),
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
        ),
      ),
    );
  }

  Widget _avatarFallback() {
    return Container(
      width: 64,
      height: 64,
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Center(
        child: Text(
          _getInitials(widget.worker.name),
          style: AppTheme.headline(
            fontSize: 22,
            fontWeight: FontWeight.w700,
            color: AppColors.primary,
          ),
        ),
      ),
    );
  }
}
