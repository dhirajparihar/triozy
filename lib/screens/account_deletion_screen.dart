import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';

class AccountDeletionScreen extends StatelessWidget {
  const AccountDeletionScreen({super.key});

  static const supportEmail = 'triozyapp@gmail.com';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 820),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Delete Your Triozy Account',
                    style: AppTheme.headline(
                      fontSize: 34,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Use this page to request deletion of your Triozy account and associated data.',
                    style: AppTheme.body(
                      fontSize: 16,
                      color: AppColors.onSurfaceVariant,
                      height: 1.6,
                    ),
                  ),
                  const SizedBox(height: 28),
                  _InfoCard(
                    title: 'How to request deletion',
                    children: const [
                      '1. Email triozyapp@gmail.com from the email address linked to your Triozy account.',
                      '2. Use the subject line: Delete Triozy Account.',
                      '3. In the email body, include your registered name, account email, and whether you want full account deletion.',
                      '4. We may contact you to verify ownership before processing the request.',
                    ],
                  ),
                  const SizedBox(height: 16),
                  _InfoCard(
                    title: 'What data is deleted',
                    children: const [
                      'Your Triozy user profile and associated account details.',
                      'Worker profile information, if you registered as a service provider.',
                      'Requests, mate listings, profile photo references, and other user-generated profile content associated with your account.',
                    ],
                  ),
                  const SizedBox(height: 16),
                  _InfoCard(
                    title: 'What may be retained',
                    children: const [
                      'We may retain limited records when required for legal, fraud-prevention, abuse-prevention, dispute-resolution, or security purposes.',
                      'Backups and logs may remain for up to 30 days before permanent removal.',
                    ],
                  ),
                  const SizedBox(height: 16),
                  _InfoCard(
                    title: 'Processing time',
                    children: const [
                      'We aim to review deletion requests within 7 business days.',
                      'Once verified, deletion is typically completed within 30 days.',
                    ],
                  ),
                  const SizedBox(height: 24),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: AppColors.outlineVariant.withValues(alpha: 0.2),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Deletion request contact',
                          style: AppTheme.headline(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 10),
                        SelectableText(
                          supportEmail,
                          style: AppTheme.body(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: AppColors.primary,
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
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  final String title;
  final List<String> children;

  const _InfoCard({
    required this.title,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: AppTheme.headline(
              fontSize: 20,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 14),
          for (final item in children) ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.only(top: 6),
                  child: Icon(
                    Icons.circle,
                    size: 7,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    item,
                    style: AppTheme.body(
                      fontSize: 15,
                      color: AppColors.onSurfaceVariant,
                      height: 1.6,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
          ],
        ],
      ),
    );
  }
}
