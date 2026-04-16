import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:ui';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:share_plus/share_plus.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/worker_model.dart';
import '../services/database_service.dart';

class WorkerProfileScreen extends StatefulWidget {
  final String workerId;
  const WorkerProfileScreen({super.key, required this.workerId});

  @override
  State<WorkerProfileScreen> createState() => _WorkerProfileScreenState();
}

class _WorkerProfileScreenState extends State<WorkerProfileScreen> {
  WorkerModel? _worker;
  bool _loading = true;
  int _selectedRating = 0;
  bool _reviewSubmitted = false;
  bool _hasCalledWorker = false;
  StreamSubscription<WorkerModel?>? _workerSub;

  @override
  void initState() {
    super.initState();
    _subscribeToWorker();
  }

  @override
  void dispose() {
    _workerSub?.cancel();
    super.dispose();
  }

  Future<void> _subscribeToWorker() async {
    final db = context.read<DatabaseService>();

    // Check if current user already rated this worker
    final uid = FirebaseAuth.instance.currentUser?.uid;
    double? existingRating;
    if (uid != null) {
      try {
        existingRating = await db.getUserRatingForWorker(widget.workerId, uid);
      } catch (_) {}
    }

    _workerSub = db
        .streamWorker(widget.workerId)
        .listen(
          (w) {
            if (mounted) {
              setState(() {
                _worker = w;
                _loading = false;
                if (existingRating != null && !_reviewSubmitted) {
                  _selectedRating = existingRating.toInt();
                  _reviewSubmitted = true;
                }
              });
            }
          },
          onError: (_) {
            if (mounted) setState(() => _loading = false);
          },
        );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        backgroundColor: AppColors.background,
        body: const Center(
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
      );
    }
    if (_worker == null) {
      return Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(title: const Text('Professional Profile')),
        body: const Center(child: Text('Professional not found')),
      );
    }
    final w = _worker!;
    final currentUid = FirebaseAuth.instance.currentUser?.uid;
    final isOwnProfile = currentUid != null && currentUid == w.uid;
    final canShowRatingCard =
        !isOwnProfile && (_hasCalledWorker || _reviewSubmitted);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          CustomScrollView(
            slivers: [
              SliverToBoxAdapter(child: _buildHeader(context)),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    children: [
                      _buildHeroProfile(w),
                      const SizedBox(height: 20),
                      _buildInfoGrid(w),
                      const SizedBox(height: 24),
                      if (isOwnProfile)
                        _buildRatingLockedCard(
                          title: 'Rating Unavailable',
                          subtitle:
                              'You cannot rate your own professional profile.',
                        )
                      else if (canShowRatingCard)
                        _buildReviews()
                      else
                        _buildRatingLockedCard(
                          title: 'Rate this Professional',
                          subtitle:
                              'Call this professional first to unlock rating.',
                        ),
                      const SizedBox(height: 120),
                    ],
                  ),
                ),
              ),
            ],
          ),
          _buildFixedCallBar(context, w),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return ClipRRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          padding: EdgeInsets.only(
            top: MediaQuery.of(context).padding.top,
            left: 24,
            right: 24,
          ),
          height: MediaQuery.of(context).padding.top + 64,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.86),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.transparent,
                  ),
                  child: const Icon(
                    Icons.arrow_back_ios_new,
                    color: AppColors.onSurface,
                    size: 20,
                  ),
                ),
              ),
              Text(
                'Professional Profile',
                style: AppTheme.headline(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              GestureDetector(
                onTap: _shareProfile,
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: const BoxDecoration(shape: BoxShape.circle),
                  child: const Icon(
                    Icons.share_outlined,
                    color: AppColors.onSurface,
                    size: 22,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeroProfile(WorkerModel w) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(
          color: AppColors.outlineVariant.withValues(alpha: 0.2),
        ),
      ),
      child: Column(
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                width: 96,
                height: 96,
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(
                    colors: [AppColors.primaryContainer, AppColors.primary],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: ClipOval(
                  child: w.photoUrl.isNotEmpty
                      ? Image.network(
                          w.photoUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) => _avatarFallback(),
                        )
                      : _avatarFallback(),
                ),
              ),
              Positioned(
                bottom: -2,
                right: -2,
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: AppColors.secondary,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                  child: const Icon(
                    Icons.verified,
                    size: 12,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            w.name,
            style: AppTheme.headline(fontSize: 26),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          Text(
            '${w.serviceType} - ${w.experience}+ years experience',
            style: AppTheme.body(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _metaPill(
                  icon: Icons.star_rounded,
                  iconColor: AppColors.tertiary,
                  text: '${w.ratingDisplay} (${w.totalJobs})',
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _metaPill(
                  icon: Icons.history_rounded,
                  iconColor: AppColors.primary,
                  text: '${w.totalJobs} Requests',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _metaPill({
    required IconData icon,
    required Color iconColor,
    required String text,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF3F6FB),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        children: [
          Icon(icon, color: iconColor, size: 18),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              text,
              style: AppTheme.body(fontSize: 13, fontWeight: FontWeight.w700),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _avatarFallback() {
    return Container(
      color: AppColors.surfaceContainerHighest,
      child: const Icon(Icons.person, size: 48, color: AppColors.outline),
    );
  }

  Widget _buildInfoGrid(WorkerModel w) {
    return Column(
      children: [
        // Service Expertise (full width)
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: AppColors.outlineVariant.withValues(alpha: 0.18),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: AppColors.primaryFixed,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.description,
                      color: AppColors.onPrimaryFixed,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Service Expertise',
                      style: AppTheme.headline(fontSize: 20),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                w.description.isNotEmpty
                    ? w.description
                    : 'Professional ${w.serviceType} with ${w.experience} years of experience. Available for residential and commercial work.',
                style: AppTheme.body(
                  fontSize: 14,
                  color: AppColors.onSurfaceVariant,
                  letterSpacing: 0.1,
                ),
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: w.skills
                    .map(
                      (tag) => Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 7,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(9999),
                          border: Border.all(
                            color: AppColors.primary.withValues(alpha: 0.2),
                          ),
                        ),
                        child: Text(
                          tag,
                          style: AppTheme.label(
                            fontSize: 12,
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
        const SizedBox(height: 16),
        _buildAreaCard(w),
      ],
    );
  }

  Widget _buildAreaCard(WorkerModel w) {
    final location = w.location.isNotEmpty ? w.location : 'Your area';
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: AppColors.outlineVariant.withValues(alpha: 0.2),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.location_on_rounded,
              color: AppColors.primary,
              size: 26,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Service Area',
                  style: AppTheme.label(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  location,
                  style: AppTheme.headline(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '& surrounding neighborhoods',
                  style: AppTheme.body(
                    fontSize: 13,
                    color: AppColors.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _shareProfile() {
    if (_worker == null) return;
    final w = _worker!;
    final profileUrl = 'https://triozy-app.web.app/#/worker/${w.uid}';
    final text =
        'ðŸ‘· Check out ${w.name} on Triozy!\n'
        'ðŸ”§ Service: ${w.serviceType}\n'
        'â­ Rating: ${w.ratingDisplay}\n'
        'ðŸ“ ${w.location}\n\n'
        'Book now: $profileUrl';
    Share.share(text);
  }

  Future<void> _submitRating() async {
    if (_selectedRating == 0 || _worker == null) return;

    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please sign in to rate this professional.'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }
    if (uid == _worker!.uid) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('You cannot rate your own profile.'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    final db = context.read<DatabaseService>();
    try {
      await db.submitWorkerRating(
        _worker!.uid,
        uid,
        _selectedRating.toDouble(),
      );
      if (mounted) {
        setState(() => _reviewSubmitted = true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Thanks! You rated ${_worker!.name.split(' ').first} $_selectedRating stars.',
            ),
            backgroundColor: AppColors.secondary,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to submit rating: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Widget _buildRatingLockedCard({
    required String title,
    required String subtitle,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: AppColors.outlineVariant.withValues(alpha: 0.2),
        ),
      ),
      child: Column(
        children: [
          Icon(
            Icons.lock_outline_rounded,
            size: 32,
            color: AppColors.outlineVariant,
          ),
          const SizedBox(height: 10),
          Text(
            title,
            style: AppTheme.headline(fontSize: 20),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            style: AppTheme.body(
              fontSize: 14,
              color: AppColors.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildReviews() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: AppColors.outlineVariant.withValues(alpha: 0.2),
        ),
      ),
      child: Column(
        children: [
          Text(
            _reviewSubmitted ? 'Your Rating' : 'Rate this Professional',
            style: AppTheme.headline(fontSize: 20),
          ),
          const SizedBox(height: 8),
          Text(
            _reviewSubmitted
                ? 'You already rated. Tap a star to update.'
                : 'Tap a star to rate your experience',
            style: AppTheme.body(
              fontSize: 14,
              color: AppColors.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(5, (index) {
              final starIndex = index + 1;
              return GestureDetector(
                onTap: () => setState(() {
                  _selectedRating = starIndex;
                  _reviewSubmitted = false;
                }),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  child: Icon(
                    starIndex <= _selectedRating
                        ? Icons.star_rounded
                        : Icons.star_outline_rounded,
                    size: 40,
                    color: starIndex <= _selectedRating
                        ? AppColors.tertiary
                        : AppColors.outlineVariant,
                  ),
                ),
              );
            }),
          ),
          if (_selectedRating > 0 && !_reviewSubmitted) ...[
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: _submitRating,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 0,
                ),
                child: Text(
                  'Submit Rating',
                  style: AppTheme.body(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildFixedCallBar(BuildContext context, WorkerModel w) {
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: ClipRRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
          child: Container(
            padding: EdgeInsets.only(
              left: 24,
              right: 24,
              top: 24,
              bottom: MediaQuery.of(context).padding.bottom + 24,
            ),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.85),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: w.isAvailable
                          ? const LinearGradient(
                              colors: [
                                AppColors.secondary,
                                AppColors.tertiaryContainer,
                              ],
                            )
                          : null,
                      color: w.isAvailable ? null : AppColors.onSurfaceVariant,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: w.isAvailable
                          ? [
                              BoxShadow(
                                color: AppColors.secondary.withValues(
                                  alpha: 0.15,
                                ),
                                blurRadius: 32,
                                offset: const Offset(0, 12),
                              ),
                            ]
                          : null,
                    ),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(16),
                        onTap: w.isAvailable
                            ? () async {
                                final db = context.read<DatabaseService>();
                                if (w.phone.isNotEmpty) {
                                  final uri = Uri(scheme: 'tel', path: w.phone);
                                  if (await canLaunchUrl(uri)) {
                                    final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
                                    if (!launched) return;
                                    // Record the call in Firestore
                                    db.incrementWorkerCalls(w.uid);
                                    final uid =
                                        FirebaseAuth.instance.currentUser?.uid;
                                    if (uid != null &&
                                        uid != w.uid &&
                                        mounted) {
                                      setState(() => _hasCalledWorker = true);
                                    }
                                  }
                                } else {
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                          'Phone number not available',
                                        ),
                                      ),
                                    );
                                  }
                                }
                              }
                            : null,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              w.isAvailable ? Icons.call : Icons.call_end,
                              color: AppColors.onSecondary,
                              size: 20,
                            ),
                            const SizedBox(width: 12),
                            Text(
                              w.isAvailable
                                  ? 'CALL ${w.name.split(' ').first.toUpperCase()} NOW'
                                  : '${w.name.split(' ').first.toUpperCase()} IS OFFLINE',
                              style: AppTheme.headline(
                                fontSize: 18,
                                color: AppColors.onSecondary,
                                letterSpacing: 1.0,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                RichText(
                  text: TextSpan(
                    children: [
                      TextSpan(
                        text: 'TYPICAL RESPONSE TIME: ',
                        style: AppTheme.label(
                          fontSize: 10,
                          color: AppColors.outline,
                          letterSpacing: 1.5,
                        ),
                      ),
                      TextSpan(
                        text: 'UNDER 5 MINS',
                        style: AppTheme.label(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: AppColors.secondary,
                          letterSpacing: 1.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
