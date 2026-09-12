import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/api/api_client.dart';
import '../../core/theme/app_theme.dart';

final seancesProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final response = await ApiClient().dio.get('/seances');
  return (response.data as List).cast<Map<String, dynamic>>();
});

class SeancesPage extends ConsumerStatefulWidget {
  const SeancesPage({super.key});

  @override
  ConsumerState<SeancesPage> createState() => _SeancesPageState();
}

class _SeancesPageState extends ConsumerState<SeancesPage> {
  final _dateCtrl     = TextEditingController(text: DateTime.now().toIso8601String().substring(0, 10));
  final _heureCtrl    = TextEditingController(text: '09:00');
  final _lieuCtrl     = TextEditingController();
  final _notesCtrl    = TextEditingController();
  int   _duree        = 90;
  bool  _creating     = false;

  @override
  void dispose() {
    _dateCtrl.dispose(); _heureCtrl.dispose();
    _lieuCtrl.dispose(); _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _creerSeance() async {
    setState(() => _creating = true);
    try {
      await ApiClient().dio.post('/seances', data: {
        'date':          _dateCtrl.text,
        'heure_debut':   _heureCtrl.text,
        'duree_minutes': _duree,
        if (_lieuCtrl.text.isNotEmpty) 'lieu': _lieuCtrl.text.trim(),
        if (_notesCtrl.text.isNotEmpty) 'notes': _notesCtrl.text.trim(),
      });
      ref.invalidate(seancesProvider);
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Séance créée — présences initialisées pour tous les athlètes'),
          backgroundColor: AppTheme.success,
          behavior: SnackBarBehavior.floating,
        ));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Erreur : $e'),
        backgroundColor: AppTheme.error,
        behavior: SnackBarBehavior.floating,
      ));
    }
    if (mounted) setState(() => _creating = false);
  }

  void _showCreateDialog() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.75,
        maxChildSize: 0.95,
        builder: (_, ctrl) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: ListView(
            controller: ctrl,
            padding: const EdgeInsets.all(20),
            children: [
              Center(child: Container(
                width: 40, height: 4,
                decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)),
              )),
              const SizedBox(height: 16),
              const Text('NOUVELLE SÉANCE', style: TextStyle(
                fontWeight: FontWeight.bold, fontSize: 16, color: AppTheme.primary)),
              const SizedBox(height: 20),
              TextFormField(
                controller: _dateCtrl,
                readOnly: true,
                decoration: const InputDecoration(labelText: 'Date', prefixIcon: Icon(Icons.calendar_today)),
                onTap: () async {
                  final d = await showDatePicker(
                    context: context,
                    initialDate: DateTime.now(),
                    firstDate: DateTime(2024),
                    lastDate: DateTime(2030),
                  );
                  if (d != null) _dateCtrl.text = d.toIso8601String().substring(0, 10);
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _heureCtrl,
                decoration: const InputDecoration(labelText: 'Heure de début (HH:MM)', prefixIcon: Icon(Icons.access_time)),
                keyboardType: TextInputType.datetime,
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<int>(
                value: _duree,
                decoration: const InputDecoration(labelText: 'Durée'),
                items: [60, 90, 120].map((d) => DropdownMenuItem(
                  value: d, child: Text('$d minutes'))).toList(),
                onChanged: (v) => setState(() => _duree = v!),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _lieuCtrl,
                decoration: const InputDecoration(labelText: 'Lieu (optionnel)', prefixIcon: Icon(Icons.location_on)),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _notesCtrl,
                maxLines: 3,
                decoration: const InputDecoration(labelText: 'Notes (optionnel)', prefixIcon: Icon(Icons.notes), alignLabelWithHint: true),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _creating ? null : _creerSeance,
                child: _creating
                    ? const SizedBox(height: 20, width: 20,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Text('CRÉER LA SÉANCE'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(seancesProvider);

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('SÉANCES'),
        leading: BackButton(onPressed: () => context.pop()),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showCreateDialog,
        backgroundColor: AppTheme.primary,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('NOUVELLE SÉANCE', style: TextStyle(color: Colors.white)),
      ),
      body: state.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 48, color: AppTheme.error),
            const SizedBox(height: 12),
            const Text('Impossible de charger les séances'),
            TextButton(onPressed: () => ref.invalidate(seancesProvider), child: const Text('Réessayer')),
          ],
        )),
        data: (seances) {
          if (seances.isEmpty) return const Center(child: Text('Aucune séance enregistrée'));
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
            itemCount: seances.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (_, i) {
              final s = seances[i];
              final date = (s['date'] as String?)?.substring(0, 10) ?? '—';
              final heure = s['heure_debut'] as String? ?? '—';
              final duree = s['duree_minutes'] as int? ?? 0;
              final lieu = s['lieu'] as String? ?? 'Salle principale';
              final statut = s['statut'] as String? ?? 'planifiee';
              final maitre = s['maitre'] as Map<String, dynamic>? ?? {};
              final color = statut == 'terminee' ? AppTheme.success
                  : statut == 'annulee' ? AppTheme.error : AppTheme.primary;
              final label = statut == 'terminee' ? 'Terminée'
                  : statut == 'annulee' ? 'Annulée' : 'Planifiée';

              return GestureDetector(
                onTap: () => Navigator.push(context, MaterialPageRoute(
                  builder: (_) => PresencesPage(seanceId: s['id'] as int, seance: s),
                )).then((_) => ref.invalidate(seancesProvider)),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.sports_martial_arts, color: color, size: 22),
                    ),
                    const SizedBox(width: 12),
                    Expanded(child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('$date à $heure', style: const TextStyle(fontWeight: FontWeight.bold)),
                        Text('$lieu · $duree min', style: const TextStyle(color: Colors.grey, fontSize: 12)),
                        Text('Maître : ${maitre['nom'] ?? ''} ${maitre['prenom'] ?? ''}',
                          style: const TextStyle(color: Colors.grey, fontSize: 11)),
                      ],
                    )),
                    Column(children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(label, style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.bold)),
                      ),
                      const SizedBox(height: 4),
                      const Icon(Icons.chevron_right, color: Colors.grey, size: 18),
                    ]),
                  ]),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

// ─── Page Présences ───────────────────────────────────────────────────────────
class PresencesPage extends ConsumerStatefulWidget {
  final int seanceId;
  final Map<String, dynamic> seance;
  const PresencesPage({super.key, required this.seanceId, required this.seance});

  @override
  ConsumerState<PresencesPage> createState() => _PresencesPageState();
}

class _PresencesPageState extends ConsumerState<PresencesPage> {
  List<Map<String, dynamic>> _presences = [];
  bool _loading = true;
  bool _saving  = false;

  @override
  void initState() {
    super.initState();
    _charger();
  }

  Future<void> _charger() async {
    try {
      final response = await ApiClient().dio.get('/seances/${widget.seanceId}');
      final data = response.data as Map<String, dynamic>;
      setState(() {
        _presences = (data['presences'] as List).cast<Map<String, dynamic>>();
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
    }
  }

  Future<void> _enregistrer() async {
    setState(() => _saving = true);
    try {
      await ApiClient().dio.post('/seances/${widget.seanceId}/presences', data: {
        'presences': _presences.map((p) => {
          'athlete_id': (p['athlete'] as Map)['id'],
          'statut': p['statut'],
          'note': p['note'],
        }).toList(),
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Présences enregistrées !'),
          backgroundColor: AppTheme.success,
          behavior: SnackBarBehavior.floating,
        ));
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Erreur : $e'),
        backgroundColor: AppTheme.error,
        behavior: SnackBarBehavior.floating,
      ));
    }
    if (mounted) setState(() => _saving = false);
  }

  Color _couleurStatut(String statut) {
    switch (statut) {
      case 'present': return AppTheme.success;
      case 'retard':  return AppTheme.warning;
      case 'excuse':  return Colors.blue;
      default:        return AppTheme.error;
    }
  }

  IconData _iconeStatut(String statut) {
    switch (statut) {
      case 'present': return Icons.check_circle;
      case 'retard':  return Icons.access_time;
      case 'excuse':  return Icons.mail_outline;
      default:        return Icons.cancel;
    }
  }

  @override
  Widget build(BuildContext context) {
    final date = (widget.seance['date'] as String?)?.substring(0, 10) ?? '—';
    final heure = widget.seance['heure_debut'] as String? ?? '—';
    final statuts = ['present', 'absent', 'retard', 'excuse'];
    final labels  = ['Présent', 'Absent', 'Retard', 'Excusé'];

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: Text('PRÉSENCES · $date'),
        leading: const BackButton(),
        actions: [
          TextButton(
            onPressed: _saving ? null : _enregistrer,
            child: _saving
                ? const SizedBox(height: 18, width: 18,
                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                : const Text('ENREGISTRER', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(children: [
              // Résumé
              Container(
                color: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _Compteur('Présents', _presences.where((p) => p['statut'] == 'present').length, AppTheme.success),
                    _Compteur('Absents',  _presences.where((p) => p['statut'] == 'absent').length,  AppTheme.error),
                    _Compteur('Retards',  _presences.where((p) => p['statut'] == 'retard').length,  AppTheme.warning),
                    _Compteur('Excusés',  _presences.where((p) => p['statut'] == 'excuse').length,  Colors.blue),
                  ],
                ),
              ),
              // Boutons rapides
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(children: [
                  Expanded(child: OutlinedButton(
                    onPressed: () => setState(() {
                      for (var p in _presences) p['statut'] = 'present';
                    }),
                    child: const Text('TOUS PRÉSENTS'),
                  )),
                  const SizedBox(width: 8),
                  Expanded(child: OutlinedButton(
                    onPressed: () => setState(() {
                      for (var p in _presences) p['statut'] = 'absent';
                    }),
                    style: OutlinedButton.styleFrom(foregroundColor: AppTheme.error),
                    child: const Text('TOUS ABSENTS'),
                  )),
                ]),
              ),
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 80),
                  itemCount: _presences.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (_, i) {
                    final p = _presences[i];
                    final athlete = p['athlete'] as Map<String, dynamic>? ?? {};
                    final nom = '${athlete['nom'] ?? ''} ${athlete['prenom'] ?? ''}'.trim();
                    final statut = p['statut'] as String? ?? 'absent';
                    final color = _couleurStatut(statut);

                    return Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border(left: BorderSide(color: color, width: 4)),
                      ),
                      child: Column(children: [
                        ListTile(
                          leading: CircleAvatar(
                            backgroundColor: color.withValues(alpha: 0.1),
                            child: Icon(_iconeStatut(statut), color: color, size: 20),
                          ),
                          title: Text(nom, style: const TextStyle(fontWeight: FontWeight.w600)),
                          subtitle: Text(athlete['ceinture_actuelle'] as String? ?? '—',
                            style: const TextStyle(fontSize: 11)),
                          trailing: DropdownButton<String>(
                            value: statut,
                            underline: const SizedBox(),
                            items: List.generate(statuts.length, (j) => DropdownMenuItem(
                              value: statuts[j],
                              child: Text(labels[j], style: TextStyle(
                                fontSize: 12,
                                color: _couleurStatut(statuts[j]),
                                fontWeight: FontWeight.w600,
                              )),
                            )),
                            onChanged: (v) => setState(() => _presences[i]['statut'] = v!),
                          ),
                        ),
                      ]),
                    );
                  },
                ),
              ),
            ]),
    );
  }
}

class _Compteur extends StatelessWidget {
  final String label;
  final int count;
  final Color color;
  const _Compteur(this.label, this.count, this.color);

  @override
  Widget build(BuildContext context) => Column(children: [
    Text('$count', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: color)),
    Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
  ]);
}
