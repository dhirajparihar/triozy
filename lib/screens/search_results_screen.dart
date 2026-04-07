import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../models/worker_model.dart';
import '../services/database_service.dart';
import '../screens/worker_profile_screen.dart';

class SearchResultsScreen extends StatefulWidget {
  const SearchResultsScreen({super.key});

  @override
  State<SearchResultsScreen> createState() => _SearchResultsScreenState();
}

class _SearchResultsScreenState extends State<SearchResultsScreen> {
  late final DatabaseService _db;
  final TextEditingController _searchController = TextEditingController();
  List<WorkerModel> _allWorkers = [];
  List<WorkerModel> _results = [];
  bool _loading = true;

  // Filter state
  String? _selectedServiceType;
  String? _selectedArea;
  bool _availableOnly = false;
  String _sortBy = 'Best Match';

  final List<String> _serviceTypes = [
    'Electrician',
    'Plumber',
    'AC Repair',
    'Carpenter',
    'Tile Worker',
    'Cleaning',
    'Maid',
    'Security',
    'Gardening',
    'Ride Sharing',
    'Car Taxi',
    'Auto',
    'Personal Driver',
    'Babysitter',
    'Tailor',
    'Home Salon',
    'Roommate',
    'HelpBuddy',
    'Mechanic',
    'Tile Worker',
    'Rental Rooms',
    'Core Cutting',
    'Property',
    'RO Service',
  ];

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
    super.dispose();
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
        return w.serviceType.toLowerCase() == _selectedServiceType!.toLowerCase() ||
            w.skills.any((s) => s.toLowerCase() == _selectedServiceType!.toLowerCase());
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
                  ..._areas.map((area) => _filterOption(
                        ctx,
                        area,
                        _selectedArea == area,
                        () {
                          setState(() {
                            _selectedArea = area;
                            _applyFilters();
                          });
                          Navigator.pop(ctx);
                        },
                      )),
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
                  ..._serviceTypes.map((s) => _filterOption(
                        ctx,
                        s,
                        _selectedServiceType == s,
                        () {
                          setState(() {
                            _selectedServiceType = s;
                            _applyFilters();
                          });
                          Navigator.pop(ctx);
                        },
                      )),
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
            ...['Best Match', 'Rating', 'Name'].map((option) => ListTile(
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
                      ? const Icon(Icons.check_circle,
                          color: AppColors.primary, size: 22)
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
                )),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _filterOption(
      BuildContext ctx, String label, bool selected, VoidCallback onTap) {
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
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSearchBar(),
              const SizedBox(height: 12),
              _buildFilterChips(),
              const SizedBox(height: 16),
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
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
              children: [
                _buildHeader(),
                const SizedBox(height: 16),
                _buildResultsCount(),
                const SizedBox(height: 16),
                _buildResultsList(context),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildHeader() {
    return RichText(
      text: TextSpan(
        children: [
          TextSpan(
            text: 'Find the perfect\n',
            style: AppTheme.headline(fontSize: 28, letterSpacing: -1.0),
          ),
          TextSpan(
            text: 'solution.',
            style: AppTheme.headline(
              fontSize: 28,
              color: AppColors.primary,
              letterSpacing: -1.0,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      height: 52,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.outlineVariant.withValues(alpha: 0.4)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
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
              style: AppTheme.body(fontSize: 16),
              decoration: InputDecoration(
                hintText: 'Search services, skills, or names...',
                hintStyle: AppTheme.body(
                  fontSize: 16,
                  color: AppColors.outline,
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
            const SizedBox(width: 20),
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
          GestureDetector(
            onTap: _showAreaFilter,
            child: _buildChip(
              Icons.map,
              _selectedArea ?? 'Area',
              _selectedArea != null,
            ),
          ),
          const SizedBox(width: 12),
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
          if (_selectedServiceType != null || _selectedArea != null || _availableOnly)
            GestureDetector(
              onTap: () {
                setState(() {
                  _selectedServiceType = null;
                  _selectedArea = null;
                  _availableOnly = false;
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
                child: const Icon(Icons.clear, color: AppColors.error, size: 20),
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
        ],
      ),
    );
  }

  Widget _buildChip(IconData icon, String label, bool selected) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      decoration: BoxDecoration(
        color: selected ? AppColors.primary : Colors.white,
        borderRadius: BorderRadius.circular(9999),
        boxShadow: selected
            ? [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.3),
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
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color:
                  selected ? AppColors.onPrimary : AppColors.onSurfaceVariant,
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
        Expanded(
          child: Text(
            'Showing ${_results.length} pros in your area',
            style: AppTheme.label(fontSize: 14, color: AppColors.outline),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        GestureDetector(
          onTap: _showSortOptions,
          child: Row(
            children: [
              Text(
                _sortBy,
                style: AppTheme.label(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primary,
                ),
              ),
              const Icon(
                Icons.keyboard_arrow_down,
                size: 18,
                color: AppColors.primary,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildResultsList(BuildContext context) {
    if (_loading) {
      return const SizedBox(
        height: 200,
        child: Center(
          child: CircularProgressIndicator(color: AppColors.primary),
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
          tags: w.skills,
          imageUrl: w.photoUrl,
          verified: w.rating >= 4.8,
          uid: w.uid,
        );
        return Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: _SearchResultCard(worker: sw),
        );
      }).toList(),
    );
  }
}


class _SearchWorker {
  final String name, role, rating, imageUrl, uid;
  final List<String> tags;
  final bool verified;

  _SearchWorker({
    required this.name,
    required this.role,
    required this.rating,
    required this.tags,
    required this.imageUrl,
    this.verified = false,
    this.uid = '',
  });
}

class _SearchResultCard extends StatelessWidget {
  final _SearchWorker worker;

  const _SearchResultCard({required this.worker});

  String _getInitials(String name) {
    final parts = name.trim().split(' ');
    if (parts.length >= 2) return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    return parts[0].isNotEmpty ? parts[0][0].toUpperCase() : '?';
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => WorkerProfileScreen(workerId: worker.uid),
        ),
      ),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.outlineVariant.withValues(alpha: 0.15)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            // Avatar
            Stack(
              clipBehavior: Clip.none,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: worker.imageUrl.isNotEmpty
                      ? Image.network(
                          worker.imageUrl,
                          width: 72,
                          height: 72,
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) => _avatarFallback(),
                        )
                      : _avatarFallback(),
                ),
                if (worker.verified)
                  Positioned(
                    bottom: -4,
                    right: -4,
                    child: Container(
                      padding: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        color: AppColors.secondary,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                      child: const Icon(Icons.check, size: 10, color: Colors.white),
                    ),
                  ),
              ],
            ),
            const SizedBox(width: 14),
            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          worker.name,
                          style: AppTheme.headline(fontSize: 16),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppColors.amber500.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.star_rounded, size: 14, color: AppColors.amber500),
                            const SizedBox(width: 3),
                            Text(
                              worker.rating,
                              style: AppTheme.body(fontSize: 13, fontWeight: FontWeight.w700),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    worker.role,
                    style: AppTheme.body(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.primary),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: worker.tags
                        .map(
                          (tag) => Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: AppColors.blue50,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              tag,
                              style: AppTheme.label(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: AppColors.primary,
                              ),
                            ),
                          ),
                        )
                        .toList(),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 4),
            const Icon(Icons.chevron_right_rounded, size: 22, color: AppColors.outlineVariant),
          ],
        ),
      ),
    );
  }

  Widget _avatarFallback() {
    return Container(
      width: 72,
      height: 72,
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Center(
        child: Text(
          _getInitials(worker.name),
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
