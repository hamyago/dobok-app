import 'dart:async';
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

Map<String, List<Map<String, dynamic>>> _groupByMonth(
    List<Map<String, dynamic>> all, int? clubId) {
  final filtered = clubId != null
      ? all.where((c) => (c['athlete']?['club_id'] as int?) == clubId).toList()
      : all;
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
  const mois = ['','Janvier','Février','Mars','Avril','Mai','Juin',
    'Juillet','Août','Septembre','Octobre','Novembre','Décembre'];
  final m = int.tryParse(parts[1]) ?? 0;
  return '${mois[m]} ${parts[0]}';
}

class CandidaturesPage extends ConsumerStatefulWidget {
  const CandidaturesPage({super.key});

  @override
  ConsumerState<CandidaturesPage> createState() => _CandidaturesPageState();
}

class _CandidaturesPageState extends ConsumerState<CandidaturesPage>
    with WidgetsBindingObserver {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Rafraîchissement automatique toutes les 30 secondes
    _timer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) ref.invalidate(candidaturesProvider);
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    super.dispose();
  }

  // Rafraîchissement quand l'app revient au premier plan
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      ref.invalidate(candidaturesProvider);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(candidaturesProvider);
    final user = ref.watch(authProvider).valueOrNull;
    final clubId = user?.clubId;
    final isPresident = user?.role == 'president';

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('Candidatures'),
        leading: BackButton(onPressed: () => context.pop()),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.invalidate(candidaturesProvider),
            tooltip: 'Actualiser',
          ),
        ],
      ),
      body: state.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 48, color: AppTheme.error),
            const SizedBox(height: 12),
            const Text('Impossible de charger les candidatures'),
            TextButton(onPressed: () => ref.invalidate(candidaturesProvider),
              child: const Text('Réessayer')),
          ],
        )),
        data: (all) {
          final grouped = _groupByMonth(all, clubId);
          if (grouped.isEmpty) return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.sports_martial_arts, size: 64, color: Colors.grey.shade300),
                const SizedBox(height: 16),
                const Text('Aucune candidature',
                  style: TextStyle(color: Colors.grey, fontSize: 16)),
                const SizedBox(height: 8),
                TextButton.icon(
                  onPressed: () => ref.invalidate(candidaturesProvider),
                  icon: const Icon(Icons.refresh),
                  label: const Text('Actualiser'),
                ),
              ],
            ),
          );
          final keys = grouped.keys.toList();
          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(candidaturesProvider),
            child: ListView.builder(
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
                final sessionOuverte = (list.first['session']?['statut'] as String?) == 'ouverte';

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
                        isPresident: isPresident,
                        sessionOuverte: sessionOuverte,
                        onRetrait: () => ref.invalidate(candidaturesProvider),
                      ),
                    )),
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(children: [
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          decoration: BoxDecoration(
                            color: AppTheme.primary,
                            borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                          ),
                          child: Row(children: [
                            const Icon(Icons.calendar_month, color: Colors.white, size: 18),
                            const SizedBox(width: 8),
                            Expanded(child: Text(_monthLabel(key),
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
                            Text('$date • $lieu',
                              style: const TextStyle(color: Colors.white70, fontSize: 12)),
                          ]),
                        ),
                        Padding(
                          padding: const EdgeInsets.all(16),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceAround,
                            children: [
                              _StatBadge('Admis', admis, AppTheme.success),
                              _StatBadge('Refusés', refuses, AppTheme.error),
                              _StatBadge('Absents', absents, Colors.grey),
                              if (enAttente > 0) _StatBadge('En attente', enAttente, AppTheme.warning),
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
                      ]),
                    ),
                  ),
                );
              },
            ),
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
  const _StatBadge(this.label, this.count, this.color);

  @override
  Widget build(BuildContext context) => Column(children: [
    Text('$count', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: color)),
    Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
  ]);
}

// ─── Page détail session ─────────────────────────────────────────────────────
class _SessionDetailPage extends StatefulWidget {
  final String moisLabel;
  final String date;
  final String lieu;
  final List<Map<String, dynamic>> candidatures;
  final bool isPresident;
  final bool sessionOuverte;
  final VoidCallback onRetrait;

  const _SessionDetailPage({
    required this.moisLabel,
    required this.date,
    required this.lieu,
    required this.candidatures,
    required this.isPresident,
    required this.sessionOuverte,
    required this.onRetrait,
  });

  @override
  State<_SessionDetailPage> createState() => _SessionDetailPageState();
}

class _SessionDetailPageState extends State<_SessionDetailPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabs;
  late List<Map<String, dynamic>> _candidatures;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 4, vsync: this);
    _candidatures = List.from(widget.candidatures);
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  List<Map<String, dynamic>> _filter(String type) {
    switch (type) {
      case 'admis': return _candidatures.where((c) => c['resultat'] == 'admis').toList();
      case 'refuse': return _candidatures.where((c) => c['resultat'] == 'refuse').toList();
      case 'absent': return _candidatures.where((c) => c['statut_presence'] == 'absent').toList();
      default: return _candidatures;
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

  Widget _paiementBadge(String statut) {
    final isConfirme = statut == 'paye' || statut == 'confirme';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: isConfirme
            ? AppTheme.success.withValues(alpha: 0.1)
            : AppTheme.warning.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(isConfirme ? Icons.check_circle : Icons.hourglass_empty,
          size: 12,
          color: isConfirme ? AppTheme.success : AppTheme.warning),
        const SizedBox(width: 4),
        Text(isConfirme ? 'Payé ✓' : 'En attente',
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w600,
            color: isConfirme ? AppTheme.success : AppTheme.warning,
          )),
      ]),
    );
  }

  Future<void> _retirerCandidature(Map<String, dynamic> c) async {
    final id = c['id'];
    final nom = '${c['athlete']?['nom'] ?? ''} ${c['athlete']?['prenom'] ?? ''}'.trim();

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Retirer la candidature'),
        content: Text('Voulez-vous retirer $nom de cette session ?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annuler')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.error),
            child: const Text('Retirer'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await ApiClient().dio.delete('/candidatures/$id');
      setState(() => _candidatures.removeWhere((x) => x['id'] == id));
      widget.onRetrait();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Candidature retirée avec succès'),
          backgroundColor: AppTheme.success,
          behavior: SnackBarBehavior.floating,
        ));
      }
    } catch (e) {
      if (mounted) {
        final msg = e.toString().contains('422')
            ? 'Impossible — liste déjà close ou date limite dépassée'
            : 'Erreur lors du retrait';
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(msg),
          backgroundColor: AppTheme.error,
          behavior: SnackBarBehavior.floating,
        ));
      }
    }
  }

  Widget _liste(List<Map<String, dynamic>> items) {
    if (items.isEmpty) return const Center(child: Text('Aucun résultat dans cette catégorie'));
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
        final statutPaiement = c['statut_paiement'] as String? ?? 'en_attente';
        final canRetirer = widget.isPresident && widget.sessionOuverte && c['resultat'] == null;

        return Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border(left: BorderSide(color: color, width: 4)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
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
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(label,
                        style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w600)),
                    ),
                    const SizedBox(height: 4),
                    _paiementBadge(statutPaiement),
                  ],
                ),
              ]),
              if (canRetirer) ...[
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    onPressed: () => _retirerCandidature(c),
                    icon: const Icon(Icons.remove_circle_outline, size: 16, color: AppTheme.error),
                    label: const Text('Retirer', style: TextStyle(color: AppTheme.error, fontSize: 12)),
                    style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 8)),
                  ),
                ),
              ],
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
        leading: BackButton(onPressed: () => Navigator.pop(context)),
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
      body: Column(children: [
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
        Expanded(child: TabBarView(
          controller: _tabs,
          children: [_liste(tous), _liste(admis), _liste(refuses), _liste(absents)],
        )),
      ]),
    );
  }
}
