import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';

class SearchResultsScreen extends StatelessWidget {
  final String initialQuery;

  const SearchResultsScreen({super.key, required this.initialQuery});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text('Search', style: AppTheme.headline(fontSize: 20)),
        backgroundColor: AppColors.background,
        surfaceTintColor: Colors.transparent,
      ),
      body: const Center(
        child: Text('Search Results Screen'),
      ),
    );
  }
}