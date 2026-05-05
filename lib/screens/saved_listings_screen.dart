import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/listing_model.dart';
import '../services/database_service.dart';
import '../theme/app_theme.dart';
import '../widgets/listing_card.dart';
import 'listing_detail_screen.dart';

class SavedListingsScreen extends StatelessWidget {
  const SavedListingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) {
      return const Scaffold(body: Center(child: Text('Sign in to save listings')));
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Saved Items'),
        backgroundColor: Colors.white,
      ),
      body: FutureBuilder<List<ListingModel>>(
        future: context.read<DatabaseService>().getSavedListings(userId),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final listings = snapshot.data ?? const <ListingModel>[];
          if (listings.isEmpty) {
            return Center(
              child: Text(
                'No saved items yet',
                style: AppTheme.body(fontSize: 16, fontWeight: FontWeight.w600),
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(20),
            itemCount: listings.length,
            separatorBuilder: (_, _) => const SizedBox(height: 16),
            itemBuilder: (context, index) {
              final listing = listings[index];
              return ListingCard(
                listing: listing,
                compact: true,
                isSaved: true,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          ListingDetailScreen(listingId: listing.id, seed: listing),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}
