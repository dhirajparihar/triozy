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

    _workerSub = db.streamWorker(widget.workerId).listen((w) {
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
    }, onError: (_) {
      if (mounted) setState(() => _loading = false);
    });
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

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          CustomScrollView(
            slivers: [
              SliverToBoxAdapter(child: _buildHeader(context)),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    children: [
                      _buildHeroProfile(w),
                      const SizedBox(height: 48),
                      _buildInfoGrid(w),
                      const SizedBox(height: 32),
                      _buildReviews(),
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
            color: const Color(0xFFF1F5F9).withValues(alpha: 0.8),
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
    return Column(
      children: [
        const SizedBox(height: 16),
        Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              width: 128,
              height: 128,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: AppColors.surfaceContainerHighest,
                  width: 4,
                ),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
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
              bottom: -8,
              right: -8,
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: AppColors.secondary,
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.background, width: 4),
                ),
                child: const Icon(
                  Icons.verified,
                  size: 14,
                  color: AppColors.onSecondary,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Text(
          w.name,
          style: AppTheme.headline(fontSize: 28),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 4),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              w.serviceType.toUpperCase(),
              style: AppTheme.label(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.secondary,
                letterSpacing: 1.0,
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Text(
                '•',
                style: TextStyle(color: AppColors.outlineVariant),
              ),
            ),
            Text(
              '${w.experience}+ YEARS EXPERIENCE',
              style: AppTheme.label(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.secondary,
                letterSpacing: 1.0,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.surfaceContainer,
                borderRadius: BorderRadius.circular(9999),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.star, color: AppColors.tertiary, size: 20),
                  const SizedBox(width: 4),
                  Text(
                    w.ratingDisplay,
                    style: AppTheme.body(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '(${w.totalJobs})',
                    style: AppTheme.body(
                      fontSize: 12,
                      color: AppColors.outline,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.surfaceContainer,
                borderRadius: BorderRadius.circular(9999),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.history, color: AppColors.primary, size: 20),
                  const SizedBox(width: 4),
                  Text(
                    '${w.totalJobs} Requests',
                    style: AppTheme.body(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
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
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
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
                  Text(
                    'Service Expertise',
                    style: AppTheme.headline(fontSize: 20),
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
                          horizontal: 16,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceContainerHigh,
                          borderRadius: BorderRadius.circular(9999),
                        ),
                        child: Text(
                          tag,
                          style: AppTheme.label(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppColors.onSurfaceVariant,
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
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.blue50.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.near_me, color: AppColors.primary, size: 20),
              const SizedBox(width: 8),
              Text('Area', style: AppTheme.headline(fontSize: 18)),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Serving ${w.location.isNotEmpty ? w.location : 'your area'} and surrounding neighborhoods.',
            style: AppTheme.body(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: AppColors.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Container(
              height: 80,
              color: AppColors.surfaceDim,
              child: Center(
                child: Icon(
                  Icons.map,
                  color: AppColors.outline.withValues(alpha: 0.5),
                  size: 32,
                ),
              ),
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
    final text = '👷 Check out ${w.name} on Triozy!\n'
        '🔧 Service: ${w.serviceType}\n'
        '⭐ Rating: ${w.ratingDisplay}\n'
        '📍 ${w.location}\n\n'
        'Book now: $profileUrl';
    Share.share(text);
  }

  Future<void> _submitRating() async {
    if (_selectedRating == 0 || _worker == null) return;

    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    final db = context.read<DatabaseService>();
    try {
      await db.submitWorkerRating(_worker!.uid, uid, _selectedRating.toDouble());
      if (mounted) {
        setState(() => _reviewSubmitted = true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Thanks! You rated ${_worker!.name.split(' ').first} $_selectedRating stars.'),
            backgroundColor: AppColors.secondary,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to submit rating: $e'), backgroundColor: AppColors.error),
        );
      }
    }
  }

  Widget _buildReviews() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
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
            style: AppTheme.body(fontSize: 14, color: AppColors.onSurfaceVariant),
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
                    starIndex <= _selectedRating ? Icons.star_rounded : Icons.star_outline_rounded,
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
                                color: AppColors.secondary.withValues(alpha: 0.15),
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
                                    await launchUrl(uri);
                                    // Record the call in Firestore
                                    db.incrementWorkerCalls(w.uid);
                                  }
                                } else {
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(content: Text('Phone number not available')),
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
