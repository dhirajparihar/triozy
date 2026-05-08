import 'package:flutter/material.dart';

import '../models/listing_model.dart';
import 'search_results_screen.dart';

class MarketplaceScreen extends StatelessWidget {
  const MarketplaceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const SearchResultsScreen(
      title: 'Marketplace',
      subtitle:
          'Browse furniture, appliances, study setups, and move-in essentials from people nearby.',
      searchHint: 'Search furniture, appliances, desks, chairs or essentials',
      initialPropertyType: PropertyType.item,
      lockedType: ListingType.marketplace,
      showCreateListingButton: true,
      createListingPropertyType: PropertyType.item,
      createListingPurpose: ListingPurpose.marketplaceSell,
    );
  }
}
