import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/api/api_client.dart';
import '../../core/models/athlete_model.dart';
import '../../core/providers/athletes_provider.dart';
import '../../core/providers/auth_provider.dart';
import '../../core/theme/app_theme.dart';

final tarifClubProvider = FutureProvider<Map<String, dynamic>?>((ref) async {
  try {
    final r = await ApiClient().dio.get('/tarif-club');
    return r.data as Map<String, dynamic>?;
  } catch (_) { return null; }
});

final mensualitesMoisProvider = FutureProvider.family<List<Map<String, dynamic>>, String>(
  (ref, moisAnnee) async {
    final parts = moisAnnee.split('-');
    final r = await ApiClient().dio.get('/mensualites',
      queryParameters: {'mois': parts[0], 'annee': parts[1]});
    return (r.data as List).cast<Map<String, dynamic>>();
  },
);

class MensualitesPage extends ConsumerStatefulWidget {
  const MensualitesPage({super.key});

  @override
  ConsumerState<MensualitesPage> createState() => _MensualitesPageState();
}

class _MensualitesPageState extends ConsumerState<MensualitesPage> {
  int _mois  = DateTime.now().month;
  int _annee = DateTime.now().year;
  bool _generating = false;

  String get _key => '$_mois-$_annee';

  final _moisLabels = ['Janvier','Février','Mars','Avril','Mai','Juin',
    'Juillet','Août','Septembre','Octobre','Novembre','Décembre'];

  Future<void> _genererMois() async {
    setState(() => _generating = true);
    try {
      final r = await ApiClient().dio.post('/mensualites/generer',
        data: {'mois': _mois, 'annee': _annee});
      ref.invalidate(mensualitesMoisProvider(_key));
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(r.data['message'] as String? ?? 'Mensualités générées'),
        backgroundColor: AppTheme.success,
        behavior: SnackBarBehavior.floating,
      ));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Erreur : $e'),
        backgroundColor: AppTheme.error,
        behavior: SnackBarBehavior.floating,
      ));
    }
    if (mounted) setState(() => _generating = false);
  }

  Future<void> _enregistrerPaiement(int athleteId, int montant) async {
    try {
      await ApiClient().dio.post('/mensualites', data: {
        'athlete_id':   athleteId,
        'montant_fcfa': montant,
        'mois':         _mois,
        'annee':        _annee,
      });
      ref.invalidate(mensualitesMoisProvider(_key));
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Paiement enregistré !'),
        backgroundColor: AppTheme.success,
        behavior: SnackBarBehavior.floating,
      ));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Erreur : $e'),
        backgroundColor: AppTheme.error,
        behavior: SnackBarBehavior.floating,
      ));
    }
  }

  String _formatMontant(int montant) => montant.toString()
    .replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]} ');

  @override
  Widget build(BuildContext context) {
    final tarifState  = ref.watch(tarifClubProvider);
    final mensState   = ref.watch(mensualitesMoisProvider(_key));

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('MENSUALITÉS'),
        leading: BackButton(onPressed: () => context.pop()),
      ),
      body: Column(children: [
        // Sélecteur mois/année
        Container(
          color: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(children: [
            IconButton(
              icon: const Icon(Icons.chevron_left),
              onPressed: () => setState(() {
                if (_mois == 1) { _mois = 12; _annee--; }
                else _mois--;
              }),
            ),
            Expanded(child: Text(
              '${_moisLabels[_mois - 1]} $_annee',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            )),
            IconButton(
              icon: const Icon(Icons.chevron_right),
              onPressed: () => setState(() {
                if (_mois == 12) { _mois = 1; _annee++; }
                else _mois++;
              }),
            ),
          ]),
        ),

        // Tarif + stats
        tarifState.when(
          data: (tarif) {
            final montant = tarif?['montant_fcfa'] as int? ?? 0;
            return Container(
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [AppTheme.primary, Color(0xFF2EA55A)],
                  begin: Alignment.topLeft, end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(children: [
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('Tarif mensuel', style: TextStyle(color: Colors.white70, fontSize: 12)),
                  Text('${_formatMontant(montant)} FCFA',
                    style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
                ])),
                ElevatedButton.icon(
                  onPressed: _generating ? null : _genererMois,
                  icon: _generating
                      ? const SizedBox(height: 16, width: 16,
                          child: CircularProgressIndicator(color: AppTheme.primary, strokeWidth: 2))
                      : const Icon(Icons.auto_fix_high, size: 16),
                  label: const Text('GÉNÉRER'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: AppTheme.primary,
                  ),
                ),
              ]),
            );
          },
          loading: () => const SizedBox(),
          error: (_, __) => const SizedBox(),
        ),

        // Liste des mensualités
        Expanded(
          child: mensState.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline, size: 48, color: AppTheme.error),
                const SizedBox(height: 12),
                const Text('Impossible de charger les mensualités'),
                TextButton(
                  onPressed: () => ref.invalidate(mensualitesMoisProvider(_key)),
                  child: const Text('Réessayer'),
                ),
              ],
            )),
            data: (mensualites) {
              if (mensualites.isEmpty) return Center(child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Aucune mensualité pour ce mois'),
                  const SizedBox(height: 12),
                  ElevatedButton(
                    onPressed: _generating ? null : _genererMois,
                    child: const Text('GÉNÉRER LES MENSUALITÉS'),
                  ),
                ],
              ));

              // Totaux
              final total   = mensualites.fold<int>(0, (s, m) => s + ((m['montant_fcfa'] as int?) ?? 0));
              final payees  = mensualites.where((m) => m['statut'] == 'paye').length;
              final attente = mensualites.where((m) => m['statut'] == 'en_attente').length;
              final retard  = mensualites.where((m) => m['statut'] == 'en_retard').length;

              return Column(children: [
                // Stats rapides
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                  child: Row(children: [
                    _StatChip('✅ Payés', payees, AppTheme.success),
                    const SizedBox(width: 8),
                    _StatChip('⏳ En attente', attente, AppTheme.warning),
                    const SizedBox(width: 8),
                    _StatChip('🔴 Retard', retard, AppTheme.error),
                  ]),
                ),
                Expanded(
                  child: ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                    itemCount: mensualites.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (_, i) {
                      final m = mensualites[i];
                      final athlete = m['athlete'] as Map<String, dynamic>? ?? {};
                      final nom = '${athlete['nom'] ?? ''} ${athlete['prenom'] ?? ''}'.trim();
                      final statut = m['statut'] as String? ?? 'en_attente';
                      final montant = m['montant_fcfa'] as int? ?? 0;
                      final isPaye = statut == 'paye';
                      final isRetard = statut == 'en_retard';
                      final color = isPaye ? AppTheme.success : isRetard ? AppTheme.error : AppTheme.warning;
                      final label = isPaye ? 'Payé' : isRetard ? 'En retard' : 'En attente';

                      return Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border(left: BorderSide(color: color, width: 4)),
                        ),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: color.withValues(alpha: 0.1),
                            child: Text(
                              nom.isNotEmpty ? nom[0] : '?',
                              style: TextStyle(color: color, fontWeight: FontWeight.bold),
                            ),
                          ),
                          title: Text(nom, style: const TextStyle(fontWeight: FontWeight.w600)),
                          subtitle: Text('${_formatMontant(montant)} FCFA',
                            style: const TextStyle(fontSize: 12)),
                          trailing: isPaye
                              ? Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: AppTheme.success.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Text('✅ Payé',
                                    style: TextStyle(fontSize: 11, color: AppTheme.success, fontWeight: FontWeight.bold)),
                                )
                              : ElevatedButton(
                                  onPressed: () => _enregistrerPaiement(
                                    athlete['id'] as int, montant),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppTheme.primary,
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                    minimumSize: Size.zero,
                                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                  ),
                                  child: const Text('ENCAISSER', style: TextStyle(fontSize: 11)),
                                ),
                        ),
                      );
                    },
                  ),
                ),
              ]);
            },
          ),
        ),
      ]),
    );
  }
}

class _StatChip extends StatelessWidget {
  final String label;
  final int count;
  final Color color;
  const _StatChip(this.label, this.count, this.color);

  @override
  Widget build(BuildContext context) => Expanded(
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        Text('$label ', style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w600)),
        Text('$count', style: TextStyle(fontSize: 14, color: color, fontWeight: FontWeight.bold)),
      ]),
    ),
  );
}
