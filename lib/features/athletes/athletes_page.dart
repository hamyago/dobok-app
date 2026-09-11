import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/models/athlete_model.dart';
import '../../core/providers/athletes_provider.dart';
import '../../core/providers/auth_provider.dart';
import '../../core/theme/app_theme.dart';
import 'athlete_form_page.dart';
import 'athlete_detail_page.dart';

class AthletesPage extends ConsumerStatefulWidget {
  const AthletesPage({super.key});

  @override
  ConsumerState<AthletesPage> createState() => _AthletesPageState();
}

class _AthletesPageState extends ConsumerState<AthletesPage> {
  final _search = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(athletesProvider);
    final user = ref.watch(authProvider).valueOrNull;
    final clubId = user?.clubId;

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('ATHLÈTES'),
        leading: BackButton(onPressed: () => context.pop()),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          await Navigator.push(context,
              MaterialPageRoute(builder: (_) => const AthleteFormPage()));
          ref.invalidate(athletesProvider);
        },
        backgroundColor: AppTheme.primary,
        icon: const Icon(Icons.person_add, color: Colors.white),
        label: const Text('AJOUTER', style: TextStyle(color: Colors.white)),
      ),
      body: Column(
        children: [
          // Barre de recherche
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: TextField(
              controller: _search,
              onChanged: (v) => setState(() => _query = v.toLowerCase()),
              decoration: InputDecoration(
                hintText: 'Rechercher un athlète...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _query.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _search.clear();
                          setState(() => _query = '');
                        },
                      )
                    : null,
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
            ),
          ),
          Expanded(
            child: state.when(
              loading: () =>
                  const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.error_outline,
                        size: 48, color: AppTheme.error),
                    const SizedBox(height: 12),
                    const Text('Impossible de charger les athlètes'),
                    TextButton(
                      onPressed: () => ref.invalidate(athletesProvider),
                      child: const Text('Réessayer'),
                    ),
                  ],
                ),
              ),
              data: (athletes) {
                // Filtrer par club
                var mine = clubId != null
                    ? athletes.where((a) => a.clubId == clubId).toList()
                    : athletes;
                // Filtrer par recherche
                if (_query.isNotEmpty) {
                  mine = mine
                      .where((a) =>
                          a.fullName.toLowerCase().contains(_query) ||
                          (a.telephone?.contains(_query) ?? false) ||
                          (a.numeroLicence
                                  ?.toLowerCase()
                                  .contains(_query) ??
                              false) ||
                          a.ceinture.toLowerCase().contains(_query))
                      .toList();
                }
                // Tri alphabétique
                mine.sort((a, b) => a.nom.compareTo(b.nom));

                if (mine.isEmpty) {
                  return Center(
                    child: Text(
                      _query.isNotEmpty
                          ? 'Aucun résultat pour "$_query"'
                          : 'Aucun athlète enregistré',
                    ),
                  );
                }
                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
                  itemCount: mine.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (_, i) => _AthleteCard(
                    athlete: mine[i],
                    onTap: () async {
                      await Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) =>
                                  AthleteDetailPage(athlete: mine[i])));
                      ref.invalidate(athletesProvider);
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _AthleteCard extends StatelessWidget {
  final AthleteModel athlete;
  final VoidCallback onTap;
  const _AthleteCard({required this.athlete, required this.onTap});

  /// Construit une URL absolue depuis une URL relative ou absolue.
  String? _absoluteUrl(String? raw) {
    if (raw == null || raw.trim().isEmpty) return null;
    if (raw.startsWith('http://') || raw.startsWith('https://')) return raw;
    return 'https://api.do-bok.com$raw';
  }

  @override
  Widget build(BuildContext context) {
    final photoUrl = _absoluteUrl(athlete.photoUrl);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
            color: Colors.white, borderRadius: BorderRadius.circular(12)),
        child: Row(children: [
          // ✅ FIX : utilisation de CachedNetworkImage avec URL absolue
          ClipOval(
            child: SizedBox(
              width: 44,
              height: 44,
              child: photoUrl != null
                  ? CachedNetworkImage(
                      imageUrl: photoUrl,
                      fit: BoxFit.cover,
                      placeholder: (_, __) => Container(
                        color: AppTheme.primary.withValues(alpha: 0.1),
                        child: Center(
                          child: Text(
                            athlete.initiale,
                            style: const TextStyle(
                              color: AppTheme.primary,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                      errorWidget: (_, __, ___) => _fallbackAvatar(),
                    )
                  : _fallbackAvatar(),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
              child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(athlete.fullName,
                  style: const TextStyle(fontWeight: FontWeight.w600)),
              if (athlete.telephone != null)
                Text(athlete.telephone!,
                    style:
                        const TextStyle(color: Colors.grey, fontSize: 12)),
            ],
          )),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: AppTheme.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(athlete.ceinture.toUpperCase(),
                style: const TextStyle(
                    fontSize: 10,
                    color: AppTheme.primary,
                    fontWeight: FontWeight.bold)),
          ),
          const SizedBox(width: 4),
          const Icon(Icons.chevron_right, color: Colors.grey, size: 20),
        ]),
      ),
    );
  }

  Widget _fallbackAvatar() {
    return Container(
      color: AppTheme.primary.withValues(alpha: 0.1),
      child: Center(
        child: Text(
          athlete.initiale,
          style: const TextStyle(
            color: AppTheme.primary,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}
