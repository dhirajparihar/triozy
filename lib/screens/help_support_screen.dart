import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';

class HelpSupportScreen extends StatelessWidget {
  const HelpSupportScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          'Help & Support',
          style: AppTheme.headline(fontSize: 20, fontWeight: FontWeight.w700),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(color: AppColors.onSurface),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Contact card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.3),
                    blurRadius: 24,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Column(
                children: [
                  const Icon(Icons.headset_mic, size: 48, color: Colors.white),
                  const SizedBox(height: 16),
                  Text(
                    'Need help?',
                    style: AppTheme.headline(fontSize: 24, color: Colors.white),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Our support team is available 24/7 to assist you.',
                    textAlign: TextAlign.center,
                    style: AppTheme.body(
                      fontSize: 14,
                      color: Colors.white.withValues(alpha: 0.8),
                    ),
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton.icon(
                    onPressed: () async {
                      final uri = Uri(
                        scheme: 'mailto',
                        path: 'triozyapp@gmail.com',
                      );
                      if (await canLaunchUrl(uri)) {
                        await launchUrl(uri);
                      }
                    },
                    icon: const Icon(Icons.email_outlined, size: 20),
                    label: Text(
                      'triozyapp@gmail.com',
                      style: AppTheme.body(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primary,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: AppColors.primary,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 14,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(9999),
                      ),
                      elevation: 0,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),

            Text(
              'FREQUENTLY ASKED QUESTIONS',
              style: AppTheme.headline(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: AppColors.onSurfaceVariant,
                letterSpacing: 2.0,
              ),
            ),
            const SizedBox(height: 16),

            _FaqTile(
              question: 'How do I find PGs or flatmates?',
              answer:
                  'Browse available PGs and flatmate listings based on your location, budget, and preferences. You can directly contact the owner or roommate through the app.',
            ),

            _FaqTile(
              question: 'How do I post my PG or flat for others?',
              answer:
                  'Go to the relevant section and tap the add icon. Add photos, rent details, location, and a short description to publish your listing.',
            ),

            _FaqTile(
              question: 'How does the marketplace work?',
              answer:
                  'The marketplace allows users to buy and sell items locally. You can post products, browse listings, and connect directly with buyers or sellers.',
            ),

            _FaqTile(
              question: 'Is Triozy available in my city?',
              answer:
                  'Triozy is expanding continuously. Enable location access to explore nearby PGs, flatmates, and marketplace listings available in your area.',
            ),

            _FaqTile(
              question: 'How do I contact a seller or flatmate?',
              answer:
                  'Open the listing or profile and use the available contact or chat option to connect directly with the person.',
            ),

            _FaqTile(
              question: 'Is posting on Triozy free?',
              answer:
                  'Yes, posting PGs, flatmate listings, and marketplace items is currently free for users.',
            ),

            const SizedBox(height: 32),

            Text(
              'REACH US',
              style: AppTheme.headline(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: AppColors.onSurfaceVariant,
                letterSpacing: 2.0,
              ),
            ),
            const SizedBox(height: 16),

            _contactTile(Icons.phone_outlined, 'Call Us', '+91 98765 43210'),
            const SizedBox(height: 8),
            _contactTile(Icons.email_outlined, 'Email', 'triozyapp@gmail.com'),
            const SizedBox(height: 8),
            _contactTile(Icons.language, 'Website', 'www.triozy.com'),

            const SizedBox(height: 80),
          ],
        ),
      ),
    );
  }

  Widget _contactTile(IconData icon, String title, String subtitle) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.outlineVariant.withValues(alpha: 0.15),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.blue50,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: AppColors.primary, size: 20),
          ),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: AppTheme.body(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.outline,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: AppTheme.body(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppColors.onSurface,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _FaqTile extends StatefulWidget {
  final String question;
  final String answer;

  const _FaqTile({required this.question, required this.answer});

  @override
  State<_FaqTile> createState() => _FaqTileState();
}

class _FaqTileState extends State<_FaqTile> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => setState(() => _expanded = !_expanded),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: _expanded
                ? AppColors.primary.withValues(alpha: 0.25)
                : AppColors.outlineVariant.withValues(alpha: 0.15),
            width: _expanded ? 1.5 : 1,
          ),
          boxShadow: [
            if (_expanded)
              BoxShadow(
                color: AppColors.primary.withValues(alpha: 0.04),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    widget.question,
                    style: AppTheme.body(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                AnimatedRotation(
                  turns: _expanded ? 0.5 : 0,
                  duration: const Duration(milliseconds: 250),
                  child: const Icon(
                    Icons.expand_more,
                    color: AppColors.primary,
                  ),
                ),
              ],
            ),
            if (_expanded) ...[
              const SizedBox(height: 12),
              Text(
                widget.answer,
                style: AppTheme.body(
                  fontSize: 14,
                  color: AppColors.onSurfaceVariant,
                  height: 1.6,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
