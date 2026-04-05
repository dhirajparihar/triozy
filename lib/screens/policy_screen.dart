import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';

enum PolicyType { terms, privacy }

class PolicyScreen extends StatelessWidget {
  final PolicyType type;
  const PolicyScreen({super.key, required this.type});

  @override
  Widget build(BuildContext context) {
    final isTerms = type == PolicyType.terms;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        title: Text(
          isTerms ? 'Terms of Service' : 'Privacy Policy',
          style: AppTheme.headline(fontSize: 20, fontWeight: FontWeight.w700),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 48),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: isTerms ? _termsContent() : _privacyContent(),
        ),
      ),
    );
  }

  // ── helpers ──────────────────────────────────────────────────────────────

  Widget _lastUpdated() => Padding(
        padding: const EdgeInsets.only(bottom: 28),
        child: Text(
          'Last Updated: April 5, 2026',
          style: AppTheme.body(fontSize: 13, color: AppColors.outline),
        ),
      );

  Widget _section(String title, List<Widget> children) => Padding(
        padding: const EdgeInsets.only(bottom: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title,
                style: AppTheme.headline(
                    fontSize: 16, fontWeight: FontWeight.w700)),
            const SizedBox(height: 10),
            ...children,
          ],
        ),
      );

  Widget _body(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(text,
            style: AppTheme.body(
                fontSize: 14,
                color: AppColors.onSurfaceVariant,
                height: 1.6)),
      );

  Widget _bullet(String text) => Padding(
        padding: const EdgeInsets.only(left: 12, bottom: 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 7),
              child: Container(
                width: 5,
                height: 5,
                decoration: const BoxDecoration(
                  color: AppColors.primary,
                  shape: BoxShape.circle,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(text,
                  style: AppTheme.body(
                      fontSize: 14,
                      color: AppColors.onSurfaceVariant,
                      height: 1.6)),
            ),
          ],
        ),
      );

  // ── Terms content ─────────────────────────────────────────────────────────

  List<Widget> _termsContent() => [
        _lastUpdated(),
        _body('Welcome to Triozy. By using our app, you agree to these Terms.'),
        const SizedBox(height: 8),
        _section('1. Eligibility', [
          _body('You must be at least 18 years old or have parental consent to use this app.'),
        ]),
        _section('2. Use of the App', [
          _body('You agree to:'),
          _bullet('Provide accurate information'),
          _bullet('Use the app legally'),
          _bullet('Not misuse, hack, or disrupt services'),
        ]),
        _section('3. Services', [
          _body('Triozy connects users with independent service providers (e.g., electrician, plumber, etc.).'),
          _bullet('We do not guarantee service quality, timing, or results'),
          _bullet('Providers are independent, not employees of the app'),
        ]),
        _section('4. Bookings & Payments', [
          _bullet('Payments may be required for certain services'),
          _bullet('Payments are processed via secure third-party providers'),
          _bullet('Cancellation and refunds depend on app policies'),
        ]),
        _section('5. Worker Subscriptions', [
          _bullet('Workers may need a paid subscription to access leads'),
          _bullet('Expired subscriptions may limit access'),
        ]),
        _section('6. User Conduct', [
          _body('You must NOT:'),
          _bullet('Use fake details'),
          _bullet('Harass or abuse others'),
          _bullet('Perform fraud or illegal activity'),
        ]),
        _section('7. Account Suspension', [
          _body('We may suspend or terminate accounts that violate these terms.'),
        ]),
        _section('8. Limitation of Liability', [
          _body('Triozy is not responsible for:'),
          _bullet('Service disputes'),
          _bullet('Loss, damage, or poor service quality'),
        ]),
        _section('9. Changes to Terms', [
          _body('We may update these Terms anytime. Continued use means acceptance.'),
        ]),
        _section('10. Contact', [
          _body('📧 Email: support@triozy.in'),
        ]),
      ];

  // ── Privacy content ───────────────────────────────────────────────────────

  List<Widget> _privacyContent() => [
        _lastUpdated(),
        _body('Triozy respects your privacy. This policy explains how we collect, use, and protect your data.'),
        const SizedBox(height: 8),
        _section('1. Information We Collect', [
          _body('We may collect:'),
          _bullet('Name, phone number, email address'),
          _bullet('Approximate or precise location (to match nearby services)'),
          _bullet('Device type, OS version, app usage data'),
        ]),
        _section('2. How We Use Your Information', [
          _body('We use your data to:'),
          _bullet('Connect users with service providers'),
          _bullet('Process bookings and payments'),
          _bullet('Improve app performance'),
          _bullet('Provide customer support'),
        ]),
        _section('3. Permissions We Use', [
          _bullet('Location → To find nearby services'),
          _bullet('Camera/Storage (if used) → For profile photos or uploads'),
          _body('We only use permissions when necessary.'),
        ]),
        _section('4. Third-Party Services', [
          _body('We may use trusted third-party services such as:'),
          _bullet('Firebase (Google) → Authentication & analytics'),
          _bullet('Payment gateways (e.g., Razorpay, Stripe) → Secure payments'),
          _body('These services may collect and process data under their own policies.'),
        ]),
        _section('5. Data Sharing', [
          _body('We may share your data with:'),
          _bullet('Service providers (to complete bookings)'),
          _bullet('Payment partners'),
          _bullet('Legal authorities (if required by law)'),
          _body('❌ We do NOT sell your personal data.'),
        ]),
        _section('6. Data Retention', [
          _body('We retain your data only as long as necessary to provide services or comply with legal obligations.'),
        ]),
        _section('7. Data Security', [
          _body('We use reasonable security measures to protect your data. However, no system is 100% secure.'),
        ]),
        _section('8. Your Rights', [
          _body('You can:'),
          _bullet('Access or update your data'),
          _bullet('Request account deletion'),
          _body('To delete your account, contact: 📧 support@triozy.in'),
        ]),
        _section("9. Children's Privacy", [
          _body('This app is not intended for users under 13. We do not knowingly collect data from children.'),
        ]),
        _section('10. Changes to This Policy', [
          _body('We may update this policy. Continued use means you accept the changes.'),
        ]),
        _section('11. Contact Us', [
          _body('📧 Email: support@triozy.in'),
        ]),
      ];
}
