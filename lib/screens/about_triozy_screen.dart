import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

class AboutTriozyScreen extends StatefulWidget {
  const AboutTriozyScreen({super.key});

  @override
  State<AboutTriozyScreen> createState() => _AboutTriozyScreenState();
}

class _AboutTriozyScreenState extends State<AboutTriozyScreen> {
  late Future<PackageInfo> _packageInfoFuture;

  @override
  void initState() {
    super.initState();
    _packageInfoFuture = PackageInfo.fromPlatform();
  }

  Future<void> _launchUrl(String rawUrl) async {
    final uri = Uri.parse(rawUrl);
    try {
      final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!launched) throw Exception('Could not launch');
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open link.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3F0FB),
      appBar: AppBar(
        title: const Text('About Triozy', style: TextStyle(color: Color(0xFF3D1F8C))),
        backgroundColor: const Color(0xFFEDE8F9),
        elevation: 0,
        iconTheme: const IconThemeData(color: Color(0xFF5E35B1)),
      ),
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 24),
            Center(
              child: Column(
                children: [
                  // Logo or fallback avatar
                  CircleAvatar(
                    radius: 52,
                    backgroundColor: const Color(0xFF5E35B1),
                    child: const Text(
                      'T',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 32,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Triozy',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF3D1F8C),
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Your all-in-one app for city movers',
                    style: TextStyle(
                      fontSize: 14,
                      color: Color(0xFF9E8FBF),
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFE0D7F5), width: 0.5),
                ),
                child: Column(
                  children: [
                    // App Version row
                    FutureBuilder<PackageInfo>(
                      future: _packageInfoFuture,
                      builder: (context, snap) {
                        Widget trailing;
                        if (snap.connectionState == ConnectionState.waiting) {
                          trailing = const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          );
                        } else if (snap.hasError) {
                          trailing = const Text('v1.0.0+14', style: TextStyle(color: Color(0xFF2D2D2D)));
                        } else {
                          final version = snap.data?.version?.isNotEmpty == true ? snap.data!.version : '2.3.1';
                          final buildNumber = snap.data?.buildNumber?.isNotEmpty == true ? snap.data!.buildNumber : '1';
                          trailing = Text(
                            'v$version+$buildNumber',
                            style: const TextStyle(color: Color(0xFF2D2D2D)),
                          );
                        }

                        return ListTile(
                          leading: const Icon(Icons.phone_android_outlined, color: Color(0xFF7C5CBF)),
                          title: const Text('App Version', style: TextStyle(color: Color(0xFF2D2D2D))),
                          trailing: trailing,
                        );
                      },
                    ),
                    const Divider(height: 1, thickness: 0.5, color: Color(0xFFF0ECFA)),
                    ListTile(
                      leading: const Icon(Icons.apartment_outlined, color: Color(0xFF7C5CBF)),
                      title: const Text('Developed by', style: TextStyle(color: Color(0xFF2D2D2D))),
                      trailing: const Text('Triozy Team', style: TextStyle(color: Color(0xFF2D2D2D))),
                    ),
                    const Divider(height: 1, thickness: 0.5, color: Color(0xFFF0ECFA)),
                    ListTile(
                      onTap: () => _launchUrl('https://triozy.com'),
                      leading: const Icon(Icons.language_outlined, color: Color(0xFF7C5CBF)),
                      title: const Text('Website', style: TextStyle(color: Color(0xFF2D2D2D))),
                      trailing: const Text('triozy.com', style: TextStyle(color: Color(0xFF7C5CBF))),
                    ),
                    const Divider(height: 1, thickness: 0.5, color: Color(0xFFF0ECFA)),
                    ListTile(
                      onTap: () => _launchUrl('https://www.linkedin.com/company/triozy/'),
                      leading: const Icon(Icons.work_outline, color: Color(0xFF7C5CBF)),
                      title: const Text('LinkedIn', style: TextStyle(color: Color(0xFF2D2D2D))),
                      trailing: const Text('Triozy', style: TextStyle(color: Color(0xFF7C5CBF))),
                    ),
                  ],
                ),
              ),
            ),
            const Spacer(),
            Padding(
              padding: const EdgeInsets.only(bottom: 24.0),
              child: Text(
                'Made with ❤️ for city movers',
                style: const TextStyle(fontSize: 12, color: Color(0xFFB0A0D0)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
