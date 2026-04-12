import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/mate_model.dart';
import '../services/database_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import 'add_mate_screen.dart';

// ── Per-tab filter state ───────────────────────────────────────────────────────

class _MateFilter {
  String? gender; // Roommate
  bool availableOnly; // Helpmate
  List<String> helpTypes; // Helpmate
  String? vehicleType; // Ridemate
  String? frequency; // Ridemate

  _MateFilter({
    this.gender,
    this.availableOnly = false,
    List<String>? helpTypes,
    this.vehicleType,
    this.frequency,
  }) : helpTypes = helpTypes ?? [];

  bool get isActive =>
      gender != null ||
      availableOnly ||
      helpTypes.isNotEmpty ||
      vehicleType != null ||
      frequency != null;

  _MateFilter copyWith({
    Object? gender = _sentinel,
    bool? availableOnly,
    List<String>? helpTypes,
    Object? vehicleType = _sentinel,
    Object? frequency = _sentinel,
  }) {
    return _MateFilter(
      gender: gender == _sentinel ? this.gender : gender as String?,
      availableOnly: availableOnly ?? this.availableOnly,
      helpTypes: helpTypes ?? List.from(this.helpTypes),
      vehicleType: vehicleType == _sentinel
          ? this.vehicleType
          : vehicleType as String?,
      frequency: frequency == _sentinel ? this.frequency : frequency as String?,
    );
  }

  void clear() {
    gender = null;
    availableOnly = false;
    helpTypes.clear();
    vehicleType = null;
    frequency = null;
  }
}

const _sentinel = Object();

// ── Screen ─────────────────────────────────────────────────────────────────────

class MateScreen extends StatefulWidget {
  const MateScreen({super.key});

  @override
  State<MateScreen> createState() => _MateScreenState();
}

class _MateScreenState extends State<MateScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  final _searchCtrl = TextEditingController();
  String _searchQuery = '';
  late final Map<MateType, _MateFilter> _filters = {
    MateType.roommate: _MateFilter(),
    MateType.helpmate: _MateFilter(),
    MateType.ridemate: _MateFilter(),
  };

  static const _tabs = [
    MateType.roommate,
    MateType.helpmate,
    MateType.ridemate,
  ];

  static const _tabColors = [
    AppColors.primary,
    AppColors.secondary,
    AppColors.tertiary,
  ];

  static const _tabIcons = [
    Icons.people_alt_rounded,
    Icons.handshake_rounded,
    Icons.directions_bike_rounded,
  ];

  static const _emptyMessages = [
    'No roommates listed yet.\nBe the first to post!',
    'No helpmates nearby yet.\nOffer help to your community!',
    'No ridematch posts yet.\nShare your commute route!',
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  int get _activeFilterCount =>
      _filters[_tabs[_tabController.index]]!.isActive ? 1 : 0;

  void _showFilterSheet() {
    final type = _tabs[_tabController.index];
    final color = _tabColors[_tabController.index];
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _FilterSheet(
        type: type,
        filter: _filters[type]!,
        accentColor: color,
        onChanged: (updated) => setState(() => _filters[type] = updated),
        onClear: () => setState(() => _filters[type]!.clear()),
      ),
    );
  }

  void _openAddMate() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AddMateScreen(initialType: _tabs[_tabController.index]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 2),
          // ── Header ──────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 2, 20, 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Find Your Match', style: AppTheme.headline(fontSize: 26)),
                const SizedBox(height: 2),
                Text(
                  'Roommate, helpmate or ride partner nearby',
                  style: AppTheme.body(fontSize: 13, color: AppColors.slate500),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          // ── Custom Tab Bar ───────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: _MateTabBar(
              controller: _tabController,
              tabs: _tabs,
              colors: _tabColors,
              icons: _tabIcons,
            ),
          ),
          const SizedBox(height: 8),
          // ── Search + Filter Bar ──────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    height: 44,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(18),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.04),
                          blurRadius: 12,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: TextField(
                      controller: _searchCtrl,
                      onChanged: (v) => setState(() => _searchQuery = v),
                      style: AppTheme.body(fontSize: 14),
                      decoration: InputDecoration(
                        hintText: 'Search people or location',
                        hintStyle: AppTheme.body(
                          fontSize: 13,
                          color: AppColors.slate400,
                        ),
                        prefixIcon: const Icon(
                          Icons.search_rounded,
                          size: 18,
                          color: AppColors.slate400,
                        ),
                        suffixIcon: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (_searchQuery.isNotEmpty)
                              GestureDetector(
                                onTap: () => setState(() {
                                  _searchCtrl.clear();
                                  _searchQuery = '';
                                }),
                                child: const Icon(
                                  Icons.close_rounded,
                                  size: 16,
                                  color: AppColors.slate400,
                                ),
                              ),
                            const SizedBox(width: 8),
                            GestureDetector(
                              onTap: _showFilterSheet,
                              child: Container(
                                width: 28,
                                height: 28,
                                decoration: BoxDecoration(
                                  color: _activeFilterCount > 0
                                      ? _tabColors[_tabController.index]
                                            .withValues(alpha: 0.12)
                                      : AppColors.surfaceContainerLow,
                                  borderRadius: BorderRadius.circular(9),
                                ),
                                child: Icon(
                                  Icons.tune_rounded,
                                  size: 16,
                                  color: _activeFilterCount > 0
                                      ? _tabColors[_tabController.index]
                                      : AppColors.slate400,
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                          ],
                        ),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(vertical: 10),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          // ── Tab Views ───────────────────────────────
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: List.generate(3, (i) {
                return _MateListView(
                  type: _tabs[i],
                  accentColor: _tabColors[i],
                  emptyMessage: _emptyMessages[i],
                  searchQuery: _searchQuery,
                  filter: _filters[_tabs[i]]!,
                  onAddTap: _openAddMate,
                );
              }),
            ),
          ),
        ],
      ),
      floatingActionButton: DecoratedBox(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AppColors.primaryContainer,
              AppColors.primary,
            ],
          ),
          borderRadius: BorderRadius.circular(999),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withValues(alpha: 0.28),
              blurRadius: 14,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: FloatingActionButton(
          onPressed: _openAddMate,
          backgroundColor: Colors.transparent,
          foregroundColor: Colors.white,
          elevation: 0,
          child: const Icon(Icons.add_rounded, size: 22),
        ),
      ),
    );
  }
}

// ── Custom Tab Bar ─────────────────────────────────────────────────────────────

class _MateTabBar extends StatelessWidget {
  final TabController controller;
  final List<MateType> tabs;
  final List<Color> colors;
  final List<IconData> icons;

  const _MateTabBar({
    required this.controller,
    required this.tabs,
    required this.colors,
    required this.icons,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 50,
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(18),
      ),
      child: TabBar(
        controller: controller,
        padding: const EdgeInsets.all(4),
        indicator: BoxDecoration(
          color: colors[controller.index],
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: colors[controller.index].withValues(alpha: 0.25),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        indicatorSize: TabBarIndicatorSize.tab,
        dividerColor: Colors.transparent,
        labelPadding: EdgeInsets.zero,
        tabs: List.generate(tabs.length, (i) {
          final isSelected = controller.index == i;
          return Tab(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      icons[i],
                      size: 16,
                      color: isSelected ? Colors.white : AppColors.slate400,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      tabs[i].label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: isSelected ? Colors.white : AppColors.slate400,
                      ),
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

// ── List View per tab ──────────────────────────────────────────────────────────

class _MateListView extends StatelessWidget {
  final MateType type;
  final Color accentColor;
  final String emptyMessage;
  final String searchQuery;
  final _MateFilter filter;
  final VoidCallback onAddTap;

  const _MateListView({
    required this.type,
    required this.accentColor,
    required this.emptyMessage,
    required this.searchQuery,
    required this.filter,
    required this.onAddTap,
  });

  List<MateModel> _apply(List<MateModel> all) {
    var result = all;

    // Text search
    if (searchQuery.isNotEmpty) {
      final q = searchQuery.toLowerCase();
      result = result.where((m) {
        return m.userName.toLowerCase().contains(q) ||
            m.location.toLowerCase().contains(q) ||
            m.description.toLowerCase().contains(q) ||
            (m.fromLocation?.toLowerCase().contains(q) ?? false) ||
            (m.toLocation?.toLowerCase().contains(q) ?? false) ||
            m.helpTypes.any((h) => h.toLowerCase().contains(q)) ||
            m.lifestyle.any((l) => l.toLowerCase().contains(q));
      }).toList();
    }

    // Roommate filters
    if (filter.gender != null && filter.gender != 'Any') {
      result = result.where((m) => m.preferredGender == filter.gender).toList();
    }

    // Helpmate filters
    if (filter.availableOnly) {
      result = result.where((m) => m.available).toList();
    }
    if (filter.helpTypes.isNotEmpty) {
      result = result
          .where((m) => filter.helpTypes.any((h) => m.helpTypes.contains(h)))
          .toList();
    }

    // Ridemate filters
    if (filter.vehicleType != null) {
      result = result
          .where((m) => m.vehicleType == filter.vehicleType)
          .toList();
    }
    if (filter.frequency != null) {
      result = result.where((m) => m.frequency == filter.frequency).toList();
    }

    return result;
  }

  @override
  Widget build(BuildContext context) {
    final db = context.read<DatabaseService>();

    return StreamBuilder<List<MateModel>>(
      stream: db.streamMates(type),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(
            child: CircularProgressIndicator(
              color: accentColor,
              strokeWidth: 2,
            ),
          );
        }
        if (snapshot.hasError) {
          return Center(
            child: Text(
              'Something went wrong',
              style: AppTheme.body(color: AppColors.outline),
            ),
          );
        }

        final filtered = _apply(snapshot.data ?? []);

        if ((snapshot.data ?? []).isEmpty) {
          return _EmptyState(
            message: emptyMessage,
            accentColor: accentColor,
            onTap: onAddTap,
          );
        }

        if (filtered.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.search_off_rounded,
                  size: 40,
                  color: AppColors.slate400,
                ),
                const SizedBox(height: 12),
                Text(
                  'No results match your search\nor filters.',
                  textAlign: TextAlign.center,
                  style: AppTheme.body(
                    fontSize: 14,
                    color: AppColors.slate500,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 96),
          itemCount: filtered.length,
          separatorBuilder: (context, i) => const SizedBox(height: 12),
          itemBuilder: (context, i) =>
              _MateCard(mate: filtered[i], accentColor: accentColor),
        );
      },
    );
  }
}

// ── Empty State ────────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  final String message;
  final Color accentColor;
  final VoidCallback onTap;

  const _EmptyState({
    required this.message,
    required this.accentColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: accentColor.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.group_add_rounded,
                size: 36,
                color: accentColor,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              message,
              textAlign: TextAlign.center,
              style: AppTheme.body(
                fontSize: 15,
                color: AppColors.slate500,
                height: 1.6,
              ),
            ),
            const SizedBox(height: 24),
            TextButton.icon(
              onPressed: onTap,
              icon: Icon(Icons.add_rounded, size: 18, color: accentColor),
              label: Text(
                'Post Now',
                style: AppTheme.body(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: accentColor,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Mate Card ─────────────────────────────────────────────────────────────────

class _MateCard extends StatelessWidget {
  final MateModel mate;
  final Color accentColor;

  const _MateCard({required this.mate, required this.accentColor});

  Future<void> _call(BuildContext context) async {
    if (mate.phone.isEmpty) return;
    final uri = Uri(scheme: 'tel', path: mate.phone);
    if (await canLaunchUrl(uri)) await launchUrl(uri);
  }

  bool get _isOwn => FirebaseAuth.instance.currentUser?.uid == mate.userId;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: AppColors.outlineVariant.withValues(alpha: 0.18),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── User row ──────────────────────────────
            Row(
              children: [
                _Avatar(
                  photoUrl: mate.userPhoto,
                  name: mate.userName,
                  size: 48,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              mate.userName,
                              style: AppTheme.body(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (_isOwn) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: accentColor.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                'You',
                                style: AppTheme.label(
                                  fontSize: 10,
                                  color: accentColor,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      if (mate.location.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            Icon(
                              Icons.location_on_rounded,
                              size: 12,
                              color: AppColors.slate400,
                            ),
                            const SizedBox(width: 3),
                            Flexible(
                              child: Text(
                                mate.location,
                                style: AppTheme.label(
                                  fontSize: 12,
                                  color: AppColors.slate500,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                // Type badge
                _TypeBadge(type: mate.type, color: accentColor),
              ],
            ),
            // ── Type-specific content ──────────────────
            const SizedBox(height: 14),
            _buildTypeContent(context),
            // ── Description ───────────────────────────
            if (mate.description.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(
                mate.description,
                style: AppTheme.body(
                  fontSize: 13,
                  color: AppColors.slate500,
                  height: 1.5,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
            // ── Action ────────────────────────────────
            if (!_isOwn && mate.phone.isNotEmpty) ...[
              const SizedBox(height: 20),
              Builder(
                builder: (context) {
                  final isUnavailable =
                      mate.type == MateType.helpmate && !mate.available;
                  return SizedBox(
                    width: double.infinity,
                    child: TextButton.icon(
                      onPressed: isUnavailable ? null : () => _call(context),
                      icon: Icon(
                        isUnavailable
                            ? Icons.do_not_disturb_rounded
                            : Icons.phone_rounded,
                        size: 16,
                      ),
                      label: Text(
                        isUnavailable
                            ? 'Not Available'
                            : 'Call ${mate.userName.split(' ').first}',
                      ),
                      style: TextButton.styleFrom(
                        foregroundColor: isUnavailable
                            ? AppColors.slate400
                            : accentColor,
                        backgroundColor: isUnavailable
                            ? AppColors.surfaceContainerLow
                            : accentColor.withValues(alpha: 0.08),
                        disabledForegroundColor: AppColors.slate400,
                        disabledBackgroundColor: AppColors.surfaceContainerLow,
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        textStyle: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildTypeContent(BuildContext context) {
    switch (mate.type) {
      case MateType.roommate:
        return _RoommateContent(mate: mate, accentColor: accentColor);
      case MateType.helpmate:
        return _HelpmateContent(mate: mate, accentColor: accentColor);
      case MateType.ridemate:
        return _RidemateContent(mate: mate, accentColor: accentColor);
    }
  }
}

// ── Roommate content ──────────────────────────────────────────────────────────

class _RoommateContent extends StatelessWidget {
  final MateModel mate;
  final Color accentColor;
  const _RoommateContent({required this.mate, required this.accentColor});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            if (mate.budget != null)
              _InfoChip(
                icon: Icons.currency_rupee_rounded,
                label: mate.budget!,
                color: accentColor,
              ),
            if (mate.preferredGender != null)
              _InfoChip(
                icon: Icons.person_rounded,
                label: mate.preferredGender!,
                color: accentColor,
              ),
          ],
        ),
        if (mate.lifestyle.isNotEmpty) ...[
          const SizedBox(height: 8),
          _ChipRow(tags: mate.lifestyle, color: accentColor),
        ],
      ],
    );
  }
}

// ── Helpmate content ──────────────────────────────────────────────────────────

class _HelpmateContent extends StatelessWidget {
  final MateModel mate;
  final Color accentColor;
  const _HelpmateContent({required this.mate, required this.accentColor});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: mate.available
                    ? AppColors.secondary.withValues(alpha: 0.1)
                    : AppColors.surfaceContainerLow,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 7,
                    height: 7,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: mate.available
                          ? AppColors.secondary
                          : AppColors.slate400,
                    ),
                  ),
                  const SizedBox(width: 5),
                  Text(
                    mate.available ? 'Available Now' : 'Not Available',
                    style: AppTheme.label(
                      fontSize: 12,
                      color: mate.available
                          ? AppColors.secondary
                          : AppColors.slate400,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        if (mate.helpTypes.isNotEmpty) ...[
          const SizedBox(height: 8),
          _ChipRow(tags: mate.helpTypes, color: accentColor),
        ],
      ],
    );
  }
}

// ── Ridemate content ──────────────────────────────────────────────────────────

class _RidemateContent extends StatelessWidget {
  final MateModel mate;
  final Color accentColor;
  const _RidemateContent({required this.mate, required this.accentColor});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Route row
        if (mate.fromLocation != null && mate.toLocation != null)
          Row(
            children: [
              Icon(
                Icons.trip_origin_rounded,
                size: 14,
                color: AppColors.secondary,
              ),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  mate.fromLocation!,
                  style: AppTheme.body(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: Icon(
                  Icons.arrow_forward_rounded,
                  size: 14,
                  color: AppColors.slate400,
                ),
              ),
              Icon(Icons.location_on_rounded, size: 14, color: AppColors.error),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  mate.toLocation!,
                  style: AppTheme.body(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            if (mate.departureTime != null)
              _InfoChip(
                icon: Icons.schedule_rounded,
                label: mate.departureTime!,
                color: accentColor,
              ),
            if (mate.frequency != null)
              _InfoChip(
                icon: Icons.repeat_rounded,
                label: mate.frequency!,
                color: accentColor,
              ),
            if (mate.vehicleType != null)
              _InfoChip(
                icon: Icons.two_wheeler_rounded,
                label: mate.vehicleType!,
                color: accentColor,
              ),
          ],
        ),
      ],
    );
  }
}

// ── Shared micro-widgets ───────────────────────────────────────────────────────

class _TypeBadge extends StatelessWidget {
  final MateType type;
  final Color color;
  const _TypeBadge({required this.type, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        type.label,
        style: AppTheme.label(
          fontSize: 11,
          color: color,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  const _InfoChip({
    required this.icon,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(label, style: AppTheme.label(fontSize: 12, color: color)),
        ],
      ),
    );
  }
}

class _ChipRow extends StatelessWidget {
  final List<String> tags;
  final Color color;
  const _ChipRow({required this.tags, required this.color});

  @override
  Widget build(BuildContext context) {
    final visible = tags.take(4).toList();
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        ...visible.map(
          (tag) => Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.surfaceContainerLow,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              tag,
              style: AppTheme.label(fontSize: 12, color: AppColors.slate500),
            ),
          ),
        ),
        if (tags.length > 4)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.surfaceContainerLow,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              '+${tags.length - 4}',
              style: AppTheme.label(fontSize: 12, color: AppColors.slate500),
            ),
          ),
      ],
    );
  }
}

class _Avatar extends StatelessWidget {
  final String photoUrl;
  final String name;
  final double size;
  const _Avatar({
    required this.photoUrl,
    required this.name,
    required this.size,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AppColors.surfaceContainerHigh,
      ),
      clipBehavior: Clip.antiAlias,
      child: photoUrl.isNotEmpty
          ? Image.network(
              photoUrl,
              fit: BoxFit.cover,
              errorBuilder: (ctx, err, stack) => _initials(name, size),
            )
          : _initials(name, size),
    );
  }

  Widget _initials(String name, double size) {
    final initials = name
        .trim()
        .split(' ')
        .take(2)
        .map((p) => p.isNotEmpty ? p[0].toUpperCase() : '')
        .join();
    return Center(
      child: Text(
        initials,
        style: GoogleFonts.inter(
          fontSize: size * 0.33,
          fontWeight: FontWeight.w700,
          color: AppColors.primary,
        ),
      ),
    );
  }
}

// ── Filter Bottom Sheet ────────────────────────────────────────────────────────

class _FilterSheet extends StatefulWidget {
  final MateType type;
  final _MateFilter filter;
  final Color accentColor;
  final ValueChanged<_MateFilter> onChanged;
  final VoidCallback onClear;

  const _FilterSheet({
    required this.type,
    required this.filter,
    required this.accentColor,
    required this.onChanged,
    required this.onClear,
  });

  @override
  State<_FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends State<_FilterSheet> {
  late _MateFilter _local;

  static const _genderOptions = ['Any', 'Male', 'Female'];
  static const _helpTypeOptions = [
    'Errands',
    'Emergency',
    'Medical',
    'Moving help',
    'Companionship',
    'Tech help',
    'Grocery',
    'Other',
  ];
  static const _vehicleOptions = ['Bike', 'Scooty', 'Car'];
  static const _frequencyOptions = ['Daily', 'Weekdays', 'Weekends', 'Once'];

  @override
  void initState() {
    super.initState();
    _local = widget.filter.copyWith();
  }

  void _apply() {
    widget.onChanged(_local);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Handle
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 12, bottom: 20),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.outlineVariant,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            child: Row(
              children: [
                Text('Filter', style: AppTheme.headline(fontSize: 20)),
                const Spacer(),
                if (_local.isActive)
                  TextButton(
                    onPressed: () => setState(() => _local.clear()),
                    child: Text(
                      'Clear all',
                      style: AppTheme.body(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.error,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          // Type-specific filters
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: _buildFilters(),
            ),
          ),
          // Apply button
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
            child: SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: _apply,
                style: ElevatedButton.styleFrom(
                  backgroundColor: widget.accentColor,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: Text(
                  'Apply Filters',
                  style: GoogleFonts.inter(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilters() {
    switch (widget.type) {
      case MateType.roommate:
        return _RoommateFilters(
          local: _local,
          genderOptions: _genderOptions,
          accentColor: widget.accentColor,
          onUpdate: (f) => setState(() => _local = f),
        );
      case MateType.helpmate:
        return _HelpmateFilters(
          local: _local,
          helpTypeOptions: _helpTypeOptions,
          accentColor: widget.accentColor,
          onUpdate: (f) => setState(() => _local = f),
        );
      case MateType.ridemate:
        return _RidemateFilters(
          local: _local,
          vehicleOptions: _vehicleOptions,
          frequencyOptions: _frequencyOptions,
          accentColor: widget.accentColor,
          onUpdate: (f) => setState(() => _local = f),
        );
    }
  }
}

// ── Filter sub-widgets ─────────────────────────────────────────────────────────

class _RoommateFilters extends StatelessWidget {
  final _MateFilter local;
  final List<String> genderOptions;
  final Color accentColor;
  final ValueChanged<_MateFilter> onUpdate;

  const _RoommateFilters({
    required this.local,
    required this.genderOptions,
    required this.accentColor,
    required this.onUpdate,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Preferred Gender',
          style: AppTheme.body(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: AppColors.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: genderOptions.map((g) {
            final selected =
                local.gender == g || (g == 'Any' && local.gender == null);
            return _FilterChip(
              label: g,
              selected: selected,
              accentColor: accentColor,
              onTap: () =>
                  onUpdate(local.copyWith(gender: g == 'Any' ? null : g)),
            );
          }).toList(),
        ),
        const SizedBox(height: 24),
      ],
    );
  }
}

class _HelpmateFilters extends StatelessWidget {
  final _MateFilter local;
  final List<String> helpTypeOptions;
  final Color accentColor;
  final ValueChanged<_MateFilter> onUpdate;

  const _HelpmateFilters({
    required this.local,
    required this.helpTypeOptions,
    required this.accentColor,
    required this.onUpdate,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Available now toggle
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: local.availableOnly
                      ? AppColors.secondary
                      : AppColors.slate400,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Available now only',
                  style: AppTheme.body(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Switch.adaptive(
                value: local.availableOnly,
                onChanged: (v) => onUpdate(local.copyWith(availableOnly: v)),
                activeThumbColor: Colors.white,
                activeTrackColor: AppColors.secondary,
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        Text(
          'Help Type',
          style: AppTheme.body(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: AppColors.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: helpTypeOptions.map((h) {
            final selected = local.helpTypes.contains(h);
            return _FilterChip(
              label: h,
              selected: selected,
              accentColor: accentColor,
              onTap: () {
                final updated = List<String>.from(local.helpTypes);
                selected ? updated.remove(h) : updated.add(h);
                onUpdate(local.copyWith(helpTypes: updated));
              },
            );
          }).toList(),
        ),
        const SizedBox(height: 24),
      ],
    );
  }
}

class _RidemateFilters extends StatelessWidget {
  final _MateFilter local;
  final List<String> vehicleOptions;
  final List<String> frequencyOptions;
  final Color accentColor;
  final ValueChanged<_MateFilter> onUpdate;

  const _RidemateFilters({
    required this.local,
    required this.vehicleOptions,
    required this.frequencyOptions,
    required this.accentColor,
    required this.onUpdate,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Vehicle',
          style: AppTheme.body(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: AppColors.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: vehicleOptions.map((v) {
            final selected = local.vehicleType == v;
            return _FilterChip(
              label: v,
              selected: selected,
              accentColor: accentColor,
              onTap: () =>
                  onUpdate(local.copyWith(vehicleType: selected ? null : v)),
            );
          }).toList(),
        ),
        const SizedBox(height: 20),
        Text(
          'Frequency',
          style: AppTheme.body(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: AppColors.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: frequencyOptions.map((f) {
            final selected = local.frequency == f;
            return _FilterChip(
              label: f,
              selected: selected,
              accentColor: accentColor,
              onTap: () =>
                  onUpdate(local.copyWith(frequency: selected ? null : f)),
            );
          }).toList(),
        ),
        const SizedBox(height: 24),
      ],
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final Color accentColor;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.selected,
    required this.accentColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? accentColor : Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected ? accentColor : AppColors.outlineVariant,
            width: 1.5,
          ),
        ),
        child: Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: selected ? Colors.white : AppColors.slate500,
          ),
        ),
      ),
    );
  }
}
