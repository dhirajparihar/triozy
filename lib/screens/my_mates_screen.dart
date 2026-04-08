import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import '../models/mate_model.dart';
import '../services/database_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import 'add_mate_screen.dart';

class MyMatesScreen extends StatelessWidget {
  const MyMatesScreen({super.key});

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

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    final db = context.read<DatabaseService>();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: AppColors.onSurface),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'My Mate Posts',
          style: AppTheme.headline(fontSize: 20, fontWeight: FontWeight.w800),
        ),
      ),
      body: uid == null
          ? const Center(child: Text('Not signed in'))
          : StreamBuilder<List<MateModel>>(
              stream: db.streamMyMates(uid),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(
                      color: AppColors.primary,
                      strokeWidth: 2,
                    ),
                  );
                }

                final all = snapshot.data ?? [];

                if (all.isEmpty) {
                  return _EmptyState(
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const AddMateScreen(),
                      ),
                    ),
                  );
                }

                // Group by type
                final grouped = <MateType, List<MateModel>>{};
                for (final type in MateType.values) {
                  final items = all.where((m) => m.type == type).toList();
                  if (items.isNotEmpty) grouped[type] = items;
                }

                return ListView(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
                  children: [
                    for (final entry in grouped.entries) ...[
                      _SectionHeader(
                        type: entry.key,
                        color: _typeColors[entry.key]!,
                        icon: _typeIcons[entry.key]!,
                        count: entry.value.length,
                      ),
                      const SizedBox(height: 10),
                      for (final mate in entry.value)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: _MyMateCard(
                            mate: mate,
                            accentColor: _typeColors[mate.type]!,
                            onDelete: () => _confirmDelete(context, mate, db),
                            onEdit: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => AddMateScreen(mateToEdit: mate),
                              ),
                            ),
                          ),
                        ),
                      const SizedBox(height: 16),
                    ],
                  ],
                );
              },
            ),
    );
  }

  Future<void> _confirmDelete(
    BuildContext context,
    MateModel mate,
    DatabaseService db,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Delete Listing?',
          style: AppTheme.headline(fontSize: 18),
        ),
        content: Text(
          'This will permanently remove your ${mate.type.label} post. This cannot be undone.',
          style: AppTheme.body(fontSize: 14, color: AppColors.slate500, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              'Cancel',
              style: AppTheme.body(fontWeight: FontWeight.w600, color: AppColors.slate500),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      try {
        await db.deleteMate(mate.id);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${mate.type.label} post deleted'),
              backgroundColor: AppColors.secondary,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to delete: $e'),
              backgroundColor: AppColors.error,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          );
        }
      }
    }
  }
}

// ── Section Header ─────────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final MateType type;
  final Color color;
  final IconData icon;
  final int count;

  const _SectionHeader({
    required this.type,
    required this.color,
    required this.icon,
    required this.count,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: 16, color: color),
        ),
        const SizedBox(width: 10),
        Text(
          type.label,
          style: AppTheme.body(fontSize: 15, fontWeight: FontWeight.w700, color: color),
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            '$count',
            style: AppTheme.label(fontSize: 12, color: color),
          ),
        ),
      ],
    );
  }
}

// ── My Mate Card ───────────────────────────────────────────────────────────────

class _MyMateCard extends StatelessWidget {
  final MateModel mate;
  final Color accentColor;
  final VoidCallback onDelete;
  final VoidCallback onEdit;

  const _MyMateCard({
    required this.mate,
    required this.accentColor,
    required this.onDelete,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Top row: meta + actions ──────────────
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: accentColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(_typeIcon(mate.type), size: 12, color: accentColor),
                      const SizedBox(width: 4),
                      Text(
                        mate.type.label,
                        style: AppTheme.label(fontSize: 11, color: accentColor),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                _TimeStamp(createdAt: mate.createdAt),
                const SizedBox(width: 4),
                // Edit
                GestureDetector(
                  onTap: onEdit,
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: accentColor.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      Icons.edit_rounded,
                      size: 16,
                      color: accentColor,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                // Delete
                GestureDetector(
                  onTap: onDelete,
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.error.withValues(alpha: 0.07),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.delete_outline_rounded,
                      size: 16,
                      color: AppColors.error,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // ── Summary ──────────────────────────────
            _buildSummary(),
            // ── Location ─────────────────────────────
            if (mate.location.isNotEmpty) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.location_on_rounded, size: 13, color: AppColors.slate400),
                  const SizedBox(width: 4),
                  Flexible(
                    child: Text(
                      mate.location,
                      style: AppTheme.label(fontSize: 12),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ],
            // ── Description ──────────────────────────
            if (mate.description.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                mate.description,
                style: AppTheme.body(fontSize: 13, color: AppColors.slate500, height: 1.4),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSummary() {
    switch (mate.type) {
      case MateType.roommate:
        return Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            if (mate.budget != null)
              _Chip(Icons.currency_rupee_rounded, mate.budget!, accentColor),
            if (mate.preferredGender != null)
              _Chip(Icons.person_rounded, mate.preferredGender!, accentColor),
            ...mate.lifestyle.take(3).map((l) => _Chip(null, l, accentColor)),
          ],
        );
      case MateType.helpmate:
        return Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            _Chip(
              mate.available ? Icons.check_circle_rounded : Icons.cancel_rounded,
              mate.available ? 'Available' : 'Unavailable',
              mate.available ? AppColors.secondary : AppColors.slate400,
            ),
            ...mate.helpTypes.take(3).map((h) => _Chip(null, h, accentColor)),
          ],
        );
      case MateType.ridemate:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (mate.fromLocation != null && mate.toLocation != null)
              Row(
                children: [
                  Icon(Icons.trip_origin_rounded, size: 13, color: AppColors.secondary),
                  const SizedBox(width: 4),
                  Flexible(
                    child: Text(
                      '${mate.fromLocation} → ${mate.toLocation}',
                      style: AppTheme.body(fontSize: 13, fontWeight: FontWeight.w600),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                if (mate.departureTime != null)
                  _Chip(Icons.schedule_rounded, mate.departureTime!, accentColor),
                if (mate.frequency != null)
                  _Chip(Icons.repeat_rounded, mate.frequency!, accentColor),
                if (mate.vehicleType != null)
                  _Chip(Icons.two_wheeler_rounded, mate.vehicleType!, accentColor),
              ],
            ),
          ],
        );
    }
  }

  IconData _typeIcon(MateType type) {
    switch (type) {
      case MateType.roommate: return Icons.people_alt_rounded;
      case MateType.helpmate: return Icons.handshake_rounded;
      case MateType.ridemate: return Icons.directions_bike_rounded;
    }
  }
}

class _Chip extends StatelessWidget {
  final IconData? icon;
  final String label;
  final Color color;
  const _Chip(this.icon, this.label, this.color);

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
          if (icon != null) ...[
            Icon(icon, size: 11, color: color),
            const SizedBox(width: 4),
          ],
          Text(label, style: AppTheme.label(fontSize: 12, color: color)),
        ],
      ),
    );
  }
}

class _TimeStamp extends StatelessWidget {
  final DateTime? createdAt;
  const _TimeStamp({required this.createdAt});

  String _format(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${dt.day}/${dt.month}/${dt.year}';
  }

  @override
  Widget build(BuildContext context) {
    if (createdAt == null) return const SizedBox.shrink();
    return Text(
      _format(createdAt!),
      style: AppTheme.label(fontSize: 11, color: AppColors.slate400),
    );
  }
}

// ── Empty State ────────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  final VoidCallback onTap;
  const _EmptyState({required this.onTap});

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
                color: AppColors.primary.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.people_alt_rounded,
                size: 36,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              "You haven't posted any mates yet.",
              textAlign: TextAlign.center,
              style: AppTheme.body(fontSize: 15, color: AppColors.slate500, height: 1.6),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: onTap,
              icon: const Icon(Icons.add_rounded, size: 18),
              label: Text(
                'Post Your First Mate',
                style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
