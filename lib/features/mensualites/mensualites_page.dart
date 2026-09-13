import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/api/api_client.dart';
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
    final mois  = int.parse(parts[0]);
    final annee = int.parse(parts[1]);
    final now   = DateTime.now();

    // FIX retards : marquer les retards avant de charger si le mois est passé
    final estMoisPasse = DateTime(annee, mois).isBefore(DateTime(now.year, now.month));
    if (estMoisPasse) {
      try {
        await ApiClient().dio.post('/mensualites/marquer-retards',
          data: {'mois': mois, 'annee': annee});
      } catch (_) { /* silencieux */ }
    }

    final r = await ApiClient().dio.get('/mensualites',
      queryParameters: {'mois': mois, 'annee': annee});
    return (r.data as List).cast<Map<String, dynamic>>();
  },
);

class MensualitesPage extends ConsumerStatefulWidget {
  const MensualitesPage({super.key});

  @override
  ConsumerState<MensualitesPage> createState() => _MensualitesPageState();
}

class _MensualitesPageState extends ConsumerState<MensualitesPage> {
  int  _mois  = DateTime.now().month;
  int  _annee = DateTime.now().year;
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

  void _showSetTarifDialog(int montantActuel) {
    final ctrl = TextEditingController(
      text: montantActuel > 0 ? montantActuel.toString() : '');
    bool saving = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(children: [
            Icon(Icons.payments_outlined, color: AppTheme.primary, size: 22),
            SizedBox(width: 8),
            Text('Tarif mensuel', style: TextStyle(fontSize: 16)),
          ]),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Définissez le montant mensuel appliqué à tous les athlètes du club.',
                style: TextStyle(fontSize: 13, color: Colors.grey)),
              const SizedBox(height: 16),
              TextFormField(
                controller: ctrl,
                autofocus: true,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Montant (FCFA)',
                  prefixIcon: Icon(Icons.attach_money),
                  suffixText: 'FCFA',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('ANNULER', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              onPressed: saving ? null : () async {
                final montant = int.tryParse(ctrl.text.trim());
                if (montant == null || montant < 0) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                    content: Text('Montant invalide'),
                    backgroundColor: AppTheme.error,
                    behavior: SnackBarBehavior.floating,
                  ));
                  return;
                }
                setDialogState(() => saving = true);
                try {
                  await ApiClient().dio.post('/tarif-club', data: {
                    'montant_fcfa': montant,
                    'libelle': 'Mensualité club',
                  });
                  ref.invalidate(tarifClubProvider);
                  if (context.mounted) {
                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content: Text('Tarif mis à jour : ${_formatMontant(montant)} FCFA'),
                      backgroundColor: AppTheme.success,
                      behavior: SnackBarBehavior.floating,
                    ));
                  }
                } catch (e) {
                  setDialogState(() => saving = false);
                  if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: Text('Erreur : $e'),
                    backgroundColor: AppTheme.error,
                    behavior: SnackBarBehavior.floating,
                  ));
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primary),
              child: saving
                  ? const SizedBox(height: 18, width: 18,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Text('ENREGISTRER', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  void _changerMois(int delta) {
    setState(() {
      _mois += delta;
      if (_mois > 12) { _mois = 1;  _annee++; }
      if (_mois < 1)  { _mois = 12; _annee--; }
      // Invalider le provider pour forcer le rechargement + recalcul retards
      ref.invalidate(mensualitesMoisProvider(_key));
    });
  }

  @override
  Widget build(BuildContext context) {
    final tarifState = ref.watch(tarifClubProvider);
    final mensState  = ref.watch(mensualitesMoisProvider(_key));

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('MENSUALITÉS'),
        leading: BackButton(onPressed: () => context.pop()),
      ),
      body: Column(children: [

        // ── Sélecteur mois/année ──────────────────────────────────────────
        Container(
          color: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(children: [
            IconButton(
              icon: const Icon(Icons.chevron_left),
              onPressed: () => _changerMois(-1),
            ),
            Expanded(child: Text(
              '${_moisLabels[_mois - 1]} $_annee',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            )),
            IconButton(
              icon: const Icon(Icons.chevron_right),
              onPressed: () => _changerMois(1),
            ),
          ]),
        ),

        // ── Tarif + bouton générer ────────────────────────────────────────
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
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Ligne 1 : tarif + icône modifier
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text(
                              'Tarif mensuel',
                              style: TextStyle(color: Colors.white70, fontSize: 12),
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                            ),
                            Text(
                              montant == 0 ? 'Non défini' : '${_formatMontant(montant)} FCFA',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Bouton modifier le tarif
                      GestureDetector(
                        onTap: () => _showSetTarifDialog(montant),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.edit, color: Colors.white, size: 14),
                              SizedBox(width: 4),
                              Text('MODIFIER', style: TextStyle(
                                color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // Ligne 2 : bouton générer pleine largeur
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _generating ? null : _genererMois,
                      icon: _generating
                          ? const SizedBox(
                              height: 16, width: 16,
                              child: CircularProgressIndicator(
                                color: AppTheme.primary, strokeWidth: 2))
                          : const Icon(Icons.auto_fix_high, size: 16),
                      label: const Text('GÉNÉRER LES MENSUALITÉS DU MOIS'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: AppTheme.primary,
                        padding: const EdgeInsets.symmetric(vertical: 10),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
          loading: () => const SizedBox(),
          error:   (_, __) => const SizedBox(),
        ),

        // ── Liste des mensualités ─────────────────────────────────────────
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
                  child: const Text('Réessayer')),
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
                    child: const Text('GÉNÉRER LES MENSUALITÉS')),
                ],
              ));

              final payees  = mensualites.where((m) => m['statut'] == 'paye').length;
              final attente = mensualites.where((m) => m['statut'] == 'en_attente').length;
              final retard  = mensualites.where((m) => m['statut'] == 'en_retard').length;

              return Column(children: [
                // ── Stats rapides ─────────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                  child: Row(children: [
                    _StatChip('✅ Payés',      payees,  AppTheme.success),
                    const SizedBox(width: 8),
                    _StatChip('⏳ En attente', attente, AppTheme.warning),
                    const SizedBox(width: 8),
                    _StatChip('🔴 Retard',     retard,  AppTheme.error),
                  ]),
                ),

                // ── Liste ─────────────────────────────────────────────────
                Expanded(
                  child: ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                    itemCount: mensualites.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (_, i) {
                      final m       = mensualites[i];
                      final athlete = m['athlete'] as Map<String, dynamic>? ?? {};
                      final nom     = '${athlete['nom'] ?? ''} ${athlete['prenom'] ?? ''}'.trim();
                      final statut  = m['statut'] as String? ?? 'en_attente';
                      final montant = m['montant_fcfa'] as int? ?? 0;
                      final isPaye   = statut == 'paye';
                      final isRetard = statut == 'en_retard';
                      final color = isPaye ? AppTheme.success
                          : isRetard ? AppTheme.error : AppTheme.warning;
                      final label = isPaye ? 'Payé'
                          : isRetard ? 'En retard' : 'En attente';

                      return Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border(left: BorderSide(color: color, width: 4)),
                        ),
                        // FIX affichage : ListTile seul, pas Column > ListTile
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: color.withValues(alpha: 0.1),
                            child: Text(
                              nom.isNotEmpty ? nom[0] : '?',
                              style: TextStyle(color: color, fontWeight: FontWeight.bold),
                            ),
                          ),
                          title: Text(nom,
                            style: const TextStyle(fontWeight: FontWeight.w600)),
                          subtitle: Text('${_formatMontant(montant)} FCFA · $label',
                            style: TextStyle(fontSize: 12, color: color)),
                          trailing: isPaye
                              ? Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: AppTheme.success.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Text('✅ Payé',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: AppTheme.success,
                                      fontWeight: FontWeight.bold)),
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
                                  child: const Text('ENCAISSER',
                                    style: TextStyle(fontSize: 11)),
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
