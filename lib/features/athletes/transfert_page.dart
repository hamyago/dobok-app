import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/api/api_client.dart';
import '../../core/models/athlete_model.dart';
import '../../core/providers/athletes_provider.dart';
import '../../core/theme/app_theme.dart';

// Provider historique clubs
final historiqueClubsProvider =
    FutureProvider.family<List<Map<String, dynamic>>, int>((ref, athleteId) async {
  final response = await ApiClient().dio.get('/athletes/$athleteId/historique-clubs');
  return (response.data as List).cast<Map<String, dynamic>>();
});

// Provider clubs disponibles
final clubsDisponiblesProvider =
    FutureProvider.family<List<Map<String, dynamic>>, int>((ref, athleteId) async {
  final response = await ApiClient().dio.get('/athletes/$athleteId/clubs-disponibles');
  return (response.data as List).cast<Map<String, dynamic>>();
});

class TransfertPage extends ConsumerStatefulWidget {
  final AthleteModel athlete;
  const TransfertPage({super.key, required this.athlete});

  @override
  ConsumerState<TransfertPage> createState() => _TransfertPageState();
}

class _TransfertPageState extends ConsumerState<TransfertPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabs;
  Map<String, dynamic>? _clubSelectionne;
  final _dateCtrl = TextEditingController(
    text: DateTime.now().toIso8601String().substring(0, 10));
  final _motifCtrl = TextEditingController();
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabs.dispose();
    _dateCtrl.dispose();
    _motifCtrl.dispose();
    super.dispose();
  }

  Future<void> _transferer() async {
    if (_clubSelectionne == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Veuillez sélectionner le club de destination'),
        backgroundColor: AppTheme.error,
        behavior: SnackBarBehavior.floating,
      ));
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirmer le transfert'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Athlète : ${widget.athlete.fullName}',
              style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text('Club de destination : ${_clubSelectionne!['nom']}',
              style: const TextStyle(color: Colors.grey)),
            const SizedBox(height: 4),
            Text('Date : ${_dateCtrl.text}',
              style: const TextStyle(color: Colors.grey)),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppTheme.warning.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text(
                '⚠️ Cette action est irréversible. L\'athlète sera retiré de votre liste et ajouté au club de destination.',
                style: TextStyle(fontSize: 12, color: Colors.orange),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annuler')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primary),
            child: const Text('CONFIRMER LE TRANSFERT'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _loading = true);
    try {
      final response = await ApiClient().dio.post(
        '/athletes/${widget.athlete.id}/transferer',
        data: {
          'club_destination_id': _clubSelectionne!['id'],
          'date_transfert': _dateCtrl.text,
          if (_motifCtrl.text.isNotEmpty) 'motif': _motifCtrl.text.trim(),
        },
      );

      ref.invalidate(athletesProvider);
      ref.invalidate(historiqueClubsProvider(widget.athlete.id));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(response.data['message'] as String? ?? 'Transfert effectué !'),
          backgroundColor: AppTheme.success,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 4),
        ));
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        String msg = 'Erreur lors du transfert';
        final err = e.toString();
        if (err.contains('403')) msg = 'Vous ne pouvez transférer que vos propres athlètes';
        if (err.contains('422')) msg = 'L\'athlète est déjà dans ce club';
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(msg),
          backgroundColor: AppTheme.error,
          behavior: SnackBarBehavior.floating,
        ));
      }
    }
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    final clubsState = ref.watch(clubsDisponiblesProvider(widget.athlete.id));
    final historiqueState = ref.watch(historiqueClubsProvider(widget.athlete.id));

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('TRANSFERT D\'ATHLÈTE'),
        leading: const BackButton(),
        bottom: TabBar(
          controller: _tabs,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white60,
          indicatorColor: Colors.white,
          tabs: const [
            Tab(text: 'Demande de transfert'),
            Tab(text: 'Historique des clubs'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabs,
        children: [
          // ── Onglet 1 : Formulaire de transfert ─────────────────────
          ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // Résumé athlète
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(children: [
                  CircleAvatar(
                    backgroundColor: AppTheme.primary.withValues(alpha: 0.1),
                    radius: 28,
                    child: Text(widget.athlete.initiale,
                      style: const TextStyle(
                        fontSize: 22, color: AppTheme.primary, fontWeight: FontWeight.bold)),
                  ),
                  const SizedBox(width: 16),
                  Expanded(child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(widget.athlete.fullName,
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 2),
                      Text('Ceinture : ${widget.athlete.ceinture.toUpperCase()}',
                        style: const TextStyle(color: Colors.grey, fontSize: 13)),
                      if (widget.athlete.numeroLicence != null)
                        Text('Licence : ${widget.athlete.numeroLicence}',
                          style: const TextStyle(color: Colors.grey, fontSize: 12)),
                    ],
                  )),
                ]),
              ),
              const SizedBox(height: 16),

              // Sélection club destination
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('CLUB DE DESTINATION', style: TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.primary)),
                    const SizedBox(height: 12),
                    clubsState.when(
                      loading: () => const Center(child: CircularProgressIndicator()),
                      error: (e, _) => Text('Erreur : $e',
                        style: const TextStyle(color: AppTheme.error)),
                      data: (clubs) => clubs.isEmpty
                          ? const Text('Aucun autre club disponible',
                              style: TextStyle(color: Colors.grey))
                          : DropdownButtonFormField<Map<String, dynamic>>(
                              value: _clubSelectionne,
                              decoration: const InputDecoration(
                                hintText: 'Sélectionner le club de destination',
                                prefixIcon: Icon(Icons.business),
                              ),
                              items: clubs.map((club) => DropdownMenuItem(
                                value: club,
                                child: Text(club['nom'] as String? ?? ''),
                              )).toList(),
                              onChanged: (v) => setState(() => _clubSelectionne = v),
                            ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Date et motif
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('DÉTAILS DU TRANSFERT', style: TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.primary)),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _dateCtrl,
                      readOnly: true,
                      decoration: const InputDecoration(
                        labelText: 'Date de transfert',
                        prefixIcon: Icon(Icons.calendar_today),
                      ),
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: DateTime.now(),
                          firstDate: DateTime(2020),
                          lastDate: DateTime(2030),
                        );
                        if (picked != null) {
                          _dateCtrl.text = picked.toIso8601String().substring(0, 10);
                        }
                      },
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _motifCtrl,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        labelText: 'Motif du transfert (optionnel)',
                        prefixIcon: Icon(Icons.notes),
                        alignLabelWithHint: true,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Avertissement
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppTheme.warning.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppTheme.warning.withValues(alpha: 0.3)),
                ),
                child: const Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.info_outline, color: AppTheme.warning, size: 20),
                    SizedBox(width: 10),
                    Expanded(child: Text(
                      'Conformément au règlement du Taekwondo ivoirien, le président du club d\'origine initie le transfert après présentation de la lettre de sortie par l\'athlète. Toutes les informations personnelles (passeport, licence) restent inchangées.',
                      style: TextStyle(fontSize: 12, color: Colors.orange, height: 1.5),
                    )),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              ElevatedButton.icon(
                onPressed: _loading ? null : _transferer,
                icon: _loading
                    ? const SizedBox(height: 18, width: 18,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Icon(Icons.swap_horiz),
                label: const Text('EFFECTUER LE TRANSFERT'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primary,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 52),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),

          // ── Onglet 2 : Historique des clubs ───────────────────────
          historiqueState.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline, size: 48, color: AppTheme.error),
                const SizedBox(height: 12),
                const Text('Impossible de charger l\'historique'),
                TextButton(
                  onPressed: () => ref.invalidate(historiqueClubsProvider(widget.athlete.id)),
                  child: const Text('Réessayer'),
                ),
              ],
            )),
            data: (historique) {
              if (historique.isEmpty) {
                return const Center(child: Text('Aucun historique disponible'));
              }
              return ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: historique.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (_, i) {
                  final h = historique[i];
                  final club = h['club'] as Map<String, dynamic>? ?? {};
                  final clubDest = h['club_destination'] as Map<String, dynamic>?;
                  final dateEntree = (h['date_entree'] as String?)?.substring(0, 10) ?? '—';
                  final dateSortie = (h['date_sortie'] as String?)?.substring(0, 10);
                  final motif = h['motif'] as String? ?? 'inscription';
                  final isCurrent = dateSortie == null;

                  return Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: isCurrent
                          ? Border.all(color: AppTheme.primary, width: 1.5)
                          : null,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: isCurrent
                                  ? AppTheme.primary.withValues(alpha: 0.1)
                                  : Colors.grey.withValues(alpha: 0.1),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(Icons.business,
                              color: isCurrent ? AppTheme.primary : Colors.grey,
                              size: 20),
                          ),
                          const SizedBox(width: 12),
                          Expanded(child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(children: [
                                Expanded(child: Text(
                                  club['nom'] as String? ?? '—',
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                )),
                                if (isCurrent)
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: AppTheme.success.withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: const Text('CLUB ACTUEL',
                                      style: TextStyle(fontSize: 10, color: AppTheme.success,
                                        fontWeight: FontWeight.bold)),
                                  ),
                              ]),
                              const SizedBox(height: 4),
                              Text('Entrée : $dateEntree${dateSortie != null ? '  •  Sortie : $dateSortie' : ''}',
                                style: const TextStyle(color: Colors.grey, fontSize: 12)),
                            ],
                          )),
                        ]),
                        if (motif == 'transfert') ...[
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.orange.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(children: [
                              const Icon(Icons.swap_horiz, size: 14, color: Colors.orange),
                              const SizedBox(width: 6),
                              Text(
                                clubDest != null
                                    ? 'Transféré vers : ${clubDest['nom']}'
                                    : 'Transfert',
                                style: const TextStyle(fontSize: 11, color: Colors.orange),
                              ),
                            ]),
                          ),
                        ],
                      ],
                    ),
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }
}
