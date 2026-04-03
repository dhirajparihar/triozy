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
            Icon(Icons.work_outline, size: 64, color: AppColors.outlineVariant.withValues(alpha: 0.5)),
            const SizedBox(height: 16),
            Text(
              isActive ? 'No active jobs' : 'No past jobs',
              style: AppTheme.body(fontSize: 16, color: AppColors.outline),
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
        return _JobCard(
          job: job,
          isOwner: job.userId == currentUserId,
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

class _JobCard extends StatelessWidget {
  final JobModel job;
  final bool isOwner;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback? onRebook;

  const _JobCard({
    required this.job,
    required this.isOwner,
    required this.onEdit,
    required this.onDelete,
    this.onRebook,
  });

  @override
  Widget build(BuildContext context) {
    final bool canModify = isOwner && job.status == 'Finding';
    final String dateStr = DateFormat('MMM d, h:mm a').format(job.createdAt ?? DateTime.now());

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: _getCategoryColor().withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(_getCategoryIcon(), color: _getCategoryColor(), size: 32),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      job.category,
                      style: AppTheme.headline(fontSize: 18),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(Icons.calendar_today, size: 14, color: AppColors.onSurfaceVariant),
                        const SizedBox(width: 4),
                        Text(dateStr, style: TextStyle(fontSize: 12, color: AppColors.onSurfaceVariant)),
                      ],
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: _getStatusColor().withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(99),
                ),
                child: Text(
                  job.status.toUpperCase(),
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: _getStatusColor(),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          const Divider(height: 1),
          const SizedBox(height: 16),
          Row(
            children: [
              const Icon(Icons.location_on, size: 18, color: AppColors.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  job.location,
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    job.price != null ? 'FIXED QUOTE' : 'ESTIMATED RANGE',
                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: AppColors.onSurfaceVariant.withValues(alpha: 0.6)),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _getPriceDisplay(),
                    style: AppTheme.headline(fontSize: 20, color: AppColors.onSurface),
                  ),
                ],
              ),
              Row(
                children: [
                  if (canModify) ...[
                    IconButton(
                      onPressed: onEdit,
                      icon: const Icon(Icons.edit_outlined, color: AppColors.primary, size: 22),
                    ),
                    IconButton(
                      onPressed: onDelete,
                      icon: const Icon(Icons.delete_outline, color: AppColors.error, size: 22),
                    ),
                  ],
                  if (!canModify)
                    ElevatedButton(
                      onPressed: job.status == 'Completed' ? onRebook : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(99)),
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                        elevation: 0,
                      ),
                      child: Text(job.status == 'Completed' ? 'Rebook' : 'View Details', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                    ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  IconData _getCategoryIcon() {
    switch (job.category) {
      case 'Plumber': return Icons.plumbing;
      case 'Electrician': return Icons.electrical_services;
      case 'Cleaner': return Icons.cleaning_services;
      case 'Painter': return Icons.imagesearch_roller;
      case 'Carpenter': return Icons.carpenter;
      default: return Icons.handyman;
    }
  }

  Color _getCategoryColor() {
    switch (job.category) {
      case 'Plumber': return Colors.blue;
      case 'Electrician': return Colors.amber;
      case 'Cleaner': return Colors.green;
      case 'Painter': return Colors.purple;
      case 'Carpenter': return Colors.orange;
      default: return AppColors.primary;
    }
  }

  Color _getStatusColor() {
    switch (job.status) {
      case 'Finding': return AppColors.primary;
      case 'Assigned': return Colors.orange;
      case 'On Way': return Colors.green;
      case 'Completed': return AppColors.onSurfaceVariant;
      default: return AppColors.primary;
    }
  }

  String _getPriceDisplay() {
    if (job.price != null) return '\$${job.price!.toStringAsFixed(2)}';
    switch (job.budgetRange) {
      case 'Economy': return '\$50 - \$150';
      case 'Standard': return '\$150 - \$400';
      case 'Premium': return '\$400 - \$900';
      default: return '\$150 - \$400';
    }
  }
}

