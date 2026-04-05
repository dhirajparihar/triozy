import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/job_model.dart';
import '../services/database_service.dart';
import '../services/auth_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import 'add_job_screen.dart';

class JobsScreen extends StatefulWidget {
  final bool showOnlyMyJobs;
  const JobsScreen({super.key, this.showOnlyMyJobs = false});

  @override
  State<JobsScreen> createState() => _JobsScreenState();
}

class _JobsScreenState extends State<JobsScreen> {
  late final DatabaseService _db;
  late final AuthService _auth;
  final TextEditingController _searchController = TextEditingController();
  String _query = ''; // ignore: prefer_final_fields

  @override
  void initState() {
    super.initState();
    _db = context.read<DatabaseService>();
    _auth = context.read<AuthService>();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<JobModel> _filterJobs(List<JobModel> jobs) {
    if (_query.isEmpty) return jobs;
    final q = _query.toLowerCase();
    return jobs.where((j) =>
      j.category.toLowerCase().contains(q) ||
      j.description.toLowerCase().contains(q) ||
      j.location.toLowerCase().contains(q) ||
      j.status.toLowerCase().contains(q),
    ).toList();
  }

  void _editJob(JobModel job) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => AddJobScreen(jobToEdit: job)),
    );
  }

  void _deleteJob(JobModel job) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Job?'),
        content: const Text('Are you sure you want to remove this job posting?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await _db.deleteJob(job.id);
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = _auth.currentUser;
    if (user == null) {
      return const Center(child: Text('Please login to view your jobs.'));
    }

    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Title
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
          child: Text(
            'Jobs',
            style: AppTheme.headline(fontSize: 24, fontWeight: FontWeight.w700, color: AppColors.primary),
          ),
        ),
        // Search bar — outside StreamBuilder so it never loses focus
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 4, 24, 8),
          child: Container(
            height: 48,
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
                const SizedBox(width: 14),
                const Icon(Icons.search_rounded, color: AppColors.outline, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    style: AppTheme.body(fontSize: 15),
                    decoration: InputDecoration(
                      hintText: 'Search by category, location...',
                      hintStyle: AppTheme.body(fontSize: 15, color: AppColors.outline),
                      border: InputBorder.none,
                    ),
                    onChanged: (v) => setState(() => _query = v.trim().toLowerCase()),
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
                      child: Icon(Icons.close, color: AppColors.outline, size: 18),
                    ),
                  )
                else
                  const SizedBox(width: 14),
              ],
            ),
          ),
        ),
        // Results from stream
        Expanded(
          child: StreamBuilder<List<JobModel>>(
            stream: widget.showOnlyMyJobs ? _db.getUserJobs(user.uid) : _db.getAllJobs(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                return Center(child: Text('Error: ${snapshot.error}'));
              }
              final filtered = _filterJobs(snapshot.data ?? []);
              return _buildJobsList(filtered, true, user.uid);
            },
          ),
        ),
      ],
    );

    // When used as standalone screen (showOnlyMyJobs), wrap with Scaffold + AppBar
    if (widget.showOnlyMyJobs) {
      return Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          title: Text(
            'My Jobs',
            style: AppTheme.headline(fontSize: 20, fontWeight: FontWeight.w700),
          ),
          backgroundColor: Colors.transparent,
          elevation: 0,
          centerTitle: true,
          iconTheme: const IconThemeData(color: AppColors.onSurface),
        ),
        body: content,
      );
    }

    // Inside MainShell — no Scaffold needed
    return content;
  }

  Widget _buildJobsList(List<JobModel> jobs, bool isActive, String currentUserId) {
    if (jobs.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.work_outline, size: 56, color: AppColors.outlineVariant.withValues(alpha: 0.5)),
            const SizedBox(height: 16),
            Text(
              'No jobs yet',
              style: AppTheme.body(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.outline),
            ),
            const SizedBox(height: 4),
            Text(
              'Post a job to find professionals near you',
              style: AppTheme.body(fontSize: 13, color: AppColors.outlineVariant),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(24),
      itemCount: jobs.length,
      itemBuilder: (context, index) {
        final job = jobs[index];
        final isOwner = job.userId == currentUserId;

        return _JobCard(
          job: job,
          showActions: widget.showOnlyMyJobs && isOwner,
          onEdit: () => _editJob(job),
          onDelete: () => _deleteJob(job),
          onRebook: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => AddJobScreen(
                  jobToEdit: JobModel(
                    id: '',
                    userId: job.userId,
                    category: job.category,
                    description: job.description,
                    location: job.location,
                    time: '',
                    budgetRange: job.budgetRange,
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class _JobCard extends StatefulWidget {
  final JobModel job;
  final bool showActions;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback? onRebook;

  const _JobCard({
    required this.job,
    this.showActions = false,
    required this.onEdit,
    required this.onDelete,
    this.onRebook,
  });

  @override
  State<_JobCard> createState() => _JobCardState();
}

class _JobCardState extends State<_JobCard> {
  bool _expanded = false;
  String? _posterName;
  String? _posterPhoto;
  bool _loadingPoster = false;

  Future<void> _loadPoster() async {
    if (_posterName != null || _loadingPoster) return;
    setState(() => _loadingPoster = true);
    try {
      final db = context.read<DatabaseService>();
      final data = await db.getUserData(widget.job.userId);
      if (mounted) {
        setState(() {
          _posterName = data?['name'] as String? ?? 'Unknown';
          _posterPhoto = data?['photoUrl'] as String?;
          _loadingPoster = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingPoster = false);
    }
  }

  String _initials(String name) {
    final parts = name.trim().split(' ');
    if (parts.length >= 2) return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    return name.isNotEmpty ? name[0].toUpperCase() : '?';
  }

  Future<void> _call(String phone) async {
    final uri = Uri.parse('tel:$phone');
    if (await canLaunchUrl(uri)) launchUrl(uri);
  }

  Widget _posterFallback() {
    final name = _posterName ?? '?';
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Center(
        child: Text(
          _initials(name),
          style: AppTheme.headline(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.primary),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final job = widget.job;
    final bool canModify = widget.showActions && job.status == 'Finding';
    final String dateStr = DateFormat('MMM d, h:mm a').format(job.createdAt ?? DateTime.now());

    return GestureDetector(
      onTap: () {
        setState(() => _expanded = !_expanded);
        if (_expanded) _loadPoster();
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
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
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Category icon avatar
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    color: _getCategoryColor().withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(_getCategoryIcon(), color: _getCategoryColor(), size: 30),
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
                              job.category,
                              style: AppTheme.headline(fontSize: 16),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: _getStatusColor().withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              job.status.toUpperCase(),
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                color: _getStatusColor(),
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(Icons.calendar_today_rounded, size: 12, color: AppColors.outline),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              dateStr,
                              style: AppTheme.body(fontSize: 12, color: AppColors.outline),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          const Icon(Icons.location_on_rounded, size: 14, color: AppColors.primary),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              job.location,
                              style: AppTheme.body(fontSize: 13, fontWeight: FontWeight.w500, color: AppColors.onSurfaceVariant),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 4),
                Icon(
                  _expanded ? Icons.keyboard_arrow_up_rounded : Icons.chevron_right_rounded,
                  size: 22,
                  color: AppColors.outlineVariant,
                ),
              ],
            ),

            // Expanded content
            AnimatedCrossFade(
              firstChild: const SizedBox.shrink(),
              secondChild: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 14),
                  // Poster info + call button
                  _loadingPoster
                      ? const Center(child: SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2)))
                      : Row(
                          children: [
                            // Avatar
                            ClipRRect(
                              borderRadius: BorderRadius.circular(22),
                              child: _posterPhoto != null && _posterPhoto!.isNotEmpty
                                  ? Image.network(
                                      _posterPhoto!,
                                      width: 44,
                                      height: 44,
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, _, _) => _posterFallback(),
                                    )
                                  : _posterFallback(),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _posterName ?? '',
                                    style: AppTheme.body(fontSize: 14, fontWeight: FontWeight.w700),
                                  ),
                                  Text(
                                    'Posted by',
                                    style: AppTheme.body(fontSize: 12, color: AppColors.outline),
                                  ),
                                ],
                              ),
                            ),
                            if (job.phone.isNotEmpty)
                              GestureDetector(
                                onTap: () => _call(job.phone),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                  decoration: BoxDecoration(
                                    color: AppColors.primary,
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(Icons.call_rounded, size: 16, color: Colors.white),
                                      const SizedBox(width: 6),
                                      Text('Call', style: AppTheme.body(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.white)),
                                    ],
                                  ),
                                ),
                              ),
                          ],
                        ),
                  if (job.description.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.background,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        job.description,
                        style: AppTheme.body(fontSize: 13, color: AppColors.onSurfaceVariant, height: 1.5),
                      ),
                    ),
                  ],
                  if (job.photoUrl != null && job.photoUrl!.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: Image.network(
                        job.photoUrl!,
                        height: 150,
                        width: double.infinity,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => const SizedBox.shrink(),
                      ),
                    ),
                  ],
                  if (canModify || (widget.showActions && job.status == 'Completed')) ...[
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        if (canModify) ...[
                          OutlinedButton.icon(
                            onPressed: widget.onEdit,
                            icon: const Icon(Icons.edit_outlined, size: 16),
                            label: const Text('Edit', style: TextStyle(fontSize: 13)),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.primary,
                              side: BorderSide(color: AppColors.primary.withValues(alpha: 0.3)),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                            ),
                          ),
                          const SizedBox(width: 8),
                          OutlinedButton.icon(
                            onPressed: widget.onDelete,
                            icon: const Icon(Icons.delete_outline, size: 16),
                            label: const Text('Delete', style: TextStyle(fontSize: 13)),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.error,
                              side: BorderSide(color: AppColors.error.withValues(alpha: 0.3)),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                            ),
                          ),
                        ],
                        if (job.status == 'Completed')
                          ElevatedButton.icon(
                            onPressed: widget.onRebook,
                            icon: const Icon(Icons.replay_rounded, size: 16),
                            label: const Text('Rebook', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                              elevation: 0,
                            ),
                          ),
                      ],
                    ),
                  ],
                ],
              ),
              crossFadeState: _expanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
              duration: const Duration(milliseconds: 250),
            ),
          ],
        ),
      ),
    );
  }

  IconData _getCategoryIcon() {
    switch (widget.job.category) {
      case 'Plumber': return Icons.plumbing;
      case 'Electrician': return Icons.electrical_services;
      case 'Cleaner': return Icons.cleaning_services;
      case 'Painter': return Icons.imagesearch_roller;
      case 'Carpenter': return Icons.carpenter;
      default: return Icons.handyman;
    }
  }

  Color _getCategoryColor() {
    switch (widget.job.category) {
      case 'Plumber': return Colors.blue;
      case 'Electrician': return Colors.amber;
      case 'Cleaner': return Colors.green;
      case 'Painter': return Colors.purple;
      case 'Carpenter': return Colors.orange;
      default: return AppColors.primary;
    }
  }

  Color _getStatusColor() {
    switch (widget.job.status) {
      case 'Finding': return AppColors.primary;
      case 'Assigned': return Colors.orange;
      case 'On Way': return Colors.green;
      case 'Completed': return AppColors.onSurfaceVariant;
      default: return AppColors.primary;
    }
  }
}

