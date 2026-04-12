import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/request_model.dart';
import '../services/database_service.dart';
import '../services/auth_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import 'add_request_screen.dart';

class _RequestFilter {
  String? status;

  bool get isActive => status != null;

  void clear() {
    status = null;
  }
}

class RequestsScreen extends StatefulWidget {
  final int initialTab;
  final bool standalone;

  const RequestsScreen({
    super.key,
    this.initialTab = 0,
    this.standalone = false,
  });

  @override
  State<RequestsScreen> createState() => _RequestsScreenState();
}

class _RequestsScreenState extends State<RequestsScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  late final DatabaseService _db;
  late final AuthService _auth;
  final TextEditingController _searchController = TextEditingController();
  String _query = '';
  final _RequestFilter _filter = _RequestFilter();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 2,
      vsync: this,
      initialIndex: widget.initialTab,
    );
    _db = context.read<DatabaseService>();
    _auth = context.read<AuthService>();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  bool _isEffectivelyOpen(RequestModel r) {
    final s = r.status.toLowerCase();
    return s == 'open' || s == 'finding' || s == 'assigned' || s == 'on way';
  }

  List<RequestModel> _applyFilters(List<RequestModel> all) {
    var list = all;
    if (_query.isNotEmpty) {
      final q = _query.toLowerCase();
      list = list
          .where(
            (r) =>
                r.category.toLowerCase().contains(q) ||
                r.description.toLowerCase().contains(q) ||
                r.location.toLowerCase().contains(q),
          )
          .toList();
    }
    if (_filter.status != null) {
      final wantOpen = _filter.status == 'Open';
      list = list.where((r) => _isEffectivelyOpen(r) == wantOpen).toList();
    }
    return list;
  }

  void _showFilterSheet() async {
    final result = await showModalBottomSheet<_RequestFilter>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _FilterSheet(current: _filter),
    );
    if (result != null && mounted) {
      setState(() {
        _filter.status = result.status;
      });
    }
  }

  void _editRequest(RequestModel r) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => AddRequestScreen(requestToEdit: r)),
    );
  }

  void _deleteRequest(RequestModel r) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Delete Request?'),
        content: const Text('This will permanently remove your request.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await _db.deleteRequest(r.id);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  Future<void> _closeRequest(RequestModel r) async {
    await _db.updateRequest(r.copyWith(status: 'Closed'));
  }

  Future<void> _reopenRequest(RequestModel r) async {
    await _db.updateRequest(r.copyWith(status: 'Open'));
  }

  Widget _buildBody(String userId) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header row
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  'Requests',
                  style: AppTheme.headline(
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (_filter.isActive)
                GestureDetector(
                  onTap: () => setState(() => _filter.clear()),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.tertiary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.close, size: 14, color: AppColors.tertiary),
                        const SizedBox(width: 4),
                        Text(
                          'Clear',
                          style: AppTheme.body(
                            fontSize: 12,
                            color: AppColors.tertiary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        // Search + Filter row
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            children: [
              Expanded(
                child: Container(
                  height: 46,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: AppColors.outlineVariant.withValues(alpha: 0.4),
                    ),
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
                      const SizedBox(width: 14),
                      const Icon(
                        Icons.search_rounded,
                        color: AppColors.outline,
                        size: 20,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextField(
                          controller: _searchController,
                          style: AppTheme.body(fontSize: 15),
                          decoration: InputDecoration(
                            hintText: 'Search requests...',
                            hintStyle: AppTheme.body(
                              fontSize: 14,
                              color: AppColors.outline,
                            ),
                            border: InputBorder.none,
                          ),
                          onChanged: (v) =>
                              setState(() => _query = v.trim().toLowerCase()),
                        ),
                      ),
                      if (_query.isNotEmpty)
                        GestureDetector(
                          onTap: () {
                            _searchController.clear();
                            setState(() => _query = '');
                          },
                          child: const Padding(
                            padding: EdgeInsets.all(10),
                            child: Icon(
                              Icons.close,
                              color: AppColors.outline,
                              size: 18,
                            ),
                          ),
                        )
                      else
                        const SizedBox(width: 14),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 10),
              GestureDetector(
                onTap: _showFilterSheet,
                child: Container(
                  height: 46,
                  width: 46,
                  decoration: BoxDecoration(
                    color: _filter.isActive ? AppColors.tertiary : Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: _filter.isActive
                          ? AppColors.tertiary
                          : AppColors.outlineVariant.withValues(alpha: 0.4),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.03),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Icon(
                    Icons.tune_rounded,
                    size: 20,
                    color: _filter.isActive
                        ? Colors.white
                        : AppColors.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        // Tab bar
        _RequestTabBar(controller: _tabController),
        const SizedBox(height: 2),
        // Tab content
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              _RequestListView(
                stream: _db.getAllRequests(),
                filter: _applyFilters,
                isMyTab: false,
                currentUserId: userId,
                isEffectivelyOpen: _isEffectivelyOpen,
                onCall: (phone) async {
                  final uri = Uri.parse('tel:$phone');
                  if (await canLaunchUrl(uri)) launchUrl(uri);
                },
                onEdit: _editRequest,
                onClose: _closeRequest,
                onReopen: _reopenRequest,
                onDelete: _deleteRequest,
              ),
              _RequestListView(
                stream: _db.getUserRequests(userId),
                filter: _applyFilters,
                isMyTab: true,
                currentUserId: userId,
                isEffectivelyOpen: _isEffectivelyOpen,
                onCall: (phone) async {
                  final uri = Uri.parse('tel:$phone');
                  if (await canLaunchUrl(uri)) launchUrl(uri);
                },
                onEdit: _editRequest,
                onClose: _closeRequest,
                onReopen: _reopenRequest,
                onDelete: _deleteRequest,
              ),
            ],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = _auth.currentUser;
    if (user == null) {
      return const Center(child: Text('Please login to view requests.'));
    }

    final body = Stack(
      children: [
        _buildBody(user.uid),
        if (widget.standalone)
          Positioned(
            right: 16,
            bottom: 14,
            child: FloatingActionButton(
              heroTag: 'requests_fab',
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const AddRequestScreen()),
              ),
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              elevation: 3,
              child: const Icon(Icons.add_rounded, size: 24),
            ),
          ),
      ],
    );

    if (widget.standalone) {
      return Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          title: Text(
            'My Requests',
            style: AppTheme.headline(fontSize: 20, fontWeight: FontWeight.w700),
          ),
          backgroundColor: Colors.transparent,
          elevation: 0,
          centerTitle: true,
          iconTheme: const IconThemeData(color: AppColors.onSurface),
        ),
        body: body,
      );
    }

    return body;
  }
}

// ── Custom Tab Bar ──────────────────────────────────────────────────────────

class _RequestTabBar extends StatelessWidget {
  final TabController controller;
  const _RequestTabBar({required this.controller});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final idx = controller.index;
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Container(
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.surfaceContainerHighest.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                _TabItem(
                  label: 'All Requests',
                  icon: Icons.list_alt_rounded,
                  selected: idx == 0,
                  activeColor: AppColors.tertiary,
                  onTap: () => controller.animateTo(0),
                ),
                _TabItem(
                  label: 'My Posts',
                  icon: Icons.person_rounded,
                  selected: idx == 1,
                  activeColor: AppColors.primary,
                  onTap: () => controller.animateTo(1),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _TabItem extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final Color activeColor;
  final VoidCallback onTap;

  const _TabItem({
    required this.label,
    required this.icon,
    required this.selected,
    required this.activeColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          margin: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: selected ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.06),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 16,
                color: selected ? activeColor : AppColors.outline,
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: AppTheme.body(
                  fontSize: 13,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  color: selected ? activeColor : AppColors.outline,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── List View ───────────────────────────────────────────────────────────────

class _RequestListView extends StatelessWidget {
  final Stream<List<RequestModel>> stream;
  final List<RequestModel> Function(List<RequestModel>) filter;
  final bool isMyTab;
  final String currentUserId;
  final bool Function(RequestModel) isEffectivelyOpen;
  final void Function(String phone) onCall;
  final void Function(RequestModel) onEdit;
  final void Function(RequestModel) onClose;
  final void Function(RequestModel) onReopen;
  final void Function(RequestModel) onDelete;

  const _RequestListView({
    required this.stream,
    required this.filter,
    required this.isMyTab,
    required this.currentUserId,
    required this.isEffectivelyOpen,
    required this.onCall,
    required this.onEdit,
    required this.onClose,
    required this.onReopen,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<RequestModel>>(
      stream: stream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }
        final filtered = filter(snapshot.data ?? []);
        if (filtered.isEmpty) {
          return _EmptyState(isMyTab: isMyTab);
        }
        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(20, 6, 20, 96),
          itemCount: filtered.length,
          itemBuilder: (_, i) {
            final r = filtered[i];
            final isOwner = r.userId == currentUserId;
            return _RequestCard(
              request: r,
              isOpen: isEffectivelyOpen(r),
              showCallButton: !isMyTab && r.phone.isNotEmpty,
              showMyActions: isMyTab && isOwner,
              onCall: () => onCall(r.phone),
              onEdit: () => onEdit(r),
              onClose: () => onClose(r),
              onReopen: () => onReopen(r),
              onDelete: () => onDelete(r),
            );
          },
        );
      },
    );
  }
}

// ── Request Card ────────────────────────────────────────────────────────────

class _RequestCard extends StatelessWidget {
  final RequestModel request;
  final bool isOpen;
  final bool showCallButton;
  final bool showMyActions;
  final VoidCallback onCall;
  final VoidCallback onEdit;
  final VoidCallback onClose;
  final VoidCallback onReopen;
  final VoidCallback onDelete;

  const _RequestCard({
    required this.request,
    required this.isOpen,
    required this.showCallButton,
    required this.showMyActions,
    required this.onCall,
    required this.onEdit,
    required this.onClose,
    required this.onReopen,
    required this.onDelete,
  });

  static const _palette = [
    Color(0xFF1565C0),
    Color(0xFF2E7D32),
    Color(0xFF6A1B9A),
    Color(0xFF00838F),
    Color(0xFFE65100),
    Color(0xFF37474F),
    Color(0xFFC62828),
    Color(0xFF4527A0),
    Color(0xFF00695C),
    Color(0xFF558B2F),
  ];

  Color _categoryColor() {
    if (request.category.isEmpty) return AppColors.primary;
    final hash = request.category.codeUnits.fold(0, (acc, c) => acc + c);
    return _palette[hash % _palette.length];
  }

  @override
  Widget build(BuildContext context) {
    final color = _categoryColor();
    final dateStr = DateFormat(
      'MMM d, h:mm a',
    ).format(request.createdAt ?? DateTime.now());

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Left accent strip
              Container(width: 4, color: color),
              // Card content
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ── Header row ──
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 46,
                            height: 46,
                            decoration: BoxDecoration(
                              color: color.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(13),
                            ),
                            child: Center(
                              child: Text(
                                request.category.isNotEmpty
                                    ? request.category.trim()[0].toUpperCase()
                                    : '?',
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w800,
                                  color: color,
                                  height: 1,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _toTitleCase(request.category),
                                  style: AppTheme.headline(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    Icon(
                                      Icons.calendar_today_outlined,
                                      size: 11,
                                      color: AppColors.outline,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      dateStr,
                                      style: AppTheme.body(
                                        fontSize: 11,
                                        color: AppColors.outline,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          // Status pill
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 5,
                            ),
                            decoration: BoxDecoration(
                              color: isOpen
                                  ? const Color(0xFFE8F5E9)
                                  : AppColors.surfaceContainerHighest,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 6,
                                  height: 6,
                                  decoration: BoxDecoration(
                                    color: isOpen
                                        ? const Color(0xFF2E7D32)
                                        : AppColors.outline,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 5),
                                Text(
                                  isOpen ? 'Open' : 'Closed',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: isOpen
                                        ? const Color(0xFF2E7D32)
                                        : AppColors.outline,
                                    letterSpacing: 0.1,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      // ── Location ──
                      if (request.location.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Icon(
                              Icons.location_on_outlined,
                              size: 13,
                              color: AppColors.outline,
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                request.location,
                                style: AppTheme.body(
                                  fontSize: 12,
                                  color: AppColors.onSurfaceVariant,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ],
                      // ── Description ──
                      if (request.description.isNotEmpty) ...[
                        const SizedBox(height: 10),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.surfaceContainerHighest.withValues(
                              alpha: 0.45,
                            ),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            request.description,
                            style: AppTheme.body(
                              fontSize: 13,
                              color: AppColors.onSurfaceVariant,
                              height: 1.45,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                      // ── Photo preview ──
                      if (request.photoUrl != null &&
                          request.photoUrl!.isNotEmpty) ...[
                        const SizedBox(height: 10),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.network(
                            request.photoUrl!,
                            height: 140,
                            width: double.infinity,
                            fit: BoxFit.cover,
                            errorBuilder: (_, _, _) => const SizedBox.shrink(),
                          ),
                        ),
                      ],
                      // ── Footer ──
                      const SizedBox(height: 12),
                      if (showCallButton && !showMyActions)
                        SizedBox(
                          width: double.infinity,
                          child: GestureDetector(
                            onTap: onCall,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 18,
                                vertical: 11,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.primary,
                                borderRadius: BorderRadius.circular(12),
                                boxShadow: [
                                  BoxShadow(
                                    color: AppColors.primary.withValues(
                                      alpha: 0.22,
                                    ),
                                    blurRadius: 8,
                                    offset: const Offset(0, 3),
                                  ),
                                ],
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(
                                    Icons.call_rounded,
                                    size: 15,
                                    color: Colors.white,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    'Call',
                                    style: AppTheme.body(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.white,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      if (showMyActions)
                        Row(
                          children: [
                            const Spacer(),
                            _ActionBtn(
                              icon: Icons.edit_outlined,
                              label: 'Edit',
                              color: AppColors.primary,
                              onTap: onEdit,
                              outlined: true,
                            ),
                            if (isOpen) ...[
                              const SizedBox(width: 6),
                              _ActionBtn(
                                icon: Icons.check_circle_outline,
                                label: 'Close',
                                color: AppColors.outline,
                                onTap: onClose,
                                outlined: true,
                              ),
                            ] else ...[
                              const SizedBox(width: 6),
                              _ActionBtn(
                                icon: Icons.refresh_rounded,
                                label: 'Reopen',
                                color: AppColors.secondary,
                                onTap: onReopen,
                                outlined: true,
                              ),
                            ],
                            const SizedBox(width: 6),
                            _ActionBtn(
                              icon: Icons.delete_outline,
                              label: '',
                              color: AppColors.error,
                              onTap: onDelete,
                              outlined: true,
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _toTitleCase(String text) {
    if (text.isEmpty) return text;
    return text
        .split(' ')
        .map((w) {
          if (w.isEmpty) return w;
          return w[0].toUpperCase() + w.substring(1).toLowerCase();
        })
        .join(' ');
  }
}

// ── Helper Widgets ──────────────────────────────────────────────────────────

class _ActionBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  final bool outlined;

  const _ActionBtn({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
    this.outlined = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: outlined ? Colors.transparent : color,
          borderRadius: BorderRadius.circular(9),
          border: Border.all(
            color: color.withValues(alpha: outlined ? 0.5 : 1),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: outlined ? color : Colors.white),
            const SizedBox(width: 4),
            Text(
              label,
              style: AppTheme.body(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: outlined ? color : Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Empty State ─────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  final bool isMyTab;
  const _EmptyState({required this.isMyTab});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: AppColors.tertiary.withValues(alpha: 0.08),
              shape: BoxShape.circle,
            ),
            child: Icon(
              isMyTab ? Icons.post_add_rounded : Icons.search_off_rounded,
              size: 36,
              color: AppColors.tertiary.withValues(alpha: 0.5),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            isMyTab ? 'No posts yet' : 'No requests found',
            style: AppTheme.body(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppColors.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            isMyTab
                ? 'Tap "Post Request" to share what you need'
                : 'Be the first to post a service request',
            style: AppTheme.body(fontSize: 13, color: AppColors.outline),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

// ── Filter Sheet ────────────────────────────────────────────────────────────

class _FilterSheet extends StatefulWidget {
  final _RequestFilter current;
  const _FilterSheet({required this.current});

  @override
  State<_FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends State<_FilterSheet> {
  String? _status;

  @override
  void initState() {
    super.initState();
    _status = widget.current.status;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
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
              Text(
                'Filter Requests',
                style: AppTheme.headline(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'STATUS',
                style: AppTheme.label(
                  color: AppColors.onSurfaceVariant,
                  letterSpacing: 1.5,
                ),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                children: ['Open', 'Closed'].map((s) {
                  final selected = _status == s;
                  return GestureDetector(
                    onTap: () => setState(() => _status = selected ? null : s),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: selected
                            ? AppColors.tertiary
                            : AppColors.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        s,
                        style: AppTheme.body(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: selected
                              ? Colors.white
                              : AppColors.onSurfaceVariant,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 28),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    final result = _RequestFilter()..status = _status;
                    Navigator.pop(context, result);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.tertiary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    elevation: 0,
                  ),
                  child: Text(
                    'Apply Filters',
                    style: AppTheme.body(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
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
