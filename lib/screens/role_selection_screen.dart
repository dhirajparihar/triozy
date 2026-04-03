import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../services/auth_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'main_shell.dart';
import 'worker_setup_screen.dart';

class RoleSelectionScreen extends StatefulWidget {
  const RoleSelectionScreen({super.key});

  @override
  State<RoleSelectionScreen> createState() => _RoleSelectionScreenState();
}

class _RoleSelectionScreenState extends State<RoleSelectionScreen> {
  late final AuthService _authService;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _authService = context.read<AuthService>();
  }

  Future<void> _selectRole(String role) async {
    setState(() => _isLoading = true);
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      await _authService.saveUser(
        uid: user.uid,
        name: user.displayName ?? '',
        email: user.email ?? '',
        role: role,
        photoUrl: user.photoURL,
      );

      if (!mounted) return;

      if (role == 'worker') {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const WorkerSetupScreen()),
        );
      } else {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const MainShell()),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.error),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 48),
          child: Column(
            children: [
              // Brand
              Text(
                'Triozy',
                style: AppTheme.headline(
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                  color: AppColors.primary,
                  letterSpacing: -1.5,
                ),
              ),
              const SizedBox(height: 40),

              // Headline
              Text(
                'How would you like\nto use Triozy?',
                style: AppTheme.headline(
                  fontSize: 36,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.5,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                'Select your path to continue with your personalized experience.',
                style: AppTheme.body(
                  fontSize: 16,
                  color: AppColors.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 48),

              // Customer Card
              _RoleCard(
                icon: Icons.person,
                iconBgColor: AppColors.primaryFixed,
                iconColor: AppColors.primary,
                title: 'I want a service',
                description:
                    'Browse verified professionals, schedule appointments, and manage your bookings in one place.',
                ctaText: 'Sign up as Customer',
                ctaColor: AppColors.primary,
                onTap: _isLoading ? null : () => _selectRole('customer'),
              ),
              const SizedBox(height: 20),

              // Provider Card
              _RoleCard(
                icon: Icons.engineering,
                iconBgColor: AppColors.secondaryContainer,
                iconColor: AppColors.onSecondaryContainer,
                title: 'I provide service',
                description:
                    'Grow your business, reach more clients, and manage your professional schedule effortlessly.',
                ctaText: 'Sign up as Provider',
                ctaColor: AppColors.secondary,
                onTap: _isLoading ? null : () => _selectRole('worker'),
              ),

              const SizedBox(height: 48),

              // Footer avatars
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 110,
                    height: 40,
                    child: Stack(
                      children: [
                        _fAvatar(0, 'https://lh3.googleusercontent.com/aida-public/AB6AXuCr2DeV0aF9b8u_5la_zt65-uK0CVs6YF9PEf1R7rNLj4U5-NctEyrL8tSf2-qJt4uYmkiFWqhOWtz6X9U90ryrhaiRvpO-J56XupLSDfYjy-ONDLe9ICEF9dC7UfTV24dAzz72-7ifIIEy0RbKQqwrtjQLpQPXv5dEyzOC9eGrPxSSgUQ6WnOOlQAeY-I92fZfNK4xkIHZCUPnPyiuQbPIFwj9Nzx7C3S-1GERRRHAuEaae6LOTPeD7K-PJhhFfWmqNJSot-PQtVA'),
                        _fAvatar(28, 'https://lh3.googleusercontent.com/aida-public/AB6AXuA6RXzQJqCng2qbVoc9vUDbosIQtB0gQ_1x06LdGajTL68BPmJTRSKWENSOPNVjj_LUHw3lmXPeRcPc59DNXDNjIDDRUsoDm4p-3KX8SumnUcWRHUM6SFWFu_F3wPvsG3F91bhY6W_o0LsR49bG-C-UjTDAMf5AhafMU8ryRnDRPP_3bHGTwkD0NmkvPZb5zAQLU9MrwYM-jLjpdc9CSWborWGionPocasHPOs9FgEDg9ns1_nVqXyP9sFlrMC4Rqvg-ACkPqMNDM4'),
                        _fAvatar(56, 'https://lh3.googleusercontent.com/aida-public/AB6AXuDCYEsdadIaDot95thymJbwFpvQkSDv38h9EnqgYdfnTdeCjSbg9OjEp-hi7mkFrKLMiky6kFvndTtahzJ6wCxIjShoXBIhgn7ZDzaM7vi8vHmQ-VNS7aiBZVlo6jprOZdXRzChjtYnJCVuKIQ4LhDgBjHPC2Z3gozIuGwk9d9-j3ybcelOoUPc6tmTdq6D47q8DbHdUQxBLNzDzMaXfb661uSfhgkcr9UJtkYEJIEJzOaKs69W72cMsHxx-xwj72j4uG9JG8ku1wo'),
                        Positioned(
                          left: 80,
                          child: Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: AppColors.surfaceContainerHigh,
                              border: Border.all(color: AppColors.background, width: 3),
                            ),
                            child: Center(
                              child: Text('10k+',
                                  style: AppTheme.body(
                                      fontSize: 9,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.onSurfaceVariant)),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                'Joined by over 10,000 users this month',
                style: AppTheme.body(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: AppColors.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _fAvatar(double left, String url) {
    return Positioned(
      left: left,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: AppColors.background, width: 3),
        ),
        child: ClipOval(
          child: Image.network(url, fit: BoxFit.cover,
              errorBuilder: (_, _, _) => Container(color: AppColors.surfaceContainerHigh)),
        ),
      ),
    );
  }
}

class _RoleCard extends StatelessWidget {
  final IconData icon;
  final Color iconBgColor;
  final Color iconColor;
  final String title;
  final String description;
  final String ctaText;
  final Color ctaColor;
  final VoidCallback? onTap;

  const _RoleCard({
    required this.icon,
    required this.iconBgColor,
    required this.iconColor,
    required this.title,
    required this.description,
    required this.ctaText,
    required this.ctaColor,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(28),
        decoration: BoxDecoration(
          color: AppColors.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.transparent, width: 2),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: iconBgColor,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(icon, color: iconColor, size: 28),
            ),
            const SizedBox(height: 28),
            Text(title, style: AppTheme.headline(fontSize: 22)),
            const SizedBox(height: 8),
            Text(
              description,
              style: AppTheme.body(
                fontSize: 14,
                color: AppColors.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 28),
            Row(
              children: [
                Text(ctaText,
                    style: AppTheme.body(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: ctaColor)),
                const SizedBox(width: 8),
                Icon(Icons.arrow_forward, size: 20, color: ctaColor),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
