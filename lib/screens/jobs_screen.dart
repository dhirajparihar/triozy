import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
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

  @override
  void initState() {
    super.initState();
    _db = context.read<DatabaseService>();
    _auth = context.read<AuthService>();
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

    // When used standalone (e.g. "My Jobs" from profile), wrap in Scaffold
    final content = StreamBuilder<List<JobModel>>(
      stream: widget.showOnlyMyJobs ? _db.getUserJobs(user.uid) : _db.getAllJobs(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        final allJobs = snapshot.data ?? [];

        return Column(
          children: [
            // Title
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Jobs',
                    style: AppTheme.headline(fontSize: 24, fontWeight: FontWeight.w700, color: AppColors.primary),
                  ),
                ],
              ),
            ),
            Expanded(
              child: _buildJobsList(allJobs, true, user.uid),
            ),
          ],
        );
      },
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

  @override
  Widget build(BuildContext context) {
    final job = widget.job;
    final bool canModify = widget.showActions && job.status == 'Finding';
    final String dateStr = DateFormat('MMM d, h:mm a').format(job.createdAt ?? DateTime.now());

    return GestureDetector(
      onTap: () => setState(() => _expanded = !_expanded),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeInOut,
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: _expanded
                ? AppColors.primary.withValues(alpha: 0.2)
                : AppColors.outlineVariant.withValues(alpha: 0.1),
          ),
          boxShadow: [
            BoxShadow(
              color: _expanded
                  ? AppColors.primary.withValues(alpha: 0.06)
                  : Colors.black.withValues(alpha: 0.03),
              blurRadius: _expanded ? 16 : 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header row
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: _getCategoryColor().withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(_getCategoryIcon(), color: _getCategoryColor(), size: 26),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(job.category, style: AppTheme.headline(fontSize: 17)),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(Icons.calendar_today_rounded, size: 13, color: AppColors.outline),
                          const SizedBox(width: 4),
                          Text(dateStr, style: AppTheme.body(fontSize: 12, color: AppColors.outline)),
                        ],
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
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

            // Location row
            const SizedBox(height: 14),
            Row(
              children: [
                const Icon(Icons.location_on_rounded, size: 16, color: AppColors.primary),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    job.location,
                    style: AppTheme.body(fontSize: 13, fontWeight: FontWeight.w500, color: AppColors.onSurfaceVariant),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Icon(
                  _expanded ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
                  size: 22,
                  color: AppColors.outline,
                ),
              ],
            ),

            // Expanded content
            AnimatedCrossFade(
              firstChild: const SizedBox.shrink(),
              secondChild: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (job.description.isNotEmpty) ...[
                    const SizedBox(height: 14),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppColors.background,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        job.description,
                        style: AppTheme.body(fontSize: 14, color: AppColors.onSurfaceVariant, height: 1.5),
                      ),
                    ),
                  ],
                  if (job.photoUrl != null && job.photoUrl!.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.network(
                        job.photoUrl!,
                        height: 160,
                        width: double.infinity,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => const SizedBox.shrink(),
                      ),
                    ),
                  ],
                  if (canModify || (widget.showActions && job.status == 'Completed')) ...[
                    const SizedBox(height: 14),
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

