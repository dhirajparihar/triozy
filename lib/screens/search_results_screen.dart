import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';


// === Search results ==========================================================

/// Placeholder screen for global search results.
class SearchResultsScreen extends StatelessWidget {
  /// Pre-filled query from the originating search entry point.
  final String initialQuery;

  const SearchResultsScreen({super.key, required this.initialQuery});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        // Keep header minimal until search UI is implemented.
        title: Text('Search', style: AppTheme.headline(fontSize: 20)),
        backgroundColor: AppColors.background,
        surfaceTintColor: Colors.transparent,
      ),
      body: const Center(
        // Placeholder view until search results are wired up.
        child: Text('Search Results Screen'),
      ),
    );
  }
}