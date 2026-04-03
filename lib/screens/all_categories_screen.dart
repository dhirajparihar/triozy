import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import 'worker_list_screen.dart';

class _ServiceItem {
  final String name;
  final String imageUrl;

  _ServiceItem({required this.name, required this.imageUrl});
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

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  static final List<_ServiceSection> _sections = [
    _ServiceSection(
      title: 'Home Maintenance',
      subtitle: '9 Services',
      subtitleColor: AppColors.primary,
      items: [
        _ServiceItem(
          name: 'Electrician',
          imageUrl:
              'https://lh3.googleusercontent.com/aida-public/AB6AXuC-eL5ZvDeISt0w2u0DR1osoZqXxH0DKO9YCBmoJAhw0zw5M0nULj0QcNh14z7RzMwC2sPi6Aw5aiepDhxhuKKZnQC-Y51TcineiQIlnhcD_oBbLntDbegJBXAYCB1K0jStkwbU_R9ek97RPWgz0d-2thTAO3CrR2h5Rq08mAZHz0GrsJqJs9CK5ta9Fe2kcH40uAUui3R5q258lfv3hmyDiVPgSiEJn-ebgr4tzXr1qkxamyYlrAqc-VFvw1k5pj7CZX54MfVIXGQ',
        ),
        _ServiceItem(
          name: 'Plumber',
          imageUrl:
              'https://lh3.googleusercontent.com/aida-public/AB6AXuCHB8HEtlkIngffZC4YxjMghwS577KPR9kJt0uUc07S5Mlm1qkPq2vSuAEn6cJgSZYYjeUbJI_Cvdx1qb8OjdWB86JZmvnlQ1301eq6gBoaDY8XQiGZk5dZjUfZg_X3UOHOgKkSspxgjxZ4bo2c0J-J7B6z5Ud7AS13btPeFC3wsglYjjxjQvw1kw2L0f34nm_nGTFDyvM-KkzyMCufsdX0sOJGBYpuikYwIpW6W_ztX6gRGhTf60sId5Fp74D0JEuqvh_TatgV8os',
        ),
        _ServiceItem(
          name: 'AC Repair',
          imageUrl:
              'https://lh3.googleusercontent.com/aida-public/AB6AXuCwJdWFNgZs5x6jOIZ_TD3QLZlaYKCr0IFVtFr-Y6js2VvkJvyM2Y4vCVnHNcl2X9uI9DXL0NpyIWgXl2bb0Rv05Yykpxk6ooavynLjBDx-dIahugWk8hDsFiqDkf8ocIn6Pv-AUPAzBAYehZCUa-Q73mbN9x_ZpMIpOxI-aRso0RGCdvpQZCqYaP40WrVLmn2Pbq7zdZXTDgIHaQcZfxBCSl0tk-AYg7n_q9PkfvOhRERWWfby5v6QHS_FLc_g81ixfPBcIiaTPQI',
        ),
        _ServiceItem(
          name: 'Carpenter',
          imageUrl:
              'https://lh3.googleusercontent.com/aida-public/AB6AXuBR59E38-pMAUc62Te_LJcTLWnxSabAyVkK6WzWryse7YKj6T9f-ULULojKFgAVoMMN__yHWs7_OCPEF64Dbeitg36hALWzXkeEFTBAzM_YKdp3ta28-Prr5R8ScejhPTDHdgaWetKX8eTaYEV8ny1y-Hw9Js4Xj5UUut_uArDZHPX8pV8DbthF1GmPBLuDyN1c6urVutSUcAyjC9Po4fxibNTTKCNONznABopB_J6F1-7VhqpPhsIP65j9U4KMxLGOvEX5QC256h0',
        ),
        _ServiceItem(
          name: 'Tile Worker',
          imageUrl:
              'https://lh3.googleusercontent.com/aida-public/AB6AXuBw9MzXeN5MQ0cnjpQy0iJdJheQTau79c9n9MpL7XEVoCb4Au5abAD7oX_tokTuW-6P0hdbtt6rbFeCgaBsEGaOu2mkwhhsMofgTv5xz6cOj8Sks0fiBKoj6-1l0xhr9pm4zykry9aN6_bGg8xi1hp2LDnY72O9qNQKLKwlRdin5Odte4cIcrAz4W85K6H_xqZURGjBGwPdM2g8Y8HW4v2WNn3vLq9EL60OHlUDzfIQKMmtsjTvOHQd3PMR6ypTBrfw5j89HbN7SKo',
        ),
        _ServiceItem(
          name: 'Cleaning',
          imageUrl:
              'https://lh3.googleusercontent.com/aida-public/AB6AXuDPwfwKoxuNUrUCIA5XaU6YkT1mDUGRkcKWD3ZthjMw8S7TCAeOYmCc7vzIfvCu0rTOokppQ_iqrL3SaHZlcosZGQnzmxdtSLQYtC9IdFsia3ag5zbh4mcRmTrxFOxbaf4p2HhoZADeMClp1aKzPM9mG29Uw205KnC76EhPzP9_PAWC5Ja1PPwG44gWFyiRUJvSZ0WE7J7G6udOV6jkVaCU7YPag_gMf8Ay5Y5Y42HDS8oOKs4iO3VKIBNe-H3VwA46BnLoKurHUy4',
        ),
        _ServiceItem(
          name: 'Maid',
          imageUrl:
              'https://lh3.googleusercontent.com/aida-public/AB6AXuBKW6YspQtlyL16TBJiYmx3RMB_z-mUwQuCDYKUVkjREH6fGUmZvhUPxfueBQZuo5QrIPTbERZ_est2TPfa7re4J9kEEVSBvaEwHoNdDFmRfHk0b6Ui-pR52ycN7U-xlK2KxQRKHSa5tsnismWqVDes_SR5WcbUwCo-XKfoK6zCrm0frCl_PB89_srfNi_lsUu8K0dJ9F4QSoz9zOGXqfl_ZV39knjkwxzkxGNsgxCDlKK8F5RytKNoA1xDPhSkh32A6oLnJR5uWcc',
        ),
        _ServiceItem(
          name: 'Security',
          imageUrl:
              'https://lh3.googleusercontent.com/aida-public/AB6AXuAF8RyOJAulwsVqIMGFJtXoJMKHDk7B7YBQFI9JRgo4eROLujLTmjz4wCP65MuGHrbvxuM6LcArAm78rns_C0kStbFyqD9a4K57O--J-ElPSTmg4fBX3gqyE9oIJtpfIH0baillLctWbdqxfFsNGNiyBd4uYxmWTL7y_7hfRDtB7mHPZJd_iMBucqU3BUlw-F6VGRsqhhPZF9EpXlRVLH0E6sjswjMnm4yb5xbx0tVLt5BzcwR_JP4EBh2MiMYNEQ8lGpl9oLpalZM',
        ),
        _ServiceItem(
          name: 'Gardening',
          imageUrl:
              'https://lh3.googleusercontent.com/aida-public/AB6AXuC7xLSymgBC0zKuwIVZ9dQhRbLLQ5IjwbPDTxgXihEVMYF63msmSu68HjEx4sdp2i-beZvEXISuuY6NA8Ys24N0sSM0L4oUxbHxYk_UVK8Ks8cPmRJI3jE9UCSMcMxhtynaVo16F_3aoRpHVe357Sr9ZuLBBcf-oFOP5puDV1URXzb1yZZ90aeWB_GLvp6i3IDVM7cf6GX5kpIBQh7IQl57HMLKEhPfnXmmVGOXPVl5KL3_M_PzsxghQF7yofk6DEOEInUtwVdlADo',
        ),
      ],
    ),
    _ServiceSection(
      title: 'Transport & Logistics',
      subtitle: '5 Services',
      subtitleColor: AppColors.primary,
      items: [
        _ServiceItem(
          name: 'Co-rider',
          imageUrl:
              'https://lh3.googleusercontent.com/aida-public/AB6AXuAHepeh83ksYE1GlpXqnCF95v_1Cfp4gS-v-6CLCZdamXVp26BIDHcTdI8jZjVwOWWskPOzIAh2CMuAGBQ8fDsvZ3N3_Od9S6jExRsmHdMp8vf3bKBqdPabrGd-iEYG5rVXUXGdRf_-UH8loAy4vLquh5blxjAKeKDY8ver3ney7MSooHwe-2QTWJFTLlZfdLTpYuFKsYBsEFkxFOkBjOTu0gee8a2Wr4ULuWOlB1dkRJ9iGoHFx63mgeLYLuUEATjjA_5URNQOnGY',
        ),
        _ServiceItem(
          name: 'Bike Taxi',
          imageUrl:
              'https://lh3.googleusercontent.com/aida-public/AB6AXuDVedJNeCCmRzo5jePOVvSTfWq9XnHbiueivIu5--_S6-EL6p5ZqdgiCj6eiiOJW0dyH001E2YpB6fpxqnBX-V_D7ZnZNS3rfaU-c1ralN9Qy_NJAUtQfNGQijGnWE8TUsDEA3Y94zPkrACrMqKpBb8EwivUF6u16rbPOXsaBPmMhS2JJ2bngJIXIJIIdR1jZPffm3mwJqmimSsDL1tJ14IuchS6EVySp05eBJ7vb2Srs9bYnIJVvMjBRRcQTxZAiMwhlKDzfV9OrE',
        ),
        _ServiceItem(
          name: 'Car Taxi',
          imageUrl:
              'https://lh3.googleusercontent.com/aida-public/AB6AXuDfvVZB9psj8zwSNHefejj7PlM5g0HlIe59lqnrveTiYM82TLo8q_oGeSfMUt0pSmVMXUn_1pAjEa9AsFYShZDRjIHKoSMO9GsLnMJ4LHtd0PgpgMGxAoa4jHXwvGYIeT4fCHulsxfyWKiKm5uYdRz0S2aTsu_uScLqg7_NBK-nozZkd0BW3m4cSsguEZQlPA7zqKOTjQPzcSRm7cE9zoJkEvRsB0zy9J7FgvUMPZTaFfXNuA47w5gaInfPg2MPuTuAifwHhtwYC0Y',
        ),
        _ServiceItem(
          name: 'Tempo',
          imageUrl:
              'https://lh3.googleusercontent.com/aida-public/AB6AXuBk7v7vbiq8HyrENJ493QwrVhnPuwTBxRiAOiogK03p_PSovGGk9kt3_JeO2HipmzOHqxZokQJed60rmwbBxejTaSkCIwebznnCpli5bv86OGUlemfPzwksYAc5qj61iX5o4CyL8Bzcy1rFddg9uMnfLzCnsMHu-ug9zzf9KPYiop23Rj0Tud8k7cJdi_L-j0QwNul1Lnbn_QtZJKHnk63i92vq_jzpdPt43Nni71v0WBZTy6ipHr5M4r5MeC1Rda6UplM_hNVfrPU',
        ),
        _ServiceItem(
          name: 'Driver',
          imageUrl:
              'https://lh3.googleusercontent.com/aida-public/AB6AXuAwDuD1S3IN23t0KGrjw-sCsHUIQtSsjhLuyg_7HD5UFj0uYNN_YWLXZIp-TjBuD1NelRPvPn6op_Rccsles8lFAESDLJXCATs1MlTid4Z2bKIjUD5R1ieN8QpkJVM1ssFRLQlN4pIvpnTGdNelVQTX9fgVF9MTm9srqs4sLz5nfnl7OLpr7lImuUCrITIN9xJYOtyq02XUodYv35gIves5v1JXXibFMP4L7hDa2AHw9ofU0C9b8E1W-qZQoAqsHRd99I1TjsIwtRA',
        ),
      ],
    ),
    _ServiceSection(
      title: 'Personal & Lifestyle',
      subtitle: '3 Services',
      subtitleColor: AppColors.tertiary,
      items: [
        _ServiceItem(
          name: 'Babysitter',
          imageUrl:
              'https://lh3.googleusercontent.com/aida-public/AB6AXuDqxFSaMPd5BZKnV6IHAB20ByypRK6c8gcNd1uzJKLKcT9p1k2r3C3ANxmJBCWp51DO29O6Rl-AIR3UoCrPqZTp-kcz31szr0-pQBFdctyxqPwVj9D3EEJHUm-kce8P44BkOJ6F5Zv4wHRNr-aWqQIu5pcukuUZDVJL-NOcn7-JcyIMZJrTfn55LRxFQZKYdqUQ4RoTr4LDxy5rIjSy3YSoeRKR6IZqGqZ1TuRZWAkVzujr11LeOV6jEEPMAZNmhmkHsjBRjcDfWys',
        ),
        _ServiceItem(
          name: 'Tailor',
          imageUrl:
              'https://lh3.googleusercontent.com/aida-public/AB6AXuDb_CQelIHmHP_BOKaFlpO4H-KXopOOnYFD3gL31Ts7nfLQuLNdDoo4Lfg8nngMvHRPEhxaN4m3E2Qoo8hZgyQjw0aoruXUR379sIcLjwiZviznsk0--3aQ-lel3yGbpcoBwC7HTPgtqCH-wO593LJkCe7zztDKIfGwRKD1YxHm5hSs5q9G3L2a14Pz7PtdHPtUQkoWNijFt8x1D3BaYyjD8G0n2_yOmV8Ycqo8ZSP91FpT8-Hq8b6kHq3MLg2J6VwfQ1ePmIUXItw',
        ),
        _ServiceItem(
          name: 'Home Salon',
          imageUrl:
              'https://lh3.googleusercontent.com/aida-public/AB6AXuDqve4vfxHS3X_DCRpzruYq3R6Nhod7-DJ5eZYBKdpYSWLaCxmHnzmsfXH2nITzqCySDRn4Och_nPtHYCkdovMOwbpamsIPozfsQS-IAGeb0eoArlBb_1sc9DpoJVxE_Z9lpCRpGHemV5OqkyTTM-r1kX29FbgQh-6RMQJpBiHpY-smtx6rYjZYgVWZkV_zHi3h7lNkqoFLcEr6TAhQBMRhq7Da3UmQotOe1FZiOX1OVJmuFuyllCnFXnIgk5NVkYOK2sYd7Gnez5o',
        ),
      ],
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          'All Categories',
          style: AppTheme.headline(fontSize: 24, fontWeight: FontWeight.w700),
        ),
        backgroundColor: Colors.white.withValues(alpha: 0.8),
        scrolledUnderElevation: 0,
        elevation: 0,
        centerTitle: false,
        iconTheme: const IconThemeData(color: AppColors.primary),
        actions: const [SizedBox(width: 8)],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeroSection(),
            const SizedBox(height: 24),
            _buildSearchBar(),
            const SizedBox(height: 32),
            ..._filteredSections().map((section) => _buildSection(context, section)),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      height: 56,
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          const SizedBox(width: 20),
          const Icon(Icons.search, color: AppColors.outline),
          const SizedBox(width: 12),
          Expanded(
            child: TextField(
              controller: _searchController,
              style: AppTheme.body(fontSize: 16),
              decoration: InputDecoration(
                hintText: 'Search categories...',
                hintStyle: AppTheme.body(fontSize: 16, color: AppColors.outline),
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
                padding: EdgeInsets.all(12),
                child: Icon(Icons.close, color: AppColors.outline, size: 20),
              ),
            )
          else
            const SizedBox(width: 20),
        ],
      ),
    );
  }

  List<_ServiceSection> _filteredSections() {
    if (_query.isEmpty) return _sections;

    return _sections
        .map((section) {
          final filtered = section.items
              .where((item) => item.name.toLowerCase().contains(_query))
              .toList();
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

  Widget _buildHeroSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        RichText(
          text: TextSpan(
            children: [
              TextSpan(
                text: 'Expert Help,\n',
                style: AppTheme.headline(fontSize: 36, letterSpacing: -1.0),
              ),
              TextSpan(
                text: 'Just a Tap Away.',
                style: AppTheme.headline(
                  fontSize: 36,
                  color: AppColors.primary,
                  letterSpacing: -1.0,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'Select a service to find verified professionals in your area.',
          style: AppTheme.body(fontSize: 16, color: AppColors.outline),
        ),
      ],
    );
  }

  Widget _buildSection(BuildContext context, _ServiceSection section) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(section.title, style: AppTheme.headline(fontSize: 20)),
              Text(
                section.subtitle,
                style: AppTheme.body(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: section.subtitleColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: section.items.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              childAspectRatio: 0.9,
            ),
            itemBuilder: (context, index) {
              final item = section.items[index];
              return _buildCard(context, item);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildCard(BuildContext context, _ServiceItem item) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => WorkerListScreen(category: item.name),
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  width: double.infinity,
                  color: AppColors.surfaceContainerHigh,
                  child: CachedNetworkImage(
                    imageUrl: item.imageUrl,
                    fit: BoxFit.cover,
                    placeholder: (context, url) => const Center(
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                    errorWidget: (context, url, error) => const Icon(
                      Icons.image_not_supported,
                      color: AppColors.outlineVariant,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              item.name,
              style: AppTheme.body(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: AppColors.onSurface,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
          ],
        ),
      ),
    );
  }
}
