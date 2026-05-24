import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';

enum PolicyType { terms, privacy }

/// Policy screen displaying Terms of Service or Privacy Policy in formatted layout.
class PolicyScreen extends StatelessWidget {
  final PolicyType type;
  const PolicyScreen({super.key, required this.type});

  @override
  Widget build(BuildContext context) {
    final isTerms = type == PolicyType.terms;
    // Switch header gradient color based on policy type (blue for terms, green for privacy).
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          // ── Fixed App Bar with Gradient Background ──────────────────────
          Container(
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
              borderRadius: const BorderRadius.vertical(bottom: Radius.circular(20)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.15),
                  blurRadius: 20,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        IconButton(
                          icon: Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(Icons.arrow_back_rounded,
                                size: 18, color: Colors.white),
                          ),
                          onPressed: () => Navigator.of(context).pop(),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                isTerms ? 'Terms of Service' : 'Privacy Policy',
                                style: GoogleFonts.inter(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white,
                                  letterSpacing: -0.4,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Last updated: May 25, 2026',
                                style: GoogleFonts.inter(
                                  fontSize: 11,
                                  color: Colors.white.withValues(alpha: 0.65),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Icon(
                            isTerms
                                ? Icons.gavel_rounded
                                : Icons.shield_rounded,
                            size: 22,
                            color: Colors.white,
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
          Expanded(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 64),
              child: Column(
                children: isTerms ? _termsContent() : _privacyContent(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Builder helpers ─────────────────────────────────────────────────────────

  /// Intro box with background and border for policy overview.
  Widget _intro(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 28),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.surfaceContainerLow,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.outlineVariant, width: 1),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ],
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

  /// Numbered section with title and child widgets (builder for policy sections).
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

  /// Standard policy paragraph styling.
  Widget _body(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(
          text,
          style: AppTheme.body(
              fontSize: 14, color: AppColors.onSurfaceVariant, height: 1.65),
        ),
      );

  /// Bullet row used for policy lists.
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

  /// Highlighted callout used for important policy notes.
  Widget _highlight(String text, {bool isWarning = false}) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: isWarning
                ? AppColors.errorContainer.withValues(alpha: 0.4)
                : AppColors.secondaryContainer.withValues(alpha: 0.25),
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
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

  /// Full Terms of Service content tree.
  List<Widget> _termsContent() => [
        _intro(
          'Welcome to Triozy — the all-in-one solution for city movers. '
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
        _section('2', 'Our Core Services', [
          _body(
              'Triozy provides a platform to facilitate your move and settlement in a new city. Your use of each feature is subject to the following:'),
          const SizedBox(height: 8),
          _highlight('Accommodations & Flatmates'),
          _bullet(
              'Triozy allows users to list and search for PGs, hostels, flats, and flatmates'),
          _bullet(
              'We do not own, manage, or endorse any properties listed. All rental agreements and disputes are strictly between the user and the lister/landlord'),
          const SizedBox(height: 6),
          _highlight('Marketplace (2nd Hand Items)'),
          _bullet(
              'Users can buy and sell second-hand goods (e.g., furniture, utensils)'),
          _bullet(
              'Triozy is not a party to these transactions. We do not handle shipping, payment processing for items, or guarantee the quality/safety of goods sold'),
          const SizedBox(height: 6),
          _highlight('Essential Services (Maids & Tiffins)'),
          _bullet(
              'We list independent local service providers for household chores and food delivery'),
          _bullet(
              'Triozy does not prepare food or employ maids. We are not liable for the quality of food, health concerns, or the conduct of independent providers'),
        ]),
        _section('3', 'Interactions & Payments', [
          _body(
              'Triozy connects you with resources, but transactions happen offline or via direct user-to-user agreement.'),
          _bullet(
              'Direct payments for rent, marketplace items, and services are made directly between users — Triozy is not liable for lost funds or scams'),
          _bullet(
              'Always exercise caution and verify items or properties in person before transferring money'),
        ]),
        _section('4', 'Prohibited Conduct', [
          _body('You must NOT:'),
          _bullet(
              'Post fraudulent property listings or counterfeit/stolen marketplace items'),
          _bullet(
              'Harass, threaten, or abuse any user, landlord, or service provider'),
          _bullet(
              'Use the platform for unsolicited marketing or illegal activities'),
          _bullet(
              'Scrape, reverse-engineer, or attempt to access platform data without permission'),
          _highlight(
              'Violations may result in immediate account suspension or permanent ban.',
              isWarning: true),
        ]),
        _section('5', 'Content & Intellectual Property', [
          _body(
              'You retain ownership of content you submit (listings, photos, requests). '
              'By posting, you grant Triozy a non-exclusive licence to display that content within the platform.'),
          _bullet(
              'Do not post content that infringes copyright, trademarks, or privacy rights of others'),
          _bullet(
              'Triozy\'s branding, design, and code are protected intellectual property'),
        ]),
        _section('6', 'Disclaimer & Liability', [
          _body(
              'Triozy is a discovery platform. We do not directly provide housing, goods, or services.'),
          _bullet(
              'We are not liable for the condition of rental properties, the safety of marketplace transactions, or the quality of independent services'),
          _bullet(
              'We are not responsible for disputes, damages, or losses arising from user-to-user interactions'),
        ]),
        _section('7', 'Changes & Termination', [
          _body(
              'We may update these Terms at any time. Changes will be notified via the app or email. '
              'Continued use after changes constitutes acceptance.'),
          _body(
              'We reserve the right to suspend or terminate any account that violates these Terms '
              'without prior notice.'),
        ]),
        _section('8', 'Contact', [
          _body('For questions or disputes regarding these Terms:'),
          _highlight('triozyapp@gmail.com'),
        ]),
      ];

  // ── Privacy Policy ──────────────────────────────────────────────────────────

  /// Full Privacy Policy content tree.
  List<Widget> _privacyContent() => [
        _intro(
          'Triozy is built to make moving to a new city seamless. '
          'This Privacy Policy explains what data we collect to power our Accommodations, Marketplace, and Services features, '
          'and how we protect it. We collect only what is necessary.',
        ),
        _section('1', 'Data We Collect', [
          _body('When you use Triozy, we may collect:'),
          _bullet('Identity: name, profile photo, email address'),
          _bullet(
              'Contact: phone number (optional, for direct connections)'),
          _bullet(
              'Location: approximate or precise location to show you relevant local properties, items, and services'),
          _bullet(
              'Listings: photos, prices, descriptions, and addresses of properties or marketplace items you choose to upload'),
          _bullet(
              'Usage: pages visited, searches performed, features used, session duration'),
          _bullet(
              'Device & Usage: device model, app version, unique identifiers and feature usage to improve performance'),
        ]),
        _section('2', 'How We Use Your Data', [
          _highlight('Accommodations & Marketplace'),
          _bullet(
              'To display your property or item listings to users in your specific city or area'),
          _bullet(
              'To allow interested buyers or tenants to contact you'),
          const SizedBox(height: 6),
          _highlight('Essential Services'),
          _bullet(
              'To match you with nearby tiffin providers and cleaning services'),
          const SizedBox(height: 6),
          _body('Across the app, we also use data to:'),
          _bullet('Personalise your experience and surface relevant content'),
          _bullet('Investigate fraud, maintain safety, and fix bugs'),
        ]),
        _section('3', 'Permissions', [
          _body('Triozy may request the following device permissions:'),
          _bullet(
              'Location (required) — to ensure you only see listings and services relevant to your new city'),
          _bullet(
              'Camera / Photo Library (optional) — for uploading profile pictures or photos of marketplace items/properties'),
          _bullet(
              'Phone (optional) — to enable one-tap direct calls to sellers, landlords, or service providers'),
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
              'Google Maps / Geolocation — proximity matching for properties and services'),
          _body(
              'Each provider operates under their own privacy policy. We recommend reviewing them.'),
        ]),
        _section('5', 'Data Sharing', [
          _body('We share data only to make the app work for you:'),
          _bullet(
              'Publicly on the platform: details of items or properties you actively choose to list'),
          _bullet(
              'With users: your contact info when you mutually agree to connect for a listing or service'),
          _bullet(
              'With legal authorities: strictly when required by law or court order'),
          _highlight(
              'We do NOT sell, rent, or trade your personal data to advertisers or data brokers.'),
        ]),
        _section('6', 'Location Data', [
          _body(
              'Location is central to finding local housing and goods. '
              'Precise location is used only when the app is active in the foreground. We do not track your location in the background.'),
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
          _bullet('Access, correct, or delete the personal data we hold about you'),
          _bullet(
              'Request complete deletion of your account via in-app settings or email'),
          _bullet(
              'Withdraw consent for optional data processing (e.g., marketing communications)'),
          _body(
              'To exercise any of these rights, contact us at triozyapp@gmail.com. '
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
          _highlight('triozyapp@gmail.com'),
        ]),
      ];
}