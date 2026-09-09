import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/api/api_client.dart';
import '../../core/providers/auth_provider.dart';
import '../../core/theme/app_theme.dart';

final candidaturesProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final response = await ApiClient().dio.get('/candidatures');
  return (response.data as List).cast<Map<String, dynamic>>();
});

// Groupe les candidatures par mois (clé = "YYYY-MM")
Map<String, List<Map<String, dynamic>>> _groupByMonth(
    List<Map<String, dynamic>> all, int? clubId) {
  final filtered = clubId != null
      ? all.where((c) => (c['athlete']?['club_id'] as int?) == clubId).toList()
      : all;

  // Trier par date de session décroissante
  filtered.sort((a, b) {
    final da = (a['session']?['date'] as String?) ?? '';
    final db = (b['session']?['date'] as String?) ?? '';
    return db.compareTo(da);
  });

  final map = <String, List<Map<String, dynamic>>>{};
  for (final c in filtered) {
    final date = (c['session']?['date'] as String?) ?? '';
    final key = date.length >= 7 ? date.substring(0, 7) : 'Inconnu';
    map.putIfAbsent(key, () => []).add(c);
  }
  return map;
}

String _monthLabel(String key) {
  if (key == 'Inconnu') return 'Date inconnue';
  final parts = key.split('-');
  if (parts.length < 2) return key;
  const mois = ['', 'Janvier','Février','Mars','Avril','Mai','Juin',
    'Juillet','Août','Septembre','Octobre','Novembre','Décembre'];
  final m = int.tryParse(parts[1]) ?? 0;
  return '${mois[m]} ${parts[0]}';
}

class CandidaturesPage extends ConsumerWidget {
  const CandidaturesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(candidaturesProvider);
    final user = ref.watch(authProvider).valueOrNull;
    final clubId = user?.clubId;

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('Candidatures'),
        leading: BackButton(onPressed: () => context.pop()),
      ),
      body: state.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 48, color: AppTheme.error),
            const SizedBox(height: 12),
            const Text('Impossible de charger les candidatures'),
            TextButton(
              onPressed: () => ref.invalidate(candidaturesProvider),
              child: const Text('Réessayer'),
            ),
          ],
        )),
        data: (all) {
          final grouped = _groupByMonth(all, clubId);
          if (grouped.isEmpty) {
            return const Center(child: Text('Aucune candidature'));
          }
          final keys = grouped.keys.toList();
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: keys.length,
            itemBuilder: (_, i) {
              final key = keys[i];
              final list = grouped[key]!;
              final admis = list.where((c) => c['resultat'] == 'admis').length;
              final refuses = list.where((c) => c['resultat'] == 'refuse').length;
              final absents = list.where((c) => c['statut_presence'] == 'absent').length;
              final enAttente = list.where((c) => c['resultat'] == null && c['statut_presence'] != 'absent').length;
              final lieu = (list.first['session']?['lieu'] as String?) ?? '—';
              final date = (list.first['session']?['date'] as String?)?.substring(0, 10) ?? '—';

              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () => Navigator.push(context, MaterialPageRoute(
                    builder: (_) => _SessionDetailPage(
                      moisLabel: _monthLabel(key),
                      date: date,
                      lieu: lieu,
                      candidatures: list,
                    ),
                  )),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      children: [
                        // Header mois
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          decoration: BoxDecoration(
                            color: AppTheme.primary,
                            borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.calendar_month, color: Colors.white, size: 18),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(_monthLabel(key),
                                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                              ),
                              Text('$date • $lieu',
                                style: const TextStyle(color: Colors.white70, fontSize: 12)),
                            ],
                          ),
                        ),
                        // Stats
                        Padding(
                          padding: const EdgeInsets.all(16),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceAround,
                            children: [
                              _StatBadge(label: 'Admis', count: admis, color: AppTheme.success),
                              _StatBadge(label: 'Refusés', count: refuses, color: AppTheme.error),
                              _StatBadge(label: 'Absents', count: absents, color: Colors.grey),
                              if (enAttente > 0)
                                _StatBadge(label: 'En attente', count: enAttente, color: AppTheme.warning),
                              Text('${list.length} total',
                                style: const TextStyle(color: Colors.grey, fontSize: 12)),
                            ],
                          ),
                        ),
                        const Padding(
                          padding: EdgeInsets.only(bottom: 8),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text('Voir le détail', style: TextStyle(color: AppTheme.primary, fontSize: 12)),
                              Icon(Icons.chevron_right, color: AppTheme.primary, size: 16),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class _StatBadge extends StatelessWidget {
  final String label;
  final int count;
  final Color color;
  const _StatBadge({required this.label, required this.count, required this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text('$count', style: TextStyle(
          fontSize: 22, fontWeight: FontWeight.bold, color: color)),
        Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
      ],
    );
  }
}

// ─── Page détail d'une session ───────────────────────────────────────────────

class _SessionDetailPage extends StatefulWidget {
  final String moisLabel;
  final String date;
  final String lieu;
  final List<Map<String, dynamic>> candidatures;
  const _SessionDetailPage({
    required this.moisLabel,
    required this.date,
    required this.lieu,
    required this.candidatures,
  });

  @override
  State<_SessionDetailPage> createState() => _SessionDetailPageState();
}

class _SessionDetailPageState extends State<_SessionDetailPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabs;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  List<Map<String, dynamic>> _filter(String type) {
    switch (type) {
      case 'admis': return widget.candidatures.where((c) => c['resultat'] == 'admis').toList();
      case 'refuse': return widget.candidatures.where((c) => c['resultat'] == 'refuse').toList();
      case 'absent': return widget.candidatures.where((c) => c['statut_presence'] == 'absent').toList();
      default: return widget.candidatures;
    }
  }

  Color _couleur(Map<String, dynamic> c) {
    if (c['statut_presence'] == 'absent') return Colors.grey;
    switch (c['resultat']) {
      case 'admis': return AppTheme.success;
      case 'refuse': return AppTheme.error;
      default: return AppTheme.warning;
    }
  }

  String _etiquette(Map<String, dynamic> c) {
    if (c['statut_presence'] == 'absent') return 'Absent';
    switch (c['resultat']) {
      case 'admis': return 'Admis';
      case 'refuse': return 'Refusé';
      default: return 'En attente';
    }
  }

  Widget _liste(List<Map<String, dynamic>> items) {
    if (items.isEmpty) {
      return const Center(child: Text('Aucun résultat dans cette catégorie'));
    }
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: items.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (_, i) {
        final c = items[i];
        final a = c['athlete'] as Map<String, dynamic>? ?? {};
        final nom = '${a['nom'] ?? ''} ${a['prenom'] ?? ''}'.trim();
        final ceinture = c['ceinture_visee'] as String? ?? '—';
        final note = c['note_finale'];
        final color = _couleur(c);
        final label = _etiquette(c);

        return Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border(left: BorderSide(color: color, width: 4)),
          ),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: color.withValues(alpha: 0.1),
                child: Text(nom.isNotEmpty ? nom[0] : '?',
                  style: TextStyle(color: color, fontWeight: FontWeight.bold)),
              ),
              const SizedBox(width: 12),
              Expanded(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(nom, style: const TextStyle(fontWeight: FontWeight.w600)),
                  Text('Ceinture visée : $ceinture',
                    style: const TextStyle(color: Colors.grey, fontSize: 12)),
                  if (note != null)
                    Text('Note : $note / 100',
                      style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w500)),
                ],
              )),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(label,
                  style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w600)),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final tous = _filter('tous');
    final admis = _filter('admis');
    final refuses = _filter('refuse');
    final absents = _filter('absent');

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: Text(widget.moisLabel),
        leading: BackButton(onPressed: () => context.pop()),
        bottom: TabBar(
          controller: _tabs,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white60,
          indicatorColor: Colors.white,
          tabs: [
            Tab(text: 'Tous (${tous.length})'),
            Tab(text: 'Admis (${admis.length})'),
            Tab(text: 'Refusés (${refuses.length})'),
            Tab(text: 'Absents (${absents.length})'),
          ],
        ),
      ),
      body: Column(
        children: [
          Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(children: [
              const Icon(Icons.calendar_today, size: 14, color: Colors.grey),
              const SizedBox(width: 6),
              Text(widget.date, style: const TextStyle(color: Colors.grey, fontSize: 13)),
              const SizedBox(width: 16),
              const Icon(Icons.location_on, size: 14, color: Colors.grey),
              const SizedBox(width: 6),
              Text(widget.lieu, style: const TextStyle(color: Colors.grey, fontSize: 13)),
            ]),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabs,
              children: [
                _liste(tous),
                _liste(admis),
                _liste(refuses),
                _liste(absents),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
