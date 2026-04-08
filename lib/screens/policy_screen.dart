import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
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
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          // ── Premium SliverAppBar ──────────────────────────────────────
          SliverAppBar(
            pinned: true,
            expandedHeight: 140,
            backgroundColor: AppColors.background,
            surfaceTintColor: Colors.transparent,
            elevation: 0,
            scrolledUnderElevation: 1,
            shadowColor: Colors.black.withValues(alpha: 0.06),
            leading: IconButton(
              icon: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: AppColors.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.arrow_back_rounded,
                    size: 18, color: AppColors.onSurface),
              ),
              onPressed: () => Navigator.of(context).pop(),
            ),
            flexibleSpace: FlexibleSpaceBar(
              titlePadding:
                  const EdgeInsets.fromLTRB(24, 0, 24, 16),
              title: Text(
                isTerms ? 'Terms of Service' : 'Privacy Policy',
                style: GoogleFonts.inter(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: AppColors.onSurface,
                  letterSpacing: -0.4,
                ),
              ),
              background: Container(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 64),
                alignment: Alignment.bottomLeft,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: isTerms
                        ? [
                            const Color(0xFF001A41),
                            AppColors.primary,
                          ]
                        : [
                            const Color(0xFF002110),
                            AppColors.secondary,
                          ],
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(
                        isTerms
                            ? Icons.gavel_rounded
                            : Icons.shield_rounded,
                        size: 22,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isTerms ? 'Terms of Service' : 'Privacy Policy',
                          style: GoogleFonts.inter(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                            letterSpacing: -0.6,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          'Last updated: April 8, 2026',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: Colors.white.withValues(alpha: 0.65),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
          // ── Content ────────────────────────────────────────────────────
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 64),
            sliver: SliverList(
              delegate: SliverChildListDelegate(
                isTerms ? _termsContent() : _privacyContent(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Builder helpers ─────────────────────────────────────────────────────────

  Widget _intro(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 28),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.surfaceContainerLow,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.outlineVariant, width: 1),
          ),
          child: Text(
            text,
            style: AppTheme.body(
                fontSize: 14,
                color: AppColors.onSurfaceVariant,
                height: 1.65),
          ),
        ),
      );

  Widget _section(String number, String title, List<Widget> children) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Center(
                    child: Text(
                      number,
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    title,
                    style: AppTheme.headline(
                        fontSize: 15, fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ...children,
          ],
        ),
      );

  Widget _body(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(
          text,
          style: AppTheme.body(
              fontSize: 14, color: AppColors.onSurfaceVariant, height: 1.65),
        ),
      );

  Widget _bullet(String text) => Padding(
        padding: const EdgeInsets.only(left: 4, bottom: 6),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Container(
                width: 5,
                height: 5,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.6),
                  shape: BoxShape.circle,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                text,
                style: AppTheme.body(
                    fontSize: 14,
                    color: AppColors.onSurfaceVariant,
                    height: 1.65),
              ),
            ),
          ],
        ),
      );

  Widget _highlight(String text, {bool isWarning = false}) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: isWarning
                ? AppColors.errorContainer.withValues(alpha: 0.4)
                : AppColors.secondaryContainer.withValues(alpha: 0.25),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            text,
            style: AppTheme.body(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: isWarning
                  ? AppColors.onErrorContainer
                  : AppColors.onSecondaryContainer,
              height: 1.5,
            ),
          ),
        ),
      );

  // ── Terms of Service ────────────────────────────────────────────────────────

  List<Widget> _termsContent() => [
        _intro(
          'Welcome to Triozy — the platform built around three pillars: Workers, Requests, and Mates. '
          'By accessing or using Triozy, you agree to be bound by these Terms of Service. '
          'Please read them carefully before proceeding.',
        ),
        _section('1', 'Eligibility & Accounts', [
          _body(
              'You must be at least 18 years old to create an account on Triozy. '
              'By registering, you confirm that the information you provide is accurate and up to date.'),
          _bullet('One account per person — duplicate accounts may be suspended'),
          _bullet(
              'You are responsible for all activity that occurs under your account'),
          _bullet(
              'Keep your sign-in credentials secure and notify us of unauthorised access'),
        ]),
        _section('2', 'The Three Pillars', [
          _body(
              'Triozy operates around three core features. Your use of each is subject to the following:'),
          const SizedBox(height: 8),
          _highlight('Workers — Find & Hire Service Professionals'),
          _bullet(
              'Workers are independent professionals, not employees of Triozy'),
          _bullet(
              'Triozy displays worker profiles but does not guarantee availability, quality, or results'),
          _bullet(
              'All agreements, pricing, and arrangements are made directly between you and the worker'),
          const SizedBox(height: 6),
          _highlight('Requests — Post Work or Service Jobs'),
          _bullet(
              'You may post requests for services that workers and professionals can respond to'),
          _bullet(
              'Requests must be lawful, genuine, and not misleading or offensive'),
          _bullet(
              'Triozy reserves the right to remove requests that violate these terms'),
          const SizedBox(height: 6),
          _highlight('Mates — Connect with People Nearby'),
          _bullet(
              'Mates allows you to connect with people in your local area for community purposes'),
          _bullet(
              'Connections must be used respectfully — harassment or misuse will result in account suspension'),
          _bullet(
              'Do not use Mates for spam, solicitation, or commercial purposes without consent'),
        ]),
        _section('3', 'Worker Listings & Verification', [
          _body(
              'Triozy performs basic identity checks but cannot guarantee every worker profile is 100% verified. '
              'Users are encouraged to review profiles, ratings, and conduct due diligence before engaging.'),
          _bullet(
              'Workers may optionally undergo identity or credential verification'),
          _bullet(
              'Verified badges indicate a completed check — not an endorsement by Triozy'),
          _bullet(
              'Falsifying credentials or reviews is strictly prohibited and may result in permanent ban'),
        ]),
        _section('4', 'Fees & Payments', [
          _body(
              'Triozy is free for users to browse and connect. Certain features may carry optional fees.'),
          _bullet(
              'Worker subscriptions may be required to receive leads or boost visibility'),
          _bullet(
              'Direct payments for services are made between the user and the worker — Triozy is not a party to those transactions'),
          _bullet(
              'Any in-app purchases are processed via secure third-party payment providers'),
          _highlight(
              'Triozy charges zero commission on worker-user transactions.'),
        ]),
        _section('5', 'Prohibited Conduct', [
          _body('You must NOT:'),
          _bullet(
              'Provide false, misleading, or fraudulent information in profiles, requests, or reviews'),
          _bullet(
              'Harass, threaten, discriminate against, or abuse any user or worker'),
          _bullet(
              'Use the platform for illegal activities, scams, or unsolicited marketing'),
          _bullet(
              'Scrape, reverse-engineer, or attempt to access platform data without permission'),
          _bullet(
              'Create fake reviews, ratings, or impersonate another person or business'),
          _highlight(
              'Violations may result in immediate account suspension or permanent ban.',
              isWarning: true),
        ]),
        _section('6', 'Content & Intellectual Property', [
          _body(
              'You retain ownership of content you submit (profile info, photos, requests). '
              'By posting, you grant Triozy a non-exclusive licence to display that content within the platform.'),
          _bullet(
              'Do not post content that infringes copyright, trademarks, or privacy rights of others'),
          _bullet(
              'Triozy\'s branding, design, and code are protected intellectual property'),
        ]),
        _section('7', 'Disclaimer & Liability', [
          _body(
              'Triozy is a marketplace platform. We connect users and workers but do not directly provide any service.'),
          _bullet(
              'We are not liable for the quality, safety, or outcome of any service delivered by a worker'),
          _bullet(
              'We are not responsible for disputes, damages, or losses arising from user-worker interactions'),
          _bullet(
              'Use of the Mates feature is entirely at your own discretion and risk'),
        ]),
        _section('8', 'Changes & Termination', [
          _body(
              'We may update these Terms at any time. Changes will be notified via the app or email. '
              'Continued use after changes constitutes acceptance.'),
          _body(
              'We reserve the right to suspend or terminate any account that violates these Terms '
              'without prior notice.'),
        ]),
        _section('9', 'Contact', [
          _body('For questions or disputes regarding these Terms:'),
          _highlight('support@triozy.in'),
        ]),
      ];

  // ── Privacy Policy ──────────────────────────────────────────────────────────

  List<Widget> _privacyContent() => [
        _intro(
          'Triozy is built on trust. This Privacy Policy explains what data we collect, '
          'why we collect it, how we use it, and your rights over it. '
          'Our platform — Workers, Requests, and Mates — requires certain data to function well. '
          'We collect only what is necessary.',
        ),
        _section('1', 'Data We Collect', [
          _body('When you use Triozy, we may collect:'),
          _bullet('Identity: name, profile photo, email address'),
          _bullet(
              'Contact: phone number (optional, for direct worker-user calls)'),
          _bullet(
              'Location: your approximate or precise location to match nearby workers, requests, and mates'),
          _bullet(
              'Usage: pages visited, searches performed, features used, session duration'),
          _bullet(
              'Device: device model, OS version, app version, unique device identifiers'),
          _bullet(
              'Workers: service category, service area, availability, portfolio photos, subscription status'),
          _bullet(
              'Requests: job title, description, category, location, and any attached media'),
        ]),
        _section('2', 'How We Use Your Data', [
          _highlight('Workers Pillar'),
          _bullet(
              'To show your profile to users searching for your service in your area'),
          _bullet(
              'To notify you of matching service requests in real time'),
          _bullet(
              'To manage your subscription and lead access'),
          const SizedBox(height: 6),
          _highlight('Requests Pillar'),
          _bullet(
              'To surface your request to relevant workers nearby'),
          _bullet(
              'To allow workers to contact you directly via call or chat'),
          const SizedBox(height: 6),
          _highlight('Mates Pillar'),
          _bullet(
              'To show nearby users you can connect with based on proximity'),
          _bullet(
              'To facilitate safe, community-driven local connections'),
          const SizedBox(height: 6),
          _body('Across all pillars, we also use data to:'),
          _bullet('Personalise your experience and surface relevant content'),
          _bullet('Investigate abuse, fraud, or violations of our Terms'),
          _bullet('Improve app performance, fix bugs, and develop new features'),
        ]),
        _section('3', 'Permissions', [
          _body('Triozy may request the following device permissions:'),
          _bullet(
              'Location (required) — to match workers, requests, and mates near you'),
          _bullet(
              'Camera / Photo Library (optional) — for uploading profile photos or portfolio images'),
          _bullet(
              'Phone (optional) — to enable one-tap direct calls to workers'),
          _body(
              'Permissions are only requested when you use the relevant feature. '
              'You can revoke permissions at any time in your device settings.'),
        ]),
        _section('4', 'Third-Party Services', [
          _body('Triozy uses trusted services to power its infrastructure:'),
          _bullet(
              'Firebase (Google) — authentication, database, push notifications, analytics'),
          _bullet(
              'Google Sign-In — secure, password-free account creation'),
          _bullet(
              'Google Maps / Geolocation — worker and request proximity matching'),
          _bullet(
              'Payment providers (e.g., Razorpay) — secure subscription billing for workers'),
          _body(
              'Each provider operates under their own privacy policy. We recommend reviewing them.'),
        ]),
        _section('5', 'Data Sharing', [
          _body('We share data only in the following circumstances:'),
          _bullet(
              'With workers — your request details and contact info when you choose to connect'),
          _bullet(
              'With users — a worker\'s profile, rating, and contact when you search'),
          _bullet(
              'With payment providers — billing info strictly for subscription processing'),
          _bullet(
              'With legal authorities — when required by applicable law or court order'),
          _highlight(
              'We do NOT sell, rent, or trade your personal data to advertisers or data brokers.'),
        ]),
        _section('6', 'Location Data', [
          _body(
              'Location is central to Triozy\'s value — it powers all three pillars. '
              'We use location to match you with the most relevant workers, requests, and mates nearby.'),
          _bullet(
              'Precise location is used only when the app is active in the foreground'),
          _bullet(
              'We do not track your location in the background without explicit consent'),
          _bullet(
              'Location data is never shared with third parties for advertising purposes'),
        ]),
        _section('7', 'Data Retention', [
          _body(
              'We retain your data for as long as your account is active or as needed to provide services. '
              'Inactive accounts may be purged after 24 months. '
              'You can request deletion at any time.'),
        ]),
        _section('8', 'Your Rights', [
          _body('You have the right to:'),
          _bullet('Access the personal data we hold about you'),
          _bullet('Correct inaccurate or outdated information'),
          _bullet('Request deletion of your account and associated data'),
          _bullet(
              'Withdraw consent for optional data processing (e.g., marketing communications)'),
          _body(
              'To exercise any of these rights, contact us at support@triozy.in. '
              'We will respond within 14 working days.'),
        ]),
        _section("9", "Children's Privacy", [
          _body(
              'Triozy is intended for users aged 18 and above. '
              'We do not knowingly collect data from anyone under 13. '
              'If we become aware of such data, it will be promptly deleted.'),
        ]),
        _section('10', 'Security', [
          _body(
              'We implement industry-standard security measures including encryption in transit (TLS), '
              'secure authentication via Google, and access controls on our backend. '
              'While no system is completely immune to attack, we continuously improve our defences.'),
        ]),
        _section('11', 'Policy Changes', [
          _body(
              'We may update this Privacy Policy to reflect changes in our practices or regulations. '
              'We will notify you via the app or email before significant changes take effect. '
              'Continued use after the update constitutes acceptance of the revised policy.'),
        ]),
        _section('12', 'Contact', [
          _body(
              'For privacy concerns, data requests, or to report a concern:'),
          _highlight('support@triozy.in'),
        ]),
      ];
}
