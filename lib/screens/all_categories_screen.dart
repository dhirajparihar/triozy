import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'dart:ui';
import 'package:cached_network_image/cached_network_image.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import 'worker_list_screen.dart';

class _ServiceItem {
  final String name;
  final String imageUrl;
  final List<String> tags;

  _ServiceItem({
    required this.name,
    required this.imageUrl,
    this.tags = const [],
  });

  bool matches(String query) {
    if (name.toLowerCase().contains(query)) return true;
    return tags.any((t) => t.toLowerCase().contains(query));
  }
}

class _ServiceSection {
  final String title;
  final String subtitle;
  final Color subtitleColor;
  final List<_ServiceItem> items;

  _ServiceSection({
    required this.title,
    required this.subtitle,
    required this.subtitleColor,
    required this.items,
  });
}

class AllCategoriesScreen extends StatefulWidget {
  const AllCategoriesScreen({super.key});

  @override
  State<AllCategoriesScreen> createState() => _AllCategoriesScreenState();
}

class _AllCategoriesScreenState extends State<AllCategoriesScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _query = '';
  String _selectedSection = 'All';
  bool _popularOnly = false;
  String? _pressedCardName;

  static const Set<String> _popularServices = {
    'Electrician',
    'Plumber',
    'AC Repair',
    'Cleaning',
    'Car Taxi',
    'Personal Driver',
    'Makeup Artist',
  };

  static const Set<String> _newServices = {'Stock Advisor', 'Solar Services'};

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  static final List<_ServiceSection> _sections = [
    _ServiceSection(
      title: 'Home Maintenance',
      subtitle: '12 Services',
      subtitleColor: AppColors.primary,
      items: [
        _ServiceItem(
          name: 'Electrician',
          imageUrl:
              'https://lh3.googleusercontent.com/aida-public/AB6AXuC-eL5ZvDeISt0w2u0DR1osoZqXxH0DKO9YCBmoJAhw0zw5M0nULj0QcNh14z7RzMwC2sPi6Aw5aiepDhxhuKKZnQC-Y51TcineiQIlnhcD_oBbLntDbegJBXAYCB1K0jStkwbU_R9ek97RPWgz0d-2thTAO3CrR2h5Rq08mAZHz0GrsJqJs9CK5ta9Fe2kcH40uAUui3R5q258lfv3hmyDiVPgSiEJn-ebgr4tzXr1qkxamyYlrAqc-VFvw1k5pj7CZX54MfVIXGQ',
          tags: [
            'electric',
            'wiring',
            'wire',
            'power',
            'lights',
            'socket',
            'switchboard',
            'fuse',
            'electrical',
          ],
        ),
        _ServiceItem(
          name: 'Plumber',
          imageUrl:
              'https://lh3.googleusercontent.com/aida-public/AB6AXuCHB8HEtlkIngffZC4YxjMghwS577KPR9kJt0uUc07S5Mlm1qkPq2vSuAEn6cJgSZYYjeUbJI_Cvdx1qb8OjdWB86JZmvnlQ1301eq6gBoaDY8XQiGZk5dZjUfZg_X3UOHOgKkSspxgjxZ4bo2c0J-J7B6z5Ud7AS13btPeFC3wsglYjjxjQvw1kw2L0f34nm_nGTFDyvM-KkzyMCufsdX0sOJGBYpuikYwIpW6W_ztX6gRGhTf60sId5Fp74D0JEuqvh_TatgV8os',
          tags: [
            'pipe',
            'water',
            'leak',
            'drain',
            'tap',
            'toilet',
            'bathroom',
            'faucet',
            'pipeline',
          ],
        ),
        _ServiceItem(
          name: 'AC Repair',
          imageUrl:
              'https://lh3.googleusercontent.com/aida-public/AB6AXuCwJdWFNgZs5x6jOIZ_TD3QLZlaYKCr0IFVtFr-Y6js2VvkJvyM2Y4vCVnHNcl2X9uI9DXL0NpyIWgXl2bb0Rv05Yykpxk6ooavynLjBDx-dIahugWk8hDsFiqDkf8ocIn6Pv-AUPAzBAYehZCUa-Q73mbN9x_ZpMIpOxI-aRso0RGCdvpQZCqYaP40WrVLmn2Pbq7zdZXTDgIHaQcZfxBCSl0tk-AYg7n_q9PkfvOhRERWWfby5v6QHS_FLc_g81ixfPBcIiaTPQI',
          tags: [
            'air conditioner',
            'aircon',
            'cooling',
            'hvac',
            'air condition',
            'split ac',
            'service ac',
          ],
        ),
        _ServiceItem(
          name: 'Solar Services',
          imageUrl:
              'https://images.unsplash.com/photo-1509391366360-2e959784a276?w=400&q=80',
          tags: [
            'solar',
            'solar panel',
            'inverter',
            'renewable',
            'energy',
            'solar installation',
            'solar repair',
          ],
        ),
        _ServiceItem(
          name: 'Painter',
          imageUrl:
              'https://images.unsplash.com/photo-1562259949-e8e7689d7828?w=400&q=80',
          tags: [
            'painting',
            'paint',
            'wall paint',
            'house paint',
            'interior paint',
            'exterior paint',
            'putty',
            'wall texture',
          ],
        ),
        _ServiceItem(
          name: 'Carpenter',
          imageUrl:
              'https://lh3.googleusercontent.com/aida-public/AB6AXuBR59E38-pMAUc62Te_LJcTLWnxSabAyVkK6WzWryse7YKj6T9f-ULULojKFgAVoMMN__yHWs7_OCPEF64Dbeitg36hALWzXkeEFTBAzM_YKdp3ta28-Prr5R8ScejhPTDHdgaWetKX8eTaYEV8ny1y-Hw9Js4Xj5UUut_uArDZHPX8pV8DbthF1GmPBLuDyN1c6urVutSUcAyjC9Po4fxibNTTKCNONznABopB_J6F1-7VhqpPhsIP65j9U4KMxLGOvEX5QC256h0',
          tags: [
            'wood',
            'furniture',
            'door',
            'window',
            'cabinet',
            'woodwork',
            'shelf',
            'almirah',
          ],
        ),
        _ServiceItem(
          name: 'Tile Worker',
          imageUrl:
              'https://lh3.googleusercontent.com/aida-public/AB6AXuBw9MzXeN5MQ0cnjpQy0iJdJheQTau79c9n9MpL7XEVoCb4Au5abAD7oX_tokTuW-6P0hdbtt6rbFeCgaBsEGaOu2mkwhhsMofgTv5xz6cOj8Sks0fiBKoj6-1l0xhr9pm4zykry9aN6_bGg8xi1hp2LDnY72O9qNQKLKwlRdin5Odte4cIcrAz4W85K6H_xqZURGjBGwPdM2g8Y8HW4v2WNn3vLq9EL60OHlUDzfIQKMmtsjTvOHQd3PMR6ypTBrfw5j89HbN7SKo',
          tags: [
            'tiles',
            'flooring',
            'marble',
            'granite',
            'floor',
            'mosaic',
            'kitchen tiles',
            'bathroom tiles',
          ],
        ),
        _ServiceItem(
          name: 'Cleaning',
          imageUrl:
              'https://lh3.googleusercontent.com/aida-public/AB6AXuDPwfwKoxuNUrUCIA5XaU6YkT1mDUGRkcKWD3ZthjMw8S7TCAeOYmCc7vzIfvCu0rTOokppQ_iqrL3SaHZlcosZGQnzmxdtSLQYtC9IdFsia3ag5zbh4mcRmTrxFOxbaf4p2HhoZADeMClp1aKzPM9mG29Uw205KnC76EhPzP9_PAWC5Ja1PPwG44gWFyiRUJvSZ0WE7J7G6udOV6jkVaCU7YPag_gMf8Ay5Y5Y42HDS8oOKs4iO3VKIBNe-H3VwA46BnLoKurHUy4',
          tags: [
            'clean',
            'sweep',
            'mop',
            'dust',
            'housekeeping',
            'sanitize',
            'deep clean',
            'home clean',
          ],
        ),
        _ServiceItem(
          name: 'Cook',
          imageUrl:
              'https://lh3.googleusercontent.com/aida-public/AB6AXuBKW6YspQtlyL16TBJiYmx3RMB_z-mUwQuCDYKUVkjREH6fGUmZvhUPxfueBQZuo5QrIPTbERZ_est2TPfa7re4J9kEEVSBvaEwHoNdDFmRfHk0b6Ui-pR52ycN7U-xlK2KxQRKHSa5tsnismWqVDes_SR5WcbUwCo-XKfoK6zCrm0frCl_PB89_srfNi_lsUu8K0dJ9F4QSoz9zOGXqfl_ZV39knjkwxzkxGNsgxCDlKK8F5RytKNoA1xDPhSkh32A6oLnJR5uWcc',
          tags: [
            'housemaid',
            'domestic',
            'helper',
            'cook',
            'household',
            'bai',
            'servant',
            'naukrani',
          ],
        ),
        _ServiceItem(
          name: 'Security',
          imageUrl:
              'https://lh3.googleusercontent.com/aida-public/AB6AXuAF8RyOJAulwsVqIMGFJtXoJMKHDk7B7YBQFI9JRgo4eROLujLTmjz4wCP65MuGHrbvxuM6LcArAm78rns_C0kStbFyqD9a4K57O--J-ElPSTmg4fBX3gqyE9oIJtpfIH0baillLctWbdqxfFsNGNiyBd4uYxmWTL7y_7hfRDtB7mHPZJd_iMBucqU3BUlw-F6VGRsqhhPZF9EpXlRVLH0E6sjswjMnm4yb5xbx0tVLt5BzcwR_JP4EBh2MiMYNEQ8lGpl9oLpalZM',
          tags: [
            'guard',
            'watchman',
            'gatekeeper',
            'protection',
            'bouncer',
            'chowkidar',
            'security guard',
          ],
        ),
        _ServiceItem(
          name: 'Gardening',
          imageUrl:
              'https://lh3.googleusercontent.com/aida-public/AB6AXuC7xLSymgBC0zKuwIVZ9dQhRbLLQ5IjwbPDTxgXihEVMYF63msmSu68HjEx4sdp2i-beZvEXISuuY6NA8Ys24N0sSM0L4oUxbHxYk_UVK8Ks8cPmRJI3jE9UCSMcMxhtynaVo16F_3aoRpHVe357Sr9ZuLBBcf-oFOP5puDV1URXzb1yZZ90aeWB_GLvp6i3IDVM7cf6GX5kpIBQh7IQl57HMLKEhPfnXmmVGOXPVl5KL3_M_PzsxghQF7yofk6DEOEInUtwVdlADo',
          tags: [
            'garden',
            'plants',
            'lawn',
            'grass',
            'landscaping',
            'tree trimming',
            'flowers',
            'mali',
          ],
        ),
        _ServiceItem(
          name: 'Water Supplier',
          imageUrl:
              'https://images.unsplash.com/photo-1559827260-dc66d52bef19?w=400&q=80',
          tags: [
            'water',
            'water can',
            'water delivery',
            'drinking water',
            'mineral water',
            'water supply',
            'water tanker',
            'jar water',
          ],
        ),
      ],
    ),
    _ServiceSection(
      title: 'Transport & Logistics',
      subtitle: '4 Services',
      subtitleColor: AppColors.primary,
      items: [
        _ServiceItem(
          name: 'Car Taxi',
          imageUrl:
              'https://lh3.googleusercontent.com/aida-public/AB6AXuDfvVZB9psj8zwSNHefejj7PlM5g0HlIe59lqnrveTiYM82TLo8q_oGeSfMUt0pSmVMXUn_1pAjEa9AsFYShZDRjIHKoSMO9GsLnMJ4LHtd0PgpgMGxAoa4jHXwvGYIeT4fCHulsxfyWKiKm5uYdRz0S2aTsu_uScLqg7_NBK-nozZkd0BW3m4cSsguEZQlPA7zqKOTjQPzcSRm7cE9zoJkEvRsB0zy9J7FgvUMPZTaFfXNuA47w5gaInfPg2MPuTuAifwHhtwYC0Y',
          tags: [
            'cab',
            'taxi',
            'ride',
            'ola',
            'uber',
            'car hire',
            'cab booking',
            'drop',
            'pickup',
          ],
        ),
        _ServiceItem(
          name: 'Auto',
          imageUrl:
              'https://lh3.googleusercontent.com/aida-public/AB6AXuBk7v7vbiq8HyrENJ493QwrVhnPuwTBxRiAOiogK03p_PSovGGk9kt3_JeO2HipmzOHqxZokQJed60rmwbBxejTaSkCIwebznnCpli5bv86OGUlemfPzwksYAc5qj61iX5o4CyL8Bzcy1rFddg9uMnfLzCnsMHu-ug9zzf9KPYiop23Rj0Tud8k7cJdi_L-j0QwNul1Lnbn_QtZJKHnk63i92vq_jzpdPt43Nni71v0WBZTy6ipHr5M4r5MeC1Rda6UplM_hNVfrPU',
          tags: [
            'auto',
            'auto rickshaw',
            'rickshaw',
            'tuk tuk',
            'three wheeler',
            '3 wheeler',
            'tempo',
            'e-rickshaw',
            'ola auto',
            'rapido auto',
          ],
        ),
        _ServiceItem(
          name: 'Mechanic',
          imageUrl:
              'https://images.unsplash.com/photo-1619642751034-765dfdf7c58e?w=400&q=80',
          tags: [
            'car repair',
            'vehicle',
            'bike repair',
            'garage',
            'engine',
            'puncture',
            'servicing',
            'tyre',
            'motor',
          ],
        ),
        _ServiceItem(
          name: 'Personal Driver',
          imageUrl:
              'https://lh3.googleusercontent.com/aida-public/AB6AXuAwDuD1S3IN23t0KGrjw-sCsHUIQtSsjhLuyg_7HD5UFj0uYNN_YWLXZIp-TjBuD1NelRPvPn6op_Rccsles8lFAESDLJXCATs1MlTid4Z2bKIjUD5R1ieN8QpkJVM1ssFRLQlN4pIvpnTGdNelVQTX9fgVF9MTm9srqs4sLz5nfnl7OLpr7lImuUCrITIN9xJYOtyq02XUodYv35gIves5v1JXXibFMP4L7hDa2AHw9ofU0C9b8E1W-qZQoAqsHRd99I1TjsIwtRA',
          tags: [
            'chauffeur',
            'personal driver',
            'cab driver',
            'vehicle driver',
            'driving',
            'car driver',
          ],
        ),
      ],
    ),
    _ServiceSection(
      title: 'Personal & Lifestyle',
      subtitle: '11 Services',
      subtitleColor: AppColors.tertiary,
      items: [
        _ServiceItem(
          name: 'Babysitter',
          imageUrl:
              'https://lh3.googleusercontent.com/aida-public/AB6AXuDqxFSaMPd5BZKnV6IHAB20ByypRK6c8gcNd1uzJKLKcT9p1k2r3C3ANxmJBCWp51DO29O6Rl-AIR3UoCrPqZTp-kcz31szr0-pQBFdctyxqPwVj9D3EEJHUm-kce8P44BkOJ6F5Zv4wHRNr-aWqQIu5pcukuUZDVJL-NOcn7-JcyIMZJrTfn55LRxFQZKYdqUQ4RoTr4LDxy5rIjSy3YSoeRKR6IZqGqZ1TuRZWAkVzujr11LeOV6jEEPMAZNmhmkHsjBRjcDfWys',
          tags: [
            'baby',
            'child',
            'nanny',
            'childcare',
            'kids',
            'infant',
            'toddler',
            'creche',
          ],
        ),
        _ServiceItem(
          name: 'Tailor',
          imageUrl:
              'https://lh3.googleusercontent.com/aida-public/AB6AXuDb_CQelIHmHP_BOKaFlpO4H-KXopOOnYFD3gL31Ts7nfLQuLNdDoo4Lfg8nngMvHRPEhxaN4m3E2Qoo8hZgyQjw0aoruXUR379sIcLjwiZviznsk0--3aQ-lel3yGbpcoBwC7HTPgtqCH-wO593LJkCe7zztDKIfGwRKD1YxHm5hSs5q9G3L2a14Pz7PtdHPtUQkoWNijFt8x1D3BaYyjD8G0n2_yOmV8Ycqo8ZSP91FpT8-Hq8b6kHq3MLg2J6VwfQ1ePmIUXItw',
          tags: [
            'stitching',
            'alteration',
            'clothes',
            'dress',
            'sewing',
            'stitch',
            'darzi',
            'suit',
            'blouse',
          ],
        ),
        _ServiceItem(
          name: 'Home Salon',
          imageUrl:
              'https://lh3.googleusercontent.com/aida-public/AB6AXuDqve4vfxHS3X_DCRpzruYq3R6Nhod7-DJ5eZYBKdpYSWLaCxmHnzmsfXH2nITzqCySDRn4Och_nPtHYCkdovMOwbpamsIPozfsQS-IAGeb0eoArlBb_1sc9DpoJVxE_Z9lpCRpGHemV5OqkyTTM-r1kX29FbgQh-6RMQJpBiHpY-smtx6rYjZYgVWZkV_zHi3h7lNkqoFLcEr6TAhQBMRhq7Da3UmQotOe1FZiOX1OVJmuFuyllCnFXnIgk5NVkYOK2sYd7Gnez5o',
          tags: [
            'beauty',
            'parlour',
            'makeup',
            'facial',
            'hair',
            'waxing',
            'manicure',
            'pedicure',
            'salon',
            'threading',
          ],
        ),
        _ServiceItem(
          name: 'Tiffin Service',
          imageUrl:
              'https://images.unsplash.com/photo-1547592180-85f173990554?w=400&q=80',
          tags: [
            'tiffin',
            'meal',
            'home food',
            'lunch',
            'dinner',
            'dabba',
            'mess',
            'food delivery',
            'subscription meal',
          ],
        ),
        _ServiceItem(
          name: 'Emergency Medical',
          imageUrl:
              'https://images.unsplash.com/photo-1516574187841-cb9cc2ca948b?w=400&q=80',
          tags: [
            'emergency',
            'medical',
            'ambulance',
            'first aid',
            'doctor',
            'hospital',
            'urgent care',
            'health',
          ],
        ),
        _ServiceItem(
          name: 'Rental Rooms',
          imageUrl:
              'https://images.unsplash.com/photo-1631049307264-da0ec9d70304?w=400&q=80',
          tags: [
            'rental',
            'room',
            'rent',
            'flat',
            'apartment',
            'furnished',
            'pg',
            'hostel',
            'accommodation',
            'lease',
          ],
        ),
        _ServiceItem(
          name: 'Core Cutting',
          imageUrl:
              'https://images.unsplash.com/photo-1504307651254-35680f356dfd?w=400&q=80',
          tags: [
            'core cutting',
            'concrete',
            'drilling',
            'wall cutting',
            'diamond cutting',
            'boring',
            'construction',
          ],
        ),
        _ServiceItem(
          name: 'Property',
          imageUrl:
              'https://images.unsplash.com/photo-1560518883-ce09059eeffa?w=400&q=80',
          tags: [
            'property',
            'real estate',
            'buy',
            'sell',
            'land',
            'plot',
            'house',
            'villa',
            'commercial',
            'agent',
            'broker',
          ],
        ),
        _ServiceItem(
          name: 'RO Service',
          imageUrl:
              'https://media.istockphoto.com/id/1353114688/photo/image-of-unrecognisable-person-doing-a-maintenance-service-on-a-household-filtration-system.jpg?s=612x612&w=0&k=20&c=orSRdqtZP0ML0XpIy1o3ZE9jb9KMlkRNiumCnZL4Mmk=',
          tags: [
            'ro',
            'water purifier',
            'ro service',
            'water filter',
            'purifier repair',
            'aquaguard',
            'kent',
            'water treatment',
          ],
        ),
        _ServiceItem(
          name: 'Makeup Artist',
          imageUrl:
              'https://images.unsplash.com/photo-1487412947147-5cebf100ffc2?w=400&q=80',
          tags: [
            'makeup',
            'makeup artist',
            'bridal makeup',
            'party makeup',
            'mua',
            'beauty',
            'foundation',
            'contouring',
            'eyeshadow',
            'mua',
          ],
        ),
        _ServiceItem(
          name: 'Stock Advisor',
          imageUrl:
              'https://images.unsplash.com/photo-1611974789855-9c2a0a7236a3?w=400&q=80',
          tags: [
            'stock',
            'advisor',
            'market',
            'investment',
            'trading',
            'equity',
            'portfolio',
            'shares',
            'financial planning',
          ],
        ),
      ],
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final sections = _filteredSections();

    return Scaffold(
      backgroundColor: AppColors.background,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            pinned: true,
            toolbarHeight: 64,
            elevation: 0,
            scrolledUnderElevation: 0,
            backgroundColor: Colors.white.withValues(alpha: 0.86),
            iconTheme: const IconThemeData(color: AppColors.onSurface),
            titleSpacing: 4,
            title: Text(
              'Explore Services',
              style: AppTheme.headline(
                fontSize: 22,
                fontWeight: FontWeight.w700,
              ),
            ),
            flexibleSpace: ClipRect(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                child: const SizedBox.expand(),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: _buildSearchBar(),
            ),
          ),
          SliverToBoxAdapter(
            child: SizedBox(
              height: 42,
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                scrollDirection: Axis.horizontal,
                children: [
                  _buildSectionChip('All'),
                  _buildSectionChip('Home Maintenance'),
                  _buildSectionChip('Transport & Logistics'),
                  _buildSectionChip('Personal & Lifestyle'),
                ],
              ),
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 10)),
          if (sections.isEmpty)
            SliverFillRemaining(
              hasScrollBody: false,
              child: Center(
                child: Text(
                  'No services found',
                  style: AppTheme.body(
                    fontSize: 16,
                    color: AppColors.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            )
          else
            ...sections.expand((section) => _buildSectionSlivers(section)),
          const SliverToBoxAdapter(child: SizedBox(height: 32)),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      height: 54,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppColors.outlineVariant.withValues(alpha: 0.45),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          const SizedBox(width: 14),
          const Icon(Icons.search_rounded, color: AppColors.outline, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              controller: _searchController,
              style: AppTheme.body(fontSize: 15, fontWeight: FontWeight.w500),
              decoration: InputDecoration(
                hintText: 'Search services...',
                hintStyle: AppTheme.body(
                  fontSize: 15,
                  color: AppColors.outline,
                ),
                border: InputBorder.none,
              ),
              onChanged: (v) => setState(() => _query = v.trim().toLowerCase()),
            ),
          ),
          if (_query.isNotEmpty)
            GestureDetector(
              onTap: () {
                _searchController.clear();
                setState(() => _query = '');
              },
              child: const Padding(
                padding: EdgeInsets.all(10),
                child: Icon(Icons.close, color: AppColors.outline, size: 18),
              ),
            )
          else
            const SizedBox(width: 8),
          Padding(
            padding: const EdgeInsets.only(right: 10),
            child: GestureDetector(
              onTap: () => setState(() => _popularOnly = !_popularOnly),
              child: Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: _popularOnly
                      ? AppColors.tertiary.withValues(alpha: 0.14)
                      : AppColors.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.tune_rounded,
                  size: 16,
                  color: _popularOnly ? AppColors.tertiary : AppColors.outline,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<_ServiceSection> _filteredSections() {
    return _sections
        .map((section) {
          if (_selectedSection != 'All' && section.title != _selectedSection) {
            return null;
          }

          var filtered = section.items
              .where((item) => item.matches(_query))
              .toList();
          if (_query.isEmpty) {
            filtered = List<_ServiceItem>.from(section.items);
          }
          if (_popularOnly) {
            filtered = filtered
                .where((item) => _popularServices.contains(item.name))
                .toList();
          }

          if (filtered.isEmpty) return null;
          return _ServiceSection(
            title: section.title,
            subtitle: '${filtered.length} Services',
            subtitleColor: section.subtitleColor,
            items: filtered,
          );
        })
        .whereType<_ServiceSection>()
        .toList();
  }

  List<Widget> _buildSectionSlivers(_ServiceSection section) {
    return [
      SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(section.title, style: AppTheme.headline(fontSize: 20)),
              Text(
                section.subtitle,
                style: AppTheme.body(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: section.subtitleColor,
                ),
              ),
            ],
          ),
        ),
      ),
      SliverPadding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        sliver: SliverLayoutBuilder(
          builder: (context, constraints) {
            const crossAxisSpacing = 12.0;
            const mainAxisSpacing = 16.0;
            const targetCardWidth = 190.0;
            const cardHeight = 220.0;

            final crossAxisCount = math.max(
              2,
              (constraints.crossAxisExtent / targetCardWidth).floor(),
            );

            return SliverGrid.builder(
              itemCount: section.items.length,
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: crossAxisCount,
                crossAxisSpacing: crossAxisSpacing,
                mainAxisSpacing: mainAxisSpacing,
                mainAxisExtent: cardHeight,
              ),
              itemBuilder: (context, index) =>
                  _buildCard(context, section.items[index]),
            );
          },
        ),
      ),
    ];
  }

  Widget _buildSectionChip(String label) {
    final selected = _selectedSection == label;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: GestureDetector(
        onTap: () => setState(() => _selectedSection = label),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: selected ? AppColors.primary : Colors.white,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: selected
                  ? AppColors.primary
                  : AppColors.outlineVariant.withValues(alpha: 0.6),
            ),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.2),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : null,
          ),
          child: Text(
            label == 'Personal & Lifestyle' ? 'Personal' : label,
            style: AppTheme.body(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: selected ? Colors.white : AppColors.onSurfaceVariant,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCard(BuildContext context, _ServiceItem item) {
    final isPressed = _pressedCardName == item.name;
    final isPopular = _popularServices.contains(item.name);
    final isNew = _newServices.contains(item.name);

    return GestureDetector(
      onTapDown: (_) => setState(() => _pressedCardName = item.name),
      onTapCancel: () => setState(() => _pressedCardName = null),
      onTapUp: (_) => setState(() => _pressedCardName = null),
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => WorkerListScreen(category: item.name),
          ),
        );
      },
      child: AnimatedScale(
        duration: const Duration(milliseconds: 120),
        scale: isPressed ? 0.97 : 1,
        child: Container(
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isPressed ? 0.12 : 0.08),
                blurRadius: isPressed ? 16 : 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Stack(
            fit: StackFit.expand,
            children: [
              CachedNetworkImage(
                imageUrl: item.imageUrl,
                fit: BoxFit.cover,
                fadeInDuration: const Duration(milliseconds: 250),
                placeholder: (context, url) => Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        AppColors.surfaceContainerHigh,
                        AppColors.surfaceContainerHighest,
                      ],
                    ),
                  ),
                ),
                errorWidget: (context, url, error) => Container(
                  color: AppColors.surfaceContainerHigh,
                  child: const Icon(
                    Icons.image_not_supported_rounded,
                    color: AppColors.outlineVariant,
                  ),
                ),
              ),
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: Container(
                  height: 68,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                      colors: [
                        Colors.black.withValues(alpha: 0.42),
                        Colors.black.withValues(alpha: 0.02),
                      ],
                    ),
                  ),
                ),
              ),
              if (isPopular || isNew)
                Positioned(
                  top: 10,
                  left: 10,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: isNew
                          ? AppColors.primary.withValues(alpha: 0.88)
                          : AppColors.secondary.withValues(alpha: 0.88),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      isNew ? 'New' : 'Popular',
                      style: AppTheme.body(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              Positioned(
                left: 10,
                right: 10,
                bottom: 10,
                child: Text(
                  item.name,
                  style: AppTheme.body(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
